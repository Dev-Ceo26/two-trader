// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Faucet
 * @notice Rubinetto testnet: 1 tIMPR per wallet, 1 volta al giorno.
 * @dev Solo testnet. NON deployare in mainnet.
 */
contract Faucet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    uint256 public dripAmount;
    uint256 public cooldown;

    mapping(address => uint256) public lastClaim;

    event Dripped(address indexed user, uint256 amount, uint256 timestamp);
    event DripAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
    event Withdrawn(address indexed owner, uint256 amount);
    event Funded(address indexed from, uint256 amount);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        require(_token != address(0), "token zero");
        require(initialOwner != address(0), "owner zero");
        TOKEN = IERC20(_token);
        dripAmount = 1 * 10 ** 18; // 1 tIMPR
        cooldown = 1 days;
    }

    function setDripAmount(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = dripAmount;
        dripAmount = newAmount;
        emit DripAmountUpdated(oldAmount, newAmount);
    }

    function setCooldown(uint256 newCooldown) external onlyOwner {
        uint256 oldCooldown = cooldown;
        cooldown = newCooldown;
        emit CooldownUpdated(oldCooldown, newCooldown);
    }

    function drip() external nonReentrant {
        // forge-lint: disable-next-line(block-timestamp)
        require(block.timestamp >= lastClaim[msg.sender] + cooldown, "cooldown active");
        require(TOKEN.balanceOf(address(this)) >= dripAmount, "faucet empty");

        lastClaim[msg.sender] = block.timestamp;
        TOKEN.safeTransfer(msg.sender, dripAmount);

        emit Dripped(msg.sender, dripAmount, block.timestamp);
    }

    function canClaim(address user) external view returns (bool claimable, uint256 secondsLeft) {
        uint256 nextClaim = lastClaim[user] + cooldown;
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= nextClaim) {
            return (true, 0);
        }
        unchecked {
            return (false, nextClaim - block.timestamp);
        }
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "amount zero");
        TOKEN.safeTransfer(owner(), amount);
        emit Withdrawn(owner(), amount);
    }

    function fund(uint256 amount) external {
        require(amount > 0, "amount zero");
        TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(msg.sender, amount);
    }
}
