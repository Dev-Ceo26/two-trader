// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";
import {DecisionRegistry} from "../contracts/decisions/DecisionRegistry.sol";
import {T2TMessenger} from "../contracts/bridge/T2TMessenger.sol";
import {T2TBridgeRoot} from "../contracts/bridge/T2TBridgeRoot.sol";
import {T2TBridgeChild} from "../contracts/bridge/T2TBridgeChild.sol";

/// @title GrantGovernance
/// @notice Fase 1 di PromoteGovernance.
///         Concede GOVERNOR_ROLE e DEFAULT_ADMIN_ROLE al Timelock
///         sui contratti di sistema.
///
///         NON rinuncia ai ruoli del deployer. Quella e' Fase 2
///         (script separato RevokeDeployer.s.sol).
///
///         Esegui questa fase, VERIFICA l'evento RoleGranted on-chain,
///         poi esegui la Fase 2.
contract GrantGovernance is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address timelock = vm.envAddress("TIMELOCK");
        address guardianRegistry = vm.envAddress("GUARDIAN_REGISTRY");
        address decisionRegistry = vm.envAddress("DECISION_REGISTRY");
        address messenger = vm.envAddress("T2T_MESSENGER");
        address bridgeRoot = vm.envAddress("BRIDGE_ROOT");
        address bridgeChild = vm.envAddress("BRIDGE_CHILD");

        require(timelock != address(0), "TIMELOCK zero");
        require(timelock != deployer, "TIMELOCK == deployer");

        console.log("=== GrantGovernance (Fase 1) ===");
        console.log("Deployer:          ", deployer);
        console.log("Timelock:          ", timelock);
        console.log("GuardianRegistry:  ", guardianRegistry);
        console.log("DecisionRegistry:  ", decisionRegistry);
        console.log("Messenger:         ", messenger);
        console.log("BridgeRoot:        ", bridgeRoot);
        console.log("BridgeChild:       ", bridgeChild);
        console.log("");

        vm.startBroadcast();

        _grantTo(guardianRegistry, timelock);
        _grantTo(decisionRegistry, timelock);
        _grantTo(messenger, timelock);
        _grantTo(bridgeRoot, timelock);
        _grantTo(bridgeChild, timelock);

        vm.stopBroadcast();

        console.log("");
        console.log("=== FASE 1 COMPLETA ===");
        console.log("Il Timelock ha GOVERNOR_ROLE e DEFAULT_ADMIN_ROLE sui 5 contratti.");
        console.log("Il deployer ha ANCORA i ruoli.");
        console.log("");
        console.log("Verifica on-chain:");
        console.log("  cast call <contratto> 'hasRole(bytes32,address)(bool)' \\");
        console.log("    $(cast keccak 'GOVERNOR_ROLE') $TIMELOCK --rpc-url $RPC");
        console.log("");
        console.log("Poi esegui Fase 2: script/RevokeDeployer.s.sol");
    }

    function _grantTo(address target, address timelock) internal {
        bytes32 governorRole = keccak256("GOVERNOR_ROLE");
        bytes32 adminRole = keccak256("DEFAULT_ADMIN_ROLE");

        // Ogni contratto ha il suo GOVERNOR_ROLE come costante, ma l'hash e' lo stesso.
        (bool ok1, ) = target.call(
            abi.encodeWithSignature("grantRole(bytes32,address)", governorRole, timelock)
        );
        require(ok1, "grant governor failed");

        (bool ok2, ) = target.call(
            abi.encodeWithSignature("grantRole(bytes32,address)", adminRole, timelock)
        );
        require(ok2, "grant admin failed");

        console.log("Granted to", target);
    }
}
