// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PoolRegistry
/// @notice Registro ufficiale dei pool SLE. Gestisce la whitelist delle curve
///         e congela l'associazione pool↔curva dopo l'attivazione.
/// @dev Immutabile (non upgradeable). In produzione owner = Timelock.
///      Il poolId è calcolato off-chain come keccak256(abi.encode(token0, token1, curve)).
contract PoolRegistry is Ownable {
    // ───────────── Structs ─────────────
    struct PoolInfo {
        address curve;
        address token0;
        address token1;
        bool active;
        uint256 createdAt;
    }

    // ───────────── Storage ─────────────
    mapping(bytes32 => PoolInfo) public pools;
    mapping(address => bool) public isWhitelistedCurve;

    // ───────────── Events ─────────────
    event PoolRegistered(bytes32 indexed poolId, address indexed curve, address token0, address token1);
    event PoolActivated(bytes32 indexed poolId);
    event CurveWhitelistUpdated(address indexed curve, bool status);

    // ───────────── Errors ─────────────
    error AlreadyRegistered();
    error NotRegistered();
    error AlreadyActive();
    error CurveNotWhitelisted();
    error ZeroAddress();
    error InvalidTokenPair();

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ───────────── Governance ─────────────

    /// @notice Aggiunge o rimuove una curva dalla whitelist
    /// @dev Solo owner (Timelock in produzione)
    function whitelistCurve(address curve, bool status) external onlyOwner {
        if (curve == address(0)) revert ZeroAddress();
        isWhitelistedCurve[curve] = status;
        emit CurveWhitelistUpdated(curve, status);
    }

    /// @notice Registra un nuovo pool. La curva è congelata da questo momento.
    /// @dev Solo owner. La curva deve essere whitelisted. token0 < token1.
    function registerPool(
        bytes32 poolId,
        address curve,
        address token0,
        address token1
    ) external onlyOwner {
        if (pools[poolId].curve != address(0)) revert AlreadyRegistered();
        if (!isWhitelistedCurve[curve]) revert CurveNotWhitelisted();
        if (token0 == address(0) || token1 == address(0)) revert ZeroAddress();
        if (uint160(token0) >= uint160(token1)) revert InvalidTokenPair();

        pools[poolId] = PoolInfo({
            curve: curve,
            token0: token0,
            token1: token1,
            active: false,
            createdAt: block.timestamp
        });

        emit PoolRegistered(poolId, curve, token0, token1);
    }

    /// @notice Attiva un pool registrato. Operazione irreversibile.
    function activatePool(bytes32 poolId) external onlyOwner {
        PoolInfo storage p = pools[poolId];
        if (p.curve == address(0)) revert NotRegistered();
        if (p.active) revert AlreadyActive();
        p.active = true;
        emit PoolActivated(poolId);
    }

    // ───────────── Views ─────────────

    function getCurve(bytes32 poolId) external view returns (address) {
        return pools[poolId].curve;
    }

    function getPool(bytes32 poolId) external view returns (PoolInfo memory) {
        return pools[poolId];
    }

    function isActive(bytes32 poolId) external view returns (bool) {
        return pools[poolId].active;
    }
}
