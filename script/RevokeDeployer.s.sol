// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

/// @title RevokeDeployer
/// @notice Fase 2 di PromoteGovernance.
///         Il deployer rinuncia a GOVERNOR_ROLE e DEFAULT_ADMIN_ROLE
///         sui contratti di sistema.
///
///         ATTENZIONE: dopo questa fase, il deployer NON HA PIU' RUOLI.
///         Solo il Timelock (via DAO) puo' agire.
///
///         Esegui DOPO aver verificato che la Fase 1 (GrantGovernance)
///         sia andata a buon fine on-chain.
contract RevokeDeployer is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address timelock = vm.envAddress("TIMELOCK");
        address guardianRegistry = vm.envAddress("GUARDIAN_REGISTRY");
        address decisionRegistry = vm.envAddress("DECISION_REGISTRY");
        address messenger = vm.envAddress("IMPERIUM_MESSENGER");
        address bridgeRoot = vm.envAddress("BRIDGE_ROOT");
        address bridgeChild = vm.envAddress("BRIDGE_CHILD");

        require(timelock != address(0), "TIMELOCK zero");
        require(timelock != deployer, "TIMELOCK == deployer");

        console.log("=== RevokeDeployer (Fase 2) ===");
        console.log("Deployer:          ", deployer);
        console.log("Timelock:          ", timelock);
        console.log("");
        console.log("ATTENZIONE: il deployer rinuncera' a tutti i ruoli.");
        console.log("Assicurati che la Fase 1 sia passata.");
        console.log("");

        vm.startBroadcast();

        // Prima verifica che il timelock ABBIA i ruoli
        _checkTimelockHasRoles(guardianRegistry, timelock);
        _checkTimelockHasRoles(decisionRegistry, timelock);
        _checkTimelockHasRoles(messenger, timelock);
        _checkTimelockHasRoles(bridgeRoot, timelock);
        _checkTimelockHasRoles(bridgeChild, timelock);

        // Poi il deployer rinuncia
        _revokeFrom(guardianRegistry, deployer);
        _revokeFrom(decisionRegistry, deployer);
        _revokeFrom(messenger, deployer);
        _revokeFrom(bridgeRoot, deployer);
        _revokeFrom(bridgeChild, deployer);

        vm.stopBroadcast();

        console.log("");
        console.log("=== FASE 2 COMPLETA ===");
        console.log("Il deployer non ha piu' ruoli sui 5 contratti.");
        console.log("Il governo e' ora del Timelock (via DAO).");
    }

    function _checkTimelockHasRoles(address target, address timelock) internal view {
        bytes32 governorRole = keccak256("GOVERNOR_ROLE");
        (bool ok, bytes memory data) = target.staticcall(
            abi.encodeWithSignature("hasRole(bytes32,address)", governorRole, timelock)
        );
        require(ok, "hasRole failed");
        bool has = abi.decode(data, (bool));
        require(has, "Timelock does not have GOVERNOR_ROLE yet. Run GrantGovernance first.");
    }

    function _revokeFrom(address target, address deployer) internal {
        bytes32 governorRole = keccak256("GOVERNOR_ROLE");
        bytes32 adminRole = keccak256("DEFAULT_ADMIN_ROLE");

        (bool ok1, ) = target.call(
            abi.encodeWithSignature("renounceRole(bytes32,address)", governorRole, deployer)
        );
        require(ok1, "renounce governor failed");

        (bool ok2, ) = target.call(
            abi.encodeWithSignature("renounceRole(bytes32,address)", adminRole, deployer)
        );
        require(ok2, "renounce admin failed");

        console.log("Revoked from", target);
    }
}
