// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {RegimeDetector} from "../../contracts/sle/core/RegimeDetector.sol";

contract RegimeDetectorTest is Test {
    RegimeDetector internal detector;
    address internal owner = address(0xA11CE);
    bytes32 internal constant POOL = keccak256("pool");

    uint8 internal constant CALM = 0;
    uint8 internal constant VOLATILE = 1;
    uint8 internal constant CRITICAL = 4;

    uint256 internal constant R0 = 1_000_000e18;
    uint256 internal constant R1 = 1_000_000e18;

    function setUp() public {
        detector = new RegimeDetector(owner);
        // Prima osservazione: inizializza
        detector.update(POOL, R0, R1, 1000e18);
    }

    // ───────────── Init ─────────────

    function test_initialState_calm() public view {
        (uint8 regime, uint256 lastBlock, bool valid) = detector.getMarketState(POOL);
        assertEq(regime, CALM);
        assertEq(lastBlock, block.number);
        assertTrue(valid);
    }

    function test_neverUpdated_isInvalid() public view {
        bytes32 unknown = keccak256("unknown");
        (uint8 regime, uint256 lastBlock, bool valid) = detector.getMarketState(unknown);
        assertEq(regime, CRITICAL);
        assertEq(lastBlock, 0);
        assertFalse(valid);
    }

    function test_update_zeroReservesReverts() public {
        vm.expectRevert(RegimeDetector.ZeroReserves.selector);
        detector.update(POOL, 0, R1, 0);
    }

    // ───────────── Staleness ─────────────

    function test_stale_becomesInvalid() public {
        vm.roll(block.number + 101); // oltre detectorStalenessBlocks (100)
        (uint8 regime, , bool valid) = detector.getMarketState(POOL);
        assertEq(regime, CRITICAL);
        assertFalse(valid);
    }

    function test_refreshBecomesValidAgain() public {
        vm.roll(block.number + 150);
        detector.update(POOL, R0, R1, 1000e18);
        (, , bool valid) = detector.getMarketState(POOL);
        assertTrue(valid);
    }

    // ───────────── Transizioni ─────────────

    function test_calm_to_volatile_afterStreak() public {
        // 3 osservazioni consecutive con volatilità > 2% (prezzo sale del 3% ogni volta)
        uint256 currentR1 = R1;
        for (uint256 i = 0; i < 3; i++) {
            currentR1 = (currentR1 * 103) / 100;
            vm.roll(block.number + 1);
            detector.update(POOL, R0, currentR1, 1000e18);
        }
        (uint8 regime, , ) = detector.getMarketState(POOL);
        assertEq(regime, VOLATILE);
    }

    function test_calm_does_not_jump_to_volatile_immediately() public {
        uint256 newR1 = (R1 * 103) / 100;
        vm.roll(block.number + 1);
        detector.update(POOL, R0, newR1, 1000e18);
        // Solo 1 osservazione: ancora CALM
        (uint8 regime, , ) = detector.getMarketState(POOL);
        assertEq(regime, CALM);
    }

    function test_volatile_to_calm_afterLongStreak() public {
        // Porta a VOLATILE
        uint256 newR1 = (R1 * 103) / 100;
        for (uint256 i = 0; i < 3; i++) {
            vm.roll(block.number + 1);
            detector.update(POOL, R0, newR1, 1000e18);
        }
        // Ora torna a stabilità (stesso prezzo)
        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1);
            detector.update(POOL, R0, newR1, 1000e18);
        }
        (uint8 regime, , ) = detector.getMarketState(POOL);
        assertEq(regime, CALM);
    }

    function test_volatile_to_critical_immediate() public {
        // Porta a VOLATILE
        uint256 newR1 = (R1 * 103) / 100;
        for (uint256 i = 0; i < 3; i++) {
            vm.roll(block.number + 1);
            detector.update(POOL, R0, newR1, 1000e18);
        }

        // Dump 15% con volume anomalo (10x)
        uint256 dumpR1 = (newR1 * 85) / 100;
        vm.roll(block.number + 1);
        detector.update(POOL, R0, dumpR1, 10_000e18);

        (uint8 regime, , ) = detector.getMarketState(POOL);
        assertEq(regime, CRITICAL);
    }

    // ───────────── Parametri ─────────────

    function test_setParameters_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        detector.setParameters(50, 150, 800, 2, 50);
    }

    function test_setParameters_invalidRangeReverts() public {
        vm.prank(owner);
        vm.expectRevert(RegimeDetector.InvalidParameter.selector);
        detector.setParameters(200, 100, 1000, 3, 100); // volLow >= volHigh
    }

    function test_setParameters_valid() public {
        vm.prank(owner);
        detector.setParameters(50, 150, 800, 2, 50);
        assertEq(detector.volatilityThresholdLow(), 50);
        assertEq(detector.volatilityThresholdHigh(), 150);
        assertEq(detector.criticalDumpThreshold(), 800);
        assertEq(detector.criticalVolumeMultiplier(), 2);
        assertEq(detector.detectorStalenessBlocks(), 50);
    }

    // ───────────── Fuzz ─────────────

    function testFuzz_getMarketState_alwaysValidOrCritical(uint256 blocksElapsed) public {
        blocksElapsed = bound(blocksElapsed, 0, 1000);
        vm.roll(block.number + blocksElapsed);
        (uint8 regime, , bool valid) = detector.getMarketState(POOL);
        if (!valid) {
            assertEq(regime, CRITICAL, "invalid must be CRITICAL (fail-closed)");
        }
    }
}
