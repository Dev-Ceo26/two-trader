// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Faucet} from "../contracts/faucet/Faucet.sol";

contract DeployFaucet is Script {
    using SafeERC20 for IERC20;

    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        address tImprAddr = vm.envAddress("TIMP_ADDR");

        vm.startBroadcast();

        Faucet faucet = new Faucet(tImprAddr, deployer);
        console.log("Faucet:", address(faucet));

        // Finanzia il faucet con 100.000 tIMP
        IERC20(tImprAddr).safeTransfer(address(faucet), 100_000 * 10 ** 18);
        console.log("Faucet funded with 100k tIMP");

        vm.stopBroadcast();
    }
}
