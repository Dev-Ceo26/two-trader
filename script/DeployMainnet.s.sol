// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {TwoTrader} from "../contracts/token/TwoTrader.sol";
import {T2TStaking} from "../contracts/staking/T2TStaking.sol";
import {T2TVault} from "../contracts/vault/T2TVault.sol";
import {FeeDistributor} from "../contracts/distribution/FeeDistributor.sol";
import {T2TFactory} from "../contracts/maker/T2TFactory.sol";

contract DeployMainnet is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address impOld = vm.envAddress("IMP_OLD");

        vm.startBroadcast();

        // 1. TwoTrader (token governance mainnet, mintable cap 1B)
        address imp = Upgrades.deployUUPSProxy(
            "TwoTrader.sol:TwoTrader",
            abi.encodeCall(TwoTrader.initialize, (deployer, deployer))
        );
        console.log("TwoTrader:", imp);

        // 2. Vault
        address vault = Upgrades.deployUUPSProxy(
            "T2TVault.sol:T2TVault",
            abi.encodeCall(T2TVault.initialize, (deployer))
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
            "T2TFactory.sol:T2TFactory",
            abi.encodeCall(T2TFactory.initialize, (deployer))
        );
        console.log("Factory:", factory);

        // 5. Staking
        address staking = Upgrades.deployUUPSProxy(
            "T2TStaking.sol:T2TStaking",
            abi.encodeCall(T2TStaking.initialize, (impOld, deployer, 7 days))
        );
        console.log("Staking:", staking);

        vm.stopBroadcast();

        console.log("\n=== DEPLOY MAINNET COMPLETO ===");
        console.log("TwoTrader:           ", imp);
        console.log("Vault:         ", vault);
        console.log("FeeDistributor:", feeDist);
        console.log("Factory:       ", factory);
        console.log("Staking:       ", staking);
    }
}
