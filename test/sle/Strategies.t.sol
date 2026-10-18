// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CalmStrategy} from "../../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../../contracts/sle/strategies/CriticalStrategy.sol";
import {IStrategy} from "../../contracts/sle/interfaces/IStrategy.sol";

contract StrategiesTest is Test {
    CalmStrategy internal calm;
    VolatileStrategy internal volatile;
    CriticalStrategy internal critical;

    bytes32 internal constant POOL = keccak256("pool");
    uint8 internal constant REGIME_CALM = 0;
    uint8 internal constant REGIME_VOLATILE = 1;
    uint8 internal constant REGIME_CRITICAL = 4;

    function setUp() public {
        calm = new CalmStrategy();
        volatile = new VolatileStrategy();
        critical = new CriticalStrategy();
    }

    // ───────────── CalmStrategy ─────────────

    function test_calm_proposeFee() public view {
        assertEq(calm.proposeFee(POOL, REGIME_CALM, 1000e18), 5);
    }

    function test_calm_neverBlocks() public view {
        assertFalse(calm.shouldBlock(POOL, REGIME_CALM, 1_000_000e18, 100e18));
        assertFalse(calm.shouldBlock(POOL, REGIME_CALM, 1, 1));
    }

    function test_calm_name() public view {
        assertEq(calm.name(), "CalmStrategy");
    }

    function test_calm_targetRegime() public view {
        assertEq(calm.targetRegime(), REGIME_CALM);
    }

    // ───────────── VolatileStrategy ─────────────

    function test_volatile_proposeFee() public view {
        assertEq(volatile.proposeFee(POOL, REGIME_VOLATILE, 1000e18), 50);
    }

    function test_volatile_neverBlocks() public view {
        assertFalse(volatile.shouldBlock(POOL, REGIME_VOLATILE, 1_000_000e18, 100e18));
    }

    function test_volatile_name() public view {
        assertEq(volatile.name(), "VolatileStrategy");
    }

    function test_volatile_targetRegime() public view {
        assertEq(volatile.targetRegime(), REGIME_VOLATILE);
    }

    // ───────────── CriticalStrategy ─────────────

    function test_critical_proposeFee() public view {
        assertEq(critical.proposeFee(POOL, REGIME_CRITICAL, 1000e18), 150);
    }

    function test_critical_blocksLargeSwaps() public view {
        uint256 reserveIn = 1_000_000e18;
        uint256 threshold = reserveIn / 100; // 10_000e18
        // Sopra soglia: blocca
        assertTrue(critical.shouldBlock(POOL, REGIME_CRITICAL, threshold + 1, reserveIn));
        assertTrue(critical.shouldBlock(POOL, REGIME_CRITICAL, threshold * 10, reserveIn));
    }

    function test_critical_allowsSmallSwaps() public view {
        uint256 reserveIn = 1_000_000e18;
        uint256 threshold = reserveIn / 100; // 10_000e18
        // Sotto soglia: permette
        assertFalse(critical.shouldBlock(POOL, REGIME_CRITICAL, threshold - 1, reserveIn));
        assertFalse(critical.shouldBlock(POOL, REGIME_CRITICAL, threshold, reserveIn));
        assertFalse(critical.shouldBlock(POOL, REGIME_CRITICAL, 1e18, reserveIn));
    }

    function test_critical_blocksAllIfPoolEmpty() public view {
        assertTrue(critical.shouldBlock(POOL, REGIME_CRITICAL, 1, 0));
    }

    function test_critical_name() public view {
        assertEq(critical.name(), "CriticalStrategy");
    }

    function test_critical_targetRegime() public view {
        assertEq(critical.targetRegime(), REGIME_CRITICAL);
    }

    // ───────────── Cross-strategy ─────────────

    function test_all_strategiesImplementInterface() public view {
        IStrategy[] memory strategies = new IStrategy[](3);
        strategies[0] = IStrategy(address(calm));
        strategies[1] = IStrategy(address(volatile));
        strategies[2] = IStrategy(address(critical));

        for (uint256 i = 0; i < strategies.length; i++) {
            assertGt(bytes(strategies[i].name()).length, 0);
            assertLe(strategies[i].proposeFee(POOL, 0, 0), 200, "fee must be <= MAX_FEE");
        }
    }

    function testFuzz_allStrategiesFeeRespectMaxFee(uint256 amountIn, uint8 regime) public view {
        assertLe(calm.proposeFee(POOL, regime, amountIn), 200);
        assertLe(volatile.proposeFee(POOL, regime, amountIn), 200);
        assertLe(critical.proposeFee(POOL, regime, amountIn), 200);
    }

    function testFuzz_critical_blockBoundary(uint256 amountIn, uint256 reserveIn) public view {
        amountIn = bound(amountIn, 0, 10_000_000e18);
        reserveIn = bound(reserveIn, 1, 10_000_000e18);

        bool blocked = critical.shouldBlock(POOL, REGIME_CRITICAL, amountIn, reserveIn);
        uint256 threshold = reserveIn / 100;

        if (amountIn > threshold) {
            assertTrue(blocked, "should block above threshold");
        } else {
            assertFalse(blocked, "should not block at or below threshold");
        }
    }
}
