// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {T2TRouter} from "../contracts/v4/T2TRouter.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract AddLiquidity is Script {
    function run() external {
        address router = vm.envAddress("ROUTER_ADDRESS");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address timp = vm.envAddress("TIMP_ADDRESS");
        address mockUsdc = vm.envAddress("MOCK_USDC_ADDRESS");
        address deployer = vm.envAddress("DEPLOYER");

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

        MockUSDC(mockUsdc).mint(deployer, 1_000_000 * 10 ** 6);
        IERC20(timp).approve(router, type(uint256).max);
        IERC20(mockUsdc).approve(router, type(uint256).max);
        console2.log("Approved router");

        // Range intorno al tick corrente del pool.
        // tickSpacing = 60, quindi tickLower/tickUpper devono essere
        // multipli di 60.
        int24 tickLower;
        int24 tickUpper;
        int24 currentTick;
        if (uint160(timp) < uint160(mockUsdc)) {
            // token0 = tTwoTrader (18 dec), token1 = MockUSDC (6 dec)
            // 1 tTwoTrader = 1 USDC in valore -> tick ~ -276324
            currentTick = -276324;
            // Range ampio: ±10000 tick (circa 2.7x in valore)
            tickLower = -286320;  // -276324 - 9996
            tickUpper = -266340;  // -276324 + 9984
        } else {
            // token0 = MockUSDC (6 dec), token1 = tTwoTrader (18 dec)
            // 1 USDC = 1 tTwoTrader in valore -> tick ~ 276324
            currentTick = 276324;
            tickLower = 266340;
            tickUpper = 286320;
        }

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(currentTick);
        // amount0/amount1 dipendono dall'ordine dei token nel PoolKey.
        // Il PoolKey ordina per indirizzo, non per decimali.
        uint256 amount0;
        uint256 amount1;
        if (uint160(timp) < uint160(mockUsdc)) {
            // token0 = tTwoTrader (18 dec), token1 = MockUSDC (6 dec)
            amount0 = 100_000 * 10 ** 18;
            amount1 = 100_000 * 10 ** 6;
        } else {
            // token0 = MockUSDC (6 dec), token1 = tTwoTrader (18 dec)
            amount0 = 100_000 * 10 ** 6;
            amount1 = 100_000 * 10 ** 18;
        }

        console2.log("Adding liquidity (range -60/+60)...");

        T2TRouter(router).addLiquidity(
            key,
            tickLower,
            tickUpper,
            amount0,
            amount1,
            sqrtPriceX96,
            deployer,
            block.timestamp + 600
        );

        console2.log("Liquidity added!");

        vm.stopBroadcast();
    }
}
