// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

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

        // Il prezzo dipende dall'ordine dei token nel PoolKey.
        // Per 1 tIMP = 1 USDC in valore:
        //   - se token0 = tIMP (18 dec), token1 = MockUSDC (6 dec)
        //     price = 1e6/1e18 = 1e-12, tick ~ -276324
        //   - se token0 = MockUSDC (6 dec), token1 = tIMP (18 dec)
        //     price = 1e18/1e6 = 1e12, tick ~ 276324
        int24 initialTick;
        if (uint160(timp) < uint160(mockUsdc)) {
            initialTick = -276324;
        } else {
            initialTick = 276324;
        }

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(initialTick);
        console2.log("Initial tick:", initialTick);
        console2.log("sqrtPriceX96:", uint256(sqrtPriceX96));

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
