// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {ICurve} from "../interfaces/ICurve.sol";
import {ISLEAddressProvider} from "../interfaces/ISLEAddressProvider.sol";
import {PoolRegistry} from "./PoolRegistry.sol";

/// @title PoolManager
/// @notice Core AMM SLE. Router = unico chiamante (letto dal provider).
/// @dev Provider immutable. onlyRouter legge provider.router() ad ogni chiamata.
///      Router non configurabile nel PM (nessun setter). Configurazione gestita dal provider.
contract PoolManager is IPoolManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant override MAX_FEE = 200;
    uint256 public constant MINIMUM_LIQUIDITY = 1_000;
    uint256 public constant PROPORTIONAL_TOLERANCE_BPS = 1;

    PoolRegistry public immutable registry;
    ISLEAddressProvider public immutable provider;

    struct PoolState {
        uint256 reserve0;
        uint256 reserve1;
        uint256 feeAccrued0;
        uint256 feeAccrued1;
        uint256 totalLPSupply;
    }

    mapping(bytes32 => PoolState) public poolStates;
    mapping(bytes32 => mapping(address => uint256)) public lpBalances;

    modifier onlyRouter() {
        if (msg.sender != provider.router()) revert UnauthorizedCaller(msg.sender);
        _;
    }

    constructor(address registry_, address provider_) {
        if (registry_ == address(0) || provider_ == address(0)) revert ZeroAddress();
        registry = PoolRegistry(registry_);
        provider = ISLEAddressProvider(provider_);
    }

    function router() external view override returns (address) {
        return provider.router();
    }

    function providerAddress() external view override returns (address) {
        return address(provider);
    }

    // ───────────── Swap ─────────────

    function swap(
        bytes32 poolId, bool zeroForOne, uint256 amountIn, uint256 minAmountOut,
        address recipient, uint256 deadline, uint256 feeBps, address payer
    ) external override onlyRouter nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired(deadline);
        if (amountIn == 0) revert ZeroAmount();
        if (feeBps > MAX_FEE) revert FeeTooHigh(feeBps, MAX_FEE);
        if (recipient == address(0) || payer == address(0)) revert ZeroAddress();

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (!pool.active) revert PoolNotActive(poolId);

        PoolState storage s = poolStates[poolId];
        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (s.reserve0, s.reserve1) : (s.reserve1, s.reserve0);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 feeAmount = Math.mulDiv(amountIn, feeBps, 10_000, Math.Rounding.Ceil);
        uint256 amountAfterFee = amountIn - feeAmount;
        if (amountAfterFee == 0) revert ZeroAmount();

        if (amountAfterFee > type(uint256).max - reserveIn) revert InsufficientLiquidity();
        uint256 denominator = reserveIn + amountAfterFee;

        uint256 maxOut = Math.mulDiv(reserveOut, amountAfterFee, denominator);
        amountOut = ICurve(pool.curve).getAmountOut(amountAfterFee, reserveIn, reserveOut);
        if (amountOut > maxOut) revert CurveOutputExceedsBound(amountOut, maxOut);
        if (amountOut < minAmountOut) revert SlippageExceeded(amountOut, minAmountOut);

        if (zeroForOne) {
            s.reserve0 += amountAfterFee;
            s.reserve1 -= amountOut;
            s.feeAccrued0 += feeAmount;
        } else {
            s.reserve1 += amountAfterFee;
            s.reserve0 -= amountOut;
            s.feeAccrued1 += feeAmount;
        }

        address tokenIn = zeroForOne ? pool.token0 : pool.token1;
        address tokenOut = zeroForOne ? pool.token1 : pool.token0;
        _safeTransferIn(IERC20(tokenIn), amountIn);
        IERC20(tokenOut).safeTransfer(recipient, amountOut);

        emit Swap(poolId, payer, zeroForOne, amountIn, amountOut, feeAmount, s.reserve0, s.reserve1);
    }

    // ───────────── Add / Remove ─────────────

    function addLiquidity(bytes32 poolId, uint256 amount0, uint256 amount1, address onBehalfOf)
        external override onlyRouter nonReentrant returns (uint256 lpMinted)
    {
        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();
        if (onBehalfOf == address(0)) revert ZeroAddress();

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (!pool.active) revert PoolNotActive(poolId);

        PoolState storage s = poolStates[poolId];

        if (s.totalLPSupply == 0) {
            if (amount1 > type(uint256).max / amount0) revert InsufficientLiquidity();
            uint256 root = Math.sqrt(amount0 * amount1);
            if (root <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            lpMinted = root - MINIMUM_LIQUIDITY;
            s.reserve0 = amount0;
            s.reserve1 = amount1;
            s.totalLPSupply = root;
        } else {
            if (s.reserve0 == 0 || s.reserve1 == 0) revert InsufficientLiquidity();
            if (!_proportionalEnough(amount0, s.reserve0, amount1, s.reserve1)) {
                revert InsufficientLiquidity();
            }
            uint256 lp0 = Math.mulDiv(amount0, s.totalLPSupply, s.reserve0);
            uint256 lp1 = Math.mulDiv(amount1, s.totalLPSupply, s.reserve1);
            lpMinted = lp0 < lp1 ? lp0 : lp1;
            if (lpMinted == 0) revert InsufficientLiquidity();
            s.reserve0 += amount0;
            s.reserve1 += amount1;
            s.totalLPSupply += lpMinted;
        }

        lpBalances[poolId][onBehalfOf] += lpMinted;
        _safeTransferIn(IERC20(pool.token0), amount0);
        _safeTransferIn(IERC20(pool.token1), amount1);

        emit LiquidityAdded(poolId, onBehalfOf, amount0, amount1, lpMinted);
    }

    function removeLiquidity(bytes32 poolId, uint256 lpAmount, address owner, address recipient)
        external override onlyRouter nonReentrant returns (uint256 amount0, uint256 amount1)
    {
        if (lpAmount == 0) revert ZeroAmount();
        if (owner == address(0) || recipient == address(0)) revert ZeroAddress();

        PoolState storage s = poolStates[poolId];
        uint256 totalSupply = s.totalLPSupply;
        if (totalSupply == 0) revert InsufficientLiquidity();
        if (lpAmount > lpBalances[poolId][owner]) revert InsufficientLiquidity();

        uint256 feeShare0 = Math.mulDiv(lpAmount, s.feeAccrued0, totalSupply);
        uint256 feeShare1 = Math.mulDiv(lpAmount, s.feeAccrued1, totalSupply);
        uint256 resShare0 = Math.mulDiv(lpAmount, s.reserve0, totalSupply);
        uint256 resShare1 = Math.mulDiv(lpAmount, s.reserve1, totalSupply);

        amount0 = feeShare0 + resShare0;
        amount1 = feeShare1 + resShare1;

        s.feeAccrued0 -= feeShare0;
        s.feeAccrued1 -= feeShare1;
        s.reserve0 -= resShare0;
        s.reserve1 -= resShare1;
        lpBalances[poolId][owner] -= lpAmount;
        s.totalLPSupply -= lpAmount;

        PoolRegistry.PoolInfo memory pool = registry.getPool(poolId);
        if (amount0 > 0) IERC20(pool.token0).safeTransfer(recipient, amount0);
        if (amount1 > 0) IERC20(pool.token1).safeTransfer(recipient, amount1);

        emit LiquidityRemoved(poolId, owner, recipient, amount0, amount1, lpAmount);
    }

    // ───────────── Interni ─────────────

    function _safeTransferIn(IERC20 token, uint256 amount) internal {
        uint256 before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.balanceOf(address(this)) - before != amount) revert FeeOnTransferNotSupported();
    }

    function _proportionalEnough(
        uint256 amount0, uint256 reserve0,
        uint256 amount1, uint256 reserve1
    ) internal pure returns (bool) {
        uint256 p0L;
        uint256 p0H;
        assembly {
            let mm := mulmod(amount0, reserve1, not(0))
            p0L := mul(amount0, reserve1)
            p0H := sub(sub(mm, p0L), lt(mm, p0L))
        }
        uint256 p1L;
        uint256 p1H;
        assembly {
            let mm := mulmod(amount1, reserve0, not(0))
            p1L := mul(amount1, reserve0)
            p1H := sub(sub(mm, p1L), lt(mm, p1L))
        }

        if (p0H == p1H && p0L == p1L) return true;

        bool p0Greater = p0H > p1H || (p0H == p1H && p0L > p1L);
        uint256 maxH = p0Greater ? p0H : p1H;
        uint256 maxL = p0Greater ? p0L : p1L;
        uint256 minH = p0Greater ? p1H : p0H;
        uint256 minL = p0Greater ? p1L : p0L;

        uint256 diffH;
        uint256 diffL;
        unchecked {
            diffL = maxL - minL;
            diffH = maxH - minH;
            if (maxL < minL) diffH -= 1;
        }

        uint256 quotientH = maxH / 10000;
        uint256 remainderH = maxH % 10000;

        uint256 qLow;
        uint256 rem = remainderH;
        for (uint256 i = 256; i > 0; ) {
            unchecked { --i; }
            uint256 bit = (maxL >> i) & 1;
            rem = rem * 2 + bit;
            if (rem >= 10000) {
                rem -= 10000;
                qLow |= uint256(1) << i;
            }
        }

        if (diffH < quotientH) return true;
        if (diffH > quotientH) return false;
        return diffL <= qLow;
    }

    // ───────────── Views ─────────────
    function getReserves(bytes32 poolId) external view override returns (uint256, uint256) {
        PoolState storage s = poolStates[poolId];
        return (s.reserve0, s.reserve1);
    }
    function getFeesAccrued(bytes32 poolId) external view override returns (uint256, uint256) {
        PoolState storage s = poolStates[poolId];
        return (s.feeAccrued0, s.feeAccrued1);
    }
    function getLPBalance(bytes32 poolId, address account) external view override returns (uint256) {
        return lpBalances[poolId][account];
    }
    function getTotalLPSupply(bytes32 poolId) external view override returns (uint256) {
        return poolStates[poolId].totalLPSupply;
    }
}
