// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IIMPUSD {
    function configureMinter(address minter, uint256 allowance) external returns (bool);
    function removeMinter(address minter) external returns (bool);
    function isMinter(address account) external view returns (bool);
    function minterAllowance(address minter) external view returns (uint256);
}

contract MasterMinter is Ownable {
    IIMPUSD public token;

    event MinterConfigured(address indexed minter, uint256 allowance);
    event MinterRemoved(address indexed minter);
    event TokenSet(address indexed token);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "MasterMinter: zero token");
        token = IIMPUSD(_token);
        emit TokenSet(_token);
    }

    function configureMinter(address minter, uint256 allowance) external onlyOwner {
        require(minter != address(0), "MasterMinter: zero minter");
        require(allowance > 0, "MasterMinter: allowance > 0");
        require(address(token) != address(0), "MasterMinter: token not set");
        require(token.configureMinter(minter, allowance), "MasterMinter: configure failed");
        emit MinterConfigured(minter, allowance);
    }

    function removeMinter(address minter) external onlyOwner {
        require(minter != address(0), "MasterMinter: zero minter");
        require(address(token) != address(0), "MasterMinter: token not set");
        require(token.removeMinter(minter), "MasterMinter: remove failed");
        emit MinterRemoved(minter);
    }

    function isMinter(address account) external view returns (bool) {
        require(address(token) != address(0), "MasterMinter: token not set");
        return token.isMinter(account);
    }

    function minterAllowance(address minter) external view returns (uint256) {
        require(address(token) != address(0), "MasterMinter: token not set");
        return token.minterAllowance(minter);
    }
}
