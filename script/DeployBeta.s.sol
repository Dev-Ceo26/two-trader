// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";
import {DecisionRegistry} from "../contracts/decisions/DecisionRegistry.sol";
import {DecisionLib} from "../contracts/decisions/DecisionLib.sol";
import {T2TMessenger} from "../contracts/bridge/T2TMessenger.sol";
import {T2TBridgeRoot} from "../contracts/bridge/T2TBridgeRoot.sol";
import {T2TBridgeChild} from "../contracts/bridge/T2TBridgeChild.sol";

/// @title DeployBeta
/// @notice Deploy Fase A: tutto con deployer come governor.
///         Versione v1.2 — aggiunge feeBps e feeRecipient ai bridge.
contract DeployBeta is Script {
    struct Deployment {
        address guardianRegistry;
        address decisionRegistry;
        address messenger;
        address bridgeRoot;
        address bridgeChild;
    }

    function run() public returns (Deployment memory d) {
        address deployer = vm.envAddress("DEPLOYER");
        uint256 l2ChainId = vm.envUint("L2_CHAIN_ID");
        uint256 l1ChainId = vm.envUint("L1_CHAIN_ID");
        uint256 threshold = vm.envOr("GUARDIAN_THRESHOLD", uint256(3));
        uint256 minStake  = vm.envOr("GUARDIAN_MIN_STAKE", uint256(1000 ether));
        uint256 cooldown  = vm.envOr("GUARDIAN_UNSTAKE_COOLDOWN", uint256(7 days));
        uint256 feeBps    = vm.envOr("FEE_BPS", uint256(10)); // 0.1% default
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        require(feeBps <= DecisionLib.MAX_FEE_BPS, "feeBps > MAX_FEE_BPS");

        console.log("=== DeployBeta (Fase A, v1.2) ===");
        console.log("Deployer:         ", deployer);
        console.log("L1 chainId:       ", l1ChainId);
        console.log("L2 chainId:       ", l2ChainId);
        console.log("Threshold:        ", threshold);
        console.log("Min stake:        ", minStake);
        console.log("Unstake cooldown: ", cooldown);
        console.log("Fee BPS:          ", feeBps);
        console.log("Fee recipient:    ", feeRecipient);

        vm.startBroadcast();

        // 1. GuardianRegistry
        address guardianRegistry = Upgrades.deployUUPSProxy(
            "GuardianRegistry.sol:GuardianRegistry",
            abi.encodeCall(
                GuardianRegistry.initialize,
                (deployer, minStake, cooldown)
            )
        );
        console.log("GuardianRegistry: ", guardianRegistry);

        // 2. DecisionRegistry
        address decisionRegistry = Upgrades.deployUUPSProxy(
            "DecisionRegistry.sol:DecisionRegistry",
            abi.encodeCall(
                DecisionRegistry.initialize,
                (deployer)
            )
        );
        console.log("DecisionRegistry: ", decisionRegistry);

        // 3. T2TMessenger
        address messenger = Upgrades.deployUUPSProxy(
            "T2TMessenger.sol:T2TMessenger",
            abi.encodeCall(
                T2TMessenger.initialize,
                (guardianRegistry, decisionRegistry, threshold)
            )
        );
        console.log("T2TMessenger:", messenger);

        // 4. T2TBridgeRoot (5 parametri: messenger, l2ChainId, governor, feeBps, feeRecipient)
        address bridgeRoot = Upgrades.deployUUPSProxy(
            "T2TBridgeRoot.sol:T2TBridgeRoot",
            abi.encodeCall(
                T2TBridgeRoot.initialize,
                (messenger, l2ChainId, deployer, feeBps, feeRecipient)
            )
        );
        console.log("T2TBridgeRoot:", bridgeRoot);

        // 5. T2TBridgeChild (5 parametri: messenger, l1ChainId, governor, feeBps, feeRecipient)
        address bridgeChild = Upgrades.deployUUPSProxy(
            "T2TBridgeChild.sol:T2TBridgeChild",
            abi.encodeCall(
                T2TBridgeChild.initialize,
                (messenger, l1ChainId, deployer, feeBps, feeRecipient)
            )
        );
        console.log("T2TBridgeChild:", bridgeChild);

        vm.stopBroadcast();

        d = Deployment({
            guardianRegistry: guardianRegistry,
            decisionRegistry: decisionRegistry,
            messenger:        messenger,
            bridgeRoot:       bridgeRoot,
            bridgeChild:      bridgeChild
        });

        console.log("\n=== DEPLOY BETA v1.2 COMPLETO ===");
        console.log("GuardianRegistry: ", d.guardianRegistry);
        console.log("DecisionRegistry: ", d.decisionRegistry);
        console.log("T2TMessenger:", d.messenger);
        console.log("T2TBridgeRoot: ", d.bridgeRoot);
        console.log("T2TBridgeChild:", d.bridgeChild);
        console.log("\nTutti i GOVERNOR_ROLE sono su:", deployer);
        console.log("Fee BPS:", feeBps);
        console.log("Fee recipient:", feeRecipient);
        console.log("Il DAO non ha ruoli su questi contratti (Fase A).");
    }
}
