# PROJECT STATE — Imperium (beta)

> Ultimo aggiornamento: 2026-10-10
> Chain ID: 9818 (beta, pubblica)
> Nome: Imperium (BETA — il nome definitivo sara' scelto prima del lancio)
> Chain ID definitivo: da decidere (9819 candidato)

---

## Cos'e' il progetto

Chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico (`DecisionLib.Decision`)
con campi nominati, firme 3/5, deadline, veto, fee.
Niente payload opachi. Niente "firma qualunque cosa".
Obiettivo: infrastruttura per trading e trasferimenti senza opacita',
con rescue nativo dei fondi e anti-scam by design.

---

## Stack tecnico

| Componente | Dove | Note |
|---|---|---|
| **reth** | Raspberry (`/mnt/reth-archive/9818`) | Nodo EVM, systemd: `reth-testnet.service` |
| **qpos-consensus** | Raspberry (processo separato) | Consenso QPoS, 4 validatori, slot 6s |
| **Blockscout** | VPS (`/opt/blockscout/docker-compose`) | Explorer, blockscout:quantum-imperium-v2 |
| **Foundry** | Raspberry (`~/.foundry/bin`) | forge, cast, anvil |
| **Repo** | Raspberry (`~/timp-token`) | git, branch `master` |

### Accessi

- RPC testnet: `http://localhost:30334` (Raspberry) / raggiungibile dal VPS
- Explorer: `https://explorer-testnet.imperiumscan.com/`
- Deployer: `0x8d2eD8c03c62407fae385E32121172b3b12ff484` (~999.999 IMP)
- VPS: `root@imperium` (Blockscout)
- Chiave deployer: in `.env.imperium` (NON committata)

---

## Contratti deployati sulla beta (19, settembre 2026)

Allineati con Sepolia. Vedi `DEPLOYED.md` per la lista completa.
Includono: tIMP, Vault, FeeDistributor, Factory, Staking, Faucet,
GuardianRegistry (v1), Messenger (v1), BridgeRoot/Child (v1),
PoolManager, Router, Hooks (v1), IMPUSD, MasterMinter, MockUSDC/USDT, BRVBTC.

**NOTA:** questi sono contratti della **versione precedente** del canone.
Non hanno `DecisionLib`, non hanno `EMERGENCY_ROLE`, non hanno fee configurabile.

---

## Contratti da deployare (canone v1.2)

Da deployare **sopra** la beta attuale, come sistema separato:

| Contratto | Stato | Indirizzo |
|---|---|---|---|
| GuardianRegistry v1.2 | deployato 2026-10-10 | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 |
| DecisionRegistry | deployato 2026-10-10 | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e |
| ImperiumMessenger v1.2 | deployato 2026-10-10 | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 |
| ImperiumBridgeRoot v1.2 | deployato 2026-10-10 | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c |
| ImperiumBridgeChild v1.2 | deployato 2026-10-10 | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 |
| ImperiumPoolManager | da deployare | — |
| ImperiumRouter v1.2 | da deployare | — |
| ImperiumHooks v1.2 (fix tick) | da deployare | — |
| TimelockController | da deployare | — |
| ImperiumDAO v1.2 | da deployare | — |

---

## Cosa funziona (verificato)

- ✅ Canone v1.2 (13/13 test Foundry verdi)
- ✅ Cross-chain con fee (collaudato su anvil, Sessioni A/B/C)
- ✅ PromoteGovernance (grant + renounce, collaudato su anvil)
- ✅ DEX V4 (pool, hook, swap — collaudato su anvil con fix tick)
- ✅ Chain testnet attiva (blocco 193.594)
- ✅ Explorer Blockscout funzionante (backend healthy, log limitati)
- ✅ Disco VPS: 16% (128 GB liberi)
- ✅ Disco Raspberry: /mnt/reth-archive 22% (349 GB liberi)

## Cosa manca

- ✅ Canone v1.2 deployato sulla beta (2026-10-10)
- ✅ 3 guardian attivi (deployer + G2 + G3), stake 1000 IMP ciascuno
- ❌ DEX fixato NON deployato sulla beta
- ❌ DAO reale (TimelockController) NON deployato
- ❌ PromoteGovernance NON eseguito sulla beta
- ❌ Test end-to-end sulla beta (deposit/firme/finalize/swap)
- ✅ `.env.testnet` creato
- ✅ Anvil a chainId 31337 (testnet resta 9818)
- ✅ Broadcast separati (31337 vs 9818)
- ⚠️ `qi-blocks`/`qi-attestations` crescono ~2 GB/giorno
- ⚠️ Zero peer (chain privata, non pubblica ancora)
- ⚠️ Firewall assente (RPC esposto su 0.0.0.0:30334)

---

## Prossimo passo

1. Cambiare anvil a chainId 31337
2. Creare `.env.testnet`
3. Deployare canone v1.2 + DEX + DAO sulla beta
4. Test end-to-end
5. Promuovere governance al DAO
6. Consegna ai betatester

---

## Come riprendere il contesto

Se stai iniziando una nuova chat, incolla questo file e chiedi:
"Riprendiamo da PROJECT-STATE.md. Cosa facciamo adesso?"

---

## Visione (per il nome definitivo)

"Prima chain decentralizzata senza mano umana, dove si fa trading senza paura
dei short, senza dump del 30% in pochi giorni, con token rescue nativo,
revert delle tx non confermate in 24h, anti-scam by design.
Il canone delle decisioni e' l'implementazione di questa visione."

Nomi candidati per la chain definitiva: Aegis, Custos, Portalis, Aeternum,
Sentinel, Vigil, Canon.

### Decisione: PromoteGovernance rimandato

**Il deployer mantiene GOVERNOR_ROLE + DEFAULT_ADMIN_ROLE su tutti i contratti**
(canone v1.2, DEX, DAO) durante la beta.

Motivo: permettere fix rapidi se qualcosa si rompe durante l'uso dei betatester.
Il DAO e' deployato ma in "shadow" (nessun ruolo sui contratti di sistema).

**PromoteGovernance sara' eseguito come ultimo passo prima del lancio pubblico**, quando:
1. I betatester hanno usato la beta per un periodo sufficiente
2. Tutti i bug conosciuti sono fixati
3. Un ultimo collaudo end-to-end e' verde
4. Si decide che il codice e' stabile

Sequenza finale:
1. `script/GrantGovernance.s.sol` — concede GOVERNOR_ROLE + DEFAULT_ADMIN_ROLE al Timelock
2. Verifica on-chain dei RoleGranted
3. `script/RevokeDeployer.s.sol` — il deployer rinuncia
4. Test di governance reale (proposta → voto → esecuzione)

---

## Riepilogo finale beta (2026-10-10)

### Tutto deployato e funzionante

| Componente | Indirizzo |
|---|---|
| tIMP | 0x63B3b910be2Ef843dbE920Df2CcC032fe5143A6B |
| mUSDC-b | 0xFCDE586a3f72d535902E8197AE3effeb4a3E9171 |
| GuardianRegistry | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 |
| DecisionRegistry | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e |
| ImperiumMessenger | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 |
| ImperiumBridgeRoot | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c |
| ImperiumBridgeChild | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 |
| ImperiumPoolManager | 0xdb9175d0d41b40b1667ea947ff38b96144a900d4 |
| ImperiumRouter | 0x743c8f316bf7d18ad139fec23754293b244e5913 |
| ImperiumHooks | 0xc6c21de82b1e1e3be0c8305c28faf8a9192800c0 |
| TimelockController | 0xf621898a59cd792cb0bef8ba46226ef3cddcb922 |
| ImperiumDAO | 0x757ac427055fad1ddb235bb84248ef489b9a7f6d |

### Test verdi (end-to-end su testnet)
- DepositCrossChain
- Firme 3/3
- verifyDecision
- finalizeDeposit
- Replay -> revert 'already processed'
- Veto
- Swap DEX
- Proposta DAO (stato Pending)

### Deployer
- 0x8d2eD8c03c62407fae385E32121172b3b12ff484
- GOVERNOR_ROLE su tutti i contratti (beta)
- VETO_ROLE su DecisionRegistry

### Guardian registrati
- G1 = deployer
- G2 = 0x10872E0e2eCC9883CDCbecD74C8e6eb856c31C72
- G3 = 0x1E48B5f4a711288fD7456Fbfa94C6F76E4bC9d87
- Chiavi private in _legacy/guardian-wallets-beta.txt (gitignored)

### Documentazione
- PROJECT-STATE.md (questo file)
- docs/CANON.md
- docs/COLLAUDO-TESTNET-V1.2.md
- docs/DEPLOYED-BETA-V1.2.md
- docs/DEPLOYED-DEX-TESTNET.md
- docs/BETA-GUIDE.md
- docs/ROADMAP-v1.2.md

### Prossimo
1. Consegna ai betatester
2. Monitoraggio 24/7 per fix rapidi
3. PromoteGovernance solo al pre-lancio

---

## Slot adattivo (2026-10-10)

### Modifica a qpos-consensus

Il consenso ora calcola lo slot dinamicamente in base al mempool:

    slot = clamp(base_slot / (1 + pending_tx / tx_scale), min_slot, max_slot)

**Parametri:**
- base_slot: 12s
- min_slot: 2s
- max_slot: 30s
- tx_scale: 5

**Comportamento:**
| pending | slot | blocchi/giorno |
|---|---|---|
| 0 | 12s | 7.200 |
| 5 | 6s | 14.400 |
| 20 | 2s | 43.200 |
| 50+ | 2s | 43.200 |

### File modificati
- `src/config.rs` — nuovi campi (`base_slot`, `min_slot`, `max_slot`, `tx_scale`, `dynamic_slot`)
- `src/reth_rpc.rs` — `txpool_pending_count()`
- `src/main.rs` — calcolo dinamico + sleep

### Riavvio
Il processo gira in screen: `screen -ls | grep qpos`.

### Verifica
- idle: slot 12s, 2-3 blocchi/30s
- 20 tx in 5s: slot 2s

### Fix formula (divisione intera)

La prima versione aveva un bug: `raw = base / (1 + pending / scale)`.
Con `pending < scale`, `pending/scale = 0` e lo slot non cambiava mai.

**Formula corretta:**
    raw = base * scale / (scale + pending)

**Verifica on-chain:**
- pending=0  → slot=12s
- pending=3  → slot=7s   ✅
- pending=5  → slot=6s
- pending=10 → slot=4s
- pending=20 → slot=2s (clamp min)
