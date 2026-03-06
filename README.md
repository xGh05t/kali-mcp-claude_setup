# kali-mcp-claude-setup

![Kali Linux](https://img.shields.io/badge/Kali_Linux-2024.x-557C94?style=flat&logo=kalilinux&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12+-3776AB?style=flat&logo=python&logoColor=white)
![Claude Desktop](https://img.shields.io/badge/Claude_Desktop-Latest-D97757?style=flat)
![MCP](https://img.shields.io/badge/MCP-Model_Context_Protocol-black?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

A complete guide for running **Claude Desktop natively on Kali Linux** with full Kali tool integration via the Model Context Protocol (MCP). This setup gives Claude Desktop direct access to 12 Kali Linux security tools, with port 5000 only open while Claude is running.

---

## How It Works

```
Claude Desktop  ──stdio──►  mcp_server.py  ──HTTP──►  kali_server.py (Flask :5000)  ──►  Kali Tools
```

Two processes work together — a Flask API that executes Kali tools locally, and an MCP server that bridges Claude Desktop to that API. Both are managed automatically by a wrapper script: they start when Claude Desktop launches, and stop when it closes.

---

## Prerequisites

- Kali Linux (2024.x or later)
- An [Anthropic account](https://claude.ai) (Claude Pro or above recommended)
- `curl`, `apt` — standard on Kali

---

## Installation

### 1. Install Claude Desktop

Claude Desktop is not officially packaged for Linux. A community-maintained Debian package is available:

```bash
# Add the GPG key
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] https://aaddrick.github.io/claude-desktop-debian stable main" | sudo tee /etc/apt/sources.list.d/claude-desktop.list

# Update and install
sudo apt update
sudo apt install claude-desktop
```

Launch Claude Desktop and sign in with your Anthropic account before continuing.

---

### 2. Install the Kali MCP Server

```bash
sudo apt install kali-server-mcp
```

This installs two scripts to `/usr/share/mcp-kali-server/`:

| File | Role |
|---|---|
| `kali_server.py` | Flask API — executes Kali tool commands |
| `mcp_server.py` | MCP server — bridges Claude Desktop to Flask API |

> ⚠️ The installed binary `/usr/bin/kali-server-mcp` only starts `kali_server.py` (the Flask API). Do **not** point Claude Desktop at this binary or pre-start it manually — the wrapper script in Step 3 handles everything.

---

### 3. Create the Wrapper Script

This script starts both processes together. Flask runs in the background; the MCP server runs in the foreground via stdio. When Claude Desktop closes, both processes exit.

```bash
sudo tee /usr/local/bin/kali-mcp-wrapper.sh << 'EOF'
#!/usr/bin/env bash
# Start the Flask API server in background
python3 /usr/share/mcp-kali-server/kali_server.py > /tmp/kali-api.log 2>&1 &
FLASK_PID=$!

# Give Flask a moment to bind to port 5000
sleep 1

# Start the MCP server (Claude Desktop communicates via stdio)
python3 /usr/share/mcp-kali-server/mcp_server.py

# When MCP server exits, kill Flask too
kill $FLASK_PID 2>/dev/null
EOF

sudo chmod +x /usr/local/bin/kali-mcp-wrapper.sh
```

---

### 4. Configure Claude Desktop

```bash
nano /home/kali/.config/Claude/claude_desktop_config.json
```

Add the `mcpServers` block to your config:

```json
{
  "preferences": {
    "coworkScheduledTasksEnabled": true,
    "ccdScheduledTasksEnabled": true,
    "sidebarMode": "task",
    "coworkWebSearchEnabled": true
  },
  "mcpServers": {
    "kali-tools": {
      "command": "/usr/local/bin/kali-mcp-wrapper.sh"
    }
  }
}
```

---

### 5. Restart Claude Desktop

Fully quit Claude Desktop (not just close the window) and relaunch it.

Verify both processes started:

```bash
ps -ef | grep -E "kali_server|mcp_server" | grep -v grep
ss -tlnp | grep 5000
```

Expected:
```
kali  xxxx  xxxx  python3 /usr/share/mcp-kali-server/kali_server.py
kali  xxxx  xxxx  python3 /usr/share/mcp-kali-server/mcp_server.py
LISTEN  127.0.0.1:5000
```

---

### 6. Verify the Connection

In a Claude Desktop chat:

> *"Use the `server_health` tool from your kali-tools MCP server and show me the result"*

A working response confirms all four core tools are available: `nmap`, `gobuster`, `dirb`, `nikto`.

---

## Available Tools

| Tool | Description |
|---|---|
| `nmap_scan` | Network and port scanner |
| `gobuster_scan` | Directory/DNS/vhost brute-force |
| `dirb_scan` | Web content/directory scanner |
| `nikto_scan` | Web server vulnerability scanner |
| `hydra_attack` | Network login brute-force |
| `john_crack` | Password hash cracker (John the Ripper) |
| `metasploit_run` | Metasploit framework execution |
| `sqlmap_scan` | SQL injection scanner |
| `enum4linux_scan` | Windows/Samba enumeration |
| `wpscan_analyze` | WordPress vulnerability scanner |
| `execute_command` | General command execution |
| `server_health` | API server health check |

---

## Monitoring

**Flask API logs** — shows every command executed in real time:
```bash
tail -f /tmp/kali-api.log
```

**Claude Desktop MCP logs:**
```bash
tail -f ~/.config/Claude/logs/mcp*.log
```

---

## Troubleshooting

### MCP fails to start — JSON parse errors in logs

**Symptom:** Errors like `Unexpected token '*', " * Serving "... is not valid JSON` in `~/.config/Claude/logs/`.

**Cause:** Claude Desktop is running `/usr/bin/kali-server-mcp` directly, which starts the Flask server and writes startup text to stdout. The MCP protocol expects only JSON on stdout, so Flask's log output corrupts the connection.

**Fix:** Make sure your config points to `/usr/local/bin/kali-mcp-wrapper.sh` (which runs `mcp_server.py`, not `kali_server.py`).

---

### Port 5000 already in use

**Symptom:** `Address already in use` in MCP logs. Flask fails to start.

**Cause:** You manually started `kali-server-mcp` or `kali_server.py` before launching Claude Desktop, and Claude Desktop tried to start a second instance.

**Fix:** Kill the existing instance before launching Claude Desktop:
```bash
pkill -f kali_server; pkill -f kali-server-mcp
```
Then let Claude Desktop start everything via the wrapper.

---

### Claude uses `bash_tool` instead of Kali MCP tools

**Symptom:** Simple commands like `whoami` run fine, but Claude says it used `bash_tool` rather than the kali-tools integration.

**Cause:** Claude defaults to its built-in bash tool for generic commands that don't require Kali-specific functionality.

**Fix:** This is expected behavior. Explicitly ask Claude to use a Kali-specific tool:
> *"Use the `nmap_scan` tool to scan..."*

Confirm the MCP is being used (not bash_tool) by checking that requests appear in `/tmp/kali-api.log`.

---

### Tools listed but `server_health` fails

**Symptom:** Claude can list the 12 tools but returns an error when trying to use them.

**Cause:** Flask API is not running — the wrapper script may have failed silently.

**Fix:**
```bash
# Check if Flask is running
ss -tlnp | grep 5000

# If not, check the Flask log for errors
cat /tmp/kali-api.log

# Restart Claude Desktop to re-trigger the wrapper
```

---

## Authorized Test Targets

Only use these tools against systems you own or are explicitly authorized to test. For verifying your setup:

| Target | Purpose | Authorized Tools |
|---|---|---|
| `scanme.nmap.org` | Nmap's official public test host | `nmap_scan` |
| `testphp.vulnweb.com` | Acunetix intentionally vulnerable site | `nikto_scan`, `gobuster_scan`, `dirb_scan`, `sqlmap_scan` |

---

## Security Notes

- Port 5000 is bound to `127.0.0.1` only — not exposed on your network interface
- Port 5000 is only open while Claude Desktop is running
- Claude will ask for context before running offensive tools — this is intentional

---

## Disclaimer

This guide is for **authorized security research, CTF challenges, and systems you own or have explicit permission to test**. Misuse of these tools may violate laws in your jurisdiction. The authors are not responsible for misuse.
