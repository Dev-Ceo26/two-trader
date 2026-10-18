# Test Coverage — SLE v1

## 1. Riepilogo

| Metrica | Valore |
|---|---|
| Test unitari | 161 |
| Invarianti | 7 (× 128.000 chiamate) |
| Fuzz test | ~15 |
| Test 512-bit | 20 |
| Coverage stimata core | ~95% |
| Coverage stimata strategie | ~85% |

## 2. Test per contratto

| Contratto | File test | Test | Fuzz | Invarianti |
|---|---|---|---|---|
| ProportionalMath | ProportionalMath.t.sol | 20 | 4 | — |
| ConstantProductCurve | ConstantProductCurve.t.sol | 9 | 2 | — |
| PoolRegistry | PoolRegistry.t.sol | 14 | 0 | — |
| PoolManager | PoolManager.t.sol | 29 | 3 | — |
| PoolManager (inv) | PoolManagerInvariant.t.sol | 0 | 0 | 7 |
| StrategySelector | StrategySelector.t.sol | 17 | 1 | — |
| RegimeDetector | RegimeDetector.t.sol | 13 | 1 | — |
| SLEAddressProvider | SLEAddressProvider.t.sol | 7 | 0 | — |
| T2TRouter | T2TRouter.t.sol | 18 | 1 | — |
| Strategies (3) | Strategies.t.sol | 17 | 2 | — |
| E2E FailClosed | EndToEndFailClosed.t.sol | 17 | 1 | — |
| E2E FullFlow | E2EFullFlow.t.sol | 4 | 1 | — |
| **Totale** | | **165** | **16** | **7** |

## 3. Copertura per area funzionale

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

## 4. Test critici (i più importanti)

### Access control
- `test_swap_directCallReverts`
- `test_addLiquidity_directCallReverts`
- `test_removeLiquidity_directCallReverts`
- `test_constructor_zeroProviderReverts`
- `test_swap_providerNotConfiguredReverts`

### Accounting
- `testFuzz_swap_kNeverDecreases`
- `testFuzz_roundingWithdrawalExact`
- `testFuzz_lpSupplyCoherent`
- `invariant_INV1..INV8`

### Matematica
- `test_bothProductOverflow512_equal`
- `test_maxValues_diffOnBothLimb`
- `testFuzz_toleranceBoundary`
- `testFuzz_neverReverts`

### Fail-closed
- `test_detectorStale_blocksSwap`
- `test_detectorRevert_blocksSwap`
- `test_criticalStrategyReverts_blocksSwap`
- `test_calmStrategyReverts_usesDefaultFee`

### Token non standard
- `test_addLiquidity_feeOnTransferReverts`
- `test_swap_reentrancyBlocked`
- `test_swap_allowanceReset`

### E2E
- `test_fullFlow_addSwapVerify`
- `test_fullFlow_removeLiquidity`
- `testFuzz_swapConservesValue`

## 5. Test fuzz: configurazione

Tutti i fuzz test usano 256 run di default (Foundry standard). Ogni run genera input casuali entro bound definiti.

Esempio:
```solidity
function testFuzz_swap_kNeverDecreases(uint256 amountIn, uint256 feeBps) public {
    amountIn = bound(amountIn, 1e6, 10_000e18);
    feeBps = bound(feeBps, 0, 200);
    // ...
}
6. Test invarianti: configurazione
256 run × 500 chiamate = 128.000 operazioni per invariante.

Handler: PoolHandler.sol espone 3 azioni random:

addLiquidity(amount0, amount1) — bounded proporzionale

removeLiquidity(lpFrac) — frazione 1-100%

swap(amountIn, zeroForOne) — bounded

Attori: 3 (alice, bob, carol), scelti random per ogni chiamata.

7. Gap di copertura noti
Area	Gap	Priorità
Reentrancy	Solo swap testato, add/remove no	ALTA
Multi-pool	Solo 1 pool nei test invariant	MEDIA
USDT-like reali	MockFeeToken copre, USDT vero no	MEDIA
Gas benchmark	Non automatizzato	BASSA
Concentrated liquidity	Non implementato (v2)	—
8. Come replicare
bash
# Tutti i test
forge test

# Solo SLE
forge test --match-path "test/sle/*"

# Solo invarianti
forge test --match-path "test/sle/PoolManagerInvariant.t.sol" -vv

# Con più run (più lento ma più copertura)
FOUNDRY_INVARIANT_RUNS=1000 forge test --match-path "test/sle/PoolManagerInvariant.t.sol"
Documento vivo. Ultimo aggiornamento: 2026-10-18.
