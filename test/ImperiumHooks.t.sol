// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ImperiumHooks} from "../contracts/v4/ImperiumHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HookMiner} from "lib/v4-periphery/test/shared/HookMiner.sol";

contract ImperiumHooksTest is Test {
    using PoolIdLibrary for PoolKey;

    ImperiumHooks internal hooks;
    GuardianRegistry internal registry;
    address internal poolManagerAddr = address(0xBEEF);
    address internal owner = address(0xA11CE);
    address internal guardian = address(0x6A12D);
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function setUp() public {
        // GuardianRegistry dietro proxy (UUPS)
        GuardianRegistry registryImpl = new GuardianRegistry();
        bytes memory regInit =
            abi.encodeWithSelector(GuardianRegistry.initialize.selector, owner, 0, 0);
        ERC1967Proxy regProxy = new ERC1967Proxy(address(registryImpl), regInit);
        registry = GuardianRegistry(address(regProxy));

        // ImperiumHooks: deploy diretto via CREATE2 con bit 0xC0
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory creationCode = type(ImperiumHooks).creationCode;
        bytes memory constructorArgs =
            abi.encode(IPoolManager(poolManagerAddr), registry, owner);

        (address hookAddr, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, creationCode, constructorArgs);

        vm.prank(CREATE2_DEPLOYER);
        ImperiumHooks impl = new ImperiumHooks{salt: salt}(
            IPoolManager(poolManagerAddr), registry, owner
        );
        require(address(impl) == hookAddr, "impl mismatch");
        hooks = impl;
    }

    function _makeKey() internal view returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hooks))
        });
    }

    function test_address_has_flags() public view {
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        assertEq(uint160(address(hooks)) & Hooks.ALL_HOOK_MASK, flags, "flags mismatch");
    }

    function test_owner_set() public view {
        assertEq(hooks.owner(), owner);
    }

    function test_guardian_registry_set() public view {
        assertEq(address(hooks.guardianRegistry()), address(registry));
    }

    function test_beforeSwap_revertsIfNotPoolManager() public {
        PoolKey memory key = _makeKey();
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, amountSpecified: 1e18, sqrtPriceLimitX96: 0
        });
        vm.expectRevert(ImperiumHooks.NotPoolManager.selector);
        hooks.beforeSwap(address(this), key, params, "");
    }

    function test_beforeSwap_returnsSelector() public {
        PoolKey memory key = _makeKey();
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, amountSpecified: 1e18, sqrtPriceLimitX96: 0
        });
        vm.prank(poolManagerAddr);
        (bytes4 sel, BeforeSwapDelta d, uint24 fee) = hooks.beforeSwap(address(this), key, params, "");
        assertEq(sel, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(d), BeforeSwapDelta.unwrap(BeforeSwapDeltaLibrary.ZERO_DELTA));
        assertEq(fee, 0);
    }

    function test_beforeSwap_recordsStats() public {
        PoolKey memory key = _makeKey();
        PoolId id = key.toId();
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, amountSpecified: 1e18, sqrtPriceLimitX96: 0
        });
        vm.prank(poolManagerAddr);
        hooks.beforeSwap(address(this), key, params, "");
        ImperiumHooks.PoolStats memory s = hooks.getPoolStats(id);
        assertEq(s.swapCount, 1);
        assertEq(hooks.totalSwaps(), 1);
    }

    function test_afterSwap_recordsVolume() public {
        PoolKey memory key = _makeKey();
        PoolId id = key.toId();
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, amountSpecified: 1e18, sqrtPriceLimitX96: 0
        });
        BalanceDelta delta = toBalanceDelta(int128(1e18), int128(-1e18));
        vm.prank(poolManagerAddr);
        (bytes4 sel, int128 hookDelta) = hooks.afterSwap(address(this), key, params, delta, "");
        assertEq(sel, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
        ImperiumHooks.PoolStats memory s = hooks.getPoolStats(id);
        assertEq(s.volume0, uint256(uint128(1e18)));
        assertEq(s.volume1, uint256(uint128(1e18)));
    }

    function test_beforeInitialize_returnsSelector() public {
        PoolKey memory key = _makeKey();
        vm.prank(poolManagerAddr);
        bytes4 sel = hooks.beforeInitialize(address(this), key, 1 << 96);
        assertEq(sel, IHooks.beforeInitialize.selector);
    }

    function test_afterInitialize_returnsSelector() public {
        PoolKey memory key = _makeKey();
        vm.prank(poolManagerAddr);
        bytes4 sel = hooks.afterInitialize(address(this), key, 1 << 96, 0);
        assertEq(sel, IHooks.afterInitialize.selector);
    }

    function test_beforeAddLiquidity_returnsSelector() public {
        PoolKey memory key = _makeKey();
        IPoolManager.ModifyLiquidityParams memory params =
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: 0
            });
        vm.prank(poolManagerAddr);
        bytes4 sel = hooks.beforeAddLiquidity(address(this), key, params, "");
        assertEq(sel, IHooks.beforeAddLiquidity.selector);
    }

    function test_afterAddLiquidity_returnsSelectorAndZero() public {
        PoolKey memory key = _makeKey();
        IPoolManager.ModifyLiquidityParams memory params =
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: 0
            });
        vm.prank(poolManagerAddr);
        (bytes4 sel, BalanceDelta d) = hooks.afterAddLiquidity(
            address(this), key, params,
            toBalanceDelta(0, 0), toBalanceDelta(0, 0), ""
        );
        assertEq(sel, IHooks.afterAddLiquidity.selector);
        assertEq(BalanceDelta.unwrap(d), BalanceDelta.unwrap(BalanceDeltaLibrary.ZERO_DELTA));
    }

    function test_beforeRemoveLiquidity_returnsSelector() public {
        PoolKey memory key = _makeKey();
        IPoolManager.ModifyLiquidityParams memory params =
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: -1e18, salt: 0
            });
        vm.prank(poolManagerAddr);
        bytes4 sel = hooks.beforeRemoveLiquidity(address(this), key, params, "");
        assertEq(sel, IHooks.beforeRemoveLiquidity.selector);
    }

    function test_afterRemoveLiquidity_returnsSelectorAndZero() public {
        PoolKey memory key = _makeKey();
        IPoolManager.ModifyLiquidityParams memory params =
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: -1e18, salt: 0
            });
        vm.prank(poolManagerAddr);
        (bytes4 sel, BalanceDelta d) = hooks.afterRemoveLiquidity(
            address(this), key, params,
            toBalanceDelta(0, 0), toBalanceDelta(0, 0), ""
        );
        assertEq(sel, IHooks.afterRemoveLiquidity.selector);
        assertEq(BalanceDelta.unwrap(d), BalanceDelta.unwrap(BalanceDeltaLibrary.ZERO_DELTA));
    }

    function test_onlyOwner_canSetGuardianRegistry() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert();
        hooks.setGuardianRegistry(registry);
    }
}
