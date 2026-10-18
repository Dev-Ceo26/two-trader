// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IT2TRouter
/// @notice Interfaccia del Router. Unico entry point per swap/add/remove.
/// @dev Legge il PoolManager dal provider. L'utente approva il Router, non il PM.
interface IT2TRouter {
    event SwapExecuted(bytes32 indexed poolId, address indexed payer, address indexed recipient, bool zeroForOne, uint256 amountIn, uint256 amountOut, uint256 feeBps);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider, uint256 amount0, uint256 amount1, uint256 lpMinted);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed owner, address indexed recipient, uint256 lpBurned, uint256 amount0, uint256 amount1);

    error BlockedByStrategy(bytes32 poolId);
    error DeadlineExpired(uint256 deadline);
    error ZeroAmount();
    error ZeroAddress();
    error FeeOnTransferNotSupported();
    error InvalidPool(bytes32 poolId);
    error ProviderNotConfigured();

    function swap(bytes32 poolId, bool zeroForOne, uint256 amountIn, uint256 minAmountOut, address recipient, uint256 deadline) external returns (uint256 amountOut);
    function addLiquidity(bytes32 poolId, uint256 amount0, uint256 amount1) external returns (uint256 lpMinted);
    function removeLiquidity(bytes32 poolId, uint256 lpAmount, address recipient) external returns (uint256 amount0, uint256 amount1);
}
