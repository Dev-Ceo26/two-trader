# Twotrader Manifesto

**Nome:** Twotrader
**Ticker:** T2T
**Dominio:** two-trader.com
**Data:** 2026-10-15
**Autore:** Dev-Ceo26 (github.com/Dev-Ceo26)

---

## Cos'e' Twotrader

Twotrader e' una chain EVM con un **canone delle decisioni** sopra il bridge.
Ogni decisione che muove valore e' un oggetto canonico con campi nominati,
firme 3/5, deadline, veto, fee. Niente payload opachi. Niente "firma
qualunque cosa".

## Il principio: il secondo trader

Twotrader significa "il secondo trader". Non un trader subordinato: il
trader che interviene **dopo**. La sua funzione e' proteggere il primo
trader da se stesso. La chain non decide al posto dell'utente: decide se
l'utente ha deciso bene.

## Caratteristiche tecniche

- **Consenso:** QPoS (Quantum Proof of Stake) con firme post-quantistiche
- **Crittografia:** Kyber512 (KEM), Dilithium2 (firme) — standard NIST
- **Canone:** DecisionLib con 12 campi, hash canonico, veto irreversibile
- **Bridge:** multi-sig guardian (3/5), anti-replay, deadline
- **DEX:** AMM con hook V4, whitelist token/pair
- **Governance:** DAO + Timelock
- **Slot adattivo:** 12s a riposo, fino a 2s sotto carico

## Documenti di riferimento

- CANON: la grammatica delle decisioni
- VOIDS: la genealogia dei vuoti del canone
- BETA-GUIDE: guida per i betatester

## Licenza

MIT

---

**La mela cade giu'. Anche quando nessuno guarda.**
