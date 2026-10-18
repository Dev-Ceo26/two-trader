// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ProportionalMath} from "../../contracts/sle/libraries/ProportionalMath.sol";

/// @dev Harness per esporre la funzione internal come external
contract Harness {
    function check(
        uint256 a0, uint256 r0, uint256 a1, uint256 r1
    ) external pure returns (bool) {
        return ProportionalMath.proportionalEnough(a0, r0, a1, r1);
    }
}

contract ProportionalMathTest is Test {
    Harness internal h;

    function setUp() public { h = new Harness(); }

    // ───────────── Uguaglianza esatta ─────────────

    function test_exactEqual() public view {
        assertTrue(h.check(500, 500, 500, 500));
    }

    function test_exactEqualLarge() public view {
        assertTrue(h.check(1e24, 1e24, 1e24, 1e24));
    }

    function test_bothProportional() public view {
        // 1/2 == 1000/2000
        assertTrue(h.check(1, 2, 1000, 2000));
    }

    // ───────────── Appena dentro tolleranza (1 bps) ─────────────

    function test_justWithinTolerance_exact1bps() public view {
        // max = 10000*10000 = 1e8, diff = 10000*1 = 10000
        // diff/max = 10000/1e8 = 1e-4 = 1 bps esatto -> accettato
        assertTrue(h.check(10000, 10000, 9999, 10000));
    }

    function test_justWithinTolerance_below1bps() public view {
        // max = 1e6 * 1e6 = 1e12, diff = 1e6 * 100 = 1e8
        // diff/max = 1e8 / 1e12 = 1e-4 = 1 bps esatto
        assertTrue(h.check(1_000_000, 1_000_000, 999_900, 1_000_000));
    }

    // ───────────── Appena fuori tolleranza ─────────────

    function test_justOverTolerance() public view {
        // max = 1e6 * 1e6 = 1e12, diff = 1e6 * 101 = 1.01e8
        // diff/max > 1 bps -> rifiutato
        assertFalse(h.check(1_000_000, 1_000_000, 999_899, 1_000_000));
    }

    function test_clearlyOverTolerance() public view {
        // 1000/1000 vs 500/1000 -> 50% differenza
        assertFalse(h.check(1000, 1000, 500, 1000));
    }

    // ───────────── Casi limite zero ─────────────

    function test_zeroAmounts() public view {
        assertTrue(h.check(0, 1000, 0, 1000));
    }

    function test_zeroVsSmall() public view {
        // p0 = 0, p1 = 1 -> diff=1, max=1, floor(1/10000)=0, 1<=0? NO
        assertFalse(h.check(0, 1000, 1, 1000));
    }

    // ───────────── Prodotti oltre 2^256 (512-bit limb alto non nullo) ─────────────

    function test_bothProductOverflow512_equal() public view {
        // p0 = 2^200 * 2^200 = 2^400, p1 = 2^200 * 2^200 = 2^400
        uint256 big = 1 << 200;
        assertTrue(h.check(big, big, big, big));
    }

    function test_bothProductOverflow512_withinTolerance() public view {
        // amount0 = 2^130, reserve1 = 2^130 -> p0 = 2^260 (limb alto non nullo)
        // amount1 = 2^130 - 2^86 (approssimativamente 2^44 volte più piccolo)
        // -> diff significativa ma entro tolleranza? No, 2^44 volte è enorme
        // Meglio: differenza relativa piccola
        uint256 a = 1 << 130;
        uint256 b = 1 << 130;
        // p0 = a*a, p1 = a*(a-1) = a^2 - a
        // diff = a, max = a^2, diff/max = 1/a = 1/2^130 << 1 bps
        assertTrue(h.check(a, b, a - 1, b));
    }

    function test_bothProductOverflow512_overTolerance() public view {
        // p0 = a^2, p1 = (a/2)^2 = a^2/4 -> diff = 3a^2/4, max = a^2
        // diff/max = 3/4 = 7500 bps >> 1 bps
        uint256 a = 1 << 130;
        uint256 half = a / 2;
        assertFalse(h.check(a, a, half, a));
    }

    // ───────────── Valori vicini a type(uint256).max ─────────────

    function test_maxValues_equal() public view {
        uint256 m = type(uint256).max;
        assertTrue(h.check(m, m, m, m));
    }

    function test_maxValues_smallDiff() public view {
        uint256 m = type(uint256).max;
        // p0 = m*m, p1 = m*(m-1) = m^2 - m, diff = m, max = m^2
        // floor(m^2 / 10000) >> m (per m grande)
        // quindi diff/max = 1/m << 1 bps -> OK
        assertTrue(h.check(m, m, m - 1, m));
    }

    function test_maxValues_diffOnBothLimb() public view {
        uint256 m = type(uint256).max;
        // p0 = m*m, p1 = (m/2)*(m/2) -> diff enorme
        assertFalse(h.check(m, m, m / 2, m));
    }

    // ───────────── Prodotti con limb alto e differenze significative ─────────────

    function test_highLimbDiff() public view {
        // p0 = 2^255 * 2^255 = 2^510 (limb alto 2^254)
        // p1 = 0 * qualcosa = 0
        // diff = 2^510, max = 2^510, diff/max = 1 = 10000 bps >> 1 bps
        uint256 big = 1 << 255;
        assertFalse(h.check(big, big, 0, big));
    }

    // ───────────── Fuzz ─────────────

    function testFuzz_proportionalToItself(
        uint256 a0, uint256 r0, uint256 a1, uint256 r1
    ) public view {
        // Un rapporto è sempre proporzionale a se stesso
        assertTrue(h.check(a0, r0, a0, r0));
    }

    function testFuzz_symmetry(
        uint256 a0, uint256 r0, uint256 a1, uint256 r1
    ) public view {
        // La simmetria è garantita: check(a0,r0,a1,r1) == check(a1,r1,a0,r0)
        assertEq(h.check(a0, r0, a1, r1), h.check(a1, r1, a0, r0));
    }

    function testFuzz_toleranceBoundary(
        uint256 maxProd, uint256 diffBps
    ) public view {
        // Costruiamo casi controllati su prodotti piccoli per testare il boundary
        maxProd = bound(maxProd, 10_000, 1e18);
        diffBps = bound(diffBps, 0, 100); // 0-1%

        uint256 diff = (maxProd * diffBps) / 10_000;
        uint256 minProd = maxProd - diff;

        // a0*r1 = maxProd, a1*r0 = minProd
        // Scegliamo a0=maxProd, r1=1, a1=minProd, r0=1 (prodotti esatti)
        bool result = h.check(maxProd, 1, minProd, 1);

        if (diffBps <= 1) {
            assertTrue(result, "should accept within 1 bps");
        } else if (diffBps >= 2) {
            assertFalse(result, "should reject over 1 bps");
        }
    }

    function testFuzz_neverReverts(
        uint256 a0, uint256 r0, uint256 a1, uint256 r1
    ) public view {
        // La funzione non deve mai revertire, indipendentemente dagli input
        // (a meno di overflow nei loop interni, che non dovrebbero esserci)
        h.check(a0, r0, a1, r1);
    }
}
