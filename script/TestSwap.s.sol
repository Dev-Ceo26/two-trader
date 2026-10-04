// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ImperiumRouter} from "../contracts/v4/ImperiumRouter.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract TestSwap is Script {
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

        // 1) Mint MockUSDC
        MockUSDC(mockUsdc).mint(deployer, 100 * 10 ** 6);
        console2.log("Minted 100 MockUSDC");

        // 2) Approva il router
        IERC20(mockUsdc).approve(router, type(uint256).max);

        // 3) SWAP REALE: 10 MockUSDC -> tIMP
        // L'ordine dei token dipende dagli indirizzi:
        //   token0 = tIMP   (0x0B30...)
        //   token1 = MockUSDC (0x6101...)
        // Quindi USDC e' token1. Per scambiare token1 -> token0:
        //   zeroForOne = false
        uint256 amountIn = 10 * 10 ** 6; // 10 MockUSDC

        console2.log("Swapping 10 MockUSDC (token1) for tIMP (token0)...");

        ImperiumRouter(router).swapExactInput(
            key,
            false,          // zeroForOne = false: token1 -> token0
            amountIn,       // amountIn
            0,              // amountOutMin
            deployer,       // recipient
            block.timestamp + 600
        );

        console2.log("Swap executed!");

        vm.stopBroadcast();
    }
}
