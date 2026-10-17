# Deploy — Twotrader Chain

## Prerequisiti

| Contratto | Deve essere deployato | Note |
|---|---|---|
| `TwotraderPoolManager` (UUPS) | Si | Singleton V4 |
| `GuardianRegistry` (UUPS) | Si | Set di firma per il bridge |
| `OWNER` (multisig DAO) | Si | Governor on-chain |

## Setup

1. Crea un file `.env` nella root del progetto (copia da `.env.example` se esiste).
2. Compila `.env` con i tuoi valori. Non condividere mai `.env`.
3. Verifica che `.env` sia in `.gitignore`: `grep '^\.env' .gitignore`
4. Verifica che `.env` non sia tracciato da git: `git ls-files | grep '^\.env'` (deve restituire vuoto).

## Variabili d'ambiente attese

Lette dagli script, presenti in `.env` o esportate nella shell:

| Variabile | Uso |
|---|---|
| `DEPLOYER` | Indirizzo pubblico del deployer |
| `RPC_URL` | Endpoint RPC della chain di destinazione |
| `POOL_MANAGER` | Indirizzo del proxy TwotraderPoolManager |
| `GUARDIAN_REGISTRY` | Indirizzo del proxy GuardianRegistry |
| `OWNER` | Indirizzo del multisig DAO |

La chiave del deployer si passa allo script via `--private-key`, `--ledger`
o `--trezor`. Mai via file di configurazione committabile.

## Deploy

### Fase A — Beta su anvil

    forge script script/DeployBeta.s.sol \
      --rpc-url http://127.0.0.1:8545 \
      --private-key $PK \
      --broadcast

### Deploy su testnet Twotrader

    forge script script/DeployTestnet.s.sol \
      --rpc-url $RPC_URL \
      --private-key $PK \
      --broadcast

### Deploy su mainnet (futuro)

    forge script script/DeployMainnet.s.sol \
      --rpc-url $RPC_URL \
      --private-key $PK \
      --broadcast

## Verifica post-deploy

Dopo ogni deploy, verifica i ruoli:

    cast call $CONTRACT "hasRole(bytes32,address)(bool)" \
      $(cast keccak "GOVERNOR_ROLE") $DEPLOYER \
      --rpc-url $RPC_URL

## Riferimenti

- `docs/CANON.md` — il canone delle decisioni
- `docs/ROADMAP-v1.2.md` — roadmap fee e gas
- `docs/COLLAUDO-2026-10-04.md` — collaudo end-to-end
