#!/bin/bash

# ================================================================
# PAXI DAPP UNINSTALLER
# Removes all traces of Paxi DApp installation
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                  PAXI DAPP UNINSTALLER                     ║
║              This will remove all installations            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}⚠️  WARNING: This will delete:${NC}"
echo "   • ~/paxi-dapp"
echo "   • All backups (~/paxi-dapp-backup-*)"
echo "   • Shortcuts and aliases"
echo "   • Transaction history"
echo ""

read -p "$(echo -e ${RED}Continue? \(yes/no\): ${NC})" -r CONFIRM

if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "\n${GREEN}Cancelled.${NC}\n"
    exit 0
fi

echo ""
echo -e "${CYAN}[1/6]${NC} ${YELLOW}Removing project folder...${NC}"
if [ -d ~/paxi-dapp ]; then
    rm -rf ~/paxi-dapp
    echo -e "${GREEN}✓ Removed ~/paxi-dapp${NC}"
else
    echo -e "${YELLOW}• No installation found${NC}"
fi

echo ""
echo -e "${CYAN}[2/6]${NC} ${YELLOW}Removing backups...${NC}"
BACKUP_COUNT=$(ls -d ~/paxi-dapp-backup-* 2>/dev/null | wc -l)
if [ $BACKUP_COUNT -gt 0 ]; then
    rm -rf ~/paxi-dapp-backup-*
    echo -e "${GREEN}✓ Removed $BACKUP_COUNT backup(s)${NC}"
else
    echo -e "${YELLOW}• No backups found${NC}"
fi

echo ""
echo -e "${CYAN}[3/6]${NC} ${YELLOW}Removing symbolic links...${NC}"
if [ -L "$PREFIX/bin/paxi" ]; then
    rm -f $PREFIX/bin/paxi
    echo -e "${GREEN}✓ Removed paxi command${NC}"
fi
if [ -L "$PREFIX/bin/paxi-update" ]; then
    rm -f $PREFIX/bin/paxi-update
    echo -e "${GREEN}✓ Removed paxi-update command${NC}"
fi

echo ""
echo -e "${CYAN}[4/6]${NC} ${YELLOW}Cleaning ~/.bashrc...${NC}"
if grep -q "paxi-dapp" ~/.bashrc 2>/dev/null; then
    # Backup bashrc
    cp ~/.bashrc ~/.bashrc.backup-$(date +%Y%m%d-%H%M%S)
    
    # Remove paxi-dapp lines
    sed -i '/paxi-dapp/d' ~/.bashrc
    sed -i '/alias paxi/d' ~/.bashrc
    
    echo -e "${GREEN}✓ Cleaned ~/.bashrc${NC}"
    echo -e "${YELLOW}  Backup saved to ~/.bashrc.backup-*${NC}"
else
    echo -e "${YELLOW}• No entries found in ~/.bashrc${NC}"
fi

echo ""
echo -e "${CYAN}[5/6]${NC} ${YELLOW}Clearing NPM cache...${NC}"
npm cache clean --force > /dev/null 2>&1
echo -e "${GREEN}✓ NPM cache cleared${NC}"

echo ""
echo -e "${CYAN}[6/6]${NC} ${YELLOW}Reloading environment...${NC}"
source ~/.bashrc 2>/dev/null
echo -e "${GREEN}✓ Environment reloaded${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅  UNINSTALLATION COMPLETED!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Removed:${NC}"
echo -e "  ${GREEN}✓${NC} Project folder"
echo -e "  ${GREEN}✓${NC} All backups"
echo -e "  ${GREEN}✓${NC} Commands & aliases"
echo -e "  ${GREEN}✓${NC} Environment entries"
echo ""
echo -e "${YELLOW}Note:${NC} Restart Termux or run ${CYAN}source ~/.bashrc${NC} to apply changes"
echo ""
echo -e "${CYAN}To reinstall, run the installer script again.${NC}"
echo ""
