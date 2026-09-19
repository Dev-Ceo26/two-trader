// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IMPUSD} from "../src/IMPUSD.sol";
import {MasterMinter} from "../src/MasterMinter.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract IMPUSDTest is Test {
    IMPUSD public token;
    MasterMinter public masterMinter;
    MockUSDC public usdc;
    MockUSDT public usdt;
    ERC1967Proxy public proxy;

    address public admin = address(0xA);
    address public pauser = address(0xB);
    address public feeCollector = address(0xC);
    address public vault = address(0xD);
    address public user = address(0xE);

    uint256 constant ONE_USD = 1000 * 10**6;

    function setUp() public {
        vm.startPrank(admin);

        usdc = new MockUSDC(admin);
        usdt = new MockUSDT(admin);
        masterMinter = new MasterMinter(admin);

        IMPUSD impl = new IMPUSD();
        bytes memory initData = abi.encodeWithSelector(
            IMPUSD.initialize.selector,
            address(usdc),
            address(usdt),
            address(masterMinter),
            pauser,
            feeCollector,
            vault,
            admin
        );
        proxy = new ERC1967Proxy(address(impl), initData);
        token = IMPUSD(address(proxy));
        masterMinter.setToken(address(proxy));

        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(token.name(), "Imperium USD");
        assertEq(token.symbol(), "tIMPUSD");
        assertEq(token.decimals(), 6);
        assertEq(token.MAX_SUPPLY(), 3_000_000_000 * 10**6);
        assertEq(token.totalSupply(), 0);
        assertEq(token.usdc(), address(usdc));
        assertEq(token.usdt(), address(usdt));
        assertEq(token.pauser(), pauser);
    }

    function testDepositAndMint() public {
        usdc.mint(user, ONE_USD);

        vm.startPrank(user);
        bool ok = usdc.approve(address(token), ONE_USD);
        require(ok);
        uint256 minted = token.depositReserveAndMint(address(usdc), ONE_USD, user);
        vm.stopPrank();

        assertEq(minted, ONE_USD);
        assertEq(token.balanceOf(user), ONE_USD);
        assertEq(token.totalSupply(), ONE_USD);
        assertEq(token.totalReserveValue(), ONE_USD);
        assertEq(token.reserveBalances(address(usdc)), ONE_USD);
    }

    function testBurnAndWithdraw() public {
        usdc.mint(user, ONE_USD);
        usdt.mint(user, ONE_USD);

        vm.startPrank(user);
        bool ok1 = usdc.approve(address(token), ONE_USD);
        require(ok1);
        bool ok2 = usdt.approve(address(token), ONE_USD);
        require(ok2);
        token.depositReserveAndMint(address(usdc), ONE_USD, user);
        token.depositReserveAndMint(address(usdt), ONE_USD, user);
        token.burnAndWithdrawReserve(ONE_USD);
        vm.stopPrank();

        // Brucia 1000 IMPUSD, riceve 500 USDC + 500 USDT (50/50)
        assertEq(token.balanceOf(user), ONE_USD);
        assertEq(token.totalSupply(), ONE_USD);
        assertEq(usdc.balanceOf(user), ONE_USD - (ONE_USD / 2));
        assertEq(usdt.balanceOf(user), ONE_USD - (ONE_USD / 2));
    }

    function testPause() public {
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        vm.prank(pauser);
        token.unpause();
        assertFalse(token.paused());
    }

    function testCannotPauseFromNonPauser() public {
        vm.prank(user);
        vm.expectRevert("IMPUSD: only pauser");
        token.pause();
    }

    function testReserveDistribution() public view {
        (uint256 u, uint256 t) = token.getRequiredReserveDistribution(ONE_USD);
        assertEq(u, 500 * 10**6);
        assertEq(t, 500 * 10**6);
    }

    function testVaultAuthorization() public {
        assertTrue(token.vaultAuthorized());
        vm.prank(vault);
        token.setFeesEnabled(true);
        assertTrue(token.feesEnabled());
    }

    function testMinterConfiguration() public {
        vm.prank(admin);
        masterMinter.configureMinter(user, ONE_USD);
        assertTrue(token.isMinter(user));
    }

    function testCannotMintExceedMaxSupply() public {
        uint256 huge = token.MAX_SUPPLY() + 1;
        usdc.mint(user, huge);

        vm.startPrank(user);
        bool ok = usdc.approve(address(token), huge);
        require(ok);
        vm.expectRevert("IMPUSD: exceeds max supply");
        token.depositReserveAndMint(address(usdc), huge, user);
        vm.stopPrank();
    }

    function testFullyCollateralized() public {
        usdc.mint(user, ONE_USD / 2);

        vm.startPrank(user);
        bool ok = usdc.approve(address(token), ONE_USD / 2);
        require(ok);
        token.depositReserveAndMint(address(usdc), ONE_USD / 2, user);
        vm.stopPrank();

        assertTrue(token.isFullyCollateralized());
        assertEq(token.getReserveCoverage(), 10_000);
    }
}
