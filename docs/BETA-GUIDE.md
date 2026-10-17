# Beta Test Guide — Imperium Testnet

> Versione beta: 0.1 (2026-10-10)
> Chain ID: 9818
> Explorer: https://explorer-testnet.imperiumscan.com/

Benvenuto nella beta di Imperium. Questa guida ti spiega cosa testare,
come farlo, e come segnalare problemi.

---

## Cos'e' Imperium

Chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico (`DecisionLib.Decision`)
con campi nominati, firme 3/5, deadline, veto, fee.
Niente payload opachi. Niente "firma qualunque cosa".

---

## Setup wallet

1. Aggiungi la rete al wallet:
   - Nome: TWOTRADER Testnet
   - RPC: [vedi docs/RPC.md]
   - Chain ID: 9818
   - Symbol: IMP

2. Ottieni IMP per il gas: chiedi al deployer
   `0x8d2eD8c03c62407fae385E32121172b3b12ff484`

---

## Contratti beta

### Canone
| Contratto | Indirizzo |
|---|---|
| GuardianRegistry | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 |
| DecisionRegistry | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e |
| ImperiumMessenger | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 |
| ImperiumBridgeRoot | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c |
| ImperiumBridgeChild | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 |

### DEX
| Contratto | Indirizzo |
|---|---|
| ImperiumPoolManager | 0xdb9175d0d41b40b1667ea947ff38b96144a900d4 |
| ImperiumRouter | 0x743c8f316bf7d18ad139fec23754293b244e5913 |
| ImperiumHooks | 0xc6c21de82b1e1e3be0c8305c28faf8a9192800c0 |

### Token
| Token | Indirizzo |
|---|---|
| tIMP (18 dec) | 0x63B3b910be2Ef843dbE920Df2CcC032fe5143A6B |
| mUSDC-b (6 dec) | 0xFCDE586a3f72d535902E8197AE3effeb4a3E9171 |

### Governance
| Contratto | Indirizzo |
|---|---|
| ImperiumDAO | 0x757ac427055fad1ddb235bb84248ef489b9a7f6d |
| Timelock | 0xf621898a59cd792cb0bef8ba46226ef3cddcb922 |

---

## Test 1 — Deposit cross-chain

**Obiettivo:** verificare il canone end-to-end.

1. Approva il BridgeRoot per mUSDC-b:
   `mUSDC-b.approve(0xAD334755..., 100000000)`

2. Chiama `depositCrossChain`:
BridgeRoot.depositCrossChain(
mUSDC-b, // token
tuo-indirizzo, // recipient
100000000, // amount (100 mUSDC)
11155111 // srcChainId (Sepolia)
)

text

3. Sull'explorer cerca l'evento `DecisionRecorded`. Troverai:
- DID (l'identificatore della decisione)
- Tutti i campi (kind, actor, token, recipient, amount, fee, ...)

4. Verifica che l'evento sia **leggibile**: ogni campo e' nominato, non e' un blob.

---

## Test 2 — Swap sul DEX

**Obiettivo:** verificare il DEX V4.

1. Approva il Router per mUSDC-b:
`mUSDC-b.approve(0x743c8f31..., 10000000)`

2. Chiama `swapExactInput`:
Router.swapExactInput(
PoolKey({
currency0: tIMP,
currency1: mUSDC-b,
fee: 3000,
tickSpacing: 60,
hooks: 0xc6c21de8...
}),
false, // zeroForOne (USDC -> tIMP)
10000000, // amountIn
0, // amountOutMin
tuo-indirizzo, // recipient
block.timestamp + 600
)

text

3. Verifica il saldo tIMP dopo lo swap.

---

## Test 3 — Governance

**Obiettivo:** verificare il DAO.

**Nota:** il DAO e' in "shadow" durante la beta. Il deployer mantiene
il controllo. I test di governance sono facoltativi.

1. Crea una proposta:
DAO.propose(
[target],
[0],
[calldata],
"descrizione"
)

text

2. Aspetta `votingDelay` (300 blocchi ~ 30 min)

3. Vota:
DAO.castVote(proposalId, 1) // 1 = For

text

4. Aspetta `votingPeriod` (1800 blocchi ~ 3 ore)

5. Esegui:
DAO.queue(...)
DAO.execute(...)

text

---

## Cosa NON fare

- **Non usare fondi reali.** Questa e' una testnet beta.
- **Non condividere le tue chiavi private.**
- **Non aspettarti stabilita' al 100%.** La beta e' per trovare problemi.

---

## Come segnalare un problema

Apri una issue su GitHub con:
- Cosa stavi facendo
- Cosa ti aspettavi
- Cosa e' successo
- Hash della transazione (dall'explorer)
- Screenshot se utile

---

## Contatti

- GitHub: Dev-Ceo26/quantum-imperium
- Explorer: https://explorer-testnet.imperiumscan.com/
