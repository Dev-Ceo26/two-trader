# T2T Smart Liquidity Engine (SLE) v1 — Audit Package

> **Versione**: 1.0
> **Data**: 2026-10-18
> **Commit**: `61ac359`
> **Contatto**: team@two-trader.com

---

## Cos'è questo pacchetto

Documentazione tecnica completa per un **audit di sicurezza esterno** del Smart Liquidity Engine (SLE) v1 di Two-Trader (T2T). Il pacchetto è progettato per essere **autosufficiente**: un auditor esterno non ha bisogno di altro per iniziare.

## Cosa contiene

| # | Documento | Cosa trovi |
|---|---|---|
| 00 | `00-README.md` | Questo file — indice e guida |
| 01 | `01-EXECUTIVE-SUMMARY.md` | Panoramica 2 pagine, punti di forza, aree di rischio |
| 02 | `02-ARCHITECTURE.md` | Diagrammi, flussi, separazione moduli |
| 03 | `03-SCOPE.md` | Cosa è in scope, cosa è escluso |
| 04 | `04-THREAT-MODEL.md` | 15 minacce + mitigazioni |
| 05 | `05-INVARIANTS.md` | 8 invarianti formali |
| 06 | `06-TEST-COVERAGE.md` | Matrice 161 test |
| 07 | `07-KNOWN-LIMITATIONS.md` | Limiti v1, roadmap v2 |
| 08 | `08-DEPLOYMENT-PROCEDURE.md` | Script + verifica incrociata |
| 09 | `09-ACCESS-CONTROL.md` | Matrice ruoli |
| 10 | `10-EMERGENCY-PROCEDURES.md` | Cosa fare in caso di incidente |
| 11 | `11-GLOSSARY.md` | Terminologia |
| 12 | `12-AUDITOR-QUESTIONNAIRE.md` | 30 domande + risposte |
| 13 | `13-LEGAL-LICENSE.md` | MIT + provenienza |

## Come iniziare

1. **Leggi** `01-EXECUTIVE-SUMMARY.md` (5 minuti)
2. **Studia** `02-ARCHITECTURE.md` e `03-SCOPE.md` (15 minuti)
3. **Analizza** `04-THREAT-MODEL.md` e `05-INVARIANTS.md` (30 minuti)
4. **Verifica** con `06-TEST-COVERAGE.md` e `08-DEPLOYMENT-PROCEDURE.md`
5. **Approfondisci** con i documenti rimanenti

## Codice da auditare

| Percorso | Contratti | LOC | Licenza |
|---|---|---|---|
| `contracts/sle/interfaces/` | 5 | ~250 | MIT |
| `contracts/sle/curves/` | 1 | ~60 | MIT |
| `contracts/sle/core/` | 7 | ~800 | MIT |
| `contracts/sle/strategies/` | 3 | ~120 | MIT |
| `contracts/sle/libraries/` | 1 | ~80 | MIT |
| `contracts/test-mocks/` | 1 | ~15 | MIT |
| **Totale in scope** | **18** | **~1.300** | **MIT** |

## Test coverage

- **161 test unitari/integrazione**: 100% pass
- **7 invarianti formali**: 128.000 chiamate random, 0 violazioni
- **~15 fuzz test**: 256+ run ciascuno
- **20 test 512-bit**: matematica `ProportionalMath`

## Come contribuire

- Segnalazioni di vulnerabilità: `security@two-trader.com` (PGP disponibile su richiesta)
- Domande tecniche: `team@two-trader.com`
- Canale riservato per auditor: da concordare

---

*Ultimo aggiornamento: 2026-10-18. Documento vivo.*
