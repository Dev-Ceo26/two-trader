// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {DecisionLib} from "./DecisionLib.sol";

/// @title DecisionRegistry
/// @notice Registro canonico delle decisioni che attraversano T2T.
///         Ogni decisione e' registrata con campi nominati, emessa in un evento
///         leggibile, e puo' essere vetata da VETO_ROLE.
///         Il veto non annulla la decisione on-chain: la marca come vetata,
///         e il messenger rifiuta di verificarla.
contract DecisionRegistry is UUPSUpgradeable, AccessControlUpgradeable {
    using DecisionLib for DecisionLib.Decision;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant VETO_ROLE     = keccak256("VETO_ROLE");

    struct Record {
        DecisionLib.Decision decision;
        bool vetoed;
        uint64 recordedAt;
        uint64 vetoedAt;
        address vetoedBy;
    }

    mapping(bytes32 => Record) public records;

    event DecisionRecorded(bytes32 indexed id, DecisionLib.Decision d, uint64 recordedAt);
    event DecisionVetoed(bytes32 indexed id, address indexed by, string reason, uint64 vetoedAt);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor) external initializer {
        require(governor != address(0), "governor zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
        _grantRole(VETO_ROLE, governor);
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    /// @notice Registra una decisione canonica.
    /// @dev    Richiede che la decisione passi `DecisionLib.validate`.
    ///         Una decisione gia' registrata non puo' essere sovrascritta.
    function record(DecisionLib.Decision calldata d) external returns (bytes32 id) {
        require(DecisionLib.validate(d), "invalid decision");

        id = DecisionLib.hash(d);
        require(records[id].recordedAt == 0, "already recorded");

        records[id] = Record({
            decision: d,
            vetoed: false,
            recordedAt: uint64(block.timestamp),
            vetoedAt: 0,
            vetoedBy: address(0)
        });

        emit DecisionRecorded(id, d, uint64(block.timestamp));
    }

    /// @notice Veta una decisione registrata.
    /// @dev    Il veto e' irreversibile. Una decisione vetata non puo' essere
    ///         verificata dal messenger.
    function veto(bytes32 id, string calldata reason) external onlyRole(VETO_ROLE) {
        Record storage r = records[id];
        require(r.recordedAt != 0, "unknown decision");
        require(!r.vetoed, "already vetoed");

        r.vetoed = true;
        r.vetoedAt = uint64(block.timestamp);
        r.vetoedBy = msg.sender;

        emit DecisionVetoed(id, msg.sender, reason, uint64(block.timestamp));
    }

    /// @notice True se la decisione e' registrata.
    function isRecorded(bytes32 id) external view returns (bool) {
        return records[id].recordedAt != 0;
    }

    /// @notice True se la decisione e' vetata.
    function isVetoed(bytes32 id) external view returns (bool) {
        return records[id].vetoed;
    }

    /// @notice Restituisce la decisione completa.
    function getDecision(bytes32 id) external view returns (DecisionLib.Decision memory) {
        return records[id].decision;
    }
}
