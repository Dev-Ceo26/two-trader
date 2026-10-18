// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "../../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../../contracts/sle/core/PoolRegistry.sol";
import {T2TRouter} from "../../contracts/sle/core/T2TRouter.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {StrategySelector} from "../../contracts/sle/core/StrategySelector.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";
import {CalmStrategy} from "../../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../../contracts/sle/strategies/CriticalStrategy.sol";
import {IRegimeDetector} from "../../contracts/sle/interfaces/IRegimeDetector.sol";
import {IPoolManager} from "../../contracts/sle/interfaces/IPoolManager.sol";
import {IT2TRouter} from "../../contracts/sle/interfaces/IT2TRouter.sol";
import {IStrategy} from "../../contracts/sle/interfaces/IStrategy.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @dev Detector configurabile: regime, valid, revert
contract MockRegimeDetector is IRegimeDetector {
    uint8 public regime;
    uint256 public lastBlock;
    bool public valid;
    bool public revertOnGet;

    function set(uint8 _regime, uint256 _lastBlock, bool _valid, bool _revert) external {
        regime = _regime;
        lastBlock = _lastBlock;
        valid = _valid;
        revertOnGet = _revert;
    }

    function getMarketState(bytes32) external view override returns (uint8, uint256, bool) {
        if (revertOnGet) revert("detector revert");
        return (regime, lastBlock, valid);
    }
}

contract RevertingStrategy is IStrategy {
    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        revert("revert proposeFee");
    }
    function shouldBlock(bytes32, uint8, uint256, uint256) external pure override returns (bool) {
        return false;
    }
    function name() external pure override returns (string memory) { return "Reverting"; }
    function targetRegime() external pure override returns (uint8) { return 0; }
}

contract EndToEndFailClosedTest is Test {
    T2TRouter internal router;
    PoolManager internal pm;
    PoolRegistry internal registry;
    SLEAddressProvider internal provider;
    StrategySelector internal selector;
    MockRegimeDetector internal detector;
    ConstantProductCurve internal curve;

    CalmStrategy internal calm;
    VolatileStrategy internal volatileS;
    CriticalStrategy internal critical;
    RevertingStrategy internal reverting;

    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);

    bytes32 internal poolId;

    uint256 internal constant INIT0 = 1_000_000e18;
    uint256 internal constant INIT1 = 1_000_000e18;

    uint8 internal constant CALM = 0;
    uint8 internal constant VOLATILE = 1;
    uint8 internal constant CRITICAL = 4;

    function setUp() public {
        curve = new ConstantProductCurve();
        registry = new PoolRegistry(owner);
        detector = new MockRegimeDetector();
        selector = new StrategySelector(address(detector), owner);

        // Strategie
        calm = new CalmStrategy();
        volatileS = new VolatileStrategy();
        critical = new CriticalStrategy();
        reverting = new RevertingStrategy();

        vm.startPrank(owner);
        selector.setStrategy(CALM, address(calm));
        selector.setStrategy(VOLATILE, address(volatileS));
        selector.setStrategy(CRITICAL, address(critical));
        vm.stopPrank();

        // Provider + PM + Router
        provider = new SLEAddressProvider(owner);
        pm = new PoolManager(address(registry), address(provider));
        router = new T2TRouter(address(provider), address(selector), address(registry));
        vm.prank(owner);
        provider.setEndpoints(address(router), address(pm));

        // Token
        token0 = new MockERC20("Token0", "T0");
        token1 = new MockERC20("Token1", "T1");
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);

        poolId = keccak256(abi.encode(address(token0), address(token1), address(curve)));

        vm.startPrank(owner);
        registry.whitelistCurve(address(curve), true);
        registry.registerPool(poolId, address(curve), address(token0), address(token1));
        registry.activatePool(poolId);
        vm.stopPrank();

        // Fondi
        token0.mint(alice, 10_000_000e18);
        token1.mint(alice, 10_000_000e18);
        vm.prank(alice);
        token0.approve(address(router), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(router), type(uint256).max);

        // Liquidità iniziale
        vm.prank(alice);
        router.addLiquidity(poolId, INIT0, INIT1);
    }

    // ───────────── Helpers ─────────────

    function _doSwap(uint256 amountIn) internal returns (uint256 out) {
        vm.prank(alice);
        out = router.swap(poolId, true, amountIn, 0, alice, block.timestamp + 100);
    }

    function _expectSwapBlocked() internal {
        _expectSwapBlockedWith(1000e18);
    }

    function _expectSwapBlockedWith(uint256 amountIn) internal {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IT2TRouter.BlockedByStrategy.selector, poolId));
        router.swap(poolId, true, amountIn, 0, alice, block.timestamp + 100);
    }

    // ───────────── Fail-closed: detector invalido/stale/revert ─────────────

    function test_detectorNeverUpdated_blocksSwap() public {
        detector.set(CALM, 0, false, false); // mai aggiornato
        _expectSwapBlocked();
    }

    function test_detectorStale_blocksSwap() public {
        vm.roll(200);
        detector.set(CALM, 50, false, false); // 200 - 50 = 150 > 100 -> stale
        _expectSwapBlocked();
    }

    function test_detectorRevert_blocksSwap() public {
        detector.set(CALM, block.number, true, true); // revert
        _expectSwapBlocked();
    }

    // ───────────── Fail-closed: CRITICAL + strategia KO ─────────────

    function test_criticalStrategyReverts_blocksSwap() public {
        // Sostituisci la strategia CRITICAL con una che reverte
        vm.prank(owner);
        selector.setStrategy(CRITICAL, address(reverting));

        detector.set(CRITICAL, block.number, true, false);
        _expectSwapBlocked();
    }

    function test_criticalNoStrategy_blocksSwap() public {
        vm.prank(owner);
        selector.unregisterStrategy(CRITICAL);

        detector.set(CRITICAL, block.number, true, false);
        _expectSwapBlocked();
    }

    // ───────────── Fail-closed: CRITICAL + strategia OK + swap grande ─────────────

    function test_criticalLargeSwap_blocks() public {
        detector.set(CRITICAL, block.number, true, false);
        // Soglia = reserveIn/100. ReserveIn iniziale = 1M -> soglia 10_000e18
        uint256 largeAmount = 20_000e18;
        _expectSwapBlockedWith(largeAmount);
    }

    // ───────────── Fail-open: CALM/VOLATILE + strategia KO -> DEFAULT_FEE ─────────────

    function test_calmStrategyReverts_usesDefaultFee() public {
        vm.prank(owner);
        selector.setStrategy(CALM, address(reverting));

        detector.set(CALM, block.number, true, false);

        // Deve passare con DEFAULT_FEE = 30 bps (non bloccare)
        uint256 out = _doSwap(1000e18);
        assertGt(out, 0);
    }

    function test_volatileStrategyReverts_usesDefaultFee() public {
        vm.prank(owner);
        selector.setStrategy(VOLATILE, address(reverting));

        detector.set(VOLATILE, block.number, true, false);

        uint256 out = _doSwap(1000e18);
        assertGt(out, 0);
    }

    function test_calmNoStrategy_usesDefaultFee() public {
        vm.prank(owner);
        selector.unregisterStrategy(CALM);
        detector.set(CALM, block.number, true, false);

        uint256 out = _doSwap(1000e18);
        assertGt(out, 0);
    }

    // ───────────── Happy path: fee dalla strategia ─────────────

    function test_calmHappyPath_usesCalmFee() public {
        detector.set(CALM, block.number, true, false);

        // Verifica indirettamente: fee 5 bps -> feeAmount su 1000e18 = 0.5e18
        uint256 aliceToken0Before = token0.balanceOf(alice);
        _doSwap(1000e18);
        uint256 spent = aliceToken0Before - token0.balanceOf(alice);
        assertEq(spent, 1000e18); // Alice spende amountIn lordo
    }

    function test_volatileHappyPath_usesVolatileFee() public {
        detector.set(VOLATILE, block.number, true, false);
        uint256 out = _doSwap(1000e18);
        assertGt(out, 0);
    }

    function test_criticalSmallSwap_allowed() public {
        detector.set(CRITICAL, block.number, true, false);
        // Sotto soglia reserveIn/100 = 10_000e18
        uint256 out = _doSwap(5000e18);
        assertGt(out, 0);
    }

    // ───────────── Verifica fee effettiva ─────────────

    function test_calmFee_actuallyApplied() public {
        detector.set(CALM, block.number, true, false);

        // Calcola feeAmount attesa su 1000e18 con 5 bps: 0.5e18
        (uint256 fee0Before,) = pm.getFeesAccrued(poolId);
        _doSwap(1000e18);
        (uint256 fee0After,) = pm.getFeesAccrued(poolId);
        assertEq(fee0After - fee0Before, 0.5e18, "CALM fee should be 5 bps");
    }

    function test_volatileFee_actuallyApplied() public {
        detector.set(VOLATILE, block.number, true, false);

        (uint256 fee0Before,) = pm.getFeesAccrued(poolId);
        _doSwap(1000e18);
        (uint256 fee0After,) = pm.getFeesAccrued(poolId);
        assertEq(fee0After - fee0Before, 5e18, "VOLATILE fee should be 50 bps");
    }

    function test_criticalFee_actuallyApplied() public {
        detector.set(CRITICAL, block.number, true, false);

        (uint256 fee0Before,) = pm.getFeesAccrued(poolId);
        _doSwap(5000e18); // sotto soglia
        (uint256 fee0After,) = pm.getFeesAccrued(poolId);
        assertEq(fee0After - fee0Before, 75e18, "CRITICAL fee should be 150 bps");
    }

    function test_defaultFee_actuallyApplied() public {
        vm.prank(owner);
        selector.setStrategy(CALM, address(reverting));
        detector.set(CALM, block.number, true, false);

        (uint256 fee0Before,) = pm.getFeesAccrued(poolId);
        _doSwap(1000e18);
        (uint256 fee0After,) = pm.getFeesAccrued(poolId);
        assertEq(fee0After - fee0Before, 3e18, "DEFAULT_FEE should be 30 bps");
    }

    // ───────────── Fuzz: blocked indipendente dall'importo quando detector invalido ─────────────

    function testFuzz_invalidDetector_alwaysBlocked(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 100_000e18);
        detector.set(CALM, 0, false, false);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IT2TRouter.BlockedByStrategy.selector, poolId));
        router.swap(poolId, true, amountIn, 0, alice, block.timestamp + 100);
    }
}
