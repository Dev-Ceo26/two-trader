// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "v4-core/types/Currency.sol";
import {CurrencyReserves} from "v4-core/libraries/CurrencyReserves.sol";
import {IProtocolFees} from "v4-core/interfaces/IProtocolFees.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ProtocolFeeLibrary} from "v4-core/libraries/ProtocolFeeLibrary.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Pool} from "v4-core/libraries/Pool.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";

/// @notice Contract handling the setting and accrual of protocol fees
abstract contract ImperiumProtocolFees is IProtocolFees, OwnableUpgradeable {
    using ProtocolFeeLibrary for uint24;
    using Pool for Pool.State;
    using CustomRevert for bytes4;

    /// @inheritdoc IProtocolFees
    mapping(Currency currency => uint256 amount) public protocolFeesAccrued;

    /// @inheritdoc IProtocolFees
    address public protocolFeeController;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @custom:oz-upgrades-unsafe-allow missing-initializer-call
    function __ImperiumProtocolFees_init(address initialOwner) internal onlyInitializing {
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc IProtocolFees
    function setProtocolFeeController(address controller) external onlyOwner {
        protocolFeeController = controller;
        emit ProtocolFeeControllerUpdated(controller);
    }

    /// @inheritdoc IProtocolFees
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external {
        if (msg.sender != protocolFeeController) InvalidCaller.selector.revertWith();
        if (!newProtocolFee.isValidProtocolFee()) ProtocolFeeTooLarge.selector.revertWith(newProtocolFee);
        PoolId id = key.toId();
        _getPool(id).setProtocolFee(newProtocolFee);
        emit ProtocolFeeUpdated(id, newProtocolFee);
    }

    /// @inheritdoc IProtocolFees
    function collectProtocolFees(address recipient, Currency currency, uint256 amount)
        external
        returns (uint256 amountCollected)
    {
        if (msg.sender != protocolFeeController) InvalidCaller.selector.revertWith();
        if (!currency.isAddressZero() && CurrencyReserves.getSyncedCurrency() == currency) {
            ProtocolFeeCurrencySynced.selector.revertWith();
        }

        amountCollected = (amount == 0) ? protocolFeesAccrued[currency] : amount;
        protocolFeesAccrued[currency] -= amountCollected;
        currency.transfer(recipient, amountCollected);
    }

    function _isUnlocked() internal virtual returns (bool);
    function _getPool(PoolId id) internal virtual returns (Pool.State storage);

    function _updateProtocolFees(Currency currency, uint256 amount) internal {
        unchecked {
            protocolFeesAccrued[currency] += amount;
        }
    }
}
