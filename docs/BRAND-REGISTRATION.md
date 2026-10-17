# Brand Registration — Twotrader

## Ethereum Mainnet

**Contratto:** TwoTraderBrandProtection
**Indirizzo:** 0x7ffcb909d502cf5092814c0a611f25b6d9d9234c
**Rete:** Ethereum Mainnet (chainId 1)
**Block deploy:** 26199241
**Tx deploy:** 0x83dba84029af27b36826d04d52830212a812ff9db13ce407bc9c0bd550a9cc8b
**Etherscan:** https://etherscan.io/address/0x7ffcb909d502cf5092814c0a611f25b6d9d9234c

## Registrazioni on-chain

| Nome | Owner | Document Hash | Timestamp | Data |
|---|---|---|---|---|
| Twotrader | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792084463 | 2026-10-15 |
| T2T | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792084823 | 2026-10-15 |
| T2T | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792175591 | 2026-10-16 |
| 2TD | 0x8d2eD8c03c62407fae385E32121172b3b12ff484 | 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095 | 1792175171 | 2026-10-16 |

**Ticker ufficiale:** T2T (leggi "T-to-T" o "T-two-T")
**Ticker difensivi:** T2T, 2TD (registrati per anteriorita', non usati operativamente)
**Brand:** Twotrader

## Documento di riferimento

Il documento di riferimento e' il manifesto Twotrader:

- **File:** `docs/TWOTRADER-MANIFESTO.md`
- **PDF:** `docs/TWOTRADER-MANIFESTO.pdf`
- **Hash (Keccak-256 del PDF):** 0x7cc6ecb5a28676582f88a25506d5b68bcd0d72310065c23c4c5f419247c0a095
- **Come verificare:** scarica il PDF, calcola `cast keccak $(xxd -p manifesto.pdf | tr -d '\n' | sed 's/^/0x/')` e confronta con l'hash sopra

## Come verificare le registrazioni

1. Vai su https://etherscan.io/address/0x7ffcb909d502cf5092814c0a611f25b6d9d9234c#readContract
2. Chiama `getBrandDetails("Twotrader")` -> owner, hash, timestamp
3. Chiama `getBrandDetails("T2T")` -> owner, hash, timestamp
4. Chiama `getBrandDetails("T2T")` -> owner, hash, timestamp
5. Chiama `getBrandDetails("2TD")` -> owner, hash, timestamp

## Cosa NON e' questa registrazione

- Non e' un marchio legale registrato
- Non protegge da conflitti con marchi esistenti (TWO TRADING LTD, 2trading HK, T1 Energy)
- Non impedisce ad altri di usare il nome "Twotrader" o i ticker

## Cosa e' questa registrazione

- Prova crittografica di anteriorita' su Ethereum mainnet
- Base per un deposito di marchio legale (in Italia, UE, o USA)
- Ancora il nome "Twotrader" e i ticker T2T / T2T / 2TD a un documento specifico (manifesto)

## Note operative

- Il logo attuale dice "T2T". Va rifatto con "T2T" prima del lancio pubblico.
- Il conflitto T2T con T1 Energy (borsa di Francoforte, settore energia solare) e' considerato irrilevante per una blockchain.
- T2T e 2TD restano registrati come difensivi contro usi futuri da parte di terzi.
