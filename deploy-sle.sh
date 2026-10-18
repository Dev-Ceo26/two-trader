#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  T2T SLE v1 — Deploy orchestrator
#  Uso: ./deploy-sle.sh [dry-run|broadcast] [rpc_url]
#  Default: dry-run su http://localhost:8545
# ═══════════════════════════════════════════════════════════
set -euo pipefail

MODE="${1:-dry-run}"
RPC_URL="${2:-http://localhost:8545}"
ENV_FILE="${ENV_FILE:-.env.anvil}"
DEPLOY_DIR="deployments"
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "unknown")

echo "═══════════════════════════════════════════════════════════"
echo "  T2T SLE v1 Deploy"
echo "  Mode:     $MODE"
echo "  RPC:      $RPC_URL"
echo "  Chain ID: $CHAIN_ID"
echo "  Env:      $ENV_FILE"
echo "═══════════════════════════════════════════════════════════"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: env file $ENV_FILE not found"
    exit 1
fi

# ─── Verifica connessione RPC ───
if ! cast block-number --rpc-url "$RPC_URL" > /dev/null 2>&1; then
    echo "ERROR: cannot connect to RPC $RPC_URL"
    exit 1
fi
echo "RPC OK (block: $(cast block-number --rpc-url "$RPC_URL"))"
echo ""

# ─── Carica variabili d'ambiente nella shell ───
# set -a esporta automaticamente tutte le variabili lette
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Verifica che DEPLOYER sia stato caricato
if [ -z "${DEPLOYER:-}" ]; then
    echo "ERROR: DEPLOYER not set after sourcing $ENV_FILE"
    exit 1
fi
echo "DEPLOYER: $DEPLOYER"

# Normalizza PK -> PRIVATE_KEY (Foundry si aspetta PRIVATE_KEY o --private-key)
if [ -n "${PK:-}" ] && [ -z "${PRIVATE_KEY:-}" ]; then
    export PRIVATE_KEY="$PK"
fi

# ─── Dry-run ───
if [ "$MODE" = "dry-run" ]; then
    echo "───── DRY RUN (no broadcast) ─────"
    forge script script/DeploySLE.s.sol:DeploySLE \
        --rpc-url "$RPC_URL" \
        ${PRIVATE_KEY:+--private-key "$PRIVATE_KEY"} \
        -vvv 2>&1 | tee /tmp/sle-deploy-dryrun.log
    echo ""
    echo "Dry-run complete. Log: /tmp/sle-deploy-dryrun.log"
    echo "Per deployare: ./deploy-sle.sh broadcast $RPC_URL"
    exit 0
fi

# ─── Broadcast ───
if [ "$MODE" != "broadcast" ]; then
    echo "ERROR: mode must be 'dry-run' or 'broadcast' (got: $MODE)"
    exit 1
fi

echo "───── BROADCAST (deploy reale) ─────"
echo "⚠️  Verra' speso gas reale. Confermi? (yes/no)"
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# ─── Deploy ───
forge script script/DeploySLE.s.sol:DeploySLE \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    -vvv 2>&1 | tee /tmp/sle-deploy-broadcast.log

# ─── Estrai indirizzi dal broadcast ───
BROADCAST_FILE="broadcast/DeploySLE.s.sol/$CHAIN_ID/run-latest.json"
if [ ! -f "$BROADCAST_FILE" ]; then
    echo "ERROR: broadcast file not found: $BROADCAST_FILE"
    exit 1
fi

mkdir -p "$DEPLOY_DIR"
OUT_FILE="$DEPLOY_DIR/$CHAIN_ID.json"

echo ""
echo "───── Salvataggio indirizzi in $OUT_FILE ─────"

jq '
  .transactions
  | map(select(.transactionType == "CREATE"))
  | map({contractName: .contractName, contractAddress: .contractAddress})
  | map({(.contractName): .contractAddress})
  | add
' "$BROADCAST_FILE" > "$OUT_FILE"

cat "$OUT_FILE"

# ─── Verifica incrociata ───
echo ""
echo "───── Verifica incrociata post-deploy ─────"
PROVIDER=$(jq -r '.SLEAddressProvider' "$OUT_FILE")
PM=$(jq -r '.PoolManager' "$OUT_FILE")
ROUTER=$(jq -r '.T2TRouter' "$OUT_FILE")

echo "provider.router()       = $(cast call $PROVIDER 'router()(address)' --rpc-url "$RPC_URL")"
echo "provider.poolManager()  = $(cast call $PROVIDER 'poolManager()(address)' --rpc-url "$RPC_URL")"
echo "pm.router()             = $(cast call $PM 'router()(address)' --rpc-url "$RPC_URL")"

echo ""
echo "Expected:"
echo "  router        = $ROUTER"
echo "  poolManager   = $PM"

ACTUAL_PROVIDER_ROUTER=$(cast call $PROVIDER 'router()(address)' --rpc-url "$RPC_URL" | tr '[:upper:]' '[:lower:]')
ACTUAL_PROVIDER_PM=$(cast call $PROVIDER 'poolManager()(address)' --rpc-url "$RPC_URL" | tr '[:upper:]' '[:lower:]')
ACTUAL_PM_ROUTER=$(cast call $PM 'router()(address)' --rpc-url "$RPC_URL" | tr '[:upper:]' '[:lower:]')

if [ "$ACTUAL_PROVIDER_ROUTER" != "$ROUTER" ]; then
    echo "❌ MISMATCH: provider.router ($ACTUAL_PROVIDER_ROUTER) != expected router ($ROUTER)"
    exit 1
fi
if [ "$ACTUAL_PROVIDER_PM" != "$PM" ]; then
    echo "❌ MISMATCH: provider.poolManager ($ACTUAL_PROVIDER_PM) != expected pm ($PM)"
    exit 1
fi
if [ "$ACTUAL_PM_ROUTER" != "$ROUTER" ]; then
    echo "❌ MISMATCH: pm.router ($ACTUAL_PM_ROUTER) != expected router ($ROUTER)"
    exit 1
fi

echo "✅ Verifica incrociata OK"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  DEPLOY COMPLETE"
echo "  Indirizzi: $OUT_FILE"
echo "═══════════════════════════════════════════════════════════"
