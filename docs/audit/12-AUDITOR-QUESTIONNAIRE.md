# Auditor Questionnaire — SLE v1

> **Destinatari**: auditor
> **Scopo**: 30 domande tipiche che un auditor si pone, con risposta già pronta

---

## Access Control

### Q1. Chi può chiamare `PoolManager.swap`?
**R**: Solo il `T2TRouter`. Il modifier `onlyRouter` verifica `msg.sender == provider.router()`. Se diverso → revert `UnauthorizedCaller`.

### Q2. `provider.router()` può essere cambiato dopo il deploy?
**R**: No. `SLEAddressProvider.setEndpoints` è one-shot (flag `_configured`). Dopo la prima chiamata, ogni successiva → revert `AlreadyConfigured`.

### Q3. Chi può chiamare `setStrategy` sul Selector?
**R**: Solo l'owner (deployer in v1, Timelock in v2). Modifier `onlyOwner`.

### Q4. Un utente può prelevare le LP di un altro?
**R**: No. `T2TRouter.removeLiquidity` passa `msg.sender` come `owner` al PoolManager. Il PM verifica `lpBalances[poolId][msg.sender] >= lpAmount`. Non c'è modo di specificare un owner diverso.

### Q5. Cosa succede se il provider non è configurato?
**R**: `provider.router()` restituisce `address(0)`. `onlyRouter` rifiuta ogni chiamata. Il Router reverte con `ProviderNotConfigured`.

---

## Accounting

### Q6. Come si garantisce che `token.balanceOf(pm) == reserve + feeAccrued`?
**R**: Invariante INV-2, verificata dopo ogni operazione in `PoolManagerInvariant.t.sol`. 128.000 chiamate, 0 violazioni.

### Q7. Cosa succede se `amountOut > maxOut`?
**R**: Revert `CurveOutputExceedsBound`. È la safety net che impedisce a una curva buggata di drenare il pool.

### Q8. Come funziona l'arrotondamento nel prelievo?
**R**: `removeLiquidity` calcola separatamente `feeShare` e `resShare` con `Math.mulDiv` (floor), poi li somma. La somma è esattamente ciò che viene sottratto dai conti. Testato con `testFuzz_roundingWithdrawalExact`.

### Q9. `MINIMUM_LIQUIDITY` è riscattabile?
**R**: No. Al primo deposito, `lpMinted = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY`, e `totalLPSupply = sqrt(...)`. La differenza (MINIMUM_LIQUIDITY) non è attribuita a nessun utente. INV-5 verifica che `Σ lpBalances <= totalLPSupply - MINIMUM_LIQUIDITY`.

### Q10. Cosa succede se `amount0 * amount1` va in overflow?
**R**: Check preventivo: `if (amount1 > type(uint256).max / amount0) revert InsufficientLiquidity`. Nessun overflow possibile.

---

## Matematica 512-bit

### Q11. `ProportionalMath.proportionalEnough` è testata per input grandi?
**R**: Sì, 20 test isolati in `ProportionalMath.t.sol`, inclusi:
- Prodotti > 2^256 (limb alto non nullo)
- Valori vicini a `type(uint256).max`
- Differenze con limb alto significativo

### Q12. Come si calcola `floor(max / 10000)` per valori a 512-bit?
**R**: Divisione bit-by-bit: si processano i 256 bit del limb basso uno alla volta, mantenendo il resto. Il quoziente è costruito bit per bit. Testato con `testFuzz_toleranceBoundary` (256 run, 0-1% diff).

### Q13. Cosa succede se `diff * 10000 > max`?
**R**: `proportionalEnough` restituisce `false`. Il chiamante (`PoolManager.addLiquidity`) reverte con `InsufficientLiquidity`.

---

## Fail-closed

### Q14. Se il detector è stale, cosa succede?
**R**: `getMarketState` restituisce `isValid = false`. Il Selector restituisce `(0, true)` → il Router reverte con `BlockedByStrategy`.

### Q15. Se la strategia reverte in CRITICAL, cosa succede?
**R**: Il Selector cattura il revert e restituisce `(0, true)` → swap bloccato. **Non c'è fallback** in CRITICAL.

### Q16. Se la strategia reverte in CALM, cosa succede?
**R**: Il Selector cattura il revert e restituisce `(DEFAULT_FEE=30, false)` → swap procede con fee 30 bps.

### Q17. Cosa succede se una strategia non è registrata?
**R**: 
- In CRITICAL: `strategies[CRITICAL] == address(0)` → `(0, true)` → block
- In CALM/VOLATILE: `strategies[regime] == address(0)` → `(DEFAULT_FEE=30, false)` → swap procede

---

## Token non standard

### Q18. Cosa succede con token fee-on-transfer?
**R**: `_safeTransferIn` verifica `balanceAfter - balanceBefore == amount`. Se diverso → revert `FeeOnTransferNotSupported`.

### Q19. Cosa succede con token USDT-like (forceApprove)?
**R**: Il Router usa `SafeERC20.forceApprove` (gestisce il caso) + reset a 0 dopo ogni operazione.

### Q20. Cosa succede se `transferFrom` ritorna true ma non trasferisce?
**R**: Stesso check di fee-on-transfer → revert.

---

## Reentrancy

### Q21. Il Router è protetto da reentrancy?
**R**: Sì. `nonReentrant` su `swap`, `addLiquidity`, `removeLiquidity`. Testato con `ReentrantToken` in `test_swap_reentrancyBlocked`.

### Q22. CEI pattern è rispettato?
**R**: Sì. In `PoolManager.swap`, reserves e fee sono aggiornate **prima** dei trasferimenti. `_safeTransferIn` e `safeTransfer` vengono dopo.

---

## MEV

### Q23. Come si mitiga il front-running?
**R**: Parzialmente. `VolatileStrategy` fee 0.5% rende i sandwich meno profittevoli. **Non li elimina**. La soluzione completa (ordine FIFO) è in roadmap v2.

### Q24. Cosa protegge dallo slippage?
**R**: `minAmountOut` obbligatorio. Se `amountOut < minAmountOut` → revert `SlippageExceeded`.

### Q25. Cosa protegge da tx in mempool troppo a lungo?
**R**: `deadline` param. Se `block.timestamp > deadline` → revert `DeadlineExpired`.

---

## Governance

### Q26. Cosa può fare l'owner in v1?
**R**: 
- Cambiare parametri del detector (range-checked)
- Aggiungere/rimuovere strategie
- Aggiungere/rimuovere curve dalla whitelist
- Registrare nuovi pool

**Non può**: cambiare endpoint del provider (one-shot), modificare PoolManager/Router/strategie (immutabili).

### Q27. C'è un timelock in v1?
**R**: No. Owner singolo (deployer). **Dichiarato come limitazione** in `07-KNOWN-LIMITATIONS.md`. Roadmap v2.

### Q28. Cosa succede se l'owner è compromesso?
**R**: L'attaccante può cambiare parametri e strategie. **Non può** rubare fondi (i fondi sono nel PM, protetti da `onlyRouter`). La finestra di rischio è limitata alle modifiche amministrative.

---

## Deploy

### Q29. Il deploy è riproducibile?
**R**: Sì. `script/DeploySLE.s.sol` + `deploy-sle.sh`. Dry-run disponibile. Verifica incrociata automatica post-deploy.

### Q30. Cosa succede se un check di verifica fallisce?
**R**: Il deploy è considerato **non valido**. Bisogna investigare e rideployare. Non c'è rollback automatico, ma i contratti sono immutabili e possono essere "abbandonati" deployandone di nuovi.

---

## Domande aperte per l'auditor

1. C'è un modo per bypassare `onlyRouter`?
2. La `ProportionalMath` è corretta per tutti gli input?
3. Il fail-closed è veramente fail-closed in tutti gli scenari?
4. Ci sono race condition nel deploy (provider one-shot)?
5. I 165 test coprono tutti i path critici?
6. C'è un modo per un utente di perdere fondi senza volerlo?
7. Il Router può essere "dirottato" per inviare token a un attacker?
8. La `removeLiquidity` può essere chiamata per un owner diverso da msg.sender?
9. Cosa succede in caso di self-destruct di un token?
10. Ci sono problemi di gas griefing?

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
