#!/bin/bash

# ================================================================
# PAXIHUB CREATE TOKEN PRC20 - COMPLETE INSTALLER
# Version 2.0.4 - FULL (Upload + Stake + Execute List + Auto-Update)
# ================================================================

set -e

VERSION="2.0.4"

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
 PAXIHUB CREATE TOKEN PRC20
--------------------------------------------------
 Version : 2.0.4
 Network : Paxi Mainnet
 Features: Token + Staking + Contracts
 Dev     : PaxiHub seven Team
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

# [1/7] System Update
echo -e "${CYAN}[1/7]${NC} ${BLUE}Updating system...${NC}"

UPDATE_FLAG="$HOME/.paxihub_last_update"
NOW_TS=$(date +%s)
MAX_AGE=86400 # 24 jam

if [ -f "$UPDATE_FLAG" ] && [ $((NOW_TS - $(cat "$UPDATE_FLAG" 2>/dev/null || echo 0))) -lt $MAX_AGE ]; then
    echo -e "${GREEN}✓ System already updated recently, skipped${NC}"
    show_progress 1
else
    echo -e "${YELLOW}⏳ Running system update...${NC}"

    timeout 120 pkg update -y >/dev/null 2>&1 \
        || echo -e "${YELLOW}⚠ pkg update skipped (timeout/fail)${NC}"

    timeout 180 pkg upgrade -y >/dev/null 2>&1 \
        || echo -e "${YELLOW}⚠ pkg upgrade skipped (timeout/fail)${NC}"

    date +%s > "$UPDATE_FLAG"

    show_progress 1
    echo -e "${GREEN}✓ System update finished${NC}"
fi

echo ""

# [2/7] Dependencies
clean_screen
echo -e "${CYAN}[2/7]${NC} ${BLUE}Smart dependency check...${NC}"

DEPS_TO_INSTALL=""
if ! check_installed node; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL nodejs"; fi
if ! check_installed git; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL git"; fi
if ! check_installed wget; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"; fi
if ! check_installed curl; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL curl"; fi
if ! check_installed bc; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL bc"; fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    echo -e "${YELLOW}Installing:$DEPS_TO_INSTALL${NC}"
    pkg install -y $DEPS_TO_INSTALL > /dev/null 2>&1 || true
    show_progress 3
else
    echo -e "${GREEN}✓ All dependencies installed${NC}"
    show_progress 1
fi

NODE_VER=$(node --version 2>/dev/null || echo "node-not-found")
echo -e "${GREEN}✓ Node.js ${NODE_VER} ready${NC}\n"
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
echo -e "${GREEN}✓ Project created${NC}\n"
pause_and_clean

# [4/7] NPM Packages
echo -e "${CYAN}[4/7]${NC} ${BLUE}Installing NPM packages...${NC}"

cat > package.json << 'PKGJSON'
{
  "name": "paxi-dapp",
  "version": "2.0.4",
  "description": "PaxiHub - Complete Token Creator + Staking",
  "main": "dapp.js",
  "scripts": { "start": "node dapp.js" },
  "keywords": ["paxi", "blockchain", "wallet", "staking"],
  "author": "PaxiHub Team",
  "license": "MIT",
  "dependencies": {
    "@cosmjs/amino": "^0.32.4",
    "@cosmjs/proto-signing": "^0.32.4",
    "@cosmjs/stargate": "^0.32.4",
    "@cosmjs/cosmwasm-stargate": "^0.32.4",
    "bip39": "^3.1.0",
    "bip32": "^4.0.0",
    "readline-sync": "^1.4.10",
    "chalk": "^4.1.2",
    "cli-table3": "^0.6.5",
    "qrcode-terminal": "^0.12.0",
    "axios": "^1.7.2",
    "dotenv": "^16.4.5",
    "figlet": "^1.7.0"
  }
}
PKGJSON

echo -e "${YELLOW}Installing packages...${NC}"
npm install --no-audit --no-fund
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ npm install gagal. Hentikan installer.${NC}"
    exit 1
fi
show_progress 4
echo -e "${GREEN}✓ All packages installed${NC}\n"
pause_and_clean

# [5/7] Create DApp
echo -e "${CYAN}[5/7]${NC} ${BLUE}Creating DApp v${VERSION}...${NC}"

cat > dapp.js << 'DAPPEOF'
#!/usr/bin/env node
const readline = require('readline-sync');
const fs = require('fs');
const bip39 = require('bip39');
const chalk = require('chalk');
const Table = require('cli-table3');
const qrcode = require('qrcode-terminal');
const figlet = require('figlet');
const axios = require('axios');
const { DirectSecp256k1HdWallet } = require('@cosmjs/proto-signing');
const { SigningStargateClient, GasPrice, coins } = require('@cosmjs/stargate');
const { SigningCosmWasmClient } = require('@cosmjs/cosmwasm-stargate');

const CONFIG = {
    VERSION: '2.0.4',
    RPC: 'https://mainnet-rpc.paxinet.io',
    LCD: 'https://mainnet-lcd.paxinet.io',
    PREFIX: 'paxi',
    DENOM: 'upaxi',
    DECIMALS: 6,
    GAS_PRICE: '0.0625upaxi',
    CHAIN_ID: 'paxi-mainnet',
    PRC20_CODE_ID: 1,
    DEV_TEAM: 'PaxiHub Team',
    DEV_CONTRACT_AUTHOR: 'Manz',
    STAKE_TOKEN: 'paxi12rtyqvnevgzeyfjmr6z456ap3hrt9j2kjgvkm6qfn4ak6aqcgf5qtrv008',
    STAKE_CONTRACT: 'paxi1arzvvpl6f24zdzauy7skdn2pweaynqa8mf2722wn248wgx8nswzqjkl9r7'
};

let wallet = null, client = null, wasmClient = null, address = null, mnemonic = null;

function clearScreen() { process.stdout.write('\x1Bc'); }

async function showBanner() {
    clearScreen();
    try { console.log(chalk.cyan(figlet.textSync('PAXIHUB', { font: 'Standard' }))); }
    catch (e) { console.log(chalk.cyan('PAXIHUB')); }
    console.log(chalk.gray('─'.repeat(50)));
    console.log(chalk.yellow('  TOKEN CREATOR + STAKING + CONTRACTS'));
    console.log(chalk.gray(`  v${CONFIG.VERSION} • Dev: ${CONFIG.DEV_TEAM}`));
    console.log(chalk.gray('─'.repeat(50)));
    if (wallet && address) {
        try {
            const balance = await client.getBalance(address, CONFIG.DENOM);
            const paxi = toHuman(balance.amount);
            console.log(chalk.green(`\n✓ ${address.substring(0,15)}...${address.slice(-10)}`));
            console.log(chalk.white(`  Balance: ${paxi} PAXI`));
        } catch (e) { console.log(chalk.gray('\nBalance: Loading...')); }
    }
    console.log('');
}

function toHuman(micro, decimals = CONFIG.DECIMALS) {
    if (!micro) return '0';
    const value = BigInt(micro.toString()), base = BigInt(10) ** BigInt(decimals);
    const intPart = value / base, fracPart = value % base;
    const fracStr = fracPart.toString().padStart(decimals, '0').replace(/0+$/, '');
    return fracStr ? `${intPart}.${fracStr}` : intPart.toString();
}

function toMicro(human, decimals = CONFIG.DECIMALS) {
    const [intPart, fracPart = ''] = human.toString().split('.');
    const paddedFrac = fracPart.padEnd(decimals, '0').substring(0, decimals);
    return (BigInt(intPart) * BigInt(10) ** BigInt(decimals) + BigInt(paddedFrac)).toString();
}

function pause() { readline.question(chalk.gray('\nTekan Enter untuk lanjut...')); }

function loadHistory() {
    try { return JSON.parse(fs.readFileSync('history.json', 'utf8')); }
    catch { return []; }
}

function saveHistory(entry) {
    const history = loadHistory();
    history.unshift({ ...entry, timestamp: new Date().toISOString() });
    fs.writeFileSync('history.json', JSON.stringify(history.slice(0, 50), null, 2));
}

async function generateWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔑 GENERATE NEW WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    mnemonic = bip39.generateMnemonic(256);
    wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonic, { prefix: CONFIG.PREFIX });
    [{ address }] = await wallet.getAccounts();
    client = await SigningStargateClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    wasmClient = await SigningCosmWasmClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    console.log(chalk.green('\n✓ Wallet created!'));
    console.log(chalk.white(`\nAddress: ${address}`));
    console.log(chalk.yellow('\n⚠️  Save your mnemonic (24 words):'));
    console.log(chalk.red(mnemonic));
    console.log(chalk.red('\nNEVER share with anyone!'));
    pause();
}

async function importWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📥 IMPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.yellow('\nEnter your 24-word mnemonic:'));
    mnemonic = readline.question('');
    if (!bip39.validateMnemonic(mnemonic)) {
        console.log(chalk.red('\n✗ Invalid mnemonic!'));
        return pause();
    }
    wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonic, { prefix: CONFIG.PREFIX });
    [{ address }] = await wallet.getAccounts();
    client = await SigningStargateClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    wasmClient = await SigningCosmWasmClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    const balance = await client.getBalance(address, CONFIG.DENOM);
    console.log(chalk.green('\n✓ Wallet imported!'));
    console.log(chalk.white(`Address: ${address}`));
    console.log(chalk.white(`Balance: ${toHuman(balance.amount)} PAXI`));
    pause();
}

async function sendPaxi() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet! Generate or import first.')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 SEND PAXI'));
    console.log(chalk.cyan('═'.repeat(50)));
    const balance = await client.getBalance(address, CONFIG.DENOM);
    console.log(chalk.white(`\nBalance: ${toHuman(balance.amount)} PAXI`));
    const recipient = readline.question(chalk.yellow('\nRecipient address: '));
    const amount = readline.question(chalk.yellow('Amount (PAXI): '));
    const microAmount = toMicro(amount);
    console.log(chalk.yellow(`\n⏳ Sending ${amount} PAXI...`));
    try {
        const result = await client.sendTokens(address, recipient, coins(microAmount, CONFIG.DENOM), 'auto');
        console.log(chalk.green('\n✓ Success!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
        saveHistory({ type: 'send', amount, recipient, hash: result.transactionHash, status: 'success' });
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
        saveHistory({ type: 'send', amount, recipient, hash: 'N/A', status: 'failed' });
    }
    pause();
}

async function viewHistory() {
    await showBanner();
    const history = loadHistory();
    if (!history.length) { console.log(chalk.yellow('\nNo history yet.')); return pause(); }
    const table = new Table({ head: ['Time', 'Type', 'Amount', 'Recipient/Token', 'Status'] });
    history.slice(0, 10).forEach(h => {
        table.push([
            new Date(h.timestamp).toLocaleString(),
            h.type,
            h.amount || 'N/A',
            (h.recipient || h.tokenAddress || 'N/A').substring(0, 20),
            h.status === 'success' ? chalk.green('✓') : chalk.red('✗')
        ]);
    });
    console.log(table.toString());
    pause();
}

function showAddressQR() {
    if (!address) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    clearScreen();
    console.log(chalk.cyan('\n📱 YOUR ADDRESS QR CODE:\n'));
    qrcode.generate(address, { small: true });
    console.log(chalk.white(`\n${address}`));
    pause();
}

async function createPRC20() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🪙 CREATE PRC-20 TOKEN'));
    console.log(chalk.cyan('═'.repeat(50)));
    const name = readline.question(chalk.yellow('\nToken Name: '));
    const symbol = readline.question(chalk.yellow('Symbol: '));
    const decimals = readline.question(chalk.yellow('Decimals (e.g., 6): '));
    const supply = readline.question(chalk.yellow('Total Supply: '));
    const microSupply = toMicro(supply, parseInt(decimals));
    const initMsg = { name, symbol, decimals: parseInt(decimals), initial_balances: [{ address, amount: microSupply }], mint: { minter: address } };
    console.log(chalk.yellow('\n⏳ Creating token...'));
    try {
        const result = await wasmClient.instantiate(address, CONFIG.PRC20_CODE_ID, initMsg, symbol, 'auto');
        console.log(chalk.green('\n✓ Token created!'));
        console.log(chalk.white(`Contract: ${result.contractAddress}`));
        saveHistory({ type: 'create_token', amount: supply, tokenAddress: result.contractAddress, status: 'success' });
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function transferPRC20() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 TRANSFER PRC-20'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nToken contract: '));
    const recipient = readline.question(chalk.yellow('Recipient: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const msg = { transfer: { recipient, amount } };
    console.log(chalk.yellow('\n⏳ Transferring...'));
    try {
        const result = await wasmClient.execute(address, contract, msg, 'auto');
        console.log(chalk.green('\n✓ Success!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function checkPRC20Balance() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💵 CHECK PRC-20 BALANCE'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nToken contract: '));
    const query = { balance: { address } };
    try {
        const result = await wasmClient.queryContractSmart(contract, query);
        console.log(chalk.green('\n✓ Balance:'));
        console.log(chalk.white(JSON.stringify(result, null, 2)));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function uploadContract() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 UPLOAD CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const wasmPath = readline.question(chalk.yellow('\nPath to .wasm file: '));
    if (!fs.existsSync(wasmPath)) { console.log(chalk.red('\n✗ File not found!')); return pause(); }
    const wasmCode = fs.readFileSync(wasmPath);
    console.log(chalk.yellow('\n⏳ Uploading...'));
    try {
        const result = await wasmClient.upload(address, wasmCode, 'auto');
        console.log(chalk.green('\n✓ Uploaded!'));
        console.log(chalk.white(`Code ID: ${result.codeId}`));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function instantiateContract() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🎯 INSTANTIATE CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const codeId = parseInt(readline.question(chalk.yellow('\nCode ID: ')));
    const label = readline.question(chalk.yellow('Label: '));
    console.log(chalk.yellow('Init message (JSON):'));
    const msgStr = readline.question('');
    const initMsg = JSON.parse(msgStr);
    console.log(chalk.yellow('\n⏳ Instantiating...'));
    try {
        const result = await wasmClient.instantiate(address, codeId, initMsg, label, 'auto');
        console.log(chalk.green('\n✓ Instantiated!'));
        console.log(chalk.white(`Contract: ${result.contractAddress}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function executeContract() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  ⚡ EXECUTE CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract address: '));
    console.log(chalk.yellow('Execute message (JSON):'));
    const msgStr = readline.question('');
    const msg = JSON.parse(msgStr);
    console.log(chalk.yellow('\n⏳ Executing...'));
    try {
        const result = await wasmClient.execute(address, contract, msg, 'auto');
        console.log(chalk.green('\n✓ Executed!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function queryContract() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔍 QUERY CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract address: '));
    console.log(chalk.yellow('Query message (JSON):'));
    const msgStr = readline.question('');
    const query = JSON.parse(msgStr);
    try {
        const result = await wasmClient.queryContractSmart(contract, query);
        console.log(chalk.green('\n✓ Result:'));
        console.log(chalk.white(JSON.stringify(result, null, 2)));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

function loadExecuteList() {
    try { return JSON.parse(fs.readFileSync('execute_list.json', 'utf8')); }
    catch { return []; }
}

function saveExecuteList(list) {
    fs.writeFileSync('execute_list.json', JSON.stringify(list, null, 2));
}

async function saveExecuteCommand() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💾 SAVE EXECUTE COMMAND'));
    console.log(chalk.cyan('═'.repeat(50)));
    const name = readline.question(chalk.yellow('\nCommand name: '));
    const contract = readline.question(chalk.yellow('Contract address: '));
    console.log(chalk.yellow('Execute message (JSON):'));
    const msgStr = readline.question('');
    const list = loadExecuteList();
    list.push({ name, contract, message: msgStr });
    saveExecuteList(list);
    console.log(chalk.green('\n✓ Command saved!'));
    pause();
}

async function listExecuteCommands() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    const list = loadExecuteList();
    if (!list.length) { console.log(chalk.yellow('\nNo saved commands.')); return pause(); }
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📋 SAVED COMMANDS'));
    console.log(chalk.cyan('═'.repeat(50)));
    list.forEach((cmd, i) => {
        console.log(chalk.white(`\n${i + 1}. ${cmd.name}`));
        console.log(chalk.gray(`   Contract: ${cmd.contract}`));
    });
    const choice = readline.question(chalk.yellow('\nRun command #: '));
    const idx = parseInt(choice) - 1;
    if (idx < 0 || idx >= list.length) { console.log(chalk.red('\n✗ Invalid!')); return pause(); }
    const cmd = list[idx];
    console.log(chalk.yellow('\n⏳ Executing...'));
    try {
        const result = await wasmClient.execute(address, cmd.contract, JSON.parse(cmd.message), 'auto');
        console.log(chalk.green('\n✓ Executed!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function deleteExecuteCommand() {
    await showBanner();
    const list = loadExecuteList();
    if (!list.length) { console.log(chalk.yellow('\nNo saved commands.')); return pause(); }
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🗑️  DELETE COMMAND'));
    console.log(chalk.cyan('═'.repeat(50)));
    list.forEach((cmd, i) => console.log(chalk.white(`${i + 1}. ${cmd.name}`)));
    const choice = readline.question(chalk.yellow('\nDelete command #: '));
    const idx = parseInt(choice) - 1;
    if (idx < 0 || idx >= list.length) { console.log(chalk.red('\n✗ Invalid!')); return pause(); }
    list.splice(idx, 1);
    saveExecuteList(list);
    console.log(chalk.green('\n✓ Deleted!'));
    pause();
}

async function stakeTokens() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💎 STAKE TOKENS'));
    console.log(chalk.cyan('═'.repeat(50)));
    const amount = readline.question(chalk.yellow('\nAmount to stake: '));
    const msg = { send: { contract: CONFIG.STAKE_CONTRACT, amount, msg: btoa(JSON.stringify({ stake: {} })) } };
    console.log(chalk.yellow('\n⏳ Staking...'));
    try {
        const result = await wasmClient.execute(address, CONFIG.STAKE_TOKEN, msg, 'auto');
        console.log(chalk.green('\n✓ Staked!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function unstakeTokens() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔓 UNSTAKE TOKENS'));
    console.log(chalk.cyan('═'.repeat(50)));
    const amount = readline.question(chalk.yellow('\nAmount to unstake: '));
    const msg = { unstake: { amount } };
    console.log(chalk.yellow('\n⏳ Unstaking...'));
    try {
        const result = await wasmClient.execute(address, CONFIG.STAKE_CONTRACT, msg, 'auto');
        console.log(chalk.green('\n✓ Unstaked!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function claimStakingRewards() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💰 CLAIM REWARDS'));
    console.log(chalk.cyan('═'.repeat(50)));
    const msg = { claim_rewards: {} };
    console.log(chalk.yellow('\n⏳ Claiming...'));
    try {
        const result = await wasmClient.execute(address, CONFIG.STAKE_CONTRACT, msg, 'auto');
        console.log(chalk.green('\n✓ Claimed!'));
        console.log(chalk.white(`TxHash: ${result.transactionHash}`));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

async function viewStakingInfo() {
    if (!wallet) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📊 STAKING INFO'));
    console.log(chalk.cyan('═'.repeat(50)));
    const query = { staker_info: { staker: address } };
    try {
        const result = await wasmClient.queryContractSmart(CONFIG.STAKE_CONTRACT, query);
        console.log(chalk.green('\n✓ Info:'));
        console.log(chalk.white(JSON.stringify(result, null, 2)));
    } catch (error) {
        console.log(chalk.red(`\n✗ Failed: ${error.message}`));
    }
    pause();
}

function showDevInfo() {
    clearScreen();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  👨‍💻 DEVELOPER INFO'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.white('\nDev Team: ' + CONFIG.DEV_TEAM));
    console.log(chalk.white('Contract Author: ' + CONFIG.DEV_CONTRACT_AUTHOR));
    console.log(chalk.white('Version: ' + CONFIG.VERSION));
    console.log(chalk.white('\nSupport:'));
    console.log(chalk.gray('  Discord: https://discord.gg/rA9Xzs69tx'));
    console.log(chalk.gray('  Telegram: https://t.me/paxi_network'));
    console.log(chalk.gray('  GitHub: https://github.com/einrika/dapps-cli-all-in-one'));
    pause();
}

function exportWallet() {
    if (!mnemonic) { console.log(chalk.red('\n✗ No wallet!')); return pause(); }
    clearScreen();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💾 EXPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.yellow('\n⚠️  Your 24-word mnemonic:'));
    console.log(chalk.red(mnemonic));
    console.log(chalk.red('\nNEVER share!'));
    pause();
}

async function settings() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  ⚙️  SETTINGS'));
    console.log(chalk.cyan('═'.repeat(50)));
    const options = ['\n1. Clear Local History', '2. Export History CSV', '3. View Config', '4. Back'];
    options.forEach(opt => console.log(opt));
    const choice = readline.question(chalk.yellow('\n» Select: '));
    if (choice === '1') {
        const confirm = readline.question(chalk.yellow('Clear? (yes/no): '));
        if (confirm.toLowerCase() === 'yes') {
            fs.writeFileSync('history.json', '[]');
            console.log(chalk.green('\n✓ Cleared'));
        }
    } else if (choice === '2') {
        const history = loadHistory();
        const csv = ['Timestamp,Type,Amount,Recipient,Hash,Status', ...history.map(h => `${h.timestamp},${h.type},${h.amount},${h.recipient},${h.hash},${h.status}`)].join('\n');
        fs.writeFileSync('history.csv', csv);
        console.log(chalk.green('\n✓ Exported to history.csv'));
    } else if (choice === '3') {
        console.log(chalk.white('\nConfiguration:'));
        console.log(chalk.gray(JSON.stringify(CONFIG, null, 2)));
    }
    pause();
}

async function mainMenuLoop() {
    while (true) {
        await showBanner();
        const options = [
            '', chalk.cyan.bold('╔═══ WALLET ═══╗'),
            '1.  🔑 Generate New Wallet', '2.  📥 Import from Mnemonic', '3.  📤 Send PAXI', '4.  📜 Transaction History', '5.  🔍 Show Address QR',
            '', chalk.cyan.bold('╔═══ PRC-20 TOKENS ═══╗'),
            '6.  🪙 Create PRC-20 Token', '7.  📤 Transfer PRC-20', '8.  💵 Check PRC-20 Balance',
            '', chalk.cyan.bold('╔═══ CONTRACT MANAGEMENT ═══╗'),
            '9.  📤 Upload Contract', '10. 🎯 Instantiate Contract', '11. ⚡ Execute Contract', '12. 🔍 Query Contract',
            '', chalk.cyan.bold('╔═══ EXECUTE LIST ═══╗'),
            '13. 💾 Save Execute Command', '14. 📋 List & Run Saved Commands', '15. 🗑️  Delete Saved Command',
            '', chalk.cyan.bold(`╔═══ STAKING (by ${CONFIG.DEV_CONTRACT_AUTHOR}) ═══╗`),
            '16. 💎 Stake Tokens', '17. 🔓 Unstake Tokens', '18. 💰 Claim Rewards', '19. 📊 View Staking Info',
            '', chalk.cyan.bold('╔═══ SYSTEM ═══╗'),
            '20. 👨‍💻 Developer Info', '21. 💾 Export Wallet', '22. ⚙️  Settings',
            '', '0.  🚪 Exit'
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
                case '0': console.log(chalk.green('\n👋 Goodbye!\n')); process.exit(0);
                default: console.log(chalk.red('\n✗ Invalid!'));
            }
        } catch (error) { console.log(chalk.red(`\n✗ Error: ${error.message}`)); }
        readline.question(chalk.gray('\nTekan Enter untuk kembali ke menu...'));
    }
}

console.log(chalk.cyan('\n⏳ Initializing PaxiHub DApp...\n'));
setTimeout(() => { mainMenuLoop().catch(error => { console.error(chalk.red(`\n✗ Fatal: ${error.message}`)); process.exit(1); }); }, 500);
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
    if [ -f ~/paxi-dapp/history.json ]; then
        cp ~/paxi-dapp/history.json ~/paxi-history-backup.json
        echo -e "${GREEN}✓ History backed up${NC}"
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
# 🚀 PAXIHUB CREATE TOKEN PRC20 v2.0.4

## Quick Start
```bash
paxidev
```

## Auto-Update
```bash
paxidev-update
```

## Features
- ✅ Wallet Management
- ✅ PRC-20 Token Creator
- ✅ Contract Upload & Management
- ✅ Execute List (Save & Run Commands)
- ✅ Staking (by Manz)
- ✅ Auto-Update from GitHub

## Execute List
Save frequently used commands:
- Menu 13: Save Execute Command
- Menu 14: List & Run Saved Commands
- Menu 15: Delete Saved Command

## Developer Info
- Dev Team: PaxiHub Team
- Version: 2.0.4

## Support
- Discord: https://discord.gg/rA9Xzs69tx
- Telegram: https://t.me/paxi_network
- GitHub: https://github.com/einrika/dapps-cli-all-in-one
READMEEOF

show_progress 1
echo -e "${GREEN}✓ Documentation created${NC}\n"
pause_and_clean

# SUCCESS
clean_screen
cat << "EOF"
╔════════════════════════════════════════════════╗
║  ✅  INSTALLATION COMPLETE v2.0.4              ║
╚════════════════════════════════════════════════╝

📦 Location: ~/paxi-dapp
🚀 Launch: paxidev
🔄 Update: paxidev-update

✨ FEATURES:
  ✓ Wallet Management
  ✓ PRC-20 Token Creator
  ✓ Contract Upload & Management
  ✓ Execute List (Save Commands)
  ✓ Staking (by Manz)
  ✓ Auto-Update from GitHub

💾 EXECUTE LIST:
  Save frequently used commands for quick access

🔄 AUTO-UPDATE:
  Command: paxidev-update
  Source: github.com/einrika/dapps-cli-all-in-one

👨‍💻 Dev Team: seven0191

EOF
echo ""
read -p "Launch now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf '\033c'
    cd ~/paxi-dapp || exit 1
    node dapp.js
else
    echo -e "\n${GREEN}Type 'paxidev' to launch later${NC}\n"
fi
