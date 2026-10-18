// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IT2TRouter} from "../interfaces/IT2TRouter.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {IStrategySelector} from "../interfaces/IStrategySelector.sol";
import {ISLEAddressProvider} from "../interfaces/ISLEAddressProvider.sol";
import {PoolRegistry} from "./PoolRegistry.sol";

/// @title T2TRouter
/// @notice Router ufficiale di SLE. Unico entry point autorizzato dal PoolManager.
/// @dev Legge PoolManager da provider.poolManager() ad ogni chiamata.
///      Flusso: transferFrom(user->router), forceApprove(pm), pm.xxx, reset approve.
///      Se pm.xxx reverte, l'intera tx viene annullata (atomicità EVM).
contract T2TRouter is IT2TRouter, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISLEAddressProvider public immutable provider;
    IStrategySelector public immutable selector;
    PoolRegistry public immutable registry;

    constructor(address _provider, address _selector, address _registry) {
        if (_provider == address(0) || _selector == address(0) || _registry == address(0)) revert ZeroAddress();
        provider = ISLEAddressProvider(_provider);
        selector = IStrategySelector(_selector);
        registry = PoolRegistry(_registry);
    }

    // ───────────── Swap ─────────────

    function swap(
        bytes32 poolId, bool zeroForOne, uint256 amountIn, uint256 minAmountOut,
        address recipient, uint256 deadline
    ) external override nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address pmAddr = provider.poolManager();
        if (pmAddr == address(0)) revert ProviderNotConfigured();
        IPoolManager pm = IPoolManager(pmAddr);

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (pool.curve == address(0)) revert InvalidPool(poolId);

        (uint256 r0, uint256 r1) = pm.getReserves(poolId);
        uint256 reserveIn = zeroForOne ? r0 : r1;

        (uint256 feeBps, bool blocked) = selector.selectForSwap(poolId, amountIn, reserveIn);
        if (blocked) revert BlockedByStrategy(poolId);

        address tokenIn = zeroForOne ? pool.token0 : pool.token1;

        _safeTransferIn(IERC20(tokenIn), amountIn);
        IERC20(tokenIn).forceApprove(pmAddr, amountIn);
        amountOut = pm.swap(poolId, zeroForOne, amountIn, minAmountOut, recipient, deadline, feeBps, msg.sender);
        IERC20(tokenIn).forceApprove(pmAddr, 0);

        emit SwapExecuted(poolId, msg.sender, recipient, zeroForOne, amountIn, amountOut, feeBps);
    }

    // ───────────── Add Liquidity ─────────────

    function addLiquidity(bytes32 poolId, uint256 amount0, uint256 amount1)
        external override nonReentrant returns (uint256 lpMinted)
    {
        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();

        address pmAddr = provider.poolManager();
        if (pmAddr == address(0)) revert ProviderNotConfigured();
        IPoolManager pm = IPoolManager(pmAddr);

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (pool.curve == address(0)) revert InvalidPool(poolId);

        _safeTransferIn(IERC20(pool.token0), amount0);
        _safeTransferIn(IERC20(pool.token1), amount1);

        IERC20(pool.token0).forceApprove(pmAddr, amount0);
        IERC20(pool.token1).forceApprove(pmAddr, amount1);

        lpMinted = pm.addLiquidity(poolId, amount0, amount1, msg.sender);

        IERC20(pool.token0).forceApprove(pmAddr, 0);
        IERC20(pool.token1).forceApprove(pmAddr, 0);

        emit LiquidityAdded(poolId, msg.sender, amount0, amount1, lpMinted);
    }

    // ───────────── Remove Liquidity ─────────────

    function removeLiquidity(bytes32 poolId, uint256 lpAmount, address recipient)
        external override nonReentrant returns (uint256 amount0, uint256 amount1)
    {
        if (lpAmount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address pmAddr = provider.poolManager();
        if (pmAddr == address(0)) revert ProviderNotConfigured();
        IPoolManager pm = IPoolManager(pmAddr);

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (pool.curve == address(0)) revert InvalidPool(poolId);

        (amount0, amount1) = pm.removeLiquidity(poolId, lpAmount, msg.sender, recipient);

        emit LiquidityRemoved(poolId, msg.sender, recipient, lpAmount, amount0, amount1);
    }

    // ───────────── Interni ─────────────

    function _safeTransferIn(IERC20 token, uint256 amount) internal {
        uint256 before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.balanceOf(address(this)) - before != amount) revert FeeOnTransferNotSupported();
    }
}
