#!/bin/bash

# ================================================================
# PAXIHUB CREATE TOKEN PRC20 - FULL IMPLEMENTATION
# Version 3.2.0 - Complete with Mint, Burn, Allowance
# ================================================================

set -e

VERSION="3.2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

clear_screen() { printf '\033c'; }

show_progress() {
    local duration=$1
    local steps=20
    local delay
    if command -v bc >/dev/null 2>&1; then
        delay=$(echo "scale=4; $duration / $steps" | bc)
    else
        delay="0.05"
    fi
    printf "["
    for ((i=0;i<steps;i++)); do
        printf "█"
        sleep $delay
    done
    printf "] Done!\n"
}

check_installed() {
    command -v "$1" >/dev/null 2>&1
}

HEADER_SHOWN=false
show_header() {
cat << "EOF"
==================================================
 PAXIHUB CREATE TOKEN PRC20 - FULL IMPLEMENTATION
--------------------------------------------------
 Version : 3.2.0  
 Networks: Testnet + Mainnet (Full Logic)
 Features: Token + Mint/Burn + Allowance + More
 Dev     : PaxiHub Team
==================================================
EOF
}

show_header_once() {
    if [ "$HEADER_SHOWN" = false ]; then
        clear_screen
        show_header
        HEADER_SHOWN=true
    fi
}

clean_screen() {
    clear_screen
    show_header
}

pause_and_clean() {
    echo ""
    read -p "Tekan Enter untuk lanjut..." -r
    clean_screen
}

# START
show_header_once

echo -e "${CYAN}Pilih opsi:${NC}"
echo -e "1) Install Baru"
echo -e "2) Update (Preserve Data)"
read -p "Pilihan [1-2]: " ACTION

if [ "$ACTION" == "2" ]; then
    echo -e "${YELLOW}🔄 Mode Update Aktif. Menyiapkan backup data...${NC}"
    if [ -d ~/paxi-dapp ]; then
        mkdir -p ~/paxi-data-backup
        for file in wallet.json config.json history.json contracts.json execute_commands.json; do
            if [ -f ~/paxi-dapp/$file ]; then
                cp ~/paxi-dapp/$file ~/paxi-data-backup/
                echo -e "${GREEN}✓ Backup $file${NC}"
            fi
        done
    fi
fi

echo ""
echo -e "${CYAN}🚀 Starting process...${NC}"
echo ""

# [0/7] Fix dpkg
echo -e "${CYAN}[0/7]${NC} ${BLUE}Checking system integrity...${NC}"
if dpkg --audit 2>&1 | grep -q "not fully installed"; then
    echo -e "${YELLOW}⚠ Fixing interrupted dpkg...${NC}"
    dpkg --configure -a 2>/dev/null || true
    echo -e "${GREEN}✓ dpkg fixed${NC}"
elif ! dpkg --audit >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Repairing package system...${NC}"
    dpkg --configure -a 2>/dev/null || true
    apt --fix-broken install -y 2>/dev/null || true
    echo -e "${GREEN}✓ System repaired${NC}"
else
    echo -e "${GREEN}✓ System OK${NC}"
fi
echo ""

# [1/7] System Update
echo -e "${CYAN}[1/7]${NC} ${BLUE}Updating system...${NC}"

UPDATE_FLAG="$HOME/.paxihub_last_update"
NOW_TS=$(date +%s)
MAX_AGE=86400

if [ -f "$UPDATE_FLAG" ] && [ $((NOW_TS - $(cat "$UPDATE_FLAG" 2>/dev/null || echo 0))) -lt $MAX_AGE ]; then
    echo -e "${GREEN}✓ System already updated recently, skipped${NC}"
    show_progress 0.5
else
    echo -e "${YELLOW}⏳ Running pkg update (max 60s)...${NC}"
    
    (timeout 60 pkg update -y 2>&1 || echo "TIMEOUT") &
    UPDATE_PID=$!
    
    SPIN='-\|/'
    i=0
    while kill -0 $UPDATE_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${YELLOW}   Updating... ${SPIN:$i:1}${NC}"
        sleep 0.2
    done
    wait $UPDATE_PID 2>/dev/null || true
    printf "\r${GREEN}   ✓ pkg update done${NC}          \n"
    
    echo -e "${YELLOW}⏳ Running pkg upgrade (max 90s)...${NC}"
    
    (timeout 90 pkg upgrade -y 2>&1 || echo "TIMEOUT") &
    UPGRADE_PID=$!
    
    i=0
    while kill -0 $UPGRADE_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${YELLOW}   Upgrading... ${SPIN:$i:1}${NC}"
        sleep 0.2
    done
    wait $UPGRADE_PID 2>/dev/null || true
    printf "\r${GREEN}   ✓ pkg upgrade done${NC}          \n"
    
    date +%s > "$UPDATE_FLAG"
    
    show_progress 0.5
    echo -e "${GREEN}✓ System update finished${NC}"
fi

echo ""

# [2/7] Dependencies
clean_screen
echo -e "${CYAN}[2/7]${NC} ${BLUE}Checking dependencies...${NC}"

DEPS_TO_INSTALL=""
MISSING_DEPS=""

if ! check_installed node; then 
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL nodejs"
    MISSING_DEPS="$MISSING_DEPS nodejs"
fi
if ! check_installed git; then 
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL git"
    MISSING_DEPS="$MISSING_DEPS git"
fi
if ! check_installed wget; then 
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"
    MISSING_DEPS="$MISSING_DEPS wget"
fi
if ! check_installed curl; then 
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL curl"
    MISSING_DEPS="$MISSING_DEPS curl"
fi
if ! check_installed bc; then 
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL bc"
    MISSING_DEPS="$MISSING_DEPS bc"
fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    echo -e "${YELLOW}📦 Missing:$MISSING_DEPS${NC}"
    echo -e "${YELLOW}⏳ Installing packages...${NC}"
    echo -e "${CYAN}Updating package list...${NC}"
    pkg update -y
    echo -e "${CYAN}Installing:$DEPS_TO_INSTALL${NC}"
    if ! pkg install -y $DEPS_TO_INSTALL; then
        echo -e "${YELLOW}⚠ Some packages failed, trying one by one...${NC}"
        for dep in $DEPS_TO_INSTALL; do
            echo -e "${CYAN}  Installing $dep...${NC}"
            pkg install -y $dep || echo -e "${RED}  ✗ Failed: $dep${NC}"
        done
    fi
    show_progress 1
    echo -e "${GREEN}✓ Installation completed${NC}"
else
    echo -e "${GREEN}✓ All basic dependencies OK${NC}"
    show_progress 0.5
fi

echo ""

# VALIDASI Node.js dan npm
echo -e "${CYAN}Validating Node.js & npm...${NC}"

if ! check_installed node; then
    echo -e "${YELLOW}Node.js not found, installing...${NC}"
    dpkg --configure -a 2>/dev/null || true
    if ! pkg install -y nodejs; then
        echo -e "${RED}✗ FATAL: Cannot install Node.js!${NC}"
        exit 1
    fi
    if ! check_installed node; then
        echo -e "${RED}✗ FATAL: Node.js still not found!${NC}"
        exit 1
    fi
fi

if ! check_installed npm; then
    echo -e "${YELLOW}npm not found, installing...${NC}"
    echo -e "${CYAN}Checking dpkg integrity...${NC}"
    if dpkg --configure -a 2>&1 | grep -q "interrupted"; then
        echo -e "${YELLOW}⚠ Fixing dpkg...${NC}"
        dpkg --configure -a
    fi
    echo -e "${CYAN}Attempting npm installation...${NC}"
    if ! pkg install -y npm 2>&1; then
        echo -e "${YELLOW}Direct npm install failed, trying alternative...${NC}"
        echo -e "${CYAN}Reinstalling nodejs...${NC}"
        pkg uninstall nodejs -y 2>/dev/null || true
        dpkg --configure -a 2>/dev/null || true
        pkg install -y nodejs
    fi
    if ! check_installed npm; then
        echo -e "${RED}✗✗ CRITICAL ERROR: npm not available!${NC}"
        exit 1
    fi
fi

NODE_VER=$(node --version 2>/dev/null)
NPM_VER=$(npm --version 2>/dev/null)
echo -e "${GREEN}✓ Node.js ${NODE_VER}${NC}"
echo -e "${GREEN}✓ npm ${NPM_VER}${NC}\n"
pause_and_clean

# [3/7] Create Project
echo -e "${CYAN}[3/7]${NC} ${BLUE}Creating project...${NC}"

cd ~ || exit 1
if [ -d "paxi-dapp" ]; then
    echo -e "${YELLOW}⚠ Backing up existing paxi-dapp...${NC}"
    BACKUP_NAME="paxi-dapp-backup-$(date +%Y%m%d-%H%M%S)"
    mv paxi-dapp "$BACKUP_NAME"
    echo -e "${GREEN}✓ Backed up to ~/$BACKUP_NAME${NC}"
fi

mkdir -p paxi-dapp
cd paxi-dapp || exit 1
show_progress 0.5
echo -e "${GREEN}✓ Project folder created${NC}\n"
pause_and_clean

# [4/7] Install Packages
echo -e "${CYAN}[4/7]${NC} ${BLUE}Installing npm packages...${NC}"

cat > package.json << 'PKGJSON'
{
  "name": "paxi-dapp",
  "version": "3.2.0",
  "description": "PaxiHub DApp Full Implementation with Mint/Burn/Allowance",
  "main": "dapp.js",
  "scripts": {
    "start": "node dapp.js"
  },
  "dependencies": {
    "@cosmjs/stargate": "^0.32.4",
    "@cosmjs/proto-signing": "^0.32.4",
    "@cosmjs/cosmwasm-stargate": "^0.32.4",
    "@cosmjs/crypto": "^0.32.4",
    "@cosmjs/encoding": "^0.32.4",
    "@cosmjs/amino": "^0.32.4",
    "bip39": "^3.1.0",
    "chalk": "^4.1.2",
    "qrcode-terminal": "^0.12.0",
    "readline-sync": "^1.4.10"
  }
}
PKGJSON

echo -e "${YELLOW}⏳ Installing packages (may take 1-3 minutes)...${NC}"

if ! npm install 2>&1 | tee npm_install.log; then
    echo -e "${RED}✗ npm install failed!${NC}"
    echo -e "${YELLOW}Trying with --legacy-peer-deps...${NC}"
    if ! npm install --legacy-peer-deps 2>&1 | tee npm_install_legacy.log; then
        echo -e "${RED}✗✗ FATAL: Cannot install packages!${NC}"
        echo -e "${YELLOW}Check npm_install.log and npm_install_legacy.log${NC}"
        exit 1
    fi
fi

show_progress 1
echo -e "${GREEN}✓ Packages installed${NC}\n"
pause_and_clean

# [5/7] Create DApp
echo -e "${CYAN}[5/7]${NC} ${BLUE}Creating DApp...${NC}"

cat > dapp.js << 'DAPPEOF'
#!/usr/bin/env node

// ================================================================
// PAXIHUB DAPP - FULL IMPLEMENTATION v3.2.0
// Complete PRC-20 with Mint, Burn, Allowance, and More
// ================================================================

const readline = require('readline-sync');
const chalk = require('chalk');
const fs = require('fs');
const path = require('path');
const qrcode = require('qrcode-terminal');
const bip39 = require('bip39');

const { DirectSecp256k1HdWallet, makeCosmoshubPath } = require('@cosmjs/proto-signing');
const { stringToPath } = require('@cosmjs/crypto');
const { SigningStargateClient, StargateClient, GasPrice } = require('@cosmjs/stargate');
const { SigningCosmWasmClient, CosmWasmClient } = require('@cosmjs/cosmwasm-stargate');

// ================================================================
// CONFIG
// ================================================================

const CONFIG = {
    version: '3.2.0',
    DEV_CONTRACT_AUTHOR: 'PaxiHub Team',
    network: 'mainnet',
    chainId: '',
    networks: {
        testnet: {
            name: 'testnet',
            rpc: 'https://testnet-rpc.paxinet.io',
            lcd: 'https://testnet-lcd.paxinet.io',
            prefix: 'paxi',
            denom: 'upaxi',
            gasPrice: '0.025upaxi',
            color: chalk.yellow
        },
        mainnet: {
            name: 'mainnet',
            rpc: 'https://mainnet-rpc.paxinet.io',
            lcd: 'https://mainnet-lcd.paxinet.io',
            prefix: 'paxi',
            denom: 'upaxi',
            gasPrice: '0.025upaxi',
            color: chalk.green
        }
    }
};

// File paths
const WALLET_FILE = 'wallet.json';
const CONFIG_FILE = 'config.json';
const HISTORY_FILE = 'history.json';
const CONTRACTS_FILE = 'contracts.json';
const EXECUTE_COMMANDS_FILE = 'execute_commands.json';

// ================================================================
// UTILITY FUNCTIONS
// ================================================================

function clearScreen() {
    // Menggunakan escape sequence yang lebih reliable untuk Termux
    // \x1Bc = reset terminal (ESC c)
    process.stdout.write('\x1Bc');
}

function loadConfig() {
    if (fs.existsSync(CONFIG_FILE)) {
        try {
            const data = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
            Object.assign(CONFIG, data);
        } catch (e) {
            console.log(chalk.yellow('⚠ Using default config'));
        }
    }
}

function saveConfig() {
    try {
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(CONFIG, null, 2));
    } catch (e) {
        console.log(chalk.red('✗ Failed to save config'));
    }
}

function getCurrentNetwork() {
    return CONFIG.networks[CONFIG.network];
}

async function fetchChainId() {
    try {
        const net = getCurrentNetwork();
        const response = await fetch(`${net.rpc}/status`);
        const data = await response.json();
        CONFIG.chainId = data.result.node_info.network;
        saveConfig();
    } catch (e) {
        console.log(chalk.yellow('⚠ Using default chain ID'));
        CONFIG.chainId = CONFIG.network === 'mainnet' ? 'paxi-mainnet-1' : 'paxi-testnet-1';
    }
}

function loadWallet() {
    if (fs.existsSync(WALLET_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(WALLET_FILE, 'utf8'));
        } catch (e) {
            console.log(chalk.red('✗ Error loading wallet'));
        }
    }
    return null;
}

function saveWallet(data) {
    try {
        fs.writeFileSync(WALLET_FILE, JSON.stringify(data, null, 2));
    } catch (e) {
        console.log(chalk.red('✗ Failed to save wallet'));
    }
}

function saveHistory(data) {
    try {
        let history = [];
        if (fs.existsSync(HISTORY_FILE)) {
            history = JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
        }
        history.push(data);
        fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
    } catch (e) {
        console.log(chalk.red('✗ Failed to save history'));
    }
}

function loadContracts() {
    if (fs.existsSync(CONTRACTS_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(CONTRACTS_FILE, 'utf8'));
        } catch (e) {
            return {};
        }
    }
    return {};
}

function saveContracts(data) {
    try {
        fs.writeFileSync(CONTRACTS_FILE, JSON.stringify(data, null, 2));
    } catch (e) {
        console.log(chalk.red('✗ Failed to save contracts'));
    }
}

function loadExecuteCommands() {
    if (fs.existsSync(EXECUTE_COMMANDS_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(EXECUTE_COMMANDS_FILE, 'utf8'));
        } catch (e) {
            return [];
        }
    }
    return [];
}

function saveExecuteCommands(data) {
    try {
        fs.writeFileSync(EXECUTE_COMMANDS_FILE, JSON.stringify(data, null, 2));
    } catch (e) {
        console.log(chalk.red('✗ Failed to save execute commands'));
    }
}

async function getSigningStargateClient() {
    const wallet = loadWallet();
    if (!wallet) return null;
    
    const net = getCurrentNetwork();
    const hdWallet = await DirectSecp256k1HdWallet.fromMnemonic(wallet.mnemonic, {
        prefix: net.prefix,
        hdPaths: [stringToPath("m/44'/118'/0'/0/0")]
    });
    
    const client = await SigningStargateClient.connectWithSigner(
        net.rpc,
        hdWallet,
        { gasPrice: GasPrice.fromString(net.gasPrice) }
    );
    
    return { client, wallet: hdWallet };
}

async function getSigningCosmWasmClient() {
    const wallet = loadWallet();
    if (!wallet) return null;
    
    const net = getCurrentNetwork();
    const hdWallet = await DirectSecp256k1HdWallet.fromMnemonic(wallet.mnemonic, {
        prefix: net.prefix,
        hdPaths: [stringToPath("m/44'/118'/0'/0/0")]
    });
    
    const client = await SigningCosmWasmClient.connectWithSigner(
        net.rpc,
        hdWallet,
        { gasPrice: GasPrice.fromString(net.gasPrice) }
    );
    
    return { client, wallet: hdWallet };
}

async function showBanner() {
    const net = getCurrentNetwork();
    // Don't clear here, let mainMenuLoop handle it    
    if (!CONFIG.chainId) {
        await fetchChainId();
    }
    
    console.log(chalk.cyan.bold('╔════════════════════════════════════════╗'));
    console.log(chalk.cyan.bold('║  PAXIHUB DAPP - FULL LOGIC v3.2.0     ║'));
    console.log(chalk.cyan.bold('╚════════════════════════════════════════╝'));
    console.log(chalk.cyan(`  Network: ${net.name.toUpperCase()}`));
    console.log(chalk.gray(`  Chain ID: ${CONFIG.chainId || 'Loading...'}`));
    
    const wallet = loadWallet();
    if (wallet) {
        console.log(chalk.white(`  Address: ${wallet.address}`));
        try {
            const balance = await getBalance(wallet.address);
            console.log(chalk.green(`  Balance: ${balance} PAXI`));
        } catch {
            console.log(chalk.gray('  Balance: N/A'));
        }
    } else {
        console.log(chalk.yellow('  Status: No wallet loaded'));
    }
    console.log('');
}

async function getBalance(address) {
    const net = getCurrentNetwork();
    try {
        const client = await StargateClient.connect(net.rpc);
        const balance = await client.getBalance(address, net.denom);
        return (parseInt(balance.amount) / 1e6).toFixed(6);
    } catch (e) {
        throw new Error(`Failed to get balance: ${e.message}`);
    }
}

function pause() {
    readline.question(chalk.gray('\nTekan Enter untuk kembali...'));
    clearScreen();
}

// ================================================================
// WALLET FUNCTIONS
// ================================================================

async function generateWallet() {
    const net = getCurrentNetwork();
    console.log(chalk.cyan('\n🔐 Generating new wallet...\n'));
    const mnemonic = bip39.generateMnemonic(256);
    const wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonic, {
        prefix: net.prefix,
        hdPaths: [stringToPath("m/44'/118'/0'/0/0")]
    });
    const [account] = await wallet.getAccounts();
    saveWallet({ address: account.address, mnemonic });
    console.log(chalk.green('✓ Wallet generated!\n'));
    console.log(chalk.white('Address:'), chalk.yellow(account.address));
    console.log(chalk.white('\nMnemonic (SAVE THIS SECURELY):'));
    console.log(chalk.red(mnemonic));
    pause();
}

async function importWallet() {
    const net = getCurrentNetwork();
    console.log(chalk.cyan('\n📥 Import wallet from mnemonic\n'));
    const mnemonic = readline.question(chalk.white('Enter mnemonic: '), { hideEchoBack: false });
    if (!bip39.validateMnemonic(mnemonic)) {
        console.log(chalk.red('\n✗ Invalid mnemonic!'));
        pause();
        return;
    }
    try {
        const wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonic, {
            prefix: net.prefix,
            hdPaths: [stringToPath("m/44'/118'/0'/0/0")]
        });
        const [account] = await wallet.getAccounts();
        saveWallet({ address: account.address, mnemonic });
        console.log(chalk.green('\n✓ Wallet imported!'));
        console.log(chalk.white('Address:'), chalk.yellow(account.address));
    } catch (e) {
        console.log(chalk.red(`\n✗ Import failed: ${e.message}`));
    }
    pause();
}

function showAddressQR() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    console.log(chalk.cyan('\n📱 Address QR Code\n'));
    console.log(chalk.white('Address:'), chalk.yellow(wallet.address));
    console.log('');
    qrcode.generate(wallet.address, { small: true });
    pause();
}

function exportWallet() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    console.log(chalk.cyan('\n💾 Export Wallet\n'));
    console.log(chalk.white('Address:'), chalk.yellow(wallet.address));
    console.log(chalk.white('\nMnemonic:'));
    console.log(chalk.red(wallet.mnemonic));
    console.log(chalk.yellow('\n⚠ Keep this mnemonic SAFE and PRIVATE!'));
    pause();
}

// ================================================================
// TRANSACTION FUNCTIONS
// ================================================================

async function sendPaxi() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n📤 Send PAXI\n'));
    const recipient = readline.question(chalk.white('Recipient address: '));
    const amount = readline.question(chalk.white('Amount (PAXI): '));
    const memo = readline.question(chalk.white('Memo (optional): '));
    
    console.log(chalk.yellow('\n⏳ Sending transaction...\n'));
    
    try {
        const { client } = await getSigningStargateClient();
        const net = getCurrentNetwork();
        const amountInMicro = Math.floor(parseFloat(amount) * 1e6).toString();
        
        const result = await client.sendTokens(
            wallet.address,
            recipient,
            [{ denom: net.denom, amount: amountInMicro }],
            'auto',
            memo
        );
        
        console.log(chalk.green('\n✓ Transaction sent!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Height:'), chalk.gray(result.height));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        saveHistory({
            type: 'Send PAXI',
            from: wallet.address,
            to: recipient,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Transaction failed: ${e.message}`));
    }
    
    pause();
}

async function viewHistory() {
    console.log(chalk.cyan('\n📜 Transaction History\n'));
    
    if (!fs.existsSync(HISTORY_FILE)) {
        console.log(chalk.yellow('No history found.'));
        pause();
        return;
    }
    
    try {
        const history = JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
        if (history.length === 0) {
            console.log(chalk.yellow('No transactions yet.'));
        } else {
            const recent = history.slice(-20).reverse();
            recent.forEach((tx, i) => {
                console.log(chalk.cyan(`\n[${i + 1}] ${tx.type}`));
                console.log(chalk.white(`  Time: ${new Date(tx.timestamp).toLocaleString()}`));
                if (tx.txHash) console.log(chalk.gray(`  TX: ${tx.txHash}`));
                if (tx.amount) console.log(chalk.green(`  Amount: ${tx.amount}`));
                if (tx.to) console.log(chalk.white(`  To: ${tx.to}`));
                if (tx.contract) console.log(chalk.white(`  Contract: ${tx.contract}`));
                if (tx.token) console.log(chalk.white(`  Token: ${tx.token}`));
            });
        }
    } catch (e) {
        console.log(chalk.red(`✗ Error reading history: ${e.message}`));
    }
    
    pause();
}

// ================================================================
// CONTRACT FUNCTIONS
// ================================================================

async function uploadContract() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n📤 Upload Contract\n'));
    const wasmPath = readline.question(chalk.white('WASM file path: '));
    
    if (!fs.existsSync(wasmPath)) {
        console.log(chalk.red('\n✗ File not found!'));
        pause();
        return;
    }
    
    console.log(chalk.yellow('\n⏳ Uploading contract...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        const wasmCode = fs.readFileSync(wasmPath);
        
        const result = await client.upload(
            wallet.address,
            wasmCode,
            'auto',
            'Uploaded via PaxiHub DApp'
        );
        
        console.log(chalk.green('\n✓ Contract uploaded!'));
        console.log(chalk.white('Code ID:'), chalk.yellow(result.codeId));
        console.log(chalk.white('Transaction Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        const contracts = loadContracts();
        if (!contracts[CONFIG.network]) contracts[CONFIG.network] = {};
        if (!contracts[CONFIG.network].uploaded) contracts[CONFIG.network].uploaded = [];
        contracts[CONFIG.network].uploaded.push({
            codeId: result.codeId,
            path: wasmPath,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        saveContracts(contracts);
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Upload failed: ${e.message}`));
    }
    
    pause();
}

async function instantiateContract() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n🎯 Instantiate Contract\n'));
    const codeId = parseInt(readline.question(chalk.white('Code ID: ')));
    const label = readline.question(chalk.white('Label: '));
    const initMsg = readline.question(chalk.white('Init message (JSON): '));
    
    console.log(chalk.yellow('\n⏳ Instantiating contract...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        const msg = JSON.parse(initMsg);
        
        const result = await client.instantiate(
            wallet.address,
            codeId,
            msg,
            label,
            'auto',
            { memo: 'Instantiated via PaxiHub DApp' }
        );
        
        console.log(chalk.green('\n✓ Contract instantiated!'));
        console.log(chalk.white('Contract Address:'), chalk.yellow(result.contractAddress));
        console.log(chalk.white('Transaction Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        const contracts = loadContracts();
        if (!contracts[CONFIG.network]) contracts[CONFIG.network] = {};
        if (!contracts[CONFIG.network].instantiated) contracts[CONFIG.network].instantiated = [];
        contracts[CONFIG.network].instantiated.push({
            address: result.contractAddress,
            codeId,
            label,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        saveContracts(contracts);
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Instantiation failed: ${e.message}`));
    }
    
    pause();
}

async function executeContract() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n⚡ Execute Contract\n'));
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const execMsg = readline.question(chalk.white('Execute message (JSON): '));
    const fundsStr = readline.question(chalk.white('Funds (e.g., 1000000upaxi or empty): '));
    
    console.log(chalk.yellow('\n⏳ Executing contract...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        const msg = JSON.parse(execMsg);
        const funds = fundsStr ? [{ denom: getCurrentNetwork().denom, amount: fundsStr.replace(/\D/g, '') }] : [];
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            msg,
            'auto',
            'Executed via PaxiHub DApp',
            funds
        );
        
        console.log(chalk.green('\n✓ Execution successful!'));
        console.log(chalk.white('Transaction Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        if (result.logs && result.logs.length > 0) {
            console.log(chalk.white('\nLogs:'));
            result.logs.forEach(log => {
                log.events.forEach(event => {
                    console.log(chalk.gray(`  ${event.type}`));
                });
            });
        }
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Execution failed: ${e.message}`));
    }
    
    pause();
}

async function queryContract() {
    console.log(chalk.cyan('\n🔍 Query Contract\n'));
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const queryMsg = readline.question(chalk.white('Query message (JSON): '));
    
    console.log(chalk.yellow('\n⏳ Querying contract...\n'));
    
    try {
        const net = getCurrentNetwork();
        const client = await CosmWasmClient.connect(net.rpc);
        const msg = JSON.parse(queryMsg);
        
        const result = await client.queryContractSmart(contractAddr, msg);
        
        console.log(chalk.green('\n✓ Query successful!\n'));
        console.log(chalk.white('Result:'));
        console.log(chalk.gray(JSON.stringify(result, null, 2)));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Query failed: ${e.message}`));
    }
    
    pause();
}

// ================================================================
// PRC-20 TOKEN FUNCTIONS (COMPLETE)
// ================================================================

async function createPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n🪙 Create PRC-20 Token\n'));
    console.log(chalk.gray('Using Code ID 1 (PRC-20 Standard)\n'));
    
    const name = readline.question(chalk.white('Token Name: '));
    const symbol = readline.question(chalk.white('Token Symbol: '));
    const decimals = parseInt(readline.question(chalk.white('Decimals (default 6): ')) || '6');
    const initialSupply = readline.question(chalk.white('Initial Supply: '));
    const label = readline.question(chalk.white('Label: ')) || symbol;
    
    console.log(chalk.yellow('\n📢 Marketing Info (optional, press Enter to skip):\n'));
    const project = readline.question(chalk.white('Project Name: '));
    const description = readline.question(chalk.white('Description: '));
    const marketing = readline.question(chalk.white('Marketing Address (empty = your address): ')) || wallet.address;
    const logoUrl = readline.question(chalk.white('Logo URL (IPFS/HTTP): '));
    
    const initMsg = {
        name: name,
        symbol: symbol,
        decimals: decimals,
        initial_balances: [
            {
                address: wallet.address,
                amount: initialSupply
            }
        ],
        mint: {
            minter: wallet.address
        }
    };
    
    if (project || description || logoUrl) {
        initMsg.marketing = {
            project: project || `${name} Project`,
            description: description || `This is ${name} token`,
            marketing: marketing
        };
        
        if (logoUrl) {
            initMsg.marketing.logo = {
                url: logoUrl
            };
        }
    }
    
    console.log(chalk.yellow('\n⏳ Creating PRC-20 token...\n'));
    console.log(chalk.gray('Init Message:'));
    console.log(chalk.gray(JSON.stringify(initMsg, null, 2)));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        const codeId = 1;
        
        const result = await client.instantiate(
            wallet.address,
            codeId,
            initMsg,
            label,
            'auto',
            { admin: undefined }
        );
        
        const contractAddress = result.contractAddress;
        
        console.log(chalk.green('\n✓ PRC-20 Token created successfully!'));
        console.log(chalk.yellow('\n📋 Token Details:'));
        console.log(chalk.white(`  Name: ${name}`));
        console.log(chalk.white(`  Symbol: ${symbol}`));
        console.log(chalk.white(`  Decimals: ${decimals}`));
        console.log(chalk.white(`  Supply: ${initialSupply}`));
        console.log(chalk.green(`  Contract: ${contractAddress}`));
        console.log(chalk.gray(`  TX Hash: ${result.transactionHash}`));
        console.log(chalk.gray(`  Height: ${result.height}`));
        console.log(chalk.gray(`  Gas Used: ${result.gasUsed}`));
        
        const contracts = loadContracts();
        if (!contracts[CONFIG.network]) contracts[CONFIG.network] = {};
        if (!contracts[CONFIG.network].prc20) contracts[CONFIG.network].prc20 = [];
        contracts[CONFIG.network].prc20.push({
            name: name,
            symbol: symbol,
            decimals: decimals,
            address: contractAddress,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        saveContracts(contracts);
        
        saveHistory({
            type: 'Create PRC-20',
            token: `${name} (${symbol})`,
            contract: contractAddress,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Token creation failed: ${e.message}`));
    }
    
    pause();
}

async function transferPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n📤 Transfer PRC-20\n'));
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const recipient = readline.question(chalk.white('Recipient address: '));
    const amount = readline.question(chalk.white('Amount: '));
    
    const executeMsg = {
        transfer: {
            recipient: recipient,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Transferring tokens...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Transfer PRC-20'
        );
        
        console.log(chalk.green('\n✓ Transfer successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        saveHistory({
            type: 'Transfer PRC-20',
            contract: contractAddr,
            to: recipient,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Transfer failed: ${e.message}`));
    }
    
    pause();
}

async function checkPRC20Balance() {
    console.log(chalk.cyan('\n💵 Check PRC-20 Balance\n'));
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const address = readline.question(chalk.white('Address to check (empty = your address): '));
    
    const wallet = loadWallet();
    const checkAddr = address || (wallet ? wallet.address : '');
    
    if (!checkAddr) {
        console.log(chalk.red('\n✗ No address specified!'));
        pause();
        return;
    }
    
    const queryMsg = {
        balance: {
            address: checkAddr
        }
    };
    
    console.log(chalk.yellow('\n⏳ Querying balance...\n'));
    
    try {
        const net = getCurrentNetwork();
        const client = await CosmWasmClient.connect(net.rpc);
        
        const result = await client.queryContractSmart(contractAddr, queryMsg);
        
        console.log(chalk.green('\n✓ Balance Retrieved:'));
        console.log(chalk.white(`  Address: ${checkAddr}`));
        console.log(chalk.yellow(`  Balance: ${result.balance}`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Query failed: ${e.message}`));
    }
    
    pause();
}

async function mintPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n⚒️  Mint PRC-20 Tokens\n'));
    console.log(chalk.gray('Only minter can execute this\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const recipient = readline.question(chalk.white('Recipient address (empty = your address): ')) || wallet.address;
    const amount = readline.question(chalk.white('Amount to mint: '));
    
    const executeMsg = {
        mint: {
            recipient: recipient,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Minting tokens...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Mint PRC-20'
        );
        
        console.log(chalk.green('\n✓ Mint successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        console.log(chalk.yellow(`  Minted ${amount} tokens to ${recipient}`));
        
        saveHistory({
            type: 'Mint PRC-20',
            contract: contractAddr,
            recipient: recipient,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Mint failed: ${e.message}`));
    }
    
    pause();
}

async function burnPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n🔥 Burn PRC-20 Tokens\n'));
    console.log(chalk.gray('This will burn tokens from your balance\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const amount = readline.question(chalk.white('Amount to burn: '));
    
    const executeMsg = {
        burn: {
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Burning tokens...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Burn PRC-20'
        );
        
        console.log(chalk.green('\n✓ Burn successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        console.log(chalk.yellow(`  Burned ${amount} tokens`));
        
        saveHistory({
            type: 'Burn PRC-20',
            contract: contractAddr,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Burn failed: ${e.message}`));
    }
    
    pause();
}

async function increaseAllowance() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n➕ Increase Allowance\n'));
    console.log(chalk.gray('Allow another address to spend your tokens\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const spender = readline.question(chalk.white('Spender address: '));
    const amount = readline.question(chalk.white('Amount: '));
    
    const executeMsg = {
        increase_allowance: {
            spender: spender,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Increasing allowance...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Increase Allowance'
        );
        
        console.log(chalk.green('\n✓ Allowance increased!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        console.log(chalk.yellow(`  ${spender} can now spend ${amount} of your tokens`));
        
        saveHistory({
            type: 'Increase Allowance',
            contract: contractAddr,
            spender: spender,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed: ${e.message}`));
    }
    
    pause();
}

async function decreaseAllowance() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n➖ Decrease Allowance\n'));
    console.log(chalk.gray('Reduce allowance for another address\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const spender = readline.question(chalk.white('Spender address: '));
    const amount = readline.question(chalk.white('Amount to decrease: '));
    
    const executeMsg = {
        decrease_allowance: {
            spender: spender,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Decreasing allowance...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Decrease Allowance'
        );
        
        console.log(chalk.green('\n✓ Allowance decreased!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        saveHistory({
            type: 'Decrease Allowance',
            contract: contractAddr,
            spender: spender,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed: ${e.message}`));
    }
    
    pause();
}

async function checkAllowance() {
    console.log(chalk.cyan('\n🔍 Check Allowance\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const owner = readline.question(chalk.white('Owner address: '));
    const spender = readline.question(chalk.white('Spender address: '));
    
    const queryMsg = {
        allowance: {
            owner: owner,
            spender: spender
        }
    };
    
    console.log(chalk.yellow('\n⏳ Querying allowance...\n'));
    
    try {
        const net = getCurrentNetwork();
        const client = await CosmWasmClient.connect(net.rpc);
        
        const result = await client.queryContractSmart(contractAddr, queryMsg);
        
        console.log(chalk.green('\n✓ Allowance Retrieved:'));
        console.log(chalk.white(`  Owner: ${owner}`));
        console.log(chalk.white(`  Spender: ${spender}`));
        console.log(chalk.yellow(`  Allowance: ${result.allowance}`));
        if (result.expires) {
            console.log(chalk.gray(`  Expires: ${JSON.stringify(result.expires)}`));
        }
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Query failed: ${e.message}`));
    }
    
    pause();
}

async function transferFromPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n📤 Transfer From (Using Allowance)\n'));
    console.log(chalk.gray('Transfer tokens using allowance\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const owner = readline.question(chalk.white('Owner address: '));
    const recipient = readline.question(chalk.white('Recipient address: '));
    const amount = readline.question(chalk.white('Amount: '));
    
    const executeMsg = {
        transfer_from: {
            owner: owner,
            recipient: recipient,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Transferring tokens...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Transfer From PRC-20'
        );
        
        console.log(chalk.green('\n✓ Transfer successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
        saveHistory({
            type: 'Transfer From PRC-20',
            contract: contractAddr,
            from: owner,
            to: recipient,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Transfer failed: ${e.message}`));
    }
    
    pause();
}

async function burnFromPRC20() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    console.log(chalk.cyan('\n🔥 Burn From (Using Allowance)\n'));
    console.log(chalk.gray('Burn tokens from another address using allowance\n'));
    
    const contractAddr = readline.question(chalk.white('Contract address: '));
    const owner = readline.question(chalk.white('Owner address: '));
    const amount = readline.question(chalk.white('Amount to burn: '));
    
    const executeMsg = {
        burn_from: {
            owner: owner,
            amount: amount
        }
    };
    
    console.log(chalk.yellow('\n⏳ Burning tokens...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        
        const result = await client.execute(
            wallet.address,
            contractAddr,
            executeMsg,
            'auto',
            'Burn From PRC-20'
        );
        
        console.log(chalk.green('\n✓ Burn successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        console.log(chalk.yellow(`  Burned ${amount} tokens from ${owner}`));
        
        saveHistory({
            type: 'Burn From PRC-20',
            contract: contractAddr,
            owner: owner,
            amount: amount,
            txHash: result.transactionHash,
            timestamp: new Date().toISOString()
        });
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Burn failed: ${e.message}`));
    }
    
    pause();
}

// ================================================================
// EXECUTE COMMANDS
// ================================================================

async function saveExecuteCommand() {
    console.log(chalk.cyan('\n💾 Save Execute Command\n'));
    
    const name = readline.question(chalk.white('Command name: '));
    const contract = readline.question(chalk.white('Contract address: '));
    const message = readline.question(chalk.white('Execute message (JSON): '));
    const funds = readline.question(chalk.white('Funds (optional, e.g., 1000000upaxi): '));
    
    try {
        JSON.parse(message);
    } catch (e) {
        console.log(chalk.red('\n✗ Invalid JSON format!'));
        pause();
        return;
    }
    
    const commands = loadExecuteCommands();
    commands.push({
        name: name,
        contract: contract,
        message: message,
        funds: funds,
        timestamp: new Date().toISOString()
    });
    saveExecuteCommands(commands);
    
    console.log(chalk.green('\n✓ Command saved!'));
    pause();
}

async function listExecuteCommands() {
    console.log(chalk.cyan('\n📋 Saved Execute Commands\n'));
    
    const commands = loadExecuteCommands();
    
    if (commands.length === 0) {
        console.log(chalk.yellow('No saved commands.'));
        pause();
        return;
    }
    
    commands.forEach((cmd, i) => {
        console.log(chalk.cyan(`\n[${i + 1}] ${cmd.name}`));
        console.log(chalk.white(`  Contract: ${cmd.contract}`));
        console.log(chalk.gray(`  Saved: ${new Date(cmd.timestamp).toLocaleString()}`));
    });
    
    console.log('');
    const choice = readline.question(chalk.yellow('Select command to run (0 to cancel): '));
    const idx = parseInt(choice) - 1;
    
    if (idx < 0 || idx >= commands.length) {
        pause();
        return;
    }
    
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet loaded!'));
        pause();
        return;
    }
    
    const cmd = commands[idx];
    console.log(chalk.yellow('\n⏳ Executing command...\n'));
    
    try {
        const { client } = await getSigningCosmWasmClient();
        const msg = JSON.parse(cmd.message);
        const funds = cmd.funds ? [{ denom: getCurrentNetwork().denom, amount: cmd.funds.replace(/\D/g, '') }] : [];
        
        const result = await client.execute(
            wallet.address,
            cmd.contract,
            msg,
            'auto',
            `Execute: ${cmd.name}`,
            funds
        );
        
        console.log(chalk.green('\n✓ Execution successful!'));
        console.log(chalk.white('TX Hash:'), chalk.gray(result.transactionHash));
        console.log(chalk.white('Gas used:'), chalk.gray(result.gasUsed));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Execution failed: ${e.message}`));
    }
    
    pause();
}

async function deleteExecuteCommand() {
    console.log(chalk.cyan('\n🗑️  Delete Execute Command\n'));
    
    const commands = loadExecuteCommands();
    
    if (commands.length === 0) {
        console.log(chalk.yellow('No saved commands.'));
        pause();
        return;
    }
    
    commands.forEach((cmd, i) => {
        console.log(chalk.cyan(`[${i + 1}] ${cmd.name}`));
    });
    
    console.log('');
    const choice = readline.question(chalk.yellow('Select command to delete (0 to cancel): '));
    const idx = parseInt(choice) - 1;
    
    if (idx < 0 || idx >= commands.length) {
        pause();
        return;
    }
    
    const confirm = readline.question(chalk.red(`Delete "${commands[idx].name}"? (yes/no): `));
    if (confirm.toLowerCase() === 'yes') {
        commands.splice(idx, 1);
        saveExecuteCommands(commands);
        console.log(chalk.green('\n✓ Command deleted!'));
    }
    
    pause();
}

// ================================================================
// STAKING (Placeholder for future implementation)
// ================================================================

async function stakeTokens() {
    console.log(chalk.yellow('\n🚧 Stake Tokens - Coming Soon'));
    console.log(chalk.gray('This feature will be implemented based on Paxi staking contracts'));
    pause();
}

async function unstakeTokens() {
    console.log(chalk.yellow('\n🚧 Unstake Tokens - Coming Soon'));
    console.log(chalk.gray('This feature will be implemented based on Paxi staking contracts'));
    pause();
}

async function claimStakingRewards() {
    console.log(chalk.yellow('\n🚧 Claim Rewards - Coming Soon'));
    console.log(chalk.gray('This feature will be implemented based on Paxi staking contracts'));
    pause();
}

async function viewStakingInfo() {
    console.log(chalk.yellow('\n🚧 View Staking Info - Coming Soon'));
    console.log(chalk.gray('This feature will be implemented based on Paxi staking contracts'));
    pause();
}

// ================================================================
// SYSTEM
// ================================================================

function showDevInfo() {
    console.log(chalk.cyan('\n👨‍💻 Developer Info\n'));
    console.log(chalk.white(`Version: ${CONFIG.version}`));
    console.log(chalk.white(`Team: ${CONFIG.DEV_CONTRACT_AUTHOR}`));
    console.log(chalk.white(`Network: ${CONFIG.network.toUpperCase()}`));
    console.log(chalk.white(`Chain ID: ${CONFIG.chainId || 'Not loaded'}`));
    console.log(chalk.white(`\nRepository: github.com/einrika/dapps-cli-all-in-one`));
    console.log(chalk.white(`Discord: https://discord.gg/rA9Xzs69tx`));
    console.log(chalk.white(`Telegram: https://t.me/paxi_network`));
    console.log(chalk.white(`\nPaxi Network Documentation:`));
    console.log(chalk.gray(`https://paxinet.io/paxi_docs/developers`));
    pause();
}

async function settings() {
    console.log(chalk.cyan('\n⚙️  Settings\n'));
    console.log('1. Switch Network (Testnet/Mainnet)');
    console.log('2. Reset Config');
    console.log('3. Clear History');
    console.log('4. Clear Contracts');
    console.log('5. Logout (Delete Wallet)');
    console.log('0. Back');
    
    const choice = readline.question(chalk.yellow('\n» Select: '));
    
    switch(choice) {
        case '1':
            CONFIG.network = CONFIG.network === 'mainnet' ? 'testnet' : 'mainnet';
            CONFIG.chainId = '';
            await fetchChainId();
            saveConfig();
            console.log(chalk.green(`\n✓ Switched to ${CONFIG.network.toUpperCase()}`));
            break;
        case '2':
            CONFIG.chainId = '';
            saveConfig();
            console.log(chalk.green('\n✓ Config reset!'));
            break;
        case '3':
            if (fs.existsSync(HISTORY_FILE)) {
                fs.unlinkSync(HISTORY_FILE);
                console.log(chalk.green('\n✓ History cleared!'));
            }
            break;
        case '4':
            if (fs.existsSync(CONTRACTS_FILE)) {
                fs.unlinkSync(CONTRACTS_FILE);
                console.log(chalk.green('\n✓ Contracts cleared!'));
            }
            break;
        case '5':
            const confirm = readline.question(chalk.red('Delete wallet? (yes/no): '));
            if (confirm.toLowerCase() === 'yes') {
                if (fs.existsSync(WALLET_FILE)) {
                    fs.unlinkSync(WALLET_FILE);
                    console.log(chalk.green('\n✓ Wallet deleted!'));
                }
            }
            break;
    }
    
    if (choice !== '0') pause();
}

// ================================================================
// MAIN MENU
// ================================================================

async function mainMenuLoop() {
    loadConfig();
    
    while (true) {
        clearScreen();
        await showBanner();
        const net = getCurrentNetwork();
        const netColor = net.color;
   
        const options = [
            chalk.cyan.bold('╔═══ WALLET ═══╗'),
            '1.  🔑 Generate New Wallet',
            '2.  📥 Import from Mnemonic',
            '3.  📤 Send PAXI',
            '4.  📜 Transaction History',
            '5.  🔍 Show Address QR',
            '',
            chalk.cyan.bold('╔═══ PRC-20 TOKENS ═══╗'),
            '6.  🪙 Create PRC-20 Token',
            '7.  📤 Transfer PRC-20',
            '8.  💵 Check PRC-20 Balance',
            '9.  ⚒️  Mint Tokens',
            '10. 🔥 Burn Tokens',
            '11. 🔥 Burn From (Allowance)',
            '',
            chalk.cyan.bold('╔═══ ALLOWANCE MANAGEMENT ═══╗'),
            '12. ➕ Increase Allowance',
            '13. ➖ Decrease Allowance',
            '14. 🔍 Check Allowance',
            '15. 📤 Transfer From (Allowance)',
            '',
            chalk.cyan.bold('╔═══ CONTRACT MANAGEMENT ═══╗'),
            '16. 📤 Upload Contract',
            '17. 🎯 Instantiate Contract',
            '18. ⚡ Execute Contract',
            '19. 🔍 Query Contract',
            '',
            chalk.cyan.bold('╔═══ EXECUTE LIST ═══╗'),
            '20. 💾 Save Execute Command',
            '21. 📋 List & Run Saved Commands',
            '22. 🗑️  Delete Saved Command',
            '',
            chalk.cyan.bold(`╔═══ STAKING (by ${CONFIG.DEV_CONTRACT_AUTHOR}) ═══╗`),
            '23. 💎 Stake Tokens',
            '24. 🔓 Unstake Tokens',
            '25. 💰 Claim Rewards',
            '26. 📊 View Staking Info',
            '',
            chalk.cyan.bold('╔═══ SYSTEM ═══╗'),
            '27. 👨‍💻 Developer Info',
            '28. 💾 Export Wallet',
            '29. ⚙️  Settings',
            '',
            netColor(`» Current Network: ${net.name.toUpperCase()} (${CONFIG.chainId || 'Loading...'})`),
            '',
            '0.  🚪 Exit'
        ];
        
        options.forEach(opt => console.log(opt));
        const choice = readline.question(chalk.yellow('\n» Select: '));
        
        try {
            switch(choice) {
                case '1': await generateWallet(); break;
                case '2': await importWallet(); break;
                case '3': await sendPaxi(); break;
                case '4': await viewHistory(); break;
                case '5': showAddressQR(); break;
                case '6': await createPRC20(); break;
                case '7': await transferPRC20(); break;
                case '8': await checkPRC20Balance(); break;
                case '9': await mintPRC20(); break;
                case '10': await burnPRC20(); break;
                case '11': await burnFromPRC20(); break;
                case '12': await increaseAllowance(); break;
                case '13': await decreaseAllowance(); break;
                case '14': await checkAllowance(); break;
                case '15': await transferFromPRC20(); break;
                case '16': await uploadContract(); break;
                case '17': await instantiateContract(); break;
                case '18': await executeContract(); break;
                case '19': await queryContract(); break;
                case '20': await saveExecuteCommand(); break;
                case '21': await listExecuteCommands(); break;
                case '22': await deleteExecuteCommand(); break;
                case '23': await stakeTokens(); break;
                case '24': await unstakeTokens(); break;
                case '25': await claimStakingRewards(); break;
                case '26': await viewStakingInfo(); break;
                case '27': showDevInfo(); break;
                case '28': exportWallet(); break;
                case '29': await settings(); break;
                case '0': 
                    console.log(chalk.green('\n👋 Goodbye!\n'));
                    process.exit(0);
                default: 
                    console.log(chalk.red('\n✗ Invalid choice!'));
                    pause();
            }
        } catch (error) {
            console.log(chalk.red(`\n✗ Error: ${error.message}`));
            pause();
        }
    }
}

console.log(chalk.cyan('\n⏳ Initializing PaxiHub DApp (Full Implementation)...\n'));
setTimeout(() => {
    mainMenuLoop().catch(error => {
        console.error(chalk.red(`\n✗ Fatal: ${error.message}`));
        process.exit(1);
    });
}, 500);
DAPPEOF

chmod +x dapp.js
echo "$VERSION" > .version
show_progress 1
echo -e "${GREEN}✓ DApp v$VERSION created${NC}\n"
pause_and_clean

# [6/7] Shortcuts
echo -e "${CYAN}[6/7]${NC} ${BLUE}Creating shortcuts...${NC}"

cat > walletpaxi << 'SHORTCUTEOF'
#!/bin/bash
printf '\033c'
cd ~/paxi-dapp && node dapp.js
SHORTCUTEOF
chmod +x walletpaxi

cat > updated-walletpaxi << 'UPDATEEOF'
#!/bin/bash
printf '\033c'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🔄 PAXIHUB AUTO-UPDATE TOOL         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

if ! ping -c 1 github.com >/dev/null 2>&1; then
    echo -e "${RED}✗ No internet connection!${NC}"
    exit 1
fi

echo -e "${YELLOW}📡 Checking for updates...${NC}"

if [ -d ~/paxi-dapp ]; then
    echo -e "${YELLOW}📦 Backing up current installation...${NC}"
    BACKUP="paxi-dapp-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r ~/paxi-dapp ~/$BACKUP
    for file in wallet.json history.json config.json contracts.json execute_commands.json; do
        if [ -f ~/paxi-dapp/$file ]; then
            cp ~/paxi-dapp/$file ~/paxi-$file-backup.json
        fi
    done
    echo -e "${GREEN}✓ Backup created: ~/$BACKUP${NC}"
fi

echo -e "${CYAN}⬇️  Downloading latest version...${NC}"
cd ~ || exit 1
rm -f install.sh

if curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/paxiwallet.sh > paxiwallet.sh; then
    echo -e "${GREEN}✓ Downloaded${NC}"
else
    echo -e "${RED}✗ Download failed!${NC}"
    exit 1
fi

chmod +x paxiwallet.sh
echo ""
echo -e "${CYAN}🚀 Installing latest version...${NC}"
echo ""
bash paxiwallet.sh
rm -f paxiwallet.sh
echo ""
echo -e "${GREEN}✅ Update complete!${NC}"
echo ""
UPDATEEOF
chmod +x updated-walletpaxi

if ! grep -q "paxi-dapp" ~/.bashrc; then
    echo 'export PATH="$HOME/paxi-dapp:$PATH"' >> ~/.bashrc
    echo 'alias walletpaxi="cd ~/paxi-dapp && ./walletpaxi"' >> ~/.bashrc
    echo 'alias updated-walletpaxi="cd ~/paxi-dapp && ./updated-walletpaxi"' >> ~/.bashrc
fi

mkdir -p "${PREFIX:-$HOME/.local/bin}" 2>/dev/null || true
ln -sf ~/paxi-dapp/walletpaxi "${PREFIX:-$HOME/.local/bin}/walletpaxi" 2>/dev/null || true
ln -sf ~/paxi-dapp/updated-walletpaxi "${PREFIX:-$HOME/.local/bin}/updated-walletpaxi" 2>/dev/null || true

show_progress 0.5
echo -e "${GREEN}✓ Shortcuts ready${NC}\n"
pause_and_clean

# [7/7] Restore Data (if Update)
echo -e "${CYAN}[7/7]${NC} ${BLUE}Restoring data...${NC}"
if [ "$ACTION" == "2" ] && [ -d ~/paxi-data-backup ]; then
    echo -e "${YELLOW}⏳ Restoring backed up data...${NC}"
    for file in wallet.json config.json history.json contracts.json execute_commands.json; do
        if [ -f ~/paxi-data-backup/$file ]; then
            cp ~/paxi-data-backup/$file ~/paxi-dapp/
            echo -e "${GREEN}✓ Restored $file${NC}"
        fi
    done
    rm -rf ~/paxi-data-backup
    echo -e "${GREEN}✓ Restoration complete${NC}"
else
    echo -e "${GREEN}✓ No data to restore (Fresh install)${NC}"
fi
echo ""

# [8/8] Docs
echo -e "${CYAN}[8/8]${NC} ${BLUE}Creating docs...${NC}"

cat > README.md << 'READMEEOF'
# 🚀 PAXIHUB CREATE TOKEN PRC20 v3.2.0

## FULL IMPLEMENTATION - Complete with Mint, Burn, Allowance

## Quick Start
```bash
walletpaxi
```

## UI Fix v3.2.0
- ✅ **No Double Screen**: Menggunakan escape sequence `\x1Bc` untuk Termux
- ✅ **Clear Flow**: mainMenuLoop clear → pause clear → repeat
- ✅ **Reliable**: Tidak ada menu yang overlap/menumpuk

## Features v3.2.0
- ✅ **DUAL MODE**: Testnet + Mainnet switching
- ✅ **Auto ChainID**: Fetches from RPC /status
- ✅ **Persistent Wallet**: Until manual logout
- ✅ **Full CosmJS**: Real blockchain transactions
- ✅ **Contract Management**: Upload/Instantiate/Execute/Query
- ✅ **PRC-20 Support**: Complete CW20 implementation
  - Create Token
  - Transfer
  - Mint (minter only)
  - Burn
  - Burn From (with allowance)
  - Increase Allowance
  - Decrease Allowance
  - Check Allowance
  - Transfer From (with allowance)
- ✅ **Staking**: Placeholder for future implementation
- ✅ **Transaction History**: Blockchain + local
- ✅ **Execute Commands**: Save & run
- ✅ **UI Fixed**: No more double screen

## PRC-20 Functions

### Token Creation
Create PRC-20 tokens using Code ID 1 with full CW20 standard.

### Minting
Only the designated minter can mint new tokens.

### Burning
- **Burn**: Burn your own tokens
- **Burn From**: Burn tokens from another address (requires allowance)

### Allowance System
- **Increase Allowance**: Allow another address to spend your tokens
- **Decrease Allowance**: Reduce allowance for an address
- **Check Allowance**: View current allowance
- **Transfer From**: Transfer using allowance

## Auto-Update
```bash
updated-walletpaxi
```

## Developer Info
- Team: PaxiHub Team
- Version: 3.2.0
- GitHub: github.com/einrika/dapps-cli-all-in-one

## Support
- Discord: https://discord.gg/rA9Xzs69tx
- Telegram: https://t.me/paxi_network
- Docs: https://paxinet.io/paxi_docs/developers

## Based On
- Paxi Network Documentation
- CW20 Standard (CosmWasm)
- Cosmos SDK
READMEEOF

show_progress 0.5
echo -e "${GREEN}✓ Documentation created${NC}\n"
pause_and_clean

# SUCCESS
clean_screen
cat << "EOF"
╔════════════════════════════════════════════════╗
║  ✅  PROCESS COMPLETE v3.2.0                   ║
║     FULL PRC-20 with Mint/Burn/Allowance      ║
╚════════════════════════════════════════════════╝

📦 Location: ~/paxi-dapp
🚀 Launch: walletpaxi
🔄 Update: updated-walletpaxi

✨ NEW FEATURES:
  ✓ Complete PRC-20 implementation
  ✓ Mint tokens (minter only)
  ✓ Burn tokens (own & from allowance)
  ✓ Allowance management (increase/decrease/check)
  ✓ Transfer from allowance
  ✓ UI clear screen fixed
  ✓ All functions follow Paxi Network standards

👨‍💻 Dev Team: PaxiHub Team
📚 Docs: https://paxinet.io/paxi_docs/developers

EOF
echo ""

echo -e "${CYAN}Loading new commands...${NC}"
source ~/.bashrc 2>/dev/null || true
echo -e "${GREEN}✓ Commands loaded!${NC}"
echo ""

read -p "Launch now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf '\033c'
    cd ~/paxi-dapp || exit 1
    node dapp.js
else
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}To launch PaxiHub, use one of:${NC}"
    echo -e "${WHITE}1. walletpaxi${NC}         ${GRAY}(if already in PATH)${NC}"
    echo -e "${WHITE}2. cd ~/paxi-dapp && ./walletpaxi${NC}"
    echo -e "${WHITE}3. source ~/.bashrc && walletpaxi${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
fi
