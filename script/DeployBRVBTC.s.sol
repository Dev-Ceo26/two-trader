// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {BolivarRepublicaVenezuelaBTC} from "../contracts/test/BolivarRepublicaVenezuelaBTC.sol";

contract DeployBRVBTC is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        address mockUsdc = vm.envAddress("MOCK_USDC_ADDRESS");     // usiamo MockUSDC come "WBTC"
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");

        vm.startBroadcast();

        BolivarRepublicaVenezuelaBTC brvbtc = new BolivarRepublicaVenezuelaBTC(
            "https://two-trader.com/metadata/brvbtc.json",
            mockUsdc,
            poolManager
        );

        console2.log("=== BRVBTC DEPLOYED ===");
        console2.log("Address:", address(brvbtc));
        console2.log("Name:   ", brvbtc.name());
        console2.log("Symbol: ", brvbtc.symbol());
        console2.log("Supply: ", brvbtc.totalSupply());
        console2.log("WBTC:   ", address(brvbtc.WBTC()));
        console2.log("Pool:   ", brvbtc.uniswapPoolManager());

        vm.stopBroadcast();
    }
}
