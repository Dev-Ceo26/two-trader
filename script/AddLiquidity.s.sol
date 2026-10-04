// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ImperiumRouter} from "../contracts/v4/ImperiumRouter.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
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

        // Range intorno al tick corrente del pool (276324).
        // tickSpacing = 60, quindi tickLower/tickUpper devono essere
        // multipli di 60.
        int24 tickLower = 276240;
        int24 tickUpper = 276420;

        // sqrtPriceX96 del pool: 2^96 * 1e6 (impostato in CreatePoolWithHook)
        uint160 sqrtPriceX96 = 79228162514264337593543950336000000;
        // amount0/amount1 dipendono dall'ordine dei token nel PoolKey.
        // Il PoolKey ordina per indirizzo, non per decimali.
        uint256 amount0;
        uint256 amount1;
        if (uint160(timp) < uint160(mockUsdc)) {
            // token0 = tIMP (18 dec), token1 = MockUSDC (6 dec)
            amount0 = 1_000 * 10 ** 18;
            amount1 = 1_000 * 10 ** 6;
        } else {
            // token0 = MockUSDC (6 dec), token1 = tIMP (18 dec)
            amount0 = 1_000 * 10 ** 6;
            amount1 = 1_000 * 10 ** 18;
        }

        console2.log("Adding liquidity (range -60/+60)...");

        ImperiumRouter(router).addLiquidity(
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
