// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20TokenMetadata {
    function tokenURI() external view returns (string memory);
}

contract BolivarRepublicaVenezuelaBTC is ERC20, ERC20Burnable, ERC20Permit, ReentrancyGuard, IERC20TokenMetadata {
    IERC20 public immutable WBTC;
    address public immutable uniswapPoolManager;
    
    uint256 public constant CAP = 21_000_000 * 10**18;
    uint256 public constant RESERVE_RATIO = 50;
    uint256 public constant PRECISION = 100;
    uint256 public constant TOKEN_PER_WBTC = 100_000 * 10**18;
    uint256 public constant WBTC_DECIMALS = 8;
    
    uint256 public totalReserve;
    
    string private _tokenURI;
    address public metadataOwner;
    
    event Minted(address indexed user, uint256 tokenAmount, uint256 wbtcAmount);
    event Burned(address indexed user, uint256 tokenAmount, uint256 wbtcAmount);
    event ReserveUpdated(uint256 newReserve, uint256 newTotalSupply);
    event MetadataUpdated(string newTokenURI, address indexed updater);
    
    error CapExceeded();
    error InsufficientReserve(uint256 required, uint256 available);
    error BelowMinimumReserveRatio(uint256 currentRatio, uint256 requiredRatio);
    error InvalidWBTCTransfer();
    error ZeroAmount();
    error NotMetadataOwner();

    modifier onlyMetadataOwner() {
        if (msg.sender != metadataOwner) revert NotMetadataOwner();
        _;
    }

    constructor(string memory initialMetadataURI, address wbtcAddress, address poolManager) 
        ERC20("Bolivar Republica Venezuela BTC", "BRVBTC")
        ERC20Permit("Bolivar Republica Venezuela BTC")
    {
        require(bytes(initialMetadataURI).length > 0, "Metadata URI required");
        
        WBTC = IERC20(wbtcAddress);
        uniswapPoolManager = poolManager;
        
        _tokenURI = initialMetadataURI;
        metadataOwner = msg.sender;
        
        _mint(uniswapPoolManager, 16_000_000 * 10**18);
        _mint(msg.sender, 5_000_000 * 10**18);
    }

    function tokenURI() external view returns (string memory) {
        return _tokenURI;
    }

    function updateMetadata(string memory newMetadataURI) external onlyMetadataOwner {
        require(bytes(newMetadataURI).length > 0, "Metadata URI required");
        _tokenURI = newMetadataURI;
        emit MetadataUpdated(newMetadataURI, msg.sender);
    }

    function transferMetadataOwnership(address newOwner) external onlyMetadataOwner {
        require(newOwner != address(0), "New owner cannot be zero");
        metadataOwner = newOwner;
    }

    function mint(uint256 wbtcAmount) external nonReentrant {
        if (wbtcAmount == 0) revert ZeroAmount();
        uint256 tokenAmount = _wbtcToToken(wbtcAmount);
        uint256 newTotalSupply = totalSupply() + tokenAmount;
        if (newTotalSupply > CAP) revert CapExceeded();
        bool success = WBTC.transferFrom(msg.sender, address(this), wbtcAmount);
        if (!success) revert InvalidWBTCTransfer();
        totalReserve += wbtcAmount;
        if (_getCurrentReserveRatio() < RESERVE_RATIO) {
            revert BelowMinimumReserveRatio(_getCurrentReserveRatio(), RESERVE_RATIO);
        }
        _mint(msg.sender, tokenAmount);
        emit Minted(msg.sender, tokenAmount, wbtcAmount);
        emit ReserveUpdated(totalReserve, totalSupply());
    }

    function burnToWBTC(uint256 tokenAmount) external nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        uint256 wbtcAmount = _tokenToWBTC(tokenAmount);
        uint256 newTotalSupply = totalSupply() - tokenAmount;
        uint256 newReserve = totalReserve - wbtcAmount;
        if (wbtcAmount > totalReserve) revert InsufficientReserve(wbtcAmount, totalReserve);
        if (newTotalSupply > 0) {
            uint256 newRatio = (newReserve * TOKEN_PER_WBTC * PRECISION) / newTotalSupply;
            if (newRatio < RESERVE_RATIO) {
                revert BelowMinimumReserveRatio(newRatio, RESERVE_RATIO);
            }
        }
        _burn(msg.sender, tokenAmount);
        totalReserve = newReserve;
        bool success = WBTC.transfer(msg.sender, wbtcAmount);
        if (!success) revert InvalidWBTCTransfer();
        emit Burned(msg.sender, tokenAmount, wbtcAmount);
        emit ReserveUpdated(totalReserve, totalSupply());
    }

    function wbtcToToken(uint256 wbtcAmount) external pure returns (uint256) {
        return _wbtcToToken(wbtcAmount);
    }

    function tokenToWBTC(uint256 tokenAmount) external pure returns (uint256) {
        return _tokenToWBTC(tokenAmount);
    }

    function getCurrentReserveRatio() external view returns (uint256) {
        return _getCurrentReserveRatio();
    }

    function canMint(uint256 wbtcAmount) external view returns (bool) {
        uint256 tokenAmount = _wbtcToToken(wbtcAmount);
        uint256 newSupply = totalSupply() + tokenAmount;
        if (newSupply > CAP) return false;
        uint256 newReserve = totalReserve + wbtcAmount;
        uint256 newRatio = (newReserve * TOKEN_PER_WBTC * PRECISION) / newSupply;
        return newRatio >= RESERVE_RATIO;
    }

    function canBurn(uint256 tokenAmount) external view returns (bool) {
        uint256 wbtcAmount = _tokenToWBTC(tokenAmount);
        if (wbtcAmount > totalReserve) return false;
        uint256 newSupply = totalSupply() - tokenAmount;
        if (newSupply == 0) return true;
        uint256 newReserve = totalReserve - wbtcAmount;
        uint256 newRatio = (newReserve * TOKEN_PER_WBTC * PRECISION) / newSupply;
        return newRatio >= RESERVE_RATIO;
    }

    function getPriceInWBTC() external pure returns (uint256) {
        return 1 ether / (TOKEN_PER_WBTC / 10**18);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function _wbtcToToken(uint256 wbtcAmount) private pure returns (uint256) {
        return wbtcAmount * TOKEN_PER_WBTC / (10**WBTC_DECIMALS);
    }

    function _tokenToWBTC(uint256 tokenAmount) private pure returns (uint256) {
        return tokenAmount * (10**WBTC_DECIMALS) / TOKEN_PER_WBTC;
    }

    function _getCurrentReserveRatio() private view returns (uint256) {
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) return 100 * PRECISION;
        return (totalReserve * TOKEN_PER_WBTC * PRECISION) / currentSupply;
    }
}
