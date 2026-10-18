# Emergency Procedures — SLE v1

> **Destinatari**: team operativo, auditor
> **Scopo**: cosa fare in caso di incidente di sicurezza

---

## 1. Classificazione incidenti

| Severità | Definizione | Tempo di risposta |
|---|---|---|
| **P0 — Critico** | Perdita di fondi, exploit attivo | Immediato (< 15 min) |
| **P1 — Alto** | Bug sfruttabile, DoS su funzione core | < 1 ora |
| **P2 — Medio** | Bug non sfruttabile, comportamento anomalo | < 24 ore |
| **P3 — Basso** | Bug UI, gas subottimale | < 1 settimana |

---

## 2. P0 — Perdita di fondi / exploit attivo

### Azioni immediate

1. **Attivare la multisig sentinelle**
2. **Valutare se esiste una pausa d'emergenza** (in v1: **non esiste** sul PM, per design)
3. **Comunicare pubblicamente** entro 1 ora:
   - Cosa è successo
   - Cosa è a rischio
   - Cosa devono fare gli utenti (es. "non aggiungete liquidità")
4. **Contattare un auditor** per analisi indipendente
5. **Se il bug è nel Router o in Selector** (modificabili), disabilitare temporaneamente tramite provider (ma provider è one-shot, quindi **non possibile** in v1)
6. **Documentare tutto** su un canale privato

### Cosa NON è possibile in v1

⚠️ **SLE v1 non ha una funzione di pausa d'emergenza**. Questa è una scelta deliberata:
- Il PoolManager è immutabile
- Il provider è one-shot
- Le strategie sono immutabili

**Se c'è un bug critico in v1**, l'unica azione è:
- Comunicare agli utenti di fermarsi
- Deployare una nuova versione (v1.1)
- Migrare la liquidità (con consenso degli utenti)

### Roadmap v2
- Aggiungere `emergencyPause()` al PoolManager con timelock
- Aggiungere multisig sentinelle con poteri limitati
- Aggiungere circuit breaker automatico

---

## 3. P1 — Bug sfruttabile

1. **Analizzare il vettore d'attacco** con il team
2. **Se il bug è in un parametro** (Detector, Selector), l'owner può modificarlo immediatamente
3. **Se il bug è in una strategia**, l'owner può deregistrarla:
selector.unregisterStrategy(regime)

text
Da quel momento, il Selector userà DEFAULT_FEE (fail-open) o blockerà (fail-closed) a seconda del regime.
4. **Se il bug è in una curva**, l'owner può:
- Rimuoverla dalla whitelist (ma i pool esistenti la usano ancora)
- **Non c'è modo di bloccare un pool attivo in v1** (feature v2)

---

## 4. P2 — Bug non sfruttabile

1. Documentare il bug su issue tracker privato
2. Pianificare fix nella prossima release (v1.1)
3. Se il bug è in un parametro, valutare fix immediato

---

## 5. Contatti di emergenza

| Ruolo | Contatto |
|---|---|
| Team lead | team@two-trader.com |
| Security | security@two-trader.com |
| Auditor esterno | (da definire) |
| Canale pubblico | (da definire, es. Twitter) |

**PGP**: disponibile su richiesta.

---

## 6. Comunicazione pubblica

Template per comunicazione P0:
[INCIDENT] Two-Trader SLE — Bug critico in [componente]
Data: [data]
Severità: CRITICO

Cosa è successo: [descrizione breve]
Impatto: [fondi a rischio, utenti coinvolti]
Azioni in corso: [pausa, fix, migrazione]
Cosa devono fare gli utenti: [istruzioni chiare]
Prossimo aggiornamento: [entro 1 ora / data]

Ci scusiamo per l'accaduto. Maggiori dettagli: [link]

text

---

## 7. Post-mortem

Dopo ogni incidente P0/P1:
1. **Timeline** dettagliata (minuto per minuto)
2. **Root cause analysis**
3. **Lezioni apprese**
4. **Azioni correttive** (con owner e scadenza)
5. **Aggiornamento documentazione** (threat model, invarianti, test)

Il post-mortem va pubblicato entro 7 giorni dall'incidente.

---

*Documento vivo. Ultimo aggiornamento: 2026-10-18.*
