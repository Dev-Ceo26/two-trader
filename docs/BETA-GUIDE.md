# Beta Test Guide — Imperium Testnet

> Versione beta: 0.1 (2026-10-10)
> Chain ID: 9818
> Explorer: https://explorer-testnet.imperiumscan.com/

Benvenuto nella beta di Imperium. Questa guida ti spiega cosa testare,
come farlo, e come segnalare problemi.

---

## Cos'e' Imperium (in due righe)

Chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico con firme 3/5,
deadline, veto, fee. Niente payload opachi. Niente "firma qualunque cosa".

---

## Cosa puoi testare

### 1. Bridge — deposito con decisione canonica

Il bridge accetta token da altre chain (per ora simulato) e li trasferisce
sulla chain Imperium. Ogni trasferimento passa per una **decisione canonica**.

**Cosa fare:**
1. Ottieni mUSDC-b dal deployer (testnet)
2. Approva il BridgeRoot
3. Chiama `depositCrossChain`
4. Guarda l'evento `DecisionRecorded` sull'explorer
5. Verifica che la decisione sia tracciabile

**Contratto da usare:**
- BridgeRoot: `0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c`
- Token mUSDC-b: `0xFCDE586a3f72d535902E8197AE3effeb4a3E9171`

### 2. DEX — swap tIMP/mUSDC

**Cosa fare:**
1. Approva il Router per tIMP e mUSDC-b
2. Chiama `swapExactInput`
3. Verifica il saldo dopo lo swap

**Contratti:**
- Router: `0x743c8f316bf7d18ad139fec23754293b244e5913`
- Pool Manager: `0xdb9175d0d41b40b1667ea947ff38b96144a900d4`

### 3. Governance — DAO

Il DAO e' deployato ma **in shadow**: durante la beta il deployer mantiene
il controllo. Se trovi problemi di governance, segnalali.

**Contratti:**
- ImperiumDAO: `0x757ac427055fad1ddb235bb84248ef489b9a7f6d`
- Timelock: `0xf621898a59cd792cb0bef8ba46226ef3cddcb922`

---

## Contratti deployati

Vedi `docs/DEPLOYED-BETA-V1.2.md` e `docs/DEPLOYED-DEX-TESTNET.md`.

---

## Come segnalare un problema

Apri una issue su GitHub con:
- Cosa stavi facendo
- Cosa ti aspettavi
- Cosa e' successo
- L'hash della transazione (dall'explorer)
- Screenshot se utile

---

## Cosa NON fare

- **Non usare fondi reali.** Questa e' una testnet beta.
- **Non condividere le tue chiavi private.**
- **Non aspettarti stabilita' al 100%.** La beta e' per trovare problemi.

---

## Contatti

- Telegram: [da definire]
- Discord: [da definire]
- GitHub: [da definire]
