// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../contracts/test/MockToken.sol";

contract DeployMockToken is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        MockToken token = new MockToken("Mock USD", "mUSDC", 6);
        vm.stopBroadcast();
        console.log("MockToken:", address(token));
    }
}
