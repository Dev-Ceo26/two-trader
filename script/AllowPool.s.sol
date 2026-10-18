// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {T2TRouter} from "../contracts/v4/T2TRouter.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

contract AllowPool is Script {
    function run() external {
        address router = vm.envAddress("ROUTER_ADDRESS");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address timp = vm.envAddress("TIMP_ADDRESS");
        address mockUsdc = vm.envAddress("MOCK_USDC_ADDRESS");

        address token0 = uint160(timp) < uint160(mockUsdc) ? timp : mockUsdc;
        address token1 = uint160(timp) < uint160(mockUsdc) ? mockUsdc : timp;

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        vm.startBroadcast();
        T2TRouter(router).allowPool(key);
        console2.log("Pool allowed:");
        console2.log("  token0:", token0);
        console2.log("  token1:", token1);
        vm.stopBroadcast();
    }
}
