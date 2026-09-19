// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable {
    uint8 private constant _DECIMALS = 6;

    constructor(address initialOwner)
        ERC20("Test USDC", "tUSDC")
        Ownable(initialOwner)
    {}

    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    /// @notice Mint libero per test (solo owner)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Mint libero per chiunque (solo testnet)
    function faucet(uint256 amount) external {
        require(amount <= 10_000 * 10**_DECIMALS, "MockUSDC: max 10k per faucet");
        _mint(msg.sender, amount);
    }
}
