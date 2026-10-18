# T2T Smart Liquidity Engine (SLE) — Design Specification v1

> **Stato**: DRAFT — da revisionare prima dell'implementazione
> **Versione**: 1.0
> **Data**: 2026-10-18
> **Autori**: T2T Core Team
> **Licenza prevista**: MIT (soggetta a verifica legale)
> **Provenienza codice**: originale, non derivato da Uniswap v4 / Balancer v2

---

## 1. Executive Summary

Il T2T Smart Liquidity Engine (SLE) è un motore di liquidità per il DEX nativo di Two-Trader (T2T) che seleziona dinamicamente la strategia di trading in base allo stato del mercato, anziché applicare regole fisse a ogni swap.

La v1 è deliberatamente conservativa:
- AMM constant product (x·y=k), semplice e auditabile
- Strategie deterministiche on-chain (nessuna AI in v1)
- Core immutabile, versioni successive deployate separatamente
- Fee limitate dal core, strategie possono solo ridurre, mai aumentare
- Regime CRITICAL sospende/limita swap, non solo alza fee

Le evoluzioni (concentrated liquidity, sentinelle AI come proponenti) sono v2+, non dipendenze della prima release.

---

## 2. Obiettivi e non-obiettivi

### 2.1 Obiettivi v1

| ID | Obiettivo | Metrica di successo |
|---|---|---|
| O1 | AMM constant product corretto e verificabile | Invarianti verdi su fuzz (>= 10.000 run) |
| O2 | Separazione netta AMM core / SLE | SLE non può creare saldi né aggirare core |
| O3 | Strategie modulari e sostituibili | Aggiungere strategia = deploy + register, zero modifiche al core |
| O4 | Fee dinamiche con tetto hard-coded | fee <= MAX_FEE sempre, testato |
| O5 | CRITICAL blocca, non solo penalizza | Swap sospesi in regime CRITICAL |
| O6 | Governance con timelock | Ogni modifica parametri passa da timelock 2 giorni |
| O7 | Gas benchmark misurabile | Report gas per swap / add / remove |

### 2.2 Non-obiettivi v1

- Liquidità concentrata (v2)
- Sentinelle AI come decisori (v2)
- Cross-chain / bridge integrato nell'SLE
- Governance on-chain completa (v1: timelock + multisig)
- Upgradability del core (immutabile, migrazione esplicita)

---

## 3. Architettura

### 3.1 Separazione dei livelli

| Livello | Responsabilità | NON può fare |
|---|---|---|
| AMM Core | Contabilità token, invarianti matematici, trasferimenti | Non conosce strategie, non conosce regimi |
| SLE | Osserva mercato, seleziona strategia, applica fee/limiti | Non crea saldi, non modifica riserve, non aggira fee cap |
| Strategie | Propongono fee e limiti per regime | Non modificano stato del pool, non trasferiscono token |

Regola d'oro: se una strategia va in errore, il core deve continuare a funzionare (fallback deterministico).

Eccezione di sicurezza: il fallback non deve trasformare un errore del detector o della strategia in un'autorizzazione implicita durante CRITICAL, dati obsoleti o stato non verificabile. In tali condizioni il comportamento deve essere fail-closed per gli swap interessati (vedi §7.3). Il fallback DEFAULT_FEE è ammesso solo quando lo stato di rischio è valido e non critico.

---

## 4. AMM Core

### 4.1 Modello matematico

Constant product: x · y = k

- x = riserva token0 (dopo fee)
- y = riserva token1 (dopo fee)
- k = costante di invariante

Formula di swap (esatta):

  feeAmount = ceil(dx * feeBps / 10_000)
  dx_after_fee = dx - feeAmount
  dy = (y * dx_after_fee) / (x + dx_after_fee)

Arrotondamento: sempre verso il basso (a favore del pool).

### 4.2 Invarianti formalizzati

Storage del pool:

  uint256 reserve0;
  uint256 reserve1;
  uint256 feeAccrued0;
  uint256 feeAccrued1;
  uint256 lastUpdatedBlock;

Definizione: k(reserve0, reserve1) = reserve0 * reserve1

Le fee sono accantonate in feeAccrued0/1 e NON entrano in k dal momento in cui vengono contabilizzate.

Flusso esatto di uno swap token0 -> token1:

1. feeAmount = ceil(amountIn * feeBps / 10_000)
2. amountAfterFee = amountIn - feeAmount
3. feeAccrued0 += feeAmount
4. reserve0 += amountAfterFee
5. reserve1 -= amountOut (calcolato su riserve precedenti e input netto)
6. Verifica: reserve0 * reserve1 >= k_before

| ID | Invariante | Test |
|---|---|---|
| INV-1 | k_after >= k_before (su reserve nette) | Fuzz su swap, add, remove |
| INV-2 | Non-negatività riserve | Sempre |
| INV-3 | LP supply == somma LP shares | Dopo ogni op |
| INV-4 | fee_bps <= MAX_FEE (200) | Sempre |
| INV-5 | feeAccrued == somma fee trasferite | Dopo ogni swap |
| INV-6 | MINIMUM_LIQUIDITY minted ad address(0) al primo add | Primo add |

### 4.3 Fee model

fee_bps in [0, MAX_FEE]
MAX_FEE = 200 (2%)

feeAmount = ceil(amountIn * fee_bps / 10_000)
amountAfterFee = amountIn - feeAmount

Enforced in PoolManager.swap(), non nella strategia.

### 4.4 Interfacce Solidity concettuali

interface IPoolManager {
    function swap(PoolId id, bool zeroForOne, uint256 amountIn, uint256 minAmountOut, address recipient, uint256 deadline, bytes calldata hookData) external returns (uint256 amountOut);
    function addLiquidity(PoolId id, uint256 amount0, uint256 amount1) external returns (uint256 lpMinted);
    function removeLiquidity(PoolId id, uint256 lpAmount) external returns (uint256 amount0, uint256 amount1);
}

interface ICurve {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256);
}

interface IRegimeDetector {
    function getMarketState(PoolId id) external view returns (MarketState memory);
}

interface IStrategySelector {
    function selectStrategy(PoolId id, MarketState memory state) external view returns (address strategy);
}

interface IStrategy {
    function proposeFee(PoolId id, MarketState memory state) external view returns (uint16 feeBps);
    function shouldBlock(PoolId id, uint256 amountIn, MarketState memory state) external view returns (bool);
    function name() external pure returns (string memory);
}

---

## 5. Curve Registry

### 5.1 Regola

Una curva, una volta associata a un pool, non è modificabile.

- PoolRegistry.registerPool(id, curveAddress) — una sola volta
- PoolRegistry.getCurve(id) — read-only
- PoolRegistry.activatePool(id) — una sola volta, congela l'associazione
- Cambio curva = nuovo pool + migrazione esplicita (v2)

### 5.2 Motivazione

Cambiare curva a un pool attivo significa cambiare prezzi, obblighi economici e diritti degli LP. L'immutabilità dopo activatePool() è una garanzia per gli LP.

### 5.3 Whitelist e safety net

Solo curve whitelisted possono essere associate a un pool.

  require(poolRegistry.isWhitelistedCurve(curve), "curve not whitelisted");

  uint256 feeAmount = FullMath.mulDivRoundingUp(amountIn, feeBps, 10_000);
  uint256 amountAfterFee = amountIn - feeAmount;

  uint256 maxOut = FullMath.mulDiv(reserveOut, amountAfterFee, reserveIn + amountAfterFee);
  uint256 amountOut = ICurve(curve).getAmountOut(amountAfterFee, reserveIn, reserveOut);

  require(amountOut <= maxOut, "curve output exceeds bound");

Il bound usa l'input netto (amountAfterFee), non l'input lordo. Altrimenti una curva potrebbe restituire più output di quanto consentito dal constant-product applicato all'input effettivamente scambiato, facendo diminuire k.

Test obbligatori: test_curveNotWhitelistedReverts, test_curveOutputExceedingBoundReverts, test_whitelistedCurveCannotExceedConstantProductBound.

---

## 6. Regime Detector

### 6.1 Segnali multipli

| Segnale | Fonte | Peso |
|---|---|---|
| TWAP (1h, 6h, 24h) | On-chain | 40% |
| Volatilità realizzata | Ultimi N swap | 30% |
| Volume / liquidità | Ratio volume24h / liquidity | 20% |
| Spread bid-ask | Swap recenti | 10% |

Nessun singolo segnale può determinare CRITICAL. Serve concordanza di almeno 2 su 4.

### 6.2 Macchina a stati con isteresi

CALM -> VOLATILE: volatilità > 2% per 10 min
VOLATILE -> CALM: volatilità < 1% per 30 min
VOLATILE -> TRENDING_UP/DOWN: TWAP differenza > 3%
VOLATILE -> CRITICAL: dump > 10% in 1h E volume > 3x media
CRITICAL -> VOLATILE: 1h senza trigger E sentinelle OK

### 6.3 Parametri (aggiornabili solo via timelock)

| Parametro | Default | Range |
|---|---|---|
| twapWindow1h | 3600s | [600, 86400] |
| volatilityThresholdLow | 100 bps | [10, 500] |
| volatilityThresholdHigh | 200 bps | [50, 1000] |
| criticalDumpThreshold | 1000 bps | [500, 3000] |
| criticalVolumeMultiplier | 3x | [2, 10] |
| detectorStalenessBlocks | 100 | [10, 1000] |

### 6.4 Validità dello stato

Il detector aggiorna lastUpdatedBlock solo quando produce uno stato valido.

  stale = (block.number - lastUpdatedBlock) > detectorStalenessBlocks

Se stale == true, lo stato è non valido -> policy fail-closed (§7.3).

---

## 7. Strategy Selector

### 7.1 Regole deterministiche v1

if state.regime == CRITICAL:   -> CriticalStrategy
elif state.regime == VOLATILE:  -> VolatileStrategy
elif state.regime == CALM:      -> CalmStrategy
else (TRENDING_*):              -> VolatileStrategy (default)

### 7.2 Sentinelle (v2)

Le sentinelle proporranno una strategia tramite Decision 3/5. Il Selector la verificherà e la applicherà solo se valida. Fallback deterministico sempre attivo.

### 7.3 Matrice fail-open / fail-closed

| Stato detector | Strategia | Comportamento |
|---|---|---|
| Valido + non CRITICAL | OK | Applica fee strategia (entro MAX_FEE) |
| Valido + non CRITICAL | KO | DEFAULT_FEE = 30 bps (fail-open) |
| Valido + CRITICAL | OK | CriticalStrategy (blocca swap > 1% liquidità) |
| Valido + CRITICAL | KO | Blocca tutti gli swap (fail-closed) |
| Non valido (stale) | qualsiasi | Blocca tutti gli swap (fail-closed) |
| Non valido (revert) | qualsiasi | Blocca tutti gli swap (fail-closed) |

Test obbligatori:
- test_failOpenWhenStrategyRevertsInCalm
- test_failClosedWhenStrategyRevertsInCritical
- test_failClosedWhenDetectorStale
- test_failClosedWhenDetectorReverts
- test_strategyCannotExceedMaxFeeEvenIfWhitelisted

---

## 8. Strategie v1

| Strategia | Regime | Fee | Blocca? |
|---|---|---|---|
| CalmStrategy | CALM | 5 bps | No |
| VolatileStrategy | VOLATILE, TRENDING_* | 50 bps | No |
| CriticalStrategy | CRITICAL | 150 bps | Sì (swap > reserveIn/100) |

CriticalStrategy.shouldBlock() blocca swap con amountIn > (reserveIn / 100), permette swap piccoli, emette CriticalSwapBlocked.

---

## 9. Governance

| Cosa | Chi | Timelock |
|---|---|---|
| Parametri RegimeDetector | DAO (multisig + timelock) | 2 giorni |
| Aggiunta strategia | DAO | 2 giorni |
| Fee per strategia | DAO | 2 giorni |
| Whitelist curve | DAO | 2 giorni |
| Pausa d'emergenza | Multisig sentinelle | Nessuno (max 24h) |
| Cambio core | Nessuno (immutabile) | — |

La multisig sentinelle può mettere in pausa un pool per max 24h, emettere EmergencyAlert. Non può prelevare fondi, cambiare fee, aggiungere strategie, durare più di 24h senza voto DAO.

---

## 10. Threat Model

### 10.1 Oracle manipulation
- TWAP manipolato -> TWAP su 1h/6h/24h + volume filter
- Flash loan attack -> CRITICAL richiede volume > 3x media
- Singolo swap -> CRITICAL -> concordanza 2/4 segnali

### 10.2 MEV / sandwich
- Front-running -> non risolto in v1 (v2: ordine per arrivo)
- Sandwich -> VolatileStrategy fee 0.5% (da dimostrare con simulazioni)
- Slippage manipulation -> minAmountOut obbligatorio

### 10.3 Reentrancy
- nonReentrant + checks-effects-interactions
- onlyPoolManager + nonReentrant su hook

### 10.4 Governance attack
- Timelock 2 giorni + veto sentinelle
- MAX_FEE hard-coded (2%)
- Curva immutabile dopo activatePool()
- Safety net bound constant-product

### 10.5 DoS
- CRITICAL permanente -> auto-transizione dopo 1h + governance override
- Strategia che reverte -> DEFAULT_FEE o fail-closed
- Pool con liquidità 0 -> MINIMUM_LIQUIDITY
- Detector obsoleto -> fail-closed

### 10.6 Replay (v2)
- Nonce + deadline + chainId

---

## 11. Criteri di accettazione per fase

| Fase | Criterio |
|---|---|
| 0 — Design | Questo documento approvato |
| 1 — AMM Core | Fuzz 10.000 run, INV-1..6 verdi, gas < 100k per swap |
| 2 — SLE v1 | RegimeDetector con isteresi, Selector deterministico, 3 strategie, fallback e fail-closed testati |
| 3 — Sicurezza | Fuzz, invariant, simulazione oracle, benchmark gas |
| 4 — Governance | Timelock funzionante, pausa emergenza testata, ruoli separati |
| 5 — Testnet | Deploy su 332, 30 giorni monitoraggio, audit esterno |

---

## 12. Roadmap

| Fase | Deliverable | Gate di uscita |
|---|---|---|
| 0 — Design | Specifica approvata | Nessuna ambiguità critica |
| 1 — AMM Core | Pool, swap, liquidità, accounting, test | Fuzz e invariant superati |
| 2 — SLE v1 | Detector, registry, selector, 3 strategie | Fallback e transizioni testati |
| 3 — Sicurezza | Test avversariali, benchmark | Nessun finding critico/alto |
| 4 — Governance | Timelock, ruoli, pausa | Test privilegi superati |
| 5 — Testnet | Deploy su 332 | 30 giorni osservazione |

---

## 13. ADR — Architecture Decision Records

### ADR-001: Constant product per v1
Decisione: x·y=k in v1
Contesto: AMM originale, no v4, audit rapido
Criterio per v2: TVL > $10M e slippage medio > 1%

### ADR-002: Core immutabile, no Diamond in v1
Decisione: core immutabile, versioni separate
Contesto: Diamond aumenta superficie d'attacco
Criterio per v3: > 3 upgrade/anno

### ADR-003: Governance timelock + multisig
Decisione: timelock 2 giorni + multisig sentinelle
Criterio per v2: > 1.000 holder attivi votano

### ADR-004: Sentinelle proponenti, non decisori (v2)
Decisione: sentinelle propongono, contratto verifica
Criterio: AI con track record > 95% su 6 mesi

### ADR-005: Fee cap nel core
Decisione: MAX_FEE = 200 bps hard-coded in PoolManager.swap()
Criterio: immutabile in v1

### ADR-006: Safety net constant-product per curve whitelisted
Decisione: maxOut = reserveOut * amountAfterFee / (reserveIn + amountAfterFee)
Criterio: vale per v1; concentrated richiederà bound specifici

### ADR-007: Fail-closed in CRITICAL / detector obsoleto
Decisione: DEFAULT_FEE solo se stato valido e non critico; altrimenti blocca
Criterio: immutabile in v1

---

## 14. Licenza e provenienza

- Codice: originale, scritto da zero dal team T2T
- Licenza prevista: MIT
- Verifica legale: obbligatoria prima del deploy mainnet
- Dipendenza da Uniswap v4: nessuna nel codice SLE e AMM v1
- Dipendenza da Balancer: nessuna
- Librerie: OpenZeppelin (MIT), forge-std (MIT)

---

## 15. Benchmark (da misurare)

| Metrica | Target v1 | Come misurarla |
|---|---|---|
| Gas per swap | < 100k | forge test --gas-report |
| Gas per addLiquidity | < 150k | Idem |
| Gas per beforeSwap SLE | < 30k | Idem |
| Latenza RegimeDetector | < 5k gas | Idem |
| Precisione regime | > 80% match | Backtest |

Target sperimentali, non garanzie.

---

## 16. Note di progettazione da chiudere

1. Curve plug-in e invarianti: il core verifica settlement e invariante specifico della curva
2. k e fee: riserve non includono fee trattenute. Test su formula Solidity
3. CRITICAL e liquidità: soglia reserveIn / 100
4. Segnali on-chain: richiedono osservazioni persistenti
5. MEV: fee 0.5% non garantisce non-profittabilità sandwich
6. Target gas: obiettivi sperimentali

---

## 17. Prossimi passi

1. Review di questo documento
2. Approvazione formale
3. Implementazione Fase 1 (AMM Core)
4. Test Fase 1
5. Implementazione Fase 2 (SLE v1)

---
