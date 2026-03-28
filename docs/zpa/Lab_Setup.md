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

### 2.4 Create Access Policies

Navigate to **Policy → Access Policy** → **Add Rule**.

Create the rules below **in order** (lower priority number = higher precedence).
ZPA evaluates rules top-to-bottom and stops at the first match.

#### Rule 1 – IT Admin Full Access

| Field | Value |
|-------|-------|
| Rule Name | `Allow-IT-Admins-Full` |
| Priority | 1 |
| Action | Allow |
| Conditions | SAML Attribute **department** = `IT` |
| Application | `Lab-WebApps`, `Lab-RDP`, `Lab-FileShare`, `Lab-SSH` |

#### Rule 2 – Engineers (Web + SSH only)

| Field | Value |
|-------|-------|
| Rule Name | `Allow-Engineers-WebSSH` |
| Priority | 2 |
| Action | Allow |
| Conditions | SAML Attribute **department** = `Engineering` |
| Application | `Lab-WebApps`, `Lab-SSH` |

> Engineers get web and SSH access but **not** RDP or SMB file shares.
> This difference is key to the per-user demo in Act 1.5.

#### Rule 3 – Contractors (Web Only)

| Field | Value |
|-------|-------|
| Rule Name | `Allow-Contractors-WebOnly` |
| Priority | 3 |
| Action | Allow |
| Conditions | SAML Attribute **department** = `Contractor` |
| Application | `Lab-WebApps` |

> Contractors are limited to the web portal only — no RDP, SSH, or file shares.

#### Rule 4 – Block Shadow App (explicit block for all users)

| Field | Value |
|-------|-------|
| Rule Name | `Block-Shadow-App` |
| Priority | 4 |
| Action | Block |
| Conditions | Any user |
| Application | `Lab-Shadow-App` |

> No user — regardless of department — may reach port 9090. This explicit
> block rule fires even if a user somehow matches a broader future allow rule.

> **Tip:** HR users (department = `HR`) match **none** of the allow rules
> above, so they are implicitly denied all private-app access. This "implicit
> deny" is as important to show as the explicit block.

---

### 2.5 Demo User Personas

Create the following user accounts in your IdP (Azure AD, Okta, Ping, etc.)
and assign the SAML **department** attribute accordingly. These four personas
power the full multi-user demo in Act 1.5 of the ZPA Demo Guide.

| Persona | Suggested Username | IdP Department | Access |
|---------|--------------------|----------------|--------|
| IT Admin | `bob.jones` | `IT` | WebApps + RDP + FileShare + SSH (full) |
| Engineer | `alice.smith` | `Engineering` | WebApps + SSH only |
| Contractor | `carol.white` | `Contractor` | WebApps only |
| HR Analyst | `dave.hr` | `HR` | **No access** (implicit deny) |

> You only need **two** of these accounts to tell a compelling story.
> The IT Admin + Contractor pair shows the biggest contrast and is the
> easiest to set up.

#### Quick IdP Setup (Azure AD example)

1. Create users `alice.smith`, `bob.jones`, `carol.white`, and `dave.hr` in
   Azure AD.
2. In the ZPA SAML IdP configuration, map the Azure AD **Department** field to
   a SAML attribute named `department`.
3. Set each user's **Department** field in their Azure AD profile to match the
   table above.
4. Log each user into a separate Windows session (or use a single machine with
   `Run as different user`) to demonstrate the access differences.

---

### 2.6 Enrol the ZPA Client on Windows 11

1. Download **ZPA Client Connector** from the ZPA Portal →
   **Administration → Client Connector**.
2. Install on the Windows 11 machine.
3. Sign in with an account that matches the SAML attribute set in the policy.

---

## 3. App Connector Installation (Ubuntu)

Run the install script as root on the Ubuntu Server:

```bash
sudo bash scripts/zpa/linux/setup_app_connector.sh
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
.\scripts\zpa\windows\setup_internal_apps.ps1
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
- [ ] All four access policy rules are created and in the correct priority order.
- [ ] Logged in as `bob.jones` (IT): RDP to `192.168.1.20:3389` **succeeds**.
- [ ] Logged in as `carol.white` (Contractor): RDP to `192.168.1.20:3389` is **blocked**.
- [ ] Logged in as `dave.hr` (HR): HTTP to `http://192.168.1.20` is **blocked**.
- [ ] Shadow app on port 9090 is **blocked** for all users.

---

## 6. Troubleshooting

| Symptom | Check |
|---------|-------|
| Connector shows *Disconnected* | Outbound 443 blocked; check firewall/proxy. Tail `/var/log/zpa-connector/connector.log`. |
| App Segment not reachable | Confirm the connector and app server are on the same subnet; check Windows Firewall on the server. |
| ZPA Client not connecting | Verify IdP metadata is correct in ZPA tenant; check machine DNS can reach `*.zscaler.net`. |
| Policy block not firing | Ensure `Lab-Shadow-App` has **no** matching allow rule. Check *Policy Simulation* in the portal. |
| Contractor can reach RDP | Verify `Allow-Contractors-WebOnly` rule does NOT include `Lab-RDP`. Check rule priority order. |
| HR user can reach any app | Verify there is **no** allow rule with department = `HR`. The implicit-deny should block all access. |
| Wrong user persona sees wrong access | Use *Policy Simulation* (Portal → Policy → Simulate) to test each persona against each app segment. |
