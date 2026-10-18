# Architecture — SLE v1

> **Destinatari**: auditor tecnici
> **Prerequisiti**: conoscenza base di AMM, Solidity, Foundry

---

## 1. Diagramma componenti

┌─────────────┐
│ UTENTE │
│ (Trader/LP) │
└──────┬──────┘
│ approve + swap/add/remove
▼
┌─────────────────────────────────────────────┐
│ T2T ROUTER │
│ - transferFrom(user → router) │
│ - forceApprove(pm) │
│ - reset allowance │
│ - nonReentrant │
└──────┬──────────────────────────────┬───────┘
│ │
│ selectForSwap │ swap/add/remove
▼ ▼
┌──────────────┐ ┌──────────────────┐
│ SELECTOR │◄─────────────│ POOL MANAGER │
│ │ getMarketState │
│ - feeBps │ │ - reserves │
│ - blocked │ │ - feeAccrued │
└──────┬───────┘ │ - lpBalances │
│ │ - onlyRouter │
│ └────────┬─────────┘
│ │
├──► DETECTOR ├──► REGISTRY (getPool)
│ (regime, stale) │
│ ├──► CURVE (getAmountOut)
└──► STRATEGIE │
Calm/Volatile/Critical └──► PROVIDER (router addr)

text

---

## 2. Flusso Swap (dettagliato)
UTENTE
│ approve(Router, amountIn)
│ swap(poolId, zeroForOne, amountIn, minAmountOut, recipient, deadline)
▼
ROUTER
├─ deadline check, amountIn > 0, recipient != 0
├─ pmAddr = provider.poolManager()
├─ pool = registry.getPool(poolId)
├─ (r0, r1) = pm.getReserves(poolId)
├─ reserveIn = zeroForOne ? r0 : r1
│
├─ (feeBps, blocked) = selector.selectForSwap(poolId, amountIn, reserveIn)
│ │
│ ├─ detector.getMarketState(poolId) → (regime, lastBlock, valid)
│ ├─ if !valid → return (0, true) [fail-closed]
│ ├─ if regime == CRITICAL:
│ │ ├─ strategy = strategies[CRITICAL]
│ │ ├─ try proposeFee / shouldBlock
│ │ └─ on revert → return (0, true) [fail-closed]
│ ├─ else:
│ │ ├─ strategy = strategies[regime]
│ │ ├─ try proposeFee / shouldBlock
│ │ └─ on revert → return (DEFAULT_FEE=30, false) [fail-open]
│ └─ clamp fee to MAX_FEE (200)
│
├─ if blocked → revert BlockedByStrategy
├─ tokenIn = zeroForOne ? token0 : token1
├─ _safeTransferIn(tokenIn, amountIn) [check fee-on-transfer]
├─ tokenIn.forceApprove(pmAddr, amountIn)
│
├─ amountOut = pm.swap(poolId, zeroForOne, amountIn, minAmountOut, recipient, deadline, feeBps, msg.sender)
│ │
│ └─ POOLMANAGER.swap
│ ├─ onlyRouter check
│ ├─ deadline, amountIn, feeBps, recipient, payer validations
│ ├─ pool.active check
│ ├─ feeAmount = ceil(amountIn * feeBps / 10000)
│ ├─ amountAfterFee = amountIn - feeAmount
│ ├─ if amountAfterFee == 0 → revert
│ ├─ reserveIn + amountAfterFee overflow check
│ ├─ maxOut = reserveOut * amountAfterFee / (reserveIn + amountAfterFee)
│ ├─ amountOut = curve.getAmountOut(amountAfterFee, reserveIn, reserveOut)
│ ├─ if amountOut > maxOut → revert [safety net]
│ ├─ if amountOut < minAmountOut → revert
│ ├─ update reserves + feeAccrued (CEI: effects first)
│ ├─ _safeTransferIn(tokenIn, amountIn)
│ └─ tokenOut.safeTransfer(recipient, amountOut)
│
├─ tokenIn.forceApprove(pmAddr, 0) [allowance reset]
└─ emit SwapExecuted(...)

text

---

## 3. Flusso AddLiquidity
UTENTE
│ approve(Router, amount0, amount1)
│ addLiquidity(poolId, amount0, amount1)
▼
ROUTER
├─ amount > 0, pool attivo
├─ pmAddr = provider.poolManager()
├─ _safeTransferIn(token0, amount0)
├─ _safeTransferIn(token1, amount1)
├─ token0.forceApprove(pmAddr, amount0)
├─ token1.forceApprove(pmAddr, amount1)
│
├─ lpMinted = pm.addLiquidity(poolId, amount0, amount1, msg.sender)
│ │
│ └─ POOLMANAGER.addLiquidity
│ ├─ onlyRouter check
│ ├─ pool.active check
│ ├─ if first deposit:
│ │ ├─ overflow check amount0 * amount1
│ │ ├─ root = sqrt(amount0 * amount1)
│ │ ├─ lpMinted = root - MINIMUM_LIQUIDITY
│ │ └─ totalLPSupply = root (include MIN lock)
│ ├─ else:
│ │ ├─ ProportionalMath.proportionalEnough(amount0, r0, amount1, r1)
│ │ ├─ if !proportional → revert [tolleranza 1 bps]
│ │ ├─ lpMinted = min(lp0, lp1)
│ ├─ update reserves + totalSupply
│ ├─ lpBalances[poolId][onBehalfOf] += lpMinted
│ └─ _safeTransferIn(token0/1)
│
├─ token0/1.forceApprove(pmAddr, 0)
└─ emit LiquidityAdded(...)

text

---

## 4. Flusso RemoveLiquidity
UTENTE
│ removeLiquidity(poolId, lpAmount, recipient)
▼
ROUTER
├─ lpAmount > 0, recipient != 0
├─ pmAddr = provider.poolManager()
├─ (amount0, amount1) = pm.removeLiquidity(poolId, lpAmount, msg.sender, recipient)
│ │
│ └─ POOLMANAGER.removeLiquidity
│ ├─ onlyRouter check
│ ├─ lpAmount <= lpBalances[poolId][owner]
│ ├─ feeShare = lpAmount * feeAccrued / totalSupply
│ ├─ resShare = lpAmount * reserve / totalSupply
│ ├─ amount = feeShare + resShare
│ ├─ update feeAccrued, reserves, lpBalances, totalSupply
│ └─ token0/1.safeTransfer(recipient, amount)
│
└─ emit LiquidityRemoved(...)

text

---

## 5. Perché SLEAddressProvider

Il `PoolManager` richiede `router` immutable e il `T2TRouter` richiede `poolManager` immutable. Deployarli direttamente crea un **ciclo di dipendenza irrisolvibile**:
RouterAddr = keccak(RouterBytecode(PMAddr))
PMAddr = keccak(PMBytecode(RouterAddr))

text

CREATE2 non aiuta: iterare gli hash non converge. Il provider risolve il ciclo:
Deploy SLEAddressProvider (senza dipendenze)

Deploy PoolManager(registry, provider) — provider già noto

Deploy T2TRouter(provider, selector, registry) — provider già noto

provider.setEndpoints(router, pm) — one-shot, atomico

text

Sia `PoolManager` che `T2TRouter` leggono l'altro address **dinamicamente** dal provider. Il provider è `immutable` nei due contratti, ma gli endpoint sono configurabili **una sola volta** e mai modificabili.

---

## 6. Separazione moduli

| Modulo | Responsabilità | NON può fare |
|---|---|---|
| **Provider** | Traccia router+pm, config one-shot | Cambiare endpoint dopo set |
| **Registry** | Whitelist curve, registra/attiva pool | Modificare curve dopo activate |
| **Detector** | Calcola regime, isteresi | Bloccare swap direttamente |
| **Selector** | Fee, blocked, fail-open/closed matrix | Trasferire token |
| **Strategie** | Proponi fee, decidi block | Modificare stato |
| **PoolManager** | Contabilità, invarianti | Conoscere strategie o regimi |
| **Router** | Entry point, transferFrom, allowance | Custodire LP o fondi |
| **Curve** | Matematica swap | Trasferire token, scrivere stato |

Ogni modulo ha **una sola responsabilità** e **non può fare** ciò che spetta ad altri. Questo è il principio che rende SLE auditabile.

---

*Documento vivo. Ogni modifica all'architettura richiede aggiornamento di questo file.*
