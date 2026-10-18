// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "../../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../../contracts/sle/core/PoolRegistry.sol";
import {T2TRouter} from "../../contracts/sle/core/T2TRouter.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";
import {IStrategySelector} from "../../contracts/sle/interfaces/IStrategySelector.sol";
import {IPoolManager} from "../../contracts/sle/interfaces/IPoolManager.sol";
import {IT2TRouter} from "../../contracts/sle/interfaces/IT2TRouter.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MockFeeToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

contract MockSelector is IStrategySelector {
    uint256 public fee;
    bool public blocked;
    function set(uint256 _fee, bool _blocked) external { fee = _fee; blocked = _blocked; }
    function selectForSwap(bytes32, uint256, uint256) external view override returns (uint256, bool) {
        return (fee, blocked);
    }
}

/// @dev Token che tenta reentrancy sul Router durante il transfer
contract ReentrantToken is ERC20 {
    T2TRouter public target;
    bool public attacking;
    bytes32 public poolId;
    bool public reentered;

    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function setTarget(T2TRouter _t, bytes32 _p) external { target = _t; poolId = _p; }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (attacking && from != address(0) && to != address(0)) {
            reentered = true;
            target.addLiquidity(poolId, 1, 1);
        }
    }
    function attack() external { attacking = true; }
}

contract T2TRouterTest is Test {
    T2TRouter internal router;
    PoolManager internal pm;
    PoolRegistry internal registry;
    SLEAddressProvider internal provider;
    ConstantProductCurve internal curve;
    MockSelector internal selector;

    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);

    bytes32 internal poolId;

    uint256 internal constant INIT0 = 1_000_000e18;
    uint256 internal constant INIT1 = 1_000_000e18;

    function setUp() public {
        curve = new ConstantProductCurve();
        registry = new PoolRegistry(owner);
        selector = new MockSelector();

        // Ordine: provider -> pm(registry, provider) -> router(provider, selector, registry) -> setEndpoints
        provider = new SLEAddressProvider(owner);
        pm = new PoolManager(address(registry), address(provider));
        router = new T2TRouter(address(provider), address(selector), address(registry));
        vm.prank(owner);
        provider.setEndpoints(address(router), address(pm));

        token0 = new MockERC20("Token0", "T0");
        token1 = new MockERC20("Token1", "T1");
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);

        poolId = keccak256(abi.encode(address(token0), address(token1), address(curve)));

        vm.prank(owner);
        registry.whitelistCurve(address(curve), true);
        vm.prank(owner);
        registry.registerPool(poolId, address(curve), address(token0), address(token1));
        vm.prank(owner);
        registry.activatePool(poolId);

        // Mint + approve al ROUTER
        token0.mint(alice, 10_000_000e18);
        token1.mint(alice, 10_000_000e18);
        token0.mint(bob, 10_000_000e18);
        token1.mint(bob, 10_000_000e18);

        vm.prank(alice);
        token0.approve(address(router), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(router), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(router), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(router), type(uint256).max);

        // Alice deposita liquidità iniziale
        vm.prank(alice);
        router.addLiquidity(poolId, INIT0, INIT1);
    }

    // ───────────── Access control ─────────────

    function test_routerIsOnlyCaller() public {
        // Chiamata diretta al PM senza impersonare il Router -> UnauthorizedCaller
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.UnauthorizedCaller.selector, address(this)));
        pm.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
    }

    function test_providerNotConfiguredReverts() public {
        SLEAddressProvider p2 = new SLEAddressProvider(owner);
        T2TRouter r2 = new T2TRouter(address(p2), address(selector), address(registry));
        // p2 non configurato -> pmAddr = 0 -> ProviderNotConfigured
        vm.prank(alice);
        vm.expectRevert(IT2TRouter.ProviderNotConfigured.selector);
        r2.addLiquidity(poolId, 1000e18, 1000e18);
    }

    // ───────────── Add Liquidity ─────────────

    function test_addLiquidity_LPToUser() public {
        uint256 bobBefore = pm.getLPBalance(poolId, bob);
        vm.prank(bob);
        uint256 lp = router.addLiquidity(poolId, 100_000e18, 100_000e18);
        assertGt(lp, 0);
        assertGt(pm.getLPBalance(poolId, bob), bobBefore);
        // Alice (router msg.sender = router) NON ha ricevuto LP
        // Le LP sono andate a bob (onBehalfOf = msg.sender di router)
    }

    function test_addLiquidity_allowanceReset() public {
        vm.prank(bob);
        router.addLiquidity(poolId, 100_000e18, 100_000e18);
        assertEq(token0.allowance(address(router), address(pm)), 0);
        assertEq(token1.allowance(address(router), address(pm)), 0);
    }

    function test_addLiquidity_zeroReverts() public {
        vm.prank(bob);
        vm.expectRevert(IT2TRouter.ZeroAmount.selector);
        router.addLiquidity(poolId, 0, 100e18);
    }

    function test_addLiquidity_feeOnTransferReverts() public {
        MockFeeToken feeToken = new MockFeeToken("Fee", "FEE");
        (address t0, address t1) = address(feeToken) < address(token0)
            ? (address(feeToken), address(token0))
            : (address(token0), address(feeToken));
        bytes32 fid = keccak256(abi.encode(t0, t1, address(curve)));
        vm.prank(owner);
        registry.registerPool(fid, address(curve), t0, t1);
        vm.prank(owner);
        registry.activatePool(fid);

        feeToken.mint(alice, 10_000_000e18);
        MockERC20(t1).mint(alice, 10_000_000e18);
        vm.prank(alice);
        feeToken.approve(address(router), type(uint256).max);
        vm.prank(alice);
        MockERC20(t1).approve(address(router), type(uint256).max);

        vm.prank(alice);
        vm.expectRevert(IT2TRouter.FeeOnTransferNotSupported.selector);
        router.addLiquidity(fid, 1000e18, 1000e18);
    }

    // ───────────── Swap ─────────────

    function test_swap_happyPath() public {
        selector.set(30, false);
        vm.prank(bob);
        uint256 out = router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100);
        assertGt(out, 0);
    }

    function test_swap_blockedByStrategy() public {
        selector.set(30, true);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IT2TRouter.BlockedByStrategy.selector, poolId));
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100);
    }

    function test_swap_deadlineExpired() public {
        selector.set(30, false);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IT2TRouter.DeadlineExpired.selector, block.timestamp - 1));
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp - 1);
    }

    function test_swap_zeroAmountReverts() public {
        selector.set(30, false);
        vm.prank(bob);
        vm.expectRevert(IT2TRouter.ZeroAmount.selector);
        router.swap(poolId, true, 0, 0, bob, block.timestamp + 100);
    }

    function test_swap_slippageExceeded() public {
        selector.set(30, false);
        vm.prank(bob);
        vm.expectRevert();
        router.swap(poolId, true, 1000e18, 1000e18, bob, block.timestamp + 100);
    }

    function test_swap_allowanceReset() public {
        selector.set(30, false);
        vm.prank(bob);
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100);
        assertEq(token0.allowance(address(router), address(pm)), 0);
    }

    function test_swap_payerIsUser() public {
        selector.set(30, false);
        vm.prank(bob);
        vm.expectEmit(true, true, true, false);
        emit IPoolManager.Swap(poolId, bob, true, 1000e18, 0, 0, 0, 0);
        // Non verifichiamo i valori (dipendono dal calcolo), solo payer = bob
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100);
    }

    // ───────────── Remove Liquidity ─────────────

    function test_removeLiquidity_ownerOnly() public {
        uint256 aliceLP = pm.getLPBalance(poolId, alice);
        // Bob prova a rimuovere le LP di alice -> pm.removeLiquidity(owner=alice, ...) 
        // ma msg.sender al PM è il router, che passa owner=alice
        // Il PM verifica lpBalances[poolId][alice] >= lpAmount, che è vero.
        // MA bob non dovrebbe poterlo fare! Il Router passa owner=msg.sender (bob),
        // non alice. Quindi il PM cerca le LP di bob (0) -> InsufficientLiquidity
        vm.prank(bob);
        vm.expectRevert(IPoolManager.InsufficientLiquidity.selector);
        router.removeLiquidity(poolId, aliceLP, bob);
    }

    function test_removeLiquidity_partial() public {
        uint256 aliceLP = pm.getLPBalance(poolId, alice);
        vm.prank(alice);
        (uint256 a0, uint256 a1) = router.removeLiquidity(poolId, aliceLP / 2, alice);
        assertGt(a0, 0);
        assertGt(a1, 0);
        assertEq(pm.getLPBalance(poolId, alice), aliceLP - aliceLP / 2);
    }

    function test_removeLiquidity_zeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(IT2TRouter.ZeroAmount.selector);
        router.removeLiquidity(poolId, 0, alice);
    }

    // ───────────── Reentrancy ─────────────

    function test_swap_reentrancyBlocked() public {
        // Token che tenta reentrancy
        ReentrantToken rt = new ReentrantToken("RT", "RT");
        (address t0, address t1) = address(rt) < address(token0)
            ? (address(rt), address(token0))
            : (address(token0), address(rt));
        bytes32 rid = keccak256(abi.encode(t0, t1, address(curve)));
        vm.prank(owner);
        registry.registerPool(rid, address(curve), t0, t1);
        vm.prank(owner);
        registry.activatePool(rid);

        rt.mint(alice, 10_000_000e18);
        MockERC20(t1).mint(alice, 10_000_000e18);
        vm.prank(alice);
        rt.approve(address(router), type(uint256).max);
        vm.prank(alice);
        MockERC20(t1).approve(address(router), type(uint256).max);

        vm.prank(alice);
        router.addLiquidity(rid, 1_000_000e18, 1_000_000e18);

        rt.setTarget(router, rid);
        rt.attack();

        // Il Router ha nonReentrant: la reentrancy deve revertire
        selector.set(30, false);
        vm.prank(alice);
        vm.expectRevert();
        router.swap(rid, true, 1000e18, 0, alice, block.timestamp + 100);
    }

    // ───────────── Fuzz ─────────────

    function testFuzz_swap_bobAlwaysPaysAmountIn(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e6, 100_000e18);
        selector.set(30, false);
        uint256 bobBefore = token0.balanceOf(bob);
        vm.prank(bob);
        router.swap(poolId, true, amountIn, 0, bob, block.timestamp + 100);
        uint256 bobAfter = token0.balanceOf(bob);
        // Bob ha pagato amountIn esatto
        assertEq(bobBefore - bobAfter, amountIn);
    }
}
