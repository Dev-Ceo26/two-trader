// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ImperiumMessenger} from "./ImperiumMessenger.sol";
import {DecisionLib} from "../decisions/DecisionLib.sol";

/// @title ImperiumBridgeChild
/// @notice Lato child del bridge Imperium. Speculare a BridgeRoot.
contract ImperiumBridgeChild is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE  = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    ImperiumMessenger public messenger;
    uint256 public l1ChainId;
    uint256 public thisChainId;

    mapping(address => bool)    public supportedTokens;
    mapping(address => address) public localToRemote;
    mapping(address => address) public remoteToLocal;
    mapping(bytes32 => bool)    public processedDecisions;

    uint256 public withdrawNonce;
    bool    public paused;

    uint256 public feeBps;
    address public feeRecipient;

    uint64 public constant DEFAULT_DEADLINE = 1 hours;

    event WithdrawalInitiated(
        address indexed withdrawer,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 nonce,
        bytes32 decisionId
    );
    event DepositFinalized(
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 indexed nonce,
        bytes32 decisionId
    );
    event TokenRegistered(address indexed localToken, address indexed remoteToken);
    event Paused(bool state);
    event FeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _messenger,
        uint256 _l1ChainId,
        address governor,
        uint256 _feeBps,
        address _feeRecipient
    ) external initializer {
        require(_messenger != address(0), "messenger zero");
        require(governor != address(0), "governor zero");
        require(_feeBps <= DecisionLib.MAX_FEE_BPS, "fee bps too high");
        require(_feeRecipient != address(0), "fee recipient zero");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
        _grantRole(EMERGENCY_ROLE, governor);

        messenger = ImperiumMessenger(_messenger);
        l1ChainId = _l1ChainId;
        thisChainId = block.chainid;
        feeBps = _feeBps;
        feeRecipient = _feeRecipient;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyRole(GOVERNOR_ROLE) {
        paused = false;
        emit Paused(false);
    }

    function setFeeBps(uint256 newBps) external onlyRole(GOVERNOR_ROLE) {
        require(newBps <= DecisionLib.MAX_FEE_BPS, "fee bps too high");
        emit FeeBpsUpdated(feeBps, newBps);
        feeBps = newBps;
    }

    function setFeeRecipient(address newRecipient) external onlyRole(GOVERNOR_ROLE) {
        require(newRecipient != address(0), "fee recipient zero");
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function registerToken(address localToken, address remoteToken) external onlyRole(GOVERNOR_ROLE) {
        require(localToken != address(0) && remoteToken != address(0), "zero token");
        require(remoteToLocal[remoteToken] == address(0), "remote already mapped");
        supportedTokens[localToken] = true;
        localToRemote[localToken] = remoteToken;
        remoteToLocal[remoteToken] = localToken;
        emit TokenRegistered(localToken, remoteToken);
    }

    /// @notice Prelievo: blocco sul child, rilascio sul root.
    function withdrawToL1(address token, address recipient, uint256 amount) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(amount > 0, "amount zero");
        require(supportedTokens[token], "token not supported");

        address remoteToken = localToRemote[token];
        require(remoteToken != address(0), "remote not mapped");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = ++withdrawNonce;
        uint256 fee = DecisionLib.computeFee(amount, feeBps);

        DecisionLib.Decision memory d = DecisionLib.Decision({
            kind:          DecisionLib.KIND_WITHDRAW,
            actor:         msg.sender,
            token:         remoteToken,
            recipient:     recipient,
            amount:        amount,
            nonce:         nonce,
            srcChainId:    thisChainId,
            dstChainId:    l1ChainId,
            deadline:      uint64(block.timestamp) + DEFAULT_DEADLINE,
            rationaleHash: keccak256(abi.encodePacked("withdraw", msg.sender, token, recipient, amount, nonce)),
            fee:           fee,
            feeRecipient:  fee > 0 ? feeRecipient : address(0)
        });

        bytes32 id = messenger.recordDecision(d);

        emit WithdrawalInitiated(msg.sender, recipient, token, amount, nonce, id);
    }

    /// @notice Rilascio lato child dopo firme dei guardian.
    function finalizeDeposit(
        DecisionLib.Decision calldata d,
        bytes[] calldata signatures
    ) external nonReentrant {
        require(!paused, "paused");
        require(d.kind == DecisionLib.KIND_DEPOSIT, "wrong kind");
        require(d.dstChainId == thisChainId, "wrong dst chain");
        require(d.recipient != address(0), "recipient zero");
        require(d.amount > 0, "amount zero");
        require(d.fee <= d.amount, "fee exceeds amount");

        bytes32 id = DecisionLib.hash(d);
        require(!processedDecisions[id], "already processed");
        require(messenger.verifyDecision(d, signatures), "invalid decision");

        processedDecisions[id] = true;

        address localToken = remoteToLocal[d.token];
        require(localToken != address(0), "unknown remote token");

        uint256 netAmount = d.amount - d.fee;
        IERC20(localToken).safeTransfer(d.recipient, netAmount);
        if (d.fee > 0) {
            IERC20(localToken).safeTransfer(d.feeRecipient, d.fee);
        }

        emit DepositFinalized(d.recipient, localToken, d.amount, d.nonce, id);
    }

    /// @notice Prelievo di emergenza. Solo GOVERNOR_ROLE.
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRole(GOVERNOR_ROLE) {
        require(to != address(0), "to zero");
        IERC20(token).safeTransfer(to, amount);
    }
}
