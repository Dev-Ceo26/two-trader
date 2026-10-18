# Collaudo canone v1.2 — Testnet Twotrader (2026-10-10)

Primo collaudo end-to-end del canone v1.2 sulla **testnet pubblica** Twotrader
(chainId 9818). Non su anvil, su chain reale.

---

## Setup

### Contratti del canone

| Contratto | Indirizzo |
|---|---|
| GuardianRegistry | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 |
| DecisionRegistry | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e |
| TwotraderMessenger | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 |
| TwotraderBridgeRoot | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c |
| TwotraderBridgeChild | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 |
| MockToken (mUSDC-b, 6 dec) | 0xFCDE586a3f72d535902E8197AE3effeb4a3E9171 |

### Guardian registrati (3/3)

| Guardian | Address | Stake |
|---|---|---|
| G1 (deployer) | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 1000 T2T |
| G2 | 0x10872E0e2eCC9883CDCbecD74C8e6eb856c31C72 | 1000 T2T |
| G3 | 0x1E48B5f4a711288fD7456Fbfa94C6F76E4bC9d87 | 1000 T2T |

### Configurazione

- Threshold: 3
- Fee BPS: 10 (0.1%)
- Fee recipient: deployer

---

## Ciclo depositCrossChain → firme → finalizeDeposit

### 1. DepositCrossChain (block 194640)

cast send 
B
R
O
O
T
"
d
e
p
o
s
i
t
C
r
o
s
s
C
h
a
i
n
(
a
d
d
r
e
s
s
,
a
d
d
r
e
s
s
,
u
i
n
t
256
,
u
i
n
t
256
)
"
 
BROOT"depositCrossChain(address,address,uint256,uint256)" TOKEN 
D
E
P
L
O
Y
E
R
10000000011155111
 
−
−
r
p
c
−
u
r
l
DEPLOYER10000000011155111 −−rpc−urlRPC_URL --private-key $PRIVATE_KEY

text

**Decision emessa:**

- id: 0xf61497b1040fc30cff667e4702783a265b815d89da88493e75b0648f2d761c60
- kind: 1 (DEPOSIT)
- actor: 0x8d2eD8c0...
- token: 0xFCDE586a...
- recipient: 0x8d2eD8c0...
- amount: 100000000 (100 mUSDC lordo)
- nonce: 1
- srcChainId: 11155111 (Sepolia)
- dstChainId: 9818 (Twotrader)
- deadline: 1791647734
- rationaleHash: 0x07a9b763...
- fee: 100000 (0.1 mUSDC)
- feeRecipient: 0x8d2eD8c0...

### 2. Verifica hash canonico

- DID (dal log):   0xf61497b1040fc30cff667e4702783a265b815d89da88493e75b0648f2d761c60
- DID (calcolato): 0xf61497b1040fc30cff667e4702783a265b815d89da88493e75b0648f2d761c60

**Coincidono.** Formula hash corretta.

### 3. Firma con 3 guardian

Tre firme su `$DID` con PK di G1, G2, G3.

**Verifica `verifyDecision`:** `true` ✅

### 4. FinalizeDeposit sul BCHILD (block 194662)

**Eventi emessi:**

- Transfer(BCHILD → deployer, 99900000) — net
- Transfer(BCHILD → deployer, 100000) — fee
- DepositFinalized(deployer, TOKEN, 100000000, nonce=1, decisionId)

### 5. Saldi finali

| Account | Prima | Dopo | Delta |
|---|---|---|---|
| Deployer | 900000000 | 1000000000 | +100000000 |
| BCHILD | 1000000000 | 900000000 | -100000000 |
| BROOT | 100000000 | 100000000 | 0 |

**Coerenti.** Il deployer ha depositato 100 mUSDC al root (bloccati nel bridge),
e ha ricevuto 99.9 mUSDC (net) + 0.1 mUSDC (fee, perché feeRecipient = deployer)
dal child. Delta netto = 0 (ha depositato 100, ha ricevuto 100).

---

## Risultato

**Il canone v1.2 funziona end-to-end sulla testnet pubblica.**

- Decisione canonica registrata on-chain
- DID calcolato == DID on-chain
- Firme 3/3 valide
- `verifyDecision` = true
- `finalizeDeposit` eseguito
- Fee trasferita al feeRecipient
- Saldi coerenti

**Prossimo:**

1. Test del veto
2. Test del replay
3. Deploy del DEX
4. PromoteGovernance (Fase C)

## Lezione appresa

Il passaggio da anvil a testnet **non ha richiesto modifiche al codice**.
L'unico problema è stato il chainId duplicato (9818 per entrambi),
risolto cambiando anvil a 31337.

---

## Test edge case

### Replay — Verde

Tentativo di rieseguire la Decision gia' processata (`0xf61497b1...`):

cast send 
B
C
H
I
L
D
"
f
i
n
a
l
i
z
e
D
e
p
o
s
i
t
(
.
.
.
)
"
"
(
.
.
.
)
"
"
[
BCHILD"finalizeDeposit(...)""(...)""[OS1,
O
S
2
,
OS2,OS3]"

text

**Risultato:** `execution reverted: already processed`

Il campo `processedDecisions[decisionId]` impedisce la doppia esecuzione.

### Veto — Verde

Nuovo deposit (nonce 3, DID `0x951b03a8...`), firme 3/3, `verifyDecision = true`.

Poi veto dal deployer (VETO_ROLE):
cast send 
D
R
E
G
"
v
e
t
o
(
b
y
t
e
s
32
,
s
t
r
i
n
g
)
"
DREG"veto(bytes32,string)"DID2 "test veto su testnet"

text

- `isVetoed(did)` → `true`
- `verifyDecision(did, sigs)` → `false`

**Il veto blocca la decisione anche con 3/3 firme valide.**

---

## Riepilogo collaudo canone v1.2 su testnet

| Test | Risultato |
|---|---|
| Deposit cross-chain | ✅ |
| DID calcolato == DID on-chain | ✅ |
| Firme 3/3 | ✅ |
| verifyDecision (baseline) | ✅ true |
| finalizeDeposit | ✅ |
| Saldi coerenti | ✅ |
| Replay | ✅ revert |
| Veto | ✅ false |
| Fee trasferita | ✅ |

**Il canone v1.2 e' operativo sulla testnet pubblica.**
