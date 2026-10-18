# Scope — SLE v1 Audit

> **Destinatari**: auditor esterni
> **Scopo**: definire esattamente cosa è in scope, cosa è escluso, e con quale priorità

---

## 1. In Scope (da auditare)

| # | Contratto | Percorso | LOC | Priorità |
|---|---|---|---|---|
| 1 | SLEAddressProvider | contracts/sle/core/SLEAddressProvider.sol | ~60 | CRITICA |
| 2 | PoolRegistry | contracts/sle/core/PoolRegistry.sol | ~100 | ALTA |
| 3 | ConstantProductCurve | contracts/sle/curves/ConstantProductCurve.sol | ~60 | CRITICA |
| 4 | RegimeDetector | contracts/sle/core/RegimeDetector.sol | ~180 | CRITICA |
| 5 | StrategySelector | contracts/sle/core/StrategySelector.sol | ~130 | CRITICA |
| 6 | PoolManager | contracts/sle/core/PoolManager.sol | ~250 | CRITICA |
| 7 | T2TRouter | contracts/sle/core/T2TRouter.sol | ~130 | CRITICA |
| 8 | ProportionalMath | contracts/sle/libraries/ProportionalMath.sol | ~80 | CRITICA |
| 9 | CalmStrategy | contracts/sle/strategies/CalmStrategy.sol | ~40 | MEDIA |
| 10 | VolatileStrategy | contracts/sle/strategies/VolatileStrategy.sol | ~40 | MEDIA |
| 11 | CriticalStrategy | contracts/sle/strategies/CriticalStrategy.sol | ~50 | ALTA |
| 12-18 | Interfacce (I*.sol) | contracts/sle/interfaces/ | ~200 | BASSA |

**Totale in scope**: 18 contratti, ~1.300 LOC.

---

## 2. Fuori scope (esplicito)

Il repository è stato ripulito. **NON contiene**:

| Componente | Stato |
|---|---|
| contracts/v4/ (Uniswap v4 fork BUSL) | ❌ Rimosso (2026-10-18) |
| contracts/maker/ (V2-style AMM) | ❌ Rimosso |
| contracts/bridge/ | ❌ Rimosso |
| contracts/governance/ (DAO, Guardian) | ❌ Rimosso |
| contracts/token/ (TwoTrader, tTwoTrader) | ❌ Rimosso |
| contracts/staking/, vault/, faucet/, distribution/, decisions/, test/ | ❌ Rimosso |
| _legacy/, _backup/, foundry-pp/ | ❌ Rimosso |
| node_modules/, package.json | ❌ Rimosso |
| Script di deploy legacy (tutti tranne DeploySLE.s.sol) | ❌ Rimosso |
| Test legacy (tutti tranne test/sle/) | ❌ Rimosso |
| Submodule v4-core, v4-periphery, openzeppelin-*-upgradeable, foundry-upgrades | ❌ Rimosso |

**Il repository contiene SOLO SLE v1 + test + audit package + brand docs.**

---

## 3. Priorità di audit

(identiche alla versione precedente — CRITICA, ALTA, MEDIA, BASSA)

## 4. Aree di focus specifico

(identiche alla versione precedente)

## 5. Test coverage

| Area | Test | Coverage |
|---|---|---|
| Access control | 12 | ~95% |
| Accounting | 24 | ~90% |
| Matematica 512-bit | 20 | ~100% |
| Fail-closed | 17 | ~90% |
| Fee-on-transfer | 3 | ~85% |
| Reentrancy | 1 | ~80% |
| Boundary | 16 | ~85% |
| E2E | 21 | ~90% |

## 6. Deliverable attesi dall'auditor

(identici alla versione precedente)

## 7. Tempistiche stimate

~2 settimane.

---

*Documento aggiornato il 2026-10-18 dopo pulizia repo (6.134 file rimossi).*
