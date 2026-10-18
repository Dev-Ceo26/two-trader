// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ICurve
/// @notice Interfaccia per una curva AMM. Ogni curva implementa una formula
///         matematica di swap. In v1 l'unica curva ammessa è ConstantProductCurve.
/// @dev La curva è associata a un pool una sola volta, dopo activatePool()
///      non è più modificabile. La whitelist è gestita dal PoolRegistry.
interface ICurve {
    /// @notice Calcola l'output per un dato input, date le riserve
    /// @param amountIn Importo in ingresso (già al netto della fee)
    /// @param reserveIn Riserva del token in ingresso (PRIMA dello swap)
    /// @param reserveOut Riserva del token in uscita (PRIMA dello swap)
    /// @return amountOut Importo in uscita
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    /// @notice Calcola l'input necessario per un dato output
    /// @param amountOut Importo in uscita desiderato
    /// @param reserveIn Riserva del token in ingresso (PRIMA dello swap)
    /// @param reserveOut Riserva del token in uscita (PRIMA dello swap)
    /// @return amountIn Importo in ingresso necessario (lordo di fee)
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    /// @notice Nome human-readable della curva (es. "ConstantProduct")
    function name() external pure returns (string memory);
}
