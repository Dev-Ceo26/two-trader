// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ImperiumDAO} from "../contracts/governance/ImperiumDAO.sol";

contract DeployDAO is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address timpAddr = vm.envAddress("TIMP_ADDR");

        vm.startBroadcast();

        // 1. TimelockController
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        TimelockController timelock = new TimelockController(
            2 days,          // minDelay
            proposers,       // proposers (vuoto per ora)
            executors,       // executors (vuoto per ora)
            deployer         // admin (temporaneo)
        );
        console.log("TimelockController:", address(timelock));

        // 2. ImperiumDAO
       ImperiumDAO dao = new ImperiumDAO(
    IVotes(timpAddr),
    timelock,
    uint48(1 days),    // votingDelay
    uint32(7 days),    // votingPeriod
    4                  // quorumPercent (4%)
);
        console.log("ImperiumDAO:", address(dao));

        // 3. Configura il Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(dao));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(dao));
        console.log("Timelock roles granted to DAO");

        // 4. Rinuncia ai ruoli di admin
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        timelock.renounceRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.renounceRole(timelock.EXECUTOR_ROLE(), deployer);
        timelock.renounceRole(timelock.CANCELLER_ROLE(), deployer);
        console.log("Deployer renounced all roles");

        vm.stopBroadcast();

        console.log("\n=== DEPLOY DAO COMPLETO ===");
        console.log("TimelockController:", address(timelock));
        console.log("ImperiumDAO:       ", address(dao));
    }
}
