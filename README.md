<p align="center">
  <img src="./assets/logo.png" alt="Two-Trader Logo" width="250">
</p>

<h1 align="center">Quantum Imperium — The Ethereum Backup Plan</h1>

<p align="center">
  <strong>A quantum-safe, modular Layer-1 blockchain designed to complement Ethereum.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Quantum--Safe-By%20Default-0A84FF?style=for-the-badge" alt="Quantum Safe">
  <img src="https://img.shields.io/badge/Layer--1-Blockchain-FFD700?style=for-the-badge" alt="Layer 1">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
  <a href="https://faucet-testnet.imperiumscan.com" target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Faucet-tIMP-7B68EE?style=for-the-badge" alt="Faucet">
  </a>
</p>

> *"Ethereum is the present. We are the future. But the future is already here, and it can coexist with the present."*

---

## 🚀 Quick Start

```bash
# Clona il repository
git clone https://github.com/Dev-Ceo26/quantum-imperium.git
cd quantum-imperium

# Installa le dipendenze Python
pip install -r requirements.txt

# Avvia il nodo Reth (Testnet 9818)
reth node --chain genesis-testnet.json --http --http.port 30334 --http.api eth,net,web3 --dev --dev.block-time 1s

# Avvia le sentinelle AI
cd sentinels
python3 orchestrator.py
🌐 Live Networks
Rete	Chain ID	RPC	Explorer
Mainnet	9819	https://rpc.imperiumscan.com	https://explorer.imperiumscan.com
Testnet	9818	https://rpc-testnet.imperiumscan.com	https://explorer-testnet.imperiumscan.com
Faucet	9818	—	https://faucet.imperiumscan.com
📚 Documentation
Documento	Descrizione
White Paper	Visione e architettura del progetto
Guida per i Guardian	Come diventare Guardian
Guida all'Installazione	Come installare un validatore
Architettura del Bridge	Come funziona il bridge
Contributing Guide	Come contribuire
Indirizzi Ufficiali	Tutti gli indirizzi deployati
Security Audit	Risultati audit (Slither + exploit test)
Test Results	Risultati dei test
🧩 Architecture
Componente	Tecnologia	Status
PQC	Kyber / Dilithium	✅ Implemented
Consensus	QPoS	🚧 In development
VM	QVM	✅ Implemented
Storage	IPFS + Tor	✅ Implemented
API	Reth JSON-RPC	✅ Implemented
Execution Client	Reth 2.5.2	✅ Operativo
Bridge	Multi-sig Guardian (3/5)	✅ Testato su testnet + Sepolia
Sentinelle AI	Python	✅ Operativo
Guardian Network	Solidity	✅ Testato su testnet
DAO + Timelock	Solidity (OZ Governor)	✅ Deployato su testnet
Staking	Solidity	✅ Deployato su testnet
Explorer	HTML + Caddy	✅ Online (mainnet + testnet)
🛣️ Roadmap
Phase	Description	Target	Status
Phase 0	Working Prototype	✅ Q1 2026	✅ Completed
Phase 1	Public Testnet	🔄 Q2 2026	✅ Completed
Phase 2	Ethereum Bridge	📅 Q3 2026	✅ Testato su Sepolia
Phase 3	Mainnet + DAO	📅 Q4 2026	🚧 In progress
Phase 4	Quantum Layer (PQC)	📅 2027	📅 Planned
🧪 Testnet Deployment (Chain ID 9818)
Contratto	Indirizzo
tIMP (governance)	0xBea13F68aE21Fc20a07FA863FF136756E9031cD0
Vault	0x155CF116dfbfA2c5F10F73137755051F1ECF40b9
FeeDistributor	0x9F7063339479a0D0652144B97d6cBB7FF151CC8A
Factory	0x96430E1660F546bF8f14772A093A6aCfb8e15e80
Staking	0x5902963aCC81BE695b7FAC379295623E76071c4E
Faucet	0xca774a8e3f1fc70ea1080468bbbd100bf6a77545
GuardianRegistry	0x0bc179C2D5793e726016B3938f31f2af53Cb2EDA
TimelockController	0x13080d47448B672053dc53e7b83b2215015d49f1
ImperiumDAO	0xB6eF9702245B91332fBb006fA15Df293313bc35D
ImperiumMessenger	0xb24448dCB713728f1d5ADf6b0a6BA707C5893762
ImperiumBridgeChild	0x4D91F584A3f677864f25e7b5cbc45399C5109Edc
Deployer: 0x8d2ed8c03c62407e385e32121172b3b12ff484

### IMPUSD (Imperium USD)

Token stablecoin algoritmico con collateral 50% USDC + 50% USDT.

| Rete | Indirizzo |
|------|-----------|
| Testnet (9818) | `0x383D8f17910b0B3000B02BF27Df04C388f6CC3A9` |
| Mainnet | — (da deployare) |

**Funzioni principali:**
- `depositReserveAndMint(asset, amount, mintTo)` — deposita collateral e ricevi IMPUSD
- `burnAndWithdrawReserve(amount)` — brucia IMPUSD e ricevi collateral
- `getReserveCoverage()` — % di collateralizzazione
- `isFullyCollateralized()` — true se collateral >= supply

🌉 Bridge Cross-Chain (Sepolia 11155111)
Contratto	Indirizzo
tIMP	0x96430E1660F546bF8f14772A093A6aCfb8e15e80
GuardianRegistry	0x9284633a660D1c2a494F6Ad43C1569E349D578C1
ImperiumMessenger	0x9053108677255F4982d8807C4D156e02306d3f80
ImperiumBridgeRoot	0x6aF62321d6576FB14eF7C2934CC177301A013dfe
Bridge model: Lock/Release (no mint/burn)
Threshold: 3/5 Guardian

📄 License
MIT License

🔗 Links
Website: imperiumchain.com

Imperium Scan: imperiumscan.com

Explorer Mainnet: explorer.imperiumscan.com

Explorer Testnet: explorer-testnet.imperiumscan.com.

Faucet: faucet-testnet.imperiumscan.com

GitHub: Quantum Imperium Repository

Twitter: Coming soon

Discord: https://discord.gg/J2W8Dk56m

<p align="center"> <strong>Quantum Imperium Core Team</strong><br> <sub>September 2026</sub> </p> ```

