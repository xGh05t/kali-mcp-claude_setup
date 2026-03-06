#!/usr/bin/env bash
# kali-mcp-claude-setup
# Automates Claude Desktop + Kali MCP Server setup on Kali Linux

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "================================================"
echo "  Claude Desktop + Kali MCP Setup"
echo "================================================"
echo ""

# --- Step 1: Install Claude Desktop ---
info "Adding Claude Desktop repository..."
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg
echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] https://aaddrick.github.io/claude-desktop-debian stable main" | sudo tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null

info "Installing Claude Desktop and kali-server-mcp..."
sudo apt update -qq
sudo apt install -y claude-desktop kali-server-mcp

# --- Step 2: Create wrapper script ---
info "Creating MCP wrapper script..."
sudo tee /usr/local/bin/kali-mcp-wrapper.sh > /dev/null << 'EOF'
#!/usr/bin/env bash
python3 /usr/share/mcp-kali-server/kali_server.py > /tmp/kali-api.log 2>&1 &
FLASK_PID=$!
sleep 1
python3 /usr/share/mcp-kali-server/mcp_server.py
kill $FLASK_PID 2>/dev/null
EOF
sudo chmod +x /usr/local/bin/kali-mcp-wrapper.sh

# --- Step 3: Configure Claude Desktop ---
CONFIG_DIR="/home/${SUDO_USER:-$USER}/.config/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
    info "Backing up existing config to ${CONFIG_FILE}.bak"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Check if mcpServers already exists
    if grep -q '"mcpServers"' "$CONFIG_FILE"; then
        warn "mcpServers already present in config — skipping. Edit manually if needed:"
        warn "  $CONFIG_FILE"
    else
        # Inject mcpServers block before the last closing brace
        info "Adding mcpServers to existing config..."
        python3 - "$CONFIG_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
config["mcpServers"] = {"kali-tools": {"command": "/usr/local/bin/kali-mcp-wrapper.sh"}}
with open(sys.argv[1], "w") as f:
    json.dump(config, f, indent=2)
PYEOF
    fi
else
    info "Writing new Claude Desktop config..."
    cat > "$CONFIG_FILE" << 'EOF'
{
  "mcpServers": {
    "kali-tools": {
      "command": "/usr/local/bin/kali-mcp-wrapper.sh"
    }
  }
}
EOF
fi

# --- Done ---
echo ""
echo "================================================"
echo -e "  ${GREEN}Setup complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Launch Claude Desktop and sign in"
echo "  2. Start a new chat and run:"
echo '     "Use the server_health tool from your kali-tools MCP server"'
echo ""
echo "Logs:"
echo "  Flask API:   tail -f /tmp/kali-api.log"
echo "  MCP server:  tail -f ~/.config/Claude/logs/mcp*.log"
echo ""
