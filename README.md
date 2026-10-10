# Imperium

> **Stato attuale beta**: vedi [PROJECT-STATE.md](./PROJECT-STATE.md)
>
> Chain: **Imperium Testnet** (chainId 9818)
> Explorer: https://explorer-testnet.imperiumscan.com/
> Ultimo aggiornamento: 2026-10-10

---

## Cos'e' Imperium

Chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico (`DecisionLib.Decision`)
con campi nominati, firme 3/5, deadline, veto, fee.
Niente payload opachi. Niente "firma qualunque cosa".

### Obiettivi

- **Infrastruttura per trading e trasferimenti** senza opacita'
- **Rescue nativo dei fondi** (deadline, veto, emergency)
- **Anti-scam by design** (whitelist, canone, governance)
- **Decisioni canoniche** tracciate, leggibili, verificabili

---

## Struttura
contracts/
├── decisions/ # DecisionLib, DecisionRegistry (canone)
├── bridge/ # Messenger, BridgeRoot, BridgeChild
├── governance/ # GuardianRegistry, ImperiumDAO, Timelock
├── v4/ # PoolManager, Router, Hooks (DEX)
├── token/ # tIMP
└── ...

docs/
├── CANON.md # La grammatica delle decisioni
├── BETA-GUIDE.md # Guida per i betatester
├── PROJECT-STATE.md # Stato attuale (in root)
└── ...

text

---

## Documentazione chiave

| Documento | Cosa contiene |
|---|---|
| [PROJECT-STATE.md](./PROJECT-STATE.md) | Stato attuale del progetto |
| [docs/CANON.md](./docs/CANON.md) | La grammatica delle decisioni |
| [docs/BETA-GUIDE.md](./docs/BETA-GUIDE.md) | Guida per i betatester |
| [docs/COLLAUDO-TESTNET-V1.2.md](./docs/COLLAUDO-TESTNET-V1.2.md) | Collaudo end-to-end |
| [docs/DEPLOYED-BETA-V1.2.md](./docs/DEPLOYED-BETA-V1.2.md) | Indirizzi canone |
| [docs/DEPLOYED-DEX-TESTNET.md](./docs/DEPLOYED-DEX-TESTNET.md) | Indirizzi DEX |

---

## Build e test

Richiede [Foundry](https://book.getfoundry.sh/).

```shell
forge build
forge test
Deploy
Vedi docs/BETA-GUIDE.md per il deploy sulla testnet.

Contatti
GitHub: Dev-Ceo26/quantum-imperium

Explorer: https://explorer-testnet.imperiumscan.com/

License
MIT (vedi LICENSE)
