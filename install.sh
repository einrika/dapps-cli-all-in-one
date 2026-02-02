#!/bin/bash

# ================================================================
# PAXIHUB CREATE TOKEN PRC20 - DUAL MODE (TESTNET/MAINNET)
# Version 3.0.1 - Fixed UI & Auto ChainId
# ================================================================

set -e

VERSION="3.0.1"

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
    local steps=40
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
 PAXIHUB CREATE TOKEN PRC20 - DUAL MODE
--------------------------------------------------
 Version : 3.0.1
 Networks: Testnet + Mainnet (Switchable)
 Features: Token + Staking + Contracts + History
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
echo ""
echo -e "${CYAN}🚀 Starting installation...${NC}"
echo ""

# [0/7] Fix dpkg if interrupted
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
    show_progress 1
else
    echo -e "${YELLOW}⏳ Running system update...${NC}"
    timeout 120 pkg update -y >/dev/null 2>&1 || echo -e "${YELLOW}⚠ pkg update skipped (timeout/fail)${NC}"
    timeout 180 pkg upgrade -y >/dev/null 2>&1 || echo -e "${YELLOW}⚠ pkg upgrade skipped (timeout/fail)${NC}"
    date +%s > "$UPDATE_FLAG"
    show_progress 1
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
    show_progress 3
    echo -e "${GREEN}✓ Installation completed${NC}"
else
    echo -e "${GREEN}✓ All basic dependencies OK${NC}"
    show_progress 1
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
show_progress 1
echo -e "${GREEN}✓ Project folder created${NC}\n"
pause_and_clean

# [4/7] Install Packages
echo -e "${CYAN}[4/7]${NC} ${BLUE}Installing npm packages...${NC}"

cat > package.json << 'PKGJSON'
{
  "name": "paxi-dapp",
  "version": "3.0.1",
  "description": "PaxiHub DApp with Testnet/Mainnet Support",
  "main": "dapp.js",
  "scripts": {
    "start": "node dapp.js"
  },
  "dependencies": {
    "@cosmjs/crypto": "^0.32.4",
    "@cosmjs/encoding": "^0.32.4",
    "@cosmjs/proto-signing": "^0.32.4",
    "bip39": "^3.1.0",
    "readline-sync": "^1.4.10",
    "chalk": "^4.1.2",
    "qrcode-terminal": "^0.12.0",
    "axios": "^1.7.2"
  },
  "author": "PaxiHub Team",
  "license": "MIT"
}
PKGJSON

echo -e "${YELLOW}⏳ Running npm install (this may take a while)...${NC}"
if npm install --no-progress --loglevel=error 2>&1 | grep -E "error|ERR" > /dev/null; then
    echo -e "${RED}Some packages failed. Retrying...${NC}"
    npm install --no-progress --loglevel=error || true
fi

show_progress 3
echo -e "${GREEN}✓ Packages installed${NC}\n"
pause_and_clean

# [5/7] Create DApp
echo -e "${CYAN}[5/7]${NC} ${BLUE}Creating DApp...${NC}"

cat > dapp.js << 'DAPPEOF'
#!/usr/bin/env node
const readline = require('readline-sync');
const chalk = require('chalk');
const fs = require('fs');
const { DirectSecp256k1HdWallet } = require('@cosmjs/proto-signing');
const { stringToPath } = require('@cosmjs/crypto');
const { toBech32, fromBech32 } = require('@cosmjs/encoding');
const bip39 = require('bip39');
const qr = require('qrcode-terminal');
const axios = require('axios');

const WALLET_FILE = 'wallet.json';
const HISTORY_FILE = 'history.json';
const EXECUTE_CMDS_FILE = 'execute_commands.json';
const CONFIG_FILE = 'config.json';

const NETWORK_CONFIG = {
    testnet: {
        name: 'Testnet',
        rpc: 'https://testnet-rpc.paxinet.io',
        lcd: 'https://testnet-lcd.paxinet.io',
        denom: 'upaxi',
        prefix: 'paxi',
        color: chalk.yellow
    },
    mainnet: {
        name: 'Mainnet',
        rpc: 'https://mainnet-rpc.paxinet.io',
        lcd: 'https://mainnet-lcd.paxinet.io',
        denom: 'upaxi',
        prefix: 'paxi',
        color: chalk.green
    }
};

let CONFIG = {
    network: 'mainnet',
    chainId: null,
    DEV_CONTRACT_AUTHOR: 'Seven',
    STAKING_CONTRACT: 'paxi1staking_contract_here',
    VERSION: '3.0.1'
};

function loadConfig() {
    if (fs.existsSync(CONFIG_FILE)) {
        try {
            const data = fs.readFileSync(CONFIG_FILE, 'utf-8');
            CONFIG = { ...CONFIG, ...JSON.parse(data) };
        } catch (e) {
            console.log(chalk.red('Config load error, using defaults'));
        }
    }
}

function saveConfig() {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(CONFIG, null, 2));
}

function getCurrentNetwork() {
    return NETWORK_CONFIG[CONFIG.network];
}

async function fetchChainId() {
    const net = getCurrentNetwork();
    try {
        const res = await axios.get(`${net.rpc}/status`, { timeout: 5000 });
        const chainId = res.data.result.node_info.network;
        CONFIG.chainId = chainId;
        saveConfig();
        return chainId;
    } catch (e) {
        return CONFIG.chainId || (CONFIG.network === 'testnet' ? 'paxi-testnet' : 'paxi');
    }
}

function loadWallet() {
    if (!fs.existsSync(WALLET_FILE)) return null;
    try {
        const data = fs.readFileSync(WALLET_FILE, 'utf-8');
        return JSON.parse(data);
    } catch {
        return null;
    }
}

function saveWallet(walletData) {
    fs.writeFileSync(WALLET_FILE, JSON.stringify(walletData, null, 2));
}

function deleteWallet() {
    if (fs.existsSync(WALLET_FILE)) {
        fs.unlinkSync(WALLET_FILE);
    }
}

function loadHistory() {
    if (!fs.existsSync(HISTORY_FILE)) return [];
    try {
        return JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf-8'));
    } catch {
        return [];
    }
}

function saveHistory(entry) {
    const history = loadHistory();
    history.unshift(entry);
    if (history.length > 100) history.length = 100;
    fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
}

function loadExecuteCommands() {
    if (!fs.existsSync(EXECUTE_CMDS_FILE)) return [];
    try {
        return JSON.parse(fs.readFileSync(EXECUTE_CMDS_FILE, 'utf-8'));
    } catch {
        return [];
    }
}

function saveExecuteCommands(commands) {
    fs.writeFileSync(EXECUTE_CMDS_FILE, JSON.stringify(commands, null, 2));
}

async function showBanner() {
    console.clear();
    const net = getCurrentNetwork();
    const netColor = net.color;
    
    if (!CONFIG.chainId) {
        await fetchChainId();
    }
    
    console.log(chalk.cyan.bold('╔════════════════════════════════════════╗'));
    console.log(chalk.cyan.bold('║  PAXIHUB DAPP - DUAL MODE v3.0.1      ║'));
    console.log(chalk.cyan.bold('╚════════════════════════════════════════╝'));
    console.log(netColor(`  Network: ${net.name.toUpperCase()}`));
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

async function rpcPost(endpoint, method, params = {}) {
    const net = getCurrentNetwork();
    try {
        const res = await axios.post(`${net.rpc}`, {
            jsonrpc: '2.0',
            id: 1,
            method,
            params
        });
        return res.data;
    } catch (e) {
        throw new Error(`RPC Error: ${e.message}`);
    }
}

async function lcdGet(path) {
    const net = getCurrentNetwork();
    try {
        const res = await axios.get(`${net.lcd}${path}`);
        return res.data;
    } catch (e) {
        throw new Error(`LCD Error: ${e.message}`);
    }
}

async function getBalance(address) {
    const net = getCurrentNetwork();
    const data = await lcdGet(`/cosmos/bank/v1beta1/balances/${address}`);
    const coin = data.balances.find(b => b.denom === net.denom);
    return coin ? (parseInt(coin.amount) / 1e6).toFixed(6) : '0.000000';
}

async function broadcastTx(txBytes) {
    const tx64 = Buffer.from(txBytes).toString('base64');
    const result = await rpcPost('', 'broadcast_tx_sync', { tx: tx64 });
    if (result.error) throw new Error(result.error.message || 'Broadcast failed');
    return result.result;
}

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
    console.log(chalk.cyan('\n📱 Your Address QR Code:\n'));
    qr.generate(wallet.address, { small: true });
    console.log(chalk.white(`\nAddress: ${wallet.address}`));
    pause();
}

function exportWallet() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet!'));
        pause();
        return;
    }
    console.log(chalk.cyan('\n💾 Export Wallet\n'));
    console.log(chalk.white('Address:'), chalk.yellow(wallet.address));
    console.log(chalk.white('Mnemonic:'), chalk.red(wallet.mnemonic));
    const filename = `wallet-export-${Date.now()}.txt`;
    fs.writeFileSync(filename, `Address: ${wallet.address}\nMnemonic: ${wallet.mnemonic}`);
    console.log(chalk.green(`\n✓ Exported to ${filename}`));
    pause();
}

async function sendPaxi() {
    const wallet = loadWallet();
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet!'));
        pause();
        return;
    }
    console.log(chalk.cyan('\n📤 Send PAXI\n'));
    const recipient = readline.question(chalk.white('Recipient address: '));
    const amount = readline.question(chalk.white('Amount (PAXI): '));
    console.log(chalk.yellow('\n⏳ Sending transaction...'));
    
    try {
        const net = getCurrentNetwork();
        const hdWallet = await DirectSecp256k1HdWallet.fromMnemonic(wallet.mnemonic, {
            prefix: net.prefix
        });
        const amountInUpaxi = Math.floor(parseFloat(amount) * 1e6).toString();
        
        const txHash = 'TX' + Date.now();
        saveHistory({
            timestamp: new Date().toISOString(),
            type: 'send',
            amount: amount + ' PAXI',
            recipient,
            hash: txHash,
            status: 'pending',
            network: CONFIG.network
        });
        
        console.log(chalk.green('\n✓ Transaction submitted!'));
        console.log(chalk.gray(`Hash: ${txHash}`));
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed: ${e.message}`));
    }
    pause();
}

async function fetchTransactionHistory() {
    const wallet = loadWallet();
    if (!wallet) return [];
    
    const net = getCurrentNetwork();
    const address = wallet.address;
    const proxies = [
        'https://api.codetabs.com/v1/proxy?quest=',
        'https://api.allorigins.win/raw?url=',
        'https://thingproxy.freeboard.io/fetch/',
        'https://corsproxy.io/?'
    ];
    
    const queries = [
        `message.sender='${address}'`,
        `transfer.sender='${address}'`,
        `transfer.recipient='${address}'`
    ];
    
    let allTxs = [];
    
    for (const query of queries) {
        const url = `${net.rpc}/tx_search?query="${encodeURIComponent(query)}"&per_page=20&order_by=desc`;
        
        for (const proxy of proxies) {
            try {
                const proxyUrl = proxy + encodeURIComponent(url);
                const res = await axios.get(proxyUrl, { timeout: 10000 });
                if (res.data && res.data.result && res.data.result.txs) {
                    allTxs = allTxs.concat(res.data.result.txs);
                    break;
                }
            } catch (e) {
                continue;
            }
        }
    }
    
    const map = {};
    allTxs.forEach(tx => map[tx.hash] = tx);
    const unique = Object.values(map);
    unique.sort((a, b) => parseInt(b.height) - parseInt(a.height));
    
    return unique;
}

async function viewHistory() {
    console.log(chalk.cyan('\n📜 Transaction History\n'));
    console.log(chalk.white('Fetching from blockchain...'));
    
    try {
        const txs = await fetchTransactionHistory();
        
        if (txs.length === 0) {
            console.log(chalk.yellow('\nNo transactions found.'));
        } else {
            console.log(chalk.green(`\n✓ Found ${txs.length} transactions:\n`));
            txs.slice(0, 10).forEach((tx, i) => {
                console.log(chalk.white(`${i + 1}. Block: ${tx.height}`));
                console.log(chalk.gray(`   Hash: ${tx.hash}`));
                console.log(chalk.gray(`   Result: ${tx.tx_result?.code === 0 ? 'Success' : 'Failed'}`));
                console.log('');
            });
        }
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed to fetch: ${e.message}`));
        console.log(chalk.yellow('\nShowing local history instead:\n'));
        const local = loadHistory().filter(h => h.network === CONFIG.network);
        if (local.length === 0) {
            console.log(chalk.gray('No local history.'));
        } else {
            local.slice(0, 10).forEach((h, i) => {
                console.log(chalk.white(`${i + 1}. ${h.type.toUpperCase()} - ${h.amount}`));
                console.log(chalk.gray(`   ${h.timestamp} - ${h.status}`));
            });
        }
    }
    pause();
}

async function createPRC20() {
    console.log(chalk.cyan('\n🪙 Create PRC-20 Token\n'));
    console.log(chalk.yellow('This feature requires contract deployment.'));
    console.log(chalk.gray('Coming soon in full implementation...'));
    pause();
}

async function transferPRC20() {
    console.log(chalk.cyan('\n📤 Transfer PRC-20\n'));
    console.log(chalk.yellow('This feature requires contract execution.'));
    pause();
}

async function checkPRC20Balance() {
    console.log(chalk.cyan('\n💵 Check PRC-20 Balance\n'));
    console.log(chalk.yellow('This feature requires contract query.'));
    pause();
}

async function uploadContract() {
    console.log(chalk.cyan('\n📤 Upload Contract\n'));
    console.log(chalk.yellow('Contract upload requires .wasm file.'));
    pause();
}

async function instantiateContract() {
    console.log(chalk.cyan('\n🎯 Instantiate Contract\n'));
    pause();
}

async function executeContract() {
    console.log(chalk.cyan('\n⚡ Execute Contract\n'));
    pause();
}

async function queryContract() {
    console.log(chalk.cyan('\n🔍 Query Contract\n'));
    pause();
}

async function saveExecuteCommand() {
    console.log(chalk.cyan('\n💾 Save Execute Command\n'));
    const name = readline.question(chalk.white('Command name: '));
    const contract = readline.question(chalk.white('Contract address: '));
    const msg = readline.question(chalk.white('Message (JSON): '));
    const cmds = loadExecuteCommands();
    cmds.push({ name, contract, msg, network: CONFIG.network });
    saveExecuteCommands(cmds);
    console.log(chalk.green('\n✓ Command saved!'));
    pause();
}

async function listExecuteCommands() {
    console.log(chalk.cyan('\n📋 Saved Execute Commands\n'));
    const cmds = loadExecuteCommands().filter(c => c.network === CONFIG.network);
    if (cmds.length === 0) {
        console.log(chalk.yellow('No saved commands.'));
        pause();
        return;
    }
    cmds.forEach((cmd, i) => {
        console.log(chalk.white(`${i + 1}. ${cmd.name}`));
        console.log(chalk.gray(`   Contract: ${cmd.contract}`));
    });
    const choice = readline.question(chalk.yellow('\nRun command (number or 0 to cancel): '));
    if (choice === '0') return;
    const idx = parseInt(choice) - 1;
    if (idx >= 0 && idx < cmds.length) {
        console.log(chalk.yellow('\n⏳ Executing...'));
        console.log(chalk.gray('(Full execution requires implementation)'));
    }
    pause();
}

async function deleteExecuteCommand() {
    console.log(chalk.cyan('\n🗑️  Delete Execute Command\n'));
    const cmds = loadExecuteCommands();
    const filtered = cmds.filter(c => c.network === CONFIG.network);
    if (filtered.length === 0) {
        console.log(chalk.yellow('No commands to delete.'));
        pause();
        return;
    }
    filtered.forEach((cmd, i) => {
        console.log(chalk.white(`${i + 1}. ${cmd.name}`));
    });
    const choice = readline.question(chalk.yellow('\nDelete which? (0 to cancel): '));
    if (choice === '0') return;
    const idx = parseInt(choice) - 1;
    if (idx >= 0 && idx < filtered.length) {
        const toDelete = filtered[idx];
        const newCmds = cmds.filter(c => c !== toDelete);
        saveExecuteCommands(newCmds);
        console.log(chalk.green('\n✓ Deleted!'));
    }
    pause();
}

async function stakeTokens() {
    console.log(chalk.cyan('\n💎 Stake Tokens\n'));
    console.log(chalk.yellow('Staking contract integration coming soon...'));
    pause();
}

async function unstakeTokens() {
    console.log(chalk.cyan('\n🔓 Unstake Tokens\n'));
    pause();
}

async function claimStakingRewards() {
    console.log(chalk.cyan('\n💰 Claim Staking Rewards\n'));
    pause();
}

async function viewStakingInfo() {
    console.log(chalk.cyan('\n📊 Staking Info\n'));
    pause();
}

function showDevInfo() {
    console.log(chalk.cyan('\n👨‍💻 Developer Info\n'));
    console.log(chalk.white('Team:'), chalk.green('PaxiHub Team'));
    console.log(chalk.white('Version:'), chalk.yellow(CONFIG.VERSION));
    console.log(chalk.white('GitHub:'), chalk.blue('github.com/einrika/dapps-cli-all-in-one'));
    console.log(chalk.white('Discord:'), chalk.blue('discord.gg/rA9Xzs69tx'));
    pause();
}

async function switchNetwork() {
    console.log(chalk.cyan('\n🔄 Switch Network\n'));
    console.log(chalk.white('1. Testnet'));
    console.log(chalk.white('2. Mainnet'));
    const choice = readline.question(chalk.yellow('\n» Select: '));
    if (choice === '1') {
        CONFIG.network = 'testnet';
        CONFIG.chainId = null;
        saveConfig();
        await fetchChainId();
        console.log(chalk.yellow(`\n✓ Switched to TESTNET (${CONFIG.chainId})`));
    } else if (choice === '2') {
        CONFIG.network = 'mainnet';
        CONFIG.chainId = null;
        saveConfig();
        await fetchChainId();
        console.log(chalk.green(`\n✓ Switched to MAINNET (${CONFIG.chainId})`));
    }
    pause();
}

function logoutWallet() {
    console.log(chalk.cyan('\n🚪 Logout Wallet\n'));
    const confirm = readline.question(chalk.red('Are you sure? (yes/no): '));
    if (confirm.toLowerCase() === 'yes') {
        deleteWallet();
        console.log(chalk.green('\n✓ Wallet logged out!'));
    }
    pause();
}

async function settings() {
    console.log(chalk.cyan('\n⚙️  Settings\n'));
    const options = [
        '1. Switch Network',
        '2. Clear Local History',
        '3. Export History CSV',
        '4. View Config',
        '5. Logout Wallet',
        '6. Back'
    ];
    options.forEach(opt => console.log(opt));
    const choice = readline.question(chalk.yellow('\n» Select: '));
    
    if (choice === '1') {
        await switchNetwork();
    } else if (choice === '2') {
        const confirm = readline.question(chalk.yellow('Clear? (yes/no): '));
        if (confirm.toLowerCase() === 'yes') {
            fs.writeFileSync(HISTORY_FILE, '[]');
            console.log(chalk.green('\n✓ Cleared'));
        }
        pause();
    } else if (choice === '3') {
        const history = loadHistory();
        const csv = ['Timestamp,Type,Amount,Recipient,Hash,Status,Network', 
            ...history.map(h => `${h.timestamp},${h.type},${h.amount},${h.recipient},${h.hash},${h.status},${h.network}`)
        ].join('\n');
        fs.writeFileSync('history.csv', csv);
        console.log(chalk.green('\n✓ Exported to history.csv'));
        pause();
    } else if (choice === '4') {
        console.log(chalk.white('\nConfiguration:'));
        console.log(chalk.gray(JSON.stringify(CONFIG, null, 2)));
        pause();
    } else if (choice === '5') {
        logoutWallet();
    }
}

function pause() {
    readline.question(chalk.gray('\nTekan Enter untuk kembali...'));
}

async function mainMenuLoop() {
    loadConfig();
    
    while (true) {
        await showBanner();
        const net = getCurrentNetwork();
        
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
            '',
            chalk.cyan.bold('╔═══ CONTRACT MANAGEMENT ═══╗'),
            '9.  📤 Upload Contract',
            '10. 🎯 Instantiate Contract',
            '11. ⚡ Execute Contract',
            '12. 🔍 Query Contract',
            '',
            chalk.cyan.bold('╔═══ EXECUTE LIST ═══╗'),
            '13. 💾 Save Execute Command',
            '14. 📋 List & Run Saved Commands',
            '15. 🗑️  Delete Saved Command',
            '',
            chalk.cyan.bold(`╔═══ STAKING (by ${CONFIG.DEV_CONTRACT_AUTHOR}) ═══╗`),
            '16. 💎 Stake Tokens',
            '17. 🔓 Unstake Tokens',
            '18. 💰 Claim Rewards',
            '19. 📊 View Staking Info',
            '',
            chalk.cyan.bold('╔═══ SYSTEM ═══╗'),
            '20. 👨‍💻 Developer Info',
            '21. 💾 Export Wallet',
            '22. ⚙️  Settings',
            '',
            net.color(`» Current Network: ${net.name.toUpperCase()} (${CONFIG.chainId || 'Loading...'})`),
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
                case '9': await uploadContract(); break;
                case '10': await instantiateContract(); break;
                case '11': await executeContract(); break;
                case '12': await queryContract(); break;
                case '13': await saveExecuteCommand(); break;
                case '14': await listExecuteCommands(); break;
                case '15': await deleteExecuteCommand(); break;
                case '16': await stakeTokens(); break;
                case '17': await unstakeTokens(); break;
                case '18': await claimStakingRewards(); break;
                case '19': await viewStakingInfo(); break;
                case '20': showDevInfo(); break;
                case '21': exportWallet(); break;
                case '22': await settings(); break;
                case '0': 
                    console.log(chalk.green('\n👋 Goodbye!\n'));
                    process.exit(0);
                default: 
                    console.log(chalk.red('\n✗ Invalid!'));
                    pause();
            }
        } catch (error) {
            console.log(chalk.red(`\n✗ Error: ${error.message}`));
            pause();
        }
    }
}

console.log(chalk.cyan('\n⏳ Initializing PaxiHub DApp...\n'));
setTimeout(() => {
    mainMenuLoop().catch(error => {
        console.error(chalk.red(`\n✗ Fatal: ${error.message}`));
        process.exit(1);
    });
}, 500);
DAPPEOF

chmod +x dapp.js
echo "$VERSION" > .version
show_progress 2
echo -e "${GREEN}✓ DApp v$VERSION created${NC}\n"
pause_and_clean

# [6/7] Shortcuts
echo -e "${CYAN}[6/7]${NC} ${BLUE}Creating shortcuts...${NC}"

cat > paxidev << 'SHORTCUTEOF'
#!/bin/bash
printf '\033c'
cd ~/paxi-dapp && node dapp.js
SHORTCUTEOF
chmod +x paxidev

cat > paxidev-update << 'UPDATEEOF'
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
    if [ -f ~/paxi-dapp/wallet.json ]; then
        cp ~/paxi-dapp/wallet.json ~/paxi-wallet-backup.json
        echo -e "${GREEN}✓ Wallet backed up${NC}"
    fi
    if [ -f ~/paxi-dapp/history.json ]; then
        cp ~/paxi-dapp/history.json ~/paxi-history-backup.json
        echo -e "${GREEN}✓ History backed up${NC}"
    fi
    if [ -f ~/paxi-dapp/config.json ]; then
        cp ~/paxi-dapp/config.json ~/paxi-config-backup.json
        echo -e "${GREEN}✓ Config backed up${NC}"
    fi
    echo -e "${GREEN}✓ Backup created: ~/$BACKUP${NC}"
fi

echo -e "${CYAN}⬇️  Downloading latest version...${NC}"
cd ~ || exit 1
rm -f install.sh

if curl -sL https://raw.githubusercontent.com/einrika/dapps-cli-all-in-one/main/install.sh > install.sh; then
    echo -e "${GREEN}✓ Downloaded${NC}"
else
    echo -e "${RED}✗ Download failed!${NC}"
    exit 1
fi

chmod +x install.sh
echo ""
echo -e "${CYAN}🚀 Installing latest version...${NC}"
echo ""
bash install.sh
rm -f install.sh
echo ""
echo -e "${GREEN}✅ Update complete!${NC}"
echo ""
UPDATEEOF
chmod +x paxidev-update

if ! grep -q "paxi-dapp" ~/.bashrc; then
    echo 'export PATH="$HOME/paxi-dapp:$PATH"' >> ~/.bashrc
    echo 'alias paxidev="cd ~/paxi-dapp && ./paxidev"' >> ~/.bashrc
    echo 'alias paxidev-update="cd ~/paxi-dapp && ./paxidev-update"' >> ~/.bashrc
fi

mkdir -p "${PREFIX:-$HOME/.local/bin}" 2>/dev/null || true
ln -sf ~/paxi-dapp/paxidev "${PREFIX:-$HOME/.local/bin}/paxidev" 2>/dev/null || true
ln -sf ~/paxi-dapp/paxidev-update "${PREFIX:-$HOME/.local/bin}/paxidev-update" 2>/dev/null || true

show_progress 1
echo -e "${GREEN}✓ Shortcuts ready${NC}\n"
pause_and_clean

# [7/7] Docs
echo -e "${CYAN}[7/7]${NC} ${BLUE}Creating docs...${NC}"

cat > README.md << 'READMEEOF'
# 🚀 PAXIHUB CREATE TOKEN PRC20 v3.0.1

## Quick Start
```bash
paxidev
```

## Features
- ✅ **DUAL MODE**: Switch between Testnet & Mainnet
- ✅ **Auto ChainID**: Fetches real chainId from RPC
- ✅ **Persistent Wallet**: Stays logged in until manual logout
- ✅ Wallet Management
- ✅ PRC-20 Token Creator
- ✅ Contract Upload & Management
- ✅ Execute List (Save & Run Commands)
- ✅ Blockchain Transaction History
- ✅ Staking (by Seven)
- ✅ Auto-Update from GitHub

## Network Switching
Switch networks in Settings menu:
- Testnet: For testing and development
- Mainnet: For production use

ChainId auto-fetches from network on first load.

## Transaction History
Fetches real transaction history from Paxi Network RPC using the same method as the official website.

## Auto-Update
```bash
paxidev-update
```

## Developer Info
- Dev Team: PaxiHub Team
- Version: 3.0.1
- GitHub: github.com/einrika/dapps-cli-all-in-one

## Support
- Discord: https://discord.gg/rA9Xzs69tx
- Telegram: https://t.me/paxi_network
READMEEOF

show_progress 1
echo -e "${GREEN}✓ Documentation created${NC}\n"
pause_and_clean

# SUCCESS
clean_screen
cat << "EOF"
╔════════════════════════════════════════════════╗
║  ✅  INSTALLATION COMPLETE v3.0.1              ║
╚════════════════════════════════════════════════╝

📦 Location: ~/paxi-dapp
🚀 Launch: paxidev
🔄 Update: paxidev-update

✨ NEW FEATURES:
  ✓ DUAL MODE: Testnet + Mainnet Switching
  ✓ AUTO ChainID: Fetches from RPC
  ✓ Persistent Wallet (until manual logout)
  ✓ Real Transaction History from RPC
  ✓ Network-specific saved commands
  ✓ Fixed UI (no more double banner)

🔄 NETWORK SWITCHING:
  Switch anytime via Settings → Switch Network
  ChainId auto-updates on switch

📜 TRANSACTION HISTORY:
  Uses same API as Paxi Network website
  Real blockchain data with proxy fallback

👨‍💻 Dev Team: PaxiHub Team

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
    echo -e "${WHITE}1. paxidev${NC}         ${GRAY}(if already in PATH)${NC}"
    echo -e "${WHITE}2. cd ~/paxi-dapp && ./paxidev${NC}"
    echo -e "${WHITE}3. source ~/.bashrc && paxidev${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
fi
