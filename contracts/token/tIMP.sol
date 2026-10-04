// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
 *
 * Distribuzione iniziale:
 *   - 100.000.000 tIMP all'owner
 *   - 100.000.000 tIMP al faucet
 *   -  10.000.000 tIMP al bridge
 *   ---------------------------------
 *   - 210.000.000 tIMP totali mintati all'init
 *
 * Il bridge può ricevere altri token tramite mintEcosystem() (solo owner)
 * in caso di scarsità per scambi cross-chain.
 */
contract tIMP is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    // ───────────── Costanti ─────────────
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    uint256 public constant OWNER_ALLOCATION   = 100_000_000 * 10 ** 18;
    uint256 public constant FAUCET_ALLOCATION  = 100_000_000 * 10 ** 18;
    uint256 public constant BRIDGE_ALLOCATION  =  10_000_000 * 10 ** 18;
    uint256 public constant INITIAL_SUPPLY     =
        OWNER_ALLOCATION + FAUCET_ALLOCATION + BRIDGE_ALLOCATION; // 210M

    // ───────────── Storage ─────────────
    address public faucet;
    address public bridge;

    mapping(address => uint256) public whitelist;
    mapping(address => bool) public hasClaimed;

    // ───────────── Eventi ─────────────
    event WhitelistAdded(address indexed wallet, uint256 amount);
    event WhitelistRemoved(address indexed wallet);
    event Claimed(address indexed wallet, uint256 amount);
    event EcosystemMint(address indexed to, uint256 amount);
    event FaucetUpdated(address indexed oldFaucet, address indexed newFaucet);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inizializza il token e distribuisce le allocazioni iniziali.
     * @param initialOwner Owner del contratto (multisig o EOA).
     * @param initialFaucet Indirizzo del faucet.
     * @param initialBridge Indirizzo del bridge.
     */
    function initialize(
        address initialOwner,
        address initialFaucet,
        address initialBridge
    ) external initializer {
        require(initialOwner != address(0), "owner zero");
        require(initialFaucet != address(0), "faucet zero");
        require(initialBridge != address(0), "bridge zero");

        __ERC20_init("Imperium Testnet", "tIMP");
        __ERC20Permit_init("tIMP");
        __ERC20Votes_init();
        __Ownable_init(initialOwner);

        faucet = initialFaucet;
        bridge = initialBridge;

        // Distribuzione iniziale
        _mint(initialOwner,  OWNER_ALLOCATION);
        _mint(initialFaucet, FAUCET_ALLOCATION);
        _mint(initialBridge, BRIDGE_ALLOCATION);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ───────────── Mint ─────────────

    /**
     * @notice Minta nuovi token a un destinatario (solo owner).
     * @dev Usato dal bridge in caso di scarsità o per nuove allocazioni.
     */
    function mintEcosystem(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to zero");
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");
        _mint(to, amount);
        emit EcosystemMint(to, amount);
    }

    // ───────────── Faucet / Bridge ─────────────

    function setFaucet(address newFaucet) external onlyOwner {
        require(newFaucet != address(0), "faucet zero");
        address old = faucet;
        faucet = newFaucet;
        emit FaucetUpdated(old, newFaucet);
    }

    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "bridge zero");
        address old = bridge;
        bridge = newBridge;
        emit BridgeUpdated(old, newBridge);
    }

    // ───────────── Whitelist / Claim ─────────────

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

    // ───────────── Override ─────────────

    function _update(address from, address to, uint256 value)
        internal override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
