// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IPoolManager
/// @notice Interfaccia del core AMM. Router è l'unico chiamante autorizzato
///         (letto dal provider). Fee <= MAX_FEE. LP a onBehalfOf.
interface IPoolManager {
    event Swap(bytes32 indexed poolId, address indexed payer, bool zeroForOne, uint256 amountIn, uint256 amountOut, uint256 feeAmount, uint256 reserve0, uint256 reserve1);
    event LiquidityAdded(bytes32 indexed poolId, address indexed onBehalfOf, uint256 amount0, uint256 amount1, uint256 lpMinted);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed owner, address indexed recipient, uint256 amount0, uint256 amount1, uint256 lpBurned);

    error PoolNotActive(bytes32 poolId);
    error CurveNotWhitelisted(address curve);
    error FeeTooHigh(uint256 feeBps, uint256 maxFee);
    error SlippageExceeded(uint256 amountOut, uint256 minAmountOut);
    error DeadlineExpired(uint256 deadline);
    error InsufficientLiquidity();
    error ZeroAmount();
    error ZeroAddress();
    error CurveOutputExceedsBound(uint256 amountOut, uint256 maxOut);
    error UnauthorizedCaller(address caller);
    error FeeOnTransferNotSupported();

    function swap(bytes32 poolId, bool zeroForOne, uint256 amountIn, uint256 minAmountOut, address recipient, uint256 deadline, uint256 feeBps, address payer) external returns (uint256 amountOut);
    function addLiquidity(bytes32 poolId, uint256 amount0, uint256 amount1, address onBehalfOf) external returns (uint256 lpMinted);
    function removeLiquidity(bytes32 poolId, uint256 lpAmount, address owner, address recipient) external returns (uint256 amount0, uint256 amount1);

    function getReserves(bytes32 poolId) external view returns (uint256 reserve0, uint256 reserve1);
    function getFeesAccrued(bytes32 poolId) external view returns (uint256 fee0, uint256 fee1);
    function getLPBalance(bytes32 poolId, address account) external view returns (uint256);
    function getTotalLPSupply(bytes32 poolId) external view returns (uint256);
    function MAX_FEE() external view returns (uint256);
    function router() external view returns (address);
    function providerAddress() external view returns (address);
}
