#!/bin/bash

# ================================================================
# ULTIMATE FIX - Hapus warna di Current Network
# Solusi paling simple: ganti jadi plain text tanpa warna
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🔧 ULTIMATE NETCOLOR FIX            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check file
if [ ! -f ~/paxi-dapp/dapp.js ]; then
    echo -e "${RED}✗ File ~/paxi-dapp/dapp.js tidak ada!${NC}"
    echo -e "${YELLOW}  Jalankan installer terlebih dahulu${NC}"
    exit 1
fi

cd ~/paxi-dapp || exit 1

# Backup
BACKUP="dapp.js.backup-$(date +%Y%m%d-%H%M%S)"
cp dapp.js "$BACKUP"
echo -e "${GREEN}✓ Backup: $BACKUP${NC}"
echo ""

# Tampilkan baris yang akan diubah
echo -e "${YELLOW}🔍 Mencari baris bermasalah...${NC}"
LINE_BEFORE=$(grep -n "netColor(\`» Current Network:\|net\.color(\`» Current Network:" dapp.js | head -1)

if [ -z "$LINE_BEFORE" ]; then
    echo -e "${RED}✗ Baris tidak ditemukan!${NC}"
    echo -e "${YELLOW}  Kemungkinan sudah diperbaiki${NC}"
    rm "$BACKUP"
    exit 0
fi

echo -e "${CYAN}Ditemukan di: $LINE_BEFORE${NC}"
echo ""

# Fix 1: Hapus definisi netColor yang tidak perlu
sed -i '/const netColor = net\.color;/d' dapp.js

# Fix 2: Ganti semua netColor(`...`) atau net.color(`...`) dengan plain string
sed -i "s/netColor(\(\`» Current Network:[^)]*\))/\1/" dapp.js
sed -i "s/net\.color(\(\`» Current Network:[^)]*\))/\1/" dapp.js

echo -e "${GREEN}✅ PERBAIKAN SELESAI!${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${WHITE}Perubahan:${NC}"
echo -e "${CYAN}•${NC} Dihapus: ${YELLOW}const netColor = net.color;${NC}"
echo -e "${CYAN}•${NC} Diganti: ${YELLOW}netColor() / net.color()${NC} → ${GREEN}plain text${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Verifikasi
if grep -q "netColor(\`» Current Network:\|net\.color(\`» Current Network:" dapp.js; then
    echo -e "${RED}⚠ Masih ada sisa yang belum terperbaiki${NC}"
    echo -e "${YELLOW}  Coba jalankan manual fix${NC}"
else
    echo -e "${GREEN}✅ Semua referensi berhasil dihapus!${NC}"
fi

echo ""
echo -e "${WHITE}🚀 Sekarang jalankan:${NC} ${GREEN}paxidev${NC}"
echo ""
