// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ImperiumDAO} from "../contracts/governance/ImperiumDAO.sol";

/// @title DeployDAO
/// @notice Deploy TimelockController + ImperiumDAO.
///         Il DAO e' il governo on-chain del protocollo.
///         Il Timelock e' il governor finale dei contratti (Fase C).
///
///         Parametri configurabili via .env (con default sensati):
///         - DAO_VOTING_DELAY:     default 1 giorno
///         - DAO_VOTING_PERIOD:    default 7 giorni
///         - DAO_PROPOSAL_THRESHOLD: default 1000 TIMP (1000e18)
///         - DAO_QUORUM_PERCENT:   default 10%
///         - DAO_TIMELOCK_DELAY:   default 2 giorni
contract DeployDAO is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address timpAddr = vm.envAddress("TIMP_ADDR");

        uint48  votingDelay        = uint48(vm.envOr("DAO_VOTING_DELAY", uint256(1 days)));
        uint32  votingPeriod       = uint32(vm.envOr("DAO_VOTING_PERIOD", uint256(7 days)));
        uint256 proposalThreshold  = vm.envOr("DAO_PROPOSAL_THRESHOLD", uint256(1000 ether));
        uint256 quorumPercent      = vm.envOr("DAO_QUORUM_PERCENT", uint256(10));
        uint256 timelockDelay      = vm.envOr("DAO_TIMELOCK_DELAY", uint256(2 days));

        require(timpAddr != address(0), "TIMP_ADDR zero");
        require(quorumPercent > 0 && quorumPercent <= 100, "quorum 1-100");
        require(proposalThreshold > 0, "threshold zero");

        console.log("=== DeployDAO ===");
        console.log("Deployer:           ", deployer);
        console.log("TIMP token:         ", timpAddr);
        console.log("Voting delay:       ", votingDelay);
        console.log("Voting period:      ", votingPeriod);
        console.log("Proposal threshold: ", proposalThreshold);
        console.log("Quorum percent:     ", quorumPercent);
        console.log("Timelock delay:     ", timelockDelay);

        vm.startBroadcast();

        // 1. TimelockController
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        TimelockController timelock = new TimelockController(
            timelockDelay,
            proposers,
            executors,
            deployer
        );
        console.log("TimelockController:", address(timelock));

        // 2. ImperiumDAO
        ImperiumDAO dao = new ImperiumDAO(
            IVotes(timpAddr),
            timelock,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercent
        );
        console.log("ImperiumDAO:       ", address(dao));

        // Nota: proposalThreshold viene letto dall'override di GovernorSettings.
        // Il valore passato al costruttore e' 0, ma se vogliamo cambiarlo va
        // fatto via setProposalThreshold dopo il deploy (soloGovernor).

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

        console.log("");
        console.log("=== DEPLOY DAO COMPLETO ===");
        console.log("TimelockController:", address(timelock));
        console.log("ImperiumDAO:       ", address(dao));
        console.log("");
        console.log("Prossimo passo: PromoteGovernance.s.sol");
        console.log("Vedi docs/ROADMAP-v1.2.md");
    }
}
