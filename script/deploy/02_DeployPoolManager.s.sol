// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ImperiumPoolManager} from "../../contracts/v4/ImperiumPoolManager.sol";

contract DeployPoolManager is Script {
    function run() public {
        address deployer = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();

        address poolManager = Upgrades.deployUUPSProxy(
            "ImperiumPoolManager.sol:ImperiumPoolManager",
            abi.encodeWithSignature("initialize(address)", deployer)
        );

        console.log("ImperiumPoolManager:", poolManager);

        vm.stopBroadcast();
    }
}
