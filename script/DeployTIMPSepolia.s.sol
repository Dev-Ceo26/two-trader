// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {tIMP} from "../contracts/token/tIMP.sol";

contract DeployTIMPSepolia is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        address timp = Upgrades.deployUUPSProxy(
            "tIMP.sol:tIMP",
            abi.encodeCall(tIMP.initialize, (deployer, deployer))
        );
        console.log("tIMP (Sepolia):", timp);

        vm.stopBroadcast();
    }
}
