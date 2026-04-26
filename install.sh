#!/bin/bash

# ==============================================================================
# xarchive2ipa Installer
# Created by github.com/xyzuan
# ==============================================================================

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}Installing xarchive2ipa...${NC}"

# Check for swiftc
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}Error: swiftc not found. Please install Xcode or Command Line Tools.${NC}"
    exit 1
fi

# Compile
echo -e "${CYAN}Compiling native binary...${NC}"
swiftc main.swift -o xarchive2ipa -O

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Compilation failed.${NC}"
    exit 1
fi

# Move to /usr/local/bin
echo -e "${CYAN}Moving to /usr/local/bin (may require sudo)...${NC}"
sudo mv xarchive2ipa /usr/local/bin/xarchive2ipa

if [ $? -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Success! xarchive2ipa is now installed.${NC}"
    echo -e "You can now run ${BOLD}xarchive2ipa${NC} from anywhere."
else
    echo -e "${RED}Error: Failed to move binary to /usr/local/bin.${NC}"
    exit 1
fi
