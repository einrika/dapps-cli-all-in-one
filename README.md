# PAXI Wallet (CLI)

Wallet CLI untuk jaringan PAXI (Cosmos-based).  
Fokus pada fungsi inti wallet dan pengembangan PRC-20 token.

---

## Fitur

### Wallet
- Generate wallet (mnemonic 12 kata, BIP39)
- Import dan export mnemonic
- Simpan dan load wallet terenkripsi
- Menampilkan alamat wallet dan QR code

### Balance
- Saldo PAXI langsung ditampilkan saat aplikasi dijalankan

### Transfer
- Kirim / transfer token PAXI

### Transaction History
- Belum berfungsi
- Perlu perbaikan metode fetch history dari jaringan Cosmos / PAXI

---

## PRC-20 Token

Fitur PRC-20 difokuskan untuk kebutuhan developer.

Fitur yang tersedia:
- Create PRC-20 token
- Transfer PRC-20
- Check balance PRC-20
- Mint token
- Burn token
- Renounce minting
- Transfer ownership
- Transfer marketing / fee address

Catatan:
- Fitur "View all PRC-20 tokens" membutuhkan query khusus di Cosmos
- Jika tidak memungkinkan secara teknis, fitur ini akan dihapus

---

## Fitur yang Tidak Didukung

Fitur berikut sengaja dihapus dan tidak termasuk scope project:

### NFT (PRC-721)
- Create collection
- Mint NFT
- Transfer NFT
- Query NFT
- View NFT

### DEX dan Liquidity
- Provide liquidity
- Withdraw liquidity
- Swap token
- Pool list dan detail

### Staking
- Delegate dan undelegate
- Claim rewards
- View delegations

### Governance
- Vote proposal

---

## Instalasi

### Auto install (disarankan)
```bash
curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/install.sh > install.sh && bash install.sh
```
### Uninstall
```bash
curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/uninstaller.sh > uninstaller.sh && bash uninstaller.sh
```
### Manual install
```
nano install.sh
# paste script install.sh
# CTRL+X, Y, Enter

chmod +x install.sh
bash install.sh
```

### Updated script 

```bash
check didalam saat run sudah selesai
```

---

### Menjalankan dapps script
```
paxi
```

---

### Struktur Direktori
```text
~/paxi-wallet/
├── wallet.js
├── paxi
├── wallet.enc
├── history.json
├── package.json
└── node_modules/
```

---

### Keamanan

1. Menggunakan standar BIP39

2. Semua data disimpan lokal

3. Wallet dapat dienkripsi dengan password

4. Private key tidak diexport

5. Mnemonic hanya berada di memory saat runtime

---

### Catatan Teknis

1. Transaction history belum berjalan dan perlu implementasi query yang benar di Cosmos RPC

2. Project ini hanya fokus pada wallet dan PRC-20

3. Fitur di luar scope tidak akan ditambahkan
---

### Status

- Wallet dasar: siap digunakan

- PRC-20: siap untuk development

- Transaction history: belum selesai

---

### Tujuan

Project ini dibuat sebagai CLI wallet sederhana dan alat bantu developer PRC-20 di jaringan PAXI.
