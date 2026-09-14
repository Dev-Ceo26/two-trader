// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

/**
 * @title tIMP — Test Imperium
 * @notice Token di governance di Quantum Imperium (testnet).
 * @dev UUPS upgradable. Mintable fino a 1B. Burnable. 18 decimali.
 */
contract tIMP is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10 ** 18;

    mapping(address => uint256) public whitelist;
    mapping(address => bool) public hasClaimed;

    event WhitelistAdded(address indexed wallet, uint256 amount);
    event WhitelistRemoved(address indexed wallet);
    event Claimed(address indexed wallet, uint256 amount);
    event EcosystemMint(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialHolder, address initialOwner) external initializer {
        require(initialHolder != address(0), "holder zero");
        require(initialOwner != address(0), "owner zero");

        __ERC20_init("Test Imperium", "tIMP");
        __ERC20Permit_init("tIMP");
        __ERC20Votes_init();
        __Ownable_init(initialOwner);

        _mint(initialHolder, INITIAL_SUPPLY);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function mintEcosystem(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");
        _mint(to, amount);
        emit EcosystemMint(to, amount);
    }

    function addToWhitelist(address wallet, uint256 amount) external onlyOwner {
        require(wallet != address(0), "wallet zero");
        whitelist[wallet] = amount;
        emit WhitelistAdded(wallet, amount);
    }

    function removeFromWhitelist(address wallet) external onlyOwner {
        whitelist[wallet] = 0;
        emit WhitelistRemoved(wallet);
    }

    function claim() external {
        require(!hasClaimed[msg.sender], "already claimed");
        uint256 amount = whitelist[msg.sender];
        require(amount > 0, "not whitelisted");
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");

        hasClaimed[msg.sender] = true;
        _mint(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function _update(address from, address to, uint256 value)
        internal override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public view override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
