// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../contracts/sle/core/PoolRegistry.sol";
import {T2TRouter} from "../contracts/sle/core/T2TRouter.sol";
import {SLEAddressProvider} from "../contracts/sle/core/SLEAddressProvider.sol";
import {StrategySelector} from "../contracts/sle/core/StrategySelector.sol";
import {RegimeDetector} from "../contracts/sle/core/RegimeDetector.sol";
import {ConstantProductCurve} from "../contracts/sle/curves/ConstantProductCurve.sol";
import {CalmStrategy} from "../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../contracts/sle/strategies/CriticalStrategy.sol";

/// @title DeploySLE
/// @notice Deploya l'intero stack SLE v1 in ordine, risolve il ciclo
///         provider<->router<->pm tramite SLEAddressProvider, e verifica
///         la configurazione incrociata.
/// @dev Ordine:
///      1. SLEAddressProvider
///      2. PoolRegistry
///      3. ConstantProductCurve
///      4. RegimeDetector
///      5. CalmStrategy, VolatileStrategy, CriticalStrategy
///      6. StrategySelector (richiede detector)
///      7. PoolManager (richiede registry + provider)
///      8. T2TRouter (richiede provider, selector, registry)
///      9. Registra le 3 strategie nel Selector
///     10. Configura il provider: setEndpoints(router, pm)
///     11. Verifica incrociata + rinuncia ownership provider
contract DeploySLE is Script {
    struct Deployment {
        address provider;
        address registry;
        address curve;
        address detector;
        address calmStrategy;
        address volatileStrategy;
        address criticalStrategy;
        address selector;
        address poolManager;
        address router;
    }

    function run() external returns (Deployment memory d) {
        address deployer = vm.envAddress("DEPLOYER");
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);

        console.log("=== SLE v1 Deploy ===");
        console.log("Deployer:", deployer);
        console.log("Admin:   ", admin);
        console.log("ChainID: ", block.chainid);

        vm.startBroadcast();

        // 1. Provider
        SLEAddressProvider provider = new SLEAddressProvider(deployer);
        d.provider = address(provider);
        console.log("1. SLEAddressProvider:", d.provider);

        // 2. PoolRegistry
        PoolRegistry registry = new PoolRegistry(deployer);
        d.registry = address(registry);
        console.log("2. PoolRegistry:     ", d.registry);

        // 3. Curve
        ConstantProductCurve curve = new ConstantProductCurve();
        d.curve = address(curve);
        console.log("3. ConstantProductCurve:", d.curve);

        // 4. RegimeDetector
        RegimeDetector detector = new RegimeDetector(deployer);
        d.detector = address(detector);
        console.log("4. RegimeDetector:   ", d.detector);

        // 5. Strategie
        CalmStrategy calm = new CalmStrategy();
        d.calmStrategy = address(calm);
        console.log("5a. CalmStrategy:    ", d.calmStrategy);

        VolatileStrategy volatileS = new VolatileStrategy();
        d.volatileStrategy = address(volatileS);
        console.log("5b. VolatileStrategy:", d.volatileStrategy);

        CriticalStrategy critical = new CriticalStrategy();
        d.criticalStrategy = address(critical);
        console.log("5c. CriticalStrategy:", d.criticalStrategy);

        // 6. StrategySelector
        StrategySelector selector = new StrategySelector(address(detector), deployer);
        d.selector = address(selector);
        console.log("6. StrategySelector: ", d.selector);

        // 7. PoolManager (con provider, non router)
        PoolManager pm = new PoolManager(address(registry), address(provider));
        d.poolManager = address(pm);
        console.log("7. PoolManager:      ", d.poolManager);

        // 8. Router (con provider, non pm)
        T2TRouter router = new T2TRouter(address(provider), address(selector), address(registry));
        d.router = address(router);
        console.log("8. T2TRouter:        ", d.router);

        // 9. Registra strategie nel Selector
        selector.setStrategy(0, address(calm));      // CALM
        selector.setStrategy(1, address(volatileS)); // VOLATILE
        selector.setStrategy(4, address(critical));  // CRITICAL
        console.log("9. Strategies registered in Selector");

        // 10. Whitelist curva + setup
        registry.whitelistCurve(address(curve), true);
        console.log("10. Curve whitelisted");

        // 11. Configura provider (one-shot)
        provider.setEndpoints(address(router), address(pm));
        console.log("11. Provider configured (one-shot)");

        // 12. Rinuncia ownership del provider (deploy non piu' modificabile)
        provider.transferOwnership(admin);
        console.log("12. Provider ownership -> admin:", admin);

        // 13. Trasferisci ownership degli altri contratti all'admin (per governance futura)
        // (il Timelock/DAO li prendera' in carico dopo il setup)
        // registry.transferOwnership(admin);    // gia' deployato con deployer = owner, skip

        vm.stopBroadcast();

        // ───────────── Verifica incrociata ─────────────
        _verify(d, admin);
    }

    function _verify(Deployment memory d, address admin) internal view {
        console.log("");
        console.log("=== VERIFICA INCROCIATA ===");

        SLEAddressProvider provider = SLEAddressProvider(d.provider);
        PoolManager pm = PoolManager(d.poolManager);
        T2TRouter router = T2TRouter(d.router);

        require(provider.isConfigured(), "VERIFY: provider not configured");
        console.log("OK: provider.isConfigured() == true");

        require(provider.router() == d.router, "VERIFY: provider.router != router");
        console.log("OK: provider.router() == router");

        require(provider.poolManager() == d.poolManager, "VERIFY: provider.pm != pm");
        console.log("OK: provider.poolManager() == poolManager");

        require(pm.router() == d.router, "VERIFY: pm.router != router");
        console.log("OK: pm.router() == router");

        require(address(router.provider()) == d.provider, "VERIFY: router.provider != provider");
        console.log("OK: router.provider() == provider");

        require(router.selector() == StrategySelector(d.selector), "VERIFY: router.selector != selector");
        console.log("OK: router.selector() == selector");

        require(address(router.registry()) == d.registry, "VERIFY: router.registry != registry");
        console.log("OK: router.registry() == registry");

        require(provider.owner() == admin, "VERIFY: provider.owner != admin");
        console.log("OK: provider.owner() == admin");

        console.log("");
        console.log("=== DEPLOY COMPLETE ===");
        console.log("Chain ID:", block.chainid);
        console.log("Provider:  ", d.provider);
        console.log("Registry:  ", d.registry);
        console.log("Curve:     ", d.curve);
        console.log("Detector:  ", d.detector);
        console.log("Selector:  ", d.selector);
        console.log("PoolManager:", d.poolManager);
        console.log("Router:    ", d.router);
    }
}
