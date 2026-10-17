# PROJECT STATE — Twotrader (T2T)

> Ultimo aggiornamento: 2026-10-17
> Nome: **Twotrader** (T2T)
> Dominio: two-trader.com | Explorer: two-trader.io
> Chain ID testnet: 9818
> Chain ID mainnet: 9819 (Standby)
> Brand registrato su Ethereum mainnet (vedi docs/BRAND-REGISTRATION.md)

---

## Che cos'e' il progetto

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
| **qpos-consensus** | Raspberry (processo separato) | Consenso QPoS, 4 validatori, slot adattivo |
| **Blockscout** | VPS (`/opt/blockscout/docker-compose`) | Explorer, blockscout:quantum-twotrader-v2 |
| **Foundry** | Raspberry (`~/.foundry/bin`) | forge, cast, anvil |
| **Repo** | Raspberry (`~/twotrader`) | git, branch `master` |

### Accessi

- RPC testnet: `http://localhost:30334` (Raspberry) / raggiungibile dal VPS (tramite whitelist)
- Explorer: `https://explorer-testnet.twotrader-scan.com/`
- Deployer: `0x8d2eD8c03c62407fae385E32121172b3b12ff484` (~999.999 IMP)
- VPS: `root@twotrader` (Blockscout)
- Chiave deployer: in `.env.twotrader` (NON committata)

---

## Stato della Testnet (Beta) — PRONTA

Tutti i contratti del canone v1.2, DEX e DAO sono deployati e testati.

| Componente | Indirizzo | Stato |
|---|---|---|
| tIMP | 0x63B3b910be2Ef843dbE920Df2CcC032fe5143A6B | ✅ |
| GuardianRegistry v1.2 | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 | ✅ |
| DecisionRegistry | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e | ✅ |
| TwotraderMessenger v1.2 | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 | ✅ |
| TwotraderBridgeRoot v1.2 | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c | ✅ |
| TwotraderBridgeChild v1.2 | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 | ✅ |
| TwotraderPoolManager | 0xdb9175d0d41b40b1667ea947ff38b96144a900d4 | ✅ (Fixato) |
| TwotraderRouter | 0x743c8f316bf7d18ad139fec23754293b244e5913 | ✅ |
| TwotraderHooks (fix tick) | 0xc6c21de82b1e1e3be0c8305c28faf8a9192800c0 | ✅ (Fixato) |
| TimelockController | 0xf621898a59cd792cb0bef8ba46226ef3cddcb922 | ✅ |
| TwotraderDAO | 0x757ac427055fad1ddb235bb84248ef489b9a7f6d | ✅ |

### Test superati (End-to-End su testnet)
- DepositCrossChain, Firme 3/3, verifyDecision, finalizeDeposit, Replay revert, Veto, Swap DEX, Proposta DAO.

---

## Mainnet (Chain ID 9819)

**STATO: NON AVVIATA.**
Nessun contratto deployato. Il lancio avverrà solo dopo il periodo di beta testing e la validazione finale del codice. Tutti gli indirizzi della mainnet verranno generati e documentati al momento del deploy.

---

## Sicurezza e Infrastruttura

- ✅ Firewall UFW attivo sul Raspberry (Porta 30334 non esposta pubblicamente).
- ✅ Disco VPS: 16% (128 GB liberi)
- ✅ Disco Raspberry: /mnt/reth-archive 22% (349 GB liberi)
- ✅ Slot adattivo: formula fixata (`base * scale / (scale + pending)`).
- ⚠️ `qi-blocks`/`qi-attestations` crescono ~2 GB/giorno (da monitorare).
- ⚠️ Zero peer (chain privata, non pubblica ancora).

---

## Prossimo passo

1. Consegna ai betatester (Guide e UI pronte).
2. Monitoraggio 24/7 per fix rapidi.
3. Preparazione script per il deploy Mainnet.
4. PromoteGovernance (solo al pre-lancio pubblico).

---

## Visione

"Prima chain decentralizzata senza mano umana, dove si fa trading senza paura
dei short, senza dump del 30% in pochi giorni, con token rescue nativo,
revert delle tx non confermate in 24h, anti-scam by design.
Il canone delle decisioni e' l'implementazione di questa visione."

**MORE THAN A PLATFORM. A TRADING ECOSYSTEM.**
