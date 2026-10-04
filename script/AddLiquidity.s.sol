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

        // Range PICCOLO: -60, +60 (0.30% fee)
        int24 tickLower = -60;
        int24 tickUpper = 60;

        uint160 sqrtPriceX96 = 79228162514264337593543950336;
        uint256 amount0 = 1_000 * 10 ** 6;   // 1000 MockUSDC
        uint256 amount1 = 1_000 * 10 ** 18;  // 1000 tIMP

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
