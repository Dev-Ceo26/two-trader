// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeBridgeChild is Script {
    function run() public {
        address proxy = vm.envAddress("BRIDGE_CHILD_PROXY");

        Options memory opts;
        opts.unsafeSkipStorageCheck = true;

        vm.startBroadcast();

        Upgrades.upgradeProxy(
            proxy,
            "T2TBridgeChild.sol:T2TBridgeChild",
            "",
            opts
        );

        console.log("BridgeChild upgraded:", proxy);

        vm.stopBroadcast();
    }
}
