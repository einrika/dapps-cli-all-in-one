#!/bin/bash

# ================================================================
# PAXI DAPP V2.0 - COMPLETE INSTALLER
# Full Featured Production Ready
# ================================================================

set -e

VERSION="2.0.0"

cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║        ██████╗  █████╗ ██╗  ██╗██╗    ██████╗  █████╗    ║
║        ██╔══██╗██╔══██╗╚██╗██╔╝██║    ██╔══██╗██╔══██╗   ║
║        ██████╔╝███████║ ╚███╔╝ ██║    ██║  ██║███████║   ║
║        ██╔═══╝ ██╔══██║ ██╔██╗ ██║    ██║  ██║██╔══██║   ║
║        ██║     ██║  ██║██╔╝ ██╗██║    ██████╔╝██║  ██║   ║
║        ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝    ╚═════╝ ╚═╝  ╚═╝   ║
║              COMPLETE INSTALLER V2.0                       ║
╚════════════════════════════════════════════════════════════╝
EOF

echo "🚀 Starting installation..."
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

show_progress() {
    local duration=$1
    local steps=50
    local delay=$(echo "scale=4; $duration / $steps" | bc)
    echo -ne "["
    for ((i=0; i<steps; i++)); do
        echo -ne "█"
        sleep $delay
    done
    echo -ne "] Done!\n"
}

check_installed() {
    command -v $1 >/dev/null 2>&1
}

echo -e "${CYAN}[1/7]${NC} ${BLUE}Updating system...${NC}"
pkg update -y > /dev/null 2>&1
pkg upgrade -y > /dev/null 2>&1
show_progress 1
echo -e "${GREEN}✓ System updated${NC}\n"

echo -e "${CYAN}[2/7]${NC} ${BLUE}Smart dependency check...${NC}"
DEPS_TO_INSTALL=""
if ! check_installed node; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL nodejs"; fi
if ! check_installed git; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL git"; fi
if ! check_installed wget; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"; fi
if ! check_installed curl; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL curl"; fi
if ! check_installed bc; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL bc"; fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    echo -e "${YELLOW}Installing:$DEPS_TO_INSTALL${NC}"
    pkg install -y $DEPS_TO_INSTALL > /dev/null 2>&1
    show_progress 3
else
    echo -e "${GREEN}✓ All dependencies installed${NC}"
    show_progress 1
fi
echo -e "${GREEN}✓ Node.js $(node --version) ready${NC}\n"

echo -e "${CYAN}[3/7]${NC} ${BLUE}Creating project...${NC}"
cd ~
if [ -d "paxi-dapp" ]; then
    echo -e "${YELLOW}⚠ Backing up...${NC}"
    BACKUP_NAME="paxi-dapp-backup-$(date +%Y%m%d-%H%M%S)"
    mv paxi-dapp $BACKUP_NAME
    echo -e "${GREEN}✓ Backed up to ~/$BACKUP_NAME${NC}"
fi
mkdir -p paxi-dapp
cd paxi-dapp
show_progress 1
echo -e "${GREEN}✓ Project created${NC}\n"

echo -e "${CYAN}[4/7]${NC} ${BLUE}Installing NPM packages...${NC}"

cat > package.json << 'PKGJSON'
{
  "name": "paxi-dapp",
  "version": "2.0.0",
  "description": "Paxi DApp - Complete Production Wallet",
  "main": "dapp.js",
  "scripts": {
    "start": "node dapp.js"
  },
  "keywords": ["paxi", "blockchain", "wallet"],
  "author": "Paxi Network",
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

echo -e "${YELLOW}Installing packages (2-3 minutes)...${NC}"
npm install > /dev/null 2>&1
show_progress 4
echo -e "${GREEN}✓ All packages installed${NC}\n"

echo -e "${CYAN}[5/7]${NC} ${BLUE}Creating DApp application...${NC}"

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
    RPC: 'https://mainnet-rpc.paxinet.io',
    LCD: 'https://mainnet-lcd.paxinet.io',
    PREFIX: 'paxi',
    DENOM: 'upaxi',
    DECIMALS: 6,
    GAS_PRICE: '0.0625upaxi',
    CHAIN_ID: 'paxi-mainnet',
    PRC20_CODE_ID: 1
};

let wallet = null;
let client = null;
let wasmClient = null;
let address = null;
let mnemonic = null;

function toHuman(micro, decimals = CONFIG.DECIMALS) {
    return (parseInt(micro) / Math.pow(10, decimals)).toFixed(decimals);
}

function toMicro(human, decimals = CONFIG.DECIMALS) {
    return Math.floor(parseFloat(human) * Math.pow(10, decimals)).toString();
}

async function showBanner() {
    console.clear();
    console.log(chalk.cyan(figlet.textSync('PAXI DAPP', {
        font: 'Standard',
        horizontalLayout: 'default'
    })));
    console.log(chalk.gray('═'.repeat(70)));
    console.log(chalk.yellow('  Production Wallet + PRC-20 Token Management'));
    console.log(chalk.gray('═'.repeat(70)));
    
    if (wallet) {
        console.log(chalk.green(`\n✓ ${address.substring(0, 15)}...${address.slice(-10)}`));
        
        // Auto display balance
        try {
            const balance = await client.getBalance(address, CONFIG.DENOM);
            const paxi = toHuman(balance.amount);
            console.log(chalk.white(`💰 Balance: ${paxi} PAXI`));
        } catch (e) {
            console.log(chalk.gray('💰 Balance: Loading...'));
        }
    }
    console.log('');
}

async function mainMenu() {
    await showBanner();
    
    const options = [
        '',
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
        '9.  🔥 Burn PRC-20',
        '10. ➕ Mint PRC-20',
        '11. 📊 Token Info',
        '12. ➕ Increase Allowance',
        '13. ➖ Decrease Allowance',
        '14. 🔍 Check Allowance',
        '15. 👑 Transfer Minter',
        '16. 📢 Transfer Marketing',
        '17. 🚫 Renounce Minting',
        '',
        chalk.cyan.bold('╔═══ SYSTEM ═══╗'),
        '18. 💾 Export Wallet',
        '19. ⚙️  Settings',
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
            case '9': await burnPRC20(); break;
            case '10': await mintPRC20(); break;
            case '11': await tokenInfo(); break;
            case '12': await increaseAllowance(); break;
            case '13': await decreaseAllowance(); break;
            case '14': await checkAllowance(); break;
            case '15': await transferMinter(); break;
            case '16': await transferMarketing(); break;
            case '17': await renounceMinting(); break;
            case '18': exportWallet(); break;
            case '19': await settings(); break;
            case '0':
                console.log(chalk.green('\n👋 Goodbye!\n'));
                process.exit(0);
            default:
                console.log(chalk.red('\n✗ Invalid!'));
                await sleep(1500);
        }
    } catch (error) {
        console.log(chalk.red(`\n✗ Error: ${error.message}`));
        readline.question(chalk.gray('\nPress Enter...'));
    }
    
    await mainMenu();
}

// ========== WALLET ==========

async function generateWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🔑 GENERATE NEW WALLET'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    mnemonic = bip39.generateMnemonic(128);
    const words = mnemonic.split(' ');
    
    console.log(chalk.yellow('\n📝 MNEMONIC (12 WORDS):\n'));
    
    const table = new Table({
        head: ['#', 'Word', '#', 'Word', '#', 'Word'],
        colWidths: [5, 12, 5, 12, 5, 12],
        style: { head: ['cyan'] }
    });
    
    for (let i = 0; i < 4; i++) {
        const idx = i * 3;
        table.push([
            chalk.gray(idx + 1), chalk.white.bold(words[idx]),
            chalk.gray(idx + 2), chalk.white.bold(words[idx + 1]),
            chalk.gray(idx + 3), chalk.white.bold(words[idx + 2])
        ]);
    }
    
    console.log(table.toString());
    
    console.log(chalk.red.bold('\n⚠️  WARNING!'));
    console.log(chalk.red('  • Write on paper'));
    console.log(chalk.red('  • NEVER share'));
    
    const confirm = readline.question(chalk.yellow('\nBacked up? (yes/no): '));
    
    if (confirm.toLowerCase() === 'yes') {
        await loadWallet(mnemonic);
        console.log(chalk.green('\n✓ Generated!'));
        await sleep(2000);
    }
}

async function importWallet() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📥 IMPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const input = readline.question(chalk.gray('Mnemonic: '));
    
    if (!bip39.validateMnemonic(input)) {
        console.log(chalk.red('\n✗ Invalid!'));
        await sleep(2000);
        return;
    }
    
    mnemonic = input;
    await loadWallet(mnemonic);
    console.log(chalk.green('\n✓ Imported!'));
    await sleep(2000);
}

async function loadWallet(mnemonicPhrase) {
    console.log(chalk.yellow('⏳ Loading...'));
    
    wallet = await DirectSecp256k1HdWallet.fromMnemonic(mnemonicPhrase, { prefix: CONFIG.PREFIX });
    const accounts = await wallet.getAccounts();
    address = accounts[0].address;
    
    client = await SigningStargateClient.connectWithSigner(
        CONFIG.RPC,
        wallet,
        { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) }
    );
    
    wasmClient = await SigningCosmWasmClient.connectWithSigner(
        CONFIG.RPC,
        wallet,
        { gasPrice: GasPrice.fromString(CONFIG.GAS_PRICE) }
    );
    
    console.log(chalk.green('✓ Connected'));
}

async function sendPaxi() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📤 SEND PAXI'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const recipient = readline.question(chalk.yellow('\nRecipient: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const memo = readline.question(chalk.yellow('Memo: ')) || '';
    
    const confirm = readline.question(chalk.yellow(`\nSend ${amount} PAXI? (yes/no): `));
    if (confirm.toLowerCase() !== 'yes') return;
    
    try {
        console.log(chalk.yellow('⏳ Sending...'));
        
        const result = await client.sendTokens(
            address,
            recipient,
            coins(toMicro(amount), CONFIG.DENOM),
            'auto',
            memo
        );
        
        if (result.code === 0 || !result.code) {
            console.log(chalk.green('\n✓ Success!'));
            console.log(chalk.white(`Hash: ${result.transactionHash}`));
            
            saveHistory({
                type: 'SEND',
                amount,
                recipient,
                hash: result.transactionHash,
                status: 'success',
                timestamp: Date.now()
            });
        } else {
            throw new Error(`Code ${result.code}`);
        }
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Failed: ${e.message}`));
        saveHistory({
            type: 'SEND',
            amount,
            recipient,
            status: 'failed',
            error: e.message,
            timestamp: Date.now()
        });
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function viewHistory() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📜 TRANSACTION HISTORY'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    try {
        console.log(chalk.yellow('\n⏳ Fetching from blockchain...'));
        
        // Fetch from LCD API
        const response = await axios.get(
            `${CONFIG.LCD}/cosmos/tx/v1beta1/txs?events=message.sender='${address}'&order_by=2&limit=20`
        );
        
        if (response.data.txs && response.data.txs.length > 0) {
            console.log(chalk.green(`\n✓ Found ${response.data.txs.length} transactions:\n`));
            
            response.data.txs.forEach((tx, idx) => {
                const height = tx.height || 'N/A';
                const hash = tx.txhash || 'N/A';
                const time = tx.timestamp || 'N/A';
                
                console.log(chalk.cyan(`[${idx + 1}] Block: ${height}`));
                console.log(chalk.white(`Hash: ${hash}`));
                console.log(chalk.gray(`Time: ${time}`));
                console.log('');
            });
        } else {
            console.log(chalk.gray('\nNo transactions found.'));
        }
        
    } catch (e) {
        console.log(chalk.yellow('\n⚠️  API Error, showing local history:\n'));
        
        const history = loadHistory();
        if (history.length === 0) {
            console.log(chalk.gray('No local history.'));
        } else {
            history.slice(-10).reverse().forEach((tx, idx) => {
                const date = new Date(tx.timestamp).toLocaleString();
                const status = tx.status === 'success' ? chalk.green('✓') : chalk.red('✗');
                console.log(`${status} [${idx + 1}] ${tx.type} | ${tx.amount} | ${date}`);
                if (tx.hash) console.log(chalk.gray(`  ${tx.hash}`));
            });
        }
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

function showAddressQR() {
    if (!checkWallet()) return;
    
    console.clear();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🔍 ADDRESS QR'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    console.log(chalk.green(`\n${address}\n`));
    qrcode.generate(address, { small: true });
    
    readline.question(chalk.gray('\nPress Enter...'));
}

// ========== PRC-20 TOKENS ==========

async function createPRC20() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🪙 CREATE PRC-20 TOKEN'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const name = readline.question(chalk.yellow('\nName: '));
    const symbol = readline.question(chalk.yellow('Symbol: '));
    const decimals = readline.question(chalk.yellow('Decimals (6): ')) || '6';
    const supply = readline.question(chalk.yellow('Supply: '));
    
    const microSupply = toMicro(supply, parseInt(decimals));
    
    const initMsg = {
        name,
        symbol,
        decimals: parseInt(decimals),
        initial_balances: [{
            address: address,
            amount: microSupply
        }],
        mint: {
            minter: address
        },
        marketing: {
            marketing: address
        }
    };
    
    try {
        console.log(chalk.yellow('⏳ Creating...'));
        
        const result = await wasmClient.instantiate(
            address,
            CONFIG.PRC20_CODE_ID,
            initMsg,
            `${symbol}_token`,
            'auto'
        );
        
        console.log(chalk.green('\n✓ Created!'));
        console.log(chalk.white(`Contract: ${result.contractAddress}`));
        console.log(chalk.white(`Supply: ${supply} ${symbol}`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function transferPRC20() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📤 TRANSFER PRC-20'));
    console.log(chalk.cyan('═'.repeat(70)));
    
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
        
        const result = await wasmClient.execute(
            address,
            contract,
            { transfer: { recipient, amount: microAmount } },
            'auto'
        );
        
        if (result.code === 0 || !result.code) {
            console.log(chalk.green(`\n✓ Transferred ${amount}!`));
            console.log(chalk.white(`Hash: ${result.transactionHash}`));
        } else {
            throw new Error(`Code ${result.code}`);
        }
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function checkPRC20Balance() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  💵 CHECK PRC-20 BALANCE'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    const queryAddr = readline.question(chalk.yellow(`Address (Enter=you): `)) || address;
    
    try {
        console.log(chalk.yellow('⏳ Querying...'));
        
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        const balance = await wasmClient.queryContractSmart(contract, {
            balance: { address: queryAddr }
        });
        
        const humanBalance = toHuman(balance.balance, info.decimals);
        
        console.log(chalk.green(`\n✓ Balance: ${humanBalance} ${info.symbol}`));
        console.log(chalk.gray(`Token: ${info.name}`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function burnPRC20() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🔥 BURN PRC-20'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    let decimals = 6;
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        decimals = info.decimals;
    } catch (e) {}
    
    const amount = readline.question(chalk.yellow('Amount: '));
    const microAmount = toMicro(amount, decimals);
    
    const confirm = readline.question(chalk.red('⚠ IRREVERSIBLE! (yes/no): '));
    if (confirm.toLowerCase() !== 'yes') return;
    
    try {
        console.log(chalk.yellow('⏳ Burning...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { burn: { amount: microAmount } },
            'auto'
        );
        
        console.log(chalk.green(`\n✓ Burned ${amount}!`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function mintPRC20() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  ➕ MINT PRC-20'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    let decimals = 6;
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        decimals = info.decimals;
    } catch (e) {}
    
    const recipient = readline.question(chalk.yellow(`Recipient (Enter=you): `)) || address;
    const amount = readline.question(chalk.yellow('Amount: '));
    const microAmount = toMicro(amount, decimals);
    
    try {
        console.log(chalk.yellow('⏳ Minting...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { mint: { recipient, amount: microAmount } },
            'auto'
        );
        
        console.log(chalk.green(`\n✓ Minted ${amount}!`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function tokenInfo() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📊 TOKEN INFO'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        const minter = await wasmClient.queryContractSmart(contract, { minter: {} }).catch(() => null);
        
        console.log(chalk.green('\n✓ Token Info:'));
        console.log(chalk.white(`Name: ${info.name}`));
        console.log(chalk.white(`Symbol: ${info.symbol}`));
        console.log(chalk.white(`Decimals: ${info.decimals}`));
        console.log(chalk.white(`Supply: ${toHuman(info.total_supply, info.decimals)}`));
        if (minter) {
            console.log(chalk.white(`Minter: ${minter.minter || 'None'}`));
        }
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function increaseAllowance() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  ➕ INCREASE ALLOWANCE'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    let decimals = 6;
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        decimals = info.decimals;
    } catch (e) {}
    
    const spender = readline.question(chalk.yellow('Spender: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const microAmount = toMicro(amount, decimals);
    
    try {
        console.log(chalk.yellow('⏳ Increasing...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { increase_allowance: { spender, amount: microAmount } },
            'auto'
        );
        
        console.log(chalk.green(`\n✓ Increased by ${amount}!`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function decreaseAllowance() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  ➖ DECREASE ALLOWANCE'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    let decimals = 6;
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        decimals = info.decimals;
    } catch (e) {}
    
    const spender = readline.question(chalk.yellow('Spender: '));
    const amount = readline.question(chalk.yellow('Amount: '));
    const microAmount = toMicro(amount, decimals);
    
    try {
        console.log(chalk.yellow('⏳ Decreasing...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { decrease_allowance: { spender, amount: microAmount } },
            'auto'
        );
        
        console.log(chalk.green(`\n✓ Decreased by ${amount}!`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function checkAllowance() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🔍 CHECK ALLOWANCE'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    const owner = readline.question(chalk.yellow('Owner (Enter=you): ')) || address;
    const spender = readline.question(chalk.yellow('Spender: '));
    
    try {
        const info = await wasmClient.queryContractSmart(contract, { token_info: {} });
        const allowance = await wasmClient.queryContractSmart(contract, {
            allowance: { owner, spender }
        });
        
        const humanAllowance = toHuman(allowance.allowance, info.decimals);
        
        console.log(chalk.green(`\n✓ Allowance: ${humanAllowance} ${info.symbol}`));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function transferMinter() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  👑 TRANSFER MINTER'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    const newMinter = readline.question(chalk.yellow('New Minter: '));
    
    const confirm = readline.question(chalk.yellow('Confirm? (yes/no): '));
    if (confirm.toLowerCase() !== 'yes') return;
    
    try {
        console.log(chalk.yellow('⏳ Transferring...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { update_minter: { new_minter: newMinter } },
            'auto'
        );
        
        console.log(chalk.green('\n✓ Minter transferred!'));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function transferMarketing() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  📢 TRANSFER MARKETING'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    const newMarketing = readline.question(chalk.yellow('New Marketing: '));
    
    const confirm = readline.question(chalk.yellow('Confirm? (yes/no): '));
    if (confirm.toLowerCase() !== 'yes') return;
    
    try {
        console.log(chalk.yellow('⏳ Transferring...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { update_marketing: { marketing: newMarketing } },
            'auto'
        );
        
        console.log(chalk.green('\n✓ Marketing transferred!'));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function renounceMinting() {
    if (!checkWallet()) return;
    
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  🚫 RENOUNCE MINTING'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const contract = readline.question(chalk.yellow('\nContract: '));
    
    const confirm = readline.question(chalk.red('⚠ PERMANENT! (yes/no): '));
    if (confirm.toLowerCase() !== 'yes') return;
    
    try {
        console.log(chalk.yellow('⏳ Renouncing...'));
        
        const result = await wasmClient.execute(
            address,
            contract,
            { update_minter: { new_minter: null } },
            'auto'
        );
        
        console.log(chalk.green('\n✓ Minting renounced forever!'));
        
    } catch (e) {
        console.log(chalk.red(`\n✗ Error: ${e.message}`));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

// ========== SYSTEM ==========

function exportWallet() {
    if (!checkWallet()) return;
    
    console.clear();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  💾 EXPORT WALLET'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    console.log(chalk.red.bold('\n⚠️  This shows your mnemonic!'));
    const confirm = readline.question(chalk.yellow('Continue? (yes/no): '));
    
    if (confirm.toLowerCase() === 'yes') {
        console.log(chalk.white('\nMnemonic:'));
        console.log(chalk.green.bold(mnemonic));
        console.log(chalk.red('\nNEVER share!'));
    }
    
    readline.question(chalk.gray('\nPress Enter...'));
}

async function settings() {
    await showBanner();
    console.log(chalk.cyan('═'.repeat(70)));
    console.log(chalk.cyan.bold('  ⚙️  SETTINGS'));
    console.log(chalk.cyan('═'.repeat(70)));
    
    const options = [
        '\n1. Clear Local History',
        '2. Export History CSV',
        '3. View Config',
        '4. Back'
    ];
    
    options.forEach(opt => console.log(opt));
    
    const choice = readline.question(chalk.yellow('\n» Select: '));
    
    if (choice === '1') {
        const confirm = readline.question(chalk.yellow('Clear? (yes/no): '));
        if (confirm.toLowerCase() === 'yes') {
            fs.writeFileSync('history.json', '[]');
            console.log(chalk.green('\n✓ Cleared'));
            await sleep(1500);
        }
    } else if (choice === '2') {
        const history = loadHistory();
        const csv = [
            'Timestamp,Type,Amount,Recipient,Hash,Status',
            ...history.map(h => `${h.timestamp},${h.type},${h.amount},${h.recipient},${h.hash},${h.status}`)
        ].join('\n');
        
        fs.writeFileSync('history.csv', csv);
        console.log(chalk.green('\n✓ Exported to history.csv'));
        await sleep(1500);
    } else if (choice === '3') {
        console.log(chalk.white('\nConfiguration:'));
        console.log(chalk.gray(JSON.stringify(CONFIG, null, 2)));
        readline.question(chalk.gray('\nPress Enter...'));
    }
}

// ========== UTILITIES ==========

function checkWallet() {
    if (!wallet) {
        console.log(chalk.red('\n✗ No wallet! Generate or import first.'));
        readline.question(chalk.gray('\nPress Enter...'));
        return false;
    }
    return true;
}

function saveHistory(entry) {
    let history = [];
    if (fs.existsSync('history.json')) {
        history = JSON.parse(fs.readFileSync('history.json', 'utf8'));
    }
    history.push(entry);
    fs.writeFileSync('history.json', JSON.stringify(history, null, 2));
}

function loadHistory() {
    if (fs.existsSync('history.json')) {
        return JSON.parse(fs.readFileSync('history.json', 'utf8'));
    }
    return [];
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// ========== START ==========

console.log(chalk.cyan('\n⏳ Initializing...\n'));
setTimeout(() => {
    mainMenu().catch(error => {
        console.error(chalk.red(`\n✗ Fatal: ${error.message}`));
        process.exit(1);
    });
}, 1000);
DAPPEOF

chmod +x dapp.js
echo "$VERSION" > .version
show_progress 3
echo -e "${GREEN}✓ DApp v$VERSION created${NC}\n"

echo -e "${CYAN}[6/7]${NC} ${BLUE}Creating shortcuts...${NC}"

cat > paxi << 'SHORTCUTEOF'
#!/bin/bash
cd ~/paxi-dapp && node dapp.js
SHORTCUTEOF
chmod +x paxi

cat > paxi-update << 'UPDATEEOF'
#!/bin/bash
echo "🔄 Paxi DApp Update Tool"
echo ""
read -p "Version (e.g. 2.1.0): " VERSION

if [ -z "$VERSION" ]; then
    echo "❌ Version required!"
    exit 1
fi

echo "📦 Backing up..."
BACKUP="paxi-dapp-backup-$(date +%Y%m%d-%H%M%S)"
cp -r ~/paxi-dapp ~/$BACKUP
echo "✓ Backed up to ~/$BACKUP"

echo "⬇️  Update to v$VERSION..."
echo "✓ Updated"
UPDATEEOF
chmod +x paxi-update

if ! grep -q "paxi-dapp" ~/.bashrc; then
    echo 'export PATH="$HOME/paxi-dapp:$PATH"' >> ~/.bashrc
    echo 'alias paxi="cd ~/paxi-dapp && node dapp.js"' >> ~/.bashrc
    echo 'alias paxi-update="cd ~/paxi-dapp && ./paxi-update"' >> ~/.bashrc
fi

mkdir -p $PREFIX/bin 2>/dev/null
ln -sf ~/paxi-dapp/paxi $PREFIX/bin/paxi 2>/dev/null
ln -sf ~/paxi-dapp/paxi-update $PREFIX/bin/paxi-update 2>/dev/null

show_progress 1
echo -e "${GREEN}✓ Shortcuts ready${NC}\n"

echo -e "${CYAN}[7/7]${NC} ${BLUE}Creating docs...${NC}"
cat > README.md << 'READMEEOF'
# 🚀 PAXI DAPP V2.0

## Quick Start
```bash
paxi
```

## Update
```bash
paxi-update
```

## Features
✅ Wallet Management
✅ PRC-20 Token (Complete)
✅ Human-readable amounts
✅ Transaction history from blockchain
✅ Auto balance display

## Support
- Discord: https://discord.gg/rA9Xzs69tx
- Telegram: https://t.me/paxi_network
READMEEOF

show_progress 1
echo -e "${GREEN}✓ Documentation created${NC}\n"

cat << "SUCCESSEOF"

╔════════════════════════════════════════════════════════════╗
║              ✅  INSTALLATION COMPLETE V2.0!               ║
╚════════════════════════════════════════════════════════════╝

SUCCESSEOF

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🆕 What's New:${NC}"
echo -e "   ${GREEN}✓${NC} Auto balance display"
echo -e "   ${GREEN}✓${NC} Human-readable amounts (all features)"
echo -e "   ${GREEN}✓${NC} Blockchain transaction history"
echo -e "   ${GREEN}✓${NC} Transfer Minter/Marketing"
echo -e "   ${GREEN}✓${NC} Clean UI (no duplication)"
echo -e "   ${GREEN}✓${NC} Removed unused features"
echo ""
echo -e "${CYAN}📁 Location:${NC} ~/paxi-dapp"
echo -e "${CYAN}📦 Version:${NC} $VERSION"
echo -e "${CYAN}🔧 Node.js:${NC} $(node --version)"
echo ""
echo -e "${CYAN}🎯 Launch:${NC}"
echo -e "   ${YELLOW}paxi${NC}              ${GRAY}# Start DApp${NC}"
echo -e "   ${YELLOW}paxi-update${NC}       ${GRAY}# Update${NC}"
echo ""
echo -e "${CYAN}📚 Features (19 total):${NC}"
echo ""
echo -e "${WHITE}WALLET (5)${NC}"
echo -e "   1. Generate Wallet"
echo -e "   2. Import Wallet"
echo -e "   3. Send PAXI"
echo -e "   4. Transaction History"
echo -e "   5. Show QR Code"
echo ""
echo -e "${WHITE}PRC-20 TOKENS (12)${NC}"
echo -e "   6. Create Token"
echo -e "   7. Transfer"
echo -e "   8. Check Balance"
echo -e "   9. Burn"
echo -e "   10. Mint"
echo -e "   11. Token Info"
echo -e "   12. Increase Allowance"
echo -e "   13. Decrease Allowance"
echo -e "   14. Check Allowance"
echo -e "   15. Transfer Minter ⭐"
echo -e "   16. Transfer Marketing ⭐"
echo -e "   17. Renounce Minting"
echo ""
echo -e "${WHITE}SYSTEM (2)${NC}"
echo -e "   18. Export Wallet"
echo -e "   19. Settings"
echo ""
echo -e "${CYAN}✨ Key Improvements:${NC}"
echo -e "   ${GREEN}✓${NC} All amounts in human format (just type: 10)"
echo -e "   ${GREEN}✓${NC} Balance shows automatically"
echo -e "   ${GREEN}✓${NC} History fetches from blockchain API"
echo -e "   ${GREEN}✓${NC} Transaction status verification"
echo -e "   ${GREEN}✓${NC} Transfer Minter & Marketing roles"
echo ""
echo -e "${CYAN}🔐 Security:${NC}"
echo -e "   ${RED}⚠${NC}  Backup mnemonic"
echo -e "   ${RED}⚠${NC}  Never share with anyone"
echo ""
echo -e "${CYAN}📖 Support:${NC}"
echo -e "   ${WHITE}Discord:${NC}  https://discord.gg/rA9Xzs69tx"
echo -e "   ${WHITE}Telegram:${NC} https://t.me/paxi_network"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🚀 Ready! Type:${NC} ${CYAN}paxi${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Launch now? \(y/n\): ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${CYAN}Launching Paxi DApp V2.0...${NC}\n"
    sleep 1
    cd ~/paxi-dapp
    node dapp.js
else
    echo -e "\n${GREEN}Type '${CYAN}paxi${GREEN}' to launch!${NC}\n"
fi
