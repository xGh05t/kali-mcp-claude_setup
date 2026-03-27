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
section() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
ok()      { echo -e "  ${GREEN}✔${NC} $1"; }
missing() { echo -e "  ${RED}✘${NC} $1 — not found"; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     Kali MCP Tools Installer                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  error "Please run with sudo: sudo bash tools.sh"
fi

# ─────────────────────────────────────────────────────────────
section "Step 1: MCP Server Package"
# ─────────────────────────────────────────────────────────────
info "Installing mcp-kali-server..."
apt update -qq
apt install -y mcp-kali-server

# Verify
for bin in kali-server-mcp mcp-server; do
  if command -v "$bin" &>/dev/null; then
    ok "$bin → $(which $bin)"
  else
    error "$bin not found after install. Check: apt install mcp-kali-server"
  fi
done

# ─────────────────────────────────────────────────────────────
section "Step 2: Recon & Scanning Tools"
# ─────────────────────────────────────────────────────────────
info "Installing nmap, gobuster, dirb, nikto..."
apt install -y nmap gobuster dirb nikto

# ─────────────────────────────────────────────────────────────
section "Step 3: Web App Testing Tools"
# ─────────────────────────────────────────────────────────────
info "Installing sqlmap, wpscan..."
apt install -y sqlmap wpscan

# ─────────────────────────────────────────────────────────────
section "Step 4: Password & Brute Force Tools"
# ─────────────────────────────────────────────────────────────
info "Installing hydra, john..."
apt install -y hydra john

# ─────────────────────────────────────────────────────────────
section "Step 5: Enumeration Tools"
# ─────────────────────────────────────────────────────────────
info "Installing enum4linux-ng..."
apt install -y enum4linux-ng

# ─────────────────────────────────────────────────────────────
section "Step 6: Exploitation Framework"
# ─────────────────────────────────────────────────────────────
info "Installing metasploit-framework..."
apt install -y metasploit-framework

# ─────────────────────────────────────────────────────────────
section "Step 7: Wordlists"
# ─────────────────────────────────────────────────────────────
info "Installing wordlists package..."
apt install -y wordlists

if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  info "Decompressing rockyou.txt..."
  gunzip -fv /usr/share/wordlists/rockyou.txt.gz
  ok "rockyou.txt → /usr/share/wordlists/rockyou.txt"
elif [ -f /usr/share/wordlists/rockyou.txt ]; then
  ok "rockyou.txt already decompressed"
else
  warn "rockyou.txt not found — wordlists package may name it differently"
fi

# ─────────────────────────────────────────────────────────────
section "Verification — All Tools"
# ─────────────────────────────────────────────────────────────
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
  echo -e "  ${GREEN}All tools installed successfully.${NC}"
  echo ""
  echo "  Next step: run the full setup"
  echo "    sudo bash setup.sh"
  echo "  Or if setup is already done, restart Claude Desktop."
else
  echo -e "  ${YELLOW}Some tools are missing. Check the output above.${NC}"
  echo "  Try running: sudo apt update && sudo apt install <tool>"
fi
echo ""
