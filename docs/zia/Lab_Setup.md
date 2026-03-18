# ZIA Demo Lab – Setup Guide

This document covers everything you need to have in place **before** you run
the demo scripts or walk a customer through the ZIA Demo Guide.

---

## 1. Prerequisites

### 1.1 Zscaler Tenant

| Item | Notes |
|------|-------|
| ZIA tenant | Production or sandbox. Free 60-day sandbox available via Zscaler. |
| Admin credentials | At minimum *Policy Administrator* role. |
| ZIA Service Edges / Nodes | Traffic must forward to ZIA; verify your forwarding method below. |

### 1.2 Lab Machines

| Machine | Role | Minimum Spec |
|---------|------|--------------|
| Windows 11 | End-user client (ZIA Client Connector installed) | 2 vCPU, 4 GB RAM |
| Ubuntu 22.04 | Traffic generator / Linux client | 2 vCPU, 2 GB RAM |

### 1.3 Traffic Forwarding

Traffic must be forwarded to ZIA. Choose **one** of the following methods:

| Method | When to Use |
|--------|-------------|
| **ZIA Client Connector** (recommended for demo) | Quickest setup; no PAC file or proxy config required on clients |
| **PAC File** | When Client Connector is not installed; point browsers to a hosted PAC file |
| **GRE / IPSec Tunnel** | For site-to-site forwarding from an on-prem router or firewall |

> **Demo tip:** Install ZIA Client Connector on the Windows 11 machine for the
> simplest setup. Connector download is at **Administration → Client Connector
> Portal**.

---

## 2. ZIA Tenant Configuration

### 2.1 SSL Inspection

SSL inspection is required for the DLP, Cloud App Control, and Advanced Threat
demos. Enable it before running the demo.

1. Navigate to **Policy → SSL Inspection**.
2. Enable **SSL Inspection** for the Default rule.
3. Download the **ZIA Root CA** certificate from **Administration → CA
   Management** and install it in the machine's trusted root store (or browser).

> **Skip this step** if you only plan to run the URL-filtering demo.

### 2.2 URL Categories & Policy

Navigate to **Policy → URL & Cloud App Control → URL Filtering** and verify
the following categories are either **blocked** or **allowed** for your demo.

#### Default Demo Policy Rules (create in order)

| Priority | Rule Name | Category | Action | Who |
|----------|-----------|----------|--------|-----|
| 1 | `Allow-Zscaler-Updates` | Software Updates | Allow | Any |
| 2 | `Block-Malware-Phishing` | Malware Sites, Phishing | Block (Custom Page) | Any |
| 3 | `Block-P2P-Torrents` | Peer-to-Peer | Block | Any |
| 4 | `Warn-Social-Media` | Social Networking | Caution (Warn) | Any |
| 5 | `Block-Adult-Content` | Adult Content, Gambling | Block | Any |
| 6 | `Allow-Business-Apps` | Cloud Storage, Productivity | Allow | Any |
| 7 | `Default-Allow` | Any | Allow | Any |

> **For the DLP demo**, add a rule before rule 7:
> `Block-Sensitive-Data-Upload` — Action: Block, DLP Dictionary: Credit Cards
> / SSNs.

### 2.3 Cloud App Control

Navigate to **Policy → URL & Cloud App Control → Cloud Application Control**.

Create the following application control rules:

| Rule Name | Application | Action |
|-----------|-------------|--------|
| `Allow-O365-Google` | Microsoft 365, Google Workspace | Allow |
| `Block-Unapproved-Storage` | Dropbox (personal), WeTransfer | Block |
| `Restrict-Social-Posts` | Twitter/X, Facebook | Allow (View Only) |

### 2.4 Advanced Threat Protection

Navigate to **Policy → Advanced Threat Protection**.

Ensure the following threat categories are set to **Block**:

- Adware / Spyware Sites
- Botnet Callback
- Command & Control (C2) Channels
- Cryptocurrency Mining
- Malware Sites
- Newly Registered Domains (set to **Caution** for demo)
- Phishing Sites

### 2.5 Data Loss Prevention (DLP)

Navigate to **Policy → Data Loss Prevention**.

Create the following DLP rules for the demo:

#### DLP Rule 1 – Block Credit Card Upload

| Field | Value |
|-------|-------|
| Rule Name | `Block-CC-Upload` |
| Channels | HTTPS, FTP, Email (SMTP) |
| DLP Dictionaries | `Credit Cards` (built-in) |
| Action | Block |

#### DLP Rule 2 – Warn on SSN / NPI Data

| Field | Value |
|-------|-------|
| Rule Name | `Warn-SSN-Upload` |
| Channels | HTTPS |
| DLP Dictionaries | `US Social Security Numbers`, `US Health Information` |
| Action | Allow (with Audit Log) |

### 2.6 Bandwidth Control

Navigate to **Policy → Bandwidth Control**.

| Rule Name | Category | Max Bandwidth |
|-----------|----------|---------------|
| `Limit-Streaming-Video` | Streaming Video | 5 Mbps |
| `Limit-File-Sharing` | File Sharing | 10 Mbps |

---

## 3. Demo Users & Groups

Create or verify the following users in your IdP (Azure AD, Okta, Ping) and
sync them to ZIA via SCIM or manual import.

| Persona | Username | Department | ZIA Group |
|---------|----------|------------|-----------|
| IT Admin | `bob.jones` | IT | `ZIA-Admins` |
| Developer | `alice.smith` | Engineering | `ZIA-Developers` |
| Contractor | `carol.white` | Contractor | `ZIA-Contractors` |
| HR Analyst | `dave.hr` | HR | `ZIA-HR` |

Create user groups in ZIA at **Administration → User Management → Groups**.

---

## 4. ZIA Client Connector Setup (Windows 11)

1. In the ZIA Admin Portal navigate to **Administration → Client Connector
   Portal**.
2. Download the **Windows Client Connector** installer.
3. Install on the Windows 11 machine.
4. Sign in with a user account that is defined in ZIA User Management.
5. Verify that the client shows **Connected** (green icon in system tray).
6. Open a browser and navigate to `https://zscaler.com` — confirm you see a
   Zscaler certificate in the browser's padlock (indicates SSL inspection is
   active).

---

## 5. Ubuntu Client Connector Setup

Run on the Ubuntu machine as root:

```bash
sudo bash scripts/zia/linux/setup_zia_client.sh
```

The script will:
- Add the Zscaler APT repository.
- Install `zscaler-client-connector`.
- Prompt you to authenticate with your ZIA tenant credentials.
- Set system-wide proxy settings so all traffic routes through ZIA.

---

## 6. Verification Checklist

Before running the demo, verify:

- [ ] ZIA Client Connector on Windows 11 shows **Connected** (green icon).
- [ ] ZIA Client Connector on Ubuntu shows the proxy is active.
- [ ] Navigate to `https://ip.zscaler.com` — page confirms traffic is flowing
      through ZIA and displays your assigned ZIA node.
- [ ] Open `https://malware.wicar.org/data/eicar.com` — ZIA should **block**
      this (EICAR test file).
- [ ] Open a social networking site — ZIA should show a **Caution/Warn** page.
- [ ] SSL inspection is working: check the browser padlock certificate for any
      HTTPS site — issuer should be **Zscaler Root CA**.
- [ ] DLP rule fires: try uploading a file containing `4111-1111-1111-1111` to
      any cloud storage site — should be blocked.
- [ ] Bandwidth rule is visible in **Analytics → Bandwidth Report**.

---

## 7. Troubleshooting

| Symptom | Check |
|---------|-------|
| Client Connector not connecting | Verify tenant URL in connector config. Check outbound 443 to `*.zscaler.net`. |
| SSL inspection not working | Root CA not installed in system/browser trust store. Reinstall the ZIA CA. |
| URL block page not showing | Verify correct URL category is mapped to a Block rule. Use **URL Category Lookup** in the portal. |
| DLP rule not firing | Confirm DLP profile is attached to the correct rule. Check channel (HTTPS vs HTTP). |
| `ip.zscaler.com` shows direct IP | Traffic not routing through ZIA. Check Client Connector is connected and proxy settings are active. |
| Linux script fails | Verify `curl` and `wget` are installed; confirm system proxy env vars (`http_proxy`, `https_proxy`) are set. |
