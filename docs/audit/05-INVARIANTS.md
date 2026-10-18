# Invariants — SLE v1

> **Destinatari**: auditor
> **Scopo**: definire formalmente le invarianti del sistema e come sono testate

---

## 1. Cosa sono le invarianti

Un'**invariante** è una proprietà che deve essere **sempre vera**, indipendentemente dalla sequenza di operazioni eseguite. Se un'invariante è violata, c'è un bug.

In SLE, le invarianti sono verificate con **Foundry invariant testing**: il framework esegue sequenze casuali di `swap`, `addLiquidity`, `removeLiquidity` e dopo ogni operazione verifica che le invarianti restino vere.

**Configurazione**: 256 run × 500 chiamate = **128.000 operazioni random** per invariante.

---

## 2. Invarianti implementate

### INV-1: LP supply coherent

**Formula**:
```
totalLPSupply == MINIMUM_LIQUIDITY + Σ lpBalances[poolId][user]

```

**Cosa significa**: la somma delle LP possedute dagli utenti, più la liquidità minima bloccata al primo deposito, deve sempre essere uguale al totale emesso.

**Perché è importante**: se `totalLPSupply` fosse maggiore della somma delle LP utente + MIN, ci sarebbero LP "fantasma" non riscattabili. Se fosse minore, alcuni utenti potrebbero riscattare più del dovuto.

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV1_lpSupplyCoherent`

**Come**: dopo ogni operazione, il test legge `pm.getTotalLPSupply(poolId)` e `pm.getLPBalance(poolId, user)` per ogni attore, e verifica l'uguaglianza.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

---

### INV-2: Token balance matches accounting

**Formula**:
```
token.balanceOf(poolManager) == reserve0 + feeAccrued0 (per token0)
token.balanceOf(poolManager) == reserve1 + feeAccrued1 (per token1)

```

**Cosa significa**: il saldo reale dei token nel PoolManager deve essere esattamente uguale alla somma di riserve contabili e fee accumulate per quel token.

**Perché è importante**: se `balance > reserve + feeAccrued`, ci sono token "persi" nel contratto (donazione o bug). Se `balance < reserve + feeAccrued`, il contratto è insolvente (bug critico: non può onorare i prelievi).

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV2_tokenBalanceMatchesAccounting`

**Come**: dopo ogni operazione, il test legge `token.balanceOf(pm)` e confronta con `reserve + feeAccrued` per entrambi i token.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

**Nota su multi-pool**: in v1 il test usa un solo pool. Se in futuro ci saranno pool multipli, l'invariante va estesa a `token.balanceOf(pm) == Σ_pool (reserve_pool + feeAccrued_pool)`.

---

### INV-3: k never decreases after swap

**Formula**:
```
k_after = reserve0_after * reserve1_after
k_before = reserve0_before * reserve1_before
k_after >= k_before (dopo ogni swap)

```

**Cosa significa**: dopo uno swap, il prodotto delle riserve non può diminuire. Le fee fanno **aumentare** k (a favore dei LP), mai diminuire.

**Perché è importante**: questa è l'invariante fondamentale del constant product. Se k diminuisse dopo uno swap, qualcuno starebbe estraendo valore dal pool senza pagare il prezzo giusto.

**Dove è verificata**: 
- `test/sle/ConstantProductCurve.t.sol::testFuzz_kNeverDecreases`
- `test/sle/PoolManager.t.sol::testFuzz_swap_kNeverDecreases`
- `test/sle/PoolManagerInvariant.t.sol::invariant_INV3_kNeverDecreasesAfterSwap`

**Come**: prima di ogni swap, il handler cattura `k_before`. Dopo lo swap, verifica `k_after >= k_before`. Se violata, setta `ghost_kViolation = true`.

**Stato**: ✅ PASS (42.884 swap, 0 violazioni)

**Nota**: l'invariante NON si applica ad `addLiquidity` o `removeLiquidity`, che cambiano k **fisiologicamente** (aggiungono o rimuovono liquidità). Solo gli swap sono soggetti a questa invariante.

---

### INV-4: MAX_FEE constant

**Formula**:
```
poolManager.MAX_FEE() == 200

```

**Cosa significa**: la fee massima applicabile è 200 basis point (2%), e non può essere cambiata.

**Perché è importante**: se `MAX_FEE` potesse cambiare, il core potrebbe applicare fee arbitrarie. Essendo hard-coded, questa protezione è assoluta.

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV4_feeCapConstant`

**Come**: chiama `pm.MAX_FEE()` e verifica che sia 200.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

---

### INV-5: MINIMUM_LIQUIDITY locked

**Formula**:
```
Σ lpBalances[poolId][user] <= totalLPSupply - MINIMUM_LIQUIDITY

```

**Cosa significa**: la somma delle LP possedute dagli utenti non può mai superare il totale meno la liquidità minima bloccata.

**Perché è importante**: garantisce che le LP minime siano permanentemente bloccate e non riscattabili. Questo previene l'attacco "donazione infinita" (dove l'ultimo LP potrebbe manipolare il prezzo).

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV5_minLiquidityLocked`

**Come**: dopo ogni operazione, il test verifica che `Σ lpBalances[user] <= totalLPSupply - MINIMUM_LIQUIDITY`.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

---

### INV-7: Router holds no tokens

**Formula**:
```
token0.balanceOf(router) == 0
token1.balanceOf(router) == 0

```

**Cosa significa**: dopo ogni operazione, il Router non deve trattenere token degli utenti. I token vengono trasferiti al PoolManager, non rimangono nel Router.

**Perché è importante**: se il Router trattenesse token, questi sarebbero potenzialmente recuperabili da un attaccante o bloccati. È un bug classico dei router (fondi bloccati).

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV7_routerHoldsNoTokens`

**Come**: dopo ogni operazione, il test verifica che `token0.balanceOf(router) == 0` e `token1.balanceOf(router) == 0`.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

---

### INV-8: Allowance always zero

**Formula**:
```
token0.allowance(router, poolManager) == 0
token1.allowance(router, poolManager) == 0

```

**Cosa significa**: dopo ogni operazione, l'allowance del Router verso il PoolManager deve essere 0.

**Perché è importante**: se l'allowance rimanesse attiva, un attaccante che controlla il PoolManager (o un bug in un'altra operazione) potrebbe usare i token del Router. Il reset a 0 è una difesa in profondità.

**Dove è verificata**: `test/sle/PoolManagerInvariant.t.sol::invariant_INV8_allowanceAlwaysZero`

**Come**: dopo ogni operazione, il test verifica che le allowance siano 0.

**Stato**: ✅ PASS (128.000 chiamate, 0 violazioni)

---

## 3. Invarianti pianificate per v2

| ID | Invariante | Motivo rinvio |
|---|---|---|
| INV-6 | `k_after >= k_before` con fee-on-transfer | Token non supportati in v1 |
| INV-9 | Concentrated liquidity invariants | Feature v2 |
| INV-10 | MEV ordering (FIFO) | Feature v2 |

---

## 4. Copertura degli invarianti

| Categoria | Invarianti | Copertura |
|---|---|---|
| Accounting | INV-1, INV-2, INV-3, INV-5 | ✅ Completa |
| Fee | INV-4 | ✅ Completa |
| Router safety | INV-7, INV-8 | ✅ Completa |
| Concentrated | INV-9, INV-10 | ❌ v2 |

---

## 5. Come replicare

```bash
# Esegui solo invariant test
forge test --match-path "test/sle/PoolManagerInvariant.t.sol" -vv

# Con più run (default 256, max 1000)
FOUNDRY_INVARIANT_RUNS=1000 forge test --match-path "test/sle/PoolManagerInvariant.t.sol"
Output atteso:

```
[PASS] invariant_INV1_lpSupplyCoherent
[PASS] invariant_INV2_tokenBalanceMatchesAccounting
[PASS] invariant_INV3_kNeverDecreasesAfterSwap
[PASS] invariant_INV4_feeCapConstant
[PASS] invariant_INV5_minLiquidityLocked
[PASS] invariant_INV7_routerHoldsNoTokens
[PASS] invariant_INV8_allowanceAlwaysZero
PoolManagerInvariantTest invariants (runs: 256, calls: 128000, reverts: 0)
Documento vivo. Ultimo aggiornamento: 2026-10-18.
