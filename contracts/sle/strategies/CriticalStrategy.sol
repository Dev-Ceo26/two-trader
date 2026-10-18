// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IStrategy} from "../interfaces/IStrategy.sol";

/// @title CriticalStrategy
/// @notice Strategia per regime CRITICAL. Fee alta (150 bps) + blocco
///         degli swap grandi (amountIn > reserveIn / 100).
/// @dev Immutabile, stateless. Soglia blocco: 1% della riserva del token d'ingresso.
contract CriticalStrategy is IStrategy {
    uint8 public constant REGIME_CRITICAL = 4;
    uint256 public constant CRITICAL_FEE_BPS = 150;
    uint256 public constant BLOCK_THRESHOLD_DIVISOR = 100;

    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        return CRITICAL_FEE_BPS;
    }

    /// @notice Blocca swap con amountIn > reserveIn / 100 (1% della riserva)
    function shouldBlock(
        bytes32,
        uint8,
        uint256 amountIn,
        uint256 reserveIn
    ) external pure override returns (bool) {
        if (reserveIn == 0) return true; // pool vuoto in CRITICAL = blocco totale
        return amountIn > (reserveIn / BLOCK_THRESHOLD_DIVISOR);
    }

    function name() external pure override returns (string memory) {
        return "CriticalStrategy";
    }

    function targetRegime() external pure override returns (uint8) {
        return REGIME_CRITICAL;
    }
}
