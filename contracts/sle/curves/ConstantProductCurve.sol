// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ICurve} from "../interfaces/ICurve.sol";

/// @title ConstantProductCurve
/// @notice Curva AMM x·y=k. Implementazione originale, non derivata da Uniswap.
/// @dev Funzioni pure. La fee è applicata dal PoolManager PRIMA di chiamare
///      getAmountOut: qui amountIn è già al netto della fee.
///      Arrotondamenti:
///        - getAmountOut: floor (a favore del pool)
///        - getAmountIn:  ceil  (a favore del pool)
contract ConstantProductCurve is ICurve {
    // ───────────── Errors ─────────────
    error ZeroAmount();
    error InvalidReserves();
    error InsufficientLiquidity();
    error OutputExceedsReserve();

    /// @inheritdoc ICurve
    /// @dev Formula: dy = (y * dx) / (x + dx), arrotondamento floor
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure override returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();

        // amountOut = floor(reserveOut * amountIn / (reserveIn + amountIn))
        amountOut = Math.mulDiv(reserveOut, amountIn, reserveIn + amountIn);

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut >= reserveOut) revert OutputExceedsReserve();
    }

    /// @inheritdoc ICurve
    /// @dev Formula: dx = ceil(x * dy / (y - dy)), arrotondamento ceil
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure override returns (uint256 amountIn) {
        if (amountOut == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        if (amountOut >= reserveOut) revert OutputExceedsReserve();

        // amountIn = ceil(reserveIn * amountOut / (reserveOut - amountOut))
        amountIn = Math.mulDiv(
            reserveIn,
            amountOut,
            reserveOut - amountOut,
            Math.Rounding.Ceil
        );
    }

    /// @inheritdoc ICurve
    function name() external pure override returns (string memory) {
        return "ConstantProduct";
    }
}
