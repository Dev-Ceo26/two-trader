# PROJECT STATE — Two-Trader (T2T)

> Ultimo aggiornamento: 2026-10-18
> Nome: **Two-Trader** (T2T)
> Dominio: two-trader.com | Explorer: explorer-testnet.two-trader.io
> Chain ID Testnet: **332**
> Chain ID Mainnet: **333** (Standby, non avviata)
> Brand registrato su Ethereum mainnet (vedi docs/BRAND-REGISTRATION.md)

---

## Che cos'e' il progetto

Two-Trader (T2T) è una chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico (`DecisionLib.Decision`)
con campi nominati, firme 3/5, deadline, veto, fee.
Niente payload opachi. Niente "firma qualunque cosa".
Obiettivo: infrastruttura per trading e trasferimenti senza opacità,
con rescue nativo dei fondi e anti-scam by design.

Sopra la chain vive **T2T DEX**, il modulo di trading nativo (Uniswap v4 fork):
pool concentrate, hooks con guardian check, router e pool manager.
**MORE THAN A PLATFORM. A TRADING ECOSYSTEM.**

---

## Stack tecnico

| Componente | Dove | Note |
|---|---|---|
| **reth** | Raspberry (`/mnt/reth-archive/332`) | Nodo EVM, systemd: `reth-testnet.service` |
| **qpos-consensus** | Raspberry (`~/qpos-consensus`) | Consenso QPoS, 4 validatori, slot adattivo |
| **Blockscout** | VPS (`/opt/blockscout`) | Explorer, `blockscout:twotrader-v2` |
| **Foundry** | Raspberry (`~/.foundry/bin`) | forge, cast, anvil |
| **Repo** | Raspberry (`~/twotrader`) | git, branch `master` |

### Accessi

- RPC testnet: `http://localhost:30334` (Raspberry)
- AuthRPC (QPoS↔Reth): `http://127.0.0.1:8553`
- Explorer: `https://explorer-testnet.two-trader.io/`
- Sito: `https://two-trader.com` (Vercel)
- Deployer: `0x8d2eD8c03c62407fae385E32121172b3b12ff484`
- VPS Blockscout: `root@imperium` (188.213.166.229)
- Chiave deployer: in `.env.twotrader` (NON committata)

---

## Rebranding completato (2026-10-18)

Tutti i riferimenti a "Imperium" sono stati rimossi dal codice e dalla documentazione.
La logica dei contratti è **invariata**, l'audit resta valido.

### Mappatura nomi

| Vecchio | Nuovo |
|---|---|
| `IMP.sol` / `contract IMP` | `TwoTrader.sol` / `contract TwoTrader` |
| `tIMP.sol` / `contract tIMP` | `tTwoTrader.sol` / `contract tTwoTrader` |
| `IMPUSD.sol` | `T2TUSD.sol` |
| `IMPStaking.sol` | `T2TStaking.sol` |
| `ImperiumBridge*` | `T2TBridge*` |
| `ImperiumMessenger` | `T2TMessenger` |
| `ImperiumRouter` | `T2TRouter` |
| `ImperiumHooks` | `T2THooks` |
| `ImperiumPoolManager` | `T2TPoolManager` |
| `ImperiumProtocolFees` | `T2TProtocolFees` |
| `ImperiumPair` / `ImperiumFactory` | `T2TPair` / `T2TFactory` |
| `ImperiumVault` | `T2TVault` |
| `ImperiumDAO` | `T2TDAO` |
| **Symbol `"IMP"`** | **`"T2T"`** |
| **Symbol `"tIMP"`** | **`"tT2T"`** |
| Display name `"Imperium"` | `"Two-Trader"` |
| Display name `"Imperium Testnet"` | `"Two-Trader Testnet"` |

### Supply e allocazioni (INVARIATE — audit valido)

| Token | MAX_SUPPLY | INITIAL_SUPPLY | Allocazioni |
|---|---|---|---|
| **TwoTrader** (mainnet) | 1.000.000.000 T2T | 100.000.000 T2T | 100M al deployer |
| **tTwoTrader** (testnet) | 1.000.000.000 tT2T | 210.000.000 tT2T | 100M owner + 100M faucet + 10M bridge |

### Test

- **51/51 test passati** (10 suite)
- Nessuna modifica alla logica
- Audit valido (bytecode logico identico)

---

## Stato della Testnet (Chain 332) — PRONTA MA NON AVVIATA

Configurazione pronta, chain non ancora avviata.

### Configurazione

| Elemento | Percorso | Stato |
|---|---|---|
| Genesis | `/home/imperium-node/genesis-332.json` | ✅ creato (chainId 332) |
| Datadir Reth | `/mnt/reth-archive/332` | ✅ creato |
| JWT | `/mnt/reth-archive/332/jwt.hex` | ✅ generato |
| QPoS config | `qpos-consensus/src/config.rs` | ✅ chain_id 332 |
| QPoS validators | `/home/imperium-node/.t2t/validators/` | ✅ copiati (4 file JSON) |
| Systemd Reth | `/etc/systemd/system/reth-testnet.service` | ✅ aggiornato a 332 |
| Systemd Description | "Reth Node - T2T Testnet (Chain ID 332)" | ✅ aggiornato |
| Vecchie chain 9818/9819 | `/mnt/reth-archive/` | ✅ cancellate |
| Backup obsoleti | `broadcast.bak.*`, `cache.bak.*` | ✅ rimossi |

### Contratti (da deployare sulla chain 332)

Tutti i contratti sono pronti per il deploy, ma **nessun indirizzo esiste ancora** sulla chain 332 (è appena stata resettata).

| Contratto | Stato |
|---|---|
| TwoTrader / tTwoTrader | ⏳ da deployare |
| T2TUSD | ⏳ da deployare |
| T2TStaking | ⏳ da deployare |
| T2TVault | ⏳ da deployare |
| T2TFactory | ⏳ da deployare |
| T2TMessenger | ⏳ da deployare |
| T2TBridgeRoot | ⏳ da deployare |
| T2TBridgeChild | ⏳ da deployare |
| T2TPoolManager | ⏳ da deployare |
| T2TRouter | ⏳ da deployare |
| T2THooks | ⏳ da deployare |
| T2TDAO + TimelockController | ⏳ da deployare |
| GuardianRegistry (sentinelle) | ⏳ da deployare |
| DecisionRegistry (canone) | ⏳ da deployare |

---

## Mainnet (Chain 333) — STANDBY

**STATO: NON AVVIATA.**
Nessun contratto deployato. Il lancio avverrà solo dopo il periodo di beta testing sulla testnet 332 e la validazione finale del codice.

Tutti gli indirizzi della mainnet verranno generati e documentati al momento del deploy.

---

## Sicurezza e Infrastruttura

- ✅ Firewall UFW attivo sul Raspberry (RPC 30334 non esposto pubblicamente)
- ✅ Whitelist IP VPS (188.213.166.229) per RPC/WS — **DA FARE**
- ✅ Disco VPS: 16% (128 GB liberi)
- ✅ Disco Raspberry: /mnt/reth-archive 22% (349 GB liberi)
- ✅ Slot adattivo: formula fixata (`base * scale / (scale + pending)`)
- ⚠️ `qi-blocks`/`qi-attestations` crescono ~2 GB/giorno (da monitorare)
- ⚠️ Zero peer (chain privata, non pubblica ancora)

---

## T2T Smart Liquidity Engine (SLE) v1 — Testnet-ready

**Stato: COMPLETO E TESTATO.** Deployato e verificato su Anvil (chain 9818).

### Panoramica

SLE è il motore di liquidità originale di T2T, **scritto da zero**, non derivato da Uniswap v4 o Balancer. Licenza prevista MIT.

Architettura modulare:
- **SLEAddressProvider**: associazione one-shot e irreversibile tra Router e PoolManager (risolve il ciclo di dipendenza)
- **PoolRegistry**: whitelist curve, registrazione pool, freeze associazione
- **ConstantProductCurve**: AMM x·y=k, formula originale
- **PoolManager**: contabilità, invarianti, safety net, fee cap, fee-on-transfer reject
- **RegimeDetector**: regime CALM/VOLATILE/CRITICAL, isteresi, staleness, fail-closed
- **StrategySelector**: matrice fail-open/fail-closed, fee clamp
- **3 Strategie**: CalmStrategy (5 bps), VolatileStrategy (50 bps), CriticalStrategy (150 bps + block > 1% liquidità)
- **T2TRouter**: unico entry point autorizzato, transferFrom utente→router, forceApprove, reset allowance

### Statistiche test

| Categoria | Numero | Cosa copre |
|---|---|---|
| Test totali | **161** | Unitari + integrazione + E2E |
| Invarianti formali | **7** | 128.000 chiamate random, 0 violazioni |
| Fuzz test | **~15** | Funzioni matematiche, swap, LP, boundary |
| Test 512-bit | **20** | ProportionalMath isolata, overflow, max values |
| Test access control | **~10** | OnlyRouter, owner check, provider config |
| Test fail-closed | **17** | Detector stale/revert, strategia KO, CRITICAL |

### Invarianti verificati

| ID | Proprietà | Test |
|---|---|---|
| INV-1 | `totalLPSupply == MINIMUM_LIQUIDITY + Σ lpBalances` | invariant_INV1 |
| INV-2 | `token.balanceOf(pm) == reserve + feeAccrued` | invariant_INV2 |
| INV-3 | `k_after >= k_before` dopo swap | invariant_INV3 |
| INV-4 | `MAX_FEE == 200` costante | invariant_INV4 |
| INV-5 | LP utente ≤ total - MINIMUM_LIQUIDITY | invariant_INV5 |
| INV-7 | Router non trattiene token | invariant_INV7 |
| INV-8 | Allowance Router→PM sempre 0 | invariant_INV8 |

### Protezioni implementate

| Protezione | Dove |
|---|---|
| **OnlyRouter** (via provider) | PoolManager mod `onlyRouter` |
| **Fee cap 200 bps** | PoolManager costante `MAX_FEE` |
| **Safety net curva** | PoolManager `maxOut` su input netto |
| **Fee-on-transfer reject** | PoolManager `_safeTransferIn` |
| **Reentrancy** | Router `nonReentrant`, PM `nonReentrant` |
| **Proporzionalità LP 1 bps** | `ProportionalMath.proportionalEnough` cross-multiply 512-bit |
| **MINIMUM_LIQUIDITY lock** | PoolManager primo add |
| **Arrotondamento prelievo** | Fee + reserve share separati |
| **Fail-closed** | Selector: detector invalido/stale/revert → block |
| **Provider one-shot** | Provider `setEndpoints` irreversibile |
| **Allowance reset** | Router dopo ogni operazione |

### Deploy

| Ambiente | Stato | Script |
|---|---|---|
| **Anvil (9818)** | ✅ Deployato e verificato | `./deploy-sle.sh broadcast` |
| **Testnet 332** | ⏳ Pronto (da deployare su chain 332) | Stesso script, `--rpc-url` diverso |
| **Mainnet 333** | ❌ Escluso (richiede audit esterno) | — |

Indirizzi del deploy Anvil in `deployments/9818.json`.

### Documentazione

- `docs/design/SMART-LIQUIDITY-ENGINE.md` — Specifica completa (434 righe)
- `docs/audit/` — Pacchetto audit esterno (14 documenti)
- `deploy-sle.sh` — Orchestratore deploy (dry-run + broadcast)
- `script/DeploySLE.s.sol` — Script Foundry

### Roadmap SLE

| Fase | Stato |
|---|---|
| v1 (constant product, strategie deterministiche) | ✅ Completo |
| v2 (concentrated liquidity, sentinelle AI) | ⏳ Pianificato |
| Audit esterno | ⏳ Prossimo (pacchetto pronto) |
| Deploy testnet 332 | ⏳ Dopo audit |

---

## Prossimo passo

1. **Avviare la chain 332** (Reth + QPoS)
2. **Deployare i contratti** con uno script unico ("deploy compresso")
3. **Registrare i guardian** (sentinelle) e impostare lo stake
4. **Creare la pool** T2T/mUSDC sul T2T DEX
5. **Riavviare Blockscout** con il nuovo logo e verificare la chain
6. **Aggiornare `.env` e landing page** con i nuovi indirizzi
7. **Onboarding betatester**

---

## Visione

"Prima chain decentralizzata senza mano umana, dove si fa trading senza paura
dei short, senza dump del 30% in pochi giorni, con token rescue nativo,
revert delle tx non confermate in 24h, anti-scam by design.
Il canone delle decisioni e' l'implementazione di questa visione."

**Le sentinelle** sono robot quantistici autonomi (nodi AI/quantistici) che monitorano
la blockchain e attivano protocolli di sicurezza senza intervento umano.
Sono implementate in `GuardianRegistry` (identità) + `DecisionLib` (firma 3/5)
+ `DecisionRegistry` (veto) + `qpos-consensus` (slot adattivo).

**TRADE. ANALYZE. GROW.**
