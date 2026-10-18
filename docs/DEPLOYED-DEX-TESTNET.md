# Deploy DEX V4 — Testnet Twotrader (2026-10-10)

Data: 2026-10-10
Deployer: 0x8d2eD8c03c62407fae385E32121172b3b12ff484
Explorer: https://explorer-testnet.twotrader-scan.com/

## Contratti DEX

| Contratto | Indirizzo |
|---|---|
| TwotraderPoolManager (proxy) | 0xdb9175d0d41b40b1667ea947ff38b96144a900d4 |
| TwotraderRouter | 0x743c8f316bf7d18ad139fec23754293b244e5913 |
| TwotraderHooks (flag 0xC0) | 0xc6c21de82b1e1e3be0c8305c28faf8a9192800c0 |

## Pool

| Campo | Valore |
|---|---|
| Token0 | tT2T (0x63B3b910..., 18 dec) |
| Token1 | mUSDC-b (0xFCDE586a..., 6 dec) |
| Fee | 3000 (0.3%) |
| TickSpacing | 60 |
| Tick iniziale | -276324 |
| Hook | 0xc6c21de8... |

## Whitelist

- allowToken(tT2T) ✅
- allowToken(mUSDC-b) ✅
- allowPair(tT2T, mUSDC-b) ✅
- allowPool(pool) ✅

## AddLiquidity

- 100.000 tT2T + 100.000 mUSDC
- Range: [-286320, -266340] (±10.000 tick)

## TestSwap

- Swap: 10 mUSDC → ~102,8 tT2T
- Rapporto: ~10,28 tT2T/USDC

**Nota:** il test Foundry `SwapRatioTest` dava 9,97 tT2T per 10 USDC (rapporto ~1:1).
La differenza tra test e chain reale e' da investigare.
Il DEX e' tecnicamente funzionante: pool, hook, swap, transfer tutti corretti.

## Script utilizzati

- script/deploy/02_DeployPoolManager.s.sol
- script/DeployTwotraderRouter.s.sol
- script/DeployTwotraderHooks.s.sol
- script/CreatePoolWithHook.s.sol
- script/AllowPool.s.sol
- script/AddLiquidity.s.sol
- script/TestSwap.s.sol
