// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ImperiumMessenger} from "../contracts/bridge/ImperiumMessenger.sol";
import {ImperiumBridgeRoot} from "../contracts/bridge/ImperiumBridgeRoot.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";

contract DeployRootSepolia is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        // 1. GuardianRegistry (su Sepolia)
        address registry = Upgrades.deployUUPSProxy(
            "GuardianRegistry.sol:GuardianRegistry",
            abi.encodeCall(
                GuardianRegistry.initialize,
                (deployer, 1000 * 10 ** 18, 7 days)
            )
        );
        console.log("GuardianRegistry (Sepolia):", registry);

        // 2. ImperiumMessenger (su Sepolia)
        address messenger = Upgrades.deployUUPSProxy(
            "ImperiumMessenger.sol:ImperiumMessenger",
            abi.encodeCall(
                ImperiumMessenger.initialize,
                (registry, 3)
            )
        );
        console.log("ImperiumMessenger (Sepolia):", messenger);

        // 3. ImperiumBridgeRoot
        address bridgeRoot = Upgrades.deployUUPSProxy(
            "ImperiumBridgeRoot.sol:ImperiumBridgeRoot",
            abi.encodeCall(
                ImperiumBridgeRoot.initialize,
                (messenger, 9818, deployer)
            )
        );
        console.log("ImperiumBridgeRoot:", bridgeRoot);

        vm.stopBroadcast();

        console.log("\n=== DEPLOY SEPOLIA COMPLETO ===");
        console.log("GuardianRegistry:    ", registry);
        console.log("ImperiumMessenger:   ", messenger);
        console.log("ImperiumBridgeRoot:  ", bridgeRoot);
    }
}
