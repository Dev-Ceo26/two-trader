# Glossary — SLE v1

> **Destinatari**: auditor, nuovo team member
> **Scopo**: terminologia del progetto

---

## A

**AMM** — Automated Market Maker. Protocollo che fornisce liquidità in modo algoritmico, senza order book.

**Audit** — Revisione indipendente del codice per identificare vulnerabilità.

## B

**bps** — Basis point. 1 bps = 0.01%. 100 bps = 1%. Usato per fee e tolleranze.

## C

**CalmStrategy** — Strategia per regime CALM. Fee 5 bps, nessun blocco.

**Constant product** — Formula AMM `x · y = k`. Usata in SLE v1.

**CRITICAL** — Regime di mercato con dump > 10% e volume anomalo. Blocca swap grandi.

**CriticalStrategy** — Strategia per regime CRITICAL. Fee 150 bps + blocca swap > 1% liquidità.

## D

**DEFAULT_FEE** — Fee di fallback (30 bps) usata se la strategia reverte in regime non-critico.

**Detector** — Vedi RegimeDetector.

## E

**E2E** — End-to-end. Test che copre l'intero flusso utente.

**Emergency** — Procedura per incidenti di sicurezza (vedi 10-EMERGENCY-PROCEDURES).

## F

**Fail-closed** — Comportamento sicuro: se qualcosa va storto, blocca. Usato in CRITICAL.

**Fail-open** — Comportamento permissivo: se qualcosa va storto, procedi con default. Usato in CALM/VOLATILE.

**Fee-on-transfer** — Token che trattiene una fee al transfer. SLE v1 li rifiuta.

**Fee cap** — `MAX_FEE = 200 bps` hard-coded. Nessuna fee può superarlo.

## I

**Invariante** — Proprietà sempre vera. Violazione = bug.

**INV-1** — `totalLPSupply == MINIMUM_LIQUIDITY + Σ lpBalances`

**INV-2** — `token.balanceOf(pm) == reserve + feeAccrued`

**INV-3** — `k_after >= k_before` dopo swap

**INV-4** — `MAX_FEE == 200` costante

**INV-5** — `Σ lpBalances <= totalLPSupply - MINIMUM_LIQUIDITY`

**INV-7** — Router non trattiene token

**INV-8** — Allowance Router→PM sempre 0

## K

**k** — Prodotto delle riserve `reserve0 * reserve1`. Deve crescere o restare uguale dopo swap.

## L

**LP** — Liquidity Provider. Chi fornisce liquidità al pool.

**lpBalances** — Mappatura `poolId → user → LP shares`.

**lpMinted** — LP coniate per un deposito.

**lpBurned** — LP bruciate per un prelievo.

## M

**MAX_FEE** — 200 bps (2%). Tetto massimo di fee applicabile.

**MINIMUM_LIQUIDITY** — 1000 (unità minime). Bloccata al primo deposito, mai riscattabile.

**MEV** — Maximal Extractable Value. Estrazione di valore tramite front-running, sandwich, ecc.

## O

**onlyRouter** — Modifier su PoolManager. Solo il Router può chiamare swap/add/remove.

**Owner** — Chi può chiamare funzioni amministrative (setStrategy, setParameters, ecc.).

## P

**PoolManager** — Core AMM. Contabilità, invarianti, safety net.

**PoolRegistry** — Registro dei pool. Whitelist curve, freeze associazioni.

**ProportionalMath** — Libreria per verifica proporzionalità LP (cross-multiply 512-bit).

**Provider** — SLEAddressProvider. Risolve il ciclo Router↔PM.

## R

**Regime** — Stato di mercato: CALM (0), VOLATILE (1), CRITICAL (4).

**RegimeDetector** — Contratto che calcola il regime. Isteresi, staleness, fail-closed.

**Router** — T2TRouter. Unico entry point autorizzato.

## S

**Safety net** — Bound `maxOut` in PoolManager. Impedisce a una curva buggata di drenare il pool.

**Selector** — StrategySelector. Sceglie fee e blocked in base al regime.

**SLE** — Smart Liquidity Engine. Il motore di liquidità di T2T.

**Stale** — Detector non aggiornato da > 100 blocchi. `isValid = false`.

**Strategia** — Contratto che propone fee e block. Ce ne sono 3: Calm, Volatile, Critical.

## T

**T2T** — Two-Trader. Il progetto.

**T2TRouter** — Il Router ufficiale di SLE.

**Timelock** — Meccanismo che ritarda l'esecuzione di una transazione (non in v1, roadmap v2).

**TWAP** — Time-Weighted Average Price. Prezzo medio pesato nel tempo.

## U

**Uniswap v4** — DEX di riferimento. SLE è **originale**, non fork di v4.

## V

**VolatileStrategy** — Strategia per regime VOLATILE. Fee 50 bps.

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
