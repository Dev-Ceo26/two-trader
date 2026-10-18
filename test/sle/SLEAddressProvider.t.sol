// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {ISLEAddressProvider} from "../../contracts/sle/interfaces/ISLEAddressProvider.sol";

contract SLEAddressProviderTest is Test {
    SLEAddressProvider internal provider;
    address internal owner = address(0xA11CE);
    address internal attacker = address(0xBAD);
    address internal router = address(0x1000);
    address internal pm = address(0x2000);

    function setUp() public {
        provider = new SLEAddressProvider(owner);
    }

    function test_initialState_notConfigured() public view {
        assertFalse(provider.isConfigured());
        assertEq(provider.router(), address(0));
        assertEq(provider.poolManager(), address(0));
    }

    function test_setEndpoints_onlyOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        provider.setEndpoints(router, pm);
    }

    function test_setEndpoints_zeroReverts() public {
        vm.prank(owner);
        vm.expectRevert(ISLEAddressProvider.ZeroAddress.selector);
        provider.setEndpoints(address(0), pm);

        vm.prank(owner);
        vm.expectRevert(ISLEAddressProvider.ZeroAddress.selector);
        provider.setEndpoints(router, address(0));
    }

    function test_setEndpoints_sameAddrReverts() public {
        vm.prank(owner);
        vm.expectRevert(ISLEAddressProvider.EndpointsMismatch.selector);
        provider.setEndpoints(router, router);
    }

    function test_setEndpoints_success() public {
        vm.expectEmit(true, true, false, true);
        emit ISLEAddressProvider.EndpointsSet(router, pm);

        vm.prank(owner);
        provider.setEndpoints(router, pm);

        assertTrue(provider.isConfigured());
        assertEq(provider.router(), router);
        assertEq(provider.poolManager(), pm);
    }

    function test_setEndpoints_oneShot() public {
        vm.prank(owner);
        provider.setEndpoints(router, pm);

        vm.prank(owner);
        vm.expectRevert(ISLEAddressProvider.AlreadyConfigured.selector);
        provider.setEndpoints(address(0x9999), address(0x8888));
    }

    function test_setEndpoints_oneShotSameValues() public {
        vm.prank(owner);
        provider.setEndpoints(router, pm);

        vm.prank(owner);
        vm.expectRevert(ISLEAddressProvider.AlreadyConfigured.selector);
        provider.setEndpoints(router, pm);
    }
}
