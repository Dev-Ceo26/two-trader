# Brand Registration — Twotrader

## Ethereum Mainnet

**Contratto:** TwoTraderBrandProtection
**Indirizzo:** 0x7ffcb909d502cf5092814c0a611f25b6d9d9234c
**Rete:** Ethereum Mainnet (chainId 1)
**Block deploy:** 26199241
**Tx deploy:** 0x83dba84029af27b36826d04d52830212a812ff9db13ce407bc9c0bd550a9cc8b
**Etherscan:** https://etherscan.io/address/0x7ffcb909d502cf5092814c0a611f25b6d9d9234c

## Registrazioni

| Nome | Owner | Document Hash | Timestamp | Data |
|---|---|---|---|---|
| Twotrader | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792084463 | 2026-10-15 |
| TDR | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792084823 | 2026-10-15 |

## Documento di riferimento

Il documento di riferimento e' il manifesto Twotrader:

- **File:** `docs/TWOTRADER-MANIFESTO.md`
- **Hash (Keccak-256 del PDF):** 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095
- **Come verificare:** scarica il PDF, calcola `cast keccak $(xxd -p manifesto.pdf | tr -d '\n')` e confronta con l'hash sopra

## Come verificare la registrazione

1. Vai su https://etherscan.io/address/0x7ffcb909d502cf5092814c0a611f25b6d9d9234c#readContract
2. Chiama `getBrandDetails("Twotrader")` -> owner, hash, timestamp
3. Chiama `getBrandDetails("TDR")` -> owner, hash, timestamp

## Cosa NON e' questa registrazione

- Non e' un marchio legale registrato
- Non protegge da conflitti con marchi esistenti (TWO TRADING LTD, 2trading HK)
- Non impedisce ad altri di usare il nome "Twotrader"

## Cosa e' questa registrazione

- Prova crittografica di anteriorita' su Ethereum mainnet
- Base per un deposito di marchio legale (in Italia, UE, o USA)
- Ancora il nome "Twotrader" e il ticker "TDR" a un documento specifico (manifesto)
