// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ImperiumMessenger} from "../contracts/bridge/ImperiumMessenger.sol";
import {ImperiumBridgeChild} from "../contracts/bridge/ImperiumBridgeChild.sol";

contract DeployBridge is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address guardianRegistry = vm.envAddress("GUARDIAN_REGISTRY");

        vm.startBroadcast();

        // 1. ImperiumMessenger
        address messenger = Upgrades.deployUUPSProxy(
            "ImperiumMessenger.sol:ImperiumMessenger",
            abi.encodeCall(
                ImperiumMessenger.initialize,
                (guardianRegistry, 3) // threshold 3/5
            )
        );
        console.log("ImperiumMessenger:", messenger);

        // 2. ImperiumBridgeChild
        address bridgeChild = Upgrades.deployUUPSProxy(
            "ImperiumBridgeChild.sol:ImperiumBridgeChild",
            abi.encodeCall(
                ImperiumBridgeChild.initialize,
                (messenger, 1, deployer) // l1ChainId=1, governor=deployer
            )
        );
        console.log("ImperiumBridgeChild:", bridgeChild);

        vm.stopBroadcast();

        console.log("\n=== DEPLOY BRIDGE COMPLETO ===");
        console.log("ImperiumMessenger:  ", messenger);
        console.log("ImperiumBridgeChild:", bridgeChild);
    }
}
