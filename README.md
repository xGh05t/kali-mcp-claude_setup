# kali-mcp-claude_setup

![Kali Linux](https://img.shields.io/badge/Kali_Linux-2024.x+-557C94?style=flat&logo=kalilinux&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12+-3776AB?style=flat&logo=python&logoColor=white)
![Claude Desktop](https://img.shields.io/badge/Claude_Desktop-Latest-D97757?style=flat)
![MCP](https://img.shields.io/badge/MCP-Model_Context_Protocol-black?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

Run **Claude Desktop natively on Kali Linux** with direct access to 12 Kali security tools via the Model Context Protocol (MCP). Claude can run nmap scans, web directory fuzzing, hash cracking, SQL injection testing, and more — all from a chat window.

---

## What This Does

```
Claude Desktop  ──stdio──►  mcp-server  ──HTTP──►  kali-server-mcp (Flask :5000)  ──►  Kali Tools
```

Two processes run together whenever Claude Desktop is open:
- **`kali-server-mcp`** — a local Flask API on port 5000 that executes Kali tool commands
- **`mcp-server`** — bridges Claude Desktop to that API over stdio

A wrapper script starts both automatically when Claude Desktop launches and kills them when it closes. Port 5000 is only open while Claude is running, and it only listens on `127.0.0.1` (never exposed on your network).

---

## Scripts in This Repo

| Script | What It Does |
|---|---|
| `setup.sh` | Full setup: installs Claude Desktop, MCP server, all tools, wrapper script, and config |
| `tools.sh` | Tools only: installs and verifies all 12 Kali tools without touching Claude Desktop |

---

## Quick Install (Recommended)

Run the full setup script as root/sudo:

```bash
git clone https://github.com/xGh05t/kali-mcp-claude_setup.git
cd kali-mcp-claude_setup
sudo bash setup.sh
```

Then skip to [Verify It Works](#verify-it-works).

---

## Install Tools Only

If Claude Desktop is already set up and you just need to pull the Kali tools:

```bash
git clone https://github.com/xGh05t/kali-mcp-claude_setup.git
cd kali-mcp-claude_setup
sudo bash tools.sh
```

This installs all 12 tools, verifies each binary is reachable, and decompresses `rockyou.txt`. Output clearly shows a ✔ or ✘ for every tool so you know exactly what's ready.

---

## Manual Setup (Step by Step)

Follow these steps if you prefer to install manually or if the script fails.

---

### Step 1 — Install Claude Desktop

> Claude Desktop has no official Linux release. This uses a well-maintained community Debian package.

```bash
# Add the GPG key
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] \
https://aaddrick.github.io/claude-desktop-debian stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list

# Install
sudo apt update
sudo apt install claude-desktop
```

**Launch Claude Desktop and sign in to your Anthropic account before continuing.** The config file you need in Step 4 is only created after the first launch.

---

### Step 2 — Install the Kali MCP Server

```bash
sudo apt install mcp-kali-server
```

> ⚠️ The correct package name is **`mcp-kali-server`** — not `kali-server-mcp`. This installs two binaries: `kali-server-mcp` (the Flask API) and `mcp-server` (the MCP bridge).

Verify the install worked:

```bash
which kali-server-mcp   # should print /usr/bin/kali-server-mcp
which mcp-server        # should print /usr/bin/mcp-server
```

---

### Step 3 — Install the Security Tools

The MCP server can call these tools, but they need to be installed first. Use `tools.sh` or install manually:

```bash
sudo apt install -y \
  dirb gobuster nikto nmap enum4linux-ng \
  hydra john metasploit-framework sqlmap wpscan wordlists
```

Decompress the rockyou wordlist (used by john and hydra):

```bash
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
```

---

### Step 4 — Create the Wrapper Script

This script manages starting and stopping both processes together.

```bash
sudo tee /usr/local/bin/kali-mcp-wrapper.sh << 'EOF'
#!/usr/bin/env bash
# Kill any leftover instance first
pkill -f kali-server-mcp 2>/dev/null || true
sleep 0.5

# Start the Flask API in the background
kali-server-mcp > /tmp/kali-api.log 2>&1 &
FLASK_PID=$!

# Wait until port 5000 is ready (up to 10 seconds)
for i in $(seq 1 10); do
  sleep 1
  ss -tlnp 2>/dev/null | grep -q ':5000' && break
done

# Start the MCP bridge (Claude Desktop talks to this via stdio)
mcp-server

# Clean up when Claude Desktop closes
kill "$FLASK_PID" 2>/dev/null
EOF

sudo chmod +x /usr/local/bin/kali-mcp-wrapper.sh
```

> **Why not just run `kali-server-mcp` directly from Claude's config?**
> Because `kali-server-mcp` is the Flask API — it prints startup text to stdout. Claude Desktop expects only JSON on stdout (MCP protocol). Pointing Claude at `kali-server-mcp` directly will corrupt the connection with JSON parse errors. The wrapper runs `mcp-server` in the foreground (which speaks JSON), while Flask runs silently in the background.

---

### Step 5 — Configure Claude Desktop

Open (or create) your Claude Desktop config file:

```bash
nano ~/.config/Claude/claude_desktop_config.json
```

Add the `mcpServers` block. If your config already has content (like `preferences`), just add the `mcpServers` key alongside it:

```json
{
  "mcpServers": {
    "kali-tools": {
      "command": "/usr/local/bin/kali-mcp-wrapper.sh"
    }
  }
}
```

If you already have other content in the file, it should look like this:

```json
{
  "preferences": {
    "...your existing preferences..."
  },
  "mcpServers": {
    "kali-tools": {
      "command": "/usr/local/bin/kali-mcp-wrapper.sh"
    }
  }
}
```

Save and close.

---

### Step 6 — Restart Claude Desktop

Fully quit Claude Desktop (don't just close the window — use the menu or kill the process):

```bash
pkill -f claude-desktop
```

Then relaunch it. After it starts, verify both background processes are running:

```bash
ps -ef | grep -E "kali.server|mcp.server" | grep -v grep
```

You should see two processes. Also check Flask is listening:

```bash
ss -tlnp | grep 5000
```

Expected output: `LISTEN  127.0.0.1:5000`

---

## Verify It Works

In a Claude Desktop chat, type:

> *"Use the `server_health` tool from your kali-tools MCP server and show me the result"*

A successful response confirms the bridge is working. You should see all 12 tools listed as available.

---

## Available Tools

| Tool | What It Does |
|---|---|
| `nmap_scan` | Network and port scanning |
| `gobuster_scan` | Directory, DNS, and vhost brute-force |
| `dirb_scan` | Web content discovery |
| `nikto_scan` | Web server vulnerability scanning |
| `hydra_attack` | Network login brute-force |
| `john_crack` | Password hash cracking (John the Ripper) |
| `metasploit_run` | Metasploit Framework execution |
| `sqlmap_scan` | SQL injection testing |
| `enum4linux_scan` | Windows and Samba enumeration |
| `wpscan_analyze` | WordPress vulnerability scanning |
| `execute_command` | Run any shell command |
| `server_health` | Check that the API is running correctly |

---

## Monitoring

Watch the Flask API in real time (shows every tool command executed):

```bash
tail -f /tmp/kali-api.log
```

Watch the MCP connection logs:

```bash
tail -f ~/.config/Claude/logs/mcp*.log
```

---

## Troubleshooting

### "JSON parse errors" in MCP logs

**Symptom:** Errors like `Unexpected token '*', " * Serving "... is not valid JSON`

**Cause:** Your config is pointing at `kali-server-mcp` directly instead of the wrapper.

**Fix:** Make sure your config uses `/usr/local/bin/kali-mcp-wrapper.sh` as the command, not any other path.

---

### Port 5000 already in use

**Symptom:** Flask fails to start. `/tmp/kali-api.log` shows `Address already in use`.

**Fix:**

```bash
pkill -f kali-server-mcp
pkill -f kali-server-mcp   # run twice if needed
```

Then restart Claude Desktop.

---

### Tools listed but calls return errors

**Symptom:** Claude can list the 12 tools but gets errors when using them.

**Cause:** Flask API isn't running, or the tool isn't installed.

**Fix:**

```bash
# Check Flask is up
ss -tlnp | grep 5000

# Check Flask logs for errors
cat /tmp/kali-api.log

# Confirm the tool is installed, e.g.:
which nmap
```

Run `sudo bash tools.sh` to verify and reinstall any missing tools.

---

### Claude uses `bash_tool` instead of Kali tools

**Symptom:** Generic commands work, but Claude doesn't use the Kali MCP tools.

**Cause:** This is expected — Claude defaults to its built-in shell for generic commands. You need to explicitly ask for a Kali tool.

**Fix:** Be specific in your request:

> *"Use the `nmap_scan` tool to scan 192.168.1.1"*

Confirm it's using the MCP (not bash_tool) by checking `/tmp/kali-api.log` for the request.

---

## Authorized Test Targets

Only use these tools against systems you own or are explicitly authorized to test. For testing your setup:

| Target | Purpose | Safe Tools |
|---|---|---|
| `scanme.nmap.org` | Nmap's official public test host | `nmap_scan` |
| `testphp.vulnweb.com` | Acunetix intentionally vulnerable site | `nikto_scan`, `gobuster_scan`, `dirb_scan`, `sqlmap_scan` |

---

## Security Notes

- Port 5000 binds to `127.0.0.1` only — not accessible from other machines on your network
- Port 5000 is only open while Claude Desktop is running
- Claude will ask for context before running offensive tools — this is intentional behavior

---

## Disclaimer

This project is for **authorized security research, CTF challenges, and systems you own or have explicit written permission to test**. Unauthorized use of these tools against systems you don't own may violate computer crime laws in your jurisdiction. The authors accept no responsibility for misuse.
