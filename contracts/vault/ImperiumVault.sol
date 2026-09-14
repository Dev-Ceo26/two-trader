// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ImperiumVault
 * @notice Tesoreria della DAO. Custodisce fondi nativi e ERC20.
 * @dev UUPS upgradable, Ownable (transitorio). In futuro: DAO.
 */
contract ImperiumVault is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    event FundsReceived(address indexed token, address indexed from, uint256 amount);
    event FundsSent(address indexed token, address indexed to, uint256 amount);
    event NativeReceived(address indexed from, uint256 amount);
    event NativeSent(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        require(initialOwner != address(0), "owner zero");
        __Ownable_init(initialOwner);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    function sendERC20(address token, address to, uint256 amount)
        external
        nonReentrant
        onlyOwner
    {
        require(token != address(0), "token zero");
        require(to != address(0), "to zero");
        IERC20(token).safeTransfer(to, amount);
        emit FundsSent(token, to, amount);
    }

    function sendNative(address payable to, uint256 amount)
        external
        nonReentrant
        onlyOwner
    {
        require(to != address(0), "to zero");
        // forge-lint: disable-next-line(arbitrary-send-eth)
        // forge-lint: disable-next-line(arbitrary-send-eth)
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "transfer failed");  
        emit NativeSent(to, amount);
    }
}
