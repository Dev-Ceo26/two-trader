// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ImperiumMessenger} from "./ImperiumMessenger.sol";

contract ImperiumBridgeRoot is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    ImperiumMessenger public messenger;
    uint256 public l2ChainId;
    uint256 public thisChainId;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public maxAmountPerTx;
    mapping(bytes32 => bool) public processedMessages;

    uint256 public depositNonce;
    bool public paused;

    event DepositInitiated(address indexed sender, address indexed recipient, address indexed token, uint256 amount, uint256 nonce);
    event WithdrawalFinalized(bytes32 indexed messageHash, address indexed token, address indexed recipient, uint256 amount);
    event TokenRegistered(address indexed token, uint256 maxAmount);
    event Paused(bool state);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _messenger,
        uint256 _l2ChainId,
        address governor
    ) external initializer {
        require(_messenger != address(0), "messenger zero");
        require(governor != address(0), "governor zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        messenger = ImperiumMessenger(_messenger);
        l2ChainId = _l2ChainId;
        thisChainId = block.chainid;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    function setPaused(bool state) external onlyRole(GOVERNOR_ROLE) {
        paused = state;
        emit Paused(state);
    }

    function registerToken(address token, uint256 maxAmount) external onlyRole(GOVERNOR_ROLE) {
        require(token != address(0), "token zero");
        supportedTokens[token] = true;
        maxAmountPerTx[token] = maxAmount;
        emit TokenRegistered(token, maxAmount);
    }

    // ✅ LOCK: utente manda token al bridge
    function deposit(address token, address recipient, uint256 amount) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(supportedTokens[token], "token not supported");
        require(amount > 0 && amount <= maxAmountPerTx[token], "invalid amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = ++depositNonce;

        emit DepositInitiated(msg.sender, recipient, token, amount, nonce);
    }

    // ✅ RELEASE: bridge manda token all'utente
    function executeWithdrawal(
        address token,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes[] calldata signatures
    ) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(amount > 0, "amount zero");

        bytes32 messageHash = keccak256(abi.encode(token, recipient, amount, nonce, l2ChainId, thisChainId));
        require(!processedMessages[messageHash], "already processed");
        require(messenger.verifySignatures(messageHash, signatures), "invalid signatures");

        processedMessages[messageHash] = true;

        IERC20(token).safeTransfer(recipient, amount);

        emit WithdrawalFinalized(messageHash, token, recipient, amount);
    }
}
