// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ImperiumHooks} from "../contracts/v4/ImperiumHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "lib/v4-periphery/test/shared/HookMiner.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";

/// @title DeployImperiumHooks
/// @notice Mine salt per bit 0xC0, deploy diretto via CREATE2 (NO proxy).
contract DeployImperiumHooks is Script {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        // Nomi allineati al .env del progetto
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address guardianRegistry = vm.envAddress("GUARDIAN_REGISTRY_ADDRESS");
        address owner = vm.envAddress("ADMIN_ADDRESS");

        require(poolManager != address(0), "POOL_MANAGER zero");
        require(guardianRegistry != address(0), "GUARDIAN_REGISTRY zero");
        require(owner != address(0), "OWNER zero");

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG); // 0xC0
        console2.log("Target flags:", flags);
        console2.log("PoolManager:", poolManager);
        console2.log("GuardianRegistry:", guardianRegistry);
        console2.log("Owner:", owner);
        console2.log("CREATE2 deployer:", CREATE2_DEPLOYER);

        bytes memory creationCode = type(ImperiumHooks).creationCode;
        bytes memory constructorArgs =
            abi.encode(IPoolManager(poolManager), GuardianRegistry(guardianRegistry), owner);

        (address predictedAddr, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, creationCode, constructorArgs);

        console2.log("Predicted hook address:", predictedAddr);
        console2.logBytes32(salt);

        vm.startBroadcast();

        ImperiumHooks hooks = new ImperiumHooks{salt: salt}(
            IPoolManager(poolManager),
            GuardianRegistry(guardianRegistry),
            owner
        );

        require(address(hooks) == predictedAddr, "address mismatch");
        console2.log("ImperiumHooks deployed:", address(hooks));

        uint160 masked = uint160(address(hooks)) & Hooks.ALL_HOOK_MASK;
        require(masked == flags, "flags mismatch");
        console2.log("Flags OK:", masked);

        vm.stopBroadcast();
    }
}
