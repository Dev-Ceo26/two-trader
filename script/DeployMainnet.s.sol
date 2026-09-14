// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMP} from "../contracts/token/IMP.sol";
import {IMPStaking} from "../contracts/staking/IMPStaking.sol";
import {ImperiumVault} from "../contracts/vault/ImperiumVault.sol";
import {FeeDistributor} from "../contracts/distribution/FeeDistributor.sol";
import {ImperiumFactory} from "../contracts/maker/ImperiumFactory.sol";

contract DeployMainnet is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address impOld = vm.envAddress("IMP_OLD");

        vm.startBroadcast();

        // 1. IMP (token governance mainnet, mintable cap 1B)
        address imp = Upgrades.deployUUPSProxy(
            "IMP.sol:IMP",
            abi.encodeCall(IMP.initialize, (deployer, deployer))
        );
        console.log("IMP:", imp);

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

        // 5. Staking
        address staking = Upgrades.deployUUPSProxy(
            "IMPStaking.sol:IMPStaking",
            abi.encodeCall(IMPStaking.initialize, (impOld, deployer, 7 days))
        );
        console.log("Staking:", staking);

        vm.stopBroadcast();

        console.log("\n=== DEPLOY MAINNET COMPLETO ===");
        console.log("IMP:           ", imp);
        console.log("Vault:         ", vault);
        console.log("FeeDistributor:", feeDist);
        console.log("Factory:       ", factory);
        console.log("Staking:       ", staking);
    }
}
