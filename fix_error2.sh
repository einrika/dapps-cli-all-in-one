#!/bin/bash

# ================================================================
# EMERGENCY FIX - Perbaiki syntax error yang terjadi
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🚑 EMERGENCY SYNTAX ERROR FIX       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

cd ~/paxi-dapp || exit 1

if [ ! -f dapp.js ]; then
    echo -e "${RED}✗ File tidak ditemukan!${NC}"
    exit 1
fi

# Restore dari backup jika ada
LATEST_BACKUP=$(ls -t dapp.js.backup-* 2>/dev/null | head -1)

if [ -n "$LATEST_BACKUP" ]; then
    echo -e "${YELLOW}📦 Menemukan backup: $LATEST_BACKUP${NC}"
    echo -e "${CYAN}Restoring dari backup...${NC}"
    cp "$LATEST_BACKUP" dapp.js
    echo -e "${GREEN}✓ File di-restore dari backup${NC}"
else
    echo -e "${RED}✗ Backup tidak ditemukan!${NC}"
    echo -e "${YELLOW}  File rusak dan tidak bisa di-restore otomatis${NC}"
    echo -e "${YELLOW}  Silakan jalankan ulang installer${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}🔧 Sekarang akan memperbaiki dengan benar...${NC}"
echo ""

# Backup baru
NEW_BACKUP="dapp.js.backup-$(date +%Y%m%d-%H%M%S)"
cp dapp.js "$NEW_BACKUP"
echo -e "${GREEN}✓ New backup: $NEW_BACKUP${NC}"

# Fix yang BENAR - hanya ganti bagian yang diperlukan dengan hati-hati
# Cari baris dan ganti dengan tepat

# Versi 1: Jika ada netColor(`...`)
if grep -q "netColor(\`» Current Network:" dapp.js; then
    echo -e "${CYAN}Memperbaiki netColor()...${NC}"
    sed -i "s/netColor(\`» Current Network: \${net\.name\.toUpperCase()} (\${CONFIG\.chainId || 'Loading\.\.\.'})\`)/\`» Current Network: \${net.name.toUpperCase()} (\${CONFIG.chainId || 'Loading...'})\`/" dapp.js
fi

# Versi 2: Jika ada net.color(`...`)
if grep -q "net\.color(\`» Current Network:" dapp.js; then
    echo -e "${CYAN}Memperbaiki net.color()...${NC}"
    sed -i "s/net\.color(\`» Current Network: \${net\.name\.toUpperCase()} (\${CONFIG\.chainId || 'Loading\.\.\.'})\`)/\`» Current Network: \${net.name.toUpperCase()} (\${CONFIG.chainId || 'Loading...'})\`/" dapp.js
fi

# Hapus baris const netColor jika ada
if grep -q "const netColor = net\.color;" dapp.js; then
    echo -e "${CYAN}Menghapus definisi netColor...${NC}"
    sed -i '/const netColor = net\.color;/d' dapp.js
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅  PERBAIKAN SELESAI!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Verify syntax
echo -e "${CYAN}🔍 Verifikasi syntax JavaScript...${NC}"
if node -c dapp.js 2>/dev/null; then
    echo -e "${GREEN}✅ Syntax OK!${NC}"
    echo ""
    echo -e "${WHITE}🚀 Sekarang jalankan:${NC} ${GREEN}paxidev${NC}"
else
    echo -e "${RED}✗ Masih ada syntax error${NC}"
    echo -e "${YELLOW}  Coba restore manual dari backup${NC}"
fi

echo ""
