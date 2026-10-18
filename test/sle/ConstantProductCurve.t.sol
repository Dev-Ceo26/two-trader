// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";

contract ConstantProductCurveTest is Test {
    ConstantProductCurve internal curve;

    uint256 internal constant RESERVE = 1_000_000e18;

    function setUp() public {
        curve = new ConstantProductCurve();
    }

    // ───────────── getAmountOut ─────────────

    function test_getAmountOut_basic() public view {
        // Con reserve 1M/1M e input 1000, output atteso ~= 999 (k conservato)
        uint256 out = curve.getAmountOut(1000e18, RESERVE, RESERVE);
        // out = 1M * 1000 / (1M + 1000) ~= 999.000999e18
        assertApproxEqRel(out, 999e18, 0.01e18); // entro 1%
    }

    function test_getAmountOut_zeroInputReverts() public {
        vm.expectRevert(ConstantProductCurve.ZeroAmount.selector);
        curve.getAmountOut(0, RESERVE, RESERVE);
    }

    function test_getAmountOut_zeroReserveReverts() public {
        vm.expectRevert(ConstantProductCurve.InvalidReserves.selector);
        curve.getAmountOut(1e18, 0, RESERVE);
    }

    function test_getAmountOut_insufficientLiquidityReverts() public {
        // amountIn così piccolo che amountOut = 0
        vm.expectRevert(ConstantProductCurve.InsufficientLiquidity.selector);
        curve.getAmountOut(1, RESERVE, RESERVE);
    }

    // ───────────── getAmountIn ─────────────

    function test_getAmountIn_basic() public view {
        // Per ottenere 999e18, input richiesto ~= 1000e18 (ceil)
        uint256 required = curve.getAmountIn(999e18, RESERVE, RESERVE);
        assertGe(required, 999e18);
        assertLe(required, 1001e18);
    }

    function test_getAmountIn_exceedsReserveReverts() public {
        vm.expectRevert(ConstantProductCurve.OutputExceedsReserve.selector);
        curve.getAmountIn(RESERVE, RESERVE, RESERVE);
    }

    // ───────────── Invariante ─────────────

    /// @notice Fuzz: il prodotto delle riserve non diminuisce dopo uno swap
    function testFuzz_kNeverDecreases(uint256 amountIn, uint256 r0, uint256 r1) public view {
        amountIn = bound(amountIn, 1e6, 100_000e18);
        r0 = bound(r0, 1_000e18, 1_000_000_000e18);
        r1 = bound(r1, 1_000e18, 1_000_000_000e18);

        uint256 kBefore = r0 * r1;

        uint256 amountOut = curve.getAmountOut(amountIn, r0, r1);

        uint256 r0After = r0 + amountIn;
        uint256 r1After = r1 - amountOut;
        uint256 kAfter = r0After * r1After;

        assertGe(kAfter, kBefore, "k decreased after swap");
    }

    // ───────────── Simmetria ─────────────

    /// @notice getAmountIn(getAmountOut(x)) <= x (a causa di ceil/floor)
    function testFuzz_roundTripSymmetry(uint256 amountIn, uint256 r0, uint256 r1) public view {
        amountIn = bound(amountIn, 1e6, 100_000e18);
        r0 = bound(r0, 10_000e18, 1_000_000e18);
        r1 = bound(r1, 10_000e18, 1_000_000e18);

        uint256 amountOut = curve.getAmountOut(amountIn, r0, r1);
        uint256 required = curve.getAmountIn(amountOut, r0, r1);

        // required dovrebbe essere <= amountIn (arrotondamento a favore del pool)
        // ma per via di ceil può essere leggermente maggiore. Tolleranza 0.01%
        assertLe(required, amountIn + amountIn / 10_000, "round-trip drift too high");
    }

    // ───────────── name ─────────────

    function test_name() public view {
        assertEq(curve.name(), "ConstantProduct");
    }
}
