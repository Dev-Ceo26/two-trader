// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GuardianRegistry} from "../governance/GuardianRegistry.sol";

/// @title T2THooks
/// @notice Uniswap v4 hook per Two-Trader Chain.
///         Implementa beforeSwap + afterSwap.
///         Bit richiesti: BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG = 0xC0.
/// @dev IMMUTABILE. L'indirizzo deve avere i bit 0xC0, ottenuti via CREATE2 + HookMiner.
///      Upgradability non compatibile con il pattern proxy perché il PoolManager
///      verifica i bit dell'indirizzo dell'hook. Migrazione futura: Diamond (EIP-2535).
contract T2THooks is IHooks, Ownable, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;

    // ───────────── Errors ─────────────
    error HookNotImplemented();
    error NotPoolManager();
    error ZeroAddress();

    // ───────────── Immutables ─────────────
    IPoolManager public immutable poolManager;
    GuardianRegistry public guardianRegistry;

    // ───────────── Storage ─────────────
    struct PoolStats {
        uint256 swapCount;
        uint256 volume0;
        uint256 volume1;
        uint256 lastSwapBlock;
    }

    mapping(PoolId => PoolStats) public poolStats;
    mapping(address => uint256) public guardianRewards;

    uint256 public totalSwaps;
    uint256 public totalGuardianRewards;
    uint256 public guardianRewardPerSwap;

    // ───────────── Events ─────────────
    event SwapRecorded(PoolId indexed id, address indexed sender, int128 amount0, int128 amount1);
    event GuardianRewardAccrued(address indexed guardian, uint256 amount, PoolId indexed id);
    event GuardianRewardPerSwapUpdated(uint256 oldValue, uint256 newValue);

    // ───────────── Modifiers ─────────────
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @notice Deploy diretto con CREATE2 per garantire i bit 0xC0
    constructor(IPoolManager _poolManager, GuardianRegistry _guardianRegistry, address _initialOwner)
        Ownable(_initialOwner)
    {
        if (address(_poolManager) == address(0)) revert ZeroAddress();
        if (address(_guardianRegistry) == address(0)) revert ZeroAddress();
        if (_initialOwner == address(0)) revert ZeroAddress();

        poolManager = _poolManager;
        guardianRegistry = _guardianRegistry;
        guardianRewardPerSwap = 1e15; // 0.001 token
    }

    // =============================================================
    //                    CALLBACKS IMPLEMENTATI
    // =============================================================

    /// @inheritdoc IHooks
    function beforeSwap(
        address /*sender*/,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata /*params*/,
        bytes calldata hookData
    ) external override onlyPoolManager nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId id = key.toId();
        PoolStats storage s = poolStats[id];
        unchecked {
            s.swapCount++;
            totalSwaps++;
        }
        s.lastSwapBlock = block.number;

        if (hookData.length >= 32) {
            address guardian = abi.decode(hookData, (address));
            _accrueGuardianReward(guardian, id);
        }

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @inheritdoc IHooks
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata /*params*/,
        BalanceDelta delta,
        bytes calldata /*hookData*/
    ) external override onlyPoolManager nonReentrant returns (bytes4, int128) {
        PoolId id = key.toId();
        PoolStats storage s = poolStats[id];

        int128 a0 = delta.amount0();
        int128 a1 = delta.amount1();

        if (a0 > 0) {
            unchecked { s.volume0 += uint128(a0); }
        } else if (a0 < 0) {
            unchecked { s.volume0 += uint128(-a0); }
        }
        if (a1 > 0) {
            unchecked { s.volume1 += uint128(a1); }
        } else if (a1 < 0) {
            unchecked { s.volume1 += uint128(-a1); }
        }

        emit SwapRecorded(id, sender, a0, a1);
        return (IHooks.afterSwap.selector, 0);
    }

    // =============================================================
    //                  CALLBACKS NON IMPLEMENTATI
    // =============================================================

    function beforeInitialize(address, PoolKey calldata, uint160)
        external view override onlyPoolManager returns (bytes4)
    {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external view override onlyPoolManager returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta, BalanceDelta, bytes calldata
    ) external view override onlyPoolManager returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeRemoveLiquidity(
        address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta, BalanceDelta, bytes calldata
    ) external view override onlyPoolManager returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeDonate(
        address, PoolKey calldata, uint256, uint256, bytes calldata
    ) external view override onlyPoolManager returns (bytes4) { revert HookNotImplemented(); }

    function afterDonate(
        address, PoolKey calldata, uint256, uint256, bytes calldata
    ) external view override onlyPoolManager returns (bytes4) { revert HookNotImplemented(); }

    // =============================================================
    //                     LOGICA INTERNA
    // =============================================================

    function _accrueGuardianReward(address guardian, PoolId id) internal {
        if (guardian == address(0)) return;

        (address gAddr, , , , bool active) = guardianRegistry.guardians(guardian);
        if (!active || gAddr == address(0)) return;

        uint256 reward = guardianRewardPerSwap;
        if (reward == 0) return;

        unchecked {
            guardianRewards[guardian] += reward;
            totalGuardianRewards += reward;
        }

        emit GuardianRewardAccrued(guardian, reward, id);
    }

    // =============================================================
    //                     ADMIN / VIEW
    // =============================================================

    function setGuardianRegistry(GuardianRegistry _registry) external onlyOwner {
        if (address(_registry) == address(0)) revert ZeroAddress();
        guardianRegistry = _registry;
    }

    function setGuardianRewardPerSwap(uint256 newValue) external onlyOwner {
        uint256 old = guardianRewardPerSwap;
        guardianRewardPerSwap = newValue;
        emit GuardianRewardPerSwapUpdated(old, newValue);
    }

    function getPoolStats(PoolId id) external view returns (PoolStats memory) {
        return poolStats[id];
    }
}
