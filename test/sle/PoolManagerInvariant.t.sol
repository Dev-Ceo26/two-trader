// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolManager} from "../../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../../contracts/sle/core/PoolRegistry.sol";
import {T2TRouter} from "../../contracts/sle/core/T2TRouter.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {StrategySelector} from "../../contracts/sle/core/StrategySelector.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";
import {CalmStrategy} from "../../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../../contracts/sle/strategies/CriticalStrategy.sol";
import {PoolHandler} from "./PoolHandler.sol";
import {MockERC20, AlwaysCalmDetector} from "./PoolHandler.sol";

contract PoolManagerInvariantTest is Test {
    PoolManager internal pm;
    PoolRegistry internal registry;
    T2TRouter internal router;
    SLEAddressProvider internal provider;
    StrategySelector internal selector;
    AlwaysCalmDetector internal detector;
    ConstantProductCurve internal curve;
    PoolHandler internal handler;

    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);
    address internal carol = address(0xDEAD);

    bytes32 internal poolId;

    function setUp() public {
        curve = new ConstantProductCurve();
        registry = new PoolRegistry(owner);
        detector = new AlwaysCalmDetector();
        selector = new StrategySelector(address(detector), owner);

        // Registra 3 strategie (ma AlwaysCalmDetector usa solo CALM)
        vm.startPrank(owner);
        selector.setStrategy(0, address(new CalmStrategy()));
        selector.setStrategy(1, address(new VolatileStrategy()));
        selector.setStrategy(4, address(new CriticalStrategy()));
        vm.stopPrank();

        provider = new SLEAddressProvider(owner);
        pm = new PoolManager(address(registry), address(provider));
        router = new T2TRouter(address(provider), address(selector), address(registry));
        vm.prank(owner);
        provider.setEndpoints(address(router), address(pm));

        token0 = new MockERC20("Token0", "T0");
        token1 = new MockERC20("Token1", "T1");
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);

        poolId = keccak256(abi.encode(address(token0), address(token1), address(curve)));

        vm.startPrank(owner);
        registry.whitelistCurve(address(curve), true);
        registry.registerPool(poolId, address(curve), address(token0), address(token1));
        registry.activatePool(poolId);
        vm.stopPrank();

        // Attori
        address[] memory actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;

        // Fondi + approve al Router
        for (uint256 i = 0; i < actors.length; i++) {
            token0.mint(actors[i], 10_000_000e18);
            token1.mint(actors[i], 10_000_000e18);
            vm.prank(actors[i]);
            token0.approve(address(router), type(uint256).max);
            vm.prank(actors[i]);
            token1.approve(address(router), type(uint256).max);
        }

        // Liquidità iniziale (Alice)
        vm.prank(alice);
        router.addLiquidity(poolId, 1_000_000e18, 1_000_000e18);

        // Handler
        handler = new PoolHandler(pm, router, registry, token0, token1, poolId, actors);

        // Target: solo handler
        targetContract(address(handler));
    }

    // ───────────── INV-1: LP supply coherent ─────────────

    /// @notice totalLPSupply == MINIMUM_LIQUIDITY + Σ lpBalances utenti
    function invariant_INV1_lpSupplyCoherent() public view {
        uint256 minLiq = pm.MINIMUM_LIQUIDITY();
        uint256 total = pm.getTotalLPSupply(poolId);

        uint256 sumUsers;
        uint256 n = handler.actorCount();
        for (uint256 i = 0; i < n; i++) {
            sumUsers += pm.getLPBalance(poolId, handler.actorAt(i));
        }

        assertEq(total, minLiq + sumUsers, "INV-1: total != MIN + sum(users)");
    }

    // ───────────── INV-2: token balance == reserves + fees ─────────────

    /// @notice Saldo token nel PM == reserve + fee per quel token
    function invariant_INV2_tokenBalanceMatchesAccounting() public view {
        (uint256 r0, uint256 r1) = pm.getReserves(poolId);
        (uint256 f0, uint256 f1) = pm.getFeesAccrued(poolId);

        assertEq(token0.balanceOf(address(pm)), r0 + f0, "INV-2: token0 balance mismatch");
        assertEq(token1.balanceOf(address(pm)), r1 + f1, "INV-2: token1 balance mismatch");
    }

    // ───────────── INV-3: k non diminuisce (testato dopo swap via handler) ─────────────

    /// @notice Dopo ogni swap, k non deve mai diminuire (le fee fanno solo crescere k)
    /// @dev Il check è fatto dentro il handler, che traccia ghost_kViolation.
    ///      Add/remove cambiano k fisiologicamente, non sono testati qui.
    function invariant_INV3_kNeverDecreasesAfterSwap() public view {
        assertFalse(handler.ghost_kViolation(), "INV-3: k decreased after a swap");
    }

    // ───────────── INV-4: fee cap (implicito) ─────────────

    /// @notice MAX_FEE costante = 200. Sempre enforced.
    function invariant_INV4_feeCapConstant() public view {
        assertEq(pm.MAX_FEE(), 200, "INV-4: MAX_FEE changed");
    }

    // ───────────── INV-5: MINIMUM_LIQUIDITY non riscattabile ─────────────

    /// @notice Le LP utente non possono superare total - MINIMUM_LIQUIDITY
    function invariant_INV5_minLiquidityLocked() public view {
        uint256 total = pm.getTotalLPSupply(poolId);
        uint256 sumUsers;
        uint256 n = handler.actorCount();
        for (uint256 i = 0; i < n; i++) {
            sumUsers += pm.getLPBalance(poolId, handler.actorAt(i));
        }
        assertLe(sumUsers, total - pm.MINIMUM_LIQUIDITY(), "INV-5: user LP > total - MIN");
    }

    // ───────────── INV-7: Router non trattiene token ─────────────

    /// @notice Il Router non deve mai trattenere token dopo operazioni riuscite
    function invariant_INV7_routerHoldsNoTokens() public view {
        assertEq(token0.balanceOf(address(router)), 0, "INV-7: router holds token0");
        assertEq(token1.balanceOf(address(router)), 0, "INV-7: router holds token1");
    }

    // ───────────── INV-8: allowance sempre azzerata ─────────────

    /// @notice Dopo ogni operazione, allowance Router->PM = 0
    function invariant_INV8_allowanceAlwaysZero() public view {
        assertEq(token0.allowance(address(router), address(pm)), 0, "INV-8: allowance t0 not 0");
        assertEq(token1.allowance(address(router), address(pm)), 0, "INV-8: allowance t1 not 0");
    }
}
