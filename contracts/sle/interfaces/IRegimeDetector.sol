// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRegimeDetector
/// @notice Interfaccia per il rilevatore di regime di mercato.
/// @dev In v1 il detector è deterministico e on-chain. In v2 le sentinelle
///      potranno proporre uno stato ma il contratto verificherà.
interface IRegimeDetector {
    /// @notice Ritorna il regime corrente per un pool
    /// @return regime 0=CALM, 1=VOLATILE, 4=CRITICAL
    /// @return lastUpdatedBlock Blocco dell'ultimo aggiornamento valido
    /// @return isValid True se lo stato è fresco e valido
    function getMarketState(bytes32 poolId)
        external
        view
        returns (uint8 regime, uint256 lastUpdatedBlock, bool isValid);
}
