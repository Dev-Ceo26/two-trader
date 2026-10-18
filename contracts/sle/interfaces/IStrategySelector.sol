// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IStrategySelector
/// @notice Interfaccia del decisore SLE. Dato un pool e un input, restituisce
///         la fee da applicare e se lo swap deve essere bloccato.
/// @dev View: non scrive storage. Il Router è l'unico chiamante autorizzato
///      (il PoolManager verificherà msg.sender).
interface IStrategySelector {
    /// @notice Seleziona fee e decisione di blocco per uno swap
    /// @param poolId ID del pool
    /// @param amountIn Importo in ingresso
    /// @param reserveIn Riserva del token in ingresso
    /// @return feeBps Fee in basis points (0 se blocked)
    /// @return shouldBlock True se lo swap deve essere bloccato
    function selectForSwap(
        bytes32 poolId,
        uint256 amountIn,
        uint256 reserveIn
    ) external view returns (uint256 feeBps, bool shouldBlock);
}
