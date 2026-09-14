// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title FeeDistributor
 * @notice Ripartisce le fee del Maker: 50% LP, 20% staker, 20% Treasury, 10% Guardian.
 * @dev UUPS upgradable, Ownable (transitorio). In futuro: DAO.
 */
contract FeeDistributor is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public constant DEFAULT_LP_SHARE = 5000;       // 50%
    uint256 public constant DEFAULT_STAKER_SHARE = 2000;   // 20%
    uint256 public constant DEFAULT_TREASURY_SHARE = 2000; // 20%
    uint256 public constant DEFAULT_GUARDIAN_SHARE = 1000; // 10%

    uint256 public lpShareBps;
    uint256 public stakerShareBps;
    uint256 public treasuryShareBps;
    uint256 public guardianShareBps;

    address public treasury;
    address public guardianPool;

    event Distributed(address indexed token, uint256 total, uint256 toTreasury, uint256 toGuardian);
    event SharesUpdated(uint256 lp, uint256 staker, uint256 treasury, uint256 guardian);
    event TreasuryUpdated(address indexed oldT, address indexed newT);
    event GuardianPoolUpdated(address indexed oldP, address indexed newP);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _treasury,
        address _guardianPool
    ) external initializer {
        require(initialOwner != address(0), "owner zero");
        require(_treasury != address(0), "treasury zero");
        require(_guardianPool != address(0), "guardian zero");

        __Ownable_init(initialOwner);

        treasury = _treasury;
        guardianPool = _guardianPool;

        lpShareBps = DEFAULT_LP_SHARE;
        stakerShareBps = DEFAULT_STAKER_SHARE;
        treasuryShareBps = DEFAULT_TREASURY_SHARE;
        guardianShareBps = DEFAULT_GUARDIAN_SHARE;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setShares(
        uint256 lp,
        uint256 staker,
        uint256 treasury_,
        uint256 guardian
    ) external onlyOwner {
        require(
            lp + staker + treasury_ + guardian == BPS_DENOMINATOR,
            "must sum 10000"
        );
        lpShareBps = lp;
        stakerShareBps = staker;
        treasuryShareBps = treasury_;
        guardianShareBps = guardian;
        emit SharesUpdated(lp, staker, treasury_, guardian);
    }

    function setTreasury(address newT) external onlyOwner {
        require(newT != address(0), "zero");
        address oldT = treasury;
        treasury = newT;
        emit TreasuryUpdated(oldT, newT);
    }

    function setGuardianPool(address newP) external onlyOwner {
        require(newP != address(0), "zero");
        address oldP = guardianPool;
        guardianPool = newP;
        emit GuardianPoolUpdated(oldP, newP);
    }

    function distribute(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "token zero");
        require(amount > 0, "amount zero");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 toTreasury = (amount * treasuryShareBps) / BPS_DENOMINATOR;
        uint256 toGuardian = (amount * guardianShareBps) / BPS_DENOMINATOR;

        if (toTreasury > 0) IERC20(token).safeTransfer(treasury, toTreasury);
        if (toGuardian > 0) IERC20(token).safeTransfer(guardianPool, toGuardian);

        // Il resto (LP + staker) rimane nel contratto per claim() futuri

        emit Distributed(token, amount, toTreasury, toGuardian);
    }
}
