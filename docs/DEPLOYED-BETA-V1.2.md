# Deploy canone v1.2 — Testnet Twotrader (chainId 9818)

Data: 2026-10-10
Deployer: 0x8d2eD8c03c62407fae385E32121172b3b12ff484
Explorer: https://explorer-testnet.twotrader-scan.com/

## Contratti del canone v1.2

| Contratto | Indirizzo |
|---|---|
| GuardianRegistry | 0xc7790e92a2e2926Fc86C4D5c01CD32f6F8363D63 |
| DecisionRegistry | 0x03B0A05a02Dbc65Db333343f4B2743087f3b3C5e |
| TwotraderMessenger | 0x81A456c4604D318684D8100DC4dF7ef2AfA40953 |
| TwotraderBridgeRoot | 0xAD33475552A4ffEcCaE0A1EEE2b432552191D61c |
| TwotraderBridgeChild | 0xF305c0c0c2d6bA082892d16418890C8DB7C5E201 |

## Configurazione

- Threshold: 3
- Min stake: 1000 T2T
- Unstake cooldown: 7 giorni
- Fee BPS: 10 (0.1%)
- Fee recipient: 0x8d2eD8c03c62407fae385E32121172b3b12ff484

## Ruoli

- GOVERNOR_ROLE: deployer (Fase A)
- VETO_ROLE (DecisionRegistry): deployer
- EMERGENCY_ROLE: deployer

## Verifiche on-chain

- Messenger.threshold() = 3
- Messenger.registry() = GuardianRegistry
- Messenger.decisionRegistry() = DecisionRegistry
- Messenger.paused() = false
- BridgeRoot.thisChainId() = 9818
- BridgeRoot.l2ChainId() = 9818
- BridgeRoot.feeBps() = 10
- BridgeRoot.feeRecipient() = deployer
- BridgeChild.thisChainId() = 9818
- BridgeChild.l1ChainId() = 11155111
- BridgeChild.feeBps() = 10
- GuardianRegistry.getGuardianCount() = 0
- GuardianRegistry.minStake() = 1000e18
- DecisionRegistry.hasRole(VETO_ROLE, deployer) = true

## Prossimo passo

1. Generare 2 wallet per i guardian
2. Finanziare i 2 wallet con T2T dal deployer
3. Registrare tutti e 3 i guardian
4. Test end-to-end del canone (deposit → firme → finalize)
5. Deploy DEX (PoolManager, Router, Hook)
6. PromoteGovernance (Fase C)

## Contratti del sistema precedente (19, settembre)

Restano attivi sulla chain, non toccati. Vedi DEPLOYED.md.
