// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

contract CreatePoolWithHook is Script {
    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address timp = vm.envAddress("TIMP_ADDRESS");
        address mockUsdc = vm.envAddress("MOCK_USDC_ADDRESS");

        address token0 = uint160(timp) < uint160(mockUsdc) ? timp : mockUsdc;
        address token1 = uint160(timp) < uint160(mockUsdc) ? mockUsdc : timp;

        console2.log("Token0:", token0);
        console2.log("Token1:", token1);

        // Prezzo corretto: 1 USDC = 1 tIMP
        // amount1/amount0 = 1e18/1e6 = 1e12
        // sqrtPriceX96 = 2^96 * sqrt(1e12) = 2^96 * 1e6
        uint160 sqrtPriceX96 = 79228162514264337593543950336000000; // 2^96 * 1e6

        vm.startBroadcast();

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        int24 tick = IPoolManager(poolManager).initialize(pool, sqrtPriceX96);
        console2.log("Pool created! Tick:", tick);

        vm.stopBroadcast();
    }
}
