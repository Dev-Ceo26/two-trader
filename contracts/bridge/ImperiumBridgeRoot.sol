// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ImperiumMessenger} from "./ImperiumMessenger.sol";
import {DecisionLib} from "../decisions/DecisionLib.sol";

/// @title ImperiumBridgeRoot
/// @notice Lato root (L1) del bridge Imperium.
///         Ogni operazione che attraversa il bridge produce una Decision
///         canonica. Deposit = lock + record. Withdrawal = verify + release.
contract ImperiumBridgeRoot is
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE  = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    ImperiumMessenger public messenger;
    uint256 public l2ChainId;
    uint256 public thisChainId;

    mapping(address => bool)    public supportedTokens;
    mapping(address => uint256) public maxAmountPerTx;
    mapping(bytes32 => bool)    public processedDecisions;

    uint256 public depositNonce;
    bool    public paused;

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
        _grantRole(EMERGENCY_ROLE, governor);

        messenger = ImperiumMessenger(_messenger);
        l2ChainId = _l2ChainId;
        thisChainId = block.chainid;
    }

    function _authorizeUpgrade(address) internal override onlyRole(GOVERNOR_ROLE) {}

    /// @notice Pausa di emergenza. Solo EMERGENCY_ROLE.
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        paused = true;
        emit Paused(true);
    }

    /// @notice Ripristino. Solo GOVERNOR_ROLE.
    function unpause() external onlyRole(GOVERNOR_ROLE) {
        paused = false;
        emit Paused(false);
    }

    function registerToken(address token, uint256 maxAmount) external onlyRole(GOVERNOR_ROLE) {
        require(token != address(0), "token zero");
        supportedTokens[token] = true;
        maxAmountPerTx[token] = maxAmount;
        emit TokenRegistered(token, maxAmount);
    }

    /// @notice LOCK: l'utente manda token al bridge e la decisione viene registrata.
    /// @dev    La decisione NON viene eseguita qui. L'esecuzione avverra' sul child
    ///         quando i guardian avranno firmato e la verifica passera'.
    function deposit(address token, address recipient, uint256 amount) external nonReentrant {
        require(!paused, "paused");
        require(recipient != address(0), "recipient zero");
        require(supportedTokens[token], "token not supported");
        require(amount > 0 && amount <= maxAmountPerTx[token], "invalid amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = ++depositNonce;

        DecisionLib.Decision memory d = DecisionLib.Decision({
            kind:          DecisionLib.KIND_DEPOSIT,
            actor:         msg.sender,
            token:         token,
            recipient:     recipient,
            amount:        amount,
            nonce:         nonce,
            srcChainId:    thisChainId,
            dstChainId:    l2ChainId,
            deadline:      uint64(block.timestamp) + DEFAULT_DEADLINE,
            rationaleHash: keccak256(abi.encodePacked("deposit", msg.sender, token, recipient, amount, nonce))
        });

        bytes32 id = messenger.recordDecision(d);

        emit DepositInitiated(msg.sender, recipient, token, amount, nonce, id);
    }

    /// @notice RELEASE: il bridge manda token all'utente.
    /// @dev    Richiede una Decision canonica firmata da threshold guardian.
    ///         La decisione deve essere stata registrata (recordDecision) e non vetata.
    function executeWithdrawal(
        DecisionLib.Decision calldata d,
        bytes[] calldata signatures
    ) external nonReentrant {
        require(!paused, "paused");
        require(d.kind == DecisionLib.KIND_WITHDRAW, "wrong kind");
        require(d.dstChainId == thisChainId, "wrong dst chain");
        require(d.recipient != address(0), "recipient zero");
        require(d.amount > 0, "amount zero");

        bytes32 id = DecisionLib.hash(d);
        require(!processedDecisions[id], "already processed");
        require(messenger.verifyDecision(d, signatures), "invalid decision");

        processedDecisions[id] = true;

        IERC20(d.token).safeTransfer(d.recipient, d.amount);

        emit WithdrawalFinalized(id, d.token, d.recipient, d.amount);
    }
}
