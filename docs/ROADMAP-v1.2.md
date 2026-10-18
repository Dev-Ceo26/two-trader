# Roadmap Canone v1.2 — Fee e gas

## Modello economico (deciso 2026-10-04)

| Scenario | Fee protocollo | Gas |
|---|---|---|
| Deposito diretto su Twotrader Chain | **0** | T2T |
| Deposito via CEX → Twotrader | **0** | T2T |
| Cross-chain (da ETH, TRX, BSC...) | **>0** (configurabile) | Entrambe |
| Fast/normal/slow | UX wallet | T2T |

**Regola dura:**
- `srcChainId == dstChainId` → `fee == 0`, `feeRecipient == address(0)`
- `srcChainId != dstChainId` → `fee >= 0`, `feeRecipient != address(0)`

Il guardian firma sempre sapendo quanto va all'utente e quanto al protocollo.

---

## Sessione A — Canone v1.2 (2 ore)

### A.1 — `DecisionLib.Decision`

Aggiungi in coda (senza cambiare l'ordine dei campi esistenti):

    uint256 fee;             // 0 se deposito diretto, >0 se cross-chain
    address feeRecipient;    // 0x0 se fee=0

### A.2 — `DecisionLib.hash`

Aggiorna per includere i due nuovi campi in coda:

    keccak256(abi.encode(
        d.kind, d.actor, d.token, d.recipient,
        d.amount, d.nonce, d.srcChainId, d.dstChainId,
        d.deadline, d.rationaleHash,
        d.fee, d.feeRecipient   // NUOVI
    ))

### A.3 — `DecisionLib.validate`

Regole:

- Se `srcChainId == dstChainId`:
  - `fee == 0`
  - `feeRecipient == address(0)`
- Se `srcChainId != dstChainId`:
  - se `fee > 0` → `feeRecipient != address(0)`
  - se `fee == 0` → `feeRecipient == address(0)`

### A.4 — `docs/CANON.md` v1.2

Nuova sezione 13 "Fee e gas" con:
- Modello economico (tabella sopra)
- Regola "deposito diretto → fee 0"
- Regola "cross-chain → fee > 0, configurabile"
- Gas in T2T: fuori dal canone, gestito dal wallet
- Fast/normal/slow: UX del wallet, non del protocollo

### A.5 — Test Foundry

Aggiungi a `test/decisions/DecisionCanon.t.sol`:

- `test_DirectDepositMustHaveZeroFee`
- `test_CrossChainMustHaveFeeRecipientIfFee`
- `test_HashIncludesFeeAndFeeRecipient`

**Target: 12 invarianti verdi (9 attuali + 3 nuovi).**

---

## Sessione B — Bridge e deploy (1,5 ore)

### B.1 — `TwotraderBridgeRoot`

Aggiungi:

    uint256 public feeBps;           // es. 10 = 0.1%
    uint256 public constant MAX_FEE_BPS = 100; // 1% tetto hard-coded
    address public feeRecipient;

    function setFeeBps(uint256 newBps) external onlyRole(GOVERNOR_ROLE);
    function setFeeRecipient(address newRecipient) external onlyRole(GOVERNOR_ROLE);

Modifica `deposit`:

    // Deposito diretto (srcChainId == dstChainId)
    Decision {
        ...,
        fee: 0,
        feeRecipient: address(0)
    }

Aggiungi `depositCrossChain` (se serve in questa sessione):

    function depositCrossChain(address token, address recipient, uint256 amount, uint256 srcChainId) external {
        uint256 fee = (amount * feeBps) / 10000;
        require(fee <= (amount * MAX_FEE_BPS) / 10000, "fee too high");
        Decision {
            ...,
            fee: fee,
            feeRecipient: feeRecipient
        }
    }

### B.2 — `TwotraderBridgeChild.finalizeDeposit`

Modifica per gestire `fee`:

    uint256 netAmount = d.amount - d.fee;
    IERC20(localToken).safeTransfer(d.recipient, netAmount);
    if (d.fee > 0) {
        IERC20(localToken).safeTransfer(d.feeRecipient, d.fee);
    }

### B.3 — `script/DeployBeta.s.sol`

Aggiungi parametri:
- `FEE_BPS` (default: 10 = 0.1%)
- `FEE_RECIPIENT` (default: deployer)

### B.4 — Redeploy su anvil

`forge clean && forge build && forge script script/DeployBeta.s.sol --broadcast`

### B.5 — Test on-chain

- Deposito diretto (fee=0) → utente riceve esattamente `amount`
- Cross-chain simulato (fee>0) → utente riceve `amount - fee`, feeRecipient riceve `fee`

---

## Sessione C — Cross-chain completo (2 ore, opzionale)

- Bridge con relay/oracle esterno (LayerZero, Wormhole, o custom)
- Oppure: bridge "finto" per test (funzione `simulateCrossChain` solo in testnet)
- Fee doppie (L1 + L2)
- Test end-to-end cross-chain

**Da valutare in base alle esigenze. Non urgente.**

---

## Note

- Il canone v1.1 (attuale) è **funzionante e collaudato** per depositi diretti fee-less.
- Il canone v1.2 aggiunge il supporto fee senza rompere il caso base.
- Il bump di versione è **obbligatorio** perché cambia la formula dell'hash.
- Tutte le firme esistenti diventano invalide. In testnet, ok. In mainnet, mai.

---

**Roadmap scritta 2026-10-04. Prossima sessione: A.**
