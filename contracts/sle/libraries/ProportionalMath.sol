// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ProportionalMath
/// @notice Verifica proporzionalità fra due rapporti con confronto cross-multiply
///         a precisione piena 512-bit, senza arrotondamenti intermedi.
/// @dev La condizione verificata è:
///        |a0*r1 - a1*r0| * 10000 <= max(a0*r1, a1*r0)
///      equivalente a:
///        |a0*r1 - a1*r0| <= floor(max(a0*r1, a1*r0) / 10000)
///      dove la divisione è calcolata bit-by-bit su 512/256 bit.
library ProportionalMath {
    uint256 internal constant TOLERANCE_BPS = 1;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice Verifica se due rapporti a0/r0 e a1/r1 sono entro TOLERANCE_BPS
    /// @param amount0 Numeratore del primo rapporto
    /// @param reserve0 Denominatore del primo rapporto
    /// @param amount1 Numeratore del secondo rapporto
    /// @param reserve1 Denominatore del secondo rapporto
    /// @return true se |a0*r1 - a1*r0| * 10000 <= max(a0*r1, a1*r0)
    function proportionalEnough(
        uint256 amount0, uint256 reserve0,
        uint256 amount1, uint256 reserve1
    ) internal pure returns (bool) {
        // P0 = amount0 * reserve1 (512-bit)
        uint256 p0L;
        uint256 p0H;
        assembly {
            let mm := mulmod(amount0, reserve1, not(0))
            p0L := mul(amount0, reserve1)
            p0H := sub(sub(mm, p0L), lt(mm, p0L))
        }

        // P1 = amount1 * reserve0 (512-bit)
        uint256 p1L;
        uint256 p1H;
        assembly {
            let mm := mulmod(amount1, reserve0, not(0))
            p1L := mul(amount1, reserve0)
            p1H := sub(sub(mm, p1L), lt(mm, p1L))
        }

        if (p0H == p1H && p0L == p1L) return true;

        // max / min
        bool p0Greater = p0H > p1H || (p0H == p1H && p0L > p1L);
        uint256 maxH = p0Greater ? p0H : p1H;
        uint256 maxL = p0Greater ? p0L : p1L;
        uint256 minH = p0Greater ? p1H : p0H;
        uint256 minL = p0Greater ? p1L : p0L;

        // diff = max - min (512-bit)
        uint256 diffH;
        uint256 diffL;
        unchecked {
            diffL = maxL - minL;
            diffH = maxH - minH;
            if (maxL < minL) diffH -= 1;
        }

        // floor(max / 10000) via divisione bit-by-bit
        uint256 quotientH = maxH / BPS_DENOMINATOR;
        uint256 remainderH = maxH % BPS_DENOMINATOR;

        uint256 qLow;
        uint256 rem = remainderH;
        for (uint256 i = 256; i > 0; ) {
            unchecked { --i; }
            uint256 bit = (maxL >> i) & 1;
            rem = rem * 2 + bit;
            if (rem >= BPS_DENOMINATOR) {
                rem -= BPS_DENOMINATOR;
                qLow |= uint256(1) << i;
            }
        }

        if (diffH < quotientH) return true;
        if (diffH > quotientH) return false;
        return diffL <= qLow;
    }
}
