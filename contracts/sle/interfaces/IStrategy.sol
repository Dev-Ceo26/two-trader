// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IStrategy
/// @notice Interfaccia per una strategia SLE. Propone fee e decide se
///         bloccare uno swap. NON modifica lo stato del pool, NON trasferisce token.
/// @dev Le fee proposte sono validate dal core (<= MAX_FEE). Il blocco è
///      applicato dal Selector, non dalla strategia stessa.
interface IStrategy {
    /// @notice Fee proposta per un dato stato di mercato (basis points)
    /// @dev DEVE essere <= MAX_FEE. Il core rifiuta fee superiori.
    function proposeFee(
        bytes32 poolId,
        uint8 regime,
        uint256 amountIn
    ) external view returns (uint256 feeBps);

    /// @notice Decide se bloccare uno swap per un dato stato
    /// @dev Se true, il core rifiuta lo swap
    function shouldBlock(
        bytes32 poolId,
        uint8 regime,
        uint256 amountIn,
        uint256 reserveIn
    ) external view returns (bool);

    /// @notice Nome della strategia
    function name() external pure returns (string memory);

    /// @notice Regime per cui la strategia è pensata
    function targetRegime() external pure returns (uint8);
}
