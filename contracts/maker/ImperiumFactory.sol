// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ImperiumPair} from "./ImperiumPair.sol";

/**
 * @title ImperiumFactory
 * @notice Factory per creare coppie AMM (ImperiumPair).
 * @dev UUPS upgradable, Ownable (transitorio). In futuro: DAO.
 */
contract ImperiumFactory is UUPSUpgradeable, OwnableUpgradeable {
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max

    address[] public allPairs;
    mapping(address => mapping(address => address)) public getPair;
    uint256 public defaultFeeBps;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 count
    );
    event DefaultFeeUpdated(uint256 oldBps, uint256 newBps);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        require(initialOwner != address(0), "owner zero");
        __Ownable_init(initialOwner);
        defaultFeeBps = 30; // 0.3%
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setDefaultFee(uint256 newBps) external onlyOwner {
        require(newBps <= MAX_FEE_BPS, "fee too high");
        uint256 oldBps = defaultFeeBps;
        defaultFeeBps = newBps;
        emit DefaultFeeUpdated(oldBps, newBps);
    }

    function createPair(address tokenA, address tokenB)
        external
        onlyOwner
        returns (address pair)
    {
        require(tokenA != address(0) && tokenB != address(0), "zero token");
        require(tokenA != tokenB, "same token");

        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(getPair[t0][t1] == address(0), "pair exists");

        pair = Upgrades.deployUUPSProxy(
            "ImperiumPair.sol:ImperiumPair",
            abi.encodeCall(ImperiumPair.initialize, (t0, t1, owner(), defaultFeeBps))
        );

        getPair[t0][t1] = pair;
        allPairs.push(pair);

        emit PairCreated(t0, t1, pair, allPairs.length);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}
