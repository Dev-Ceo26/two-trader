// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IStrategy} from "../interfaces/IStrategy.sol";

/// @title CalmStrategy
/// @notice Strategia per regime CALM. Fee bassa (5 bps), nessun blocco.
///         Incentiva il volume quando il mercato è tranquillo.
/// @dev Immutabile, stateless, nessun parametro configurabile.
contract CalmStrategy is IStrategy {
    uint8 public constant REGIME_CALM = 0;
    uint256 public constant CALM_FEE_BPS = 5;

    function proposeFee(bytes32, uint8, uint256) external pure override returns (uint256) {
        return CALM_FEE_BPS;
    }

    function shouldBlock(bytes32, uint8, uint256, uint256) external pure override returns (bool) {
        return false;
    }

    function name() external pure override returns (string memory) {
        return "CalmStrategy";
    }

    function targetRegime() external pure override returns (uint8) {
        return REGIME_CALM;
    }
}
