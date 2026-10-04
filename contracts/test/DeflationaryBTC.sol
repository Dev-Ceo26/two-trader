// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DeflationaryBTC is ERC20, ERC20Permit, ERC1363, Ownable2Step, Pausable, ReentrancyGuard {
    uint256 public constant INITIAL_SUPPLY = 250_000_000 * 10**18;
    uint256 public constant FINAL_SUPPLY = 21_000_000 * 10**18;
    uint256 public constant TAX_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;

    bool public burnActive;
    uint256 public totalBurned;
    uint256 public lastBurnCheck;

    event BurnExecuted(address indexed from, uint256 amount);
    event BurnDeactivated(uint256 finalSupply);
    event TokensRescued(address token, uint256 amount);

    constructor(address recipient)
        ERC20("DeflationaryBTC", "DBTC")
        ERC20Permit("DeflationaryBTC")
        Ownable(msg.sender)
    {
        require(recipient != address(0), "DeflationaryBTC: zero address");
        _mint(recipient, INITIAL_SUPPLY);
        burnActive = true;
        lastBurnCheck = block.timestamp;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (value == 0) {
            super._update(from, to, 0);
            return;
        }

        if (paused()) {
            revert("DeflationaryBTC: paused");
        }

        uint256 tax = 0;
        if (burnActive && from != address(0) && to != address(0)) {
            tax = (value * TAX_BPS) / BPS_DENOMINATOR;
            if (tax > 0) {
                uint256 newSupply = totalSupply() - tax;
                if (newSupply < FINAL_SUPPLY) {
                    uint256 burnable = totalSupply() - FINAL_SUPPLY;
                    if (burnable > 0) {
                        super._update(from, address(0), burnable);
                        totalBurned += burnable;
                        emit BurnExecuted(from, burnable);
                    }
                    burnActive = false;
                    emit BurnDeactivated(FINAL_SUPPLY);
                    tax = 0;
                } else {
                    super._update(from, address(0), tax);
                    totalBurned += tax;
                    emit BurnExecuted(from, tax);
                }
            }
        }
        super._update(from, to, value - tax);
    }

    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "DeflationaryBTC: zero amount");
        require(balanceOf(msg.sender) >= amount, "DeflationaryBTC: insufficient balance");
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit BurnExecuted(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getBurnStatus() external view returns (bool active, uint256 remainingToBurn, uint256 totalSupply_) {
        totalSupply_ = totalSupply();
        active = burnActive;
        remainingToBurn = totalSupply_ > FINAL_SUPPLY ? totalSupply_ - FINAL_SUPPLY : 0;
    }

    function getNetAmount(uint256 grossAmount) external view returns (uint256) {
        if (!burnActive) return grossAmount;
        uint256 tax = (grossAmount * TAX_BPS) / BPS_DENOMINATOR;
        return grossAmount - tax;
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "DeflationaryBTC: cannot rescue self");
        if (token == address(0)) {
            (bool success, ) = owner().call{value: amount}("");
            require(success, "DeflationaryBTC: ETH transfer failed");
        } else {
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSelector(0xa9059cbb, owner(), amount)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "DeflationaryBTC: transfer failed");
        }
        emit TokensRescued(token, amount);
    }
}
