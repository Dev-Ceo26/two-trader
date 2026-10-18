# Access Control — SLE v1

> **Destinatari**: auditor
> **Scopo**: matrice completa dei ruoli e delle autorizzazioni per ogni contratto

---

## 1. Principi

1. **Minimo privilegio**: ogni contratto ha solo i permessi necessari
2. **Separazione ruoli**: chi decide (owner) ≠ chi esegue (router)
3. **One-shot dove possibile**: provider configurato una volta, mai più
4. **Nessun setter sul core**: PoolManager non ha funzioni di modifica
5. **Fail-closed su accesso non autorizzato**: revert, non fallback silenzioso

---

## 2. Matrice ruoli per contratto

### SLEAddressProvider

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `setEndpoints(router, pm)` | owner | One-shot (1 volta sola) |
| `router()` | chiunque | view |
| `poolManager()` | chiunque | view |
| `isConfigured()` | chiunque | view |
| `transferOwnership(newOwner)` | owner | standard |

**Protezione**: `_configured` flag. Secondo `setEndpoints` → revert `AlreadyConfigured`.

### PoolRegistry

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `whitelistCurve(curve, bool)` | owner | amministrativa |
| `registerPool(id, curve, t0, t1)` | owner | amministrativa |
| `activatePool(id)` | owner | irreversibile |
| `getCurve(id)` | chiunque | view |
| `getPool(id)` | chiunque | view |
| `isActive(id)` | chiunque | view |
| `isWhitelistedCurve(curve)` | chiunque | view |

**Protezione**: `onlyOwner` su whitelist/register/activate. Curva congelata dopo `registerPool`.

### RegimeDetector

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `update(poolId, r0, r1, vol)` | chiunque | keeper (no auth) |
| `getMarketState(poolId)` | chiunque | view |
| `setParameters(...)` | owner | amministrativa |
| `transferOwnership(newOwner)` | owner | standard |

**Nota**: `update` è permissionless (chiunque può aggiornare le osservazioni). Questo è deliberato: i keeper possono aggiornare, ma non possono falsificare lo stato (i dati sono passati come parametri e validati on-chain).

**Range check** in `setParameters`: `_volLow < _volHigh`, `_critDump > _volHigh`, `_critVolMult > 0`, `_staleness > 0`.

### StrategySelector

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `setStrategy(regime, strategy)` | owner | amministrativa |
| `unregisterStrategy(regime)` | owner | amministrativa |
| `selectForSwap(...)` | chiunque (view) | view |
| `transferOwnership(newOwner)` | owner | standard |

**Protezione**: `onlyOwner` su setStrategy/unregister. Regimi ammessi: 0 (CALM), 1 (VOLATILE), 4 (CRITICAL). Altri → revert `InvalidRegime`.

### PoolManager

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `swap(...)` | **solo Router** | core |
| `addLiquidity(...)` | **solo Router** | core |
| `removeLiquidity(...)` | **solo Router** | core |
| `getReserves`, `getFeesAccrued`, `getLPBalance`, `getTotalLPSupply` | chiunque | view |
| `MAX_FEE()`, `router()`, `providerAddress()` | chiunque | view |
| `poolStates(id)` | chiunque | view |

**Protezione**: `modifier onlyRouter` su swap/add/remove. `onlyRouter` legge `provider.router()` ad ogni chiamata.

**Nessun setter**: PoolManager non ha funzioni amministrative (no owner, no upgrade, no pause). Il contratto è immutabile nel comportamento.

### T2TRouter

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `swap(...)` | chiunque | entry point |
| `addLiquidity(...)` | chiunque | entry point |
| `removeLiquidity(poolId, lpAmount, recipient)` | **solo owner delle LP** | entry point |
| `provider()`, `selector()`, `registry()` | chiunque | view |

**Protezione per removeLiquidity**: il Router passa `msg.sender` come `owner` al PoolManager. Il PM verifica `lpBalances[poolId][owner] >= lpAmount`. Un utente non può prelevare le LP di un altro.

**Reentrancy**: `nonReentrant` su swap, addLiquidity, removeLiquidity.

### Strategie (CalmStrategy, VolatileStrategy, CriticalStrategy)

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `proposeFee(...)` | chiunque (view) | view |
| `shouldBlock(...)` | chiunque (view) | view |
| `name()`, `targetRegime()` | chiunque | view |

**Nessuna funzione di stato**: le strategie sono **pure/view**. Non possono modificare nulla, non hanno owner.

**Nota su CriticalStrategy**: `shouldBlock` è l'unica funzione che può **negare** uno swap (se `amountIn > reserveIn/100`). Ma non ha effetti collaterali: è view.

### ConstantProductCurve

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `getAmountOut(...)` | chiunque (pure) | pure |
| `getAmountIn(...)` | chiunque (pure) | pure |
| `name()` | chiunque (pure) | pure |

**Nessuna funzione di stato, nessun owner**: la curva è pura matematica.

### ProportionalMath (libreria)

| Funzione | Chi può chiamare | Tipo |
|---|---|---|
| `proportionalEnough(...)` | chiunque (internal) | pure |

**Libreria internal**: non deployabile come contratto separato, chiamata inline dal PoolManager.

---

## 3. Ruoli chiave: chi è "owner"?

In v1, tutti i contratti hanno `owner = deployer` (EOA). In v2, l'owner sarà:

| Contratto | Owner v1 | Owner v2 (target) |
|---|---|---|
| SLEAddressProvider | deployer | Timelock |
| PoolRegistry | deployer | Timelock |
| RegimeDetector | deployer | Timelock |
| StrategySelector | deployer | Timelock |

**Rischio in v1**: owner singolo può:
- Cambiare parametri del detector
- Aggiungere/rimuovere strategie
- Aggiungere/rimuovere curve dalla whitelist
- Registrare nuovi pool

**Non può**:
- Cambiare gli endpoint del provider (one-shot)
- Modificare il PoolManager (immutabile)
- Modificare il Router (immutabile)
- Modificare le strategie (immutabili)

---

## 4. Flusso autorizzativo: swap
UTENTE
│ approve(Router)
│ swap(...)
▼
ROUTER
├─ no auth (chiunque può chiamare)
├─ transferFrom(user → router)
├─ forceApprove(pm)
│
├─ pm.swap(...) ← msg.sender = router
│ │
│ └─ POOLMANAGER
│ ├─ onlyRouter: msg.sender == provider.router() ✅
│ └─ esegue swap
│
├─ reset allowance
└─ fine

text

**Punti di controllo**:
1. Router: nessuna auth (chiunque può chiamare)
2. PM `onlyRouter`: verifica `msg.sender == provider.router()`
3. Utente: deve approvare il Router per `amountIn`

---

## 5. Flusso autorizzativo: removeLiquidity
UTENTE
│ removeLiquidity(poolId, lpAmount, recipient)
▼
ROUTER
├─ no auth (chiunque può chiamare)
├─ pm.removeLiquidity(poolId, lpAmount, owner=msg.sender, recipient)
│ │
│ └─ POOLMANAGER
│ ├─ onlyRouter: msg.sender == router ✅
│ ├─ lpAmount <= lpBalances[poolId][owner] ← verifica proprietario
│ └─ trasferisci token a recipient
│
└─ fine

text

**Punti di controllo**:
1. Router: passa `owner = msg.sender` (chi chiama è il proprietario)
2. PM: verifica `lpBalances[poolId][owner] >= lpAmount`
3. **Non c'è modo** per un utente di prelevare le LP di un altro: il Router forza `owner = msg.sender`

---

## 6. Cosa NON può fare nessuno

Anche con accesso root al deployer:

| Azione | Perché è impossibile |
|---|---|
| Cambiare `MAX_FEE` | Hard-coded 200 nel PM |
| Cambiare l'Router del PM | PM legge da provider (one-shot) |
| Aggiungere funzioni al PM | PM è immutabile |
| Modificare la curva dopo activate | Registry congela |
| Modificare una strategia | Strategie sono immutabili |
| Prelevare fondi dal PM senza LP | `removeLiquidity` richiede LP |
| Chiamare `pm.swap` direttamente | `onlyRouter` blocca |

---

## 7. Matrice riassuntiva

| Contratto | Owner | Modificabile | One-shot | Immutabile |
|---|---|---|---|---|
| SLEAddressProvider | deployer | solo `setEndpoints` | ✅ | endpoints |
| PoolRegistry | deployer | whitelist, register | parziale | curve fisse |
| RegimeDetector | deployer | solo `setParameters` | — | logica |
| StrategySelector | deployer | `setStrategy` | — | logica |
| PoolManager | nessuno | nulla | — | tutto |
| T2TRouter | nessuno | nulla | — | tutto |
| CalmStrategy | nessuno | nulla | — | tutto |
| VolatileStrategy | nessuno | nulla | — | tutto |
| CriticalStrategy | nessuno | nulla | — | tutto |
| ConstantProductCurve | nessuno | nulla | — | tutto |
| ProportionalMath | — | — | — | libreria |

---

## 8. Test di access control

| Test | Cosa verifica |
|---|---|
| `test_swap_directCallReverts` | PM rifiuta chiamata diretta |
| `test_addLiquidity_directCallReverts` | Idem |
| `test_removeLiquidity_directCallReverts` | Idem |
| `test_constructor_zeroProviderReverts` | PM richiede provider != 0 |
| `test_swap_providerNotConfiguredReverts` | PM rifiuta se provider non configurato |
| `test_setEndpoints_onlyOwner` | Provider: solo owner può setEndpoints |
| `test_setEndpoints_oneShot` | Provider: no doppia chiamata |
| `test_registerPool_onlyOwner` | Registry: solo owner |
| `test_activatePool_onlyOwner` | Registry: solo owner |
| `test_setStrategy_onlyOwner` | Selector: solo owner |
| `test_removeLiquidity_ownerOnly` | Router: non puoi prelevare LP altrui |
| `test_routerIsOnlyCaller` | PM: solo Router |
| `invariant_INV7_routerHoldsNoTokens` | Router non trattiene token |
| `invariant_INV8_allowanceAlwaysZero` | Allowance reset |

---

## 9. Cosa controllare durante l'audit

1. **`onlyRouter` bypassabile?** Ispezionare `PoolManager.onlyRouter` e `provider.router()`.
2. **`setEndpoints` chiamabile due volte?** Ispezionare `SLEAddressProvider.setEndpoints`.
3. **`removeLiquidity` può prelevare LP altrui?** Ispezionare il flusso Router→PM.
4. **Owner può fare qualcosa di inaspettato?** Controllare tutte le funzioni `onlyOwner`.
5. **Nessuna funzione nascosta?** Cercare `fallback`, `receive`, `delegatecall`.
6. **Nessun `selfdestruct`?** Verificare assenza.
7. **Nessun `tx.origin`?** Verificare assenza (usare `msg.sender`).
8. **`transferOwnership` a zero address?** Verificare check.

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
