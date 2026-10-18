// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {T2TUSD} from "../../src/T2TUSD.sol";
import {MasterMinter} from "../../src/MasterMinter.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {MockUSDT} from "../../src/MockUSDT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployT2TUSD is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        address safeTeamVault = vm.envAddress("SAFE_TEAM_VAULT_ADDRESS");

        console.log("=== Deploy T2TUSD ===");
        console.log("Deployer: %s", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy mock stablecoin
        MockUSDC mockUsdc = new MockUSDC(deployer);
        MockUSDT mockUsdt = new MockUSDT(deployer);
        console.log("MockUSDC: %s", address(mockUsdc));
        console.log("MockUSDT: %s", address(mockUsdt));

        // 2. Deploy MasterMinter
        MasterMinter masterMinter = new MasterMinter(deployer);
        console.log("MasterMinter: %s", address(masterMinter));

        // 3. Deploy implementation
        T2TUSD impl = new T2TUSD();
        console.log("T2TUSD impl: %s", address(impl));

        // 4. Deploy proxy + initialize
        bytes memory initData = abi.encodeWithSelector(
            T2TUSD.initialize.selector,
            address(mockUsdc),
            address(mockUsdt),
            address(masterMinter),
            pauser,
            feeCollector,
            safeTeamVault,
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        console.log("T2TUSD proxy: %s", address(proxy));

        // 5. Collega MasterMinter al token
        masterMinter.setToken(address(proxy));

        vm.stopBroadcast();

        console.log("=== DEPLOY COMPLETE ===");
        console.log("T2TUSD (proxy): %s", address(proxy));
        console.log("MasterMinter:  %s", address(masterMinter));
        console.log("MockUSDC:      %s", address(mockUsdc));
        console.log("MockUSDT:      %s", address(mockUsdt));
    }
}
