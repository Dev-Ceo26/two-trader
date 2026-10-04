// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ImperiumHooks} from "../contracts/v4/ImperiumHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {GuardianRegistry} from "../contracts/governance/GuardianRegistry.sol";
import {HookMiner} from "lib/v4-periphery/test/shared/HookMiner.sol";

contract HookMinerTest is Test {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function test_mine_0xC0() public view {
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        console2.log("Target flags:", flags);

        bytes memory creationCode = type(ImperiumHooks).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(0xBEEF)),
            GuardianRegistry(address(0xCAFE)),
            address(0xA11CE)
        );

        (address hookAddr, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, creationCode, constructorArgs);

        console2.log("Mined address:", hookAddr);
        console2.logBytes32(salt);

        uint160 masked = uint160(hookAddr) & Hooks.ALL_HOOK_MASK;
        assertEq(masked, flags, "flags mismatch");
        assertTrue(uint160(hookAddr) & 0x80 != 0, "bit 7 missing");
        assertTrue(uint160(hookAddr) & 0x40 != 0, "bit 6 missing");
    }
}
