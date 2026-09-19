// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ImperiumMessenger} from "./ImperiumMessenger.sol";

contract ImperiumBridgeChild is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    ImperiumMessenger public messenger;
    uint256 public l1ChainId;
    uint256 public thisChainId;

    mapping(address => bool) public supportedTokens;
    mapping(address => address) public localToRemote;
    mapping(address => address) public remoteToLocal;
    mapping(bytes32 => bool) public processedMessages;

    uint256 public withdrawNonce;
    bool public paused;

    event TokenRegistered(address indexed localToken, address indexed remoteToken);
    event WithdrawalInitiated(address indexed withdrawer, address indexed recipient, address indexed token, uint256 amount, uint256 nonce, bytes32 messageHash);
    event DepositFinalized(address indexed recipient, address indexed token, uint256 amount, uint256 indexed nonce, bytes32 messageHash);
    event Paused(bool state);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _messenger,
        uint256 _l1ChainId,
        address governor
    ) external initializer {
        require(_messenger != address(0), "messenger zero");
        require(governor != address(0), "governor zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        messenger = ImperiumMessenger(_messenger);
        l1ChainId = _l1ChainId;
        thisChainId = block.chainid;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    function setPaused(bool state) external onlyRole(GOVERNOR_ROLE) {
        paused = state;
        emit Paused(state);
    }

    function registerToken(address localToken, address remoteToken) external onlyRole(GOVERNOR_ROLE) {
        require(localToken != address(0) && remoteToken != address(0), "zero token");
        require(remoteToLocal[remoteToken] == address(0), "remote already mapped");
        supportedTokens[localToken] = true;
        localToRemote[localToken] = remoteToken;
        remoteToLocal[remoteToken] = localToken;
        emit TokenRegistered(localToken, remoteToken);
    }

    // ✅ LOCK: utente manda token al bridge
    function withdrawToL1(address token, address recipient, uint256 amount) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(amount > 0, "amount zero");
        require(supportedTokens[token], "token not supported");

        address remoteToken = localToRemote[token];
        require(remoteToken != address(0), "remote not mapped");

        // Trasferisci i token dall'utente al bridge
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = ++withdrawNonce;
        bytes32 messageHash = keccak256(abi.encode(remoteToken, recipient, amount, nonce, thisChainId, l1ChainId));

        emit WithdrawalInitiated(msg.sender, recipient, token, amount, nonce, messageHash);
    }

    // ✅ RELEASE: bridge manda token all'utente
    function finalizeDeposit(
        address token,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 srcChainId,
        bytes[] calldata signatures
    ) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(amount > 0, "amount zero");

        bytes32 messageHash = keccak256(abi.encode(token, recipient, amount, nonce, srcChainId, thisChainId));
        require(!processedMessages[messageHash], "already processed");
        require(messenger.verifySignatures(messageHash, signatures), "invalid signatures");

        processedMessages[messageHash] = true;

        address localToken = remoteToLocal[token];
        require(localToken != address(0), "unknown remote token");

        // Trasferisci i token dal bridge all'utente
        IERC20(localToken).safeTransfer(recipient, amount);

        emit DepositFinalized(recipient, localToken, amount, nonce, messageHash);
    }
        // Funzione di emergenza: solo il governor può prelevare token
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRole(GOVERNOR_ROLE) {
        require(to != address(0), "to zero");
        IERC20(token).safeTransfer(to, amount);
    }
}
