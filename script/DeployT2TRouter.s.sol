// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {T2TRouter} from "../contracts/v4/T2TRouter.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DeployT2TRouter is Script {
    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address owner = vm.envAddress("ADMIN_ADDRESS");

        console2.log("PoolManager:", poolManager);
        console2.log("Owner:", owner);

        vm.startBroadcast();

        T2TRouter router = new T2TRouter(
            IPoolManager(poolManager),
            owner
        );

        console2.log("T2TRouter deployed:", address(router));

        vm.stopBroadcast();
    }
}
