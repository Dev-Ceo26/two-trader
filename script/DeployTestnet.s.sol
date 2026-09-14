// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {tIMP} from "../contracts/token/tIMP.sol";
import {IMPStaking} from "../contracts/staking/IMPStaking.sol";
import {ImperiumVault} from "../contracts/vault/ImperiumVault.sol";
import {FeeDistributor} from "../contracts/distribution/FeeDistributor.sol";
import {ImperiumFactory} from "../contracts/maker/ImperiumFactory.sol";

contract DeployTestnet is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        // 1. tIMP
        address timp = Upgrades.deployUUPSProxy(
            "tIMP.sol:tIMP",
            abi.encodeCall(tIMP.initialize, (deployer, deployer))
        );
        console.log("tIMP:", timp);

        // 2. Vault
        address vault = Upgrades.deployUUPSProxy(
            "ImperiumVault.sol:ImperiumVault",
            abi.encodeCall(ImperiumVault.initialize, (deployer))
        );
        console.log("Vault:", vault);

        // 3. FeeDistributor
        address feeDist = Upgrades.deployUUPSProxy(
            "FeeDistributor.sol:FeeDistributor",
            abi.encodeCall(FeeDistributor.initialize, (deployer, vault, vault))
        );
        console.log("FeeDistributor:", feeDist);

        // 4. Factory
        address factory = Upgrades.deployUUPSProxy(
            "ImperiumFactory.sol:ImperiumFactory",
            abi.encodeCall(ImperiumFactory.initialize, (deployer))
        );
        console.log("Factory:", factory);

        // 5. Staking (usa lo stesso tIMP)
        address staking = Upgrades.deployUUPSProxy(
            "IMPStaking.sol:IMPStaking",
            abi.encodeCall(IMPStaking.initialize, (timp, deployer, 7 days))
        );
        console.log("Staking:", staking);

        vm.stopBroadcast();

        console.log("\n=== DEPLOY TESTNET COMPLETO ===");
        console.log("tIMP:          ", timp);
        console.log("Vault:         ", vault);
        console.log("FeeDistributor:", feeDist);
        console.log("Factory:       ", factory);
        console.log("Staking:       ", staking);
    }
}
