# Deployment Procedure — SLE v1

> **Destinatari**: auditor, DevOps
> **Scopo**: come deployare SLE in modo riproducibile e verificabile

---

## 1. Prerequisiti

| Requisito | Versione minima |
|---|---|
| Foundry (forge, cast) | ultima stabile |
| Bash | 4.0+ |
| jq | 1.6+ |
| RPC endpoint | qualsiasi EVM-compatible |
| Chiave deployer | con fondi per gas |

---

## 2. File di deploy

| File | Scopo |
|---|---|
| `script/DeploySLE.s.sol` | Script Foundry (deploy + verifica) |
| `deploy-sle.sh` | Orchestratore bash (dry-run/broadcast) |
| `.env.anvil` / `.env.testnet` | Variabili d'ambiente |

---

## 3. Ordine di deploy (12 contratti)

Lo script segue quest'ordine **non modificabile** (dipendenze):

| # | Contratto | Dipende da |
|---|---|---|
| 1 | SLEAddressProvider | — |
| 2 | PoolRegistry | — |
| 3 | ConstantProductCurve | — |
| 4 | RegimeDetector | — |
| 5a | CalmStrategy | — |
| 5b | VolatileStrategy | — |
| 5c | CriticalStrategy | — |
| 6 | StrategySelector | RegimeDetector |
| 7 | PoolManager | PoolRegistry, SLEAddressProvider |
| 8 | T2TRouter | SLEAddressProvider, StrategySelector, PoolRegistry |
| 9 | (config) | Registra 3 strategie nel Selector |
| 10 | (config) | Whitelist curva nel Registry |
| 11 | (config) | setEndpoints(router, pm) — **one-shot** |
| 12 | (config) | Transfer ownership provider → admin |

**Perché quest'ordine**: SLEAddressProvider rompe il ciclo Router↔PM. Va deployato per primo. I contratti senza dipendenze (registry, curve, detector, strategie) vengono dopo. Poi Selector (dipende da detector). Poi PM (dipende da provider). Infine Router (dipende da provider + selector + registry).

---

## 4. Procedura dry-run

```bash
# 1. Verifica connessione
cast block-number --rpc-url $RPC_URL

# 2. Carica env
source .env.<network>

# 3. Dry-run (no broadcast, nessun gas speso)
./deploy-sle.sh dry-run $RPC_URL
Output atteso:

text
=== SLE v1 Deploy ===
1. SLEAddressProvider: 0x...
2. PoolRegistry:       0x...
...
12. Provider ownership -> admin: 0x...
=== VERIFICA INCROCIATA ===
OK: provider.isConfigured() == true
OK: provider.router() == router
OK: provider.poolManager() == poolManager
OK: pm.router() == router
OK: router.provider() == provider
OK: router.selector() == selector
OK: router.registry() == registry
OK: provider.owner() == admin
=== DEPLOY COMPLETE ===
Gas stimato: ~6.5M (~0.013 ETH su Anvil).

5. Procedura broadcast (deploy reale)
bash
# 1. Verifica di essere sul network giusto
cast chain-id --rpc-url $RPC_URL
# Atteso: 9818 (Anvil), 332 (Testnet), 333 (Mainnet)

# 2. Verifica il deployer
cast balance $DEPLOYER --rpc-url $RPC_URL

# 3. Broadcast
./deploy-sle.sh broadcast $RPC_URL

# 4. Conferma
# (chiede "yes" per confermare spesa gas)
Output atteso:

text
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Transactions saved to: broadcast/DeploySLE.s.sol/<chainid>/run-latest.json
───── Salvataggio indirizzi in deployments/<chainid>.json ─────
{...}
───── Verifica incrociata post-deploy ─────
✅ Verifica incrociata OK
6. Verifica post-deploy
Dopo il broadcast, eseguire i seguenti check (script automatico in deploy-sle.sh):

Check	Comando
Provider configurato	cast call $PROVIDER 'isConfigured()(bool)'
Provider.router == Router	cast call $PROVIDER 'router()(address)'
Provider.poolManager == PM	cast call $PROVIDER 'poolManager()(address)'
PM.router == Router	cast call $PM 'router()(address)'
PM.provider == Provider	cast call $PM 'providerAddress()(address)'
Router.provider == Provider	cast call $ROUTER 'provider()(address)'
Router.selector == Selector	cast call $ROUTER 'selector()(address)'
Router.registry == Registry	cast call $ROUTER 'registry()(address)'
Selector strategies registrate	cast call $SELECTOR 'strategies(uint8)(address)' 0/1/4
PM.MAX_FEE == 200	cast call $PM 'MAX_FEE()(uint256)'
Se anche un solo check fallisce, il deploy NON è valido.

7. Verifica indirizzi (case sensitivity)
⚠️ Attenzione: jq restituisce address in lowercase, cast call in checksum (mixed case). I due sono equivalenti.

Per confrontare:

bash
# Normalizza entrambi a lowercase
ACTUAL=$(cast call $PROVIDER 'router()(address)' --rpc-url $RPC | tr '[:upper:]' '[:lower:]')
EXPECTED=$(jq -r '.T2TRouter' deployments/<chainid>.json | tr '[:upper:]' '[:lower:]')
[ "$ACTUAL" = "$EXPECTED" ] && echo "OK" || echo "MISMATCH"
8. Salvataggio e versionamento
Dopo il deploy:

File	Cosa contiene	Versionato?
deployments/<chainid>.json	Indirizzi contratti	✅ Sì
broadcast/DeploySLE.s.sol/<chainid>/run-latest.json	Trace completo	✅ Sì
cache/DeploySLE.s.sol/<chainid>/run-latest.json	Sensitive values	❌ No (gitignored)
9. Rollback
Non è possibile rollback. Il deploy è atomico ma non reversibile:

Se un contratto è sbagliato, va deployato un nuovo stack

I vecchi contratti restano on-chain (immutabili)

La migrazione richiede un nuovo deployments/<chainid>.json

Per testnet/Anvil: si può resettare la chain e rideployare.
Per mainnet: serve una procedura di migrazione esplicita (v2).

10. Deploy multi-rete
Rete	Chain ID	RPC	Env file
Anvil	9818	http://localhost:8545	.env.anvil
Testnet 332	332	http://localhost:30334	.env.testnet
Mainnet 333	333	http://localhost:30335	.env.mainnet (da creare)
Mainnet 333: NON deployare fino a:

Audit esterno completato

Testnet 332 stabile per 30 giorni

Bug bounty attivo

11. Script completo
bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-dry-run}"
RPC_URL="${2:-http://localhost:8545}"
ENV_FILE="${ENV_FILE:-.env.anvil}"

source "$ENV_FILE"
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")

if [ "$MODE" = "dry-run" ]; then
    forge script script/DeploySLE.s.sol:DeploySLE \
        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -vvv
else
    forge script script/DeploySLE.s.sol:DeploySLE \
        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -vvv
fi

# Estrai indirizzi
mkdir -p deployments
jq '.transactions | map(select(.transactionType == "CREATE")) | map({contractName, contractAddress}) | map({(.contractName): .contractAddress}) | add' \
   "broadcast/DeploySLE.s.sol/$CHAIN_ID/run-latest.json" > "deployments/$CHAIN_ID.json"
12. Checklist deploy
Prima di ogni deploy, verificare:

□ forge build è verde
□ forge test è verde (165 test)
□ forge test --match-path "test/sle/PoolManagerInvariant.t.sol" è verde (7 invarianti)
□ RPC risponde (cast block-number)
□ Deployer ha fondi sufficienti
□ Env file è corretto per la rete
□ Chain ID corrisponde all'env
□ Dry-run completato senza errori
□ Verifica incrociata post-deploy verde
□ deployments/<chainid>.json salvato e committato
Solo dopo tutti i check: procedere al broadcast.

Documento vivo. Ultimo aggiornamento: 2026-10-18.
