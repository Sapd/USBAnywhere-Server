# Troubleshooting Guide — USBAnywhere Server

## Common Issues

### 1. Application won't start

**Solutions**:
1. Right-click `USBAnywhere-Server.exe` → **Run as administrator**
2. Check Windows Event Viewer or `%AppData%\USBAnywhere-Server\logs` (or `logs\` in Portable mode)

---

### 2. Driver installation fails

**Solutions**:
1. Restart Windows if a Windows Update is pending
2. Manual install: `msiexec /i drivers\usbipd-win.msi` from an Administrator prompt

---

### 3. Client can't see or connect to the server

**Solutions**:
1. Open **⚙️ Settings** in USBAnywhere Server and click **🛡️ Configure Firewall** to open TCP port 3240
2. Or run in Administrator PowerShell:
   ```powershell
   New-NetFirewallRule -DisplayName "USBAnywhere Server (TCP 3240)" -Direction Inbound -Protocol TCP -LocalPort 3240 -Action Allow
   ```
3. Verify the device shows `Shared` status in USBAnywhere Server

---

## Getting Help

- [USBAnywhere Server Issues](https://github.com/oscarlosu-lab/USBAnywhere-Server/issues)
- [USBAnywhere Client Repository](https://github.com/oscarlosu-lab/USBAnywhere)
