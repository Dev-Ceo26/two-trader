# Scope — SLE v1 Audit

> **Destinatari**: auditor esterni
> **Scopo**: definire esattamente cosa è in scope, cosa è escluso, e con quale priorità

---

## 1. In Scope (da auditare)

| # | Contratto | Percorso | LOC | Priorità |
|---|---|---|---|---|
| 1 | `SLEAddressProvider` | `contracts/sle/core/SLEAddressProvider.sol` | ~60 | **CRITICA** |
| 2 | `PoolRegistry` | `contracts/sle/core/PoolRegistry.sol` | ~100 | ALTA |
| 3 | `ConstantProductCurve` | `contracts/sle/curves/ConstantProductCurve.sol` | ~60 | **CRITICA** |
| 4 | `RegimeDetector` | `contracts/sle/core/RegimeDetector.sol` | ~180 | **CRITICA** |
| 5 | `StrategySelector` | `contracts/sle/core/StrategySelector.sol` | ~130 | **CRITICA** |
| 6 | `PoolManager` | `contracts/sle/core/PoolManager.sol` | ~250 | **CRITICA** |
| 7 | `T2TRouter` | `contracts/sle/core/T2TRouter.sol` | ~130 | **CRITICA** |
| 8 | `ProportionalMath` | `contracts/sle/libraries/ProportionalMath.sol` | ~80 | **CRITICA** |
| 9 | `CalmStrategy` | `contracts/sle/strategies/CalmStrategy.sol` | ~40 | MEDIA |
| 10 | `VolatileStrategy` | `contracts/sle/strategies/VolatileStrategy.sol` | ~40 | MEDIA |
| 11 | `CriticalStrategy` | `contracts/sle/strategies/CriticalStrategy.sol` | ~50 | ALTA |
| 12 | `ISLEAddressProvider` | `contracts/sle/interfaces/ISLEAddressProvider.sol` | ~30 | BASSA |
| 13 | `IPoolManager` | `contracts/sle/interfaces/IPoolManager.sol` | ~50 | BASSA |
| 14 | `IT2TRouter` | `contracts/sle/interfaces/IT2TRouter.sol` | ~40 | BASSA |
| 15 | `IStrategy` | `contracts/sle/interfaces/IStrategy.sol` | ~30 | BASSA |
| 16 | `IStrategySelector` | `contracts/sle/interfaces/IStrategySelector.sol` | ~20 | BASSA |
| 17 | `IRegimeDetector` | `contracts/sle/interfaces/IRegimeDetector.sol` | ~20 | BASSA |
| 18 | `ICurve` | `contracts/sle/interfaces/ICurve.sol` | ~30 | BASSA |

**Totale in scope**: 18 contratti, ~1.300 LOC.

## 2. Fuori scope (esplicito)

| Componente | Motivo esclusione |
|---|---|
| `contracts/v4/` | Non deployato in mainnet, non fa parte di SLE |
| `contracts/token/` (TwoTrader, tTwoTrader) | Token ERC20 standard OpenZeppelin, non modificato |
| `contracts/bridge/` | Layer separato, non nel flusso SLE |
| `contracts/governance/` (T2TDAO) | Governance on-chain, non in SLE v1 |
| `_legacy/` | Backup storici, non deployati |
| `lib/` (OpenZeppelin, forge-std) | Librerie standard, assumiamo sicure |
| `qpos-consensus/` (Rust) | Layer consenso, fuori scope Solidity |
| Frontend, landing page | Web2, non smart contract |

## 3. Priorità di audit

### CRITICA (auditare per primo)
- `PoolManager` — contabilità, invarianti
- `ProportionalMath` — matematica 512-bit
- `T2TRouter` — access control, transferFrom
- `SLEAddressProvider` — risolve dipendenza circolare
- `RegimeDetector` + `StrategySelector` — fail-closed matrix

**Se trovi un bug qui, può causare perdita di fondi.**

### ALTA
- `PoolRegistry` — whitelist curve
- `ConstantProductCurve` — formula swap
- `CriticalStrategy` — blocca swap in CRITICAL

**Se trovi un bug qui, può causare DoS o comportamento anomalo.**

### MEDIA
- `CalmStrategy`, `VolatileStrategy` — solo fee, no blocchi

**Se trovi un bug qui, impatta l'UX ma non la sicurezza dei fondi.**

### BASSA
- Interfacce (`I*.sol`) — solo firme, nessuna logica

**Se trovi un bug qui, è tipico o di design.**

## 4. Aree di focus specifico

L'auditor è invitato a concentrarsi su:

### 4.1 Access control
- `PoolManager.onlyRouter` legge da `provider.router()`: può essere aggirato?
- `T2TRouter` è l'unico entry point? Un utente può chiamare `pm.swap` direttamente?
- `provider.setEndpoints` può essere chiamato due volte?
- `StrategySelector.setStrategy` può essere chiamato da non-owner?

### 4.2 Accounting e invariant
- `reserve + feeAccrued` == `token.balanceOf(pm)`?
- Il prelievo con arrotondamento restituisce esattamente `feeShare + resShare`?
- `MINIMUM_LIQUIDITY` è riscattabile?
- Overflow/underflow in `removeLiquidity`?

### 4.3 Matematica
- `ProportionalMath.proportionalEnough` è corretta per input > 2^128?
- `ConstantProductCurve.getAmountOut` rispetta `k_after >= k_before`?
- `Math.mulDiv` con `Rounding.Ceil` è usato correttamente?

### 4.4 Fail-closed
- Se `detector.getMarketState` reverte, il Selector blocca?
- Se `strategy.proposeFee` reverte in CRITICAL, il Selector blocca?
- Se `detector` è stale, il Selector blocca?
- Il fallback `DEFAULT_FEE=30` è attivato solo in regime non-critico?

### 4.5 Token non standard
- Fee-on-transfer: `_safeTransferIn` reverte correttamente?
- USDT-like (forceApprove): il Router resetta a 0?
- Token con `transferFrom` che non trasferisce nulla: rilevato?

### 4.6 Reentrancy
- `nonReentrant` su tutte le funzioni di stato?
- Checks-Effects-Interactions rispettato?
- Callback ERC777/ERC1363 possono rientrare?

## 5. Test coverage noti

| Area | Coverage stimata | Note |
|---|---|---|
| Access control | ~95% | `test_swap_directCallReverts`, ecc. |
| Accounting | ~90% | Fuzz + invariant |
| Matematica | ~100% | 20 test isolati ProportionalMath |
| Fail-closed | ~90% | EndToEndFailClosed.t.sol |
| Fee-on-transfer | ~85% | MockFeeToken |
| Reentrancy | ~80% | 1 test (swap), espandibile |
| Boundary | ~85% | Fuzz su tutti i main path |

**Aree con coverage < 90% sono candidati per audit manuale approfondito.**

## 6. Deliverable attesi dall'auditor

| Deliverable | Formato |
|---|---|
| Report finale | PDF/Markdown |
| Lista finding | Severity + descrizione + PoC + fix suggerito |
| Classificazione | Critical / High / Medium / Low / Info |
| Retest | Verifica fix dopo patch |
| Attestazione | Firma auditore |

## 7. Tempistiche stimate

| Fase | Durata |
|---|---|
| Kick-off + lettura documentazione | 1 giorno |
| Analisi statica + manual review | 5-7 giorni |
| Test dinamici + PoC | 2-3 giorni |
| Report + review | 2 giorni |
| Retest post-fix | 1-2 giorni |
| **Totale** | **~2 settimane** |

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
