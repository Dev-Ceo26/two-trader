// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISLEAddressProvider} from "../interfaces/ISLEAddressProvider.sol";

/// @title SLEAddressProvider
/// @notice Provider one-shot per gli indirizzi di Router e PoolManager.
/// @dev Configurazione atomica e irreversibile. Owner esegue setEndpoints() una volta
///      e poi rinuncia all'ownership (o resta con poteri nulli).
///      Il provider non ha setter successivi, non ha upgrade, non può cambiare gli endpoint.
contract SLEAddressProvider is ISLEAddressProvider, Ownable {
    address private _router;
    address private _poolManager;
    bool private _configured;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Configura Router e PoolManager in un'unica transazione atomica
    /// @dev Chiamabile una sola volta. Rifiuta indirizzi zero.
    function setEndpoints(address router_, address poolManager_) external override onlyOwner {
        if (_configured) revert AlreadyConfigured();
        if (router_ == address(0) || poolManager_ == address(0)) revert ZeroAddress();
        if (router_ == poolManager_) revert EndpointsMismatch();

        _router = router_;
        _poolManager = poolManager_;
        _configured = true;

        emit EndpointsSet(router_, poolManager_);
    }

    function router() external view override returns (address) {
        return _router;
    }

    function poolManager() external view override returns (address) {
        return _poolManager;
    }

    function isConfigured() external view override returns (bool) {
        return _configured;
    }
}
