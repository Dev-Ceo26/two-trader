// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IMPUSD is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ============ Costanti ============
    uint8 private constant _DECIMALS = 6;
    uint256 public constant MAX_SUPPLY = 3_000_000_000 * 10**_DECIMALS;

    uint256 public constant USDC_WEIGHT = 5000; // 50%
    uint256 public constant USDT_WEIGHT = 5000; // 50%

    // ============ Storage ============
    address public usdc;
    address public usdt;
    address public safeTeamVault;
    address public feeCollector;
    address public masterMinter;
    address public pauser;

    bool public vaultAuthorized;
    bool public feesEnabled;
    uint256 public mintFeeBasisPoints;
    uint256 public burnFeeBasisPoints;

    uint256 public totalMinted;
    uint256 public totalReserveValue;
    uint256 public lastReserveUpdate;

    mapping(address => uint256) public reserveBalances;
    mapping(address => bool) public isMinter;
    mapping(address => uint256) public minterAllowance;

    // ============ Events ============
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event ReserveDeposited(address indexed asset, uint256 amount);
    event ReserveWithdrawn(address indexed asset, uint256 amount);
    event MinterConfigured(address indexed minter, uint256 allowance);
    event MinterRemoved(address indexed minter);
    event SafeTeamVaultSet(address indexed vault, bool authorized);
    event FeeConfigurationUpdated(uint256 mintFee, uint256 burnFee, address collector, bool enabled);
    event MasterMinterChanged(address indexed oldMinter, address indexed newMinter);
    event PauserChanged(address indexed oldPauser, address indexed newPauser);

    // ============ Modifiers ============
    modifier onlyMasterMinter() {
        require(msg.sender == masterMinter, "IMPUSD: only master minter");
        _;
    }

    modifier onlyPauser() {
        require(msg.sender == pauser, "IMPUSD: only pauser");
        _;
    }

    modifier onlyVaultOrOwner() {
        require(
            msg.sender == owner() || (vaultAuthorized && msg.sender == safeTeamVault),
            "IMPUSD: only vault or owner"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initialize ============
    function initialize(
        address _usdc,
        address _usdt,
        address _masterMinter,
        address _pauser,
        address _feeCollector,
        address _safeTeamVault,
        address initialOwner
    ) external initializer {
        require(_usdc != address(0), "IMPUSD: zero usdc");
        require(_usdt != address(0), "IMPUSD: zero usdt");
        require(_masterMinter != address(0), "IMPUSD: zero masterMinter");
        require(_pauser != address(0), "IMPUSD: zero pauser");

        __ERC20_init("Imperium USD", "tIMPUSD");
        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();

        usdc = _usdc;
        usdt = _usdt;
        masterMinter = _masterMinter;
        pauser = _pauser;
        feeCollector = _feeCollector;
        safeTeamVault = _safeTeamVault;
        vaultAuthorized = _safeTeamVault != address(0);
        lastReserveUpdate = block.timestamp;
    }

    // ============ ERC20 overrides ============
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }

    // ============ Reserve & Mint ============
    function depositReserveAndMint(
        address asset,
        uint256 amount,
        address mintTo
    ) external nonReentrant whenNotPaused returns (uint256 amountMinted) {
        require(asset == usdc || asset == usdt, "IMPUSD: invalid reserve asset");
        require(amount > 0, "IMPUSD: amount must be > 0");
        require(mintTo != address(0), "IMPUSD: mint to zero");
        require(totalMinted + amount <= MAX_SUPPLY, "IMPUSD: exceeds max supply");

        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        reserveBalances[asset] += amount;
        totalReserveValue += amount;
        lastReserveUpdate = block.timestamp;

        uint256 fee = 0;
        uint256 amountAfterFee = amount;
        if (feesEnabled && mintFeeBasisPoints > 0) {
            fee = (amount * mintFeeBasisPoints) / 10_000;
            amountAfterFee = amount - fee;
        }

        _mint(mintTo, amountAfterFee);
        totalMinted += amountAfterFee;

        if (fee > 0 && feeCollector != address(0)) {
            _mint(feeCollector, fee);
            totalMinted += fee;
        }

        emit ReserveDeposited(asset, amount);
        emit Mint(msg.sender, mintTo, amountAfterFee);
        return amountAfterFee;
    }

    function burnAndWithdrawReserve(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "IMPUSD: amount must be > 0");
        require(balanceOf(msg.sender) >= amount, "IMPUSD: insufficient balance");

        uint256 fee = 0;
        uint256 amountAfterFee = amount;
        if (feesEnabled && burnFeeBasisPoints > 0) {
            fee = (amount * burnFeeBasisPoints) / 10_000;
            amountAfterFee = amount - fee;
        }

        (uint256 usdcAmount, uint256 usdtAmount) = getRequiredReserveDistribution(amountAfterFee);

        // Preleva solo ciò che è disponibile in riserva (no underflow)
        uint256 usdcToSend = usdcAmount > reserveBalances[usdc] ? reserveBalances[usdc] : usdcAmount;
        uint256 usdtToSend = usdtAmount > reserveBalances[usdt] ? reserveBalances[usdt] : usdtAmount;

        _burn(msg.sender, amount);
        if (fee > 0) {
            _burn(feeCollector, fee);
        }

        reserveBalances[usdc] -= usdcToSend;
        reserveBalances[usdt] -= usdtToSend;
        totalReserveValue -= (usdcToSend + usdtToSend);
        lastReserveUpdate = block.timestamp;

        if (usdcToSend > 0) IERC20(usdc).transfer(msg.sender, usdcToSend);
        if (usdtToSend > 0) IERC20(usdt).transfer(msg.sender, usdtToSend);

        emit ReserveWithdrawn(usdc, usdcToSend);
        emit ReserveWithdrawn(usdt, usdtToSend);
        emit Burn(msg.sender, amount);
    }

    // ============ View ============
    function getRequiredReserveDistribution(uint256 amount)
        public
        pure
        returns (uint256 usdcAmount, uint256 usdtAmount)
    {
        usdcAmount = (amount * USDC_WEIGHT) / 10_000;
        usdtAmount = (amount * USDT_WEIGHT) / 10_000;
    }

    function getReserveCoverage() public view returns (uint256) {
        if (totalSupply() == 0) return 10_000;
        return (totalReserveValue * 10_000) / totalSupply();
    }

    function isFullyCollateralized() public view returns (bool) {
        return totalReserveValue >= totalSupply();
    }

    function getFeeConfig()
        external
        view
        returns (uint256 mintFee, uint256 burnFee, address collector, bool enabled)
    {
        return (mintFeeBasisPoints, burnFeeBasisPoints, feeCollector, feesEnabled);
    }

    // ============ Minter management ============
    function configureMinter(address _minter, uint256 _allowance)
        external
        onlyMasterMinter
        returns (bool)
    {
        require(_minter != address(0), "IMPUSD: zero minter");
        require(_allowance > 0, "IMPUSD: allowance must be > 0");
        isMinter[_minter] = true;
        minterAllowance[_minter] = _allowance;
        emit MinterConfigured(_minter, _allowance);
        return true;
    }

    function removeMinter(address _minter) external onlyMasterMinter returns (bool) {
        require(isMinter[_minter], "IMPUSD: not a minter");
        isMinter[_minter] = false;
        minterAllowance[_minter] = 0;
        emit MinterRemoved(_minter);
        return true;
    }

    // ============ Admin ============
    function setSafeTeamVault(address _vault, bool _authorized) external onlyOwner {
        require(_vault != address(0), "IMPUSD: zero vault");
        safeTeamVault = _vault;
        vaultAuthorized = _authorized;
        emit SafeTeamVaultSet(_vault, _authorized);
    }

    function setFeesEnabled(bool _enabled) external onlyVaultOrOwner {
        feesEnabled = _enabled;
        emit FeeConfigurationUpdated(mintFeeBasisPoints, burnFeeBasisPoints, feeCollector, _enabled);
    }

    function setMintFee(uint256 _fee) external onlyVaultOrOwner {
        require(_fee <= 1000, "IMPUSD: fee too high");
        mintFeeBasisPoints = _fee;
        emit FeeConfigurationUpdated(_fee, burnFeeBasisPoints, feeCollector, feesEnabled);
    }

    function setBurnFee(uint256 _fee) external onlyVaultOrOwner {
        require(_fee <= 1000, "IMPUSD: fee too high");
        burnFeeBasisPoints = _fee;
        emit FeeConfigurationUpdated(mintFeeBasisPoints, _fee, feeCollector, feesEnabled);
    }

    function setFeeCollector(address _collector) external onlyVaultOrOwner {
        require(_collector != address(0), "IMPUSD: zero collector");
        feeCollector = _collector;
        emit FeeConfigurationUpdated(mintFeeBasisPoints, burnFeeBasisPoints, _collector, feesEnabled);
    }

    function changeMasterMinter(address _newMinter) external onlyMasterMinter {
        require(_newMinter != address(0), "IMPUSD: zero");
        emit MasterMinterChanged(masterMinter, _newMinter);
        masterMinter = _newMinter;
    }

    function changePauser(address _newPauser) external onlyMasterMinter {
        require(_newPauser != address(0), "IMPUSD: zero");
        emit PauserChanged(pauser, _newPauser);
        pauser = _newPauser;
    }

    function pause() external onlyPauser {
        _pause();
    }

    function unpause() external onlyPauser {
        _unpause();
    }
}
