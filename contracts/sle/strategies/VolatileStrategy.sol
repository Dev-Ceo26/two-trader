// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IStrategy} from "../interfaces/IStrategy.sol";

/// @title VolatileStrategy
/// @notice Strategia per regime VOLATILE / TRENDING_*.
///         Fee media (50 bps) per proteggere da sandwich.
///         Nessun blocco: gli utenti possono sempre uscire.
/// @dev Immutabile, stateless.
contract VolatileStrategy is IStrategy {
    uint8 public constant REGIME_VOLATILE = 1;
    uint256 public constant VOLATILE_FEE_BPS = 50;

    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        return VOLATILE_FEE_BPS;
    }

    function shouldBlock(bytes32, uint8, uint256, uint256) external pure override returns (bool) {
        return false;
    }

    function name() external pure override returns (string memory) {
        return "VolatileStrategy";
    }

    function targetRegime() external pure override returns (uint8) {
        return REGIME_VOLATILE;
    }
}
