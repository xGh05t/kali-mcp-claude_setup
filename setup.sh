#!/usr/bin/env bash
# kali-mcp-claude-setup

set -e

if ! grep -qi kali /etc/os-release 2>/dev/null; then
  echo "[!] This script is designed for Kali Linux. Continuing anyway..."
fi

if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run with sudo: sudo bash setup.sh"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Step 1: Claude Desktop
echo ""
echo "=== Step 1: Claude Desktop ==="

echo "[*] Adding Claude Desktop repository..."
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg

echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] \
https://aaddrick.github.io/claude-desktop-debian stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null

echo "[*] Updating package list..."
sudo apt update

echo "[*] Installing Claude Desktop..."
sudo apt install -y claude-desktop

# Step 2: Kali MCP Server
echo ""
echo "=== Step 2: Kali MCP Server ==="

echo "[*] Installing mcp-kali-server..."
sudo apt install -y mcp-kali-server

command -v kali-server-mcp &>/dev/null || { echo "[ERROR] kali-server-mcp not found."; exit 1; }
command -v mcp-server &>/dev/null || { echo "[ERROR] mcp-server not found."; exit 1; }
echo "[*] Verified: kali-server-mcp and mcp-server are installed."

# Step 3: Security Tools
echo ""
echo "=== Step 3: Security Tools ==="

echo "[*] Installing required Kali security tools..."
sudo apt install -y \
  dirb gobuster nikto nmap enum4linux-ng \
  hydra john metasploit-framework sqlmap wpscan wordlists

if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  echo "[*] Decompressing rockyou wordlist..."
  sudo gunzip -fv /usr/share/wordlists/rockyou.txt.gz
fi

# Step 4: Wrapper Script
echo ""
echo "=== Step 4: Wrapper Script ==="

echo "[*] Creating MCP wrapper script at /usr/local/bin/kali-mcp-wrapper.sh..."
tee /usr/local/bin/kali-mcp-wrapper.sh > /dev/null << 'EOF'
#!/usr/bin/env bash
pkill -f kali-server-mcp 2>/dev/null || true
sleep 0.5

kali-server-mcp > /tmp/kali-api.log 2>&1 &
FLASK_PID=$!

READY=0
for i in $(seq 1 10); do
  sleep 1
  if ss -tlnp 2>/dev/null | grep -q ':5000'; then
    READY=1
    break
  fi
done

if [ "$READY" -eq 0 ]; then
  echo "[kali-mcp-wrapper] ERROR: Flask API failed to start. Check /tmp/kali-api.log" >&2
  kill "$FLASK_PID" 2>/dev/null
  exit 1
fi

mcp-server
kill "$FLASK_PID" 2>/dev/null
EOF

chmod +x /usr/local/bin/kali-mcp-wrapper.sh
echo "[*] Wrapper script created."

# Step 5: Claude Desktop Config
echo ""
echo "=== Step 5: Claude Desktop Config ==="

CONFIG_DIR="$REAL_HOME/.config/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"
mkdir -p "$CONFIG_DIR"
chown "$REAL_USER:$REAL_USER" "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
  echo "[*] Backing up existing config to ${CONFIG_FILE}.bak"
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

  if grep -q '"mcpServers"' "$CONFIG_FILE"; then
    echo "[!] mcpServers block already exists — skipping to avoid overwrite."
    echo '[!] If kali-tools is missing, add it manually: "kali-tools": { "command": "/usr/local/bin/kali-mcp-wrapper.sh" }'
  else
    echo "[*] Injecting mcpServers into existing config..."
    python3 - "$CONFIG_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
config.setdefault("mcpServers", {})["kali-tools"] = {
    "command": "/usr/local/bin/kali-mcp-wrapper.sh"
}
with open(sys.argv[1], "w") as f:
    json.dump(config, f, indent=2)
print(f"Config updated: {sys.argv[1]}")
PYEOF
  fi
else
  echo "[*] Writing new Claude Desktop config..."
  cat > "$CONFIG_FILE" << 'JSONEOF'
{
  "mcpServers": {
    "kali-tools": {
      "command": "/usr/local/bin/kali-mcp-wrapper.sh"
    }
  }
}
JSONEOF
fi

chown "$REAL_USER:$REAL_USER" "$CONFIG_FILE"
echo "[*] Config saved to: $CONFIG_FILE"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "  Next steps:"
echo "    1. Launch Claude Desktop and sign in"
echo '    2. Type: "Use the server_health tool from your kali-tools MCP server"'
echo "    3. You should see all 12 tools confirmed as available"
echo ""
echo "  Logs: tail -f /tmp/kali-api.log"
echo "        tail -f ~/.config/Claude/logs/mcp*.log"