// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {T2TFactory} from "../contracts/maker/T2TFactory.sol";

contract CreatePair is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");

        console.log("=== Create Pair ===");
        console.log("Factory:", factory);
        console.log("Token A:", tokenA);
        console.log("Token B:", tokenB);

        vm.startBroadcast(pk);
        address pair = T2TFactory(factory).createPair(tokenA, tokenB);
        vm.stopBroadcast();

        console.log("Pair created:", pair);
    }
}
