// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ISLEAddressProvider
/// @notice Interfaccia del provider di indirizzi SLE. Configurazione one-shot
///         e irreversibile di router e poolManager.
interface ISLEAddressProvider {
    event EndpointsSet(address indexed router, address indexed poolManager);

    error AlreadyConfigured();
    error ZeroAddress();
    error EndpointsMismatch();

    function setEndpoints(address router, address poolManager) external;

    function router() external view returns (address);
    function poolManager() external view returns (address);
    function isConfigured() external view returns (bool);
}
