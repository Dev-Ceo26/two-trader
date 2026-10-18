// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StrategySelector} from "../../contracts/sle/core/StrategySelector.sol";
import {CalmStrategy} from "../../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../../contracts/sle/strategies/CriticalStrategy.sol";
import {IStrategy} from "../../contracts/sle/interfaces/IStrategy.sol";
import {IRegimeDetector} from "../../contracts/sle/interfaces/IRegimeDetector.sol";

// ───────────── Mocks ─────────────

contract MockDetector is IRegimeDetector {
    uint8 public regimeValue;
    uint256 public lastBlock;
    bool public validValue;
    bool public shouldRevert;

    function set(uint8 _regime, uint256 _lastBlock, bool _valid, bool _shouldRevert) external {
        regimeValue = _regime;
        lastBlock = _lastBlock;
        validValue = _valid;
        shouldRevert = _shouldRevert;
    }

    function getMarketState(bytes32) external view override returns (uint8, uint256, bool) {
        if (shouldRevert) revert("detector revert");
        return (regimeValue, lastBlock, validValue);
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

contract RevertingBlockStrategy is IStrategy {
    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        return 50;
    }
    function shouldBlock(bytes32, uint8, uint256, uint256) external pure override returns (bool) {
        revert("revert shouldBlock");
    }
    function name() external pure override returns (string memory) { return "RevertingBlock"; }
    function targetRegime() external pure override returns (uint8) { return 0; }
}

contract HighFeeStrategy is IStrategy {
    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        return 999; // oltre MAX_FEE
    }
    function shouldBlock(bytes32, uint8, uint256, uint256) external pure override returns (bool) {
        return false;
    }
    function name() external pure override returns (string memory) { return "HighFee"; }
    function targetRegime() external pure override returns (uint8) { return 0; }
}

// ───────────── Test ─────────────

contract StrategySelectorTest is Test {
    StrategySelector internal selector;
    MockDetector internal detector;
    CalmStrategy internal calm;
    VolatileStrategy internal volatileStrat;
    CriticalStrategy internal critical;

    address internal owner = address(0xA11CE);
    address internal attacker = address(0xBAD);
    bytes32 internal constant POOL = keccak256("pool");

    uint8 internal constant CALM = 0;
    uint8 internal constant VOLATILE = 1;
    uint8 internal constant CRITICAL = 4;

    function setUp() public {
        detector = new MockDetector();
        selector = new StrategySelector(address(detector), owner);

        calm = new CalmStrategy();
        volatileStrat = new VolatileStrategy();
        critical = new CriticalStrategy();

        vm.startPrank(owner);
        selector.setStrategy(CALM, address(calm));
        selector.setStrategy(VOLATILE, address(volatileStrat));
        selector.setStrategy(CRITICAL, address(critical));
        vm.stopPrank();
    }

    // ───────────── setStrategy ─────────────

    function test_setStrategy_onlyOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        selector.setStrategy(CALM, address(0x1));
    }

    function test_setStrategy_invalidRegimeReverts() public {
        vm.prank(owner);
        vm.expectRevert(StrategySelector.InvalidRegime.selector);
        selector.setStrategy(2, address(0x1)); // TRENDING_UP non supportato in v1
    }

    function test_setStrategy_zeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(StrategySelector.ZeroAddress.selector);
        selector.setStrategy(CALM, address(0));
    }

    // ───────────── Happy path ─────────────

    function test_calm_returnsCalmFee() public {
        detector.set(CALM, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 5);
        assertFalse(blocked);
    }

    function test_volatile_returnsVolatileFee() public {
        detector.set(VOLATILE, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 50);
        assertFalse(blocked);
    }

    function test_critical_returnsCriticalFee_noBlock() public {
        detector.set(CRITICAL, block.number, true, false);
        // Sotto soglia (reserveIn/100): non blocca
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 150);
        assertFalse(blocked);
    }

    function test_critical_blocksLargeSwap() public {
        detector.set(CRITICAL, block.number, true, false);
        // Sopra soglia: blocca
        uint256 reserveIn = 1_000_000e18;
        uint256 largeAmount = (reserveIn / 100) + 1;
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, largeAmount, reserveIn);
        assertEq(fee, 150);
        assertTrue(blocked);
    }

    // ───────────── Fail-closed ─────────────

    function test_detectorReverts_failClosed() public {
        detector.set(CALM, block.number, true, true); // shouldRevert = true
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    function test_detectorStale_failClosed() public {
        detector.set(CALM, block.number, false, false); // isValid = false
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    function test_criticalRevertingStrategy_failClosed() public {
        RevertingStrategy bad = new RevertingStrategy();
        vm.prank(owner);
        selector.setStrategy(CRITICAL, address(bad));

        detector.set(CRITICAL, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    function test_criticalNoStrategy_failClosed() public {
        vm.prank(owner);
        selector.unregisterStrategy(CRITICAL);

        detector.set(CRITICAL, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    function test_criticalShouldBlockReverts_failClosed() public {
        RevertingBlockStrategy bad = new RevertingBlockStrategy();
        vm.prank(owner);
        selector.setStrategy(CRITICAL, address(bad));

        detector.set(CRITICAL, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, 0);
        assertTrue(blocked);
    }

    // ───────────── Fail-open ─────────────

    function test_calmRevertingStrategy_defaultFee() public {
        RevertingStrategy bad = new RevertingStrategy();
        vm.prank(owner);
        selector.setStrategy(CALM, address(bad));

        detector.set(CALM, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, selector.DEFAULT_FEE());
        assertFalse(blocked);
    }

    function test_calmNoStrategy_defaultFee() public {
        vm.prank(owner);
        selector.unregisterStrategy(CALM);

        detector.set(CALM, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, selector.DEFAULT_FEE());
        assertFalse(blocked);
    }

    function test_volatileShouldBlockReverts_defaultFee() public {
        RevertingBlockStrategy bad = new RevertingBlockStrategy();
        vm.prank(owner);
        selector.setStrategy(VOLATILE, address(bad));

        detector.set(VOLATILE, block.number, true, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, selector.DEFAULT_FEE());
        assertFalse(blocked);
    }

    // ───────────── Fee clamp ─────────────

    function test_highFeeStrategy_clampedToMaxFee() public {
        HighFeeStrategy high = new HighFeeStrategy();
        vm.prank(owner);
        selector.setStrategy(CALM, address(high));

        detector.set(CALM, block.number, true, false);
        (uint256 fee, ) = selector.selectForSwap(POOL, 1000e18, 1_000_000e18);
        assertEq(fee, selector.MAX_FEE());
    }

    // ───────────── Fuzz ─────────────

    function testFuzz_alwaysReturnsValidFee(uint8 regime, uint256 amountIn, uint256 reserveIn, bool isValid) public {
        regime = uint8(bound(regime, 0, 4));
        amountIn = bound(amountIn, 1, 1_000_000e18);
        reserveIn = bound(reserveIn, 1, 1_000_000e18);

        detector.set(regime, block.number, isValid, false);
        (uint256 fee, bool blocked) = selector.selectForSwap(POOL, amountIn, reserveIn);

        // La fee deve sempre essere <= MAX_FEE, indipendentemente da blocked
        // (fail-closed -> fee 0; CriticalStrategy con blocco -> fee 150)
        assertLe(fee, selector.MAX_FEE(), "fee must be <= MAX_FEE");

        // Se il detector era invalido, blocked DEVE essere true (fail-closed)
        if (!isValid) {
            assertTrue(blocked, "invalid detector must fail-close");
        }
    }
}
