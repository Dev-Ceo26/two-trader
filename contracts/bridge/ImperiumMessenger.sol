// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {GuardianRegistry} from "../governance/GuardianRegistry.sol";

contract ImperiumMessenger is UUPSUpgradeable, AccessControlUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    GuardianRegistry public registry;
    uint256 public threshold;

    event SignaturesVerified(bytes32 indexed messageHash, uint256 count);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry, uint256 _threshold) external initializer {
        require(_registry != address(0), "registry zero");
        require(_threshold > 0, "threshold zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);

        registry = GuardianRegistry(_registry);
        threshold = _threshold;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    function verifySignatures(
        bytes32 messageHash,
        bytes[] calldata signatures
    ) external view returns (bool) {
        if (signatures.length < threshold) return false;

        bytes32 ethHash = messageHash.toEthSignedMessageHash();
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
}
