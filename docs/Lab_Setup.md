# ZPA Demo Lab – Setup Guide

This document covers everything you need to have in place **before** you run
the demo scripts or walk a customer through the ZPA Demo Guide.

---

## 1. Prerequisites

### 1.1 Zscaler Tenant

| Item | Notes |
|------|-------|
| ZPA tenant | Production or sandbox. Free 60-day sandbox available via Zscaler. |
| Admin credentials | At minimum *App Connector Group Admin* + *Policy Admin* roles. |
| ZPA App Connector provisioning key | Generated in **Administration → App Connectors → Add App Connector Group**. |
| ZPA Client Connector portal access | To create the Windows-client enrollment token. |

### 1.2 Lab Machines

| Machine | Role | Minimum Spec |
|---------|------|--------------|
| Ubuntu 22.04 Server | ZPA App Connector | 2 vCPU, 4 GB RAM, 20 GB disk |
| Windows Server 2022 | Internal app host (IIS, RDP, SMB) | 2 vCPU, 4 GB RAM, 40 GB disk |
| Windows 11 | ZPA Client Connector (end-user) | 2 vCPU, 4 GB RAM |

All three machines must be on the **same LAN segment** (or the Ubuntu connector
must have IP connectivity to the Windows Server).

> **Important:** The App Connector makes **outbound-only** connections to ZPA
> cloud. No inbound firewall rules are needed for the connector itself.

### 1.3 Network

| Requirement | Value |
|-------------|-------|
| Lab subnet | 192.168.1.0/24 (adjust to match your environment) |
| Ubuntu connector IP | 192.168.1.10 |
| Windows Server IP | 192.168.1.20 |
| Windows client IP | 192.168.1.30 (DHCP is fine) |
| Outbound HTTPS (443) | Required from all machines to `*.zscaler.net`, `*.zscalerone.net`, `*.zscalertwo.net`, etc. |

---

## 2. ZPA Tenant Configuration

### 2.1 Create a Connector Group & Provisioning Key

1. Log in to the **ZPA Admin Portal** → **Administration** →
   **App Connectors**.
2. Click **Add App Connector Group**:
   - Name: `Lab-Connector-Group`
   - Location: your lab location
   - Upgrade schedule: *Default*
3. Inside the group, click **Add Provisioning Key**.
   - Name: `Ubuntu-Lab-Connector`
   - Max usage count: `1` (one connector in the lab)
   - Copy the key — you will paste it into `setup_app_connector.sh`.

### 2.2 Create Application Segments

Create the following segments to cover the Windows Server services. Navigate
to **Applications → Application Segments** → **Add Application Segment**.

#### Segment 1 – Lab Web Apps

| Field | Value |
|-------|-------|
| Name | `Lab-WebApps` |
| Enabled | Yes |
| Domain / IP | `192.168.1.20` |
| TCP Ports | `80, 443, 8080, 8443` |
| Connector Group | `Lab-Connector-Group` |

#### Segment 2 – Lab RDP

| Field | Value |
|-------|-------|
| Name | `Lab-RDP` |
| Enabled | Yes |
| Domain / IP | `192.168.1.20` |
| TCP Port | `3389` |
| Connector Group | `Lab-Connector-Group` |

#### Segment 3 – Lab SMB / File Shares

| Field | Value |
|-------|-------|
| Name | `Lab-FileShare` |
| Enabled | Yes |
| Domain / IP | `192.168.1.20` |
| TCP Ports | `445, 139` |
| Connector Group | `Lab-Connector-Group` |

#### Segment 4 – Lab SSH (Ubuntu)

| Field | Value |
|-------|-------|
| Name | `Lab-SSH` |
| Enabled | Yes |
| Domain / IP | `192.168.1.10` |
| TCP Port | `22` |
| Connector Group | `Lab-Connector-Group` |

#### Segment 5 – "Shadow IT" App (used for policy-block demo)

| Field | Value |
|-------|-------|
| Name | `Lab-Shadow-App` |
| Enabled | Yes |
| Domain / IP | `192.168.1.20` |
| TCP Port | `9090` |
| Connector Group | `Lab-Connector-Group` |

> Leave this segment **without** an access policy so the block demo works.

### 2.3 Create Server Groups

Navigate to **Applications → Server Groups** → **Add Server Group**.

| Name | Application Segments | Dynamic Discovery |
|------|----------------------|-------------------|
| `Lab-Servers` | All five segments above | **Enabled** |

Enabling **Dynamic Discovery** is what powers the App Discovery demo — ZPA
App Discovery will scan and surface additional ports/services automatically.

### 2.4 Create an Access Policy

Navigate to **Policy → Access Policy** → **Add Rule**.

#### Rule 1 – Allow Lab Users Full Access

| Field | Value |
|-------|-------|
| Rule Name | `Allow-Lab-Users-WebRDP-SMB` |
| Action | Allow |
| Conditions | SAML Attribute **department** = `Lab` (or your IdP attribute) |
| Application | `Lab-WebApps`, `Lab-RDP`, `Lab-FileShare`, `Lab-SSH` |

> **Do NOT** add `Lab-Shadow-App` — this intentional gap is what the
> policy-block demo demonstrates.

#### Rule 2 – Block All Other Private Apps (optional but recommended)

| Field | Value |
|-------|-------|
| Rule Name | `Block-Unentitled-Apps` |
| Action | Block |
| Conditions | Any user |
| Application | `Lab-Shadow-App` |

### 2.5 Enrol the ZPA Client on Windows 11

1. Download **ZPA Client Connector** from the ZPA Portal →
   **Administration → Client Connector**.
2. Install on the Windows 11 machine.
3. Sign in with an account that matches the SAML attribute set in the policy.

---

## 3. App Connector Installation (Ubuntu)

Run the install script as root on the Ubuntu Server:

```bash
sudo bash scripts/linux/setup_app_connector.sh
```

The script will:
- Install Docker (if not present) or the native App Connector package.
- Prompt for the provisioning key you created in step 2.1.
- Start the `zpa-connector` service.
- Show the connector status.

After a minute or two, the connector will appear as **Connected** in the ZPA
Admin Portal under **Administration → App Connectors**.

---

## 4. Windows Server App Setup

Run the PowerShell setup script on the Windows Server as an **Administrator**:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\windows\setup_internal_apps.ps1
```

The script installs and configures:
- **IIS** (ports 80 and 443) with a simple demo landing page.
- **Additional HTTP listeners** on ports 8080, 8443 (via IIS bindings).
- A **"Shadow IT" HTTP server** on port 9090 (used for the block demo).
- Confirms **RDP** is enabled.
- Creates a **SMB share** named `LabShare`.

---

## 5. Verification Checklist

Before running the demo, verify:

- [ ] App Connector shows **Connected** in ZPA Portal.
- [ ] All five Application Segments show the connector in their server group.
- [ ] Windows Server IIS responds at `http://192.168.1.20`.
- [ ] Windows 11 ZPA Client shows **Connected** (green icon in system tray).
- [ ] From Windows 11, browsing to `http://192.168.1.20` works **only when the
      ZPA client is connected** (disconnect the client and try again to confirm
      direct access is blocked by your network posture/firewall).

---

## 6. Troubleshooting

| Symptom | Check |
|---------|-------|
| Connector shows *Disconnected* | Outbound 443 blocked; check firewall/proxy. Tail `/var/log/zpa-connector/connector.log`. |
| App Segment not reachable | Confirm the connector and app server are on the same subnet; check Windows Firewall on the server. |
| ZPA Client not connecting | Verify IdP metadata is correct in ZPA tenant; check machine DNS can reach `*.zscaler.net`. |
| Policy block not firing | Ensure `Lab-Shadow-App` has **no** matching allow rule. Check *Policy Simulation* in the portal. |
