// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GuardianRegistry is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    struct Guardian {
        address addr;
        bytes32 publicKey;
        uint256 stakedAmount;
        uint256 registeredAt;
        bool active;
    }

    uint256 public minStake;
    uint256 public unstakeCooldown;

    mapping(address => Guardian) public guardians;
    address[] public guardianList;
    mapping(address => uint256) public unstakeRequestedAt;

    event GuardianRegistered(address indexed guardian, bytes32 publicKey, uint256 stake);
    event GuardianSlashed(address indexed guardian, uint256 amount, bytes32 reason);
    event GuardianDeactivated(address indexed guardian);
    event MinStakeUpdated(uint256 oldValue, uint256 newValue);
    event UnstakeCooldownUpdated(uint256 oldValue, uint256 newValue);
    event UnstakeRequested(address indexed guardian, uint256 availableAt);
    event UnstakeCancelled(address indexed guardian);
    event GuardianUnstaked(address indexed guardian, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor, uint256 _minStake, uint256 _unstakeCooldown) external initializer {
        require(governor != address(0), "governor zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        minStake = _minStake;
        unstakeCooldown = _unstakeCooldown;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    function registerGuardian(bytes32 publicKey) external payable {
        require(guardians[msg.sender].addr == address(0), "already registered");
        require(msg.value >= minStake, "stake too low");
        require(publicKey != bytes32(0), "pubkey zero");

        guardians[msg.sender] = Guardian({
            addr: msg.sender,
            publicKey: publicKey,
            stakedAmount: msg.value,
            registeredAt: block.timestamp,
            active: true
        });
        guardianList.push(msg.sender);

        emit GuardianRegistered(msg.sender, publicKey, msg.value);
    }

    function isActiveGuardian(address who) external view returns (bool) {
        return guardians[who].active;
    }

    function getGuardianCount() external view returns (uint256) {
        return guardianList.length;
    }

    function slashGuardian(address guardian, uint256 amount, bytes32 reason)
        external onlyRole(GOVERNOR_ROLE)
    {
        Guardian storage g = guardians[guardian];
        require(g.active, "not active");
        require(amount <= g.stakedAmount, "amount too high");
        g.stakedAmount -= amount;
        emit GuardianSlashed(guardian, amount, reason);
    }

    function deactivateGuardian(address guardian)
        external onlyRole(GOVERNOR_ROLE)
    {
        require(guardians[guardian].active, "not active");
        guardians[guardian].active = false;
        emit GuardianDeactivated(guardian);
    }

    function setMinStake(uint256 newMin) external onlyRole(GOVERNOR_ROLE) {
        emit MinStakeUpdated(minStake, newMin);
        minStake = newMin;
    }

    function setUnstakeCooldown(uint256 newCooldown) external onlyRole(GOVERNOR_ROLE) {
        emit UnstakeCooldownUpdated(unstakeCooldown, newCooldown);
        unstakeCooldown = newCooldown;
    }

    function requestUnstake() external {
        require(guardians[msg.sender].active, "not active");
        require(unstakeRequestedAt[msg.sender] == 0, "already requested");

        unstakeRequestedAt[msg.sender] = block.timestamp;
        emit UnstakeRequested(msg.sender, block.timestamp + unstakeCooldown);
    }

    function cancelUnstake() external {
        require(unstakeRequestedAt[msg.sender] != 0, "no request");
        unstakeRequestedAt[msg.sender] = 0;
        emit UnstakeCancelled(msg.sender);
    }

    function executeUnstake() external {
        require(unstakeRequestedAt[msg.sender] != 0, "no request");

        uint256 readyAt = unstakeRequestedAt[msg.sender] + unstakeCooldown;
        // forge-lint: disable-next-line(block-timestamp)
        require(block.timestamp >= readyAt, "cooldown");

        uint256 amount = guardians[msg.sender].stakedAmount;
        require(amount > 0, "nothing to unstake");

        guardians[msg.sender].active = false;
        guardians[msg.sender].stakedAmount = 0;
        unstakeRequestedAt[msg.sender] = 0;

        emit GuardianUnstaked(msg.sender, amount);

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
    }
}
