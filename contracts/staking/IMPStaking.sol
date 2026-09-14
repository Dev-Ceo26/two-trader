// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title IMPStaking
 * @notice Stake IMP → diritto a IMPR 1:1 (whitelist DAO).
 * @dev UUPS upgradable, Ownable (transitorio). In futuro: DAO.
 *      Usa ReentrancyGuard stateless (OZ v5.7.0) invece di ReentrancyGuardUpgradeable.
 */
contract IMPStaking is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public impToken;
    uint256 public lockPeriod;

    struct Stake {
        uint256 amount;
        uint256 since;
        uint256 unlockAt;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount, uint256 unlockAt);
    event Unstaked(address indexed user, uint256 amount);
    event LockPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _impToken,
        address initialOwner,
        uint256 _lockPeriod
    ) external initializer {
        require(_impToken != address(0), "imp zero");
        require(initialOwner != address(0), "owner zero");

        __Ownable_init(initialOwner);

        impToken = IERC20(_impToken);
        lockPeriod = _lockPeriod;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

        function setLockPeriod(uint256 newPeriod) external onlyOwner {
        uint256 oldPeriod = lockPeriod;
        lockPeriod = newPeriod;
        emit LockPeriodUpdated(oldPeriod, newPeriod);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount zero");
        impToken.safeTransferFrom(msg.sender, address(this), amount);

        Stake storage s = stakes[msg.sender];
        s.amount += amount;
        s.since = block.timestamp;
        s.unlockAt = block.timestamp + lockPeriod;
        totalStaked += amount;

        emit Staked(msg.sender, amount, s.unlockAt);
    }

    function unstake(uint256 amount) external nonReentrant {
        Stake storage s = stakes[msg.sender];
        require(amount > 0 && amount <= s.amount, "invalid");
        // forge-lint: disable-next-line(block-timestamp)
        require(block.timestamp >= s.unlockAt, "locked");

        s.amount -= amount;
        totalStaked -= amount;
        impToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function stakedOf(address user) external view returns (uint256) {
        return stakes[user].amount;
    }
}
