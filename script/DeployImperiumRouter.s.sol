// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ImperiumRouter} from "../contracts/v4/ImperiumRouter.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DeployImperiumRouter is Script {
    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address owner = vm.envAddress("ADMIN_ADDRESS");

        console2.log("PoolManager:", poolManager);
        console2.log("Owner:", owner);

        vm.startBroadcast();

        ImperiumRouter router = new ImperiumRouter(
            IPoolManager(poolManager),
            owner
        );

        console2.log("ImperiumRouter deployed:", address(router));

        vm.stopBroadcast();
    }
}
