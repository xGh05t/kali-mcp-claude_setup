#!/usr/bin/env bash
# tools.sh
# Installs all tools required by the Kali MCP server.
# Run with: sudo bash tools.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
ok()      { echo -e "  ${GREEN}â${NC} $1"; }
missing() { echo -e "  ${RED}â${NC} $1 â not found"; }

# Prints a full-width section header with visible separator lines
section() {
  echo ""
  echo -e "${BLUE}ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
}

echo ""
echo "ââââââââââââââââââââââââââââââââââââââââââââââââ"
echo "â     Kali MCP Tools Installer                 â"
echo "ââââââââââââââââââââââââââââââââââââââââââââââââ"
echo ""

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  error "Please run with sudo: sudo bash tools.sh"
fi

# ââ Step 1 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 1: MCP Server Package"

info "Updating package list..."
apt update -qq

info "Installing mcp-kali-server..."
apt install -y mcp-kali-server

# Verify both binaries exist
for bin in kali-server-mcp mcp-server; do
  if command -v "$bin" &>/dev/null; then
    ok "$bin â $(which $bin)"
  else
    error "$bin not found after install. Check: apt install mcp-kali-server"
  fi
done

# ââ Step 2 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 2: Recon & Scanning Tools"

info "Installing nmap, gobuster, dirb, nikto..."
apt install -y nmap gobuster dirb nikto

# ââ Step 3 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 3: Web App Testing Tools"

info "Installing sqlmap, wpscan..."
apt install -y sqlmap wpscan

# ââ Step 4 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 4: Password & Brute Force Tools"

info "Installing hydra, john..."
apt install -y hydra john

# ââ Step 5 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 5: Enumeration Tools"

info "Installing enum4linux-ng..."
apt install -y enum4linux-ng

# ââ Step 6 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 6: Exploitation Framework"

info "Installing metasploit-framework..."
apt install -y metasploit-framework

# ââ Step 7 ââââââââââââââââââââââââââââââââââââââââââââââââââââ
section "Step 7: Wordlists"

info "Installing wordlists package..."
apt install -y wordlists

if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  info "Decompressing rockyou.txt..."
  gunzip -fv /usr/share/wordlists/rockyou.txt.gz
  ok "rockyou.txt â /usr/share/wordlists/rockyou.txt"
elif [ -f /usr/share/wordlists/rockyou.txt ]; then
  ok "rockyou.txt already decompressed"
else
  warn "rockyou.txt not found â wordlists package may name it differently"
fi

# ââ Verification âââââââââââââââââââââââââââââââââââââââââââââââ
section "Verification â All Tools"

echo ""
TOOLS=(
  "kali-server-mcp"
  "mcp-server"
  "nmap"
  "gobuster"
  "dirb"
  "nikto"
  "sqlmap"
  "wpscan"
  "hydra"
  "john"
  "enum4linux-ng"
  "msfconsole"
)

ALL_OK=true
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool"
  else
    missing "$tool"
    ALL_OK=false
  fi
done

echo ""
if [ "$ALL_OK" = true ]; then
  echo -e "${GREEN}ââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
  echo -e "${GREEN}â     All tools installed successfully.        â${NC}"
  echo -e "${GREEN}ââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
  echo ""
  echo "  Next step: run the full setup"
  echo "    sudo bash setup.sh"
  echo "  Or if setup is already done, restart Claude Desktop."
else
  echo -e "${YELLOW}[!]${NC} Some tools are missing. Check the output above."
  echo "  Try running: sudo apt update && sudo apt install <tool>"
fi
echo ""
