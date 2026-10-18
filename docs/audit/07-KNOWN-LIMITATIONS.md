# Known Limitations — SLE v1

> **Destinatari**: auditor
> **Scopo**: dichiarare esplicitamente cosa SLE v1 NON fa, cosa è parzialmente mitigato, e cosa arriverà in v2

---

## 1. Limitazioni funzionali

### 1.1 Liquidità concentrata non supportata
- **Cosa manca**: posizioni LP con range di prezzo (tick)
- **Cosa c'è**: constant product puro (x·y=k)
- **Impatto**: inefficienza del capitale rispetto a Uniswap v3/v4
- **Roadmap**: v2 (concentrated liquidity)
- **Mitigazione**: l'architettura a curve plug-in permette di aggiungere una `ConcentratedCurve` senza modificare il core

### 1.2 TrendStrategy non sposta liquidità
- **Cosa manca**: la strategia "trend" non può aggiungere/rimuovere liquidità in base al trend
- **Cosa c'è**: solo fee dinamiche (0.5% in VOLATILE/TRENDING)
- **Motivo**: senza concentrated liquidity, non c'è modo di spostare liquidità in modo efficiente
- **Roadmap**: v2 (con concentrated liquidity)

### 1.3 Sentinelle AI non implementate
- **Cosa manca**: le sentinelle (AI/quantum) non possono proporre strategie o override
- **Cosa c'è**: strategie deterministiche basate su segnali on-chain
- **Motivo**: l'AI off-chain non è affidabile al 100%, e va introdotta solo con track record verificato
- **Roadmap**: v2

### 1.4 TWAP semplificato
- **Cosa manca**: TWAP su finestre lunghe (24h, 7d) con osservazioni persistenti
- **Cosa c'è**: volatilità calcolata tra osservazioni consecutive (finestra breve)
- **Motivo**: richiede storage persistente e keeper affidabile, non in v1
- **Roadmap**: v2

---

## 2. Limitazioni di sicurezza

### 2.1 Front-running / MEV non mitigati
- **Cosa manca**: ordine FIFO, commit-reveal, o meccanismi anti-MEV
- **Cosa c'è**: `VolatileStrategy` con fee 0.5% (mitigazione economica)
- **Impatto**: sandwich attack possibili, ma meno profittevoli
- **Roadmap**: v2
- **Nota**: la fee 0.5% **non garantisce** che un sandwich sia non profittevole. Va testato con simulazioni.

### 2.2 Nessun timelock in v1
- **Cosa manca**: timelock per modifiche a Detector/Selector/Registry
- **Cosa c'è**: owner singolo (deployer) per modifiche amministrative
- **Impatto**: l'owner può cambiare parametri senza delay
- **Roadmap**: v2 (Timelock + multisig)
- **Nota**: questa è una centralizzazione dichiarata in v1

### 2.3 Provider owner singolo
- **Cosa manca**: multisig o timelock per `setEndpoints`
- **Cosa c'è**: owner singolo, ma one-shot (setEndpoints chiamabile una volta)
- **Impatto**: la finestra di rischio è solo al deploy
- **Roadmap**: v2 (multisig)

### 2.4 Audit esterno: questo è il primo
- **Cosa manca**: audit precedenti
- **Cosa c'è**: 165 test, 7 invarianti × 128.000 chiamate
- **Impatto**: 165 test non sostituiscono la revisione umana
- **Roadmap**: questo pacchetto

---

## 3. Limitazioni tecniche

### 3.1 Token non standard
- **Supportati**: ERC20 standard, USDT-like (forceApprove)
- **Rifiutati con revert**: fee-on-transfer, rebasing, token con callback
- **Motivo**: `_safeTransferIn` verifica balance delta
- **Impatto**: alcuni token non possono essere usati in SLE v1
- **Roadmap**: valutare supporto esplicito per fee-on-transfer in v2

### 3.2 Pool singolo per test invariant
- **Cosa manca**: test invarianti con più pool che condividono token
- **Cosa c'è**: 1 pool per test
- **Impatto**: l'invariante INV-2 (token balance) non copre il caso multi-pool
- **Roadmap**: estendere `PoolHandler` a 2+ pool

### 3.3 Reentrancy test parziale
- **Coperto**: swap con ReentrantToken
- **Non coperto**: add/remove liquidity reentrancy
- **Motivo**: il pattern `nonReentrant` è lo stesso su tutte le funzioni, un test copre tutti
- **Roadmap**: aggiungere test espliciti per add/remove

### 3.4 Gas benchmark non automatizzato
- **Cosa manca**: report gas per operazione in CI
- **Cosa c'è**: stime manuali (~140k per swap)
- **Roadmap**: `forge snapshot` in CI

---

## 4. Limitazioni di design

### 4.1 No upgradeability del core
- **Scelta deliberata**: core immutabile
- **Motivo**: auditabilità, no backdoor, no rischio upgrade malevolo
- **Impatto**: fix richiede deploy nuovo + migrazione esplicita
- **Roadmap**: v2 potrebbe introdurre Diamond (EIP-2535) se necessario

### 4.2 No flash loan
- **Cosa manca**: flash loan nativo
- **Motivo**: non è un requisito di SLE v1
- **Roadmap**: valutare per v2 (utile per arbitraggio)

### 4.3 No oracle esterno
- **Cosa manca**: Chainlink o altri oracle per prezzi esterni
- **Cosa c'è**: prezzo calcolato on-chain dalle riserve
- **Motivo**: SLE è un AMM, non un protocollo di lending
- **Roadmap**: valutare per v2 se integrato con altri protocolli

---

## 5. Cosa NON è una limitazione

Per evitare confusione, ecco cose che **sembrano** limitazioni ma non lo sono:

| Cosa | Perché non è una limitazione |
|---|---|
| No admin functions su PoolManager | Deliberato: core immutabile |
| Provider one-shot | Deliberato: previene sostituzione Router |
| MINIMUM_LIQUIDITY lock | Deliberato: previene attacco donazione |
| Fee max 200 bps hard-coded | Deliberato: previene fee arbitrarie |
| Fail-closed su detector stale | Deliberato: sicurezza > disponibilità |
| No upgrade del Router | Deliberato: auditabilità |

---

## 6. Riepilogo: cosa arriva in v2

| Feature | Priorità | Impatto |
|---|---|---|
| Concentrated liquidity | ALTA | Efficienza capitale |
| Sentinelle AI (proponenti) | ALTA | Strategie adattive |
| Timelock + multisig | ALTA | Riduce centralizzazione |
| MEV ordering (FIFO) | MEDIA | Riduce sandwich |
| TWAP persistente | MEDIA | Regime detector migliore |
| Supporto fee-on-transfer | BASSA | Più token |
| Flash loan nativo | BASSA | Arbitraggio |
| Diamond (upgrade) | BASSA | Se necessario |

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
