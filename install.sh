#!/bin/bash

# ================================================================
# PAXIHUB CREATE TOKEN PRC20 - COMPLETE INSTALLER
# Version 2.0.3 - FULL (Upload + Stake + Execute List + Auto-Update)
# ================================================================

set -e

VERSION="2.0.3"

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
 Version : 2.0.3
 Network : Paxi Mainnet
 Features: Token + Staking + Contracts
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

# [1/7] System Update
echo -e "${CYAN}[1/7]${NC} ${BLUE}Updating system...${NC}"
clean_screen
echo -e "${CYAN}[1/7]${NC} ${BLUE}Updating system...${NC}"
pkg update -y > /dev/null 2>&1 || true
pkg upgrade -y > /dev/null 2>&1 || true
show_progress 1
echo -e "${GREEN}✓ System updated${NC}\n"

# [2/7] Dependencies
echo -e "${CYAN}[2/7]${NC} ${BLUE}Smart dependency check...${NC}"
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
clean_screen
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
clean_screen
cat > package.json << 'PKGJSON'
{
  "name": "paxi-dapp",
  "version": "2.0.3",
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
npm install --no-audit --no-fund > /dev/null 2>&1 || true
show_progress 4
echo -e "${GREEN}✓ All packages installed${NC}\n"
pause_and_clean

# [5/7] Create DApp
echo -e "${CYAN}[5/7]${NC} ${BLUE}Creating DApp v${VERSION}...${NC}"
clean_screen

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
    VERSION: '2.0.3',
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
    return fracStr.length > 0 ? `${intPart}.${fracStr}` : intPart.toString();
}

function toMicro(human, decimals = CONFIG.DECIMALS) {
    const [intPart, fracPart = ''] = human.toString().split('.');
    const frac = (fracPart + '0'.repeat(decimals)).slice(0, decimals);
    return (BigInt(intPart || '0') * (BigInt(10) ** BigInt(decimals)) + BigInt(frac || '0')).toString();
}

function saveHistory(entry) {
    let history = [];
    if (fs.existsSync('history.json')) {
        try { history = JSON.parse(fs.readFileSync('history.json', 'utf8')); }
        catch (e) { history = []; }
    }
    history.push(entry);
    fs.writeFileSync('history.json', JSON.stringify(history, null, 2));
}

function loadHistory() {
    if (fs.existsSync('history.json')) {
        try { return JSON.parse(fs.readFileSync('history.json', 'utf8')); }
        catch (e) { return []; }
    }
    return [];
}

async function loadWallet(mnemonicPhrase) {
    console.log(chalk.yellow('⏳ Loading...'));
    wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonicPhrase, { prefix: CONFIG.PREFIX });
    const accounts = await wallet.getAccounts();
    address = accounts[0].address;
    client = await SigningStargateClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    wasmClient = await SigningCosmWasmClient.connectWithSigner(CONFIG.RPC, wallet, { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) });
    console.log(chalk.green('✓ Connected'));
}

function checkWallet() {
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet! Generate or import first.'));
        readline.question(chalk.gray('\nTekan Enter...'));
        return false;
    }
    return true;
}

function pause() { readline.question(chalk.gray('\nTekan Enter...')); }

async function generateWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔑 GENERATE NEW WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    mnemonic = bip39.generateMnemonic(128);
    const words = mnemonic.split(' ');
    console.log(chalk.yellow('\n📝 MNEMONIC (12 WORDS):\n'));
    const table = new Table({ head: ['#', 'Word', '#', 'Word', '#', 'Word'], colWidths: [4, 12, 4, 12, 4, 12], style: { head: ['cyan'] } });
    for (let i = 0; i < 4; i++) {
        const idx = i * 3;
        table.push([chalk.gray(idx + 1), chalk.white.bold(words[idx]), chalk.gray(idx + 2), chalk.white.bold(words[idx + 1]), chalk.gray(idx + 3), chalk.white.bold(words[idx + 2])]);
    }
    console.log(table.toString());
    console.log(chalk.red.bold('\n⚠️  WARNING: Write on paper • NEVER share'));
    const confirm = readline.question(chalk.yellow('\nBacked up? (yes/no): '));
    if (confirm.toLowerCase() === 'yes') {
        await loadWallet(mnemonic);
        console.log(chalk.green('\n✓ Generated!'));
    }
    pause();
}

async function importWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📥 IMPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    const input = readline.question(chalk.gray('Mnemonic: '));
    if (!bip39.validateMnemonic(input)) {
        console.log(chalk.red('\n✗ Invalid!'));
        pause();
        return;
    }
    mnemonic = input;
    await loadWallet(mnemonic);
    console.log(chalk.green('\n✓ Imported!'));
    pause();
}

async function sendPaxi() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 SEND PAXI'));
    console.log(chalk.cyan('═'.repeat(50)));
    const recipient = readline.question(chalk.yellow('\nRecipient: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const memo = readline.question(chalk.yellow('Memo: ')) || '';
    const confirm = readline.question(chalk.yellow(`\nSend ${amount} PAXI? (yes/no): `));
    if (confirm.toLowerCase() !== 'yes') return;
    try {
        console.log(chalk.yellow('⏳ Sending...'));
        const result = await client.sendTokens(address, recipient, coins(toMicro(amount), CONFIG.DENOM), 'auto', memo);
        if (result && (result.code === 0 || !result.code)) {
            console.log(chalk.green('\n✓ Success!'));
            if (result.transactionHash) console.log(chalk.white(`Hash: ${result.transactionHash}`));
            saveHistory({ type: 'SEND', amount, recipient, hash: result.transactionHash, status: 'success', timestamp: Date.now() });
        } else { throw new Error(`Code ${result.code}`); }
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed: ${e.message}`));
        saveHistory({ type: 'SEND', amount, recipient, status: 'failed', error: e.message, timestamp: Date.now() });
    }
    pause();
}

async function viewHistory() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📜 TRANSACTION HISTORY'));
    console.log(chalk.cyan('═'.repeat(50)));
    try {
        console.log(chalk.yellow('\n⏳ Fetching...'));
        const response = await axios.get(`${CONFIG.LCD}/cosmos/tx/v1beta1/txs?events=message.sender='${address}'&order_by=2&limit=20`);
        if (response.data.txs && response.data.txs.length > 0) {
            console.log(chalk.green(`\n✓ Found ${response.data.txs.length} transactions:\n`));
            response.data.txs.forEach((tx, idx) => {
                console.log(chalk.cyan(`[${idx + 1}] Block: ${tx.height || 'N/A'}`));
                console.log(chalk.white(`Hash: ${tx.txhash || 'N/A'}`));
                console.log('');
            });
        } else { console.log(chalk.gray('\nNo transactions.')); }
    } catch (e) {
        console.log(chalk.yellow('\n⚠️  Using local history:\n'));
        const history = loadHistory();
        if (history.length === 0) { console.log(chalk.gray('No local history.')); }
        else {
            history.slice(-10).reverse().forEach((tx, idx) => {
                const date = new Date(tx.timestamp).toLocaleString();
                const status = tx.status === 'success' ? chalk.green('✓') : chalk.red('✗');
                console.log(`${status} [${idx + 1}] ${tx.type} | ${tx.amount} | ${date}`);
            });
        }
    }
    pause();
}

function showAddressQR() {
    if (!checkWallet()) return;
    clearScreen();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔍 ADDRESS QR'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.green(`\n${address}\n`));
    qrcode.generate(address, { small: true });
    pause();
}

async function createPRC20() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🪙 CREATE PRC-20 TOKEN'));
    console.log(chalk.cyan('═'.repeat(50)));
    const name = readline.question(chalk.yellow('\nName: '));
    const symbol = readline.question(chalk.yellow('Symbol: '));
    const decimalsStr = readline.question(chalk.yellow('Decimals (6): ')) || '6';
    const decimals = parseInt(decimalsStr) || 6;
    const supply = readline.question(chalk.yellow('Supply: '));
    const microSupply = toMicro(supply, decimals);
    const initMsg = { name, symbol, decimals: parseInt(decimals), initial_balances: [{ address: address, amount: microSupply }], mint: { minter: address }, marketing: { marketing: address } };
    try {
        console.log(chalk.yellow('⏳ Creating...'));
        const result = await wasmClient.instantiate(address, CONFIG.PRC20_CODE_ID, initMsg, `${symbol}_token`, 'auto');
        console.log(chalk.green('\n✓ Created!'));
        console.log(chalk.white(`Contract: ${result.contractAddress || 'N/A'}`));
        console.log(chalk.white(`Supply: ${supply} ${symbol}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function transferPRC20() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 TRANSFER PRC-20'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract: '));
    let decimals = 6;
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        decimals = info.decimals;
        console.log(chalk.gray(`Token: ${info.name} (${info.symbol})`));
    } catch (e) {}
    const recipient = readline.question(chalk.yellow('Recipient: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const microAmount = toMicro(amount, decimals);
    try {
        console.log(chalk.yellow('⏳ Transferring...'));
        const result = await wasmClient.execute(address, contract, { transfer: { recipient, amount: microAmount } }, 'auto');
        if (result && (result.code === 0 || !result.code)) { console.log(chalk.green(`\n✓ Transferred ${amount}!`)); }
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function checkPRC20Balance() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💵 CHECK PRC-20 BALANCE'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract: '));
    const queryAddr = readline.question(chalk.yellow(`Address (Enter=you): `)) || address;
    try {
        console.log(chalk.yellow('⏳ Querying...'));
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        const balance = await wasmClient.queryContractSmart(contract, { balance: { address: queryAddr } });
        const humanBalance = toHuman(balance.balance, info.decimals);
        console.log(chalk.green(`\n✓ Balance: ${humanBalance} ${info.symbol}`));
        console.log(chalk.gray(`Token: ${info.name}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function uploadContract() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📤 UPLOAD CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const wasmPath = readline.question(chalk.yellow('\nPath to .wasm file: '));
    if (!fs.existsSync(wasmPath)) {
        console.log(chalk.red('\n✗ File not found!'));
        pause();
        return;
    }
    try {
        console.log(chalk.yellow('\n⏳ Uploading (may take a while)...'));
        const wasmCode = fs.readFileSync(wasmPath);
        const result = await wasmClient.upload(address, wasmCode, 'auto');
        console.log(chalk.green('\n✓ Contract uploaded!'));
        console.log(chalk.white(`Code ID: ${result.codeId}`));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
        console.log(chalk.gray(`\nDeveloped by: ${CONFIG.DEV_CONTRACT_AUTHOR}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function instantiateContract() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🎯 INSTANTIATE CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const codeId = readline.question(chalk.yellow('\nCode ID: '));
    const label = readline.question(chalk.yellow('Label: '));
    const initMsg = readline.question(chalk.yellow('Init Message (JSON): '));
    try {
        console.log(chalk.yellow('⏳ Instantiating...'));
        const msg = JSON.parse(initMsg);
        const result = await wasmClient.instantiate(address, parseInt(codeId), msg, label, 'auto');
        console.log(chalk.green('\n✓ Contract instantiated!'));
        console.log(chalk.white(`Contract: ${result.contractAddress}`));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function executeContract() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  ⚡ EXECUTE CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract: '));
    const execMsg = readline.question(chalk.yellow('Execute Message (JSON): '));
    const fundsStr = readline.question(chalk.yellow('Funds (PAXI, optional): ')) || '0';
    try {
        console.log(chalk.yellow('⏳ Executing...'));
        const msg = JSON.parse(execMsg);
        const fundsAmount = parseFloat(fundsStr) > 0 ? coins(toMicro(fundsStr), CONFIG.DENOM) : [];
        const result = await wasmClient.execute(address, contract, msg, 'auto', '', fundsAmount);
        console.log(chalk.green('\n✓ Executed!'));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function queryContract() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔍 QUERY CONTRACT'));
    console.log(chalk.cyan('═'.repeat(50)));
    const contract = readline.question(chalk.yellow('\nContract: '));
    const queryMsg = readline.question(chalk.yellow('Query Message (JSON): '));
    try {
        console.log(chalk.yellow('⏳ Querying...'));
        const msg = JSON.parse(queryMsg);
        const result = await wasmClient.queryContractSmart(contract, msg);
        console.log(chalk.green('\n✓ Query Result:'));
        console.log(chalk.white(JSON.stringify(result, null, 2)));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function saveExecuteCommand() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💾 SAVE EXECUTE COMMAND'));
    console.log(chalk.cyan('═'.repeat(50)));
    const name = readline.question(chalk.yellow('\nCommand Name: '));
    const contract = readline.question(chalk.yellow('Contract: '));
    const execMsg = readline.question(chalk.yellow('Execute Message (JSON): '));
    const fundsStr = readline.question(chalk.yellow('Funds (PAXI, optional): ')) || '0';
    const command = { name, contract, execMsg, funds: fundsStr, timestamp: Date.now() };
    let commands = [];
    if (fs.existsSync('execute_commands.json')) {
        try { commands = JSON.parse(fs.readFileSync('execute_commands.json', 'utf8')); }
        catch (e) { commands = []; }
    }
    commands.push(command);
    fs.writeFileSync('execute_commands.json', JSON.stringify(commands, null, 2));
    console.log(chalk.green('\n✓ Command saved!'));
    pause();
}

async function listExecuteCommands() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📋 SAVED EXECUTE COMMANDS'));
    console.log(chalk.cyan('═'.repeat(50)));
    if (!fs.existsSync('execute_commands.json')) {
        console.log(chalk.gray('\nNo saved commands.'));
        pause();
        return;
    }
    let commands = [];
    try { commands = JSON.parse(fs.readFileSync('execute_commands.json', 'utf8')); }
    catch (e) {
        console.log(chalk.red('\n✗ Error reading commands'));
        pause();
        return;
    }
    if (commands.length === 0) {
        console.log(chalk.gray('\nNo saved commands.'));
        pause();
        return;
    }
    console.log(chalk.green(`\n✓ Found ${commands.length} saved commands:\n`));
    commands.forEach((cmd, idx) => {
        console.log(chalk.cyan(`[${idx + 1}] ${cmd.name}`));
        console.log(chalk.white(`    Contract: ${cmd.contract.substring(0, 20)}...`));
        console.log(chalk.gray(`    Saved: ${new Date(cmd.timestamp).toLocaleString()}`));
        console.log('');
    });
    const choice = readline.question(chalk.yellow('Execute which? (number or 0 to cancel): '));
    const idx = parseInt(choice) - 1;
    if (idx >= 0 && idx < commands.length) {
        const cmd = commands[idx];
        console.log(chalk.yellow(`\nExecuting: ${cmd.name}...`));
        const confirm = readline.question(chalk.yellow('Confirm? (yes/no): '));
        if (confirm.toLowerCase() !== 'yes') return;
        try {
            const msg = JSON.parse(cmd.execMsg);
            const fundsAmount = parseFloat(cmd.funds) > 0 ? coins(toMicro(cmd.funds), CONFIG.DENOM) : [];
            const result = await wasmClient.execute(address, cmd.contract, msg, 'auto', '', fundsAmount);
            console.log(chalk.green('\n✓ Executed!'));
            console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
        } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    }
    pause();
}

async function deleteExecuteCommand() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🗑️  DELETE SAVED COMMAND'));
    console.log(chalk.cyan('═'.repeat(50)));
    if (!fs.existsSync('execute_commands.json')) {
        console.log(chalk.gray('\nNo saved commands.'));
        pause();
        return;
    }
    let commands = [];
    try { commands = JSON.parse(fs.readFileSync('execute_commands.json', 'utf8')); }
    catch (e) {
        console.log(chalk.red('\n✗ Error reading commands'));
        pause();
        return;
    }
    if (commands.length === 0) {
        console.log(chalk.gray('\nNo saved commands.'));
        pause();
        return;
    }
    console.log(chalk.green(`\n✓ Saved commands:\n`));
    commands.forEach((cmd, idx) => { console.log(chalk.cyan(`[${idx + 1}] ${cmd.name}`)); });
    const choice = readline.question(chalk.yellow('\nDelete which? (number or 0 to cancel): '));
    const idx = parseInt(choice) - 1;
    if (idx >= 0 && idx < commands.length) {
        const confirm = readline.question(chalk.red('Confirm delete? (yes/no): '));
        if (confirm.toLowerCase() === 'yes') {
            commands.splice(idx, 1);
            fs.writeFileSync('execute_commands.json', JSON.stringify(commands, null, 2));
            console.log(chalk.green('\n✓ Deleted!'));
        }
    }
    pause();
}

async function stakeTokens() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💎 STAKE TOKENS'));
    console.log(chalk.gray(`  Contract by: ${CONFIG.DEV_CONTRACT_AUTHOR}`));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.white(`\nStake Token: ${CONFIG.STAKE_TOKEN}`));
    console.log(chalk.white(`Stake Contract: ${CONFIG.STAKE_CONTRACT}`));
    const amount = readline.question(chalk.yellow('\nAmount to stake: '));
    const confirm = readline.question(chalk.yellow(`Stake ${amount}? (yes/no): `));
    if (confirm.toLowerCase() !== 'yes') return;
    try {
        console.log(chalk.yellow('⏳ Staking...'));
        const stakeMsg = Buffer.from(JSON.stringify({ stake: {} })).toString('base64');
        const execMsg = { send: { contract: CONFIG.STAKE_CONTRACT, amount: toMicro(amount), msg: stakeMsg } };
        const result = await wasmClient.execute(address, CONFIG.STAKE_TOKEN, execMsg, { amount: coins('30000', CONFIG.DENOM), gas: '1500000' });
        console.log(chalk.green('\n✓ Staked!'));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function unstakeTokens() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  🔓 UNSTAKE TOKENS'));
    console.log(chalk.cyan('═'.repeat(50)));
    const amount = readline.question(chalk.yellow('\nAmount to unstake: '));
    const confirm = readline.question(chalk.yellow(`Unstake ${amount}? (yes/no): `));
    if (confirm.toLowerCase() !== 'yes') return;
    try {
        console.log(chalk.yellow('⏳ Unstaking...'));
        const execMsg = { unstake: { amount: toMicro(amount) } };
        const result = await wasmClient.execute(address, CONFIG.STAKE_CONTRACT, execMsg, 'auto');
        console.log(chalk.green('\n✓ Unstaked!'));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function claimStakingRewards() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💰 CLAIM STAKING REWARDS'));
    console.log(chalk.cyan('═'.repeat(50)));
    try {
        console.log(chalk.yellow('⏳ Claiming rewards...'));
        const execMsg = { claim_rewards: {} };
        const result = await wasmClient.execute(address, CONFIG.STAKE_CONTRACT, execMsg, 'auto');
        console.log(chalk.green('\n✓ Rewards claimed!'));
        console.log(chalk.white(`Tx Hash: ${result.transactionHash}`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

async function viewStakingInfo() {
    if (!checkWallet()) return;
    await showBanner();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  📊 STAKING INFO'));
    console.log(chalk.cyan('═'.repeat(50)));
    try {
        console.log(chalk.yellow('⏳ Fetching info...'));
        const stakeInfo = await wasmClient.queryContractSmart(CONFIG.STAKE_CONTRACT, { staker_info: { staker: address } });
        console.log(chalk.green('\n✓ Your Staking Info:'));
        console.log(chalk.white(`Staked: ${toHuman(stakeInfo.amount || '0')}`));
        console.log(chalk.white(`Rewards: ${toHuman(stakeInfo.pending_rewards || '0')}`));
        const poolInfo = await wasmClient.queryContractSmart(CONFIG.STAKE_CONTRACT, { pool_info: {} });
        console.log(chalk.gray('\nPool Info:'));
        console.log(chalk.gray(`Total Staked: ${toHuman(poolInfo.total_staked || '0')}`));
        console.log(chalk.gray(`APR: ${poolInfo.apr || 'N/A'}%`));
    } catch (e) { console.log(chalk.red(`\n✗ Error: ${e.message}`)); }
    pause();
}

function showDevInfo() {
    clearScreen();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  👨‍💻 DEVELOPER INFO'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.green('\n📦 DApp Information:'));
    console.log(chalk.white(`Version: ${CONFIG.VERSION}`));
    console.log(chalk.white(`Dev Team: ${CONFIG.DEV_TEAM}`));
    console.log(chalk.green('\n🔧 Smart Contracts:'));
    console.log(chalk.white(`PRC-20 Code ID: ${CONFIG.PRC20_CODE_ID}`));
    console.log(chalk.white(`Contract Developer: ${CONFIG.DEV_CONTRACT_AUTHOR}`));
    console.log(chalk.green('\n💎 Staking Contracts:'));
    console.log(chalk.white(`Stake Token: ${CONFIG.STAKE_TOKEN}`));
    console.log(chalk.white(`Stake Contract: ${CONFIG.STAKE_CONTRACT}`));
    console.log(chalk.gray(`Developer: ${CONFIG.DEV_CONTRACT_AUTHOR}`));
    console.log(chalk.green('\n🌐 Network:'));
    console.log(chalk.white(`Chain ID: ${CONFIG.CHAIN_ID}`));
    console.log(chalk.white(`RPC: ${CONFIG.RPC}`));
    console.log(chalk.white(`LCD: ${CONFIG.LCD}`));
    console.log(chalk.green('\n📞 Support:'));
    console.log(chalk.white(`Discord: https://discord.gg/rA9Xzs69tx`));
    console.log(chalk.white(`Telegram: https://t.me/paxi_network`));
    pause();
}

function exportWallet() {
    if (!checkWallet()) return;
    clearScreen();
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.cyan.bold('  💾 EXPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(50)));
    console.log(chalk.red.bold('\n⚠️  This shows your mnemonic!'));
    const confirm = readline.question(chalk.yellow('Continue? (yes/no): '));
    if (confirm.toLowerCase() === 'yes') {
        console.log(chalk.white('\nMnemonic:'));
        console.log(chalk.green.bold(mnemonic));
        console.log(chalk.red('\nNEVER share!'));
    }
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
clean_screen

cat > paxi << 'SHORTCUTEOF'
#!/bin/bash
printf '\033c'
cd ~/paxi-dapp && node dapp.js
SHORTCUTEOF
chmod +x paxi

cat > paxi-update << 'UPDATEEOF'
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
chmod +x paxi-update

if ! grep -q "paxi-dapp" ~/.bashrc; then
    echo 'export PATH="$HOME/paxi-dapp:$PATH"' >> ~/.bashrc
    echo 'alias paxi="cd ~/paxi-dapp && ./paxi"' >> ~/.bashrc
    echo 'alias paxi-update="cd ~/paxi-dapp && ./paxi-update"' >> ~/.bashrc
fi

mkdir -p "${PREFIX:-$HOME/.local/bin}" 2>/dev/null || true
ln -sf ~/paxi-dapp/paxi "${PREFIX:-$HOME/.local/bin}/paxi" 2>/dev/null || true
ln -sf ~/paxi-dapp/paxi-update "${PREFIX:-$HOME/.local/bin}/paxi-update" 2>/dev/null || true

show_progress 1
echo -e "${GREEN}✓ Shortcuts ready${NC}\n"
pause_and_clean

# [7/7] Docs
echo -e "${CYAN}[7/7]${NC} ${BLUE}Creating docs...${NC}"
clean_screen

cat > README.md << 'READMEEOF'
# 🚀 PAXIHUB CREATE TOKEN PRC20 v2.0.3

## Quick Start
```bash
paxi
```

## Auto-Update
```bash
paxi-update
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
- Contract Developer: Manz
- Version: 2.0.3

## Staking Contracts
- Stake Token: paxi12rtyqvnevgzeyfjmr6z456ap3hrt9j2kjgvkm6qfn4ak6aqcgf5qtrv008
- Stake Contract: paxi1arzvvpl6f24zdzauy7skdn2pweaynqa8mf2722wn248wgx8nswzqjkl9r7

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
║  ✅  INSTALLATION COMPLETE v2.0.3              ║
╚════════════════════════════════════════════════╝

📦 Location: ~/paxi-dapp
🚀 Launch: paxi
🔄 Update: paxi-update

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
  Command: paxi-update
  Source: github.com/einrika/dapps-cli-all-in-one

👨‍💻 Dev Team: PaxiHub Team
🔧 Contract Dev: Manz
EOF

echo ""
read -p "Launch now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf '\033c'
    cd ~/paxi-dapp || exit 1
    node dapp.js
else
    echo -e "\n${GREEN}Type 'paxi' to launch later${NC}\n"
fi
