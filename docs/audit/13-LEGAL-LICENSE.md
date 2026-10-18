# Legal & License — SLE v1

> **Destinatari**: auditor, legale
> **Scopo**: dichiarare licenza, provenienza del codice, e conformità

---

## 1. Licenza

**Tutto il codice SLE è rilasciato sotto licenza MIT.**
MIT License

Copyright (c) 2026 Two-Trader (T2T)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

text

---

## 2. Provenienza del codice

| Componente | Provenienza | Note |
|---|---|---|
| SLE core (provider, registry, pool manager, router) | **Originale**, scritto da zero | Nessuna derivazione da terzi |
| ConstantProductCurve | **Originale** | Formula x·y=k, implementazione custom |
| ProportionalMath | **Originale** | Cross-multiply 512-bit, implementazione custom |
| RegimeDetector | **Originale** | Logica regime + isteresi custom |
| StrategySelector | **Originale** | Matrice fail-closed custom |
| Strategie (3) | **Originale** | Semplici, stateless |
| Interfacce | **Originale** | Definite per SLE |

---

## 3. Dipendenze esterne

| Libreria | Versione | Licenza | Uso |
|---|---|---|---|
| OpenZeppelin Contracts | 5.x | MIT | ERC20, SafeERC20, Ownable, ReentrancyGuard, Math |
| Foundry (forge-std) | latest | MIT | Test framework |

**Nessuna dipendenza da**:
- Uniswap v4 (BUSL-1.1)
- Balancer v2 (GPL-3.0)
- Altri protocolli con licenze restrittive

---

## 4. Conformità licenze

| Aspetto | Stato |
|---|---|
| SPDX identifier presente | ✅ In ogni file `.sol` |
| Nessun codice copiato da fonti BUSL | ✅ Verificato |
| Nessun codice copiato da fonti GPL | ✅ Verificato |
| Attribuzione OpenZeppelin | ✅ MIT, attribuzione non richiesta ma gradita |

---

## 5. Copyright

Ogni file `.sol` in `contracts/sle/` inizia con:
// SPDX-License-Identifier: MIT

text

Il copyright è detenuto da Two-Trader (T2T). Il team è aperto a contribuzioni esterne (con CLA da definire).

---

## 6. Disclaimer

**Il software è fornito "as is"**, senza garanzie di alcun tipo. Gli autori non sono responsabili per:
- Perdite di fondi dovute a bug
- Danni derivanti dall'uso del software
- Violazioni di leggi locali da parte degli utenti

**Uso in mainnet**: richiede audit esterno indipendente. L'audit è in corso (questo pacchetto).

---

## 7. Audit trail

| Evento | Data | Riferimento |
|---|---|---|
| Primo commit SLE | 2026-10-18 | `61ac359` |
| Design doc | 2026-10-18 | `docs/design/SMART-LIQUIDITY-ENGINE.md` |
| Deploy Anvil verificato | 2026-10-18 | `deployments/9818.json` |
| Pacchetto audit | 2026-10-18 | `docs/audit/` |

---

## 8. Contatti legali

- **Generale**: legal@two-trader.com
- **Security**: security@two-trader.com
- **GitHub**: https://github.com/Dev-Ceo26/two-trader

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
