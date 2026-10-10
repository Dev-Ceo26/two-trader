# VOIDS.md — Genealogia dei Vuoti del Canone

> Versione: 1.0 (beta)
> Data: 2026-10-10
> Canone di riferimento: v1.2
> Autori: i progettisti originali del canone
> Stato: beta — il Quorum di Osservazione e' calibrato per la beta.
>        Prima del lancio pubblico, N deve essere rivisto (vedi P5).

---

## Preambolo

Questo documento non descrive l'architettura dei pieni. Quella e' nel
`CANON.md`. Questo documento descrive la filosofia dei vuoti: i campi
che esistono ma non sono completamente specificati, le cui forme sono
state scelte consapevolmente per accogliere un futuro che non era
ancora conoscibile.

Il `CANON.md` stabilisce la fisica. Il `VOIDS.md` spiega perche' quella
fisica ha quella forma. Senza genealogia, la fisica e' orfana. Senza
di essa, ogni generazione futura puo' dire: "il campo era vuoto, quindi
era progettato per accogliermi". E il vuoto, da solo, non puo'
contraddirla.

Questo documento e' un **patto**, non una prefazione. Chi eredita il
canone eredita anche questo documento. Ereditarlo significa:

- Rispettare la forma dei vuoti, non solo la loro larghezza.
- Dimostrare la derivabilita' di ogni estensione proposta.
- Continuare a scrivere questo documento, non solo a leggerlo.

---

## Principi ermeneutici

### P1 — Non-colonizzazione

Un vuoto e' una forma negativa con un perimetro. Chi lo abita deve
rispettare la forma. Chi viola il perimetro non estende: riscrive.

### P2 — Derivabilita'

Un'estensione e' legittima se deriva dalla conoscenza. "Conoscenza"
non e' opinione, non e' maggioranza, non e' consensus. E' cio' che
regge al mondo, come la mela che cade giu'.

### P3 — Umilta'

I vuoti esistono perche' il progettista non aveva la conoscenza per
riempirli. Questo documento e' un atto di onesta', non di onniscienza.
La genealogia e' un cantiere aperto, non un museo.

### P4 — Prevalenza

In caso di conflitto interpretativo tra `CANON.md` e `VOIDS.md`,
prevale il `VOIDS.md`. Perche' il canone e' la fisica, ma il `VOIDS.md`
e' la ragione per cui quella fisica e' stata scelta.

### P5 — Falsificabilita'

Un emendamento al `VOIDS.md` e' legittimo se e solo se la forma attuale
di un vuoto produce una contraddizione osservabile con la conoscenza.
"Contraddizione osservabile" significa: applicando la forma attuale a
un caso reale, il risultato contraddice cio' che sappiamo essere vero.

---

## Mappatura dei vuoti

### Campo 1 — kind

**Forma:** `uint8`
**Valori assegnati:** 1, 2, 3, 4
**Valori liberi:** 5–255 (251 valori)

**Intenzione originaria del vuoto:**
Ogni valore di `kind` e' un TIPO di decisione. Un tipo e' una classe
di azioni con semantica omogenea: stessa forma di validazione, stesso
schema di esecuzione, stessa classe di rischio. I valori 1–4 sono tipi
(DEPOSIT, WITHDRAW, REGISTER_TOKEN, EMERGENCY). I valori 5–255 sono
riservati a futuri TIPI. Non a sottotipi. Non a metadati. Non a stato.
Non a routing. Non a versioning.

La scelta di `uint8` e non di `enum` e' deliberata: `enum` avrebbe
richiuso il canone a 4 valori, dichiarando che non ci sarebbe stato
altro. `uint8` dichiara che ci sara' altro — ma che quel "altro" ha
la stessa forma dei primi quattro. Tipi, non usi.

**Confine del vuoto:**
Se il sistema arriva a 200 valori assegnati, il modello mentale e'
fallito. Un canone con 200 tipi non e' un canone: e' un elenco. Se ci
arrivi, fermati. Non aggiungere il 201°. Smonta e ricomincia il modello.

**Maledizione del vuoto:**
- Vietato usare `kind` per codificare sottocategorie. `kind = 100` non
  significa "deposit speciale". Se serve un "deposit speciale", e' un
  tipo nuovo (kind = 5), con propria validazione e propria semantica.
- Vietato usare `kind` come canale secondario. `kind = 200` non
  trasporta hash, stato utente, metadati di governance.

---

### Campo 2 — actor

**Forma:** `address`
**Valori assegnati:** Indirizzi crittografici validi (EOA o Smart Contract)
**Valori liberi:** Qualsiasi address, incluso 0x0 in scenari specifici non operativi

**Intenzione originaria del vuoto:**
`actor` e' il Soggetto Giuridico della Decisione. Risponde a:
"A chi appartiene la volonta' espressa in questo codice?".

Il canone v1.2 associa `actor` a `msg.sender`. Ma questa e' una
contingenza esecutiva. L'intenzione originaria e' che `actor` sia il
titolare del diritto e del rischio: l'entita' dal cui bilancio esce
`amount` e la cui firma convalida il `rationaleHash`.

**Confine del vuoto:**
Se l'infrastruttura evolve verso relayer-based, cross-chain o Account
Abstraction (ERC-4337), `actor` DEVE continuare a rappresentare l'utente
finale. Il `msg.sender` del contratto (relayer, paymaster) e' dato
infrastrutturale, non sovrascrive mai `actor`.

L'unica variazione ammessa: da persona fisica (EOA) a persona giuridica
(Smart Contract / Multisig), a patto che il possesso dei fondi rimanga
invariato.

**Maledizione del vuoto:**
- Vietato inserire l'address del relayer o del bridge in `actor` per
  "comodita' di routing". Se lo fai, il canone diventa cieco sull'utente.
- `actor` e' chi agisce, non chi riceve. Se serve un beneficiario
  diverso, si usa un campo dedicato, non si inverte `actor`.
- Vietato usare address speciali come flag di stato. `actor` non e'
  una macchina a stati.

---

### Campo 5 — amount

**Forma:** `uint256`
**Valori assegnati:** Importi lordi per kind 1 e 2; non applicabile per kind 3 e 4
**Valori liberi:** Tutti i valori >= 0, ma il significato e' vincolato

**Intenzione originaria del vuoto:**
`amount` e' l'importo **lordo**. Quello che l'utente vede, firma, paga.
La fee non e' mai sottratta a monte. Se `amount = 100`, l'utente sposta
100 unita' del token. La fee viene detratta a valle, come conseguenza.

Il vuoto e' l'unita' di misura. `uint256` non dice se sono wei, token,
micro-unita' o centesimi. Il significato sta nel `decimals()` del token
puntato dal campo `token`. `amount` e' auto-verificabile solo in
presenza di `token`.

**Confine del vuoto:**
`amount` e' in unita' **minime** del token. "100 mUSDC" non esiste nel
canone: esiste `100000000` con `token = mUSDC`.

**Maledizione del vuoto:**
- Vietato usare `amount` come canale secondario: `amount = X` con X che
  codifica una scala (1=piccolo, 100=grande) e' colonizzazione.
- `amount` non e' una fee. La fee e' `fee`.
- `amount` non e' slippage, rate, tolleranza.
- `amount = 0` e' legittimo **solo** per kind 3 e 4.

**Accoppiamento con `fee`:**
`amount` e' lordo, `fee` e' detratto, `amount - fee` e' cio' che l'utente
riceve. Chi propone "`amount` e' netto, `fee` si aggiunge sopra" sta
proponendo un modello economico diverso, non un'estensione.

---

### Campo 6 — rationaleHash

**Forma:** `bytes32`
**Valori assegnati:** Hash crittografici (Keccak-256)
**Valori liberi:** Qualsiasi sequenza di 32 byte diversa da zero

**Intenzione originaria del vuoto:**
E' il cordone ombelicale tra la matematica del canone e la ragione
umana. Per la macchina sono bit. Per il modello, DEVE puntare a
un'attestazione umana, immutabile, verificabile. L'hash non e' li'
per risparmiare spazio: e' li' per ancorare una responsabilita'.

**Confine del vuoto:**
L'hash risolve UNICAMENTE in un documento di testo leggibile da un
essere umano (Markdown su IPFS, testo firmato, PDF) che spieghi *il
perche'* della decisione. Il vuoto accetta qualsiasi protocollo di
storage (IPFS, Arweave, Swarm) a patto che l'output sia decifrabile
da un uomo.

**Maledizione del vuoto:**
Vietato usare `rationaleHash` per scopi computazionali:
- L'hash di un binario o software da eseguire.
- L'hash di uno stato di sistema o database.
- Un salt crittografico o nonce.

Se l'hash punta a un blob binario incomprensibile, la decisione e'
"firmata a vuoto". Senza la parola umana dietro l'hash, la fisica del
codice diventa dittatura cieca.

---

### Campi 11 e 12 — fee + feeRecipient (introdotti in v1.2)

**Forma:** `fee` (uint256), `feeRecipient` (address)
**Valori assegnati:** Valori accoppiati (entrambi > 0 o entrambi = 0)
**Valori liberi:** Configurazioni asimmetriche (proibite)

**Intenzione originaria del vuoto:**
Sono nati gemelli siamesi in v1.2. Il vuoto e' lo spazio logico
relazionale tra i due: legare indissolubilmente l'onere economico al
suo beneficiario. Il silenzio del codice su cosa fare in caso di
disallineamento non e' svista: e' divieto implicito.

**Confine del vuoto:**
L'unica evoluzione ammessa e' la variazione simmetrica: cambiare
l'intensita' della fee o l'address del beneficiario. Se fee = 0,
recipient = address(0). Niente altro.

**Maledizione del vuoto:**
- `fee > 0` con `feeRecipient = 0x0`: non e' "bruciare" i token. Se
  serve burn, si crea un kind apposito o si punta a un address di burn
  esplicito.
- `fee = 0` con `feeRecipient != 0x0`: non e' "routing" o "tagging".
  Chi usa il recipient come referrer sta profanando l'architettura.

Separare i due campi o usarli asimmetricamente e' riscrittura
mascherata.

---

### Campo 9 — deadline

**Forma:** `uint64`
**Valori assegnati:** Timestamp Unix in secondi
**Valori liberi:** Qualsiasi intero a 64 bit, incluso 0

**Intenzione originaria del vuoto:**
E' l'orizzonte degli eventi della decisione. La scelta di `uint64`
dichiara l'unita' di misura: Timestamp Unix (secondi dal 1970). Non
block number, che variano da chain a chain. Il tempo del canone e' il
tempo degli orologi umani.

Il grande vuoto progettato e' `deadline = 0`. Nel silenzio del codice,
lo zero non e' assenza di dato: e' dichiarazione di eternita'.

**Confine del vuoto:**
- `deadline > 0`: la decisione ha scadenza. Oltre, la fisica rifiuta.
- `deadline = 0`: "senza scadenza". Firma perpetua, valida finche' il
  canone esiste. Potere immenso, concesso per decisioni di governance
  o setup iniziali che non devono temere il tempo.

**Maledizione del vuoto:**
- Vietato rilassare il controllo per accettare block number. Se domani
  `1000000` viene interpretato come blocco anziche' timestamp, la linea
  temporale del canone e' violata.
- Vietato usare `deadline = 0` come flag per "esegui immediatamente in
  emergenza". Lo zero significa eternita' della validita', non urgenza
  dell'esecuzione.
- Vietato usare i bit superiori di `uint64` per contatori o ID.

---

## Clausola di Emendamento (P5 — Falsificabilita')

Il `VOIDS.md` non e' immutabile. Ma non e' nemmeno emendabile per
volonta'. E' emendabile per **contraddizione**.

### Quorum di Osservazione

Un emendamento e' ammesso solo se un osservatore indipendente
conferma la contraddizione sul piano empirico. L'osservatore non
esprime un parere ("voto"): certifica la **ripetibilita' scientifica**
della contraddizione. Se la contraddizione non e' riproducibile da
terzi nel mondo reale, la proposta decade come rumore.

**N per la beta: 1 + 1.**
- 1 = il proponente.
- 1 = l'osservatore indipendente.
- Se l'osservatore conferma -> l'emendamento entra in vigore.
- Se l'osservatore non conferma -> l'emendamento e' vetato.

**Nota per il futuro:** N = 2 e' calibrato per una community piccola
(beta). Prima del lancio pubblico, N deve essere rivisto (proposta
minima: 5 osservatori indipendenti). N=2 e' troppo basso per un
sistema maturo, perche' un singolo osservatore puo' emendare qualsiasi
cosa.

### Procedura

1. **Proposta.** Chiunque puo' proporre un emendamento. Deve contenere:
   - La voce del `VOIDS.md` che intende modificare.
   - Il caso reale in cui la forma attuale produce contraddizione.
   - La nuova forma proposta.
   - La dimostrazione che la nuova forma risolve la contraddizione
     senza introdurne di nuove.

2. **Conferma dell'osservatore.** Un osservatore indipendente applica
   la forma attuale al caso reale proposto. Se vede la stessa
   contraddizione, conferma. Se non la vede, veto.

3. **Entrata in vigore provvisoria.** L'emendamento entra in vigore
   immediatamente, marcato come **provvisorio**. Il canone lo accetta.
   Ma la voce originale resta nel registro, non cancellata.

4. **Verifica empirica.** Nei mesi successivi, l'emendamento viene
   applicato. Se regge all'uso, diventa **definitivo**. Se produce
   una nuova contraddizione, decade.

5. **Registro.** Ogni emendamento e' registrato in
   `docs/VOIDS-REGISTRY.md` con: data, autore, osservatore, voce
   modificata, contraddizione osservata, esito.

### Autoreferenzialita'

Questa procedura e' essa stessa soggetta al `VOIDS.md`. Un emendamento
alla procedura di emendamento segue la procedura stessa. Non esiste
un "fuori" dalla procedura.

---

## Come si eredita

Chi propone una modifica al canone deve:

1. Identificare quale vuoto intende riempire.
2. Citare la voce corrispondente del `VOIDS.md`.
3. Dimostrare che la modifica e' conforme alla forma del vuoto (P1)
   e derivabile dalla conoscenza (P2).
4. Se la modifica non e' conforme, dichiararla esplicitamente come
   **riscrittura**, non come estensione. Una riscrittura richiede un
   bump di versione maggiore del canone e una nuova voce del
   `VOIDS.md` che spieghi perche' la vecchia forma era insufficiente.

---

**La mela cade giu'. Anche quando nessuno guarda.**
