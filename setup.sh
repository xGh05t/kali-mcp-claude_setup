#!/usr/bin/env bash
# kali-mcp-claude-setup
# Automates Claude Desktop + Kali MCP Server setup on Kali Linux

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Prints a full-width section header with visible separator lines
section() {
  echo ""
  echo -e "${BLUE}ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
}

echo ""
echo "âââââââââââââââââââââââââââââââââââââââââââââââ"
echo "â     Claude Desktop + Kali MCP Setup          "\+"| "
echo "ââââââââââââââââââââââââââââââââââââââââââââââââ"
echo ""

# Make sure we're on Kali
if ! grep -qi kali /etc/os-release 2>/dev/null; then
  warn "This script is designed for Kali Linux. Continuing anyway..."
fi

# Must be run with sudo
if [ "$EUID" -ne 0 ]; then
  error "Please run with sudo: sudo bash setup.sh"
fi

# Determine the actual user's home directory
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

section "Step 1: Claude Desktop"

info "Adding Claude Desktop repository (community package for Linux)..."
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
  | gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg

echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] \
https://aaddrick.github.io/claude-desktop-debian stable main" \
  | tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null

info "Updating package list..."
apt update -qq

info "Installing Claude Desktop..."
apt install -y claude-desktop

section "Step 2: Kali MCP Server"

info "Installing mcp-kali-server..."
apt install -y mcp-kali-server

# Verify the binaries exist
if ! command -v kali-server-mcp &>/dev/null; then
  error "kali-server-mcp binary not found. Try: sudo apt install mcp-kali-server"
fi
if ! command -v mcp-server &>/dev/null; then
  error "mcp-server binary not found. Try: sudo apt install mcp-kali-server"
fi
info "Verified: kali-server-mcp and mcp-server are installed."

section "Step 3: Security Tools"

info "Installing required Kali security tools..."
apt install -y \
  dirb gobuster nikto nmap enum4linux-ng \
  hydra john metasploit-framework sqlmap wpscan wordlists

# Decompress rockyou wordlist if needed
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  info "Decompressing rockyou wordlist..."
  gunzip -fv /usr/share/wordlists/rockyou.txt.gz
fi

section "Step 4: Wrapper Script"

info "Creating MCP wrapper script at /usr/local/bin/kali-mcp-wrapper.sh..."
tee /usr/local/bin/kali-mcp-wrapper.sh > /dev/null << 'EOF'
#!/usr/bin/env bash
# kali-mcp-wrapper.sh
# Starts both the Kali API server and MCP bridge for Claude Desktop.
# This script is called automatically when Claude Desktop launches.

# Kill any leftover instance of the API server
pkill -f kali-server-mcp 2>/dev/null || true
sleep 0.5

# Start the Flask API server in the background
kali-server-mcp > /tmp/kali-api.log 2>&1 &
FLASK_PID=$!

# Wait until port 5000 is ready (up to 10 seconds)
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

# Start the MCP server - Claude Desktop talks to it via stdio
mcp-server

# Cleanup when Claude Desktop closes
kill "$FLASK_PID" 2>/dev/null
EOF

chmod +x /usr/local/bin/kali-mcp-wrapper.sh
info "Wrapper script created and made executable."

section "Step 5: Claude Desktop Config"

CONFIG_DIR="$REAL_HOME/.config/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"
mkdir -p "$CONFIG_DIR"
chown "$REAL_USER:$REAL_USER" "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
  info "Backing up existing config to ${CONFIG_FILE}.bak"
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

  if grep -q '"mcpServers"' "$CONFIG_FILE"; then
    warn "mcpServers block already exists in your config - skipping to avoid overwrite."
    warn "If kali-tools is missing, add it manually:"
    warn '  "kali-tools": { "command": "/usr/local/bin/kali-mcp-wrapper.sh" }'
  else
    info "Injecting mcpServers into existing config..."
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
  info "Writing new Claude Desktop config..."
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
info "Config saved to: $CONFIG_FILE"

echo ""
echo -e "${GREEN}âââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
echo -e "${GREEN}â     Setup complete!                          â${NC}"
echo -e "${GREEN}ââââââââââââââââââââââââââââââââââââââââââââââââ${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "    1. Launch Claude Desktop and sign in"
echo "    2. Start a new chat and type:"
echo '       "Use the server_health tool from your kali-tools MCP server"'
echo "    3. You should see all 12 tools confirmed as available"
echo ""
echo "  Logs to monitor:"
echo "    tail -f /tmp/kali-api.log"
echo "    tail -f ~/.config/Claude/logs/mcp*.log"
echo ""
