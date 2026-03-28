#!/usr/bin/env bash
# tools.sh
# Installs all tools required by the Kali MCP server.
# Run with: sudo bash tools.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run with sudo: sudo bash tools.sh"
  exit 1
fi

echo ""
echo "=== Kali MCP Tools Installer ==="
echo ""

echo "=== Step 1: MCP Server Package ==="
apt update -qq
apt install -y mcp-kali-server

for bin in kali-server-mcp mcp-server; do
  if command -v "$bin" &>/dev/null; then
    echo "[*] $bin -> $(which $bin)"
  else
    echo "[ERROR] $bin not found after install. Check: apt install mcp-kali-server"
    exit 1
  fi
done

echo ""
echo "=== Step 2: Recon & Scanning Tools ==="
apt install -y nmap gobuster dirb nikto

echo ""
echo "=== Step 3: Web App Testing Tools ==="
apt install -y sqlmap wpscan

echo ""
echo "=== Step 4: Password & Brute Force Tools ==="
apt install -y hydra john

echo ""
echo "=== Step 5: Enumeration Tools ==="
apt install -y enum4linux-ng

echo ""
echo "=== Step 6: Exploitation Framework ==="
apt install -y metasploit-framework

echo ""
echo "=== Step 7: Wordlists ==="
apt install -y wordlists

if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  echo "[*] Decompressing rockyou.txt..."
  gunzip -fv /usr/share/wordlists/rockyou.txt.gz
  echo "[*] rockyou.txt -> /usr/share/wordlists/rockyou.txt"
elif [ -f /usr/share/wordlists/rockyou.txt ]; then
  echo "[*] rockyou.txt already decompressed"
else
  echo "[!] rockyou.txt not found — wordlists package may name it differently"
fi

echo ""
echo "=== Verification: All Tools ==="
echo ""

TOOLS=(
  "kali-server-mcp" "mcp-server"
  "nmap" "gobuster" "dirb" "nikto"
  "sqlmap" "wpscan"
  "hydra" "john"
  "enum4linux-ng" "msfconsole"
)

ALL_OK=true
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    echo "  [ok] $tool"
  else
    echo "  [MISSING] $tool"
    ALL_OK=false
  fi
done

echo ""
if [ "$ALL_OK" = true ]; then
  echo "=== All tools installed successfully. ==="
  echo ""
  echo "  Next step: sudo bash setup.sh"
  echo "  Or if setup is already done, restart Claude Desktop."
else
  echo "[!] Some tools are missing. Check the output above."
  echo "    Try: sudo apt update && sudo apt install <tool>"
fi
echo ""