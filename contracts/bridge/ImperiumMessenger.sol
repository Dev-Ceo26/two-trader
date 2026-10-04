// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {GuardianRegistry} from "../governance/GuardianRegistry.sol";
import {DecisionLib} from "../decisions/DecisionLib.sol";
import {DecisionRegistry} from "../decisions/DecisionRegistry.sol";

/// @title ImperiumMessenger
/// @notice Verifica firme 3/5 su decisioni canoniche.
///         Non accetta piu' hash opachi: accetta una DecisionLib.Decision
///         che viene registrata nel DecisionRegistry e poi verificata.
///         Una decisione vetata o scaduta non passa mai, nemmeno con 5/5 firme.
contract ImperiumMessenger is UUPSUpgradeable, AccessControlUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant GOVERNOR_ROLE  = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    GuardianRegistry public registry;
    DecisionRegistry public decisionRegistry;
    uint256 public threshold;
    bool public paused;

    event SignaturesVerified(bytes32 indexed decisionId, uint256 count);
    event DecisionRecordedViaMessenger(bytes32 indexed decisionId, DecisionLib.Decision d);
    event Paused(bool state);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _registry,
        address _decisionRegistry,
        uint256 _threshold
    ) external initializer {
        require(_registry != address(0), "registry zero");
        require(_decisionRegistry != address(0), "decisionRegistry zero");
        require(_threshold > 0, "threshold zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        registry = GuardianRegistry(_registry);
        decisionRegistry = DecisionRegistry(_decisionRegistry);
        threshold = _threshold;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    /// @notice Solo l'emergency puo' mettere in pausa il messenger.
    ///         Il pause e' reversibile solo dal governor.
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyRole(GOVERNOR_ROLE) {
        paused = false;
        emit Paused(false);
    }

    /// @notice Registra una decisione canonica nel DecisionRegistry.
    /// @dev    Chiunque puo' chiamare: registrare non significa eseguire.
    ///         L'esecuzione richiede la verifica delle firme.
    function recordDecision(DecisionLib.Decision calldata d) external returns (bytes32 id) {
        id = decisionRegistry.record(d);
        emit DecisionRecordedViaMessenger(id, d);
    }

    /// @notice Verifica le firme di una decisione registrata e non vetata.
    /// @dev    Restituisce false (non revert) se:
    ///         - il messenger e' in pausa
    ///         - la decisione non e' registrata
    ///         - la decisione e' vetata
    ///         - la deadline e' scaduta
    ///         - le firme valide sono sotto threshold
    function verifyDecision(
        DecisionLib.Decision calldata d,
        bytes[] calldata signatures
    ) external view returns (bool) {
        if (paused) return false;
        if (!DecisionLib.validate(d)) return false;
        if (DecisionLib.isExpired(d, block.timestamp)) return false;

        bytes32 id = DecisionLib.hash(d);

        if (!decisionRegistry.isRecorded(id)) return false;
        if (decisionRegistry.isVetoed(id)) return false;

        if (signatures.length < threshold) return false;

        bytes32 ethHash = id.toEthSignedMessageHash();
        address[] memory seen = new address[](threshold);
        uint256 valid = 0;

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ethHash.recover(signatures[i]);

            if (!registry.isActiveGuardian(signer)) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < valid; j++) {
                if (seen[j] == signer) { duplicate = true; break; }
            }
            if (duplicate) continue;

            seen[valid] = signer;
            valid++;

            if (valid >= threshold) return true;
        }

        return false;
    }

    /// @notice Versione con evento: usa questa se vuoi tracciare le verifiche riuscite.
    /// @dev    Stessa logica di verifyDecision, ma emette un evento.
    ///         Non e' view. Da chiamare dal bridge invece di verifyDecision
    ///         se vuoi che l'evento venga emesso.
    function verifyDecisionAndEmit(
        DecisionLib.Decision calldata d,
        bytes[] calldata signatures
    ) external returns (bool ok) {
        if (paused) return false;
        if (!DecisionLib.validate(d)) return false;
        if (DecisionLib.isExpired(d, block.timestamp)) return false;

        bytes32 id = DecisionLib.hash(d);

        if (!decisionRegistry.isRecorded(id)) return false;
        if (decisionRegistry.isVetoed(id)) return false;

        if (signatures.length < threshold) return false;

        bytes32 ethHash = id.toEthSignedMessageHash();
        address[] memory seen = new address[](threshold);
        uint256 valid = 0;

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ethHash.recover(signatures[i]);

            if (!registry.isActiveGuardian(signer)) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < valid; j++) {
                if (seen[j] == signer) { duplicate = true; break; }
            }
            if (duplicate) continue;

            seen[valid] = signer;
            valid++;

            if (valid >= threshold) {
                emit SignaturesVerified(id, valid);
                return true;
            }
        }

        return false;
    }

    /// @notice Cambia la threshold. Solo il governor.
    function setThreshold(uint256 newThreshold) external onlyRole(GOVERNOR_ROLE) {
        require(newThreshold > 0, "threshold zero");
        threshold = newThreshold;
    }
}
