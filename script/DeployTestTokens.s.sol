// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {E2EMockERC20} from "../contracts/test-mocks/E2EMockERC20.sol";

/// @title DeployTestTokens
/// @notice Deploya 2 token mock (T2T e USDC) per testare SLE.
contract DeployTestTokens is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        console.log("Deployer:", deployer);
        console.log("ChainID: ", block.chainid);

        vm.startBroadcast();

        E2EMockERC20 t2t = new E2EMockERC20("Two-Trader", "T2T");
        console.log("T2T_MOCK:", address(t2t));

        E2EMockERC20 usdc = new E2EMockERC20("Mock USDC", "mUSDC");
        console.log("USDC_MOCK:", address(usdc));

        vm.stopBroadcast();
    }
}
