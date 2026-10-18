#!/usr/bin/env bash
set -euo pipefail

cd ~/twotrader
source .env.testnet

echo "═══════════════════════════════════════════════════════════"
echo "  SLE v1 — E2E Test su Testnet 332"
echo "═══════════════════════════════════════════════════════════"

# Indirizzi
PROVIDER=$SLE_PROVIDER
REGISTRY=$SLE_REGISTRY
CURVE=$SLE_CURVE
DETECTOR=$SLE_DETECTOR
PM=$SLE_POOL_MANAGER
ROUTER=$SLE_ROUTER
T2T=$T2T_MOCK
USDC=$USDC_MOCK
RPC=$RPC_URL
PK=$PRIVATE_KEY
FROM=$DEPLOYER

echo "Deployer:    $FROM"
echo "T2T mock:    $T2T"
echo "USDC mock:   $USDC"
echo "Router:      $ROUTER"
echo "PoolManager: $PM"
echo ""

# 1. Mint token al deployer
echo "[1] Mint 10M T2T e 10M USDC al deployer"
cast send $T2T "mint(address,uint256)" $FROM 10000000000000000000000000 --rpc-url $RPC --private-key $PK > /dev/null
cast send $USDC "mint(address,uint256)" $FROM 10000000000000000000000000 --rpc-url $RPC --private-key $PK > /dev/null
echo "  ✅ Mint OK"

# 2. Approva Router
echo ""
echo "[2] Approva Router per entrambi i token"
MAX="115792089237316195423570985008687907853269984665640564039457584007913129639935"
cast send $T2T "approve(address,uint256)" $ROUTER $MAX --rpc-url $RPC --private-key $PK > /dev/null
cast send $USDC "approve(address,uint256)" $ROUTER $MAX --rpc-url $RPC --private-key $PK > /dev/null
echo "  ✅ Approve OK"

# 3. Ordina token
TOKEN0=$T2T
TOKEN1=$USDC
if [[ $(echo "$T2T $USDC" | awk '{print ($1 < $2)}') == "0" ]]; then
  TOKEN0=$USDC
  TOKEN1=$T2T
fi
echo ""
echo "[3] token0: $TOKEN0, token1: $TOKEN1"

# 4. Calcola poolId
POOL_ID=$(cast keccak $(cast abi-encode "f(address,address,address)" $TOKEN0 $TOKEN1 $CURVE))
echo "  poolId: $POOL_ID"

# 5. Registra pool
echo ""
echo "[5] Registra pool nel Registry"
cast send $REGISTRY "registerPool(bytes32,address,address,address)" \
  $POOL_ID $CURVE $TOKEN0 $TOKEN1 --rpc-url $RPC --private-key $PK > /dev/null
cast send $REGISTRY "activatePool(bytes32)" $POOL_ID --rpc-url $RPC --private-key $PK > /dev/null
echo "  ✅ Pool registrata + attivata"

# 6. Inizializza Detector
echo ""
echo "[6] Inizializza RegimeDetector (regime CALM)"
cast send $DETECTOR "update(bytes32,uint256,uint256,uint256)" \
  $POOL_ID 1000000000000000000000000 1000000000000000000000000 0 --rpc-url $RPC --private-key $PK > /dev/null
echo "  ✅ Detector inizializzato"

# 7. Add liquidity
echo ""
echo "[7] Add liquidity 1M / 1M"
cast send $ROUTER "addLiquidity(bytes32,uint256,uint256)" \
  $POOL_ID 1000000000000000000000000 1000000000000000000000000 \
  --rpc-url $RPC --private-key $PK > /dev/null

LP=$(cast call $PM "getLPBalance(bytes32,address)(uint256)" $POOL_ID $FROM --rpc-url $RPC)
echo "  ✅ LP deployer: $LP"

# 8. Swap
echo ""
echo "[8] Swap 1000 T2T -> USDC"
BAL_BEFORE=$(cast call $USDC "balanceOf(address)(uint256)" $FROM --rpc-url $RPC | awk '{print $1}')
DEADLINE=$(( $(date +%s) + 3600 ))

# zeroForOne: true se T2T == token0
ZERO_FOR_ONE="true"
if [ "$TOKEN0" != "$T2T" ]; then
  ZERO_FOR_ONE="false"
fi
echo "  zeroForOne: $ZERO_FOR_ONE"

cast send $ROUTER "swap(bytes32,bool,uint256,uint256,address,uint256)" \
  $POOL_ID $ZERO_FOR_ONE 1000000000000000000000 0 $FROM $DEADLINE \
  --rpc-url $RPC --private-key $PK > /dev/null

BAL_AFTER=$(cast call $USDC "balanceOf(address)(uint256)" $FROM --rpc-url $RPC | awk '{print $1}')
echo "  USDC before: $BAL_BEFORE"
echo "  USDC after:  $BAL_AFTER"

# 9. Verifica contabilità
echo ""
echo "[9] Verifica contabilità PM"
cast call $PM "getReserves(bytes32)(uint256,uint256)" $POOL_ID --rpc-url $RPC
cast call $PM "getFeesAccrued(bytes32)(uint256,uint256)" $POOL_ID --rpc-url $RPC

# 10. Verifica Router pulito
echo ""
echo "[10] Verifica Router non trattiene token"
echo "  Router T2T:  $(cast call $T2T "balanceOf(address)(uint256)" $ROUTER --rpc-url $RPC)"
echo "  Router USDC: $(cast call $USDC "balanceOf(address)(uint256)" $ROUTER --rpc-url $RPC)"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  E2E TEST COMPLETE"
echo "═══════════════════════════════════════════════════════════"
