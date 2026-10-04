# CANON — Imperium Decision Canon

> Versione: 1.0 (Beta, Fase A)
> Ultimo aggiornamento: 2026-10-04
> Contratto di riferimento: `contracts/decisions/DecisionLib.sol`

Questo documento definisce la **grammatica delle decisioni** che attraversano il bridge Imperium. Ogni decisione che ha effetto on-chain deve essere esprimibile come `DecisionLib.Decision`. Nessuna decisione opaca. Nessun `bytes32` sciolto. Nessuna firma su qualcosa che non sia nel canone.

---

## 1. La struct `Decision`

```solidity
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
}
Ordine dei campi è parte del canone. Cambiarlo invalida ogni firma esistente. Mai cambiare l'ordine. Mai rimuovere un campo. Solo aggiungere in coda, e solo con bump di versione esplicito.

Campo per campo
Campo	Tipo	Vincoli	Descrizione
kind	uint8	uno dei KIND_* sotto	Tipo di decisione
actor	address	≠ address(0)	Chi ha originato la decisione (msg.sender on-chain)
token	address	vedi kind	Token coinvolto (address(0) se non applicabile)
recipient	address	vedi kind	Destinatario (address(0) se non applicabile)
amount	uint256	vedi kind	Importo (0 se non applicabile)
nonce	uint256	unico per (actor, kind)	Anti-replay
srcChainId	uint256	≠ 0	Catena di origine
dstChainId	uint256	≠ 0	Catena di destinazione
deadline	uint64	≠ 0	Dopo questo timestamp, la firma è invalida
rationaleHash	bytes32	≠ 0	keccak256 di una spiegazione umana off-chain
2. I kind ammessi
Valore	Costante	Uso	Campi obbligatori
1	KIND_DEPOSIT	Lock su root, release su child	token, recipient, amount
2	KIND_WITHDRAW	Lock su child, release su root	token, recipient, amount
3	KIND_REGISTER_TOKEN	Registrazione token supportato	token
4	KIND_EMERGENCY	Azione di emergenza	nessuno specifico
Aggiungere un nuovo kind richiede:

Aggiungere la costante in DecisionLib.sol

Aggiungere i vincoli in DecisionLib.validate

Aggiornare questo documento

Aggiungere un test in test/decisions/

3. L'hash canonico
solidity
function hash(Decision memory d) internal pure returns (bytes32) {
    return keccak256(abi.encode(
        d.kind, d.actor, d.token, d.recipient,
        d.amount, d.nonce, d.srcChainId, d.dstChainId,
        d.deadline, d.rationaleHash
    ));
}
Questo hash è:

L'ID della decisione nel DecisionRegistry

Il messaggio firmato dai guardian (via toEthSignedMessageHash)

La chiave anti-replay (processedDecisions[id] nei bridge)

Cambiare i campi o l'ordine cambia l'hash e invalida tutte le firme esistenti.

4. rationaleHash — la spiegazione umana
rationaleHash è l'unico campo che non ha effetto diretto on-chain. È un hash. Ma è parte del canone perché lega ogni decisione a una spiegazione leggibile.

Convenzione (v1.0):

rationaleHash = keccak256(abi.encodePacked("deposit", actor, token, recipient, amount, nonce)) per deposit

rationaleHash = keccak256(abi.encodePacked("withdraw", actor, token, recipient, amount, nonce)) per withdraw

Questo è il minimo. In futuro, rationaleHash potrà puntare a un documento IPFS o a un URL versionato. La regola: chi firma deve poter verificare che l'hash corrisponda a una spiegazione che comprende.

Nessuna decisione senza rationaleHash ≠ 0. Se non sai spiegare cosa stai firmando, non stai firmando.

5. Il ciclo di vita di una decisione
text
1. PROPOSAL       Il bridge (o un attore autorizzato) costruisce una Decision
                  e chiama messenger.recordDecision(d).
                  → evento DecisionRecorded(id, d) nel DecisionRegistry

2. FIRMA          I guardian leggono l'evento, verificano rationaleHash,
                  e firmano l'hash canonico (id).
                  → firme fuori catena (ECDSA, eth_sign)

3. VERIFICA       Chiunque chiama messenger.verifyDecision(d, signatures).
                  Restituisce true se e solo se:
                  - messenger non in pausa
                  - DecisionLib.validate(d) == true
                  - !DecisionLib.isExpired(d, now)
                  - decisionRegistry.isRecorded(id) == true
                  - decisionRegistry.isVetoed(id) == false
                  - almeno threshold firme valide da guardian attivi distinti

4. ESECUZIONE     Il bridge chiama executeWithdrawal / finalizeDeposit.
                  → trasferimento token
                  → processedDecisions[id] = true (anti-replay)

5. VETO           In qualsiasi momento dopo la registrazione,
                  VETO_ROLE può chiamare decisionRegistry.veto(id, reason).
                  → la decisione non è più verificabile
                  → evento DecisionVetoed pubblico
6. Veto
Chi ha VETO_ROLE:

Fase A (attuale): il deployer

Fase C (futura): il Timelock del DAO, o un Safe dedicato

Il veto è irreversibile. Non esiste unveto. Una volta vetata, una decisione resta vetata per sempre.

Effetto del veto:

verifyDecision restituisce false anche con 5/5 firme valide

executeWithdrawal / finalizeDeposit reverta

Il token resta nel bridge

Conseguenza sui firmatari: chi ha firmato una decisione poi vetata ha firmato male. La politica di slashing (futura, non in questa versione) prevederà una penalità proporzionale allo stake. Per ora, il veto è un segnale pubblico: il firmatario è tracciato.

7. Scadenze
Regola dura: deadline ≠ 0. Ogni decisione ha una scadenza. Nessuna decisione eterna.

Deadline di default: 1 ora dalla costruzione (DEFAULT_DEADLINE = 1 hours).

Perché: una decisione senza scadenza è una firma in bianco. Se il contesto cambia (prezzo, saldo, altro), la firma vecchia resta valida per sempre. Inaccettabile.

Chi decide la deadline: il bridge, al momento della costruzione. Non l'utente. Non il guardian. Così è uniforme per kind.

Verifica: DecisionLib.isExpired(d, block.timestamp). Se now > deadline, la decisione è morta.

8. Threshold e firme
Threshold attuale: 3 su 5 (configurato in initialize del messenger, modificabile via setThreshold dal governor).

Regole di conteggio:

Una firma conta solo se il firmatario è registry.isActiveGuardian(signer) == true al momento della verifica

Firme duplicate (stesso firmatario) contano una sola volta

Firme da non-guardian sono ignorate (non invalidano il messaggio, semplicemente non contano)

Firme in eccesso rispetto a threshold sono accettate

Cosa significa in pratica: un guardian rimosso dopo aver firmato non conta più. Questo è intenzionale: se un guardian viene disattivato per comportamento scorretto, le sue firme passate non valgono più come peso attuale.

9. Ruoli on-chain
Ruolo	Dove	Chi lo ha	Cosa può fare
GOVERNOR_ROLE	GuardianRegistry, DecisionRegistry, Messenger, BridgeRoot, BridgeChild	Deployer (Fase A) → Timelock (Fase C)	Upgrade, cambio parametri, grant/revoke ruoli
VETO_ROLE	DecisionRegistry	Deployer (Fase A) → Safe dedicato (Fase C)	Vetare decisioni
EMERGENCY_ROLE	Messenger, BridgeRoot, BridgeChild	Deployer (Fase A) → Safe emergenza (Fase C)	Solo pausa, niente altro
DEFAULT_ADMIN_ROLE	Tutti	Deployer (Fase A) → Timelock (Fase C)	Grant/revoke degli altri ruoli
Principio: nessun ruolo è permanente. Tutti passano dal deployer (Fase A) al DAO o a Safe dedicati (Fase C) con transazioni pubbliche.

10. Cosa NON è nel canone
Esplicitamente fuori dal canone:

Payload bytes opachi. Vietati.

Decisioni senza rationaleHash. Vietate.

Decisioni senza deadline. Vietate.

Firme su hash non canonici. Ignorate.

verifySignatures(bytes32, bytes[]) — la vecchia API è stata rimossa.

Aggirare il DecisionRegistry per eseguire azioni del bridge. Vietato.

11. Versionamento
Versione corrente: 1.0.

Cambiamenti ammessi senza bump di versione:

Aggiunta di nuovi kind (con aggiornamento di validate e di questo documento)

Aggiunta di commenti in DecisionLib.sol

Cambiamenti che richiedono bump di versione:

Aggiunta di un campo alla struct (in coda)

Cambio di un vincolo in validate

Cambio del formato di rationaleHash

Cambiamenti vietati:

Rimuovere un campo

Cambiare l'ordine dei campi

Cambiare la formula dell'hash

12. Riferimenti
contracts/decisions/DecisionLib.sol — definizione canonica

contracts/decisions/DecisionRegistry.sol — registro e veto

contracts/bridge/ImperiumMessenger.sol — verifica firme

contracts/bridge/ImperiumBridgeRoot.sol — bridge lato L1

contracts/bridge/ImperiumBridgeChild.sol — bridge lato L2

test/decisions/DecisionCanon.t.sol — invarianti verificati

Fine del canone v1.0.

Chi legge questo documento e il codice DecisionLib.sol deve poter capire, senza altre fonti, cosa è una decisione, come si firma, come si verifica, e cosa la può fermare.
