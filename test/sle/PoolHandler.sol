// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "../../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../../contracts/sle/core/PoolRegistry.sol";
import {T2TRouter} from "../../contracts/sle/core/T2TRouter.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {StrategySelector} from "../../contracts/sle/core/StrategySelector.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";
import {CalmStrategy} from "../../contracts/sle/strategies/CalmStrategy.sol";
import {VolatileStrategy} from "../../contracts/sle/strategies/VolatileStrategy.sol";
import {CriticalStrategy} from "../../contracts/sle/strategies/CriticalStrategy.sol";
import {IRegimeDetector} from "../../contracts/sle/interfaces/IRegimeDetector.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @dev Detector sempre CALM valido (per invarianti non testare fail-closed)
contract AlwaysCalmDetector is IRegimeDetector {
    function getMarketState(bytes32) external view override returns (uint8, uint256, bool) {
        return (0, block.number, true); // CALM, valido
    }
}

/// @dev Handler: espone azioni random a Foundry. Traccia ghost per invarianti.
contract PoolHandler is Test {
    PoolManager public immutable pm;
    T2TRouter public immutable router;
    PoolRegistry public immutable registry;
    MockERC20 public immutable token0;
    MockERC20 public immutable token1;
    bytes32 public immutable poolId;

    address[] public actors;
    address internal currentActor;

    // Ghost: LP depositate note per utente (per INV-1)
    mapping(address => uint256) public ghost_lpDeposited;
    mapping(address => uint256) public ghost_lpWithdrawn;

    // Ghost: contatori operazioni (per debug)
    uint256 public ghost_swaps;
    uint256 public ghost_adds;
    uint256 public ghost_removes;

    // Ghost: violazione k dopo swap (per INV-3)
    bool public ghost_kViolation;

    modifier useActor() {
        currentActor = actors[bound(_random(), 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(
        PoolManager _pm, T2TRouter _router, PoolRegistry _registry,
        MockERC20 _token0, MockERC20 _token1, bytes32 _poolId,
        address[] memory _actors
    ) {
        pm = _pm;
        router = _router;
        registry = _registry;
        token0 = _token0;
        token1 = _token1;
        poolId = _poolId;
        actors = _actors;
    }

    function _random() internal view returns (uint256) {
        return uint256(keccak256(abi.encode(block.timestamp, block.number, gasleft())));
    }

    // ───────────── Actions ─────────────

    function addLiquidity(uint256 amount0, uint256 amount1) external useActor {
        // Bounded: [1e18, 100_000e18]
        amount0 = bound(amount0, 1e18, 100_000e18);
        amount1 = bound(amount1, 1e18, 100_000e18);

        // Rendi proporzionale al pool corrente (per rispettare tolleranza 1 bps)
        (uint256 r0, uint256 r1) = pm.getReserves(poolId);
        if (r0 > 0 && r1 > 0) {
            amount1 = (amount0 * r1) / r0;
            if (amount1 == 0) return;
        }

        try router.addLiquidity(poolId, amount0, amount1) returns (uint256 lp) {
            ghost_lpDeposited[currentActor] += lp;
            ghost_adds++;
        } catch {
            // Se fallisce (es. proporzionale, saldo), skip silenzioso
        }
    }

    function removeLiquidity(uint256 lpFrac) external useActor {
        uint256 balance = pm.getLPBalance(poolId, currentActor);
        if (balance == 0) return;

        lpFrac = bound(lpFrac, 1, 100);
        uint256 lpAmount = (balance * lpFrac) / 100;
        if (lpAmount == 0) return;

        try router.removeLiquidity(poolId, lpAmount, currentActor) {
            ghost_lpWithdrawn[currentActor] += lpAmount;
            ghost_removes++;
        } catch {}
    }

    function swap(uint256 amountIn, bool zeroForOne) external useActor {
        amountIn = bound(amountIn, 1e6, 100_000e18);

        // Verifica saldo
        uint256 bal = zeroForOne ? token0.balanceOf(currentActor) : token1.balanceOf(currentActor);
        if (bal < amountIn) return;

        // Cattura k before
        (uint256 r0Before, uint256 r1Before) = pm.getReserves(poolId);
        uint256 kBefore = r0Before * r1Before;

        // Esegui swap
        try router.swap(poolId, zeroForOne, amountIn, 0, currentActor, block.timestamp + 100) {
            ghost_swaps++;

            // Verifica k after: deve essere >= kBefore (le fee fanno crescere k)
            (uint256 r0After, uint256 r1After) = pm.getReserves(poolId);
            uint256 kAfter = r0After * r1After;
            if (kAfter < kBefore) {
                ghost_kViolation = true;
            }
        } catch {}
    }

    // ───────────── Views per invarianti ─────────────

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i];
    }

    function totalGhostLP() external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < actors.length; i++) {
            total += ghost_lpDeposited[actors[i]] - ghost_lpWithdrawn[actors[i]];
        }
        return total;
    }
}
