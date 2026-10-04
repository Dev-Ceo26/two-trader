// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";
import {DecisionRegistry} from "../contracts/decisions/DecisionRegistry.sol";
import {DecisionLib} from "../contracts/decisions/DecisionLib.sol";
import {ImperiumMessenger} from "../contracts/bridge/ImperiumMessenger.sol";
import {ImperiumBridgeRoot} from "../contracts/bridge/ImperiumBridgeRoot.sol";
import {ImperiumBridgeChild} from "../contracts/bridge/ImperiumBridgeChild.sol";

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

        // 3. ImperiumMessenger
        address messenger = Upgrades.deployUUPSProxy(
            "ImperiumMessenger.sol:ImperiumMessenger",
            abi.encodeCall(
                ImperiumMessenger.initialize,
                (guardianRegistry, decisionRegistry, threshold)
            )
        );
        console.log("ImperiumMessenger:", messenger);

        // 4. ImperiumBridgeRoot (5 parametri: messenger, l2ChainId, governor, feeBps, feeRecipient)
        address bridgeRoot = Upgrades.deployUUPSProxy(
            "ImperiumBridgeRoot.sol:ImperiumBridgeRoot",
            abi.encodeCall(
                ImperiumBridgeRoot.initialize,
                (messenger, l2ChainId, deployer, feeBps, feeRecipient)
            )
        );
        console.log("ImperiumBridgeRoot:", bridgeRoot);

        // 5. ImperiumBridgeChild (5 parametri: messenger, l1ChainId, governor, feeBps, feeRecipient)
        address bridgeChild = Upgrades.deployUUPSProxy(
            "ImperiumBridgeChild.sol:ImperiumBridgeChild",
            abi.encodeCall(
                ImperiumBridgeChild.initialize,
                (messenger, l1ChainId, deployer, feeBps, feeRecipient)
            )
        );
        console.log("ImperiumBridgeChild:", bridgeChild);

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
        console.log("ImperiumMessenger:", d.messenger);
        console.log("ImperiumBridgeRoot: ", d.bridgeRoot);
        console.log("ImperiumBridgeChild:", d.bridgeChild);
        console.log("\nTutti i GOVERNOR_ROLE sono su:", deployer);
        console.log("Fee BPS:", feeBps);
        console.log("Fee recipient:", feeRecipient);
        console.log("Il DAO non ha ruoli su questi contratti (Fase A).");
    }
}
