// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract DeployMocks is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        MockUSDC usdc = new MockUSDC(deployer);
        console2.log("MockUSDC:", address(usdc));

        MockUSDT usdt = new MockUSDT(deployer);
        console2.log("MockUSDT:", address(usdt));

        usdc.mint(deployer, 10_000_000 * 10 ** 6);
        usdt.mint(deployer, 10_000_000 * 10 ** 6);
        console2.log("Minted 10M USDC + 10M USDT al deployer");

        vm.stopBroadcast();

        console2.log("");
        console2.log("MOCK_USDC_ADDRESS:", address(usdc));
        console2.log("MOCK_USDT_ADDRESS:", address(usdt));
    }
}
