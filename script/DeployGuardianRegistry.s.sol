// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";

contract DeployGuardianRegistry is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        address registry = Upgrades.deployUUPSProxy(
            "GuardianRegistry.sol:GuardianRegistry",
            abi.encodeCall(
                GuardianRegistry.initialize,
                (deployer, 1000 * 10 ** 18, 7 days)
            )
        );

        console.log("GuardianRegistry:", registry);

        vm.stopBroadcast();
    }
}
