# Threat Model — SLE v1

> **Destinatari**: auditor
> **Scopo**: enumerare le minacce note, il vettore d'attacco, la mitigazione implementata, e il test che la verifica

---

## Legenda

| Sigla | Significato |
|---|---|
| **T** | Threat |
| **V** | Vettore d'attacco |
| **M** | Mitigazione |
| **S** | Stato (✅ implementata, ⚠️ parziale, ❌ assente) |
| **Test** | Test che verifica la mitigazione |

---

## Categoria 1: Access Control

### T1.1 — Chiamata diretta al PoolManager
- **V**: Utente chiama `pm.swap/addLiquidity/removeLiquidity` senza passare dal Router
- **M**: `onlyRouter` legge `provider.router()`. Se `msg.sender != router` → revert `UnauthorizedCaller`
- **S**: ✅
- **Test**: `test_swap_directCallReverts`, `test_addLiquidity_directCallReverts`, `test_removeLiquidity_directCallReverts`

### T1.2 — Sostituzione del Router
- **V**: Owner del provider chiama `setEndpoints` due volte per cambiare il Router
- **M**: Provider ha flag `_configured` one-shot. Secondo `setEndpoints` → revert `AlreadyConfigured`
- **S**: ✅
- **Test**: `test_setEndpoints_oneShot`, `test_setEndpoints_oneShotSameValues`

### T1.3 — Registrazione pool da non-owner
- **V**: Utente chiama `registry.registerPool` per registrare pool falso
- **M**: `registerPool` ha `onlyOwner`. Registry owner = deployer/timelock
- **S**: ✅
- **Test**: `test_registerPool_onlyOwner`

### T1.4 — Strategia non autorizzata
- **V**: Utente chiama `selector.setStrategy` per registrare strategia falsa
- **M**: `setStrategy` ha `onlyOwner`. Selector owner = deployer/timelock
- **S**: ✅
- **Test**: `test_setStrategy_onlyOwner`

---

## Categoria 2: Accounting e Invarianti

### T2.1 — k diminuisce dopo swap
- **V**: Curva o fee mal calcolate fanno scendere `reserve0 * reserve1`
- **M**: `maxOut` bound + safety net. Curva è whitelisted. Se `amountOut > maxOut` → revert
- **S**: ✅
- **Test**: `testFuzz_swap_kNeverDecreases`, `test_swap_maliciousCurve_reverts`, `invariant_INV3`

### T2.2 — Fee accumulate non corrispondono ai trasferimenti
- **V**: Fee contabilizzate ma non effettivamente ricevute dal PM
- **M**: `_safeTransferIn` verifica balance delta. Fee = `ceil(amountIn * feeBps / 10000)` sempre accreditata
- **S**: ✅
- **Test**: `test_swap_feeAccrued`, `invariant_INV2`

### T2.3 — LP supply incoerente
- **V**: `totalLPSupply` ≠ `MINIMUM_LIQUIDITY + Σ lpBalances`
- **M**: Ogni add/remove aggiorna entrambi in modo atomico
- **S**: ✅
- **Test**: `invariant_INV1`, `invariant_INV5`

### T2.4 — MINIMUM_LIQUIDITY riscattabile
- **V**: Utente prova a prelevare le LP bloccate al primo deposito
- **M**: `lpBalances[poolId][deployer]` non include MIN. `removeLiquidity` verifica `lpAmount <= lpBalances[msg.sender]`
- **S**: ✅
- **Test**: `test_addLiquidity_firstDeposit_locksMinimum`, `invariant_INV5`

### T2.5 — Arrotondamento prelievo
- **V**: `feeShare + resShare` sommati in ordine diverso causano underflow
- **M**: Calcolo separato con `Math.mulDiv`, somma = sottrazione esatta
- **S**: ✅
- **Test**: `testFuzz_roundingWithdrawalExact`

### T2.6 — Overflow in `amount0 * amount1` (primo deposito)
- **V**: Primo deposito con amount enormi causa overflow silenzioso
- **M**: `if (amount1 > type(uint256).max / amount0) revert InsufficientLiquidity`
- **S**: ✅
- **Test**: Coperto da fuzz `testFuzz_lpSupplyCoherent`

### T2.7 — Overflow in `reserveIn + amountAfterFee`
- **V**: `reserveIn + amountAfterFee` supera `uint256.max`
- **M**: `if (amountAfterFee > type(uint256).max - reserveIn) revert`
- **S**: ✅
- **Test**: Coperto da `test_swap_*`

---

## Categoria 3: Matematica 512-bit

### T3.1 — `proportionalEnough` accetta differenze > 1 bps
- **V**: Input con prodotti > 2^128 causano overflow in check naive
- **M**: Cross-multiply 512-bit + divisione bit-by-bit `floor(max/10000)`
- **S**: ✅
- **Test**: 20 test `ProportionalMath.t.sol` (inclusi overflow e max values)

### T3.2 — Limb alto ignorato
- **V**: Se `maxH > 0` ma `diff` reale > 1 bps, vecchia implementazione accettava
- **M**: Confronto completo `rHigh/rMid/rLow` vs `maxH/maxL`, no scorciatoie
- **S**: ✅
- **Test**: `test_maxValues_diffOnBothLimb`, `test_highLimbDiff`

### T3.3 — Divisione bit-by-bit errata
- **V**: Carry non propagato causano quoziente sbagliato
- **M**: `rem * 2 + bit`, `if (rem >= 10000) { rem -= 10000; qLow |= 1 << i; }`
- **S**: ✅
- **Test**: `testFuzz_toleranceBoundary` (256 run, 0-1% diff)

---

## Categoria 4: Fail-closed

### T4.1 — Detector stale
- **V**: Detector non aggiornato da >100 blocchi, regime non valido
- **M**: `getMarketState` → `isValid = false` se `block.number - lastUpdatedBlock > 100`. Selector → `(0, true)` → block
- **S**: ✅
- **Test**: `test_detectorStale_blocksSwap`, `test_stale_becomesInvalid`

### T4.2 — Detector revert
- **V**: `getMarketState` reverte (bug o gas)
- **M**: `try/catch` nel Selector → `(0, true)` → block
- **S**: ✅
- **Test**: `test_detectorReverts_failClosed`

### T4.3 — Strategia revert in CRITICAL
- **V**: `CriticalStrategy.proposeFee` reverte durante regime critico
- **M**: `try/catch` in CRITICAL → `(0, true)` → block (no fallback)
- **S**: ✅
- **Test**: `test_criticalRevertingStrategy_failClosed`

### T4.4 — Strategia revert in CALM
- **V**: `CalmStrategy.proposeFee` reverte in regime calmo
- **M**: `try/catch` in CALM → `(DEFAULT_FEE=30, false)` → swap procede
- **S**: ✅
- **Test**: `test_calmStrategyReverts_usesDefaultFee`

### T4.5 — Nessuna strategia registrata per CRITICAL
- **V**: Owner dimentica di registrare `CriticalStrategy`
- **M**: `strategies[CRITICAL] == address(0)` → `(0, true)` → block
- **S**: ✅
- **Test**: `test_criticalNoStrategy_blocksSwap`

---

## Categoria 5: Token non standard

### T5.1 — Fee-on-transfer
- **V**: Token trattiene fee sul transfer, PM riceve meno di `amount`
- **M**: `_safeTransferIn` verifica `balanceAfter - balanceBefore == amount`. Se no → revert `FeeOnTransferNotSupported`
- **S**: ✅
- **Test**: `test_addLiquidity_feeOnTransferReverts`, `test_swap_reentrancyBlocked`

### T5.2 — USDT-like (forceApprove)
- **V**: Token richiede `approve(0)` prima di nuovo `approve`
- **M**: Router usa `SafeERC20.forceApprove` + reset a 0 dopo operazione
- **S**: ✅
- **Test**: `test_swap_allowanceReset`, `test_addLiquidity_allowanceReset`, `invariant_INV8`

### T5.3 — Token che non trasferisce nulla
- **V**: `transferFrom` ritorna true ma non trasferisce
- **M**: Stesso check di fee-on-transfer → revert
- **S**: ✅
- **Test**: `test_addLiquidity_feeOnTransferReverts`

---

## Categoria 6: Reentrancy

### T6.1 — Reentrancy su swap
- **V**: Token chiama `router.swap` durante `transferFrom`
- **M**: `nonReentrant` su Router. Callback → revert
- **S**: ✅
- **Test**: `test_swap_reentrancyBlocked` (ReentrantToken)

### T6.2 — Reentrancy su addLiquidity
- **V**: Token chiama `router.addLiquidity` durante transfer
- **M**: `nonReentrant` su Router
- **S**: ✅
- **Test**: `test_swap_reentrancyBlocked` (indiretto)

### T6.3 — CEI violation
- **V**: Transfer prima di aggiornare stato
- **M**: `PoolManager.swap` aggiorna reserves/fee PRIMA di `safeTransfer`. Router fa transfer dopo
- **S**: ✅
- **Test**: Ispezione codice (`_safeTransferIn` dopo state update in swap)

---

## Categoria 7: MEV / Front-running

### T7.1 — Sandwich attack
- **V**: Attaccante mette swap prima/dopo quello della vittima
- **M**: ⚠️ `VolatileStrategy` fee 0.5% rende **meno profittevole** ma non impossibile
- **S**: ⚠️ Parziale
- **Test**: **Nessuno** (mitigazione economica, non tecnica)
- **Nota**: Soluzione completa (ordine FIFO) in roadmap v2

### T7.2 — Slippage manipulation
- **V**: Attaccante manipola prezzo spot con swap
- **M**: `minAmountOut` obbligatorio (utente imposta)
- **S**: ✅
- **Test**: `test_swap_slippageExceeded`

### T7.3 — Deadline expired
- **V**: Tx rimane in mempool, eseguita dopo deadline
- **M**: `deadline` param + check `block.timestamp <= deadline`
- **S**: ✅
- **Test**: `test_swap_deadlineExpired`, `test_deadlineExpired`

---

## Categoria 8: Governance / Admin

### T8.1 — Provider compromesso
- **V**: Owner del provider chiama `setEndpoints` con address malevoli
- **M**: One-shot. Dopo deploy, provider owner = admin (multisig/timelock futuro). Deploy non modificabile
- **S**: ✅ (one-shot) / ⚠️ (owner singolo in v1)
- **Test**: `test_setEndpoints_oneShot`
- **Nota**: v2 → Timelock

### T8.2 — Registry compromesso
- **V**: Owner registra pool con curva malevola
- **M**: `whitelistCurve` + `registerPool` solo owner. Whitelist review manuale
- **S**: ✅ (design)
- **Test**: `test_whitelistCurve_onlyOwner`, `test_registerPool_requiresWhitelistedCurve`

### T8.3 — Detector params malevoli
- **V**: Owner setta `volatilityThresholdHigh` a 0 → sempre CRITICAL
- **M**: `setParameters` ha range check (`_volLow < _volHigh`, `_critDump > _volHigh`)
- **S**: ⚠️ Parziale (range check, ma no timelock in v1)
- **Test**: `test_setParameters_invalidRangeReverts`
- **Nota**: v2 → Timelock

---

## Categoria 9: DoS

### T9.1 — CRITICAL permanente
- **V**: Detector bloccato in CRITICAL da trigger continui
- **M**: Isteresi `criticalExitStreak = 10`. Auto-transizione dopo 10 osservazioni
- **S**: ✅
- **Test**: `test_volatile_to_calm_afterLongStreak`

### T9.2 — Pool con liquidità 0
- **V**: Swap su pool mai inizializzato
- **M**: `if (reserveIn == 0 \|\| reserveOut == 0) revert InsufficientLiquidity`
- **S**: ✅
- **Test**: `test_swap_*` (indiretto)

### T9.3 — Loop infinito in `_proportionalEnough`
- **V**: Divisione bit-by-bit con carry mal gestito
- **M**: `for (uint256 i = 256; i > 0; )` con `--i` in `unchecked`, sempre termina
- **S**: ✅
- **Test**: `testFuzz_neverReverts`

---

## Categoria 10: Integer

### T10.1 — Underflow `block.number - lastUpdatedBlock`
- **V**: `block.number < lastUpdatedBlock` (impossibile in pratica)
- **M**: Monotonia di `block.number`
- **S**: ✅ (implicito)
- **Test**: Fuzz su RegimeDetector

### T10.2 — Overflow `amount0 * amount1`
- **V**: Vedi T2.6
- **M**: Check esplicito
- **S**: ✅

### T10.3 — Overflow `reserveIn + amountAfterFee`
- **V**: Vedi T2.7
- **M**: Check esplicito
- **S**: ✅

---

## Riepilogo

| Categoria | Threat | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|
| Access control | 4 | 4 | 0 | 0 |
| Accounting | 7 | 7 | 0 | 0 |
| Matematica | 3 | 3 | 0 | 0 |
| Fail-closed | 5 | 5 | 0 | 0 |
| Token non standard | 3 | 3 | 0 | 0 |
| Reentrancy | 3 | 3 | 0 | 0 |
| MEV | 3 | 2 | 1 | 0 |
| Governance | 3 | 2 | 1 | 0 |
| DoS | 3 | 3 | 0 | 0 |
| Integer | 3 | 3 | 0 | 0 |
| **Totale** | **37** | **35** | **2** | **0** |

**2 minacce parzialmente mitigate**, entrambe **dichiarate** e con roadmap v2 (MEV, governance/timelock).

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
