// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {T2TMessenger} from "./T2TMessenger.sol";
import {DecisionLib} from "../decisions/DecisionLib.sol";

/// @title T2TBridgeRoot
/// @notice Lato root del bridge T2T.
///         Deposito diretto (stessa chain): fee = 0.
///         Cross-chain: fee = amount * feeBps / 10000, con tetto MAX_FEE_BPS.
contract T2TBridgeRoot is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE  = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    T2TMessenger public messenger;
    uint256 public l2ChainId;
    uint256 public thisChainId;

    mapping(address => bool)    public supportedTokens;
    mapping(address => uint256) public maxAmountPerTx;
    mapping(bytes32 => bool)    public processedDecisions;

    uint256 public depositNonce;
    bool    public paused;

    /// @notice Fee in basis points per operazioni cross-chain. Configurabile dal governor.
    uint256 public feeBps;

    /// @notice Destinatario della fee. Configurabile dal governor.
    address public feeRecipient;

    /// @notice Deadline di default per ogni decisione (1 ora).
    uint64 public constant DEFAULT_DEADLINE = 1 hours;

    event DepositInitiated(
        address indexed sender,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 nonce,
        bytes32 decisionId
    );
    event WithdrawalFinalized(
        bytes32 indexed decisionId,
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event TokenRegistered(address indexed token, uint256 maxAmount);
    event Paused(bool state);
    event FeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _messenger,
        uint256 _l2ChainId,
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

        messenger = T2TMessenger(_messenger);
        l2ChainId = _l2ChainId;
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

    function registerToken(address token, uint256 maxAmount) external onlyRole(GOVERNOR_ROLE) {
        require(token != address(0), "token zero");
        supportedTokens[token] = true;
        maxAmountPerTx[token] = maxAmount;
        emit TokenRegistered(token, maxAmount);
    }

    /// @notice Deposito diretto: srcChainId == dstChainId, fee = 0.
    function deposit(address token, address recipient, uint256 amount) external nonReentrant {
        _deposit(token, recipient, amount, thisChainId, 0);
    }

    /// @notice Deposito cross-chain: srcChainId != dstChainId, fee calcolata.
    function depositCrossChain(
        address token,
        address recipient,
        uint256 amount,
        uint256 srcChainId
    ) external nonReentrant {
        require(srcChainId != thisChainId, "use deposit() for same chain");
        uint256 fee = DecisionLib.computeFee(amount, feeBps);
        _deposit(token, recipient, amount, srcChainId, fee);
    }

    function _deposit(
        address token,
        address recipient,
        uint256 amount,
        uint256 srcChainId,
        uint256 fee
    ) internal {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(supportedTokens[token], "token not supported");
        require(amount > 0 && amount <= maxAmountPerTx[token], "invalid amount");
        require(fee <= amount, "fee exceeds amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = ++depositNonce;

        DecisionLib.Decision memory d = DecisionLib.Decision({
            kind:          DecisionLib.KIND_DEPOSIT,
            actor:         msg.sender,
            token:         token,
            recipient:     recipient,
            amount:        amount,
            nonce:         nonce,
            srcChainId:    srcChainId,
            dstChainId:    l2ChainId,
            deadline:      uint64(block.timestamp) + DEFAULT_DEADLINE,
            rationaleHash: keccak256(abi.encodePacked("deposit", msg.sender, token, recipient, amount, nonce)),
            fee:           fee,
            feeRecipient:  fee > 0 ? feeRecipient : address(0)
        });

        bytes32 id = messenger.recordDecision(d);

        emit DepositInitiated(msg.sender, recipient, token, amount, nonce, id);
    }

    /// @notice Rilascio lato root dopo firme dei guardian.
    function executeWithdrawal(
        DecisionLib.Decision calldata d,
        bytes[] calldata signatures
    ) external nonReentrant {
        require(!paused, "paused");
        require(d.kind == DecisionLib.KIND_WITHDRAW, "wrong kind");
        require(d.dstChainId == thisChainId, "wrong dst chain");
        require(d.recipient != address(0), "recipient zero");
        require(d.amount > 0, "amount zero");
        require(d.fee <= d.amount, "fee exceeds amount");

        bytes32 id = DecisionLib.hash(d);
        require(!processedDecisions[id], "already processed");
        require(messenger.verifyDecision(d, signatures), "invalid decision");

        processedDecisions[id] = true;

        uint256 netAmount = d.amount - d.fee;
        IERC20(d.token).safeTransfer(d.recipient, netAmount);
        if (d.fee > 0) {
            IERC20(d.token).safeTransfer(d.feeRecipient, d.fee);
        }

        emit WithdrawalFinalized(id, d.token, d.recipient, d.amount);
    }
}
