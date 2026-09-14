// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ImperiumPair
 * @notice Coppia AMM (x*y=k) con token LP.
 * @dev UUPS upgradable, Ownable (transitorio). In futuro: DAO.
 */
contract ImperiumPair is
    ERC20Upgradeable,
    ReentrancyGuardTransient,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max

    IERC20 public token0;
    IERC20 public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint256 public feeBps;
    address public feeRecipient;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event FeeUpdated(uint256 oldBps, uint256 newBps);
    event FeeRecipientUpdated(address oldRecipient, address indexed  newRecipient);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token0,
        address _token1,
        address initialOwner,
        uint256 _feeBps
    ) external initializer {
        require(_token0 != address(0) && _token1 != address(0), "zero token");
        require(_token0 != _token1, "same token");
        require(initialOwner != address(0), "owner zero");
        require(_feeBps <= MAX_FEE_BPS, "fee too high");

        __ERC20_init("Imperium LP", "ILP");
        __Ownable_init(initialOwner);

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeBps = _feeBps;
        feeRecipient = initialOwner;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setFee(uint256 newBps) external onlyOwner {
        require(newBps <= MAX_FEE_BPS, "fee too high");
        uint256 oldBps = feeBps;
        feeBps = newBps;
        emit FeeUpdated(oldBps, newBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "recipient zero");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function getReserves() external view returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));
        uint256 amount0 = bal0 - reserve0;
        uint256 amount1 = bal1 - reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            liquidity = _min(
                (amount0 * _totalSupply) / reserve0,
                (amount1 * _totalSupply) / reserve1
            );
        }
        require(liquidity > 0, "liquidity zero");
        _mint(to, liquidity);

        _update(bal0, bal1);
        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf(address(this));
        uint256 _totalSupply = totalSupply();
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        amount0 = (liquidity * bal0) / _totalSupply;
        amount1 = (liquidity * bal1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "insufficient liquidity");

        _burn(address(this), liquidity);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);

        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "zero out");
        require(amount0Out < reserve0 && amount1Out < reserve1, "insufficient reserve");

        if (amount0Out > 0) token0.safeTransfer(to, amount0Out);
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out);

        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        uint256 amount0In = bal0 > reserve0 - amount0Out ? bal0 - (reserve0 - amount0Out) : 0;
        uint256 amount1In = bal1 > reserve1 - amount1Out ? bal1 - (reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "no input");

        uint256 amount0InAfterFee = amount0In * (BPS_DENOMINATOR - feeBps) / BPS_DENOMINATOR;
        uint256 amount1InAfterFee = amount1In * (BPS_DENOMINATOR - feeBps) / BPS_DENOMINATOR;

        uint256 newReserve0 = reserve0 + amount0InAfterFee;
        uint256 newReserve1 = reserve1 + amount1InAfterFee;
        require(newReserve0 * newReserve1 >= uint256(reserve0) * uint256(reserve1), "k");

        _update(bal0, bal1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _update(uint256 bal0, uint256 bal1) private {
        reserve0 = SafeCast.toUint112(bal0);
        reserve1 = SafeCast.toUint112(bal1);
        emit Sync(reserve0, reserve1);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
