// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRegimeDetector} from "../interfaces/IRegimeDetector.sol";

/// @title RegimeDetector
/// @notice Rileva il regime di mercato per ogni pool.
///         update() scrive osservazioni e calcola il regime.
///         getMarketState() legge lo stato e verifica staleness.
/// @dev Immutabile. In produzione owner = Timelock.
///      Isteresi per evitare flip-flop. Fail-closed se stale.
contract RegimeDetector is IRegimeDetector, Ownable {
    // ───────────── Costanti regime ─────────────
    uint8 public constant REGIME_CALM = 0;
    uint8 public constant REGIME_VOLATILE = 1;
    uint8 public constant REGIME_CRITICAL = 4;

    // ───────────── Parametri (aggiornabili solo via timelock) ─────────────
    uint256 public volatilityThresholdLow = 100;
    uint256 public volatilityThresholdHigh = 200;
    uint256 public criticalDumpThreshold = 1000;
    uint256 public criticalVolumeMultiplier = 3;
    uint256 public detectorStalenessBlocks = 100;
    uint256 public calmToVolatileMinStreak = 3;
    uint256 public volatileToCalmMinStreak = 10;
    uint256 public criticalExitStreak = 10;

    // ───────────── Stato per pool ─────────────
    struct PoolRegime {
        uint8 currentRegime;
        uint256 lastUpdatedBlock;
        uint256 lastPrice;
        uint256 streakCount;
        uint256 observationsCount;
        uint256 totalVolume;
    }

    mapping(bytes32 => PoolRegime) public regimes;

    // ───────────── Events ─────────────
    event RegimeUpdated(bytes32 indexed poolId, uint8 oldRegime, uint8 newRegime, uint256 price, uint256 volume);
    event ParametersUpdated();

    // ───────────── Errors ─────────────
    error ZeroAddress();
    error ZeroReserves();
    error InvalidParameter();

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ───────────── Update ─────────────

    function update(
        bytes32 poolId,
        uint256 reserve0,
        uint256 reserve1,
        uint256 volume0
    ) external returns (uint8 newRegime) {
        if (reserve0 == 0 || reserve1 == 0) revert ZeroReserves();

        uint256 currentPrice = (reserve1 * 1e18) / reserve0;

        PoolRegime storage r = regimes[poolId];
        uint8 oldRegime = r.currentRegime;

        uint256 volatility = _computeVolatility(r.lastPrice, currentPrice);
        uint256 dump = _computeDump(r.lastPrice, currentPrice);

        uint8 computedRegime = _classifyRegime(r, volatility, dump, volume0);

        newRegime = _applyHysteresis(r, oldRegime, computedRegime);

        r.currentRegime = newRegime;
        r.lastUpdatedBlock = block.number;
        r.lastPrice = currentPrice;
        r.totalVolume += volume0;
        r.observationsCount++;

        emit RegimeUpdated(poolId, oldRegime, newRegime, currentPrice, volume0);
    }

    // ───────────── View ─────────────

    function getMarketState(bytes32 poolId)
        external
        view
        override
        returns (uint8 regime, uint256 lastUpdatedBlock, bool isValid)
    {
        PoolRegime storage r = regimes[poolId];
        lastUpdatedBlock = r.lastUpdatedBlock;

        if (lastUpdatedBlock == 0) {
            return (REGIME_CRITICAL, 0, false);
        }

        if (block.number - lastUpdatedBlock > detectorStalenessBlocks) {
            return (REGIME_CRITICAL, lastUpdatedBlock, false);
        }

        return (r.currentRegime, lastUpdatedBlock, true);
    }

    // ───────────── Admin ─────────────

    function setParameters(
        uint256 _volLow,
        uint256 _volHigh,
        uint256 _critDump,
        uint256 _critVolMult,
        uint256 _staleness
    ) external onlyOwner {
        if (_volLow >= _volHigh) revert InvalidParameter();
        if (_critDump <= _volHigh) revert InvalidParameter();
        if (_critVolMult == 0) revert InvalidParameter();
        if (_staleness == 0) revert InvalidParameter();

        volatilityThresholdLow = _volLow;
        volatilityThresholdHigh = _volHigh;
        criticalDumpThreshold = _critDump;
        criticalVolumeMultiplier = _critVolMult;
        detectorStalenessBlocks = _staleness;

        emit ParametersUpdated();
    }

    // ───────────── Interni ─────────────

    function _computeVolatility(uint256 lastPrice, uint256 currentPrice) internal pure returns (uint256) {
        if (lastPrice == 0) return 0;
        uint256 diff = currentPrice > lastPrice ? currentPrice - lastPrice : lastPrice - currentPrice;
        return (diff * 10_000) / lastPrice;
    }

    function _computeDump(uint256 lastPrice, uint256 currentPrice) internal pure returns (uint256) {
        if (lastPrice == 0 || currentPrice >= lastPrice) return 0;
        return ((lastPrice - currentPrice) * 10_000) / lastPrice;
    }

    function _classifyRegime(
        PoolRegime storage r,
        uint256 volatility,
        uint256 dump,
        uint256 volume
    ) internal view returns (uint8) {
        uint256 avgVolume = r.observationsCount == 0 ? 0 : r.totalVolume / r.observationsCount;
        bool volumeAnomaly = avgVolume > 0 && volume > avgVolume * criticalVolumeMultiplier;

        if (dump >= criticalDumpThreshold && volumeAnomaly) {
            return REGIME_CRITICAL;
        }

        if (volatility >= volatilityThresholdHigh) {
            return REGIME_VOLATILE;
        }

        return REGIME_CALM;
    }

    function _applyHysteresis(
        PoolRegime storage r,
        uint8 oldRegime,
        uint8 computedRegime
    ) internal returns (uint8) {
        if (computedRegime != oldRegime) {
            r.streakCount++;
        } else {
            r.streakCount = 0;
            return oldRegime;
        }

        if (oldRegime == REGIME_CALM && computedRegime == REGIME_VOLATILE) {
            if (r.streakCount >= calmToVolatileMinStreak) {
                r.streakCount = 0;
                return REGIME_VOLATILE;
            }
        } else if (oldRegime == REGIME_VOLATILE && computedRegime == REGIME_CALM) {
            if (r.streakCount >= volatileToCalmMinStreak) {
                r.streakCount = 0;
                return REGIME_CALM;
            }
        } else if (oldRegime == REGIME_VOLATILE && computedRegime == REGIME_CRITICAL) {
            r.streakCount = 0;
            return REGIME_CRITICAL;
        } else if (oldRegime == REGIME_CRITICAL) {
            if (r.streakCount >= criticalExitStreak) {
                r.streakCount = 0;
                return computedRegime;
            }
        } else {
            r.streakCount = 0;
            return computedRegime;
        }

        return oldRegime;
    }
}
