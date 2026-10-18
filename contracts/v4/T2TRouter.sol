// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LiquidityAmounts} from "v4-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

contract T2TRouter is IUnlockCallback, Ownable, ReentrancyGuard {
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    using PoolIdLibrary for PoolKey;

    using SafeERC20 for IERC20;

    IPoolManager public immutable poolManager;
    mapping(address => bool) public isAllowedToken;
    mapping(bytes32 => bool) public isAllowedPool;
    mapping(bytes32 => bool) public isAllowedPair;
    bool public strictPoolMode = true;

    error NotPoolManager();
    error TokenNotAllowed(address token);
    error PoolNotAllowed(bytes32 poolId);
    error PairNotAllowed(address token0, address token1);
    error DeadlinePassed();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientOutput(uint256 received, uint256 minRequired);

    event TokenAllowed(address indexed token);
    event PoolAllowed(bytes32 indexed poolId);
    event PairAllowed(address indexed token0, address indexed token1);
    event SwapExecuted(address indexed sender, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed provider, bytes32 indexed poolId, uint128 liquidity);

    struct SwapCallbackData {
        PoolKey key;
        IPoolManager.SwapParams params;
        address payer;
        address recipient;
    }

    struct AddLiquidityCallbackData {
        PoolKey key;
        IPoolManager.ModifyLiquidityParams params;
        address payer;
    }

    constructor(IPoolManager _poolManager, address _initialOwner) Ownable(_initialOwner) {
        if (address(_poolManager) == address(0)) revert ZeroAddress();
        poolManager = _poolManager;
    }

    function allowToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        isAllowedToken[token] = true;
        emit TokenAllowed(token);
    }

    function allowPair(address tokenA, address tokenB) external onlyOwner {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        isAllowedPair[_pairHash(tokenA, tokenB)] = true;
        emit PairAllowed(tokenA, tokenB);
    }

    function allowPool(PoolKey calldata key) external onlyOwner {
        isAllowedPool[PoolId.unwrap(key.toId())] = true;
        emit PoolAllowed(PoolId.unwrap(key.toId()));
    }

    /// @notice Aggiunge liquidità CALCOLANDO la liquidità dagli importi
    function addLiquidity(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (BalanceDelta delta) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (amount0 == 0 && amount1 == 0) revert InvalidAmount();

        _validatePool(key);

        // CALCOLA la liquidità dagli importi (matematica Uniswap v4)
        uint160 sqrtPriceLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        if (liquidity == 0) revert InvalidAmount();

        bytes memory data = abi.encodePacked(
            bytes1(0x02),
            abi.encode(
                AddLiquidityCallbackData({
                    key: key,
                    params: IPoolManager.ModifyLiquidityParams({
                        tickLower: tickLower,
                        tickUpper: tickUpper,
                        liquidityDelta: int128(liquidity),
                        salt: 0
                    }),
                    payer: msg.sender
                })
            )
        );

        delta = abi.decode(poolManager.unlock(data), (BalanceDelta));

        emit LiquidityAdded(msg.sender, PoolId.unwrap(key.toId()), liquidity);
    }


    function swapExactInput(
        PoolKey calldata key,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (BalanceDelta delta) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (amountIn == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();

        _validatePool(key);

        bytes memory data = abi.encodePacked(
            bytes1(0x01),
            abi.encode(
                SwapCallbackData({
                    key: key,
                    params: IPoolManager.SwapParams({
                        zeroForOne: zeroForOne,
                        amountSpecified: -int256(amountIn),
                        sqrtPriceLimitX96: zeroForOne
                            ? 4295128740
                            : 1461446703485210103287273052203988822378723970341
                    }),
                    payer: msg.sender,
                    recipient: recipient
                })
            )
        );

        delta = abi.decode(poolManager.unlock(data), (BalanceDelta));

        int128 outputAmount = zeroForOne ? delta.amount1() : delta.amount0();
        uint256 received = outputAmount > 0 ? uint256(uint128(outputAmount)) : 0;
        if (received < amountOutMin) revert InsufficientOutput(received, amountOutMin);

        emit SwapExecuted(msg.sender, amountIn, received);
    }

    function unlockCallback(bytes calldata rawData) external onlyPoolManager returns (bytes memory) {
        bytes1 op = rawData[0];
        
        if (op == 0x01) {
            // Swap
            SwapCallbackData memory data = abi.decode(rawData[1:], (SwapCallbackData));
            BalanceDelta delta = poolManager.swap(data.key, data.params, "");
            _settleDeltas(data.key, data.payer, data.recipient, delta);
            return abi.encode(delta);
        } else if (op == 0x02) {
            // Add liquidity
            AddLiquidityCallbackData memory data = abi.decode(rawData[1:], (AddLiquidityCallbackData));
            (BalanceDelta delta, ) = poolManager.modifyLiquidity(data.key, data.params, "");
            _settleDeltas(data.key, data.payer, data.payer, delta);
            return abi.encode(delta);
        } else {
            revert InvalidAmount();
        }
    }

    function _validatePool(PoolKey calldata key) internal view {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        if (!isAllowedToken[token0]) revert TokenNotAllowed(token0);
        if (!isAllowedToken[token1]) revert TokenNotAllowed(token1);
        if (!isAllowedPair[_pairHash(token0, token1)]) revert PairNotAllowed(token0, token1);
        if (strictPoolMode && !isAllowedPool[PoolId.unwrap(key.toId())]) revert PoolNotAllowed(PoolId.unwrap(key.toId()));
    }

    function _pairHash(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address t0, address t1) = uint160(tokenA) < uint160(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(t0, t1));
    }

    function _settleDeltas(PoolKey memory key, address payer, address recipient, BalanceDelta delta) internal {
        int128 a0 = delta.amount0();
        int128 a1 = delta.amount1();
        if (a0 < 0) { poolManager.sync(key.currency0); IERC20(Currency.unwrap(key.currency0)).safeTransferFrom(payer, address(poolManager), uint128(-a0)); poolManager.settle(); }
        if (a1 < 0) { poolManager.sync(key.currency1); IERC20(Currency.unwrap(key.currency1)).safeTransferFrom(payer, address(poolManager), uint128(-a1)); poolManager.settle(); }
        if (a0 > 0) poolManager.take(key.currency0, recipient, uint128(a0));
        if (a1 > 0) poolManager.take(key.currency1, recipient, uint128(a1));
    }
}
