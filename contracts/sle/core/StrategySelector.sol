// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategySelector} from "../interfaces/IStrategySelector.sol";
import {IRegimeDetector} from "../interfaces/IRegimeDetector.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

/// @title StrategySelector
/// @notice Decide fee e blocco per ogni swap. Applica la matrice
///         fail-open/fail-closed secondo specifica SLE §7.3.
/// @dev Immutabile. Owner = Timelock. Le strategie sono registrate per regime.
///      Il Router chiama selectForSwap(), poi passa fee+blocked al PoolManager.
contract StrategySelector is IStrategySelector, Ownable {
    // ───────────── Costanti ─────────────
    uint256 public constant DEFAULT_FEE = 30;
    uint256 public constant MAX_FEE = 200;

    uint8 public constant REGIME_CALM = 0;
    uint8 public constant REGIME_VOLATILE = 1;
    uint8 public constant REGIME_CRITICAL = 4;

    // ───────────── Immutables ─────────────
    IRegimeDetector public immutable detector;

    // ───────────── Storage ─────────────
    mapping(uint8 => address) public strategies;

    // ───────────── Events ─────────────
    event StrategyRegistered(uint8 indexed regime, address strategy);
    event StrategyUnregistered(uint8 indexed regime);

    // ───────────── Errors ─────────────
    error ZeroAddress();
    error InvalidRegime();

    constructor(address _detector, address initialOwner) Ownable(initialOwner) {
        if (_detector == address(0)) revert ZeroAddress();
        detector = IRegimeDetector(_detector);
    }

    // ───────────── Governance ─────────────

    /// @notice Registra la strategia per un regime
    /// @dev Solo owner. Regimi ammessi: 0, 1, 4.
    function setStrategy(uint8 regime, address strategy) external onlyOwner {
        if (regime != REGIME_CALM && regime != REGIME_VOLATILE && regime != REGIME_CRITICAL) {
            revert InvalidRegime();
        }
        if (strategy == address(0)) revert ZeroAddress();
        strategies[regime] = strategy;
        emit StrategyRegistered(regime, strategy);
    }

    /// @notice Rimuove la strategia per un regime
    function unregisterStrategy(uint8 regime) external onlyOwner {
        delete strategies[regime];
        emit StrategyUnregistered(regime);
    }

    // ───────────── Core ─────────────

    /// @inheritdoc IStrategySelector
    function selectForSwap(
        bytes32 poolId,
        uint256 amountIn,
        uint256 reserveIn
    ) external view override returns (uint256 feeBps, bool shouldBlock) {
        // 1. Leggi regime (try/catch sul detector)
        uint8 regime;
        bool isValid;
        try detector.getMarketState(poolId) returns (uint8 r, uint256, bool v) {
            regime = r;
            isValid = v;
        } catch {
            // Detector revert -> fail-closed
            return (0, true);
        }

        // 2. Detector non valido (stale o mai aggiornato) -> fail-closed
        if (!isValid) {
            return (0, true);
        }

        // 3. CRITICAL: strategia obbligatoria, se reverte -> fail-closed
        if (regime == REGIME_CRITICAL) {
            address strat = strategies[REGIME_CRITICAL];
            if (strat == address(0)) {
                // Nessuna strategia critical registrata -> fail-closed
                return (0, true);
            }

            try IStrategy(strat).proposeFee(poolId, regime, amountIn) returns (uint256 f) {
                uint256 clampedFee = f > MAX_FEE ? MAX_FEE : f;

                try IStrategy(strat).shouldBlock(poolId, regime, amountIn, reserveIn) returns (bool b) {
                    return (clampedFee, b);
                } catch {
                    // shouldBlock fallito -> fail-closed
                    return (0, true);
                }
            } catch {
                // proposeFee fallito -> fail-closed
                return (0, true);
            }
        }

        // 4. CALM / VOLATILE: strategia opzionale, se reverte -> DEFAULT_FEE (fail-open)
        address strat = strategies[regime];
        if (strat == address(0)) {
            // Nessuna strategia registrata per questo regime -> DEFAULT_FEE
            return (DEFAULT_FEE, false);
        }

        try IStrategy(strat).proposeFee(poolId, regime, amountIn) returns (uint256 f) {
            uint256 clampedFee = f > MAX_FEE ? MAX_FEE : f;

            try IStrategy(strat).shouldBlock(poolId, regime, amountIn, reserveIn) returns (bool b) {
                return (clampedFee, b);
            } catch {
                // shouldBlock fallito in regime non critico -> DEFAULT_FEE
                return (DEFAULT_FEE, false);
            }
        } catch {
            // proposeFee fallito in regime non critico -> DEFAULT_FEE
            return (DEFAULT_FEE, false);
        }
    }
}
