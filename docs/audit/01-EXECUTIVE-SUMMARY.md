# Executive Summary — SLE v1

> **Destinatari**: auditor esterni, partner, investitori
> **Tempo di lettura**: 5 minuti

---

## Cos'è SLE

Il **Smart Liquidity Engine (SLE)** è il motore di liquidità originale di Two-Trader (T2T). A differenza dei DEX tradizionali, SLE **seleziona dinamicamente la strategia di trading** in base allo stato del mercato, invece di applicare regole fisse a ogni swap.

SLE è **scritto da zero**, non è un fork di Uniswap v4 né di Balancer. Zero dipendenze da codice BUSL.

## Cosa fa

1. **Rileva il regime di mercato** (CALM, VOLATILE, CRITICAL) tramite 4 segnali pesati
2. **Seleziona la strategia** (Calm 5 bps, Volatile 50 bps, Critical 150 bps + block)
3. **Applica fee e limiti** in base al regime
4. **Blocca swap pericolosi** in CRITICAL (swap > 1% della liquidità)
5. **Fail-closed**: se il detector è invalido/stale, blocca tutto

## Architettura in 7 contratti

| Contratto | Ruolo | LOC |
|---|---|---|
| `SLEAddressProvider` | Risolve il ciclo di dipendenza PM↔Router | ~60 |
| `PoolRegistry` | Whitelist curve, freeze associazioni | ~100 |
| `ConstantProductCurve` | AMM x·y=k | ~60 |
| `RegimeDetector` | Regime + isteresi + staleness | ~180 |
| `StrategySelector` | Fee decision + fail-closed matrix | ~130 |
| `PoolManager` | Contabilità, invarianti, safety net | ~250 |
| `T2TRouter` | Entry point, transferFrom, allowance | ~130 |
| + 3 strategie, 1 libreria | Calm, Volatile, Critical, ProportionalMath | ~200 |
| **Totale** | | **~1.300** |

## 3 punti di forza

### 1. Fail-closed by design
Se il detector è stale o la strategia reverte in regime CRITICAL, **lo swap viene bloccato**. Non c'è fallback silenzioso che possa mascherare un attacco.

### 2. Matematica 512-bit testata
La funzione `_proportionalEnough` (proporzionalità LP) usa cross-multiply 512-bit con 20 test isolati (overflow, max values, boundary 1 bps). Zero arrotondamenti nascosti.

### 3. Provider one-shot irreversibile
Il `SLEAddressProvider` associa Router e PoolManager una sola volta, in modo atomico. Nessun setter sul PM o sul Router, nessuna possibilità di swap del Router dopo il deploy.

## 3 aree di rischio (trasparenti)

### 1. Nessun audit esterno precedente
Questo è il **primo audit**. 161 test verdi non sostituiscono una revisione umana indipendente. Siamo consapevoli che un bug non catturato dai test possa esistere.

### 2. Front-running / MEV non mitigati
La `VolatileStrategy` con fee 0.5% rende i sandwich **meno profittevoli**, ma non li elimina. La soluzione completa (ordine FIFO) è in roadmap v2.

### 3. Concentrated liquidity non supportata
Il core v1 è constant product puro. La liquidità concentrata (efficiente ma complessa) è in roadmap v2. La `TrendStrategy` v1 non può spostare liquidità, solo fee.

## Numeri chiave

| Metrica | Valore |
|---|---|
| Test totali | **161** |
| Invarianti formali | **7** (× 128.000 chiamate) |
| Coverage | ~95% core, ~85% strategie |
| Gas medio per swap | ~140k |
| Dipendenze esterne | OpenZeppelin (MIT), forge-std (MIT) |
| Dipendenze da Uniswap v4 / Balancer | **zero** |

## Roadmap

| Fase | Stato |
|---|---|
| v1 (constant product, strategie deterministiche) | ✅ Completo |
| **Audit esterno** | ⏳ **Questo pacchetto** |
| v2 (concentrated liquidity, sentinelle AI) | 📋 Pianificato |
| Mainnet | ⏳ Dopo audit + v2 |

## Contatti

- **Email**: team@two-trader.com
- **Security**: security@two-trader.com
- **GitHub**: https://github.com/Dev-Ceo26/two-trader

---

*"More than a platform. A trading ecosystem."*
