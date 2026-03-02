# PAXI Wallet CLI

Professional Command Line Interface (CLI) for PAXI Network (Cosmos-based). Focuses on core wallet functionality and PRC-20 token management.

![PAXI Wallet](https://s6.imgcdn.dev/Y1h2sh.jpg)

## 🚀 Features

### 🔐 Wallet Management
- **Generate Wallet**: Create a new wallet with a 24-word BIP39 mnemonic.
- **Import/Export**: Easily import or export your wallet using mnemonics.
- **Persistence**: Securely stores your wallet locally (until manual logout).
- **QR Code**: View your wallet address and its corresponding QR code for easy receiving.
- **Dual Network**: Seamlessly switch between **Mainnet** and **Testnet**.

### 💸 Core Transactions
- **Balance Inquiry**: Check your PAXI balance in real-time.
- **Transfer PAXI**: Send PAXI tokens to any address with optional memos.
- **Transaction History**: Track your recent blockchain activities.

### 🪙 PRC-20 Token Suite
Complete implementation of CW20 standard:
- **Token Creation**: Launch your own PRC-20 token in minutes.
- **Management**: Mint new tokens (minter only) or burn your own tokens.
- **Allowance System**: Professional allowance management (Increase/Decrease/Check).
- **Advanced Transfers**: Standard transfers and `TransferFrom` using allowances.

### 🛠 Developer Tools
- **Contract Management**: Upload, instantiate, execute, and query CosmWasm contracts.
- **Command Presets**: Save frequently used execute commands for quick access.

---

## 📥 Installation & Setup

### Requirements
- Node.js (v16+)
- npm
- Termux (for Android users) or any Linux/macOS terminal.

### Quick Install
```bash
curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/paxiwallet.sh > paxiwallet.sh && bash paxiwallet.sh
```

---

## 🎮 CLI Usage

After installation, you can use the following commands:

### `walletpaxi`
Launches the main Interactive CLI menu.

### `updated-walletpaxi`
Automatically updates the tool to the latest version while **preserving your wallet and data**.

---

## 📋 Commands Overview

| Command | Action |
|---------|--------|
| `1` | Generate New Wallet |
| `2` | Import from Mnemonic |
| `3` | Send PAXI |
| `4` | Transaction History |
| `6` | Create PRC-20 Token |
| `9` | Mint Tokens |
| `10` | Burn Tokens |
| `16-19`| Contract Management |
| `29` | Settings (Switch Network, Logout, etc.) |

---

## 🔄 Update & Maintenance

### How to Update
Run the update command:
```bash
updated-walletpaxi
```
The script will backup your `wallet.json`, `history.json`, and other configurations, download the latest version, and restore your data automatically.

### How to Uninstall
Run the uninstaller script:
```bash
curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/uninstaller.sh > uninstaller.sh && bash uninstaller.sh
```

---

## 🌐 Network Configuration

### Mainnet
- **RPC**: `https://mainnet-rpc.paxinet.io`
- **Prefix**: `paxi`

### Testnet
- **RPC**: `https://testnet-rpc.paxinet.io`
- **Prefix**: `paxi`

---

## 👨‍💻 Developer Support

- **Team**: PaxiHub Team
- **Documentation**: [https://paxinet.io/paxi_docs/developers](https://paxinet.io/paxi_docs/developers)
- **Telegram**: [https://t.me/paxi_network](https://t.me/paxi_network)

---
*Disclaimer: Use at your own risk. Always backup your mnemonics in a secure place.*
