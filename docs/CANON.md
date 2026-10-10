# CANON — Imperium Decision Canon

> Versione: 1.2 (Beta, Fase A)
> Ultimo aggiornamento: 2026-10-04
> Contratto di riferimento: `contracts/decisions/DecisionLib.sol`

Questo documento definisce la **grammatica delle decisioni** che attraversano il bridge Imperium. Ogni decisione che ha effetto on-chain deve essere esprimibile come `DecisionLib.Decision`. Nessuna decisione opaca. Nessun `bytes32` sciolto. Nessuna firma su qualcosa che non sia nel canone.

---

## 1. La struct `Decision`

    struct Decision {
        uint8   kind;
        address actor;
        address token;
        address recipient;
        uint256 amount;
        uint256 nonce;
        uint256 srcChainId;
        uint256 dstChainId;
        uint64  deadline;
        bytes32 rationaleHash;
        // --- v1.2 ---
        uint256 fee;             // 0 se deposito diretto, >0 se cross-chain
        address feeRecipient;    // 0x0 se fee == 0
    }

**L'ordine dei campi è parte del canone.** Cambiarlo invalida ogni firma esistente. Mai cambiare l'ordine. Mai rimuovere un campo. Solo aggiungere in coda, e solo con bump di versione esplicito.

### Campo per campo

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| `kind` | uint8 | uno dei `KIND_*` sotto | Tipo di decisione |
| `actor` | address | diverso da address(0) | Chi ha originato la decisione |
| `token` | address | vedi kind | Token coinvolto (address(0) se non applicabile) |
| `recipient` | address | vedi kind | Destinatario (address(0) se non applicabile) |
| `amount` | uint256 | vedi kind | Importo lordo (0 se non applicabile) |
| `nonce` | uint256 | unico per (actor, kind) | Anti-replay |
| `srcChainId` | uint256 | diverso da 0 | Catena di origine |
| `dstChainId` | uint256 | diverso da 0 | Catena di destinazione |
| `deadline` | uint64 | diverso da 0 | Dopo questo timestamp, la firma è invalida |
| `rationaleHash` | bytes32 | diverso da 0 | keccak256 di una spiegazione umana off-chain |
| `fee` | uint256 | vedi sezione 13 | Fee trattenuta dal protocollo (0 se deposito diretto) |
| `feeRecipient` | address | vedi sezione 13 | Destinatario della fee (0x0 se fee == 0) |

---

## 2. I `kind` ammessi

| Valore | Costante | Uso | Campi obbligatori |
|---|---|---|---|
| 1 | `KIND_DEPOSIT` | Deposito (lock o trasferimento) | token, recipient, amount |
| 2 | `KIND_WITHDRAW` | Prelievo | token, recipient, amount |
| 3 | `KIND_REGISTER_TOKEN` | Registrazione token supportato | token |
| 4 | `KIND_EMERGENCY` | Azione di emergenza | nessuno specifico |

---

## 3. L'hash canonico

    function hash(Decision memory d) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            d.kind, d.actor, d.token, d.recipient,
            d.amount, d.nonce, d.srcChainId, d.dstChainId,
            d.deadline, d.rationaleHash,
            d.fee, d.feeRecipient
        ));
    }

Questo hash è:
- **L'ID della decisione** nel `DecisionRegistry`
- **Il messaggio firmato** dai guardian
- **La chiave anti-replay** (`processedDecisions[id]` nei bridge)

**Cambiare i campi o l'ordine cambia l'hash e invalida tutte le firme esistenti.**

Verifica ricorrente:

    cast keccak $(cast abi-encode "f(uint8,address,address,address,uint256,uint256,uint256,uint256,uint64,bytes32,uint256,address)" \
      $KIND $ACTOR $TOKEN $RECIPIENT $AMOUNT $NONCE $SRC $DST $DEADLINE $RATIONALE $FEE $FEE_RECIPIENT)

deve restituire esattamente il `DID` emesso nell'evento `DecisionRecorded`.

---

## 4. `rationaleHash` — la spiegazione umana

`rationaleHash` lega ogni decisione a una spiegazione leggibile.

**Convenzione (v1.2):**

- Deposit: `keccak256(abi.encodePacked("deposit", actor, token, recipient, amount, nonce))`
- Withdraw: `keccak256(abi.encodePacked("withdraw", actor, token, recipient, amount, nonce))`

**Nessuna decisione senza `rationaleHash` diverso da zero.** Se non sai spiegare cosa stai firmando, non stai firmando.

---

## 5. Il ciclo di vita di una decisione

    1. PROPOSAL       Il bridge costruisce una Decision e chiama recordDecision(d).
    2. FIRMA          I guardian firmano l'id canonico (ETH personal_sign di id).
    3. VERIFICA       verifyDecision(d, sigs) controlla pausa, validità, deadline,
                      registrazione, veto, threshold, guardian attivi.
    4. ESECUZIONE     Il bridge trasferisce token e marca processedDecisions[id] = true.
    5. VETO           VETO_ROLE può vetare una decisione in qualsiasi momento.

---

## 6. Veto

**Chi ha `VETO_ROLE`:** deployer (Fase A) → Safe/DAO (Fase C).

**Il veto è irreversibile.** `verifyDecision` restituisce `false` anche con 5/5 firme valide.

---

## 7. Scadenze

**Regola dura: `deadline` diverso da zero.** Deadline di default: 1 ora dalla costruzione.

---

## 8. Threshold e firme

**Threshold:** 3 su 5 (configurabile dal governor).

Regole:
- Conta solo se `isActiveGuardian(signer)` al momento della verifica.
- Firme duplicate contano una volta.
- Firme da non-guardian sono ignorate.
- Firme in eccesso rispetto a threshold sono accettate.

### 8.1 Come si firma — regola operativa

**Il messaggio firmato è `id = DecisionLib.hash(d)`.**

**Con `cast`:**

    cast wallet sign --private-key <PK> $DID

**NON** usare `--no-hash` sull'eth-hash precalcolato. **NON** calcolare il prefisso a mano.

**Verifica:**

    cast wallet verify --address <ATTESO> $DID $FIRMA

Deve restituire `Validation succeeded`.

**Con ethers.js:**

    const id = computeDecisionHash(decision);
    const signature = await wallet.signMessage(ethers.getBytes(id));

---

## 9. Ruoli on-chain

| Ruolo | Dove | Chi lo ha | Cosa può fare |
|---|---|---|---|
| `GOVERNOR_ROLE` | GuardianRegistry, DecisionRegistry, Messenger, BridgeRoot, BridgeChild | Deployer (Fase A) → Timelock (Fase C) | Upgrade, cambio parametri, grant/revoke |
| `VETO_ROLE` | DecisionRegistry | Deployer (Fase A) → Safe (Fase C) | Vetare decisioni |
| `EMERGENCY_ROLE` | Messenger, BridgeRoot, BridgeChild, GuardianRegistry | Deployer (Fase A) → Safe (Fase C) | Solo pausa e deactivateGuardian |
| `DEFAULT_ADMIN_ROLE` | Tutti | Deployer (Fase A) → Timelock (Fase C) | Grant/revoke |

---

## 10. Cosa NON è nel canone

- Payload `bytes` opachi. Vietati.
- Decisioni senza `rationaleHash`. Vietate.
- Decisioni senza `deadline`. Vietate.
- Decisioni con `fee > amount * MAX_FEE_BPS / 10000`. Vietate (revertа).
- Firme su hash non canonici. Ignorate.
- Aggirare il DecisionRegistry. Vietato.

---

## 11. Versionamento

**Versione corrente: 1.2.**

Cambiamenti ammessi **senza bump:**
- Nuovi `kind` (con aggiornamento di `validate`)
- Commenti in `DecisionLib.sol`

Cambiamenti che **richiedono bump:**
- Aggiunta di un campo alla struct (in coda)
- Cambio di un vincolo in `validate`
- Cambio del formato di `rationaleHash`
- Cambio del valore di `MAX_FEE_BPS`

Cambiamenti **vietati:**
- Rimuovere un campo
- Cambiare l'ordine dei campi
- Cambiare la formula dell'hash

---

## 11.1 Prevalenza del VOIDS.md

L'interpretazione dei vuoti del canone segue `docs/VOIDS.md`.
Una modifica che non e' conforme al `VOIDS.md` non e' un'estensione
legittima: e' una **riscrittura**, e richiede un bump di versione
maggiore del canone.

In caso di conflitto interpretativo tra `CANON.md` e `VOIDS.md`,
prevale il `VOIDS.md` (P4 — Prevalenza).

La procedura di emendamento del `VOIDS.md` e' definita nel `VOIDS.md`
stesso (P5 — Falsificabilita', Clausola di Emendamento).

I vuoti mappati nel `VOIDS.md` sono:
- `kind` — il Sovrano
- `actor` — il Soggetto Giuridico
- `amount` — la Misura
- `rationaleHash` — il Testimone
- `fee` + `feeRecipient` — i Custodi del valore
- `deadline` — l'Orizzonte

---

## 12. Riferimenti

- `contracts/decisions/DecisionLib.sol` — definizione canonica
- `contracts/decisions/DecisionRegistry.sol` — registro e veto
- `contracts/bridge/ImperiumMessenger.sol` — verifica firme
- `contracts/bridge/ImperiumBridgeRoot.sol` — bridge lato L1
- `contracts/bridge/ImperiumBridgeChild.sol` — bridge lato L2
- `contracts/governance/GuardianRegistry.sol` — stake e ruoli guardian
- `test/decisions/DecisionCanon.t.sol` — 13 invarianti verificati
- `docs/COLLAUDO-2026-10-04.md` — collaudo end-to-end su anvil
- `docs/ROADMAP-v1.2.md` — piano fee e gas

---

## 13. Fee e gas

### Modello economico

| Scenario | Fee protocollo | Gas |
|---|---|---|
| Deposito diretto su Imperium Chain | **0** | IMP |
| Deposito via CEX → Imperium | **0** | IMP |
| Cross-chain (da ETH, TRX, BSC...) | **>0** (configurabile) | Entrambe |
| Fast/normal/slow | UX wallet | IMP |

### Regole hard-coded (immutabili)

- **`MAX_FEE_BPS = 100` (1%)** — tetto massimo alla fee, non superabile
  nemmeno dal governor.
- La fee è calcolata sul **lordo**: `fee = amount * feeBps / 10000`.
  L'utente manda `amount`, il bridge trattiene `fee`, l'utente riceve
  `amount - fee`.
- `DecisionLib.validate` verifica `fee <= amount * MAX_FEE_BPS / 10000`.

### Regola per kind

- Se `srcChainId == dstChainId` (deposito diretto):
  - `fee == 0`
  - `feeRecipient == address(0)`
- Se `srcChainId != dstChainId` (cross-chain):
  - se `fee > 0` → `feeRecipient != address(0)`
  - se `fee == 0` → `feeRecipient == address(0)`
  - `fee <= amount * MAX_FEE_BPS / 10000`

### Gas in IMP

Il gas si paga in IMP sulla chain Imperium. **Fuori dal canone:** gestito
dal wallet/client, non dal protocollo.

### Fast/normal/slow

Scelta di UX del wallet, **non del protocollo**. Il contratto non decide
quanto gas pagare. L'utente sceglie via wallet.

---

**Fine del canone v1.2.**

Chi legge questo documento e il codice `DecisionLib.sol` deve poter capire, senza altre fonti, cosa è una decisione, come si firma, come si verifica, come si calcola la fee, e cosa la può fermare.
