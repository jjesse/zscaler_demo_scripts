# ZPA Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Private Access demo
with a customer or prospect. It maps every demo beat to the scripts in this
repository so you never lose your place.

---

## Overview

This demo tells a single story in five acts:

| Act | Story Beat | Key ZPA Capability |
|-----|-----------|-------------------|
| 1 | "User connects to private apps – no VPN" | Zero-Trust app access |
| 1.5 | "Different users see different apps" | Granular per-user policy |
| 2 | "IT doesn't know about all its apps" | App Discovery |
| 3 | "Block a user from apps they shouldn't reach" | Policy enforcement + access denied |
| 4 | "Admin gets full visibility" | Log Explorer / Analytics |

Total run time: **25–35 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

If you have limited time, run this cut-down version. It covers the three
moments that land hardest with executives:

| # | What to Show | Time |
|---|-------------|------|
| 1 | IT Admin (`bob.jones`) browses web app + opens RDP in browser | 2 min |
| 2 | Contractor (`carol.white`) — same machine, web works, RDP is silently blocked | 3 min |
| 3 | HR Analyst (`dave.hr`) — everything blocked, ZPA Client shows zero sessions | 2 min |
| 4 | In ZPA portal: show Log Explorer — ALLOW + BLOCK entries, all with user identity | 3 min |

**Talking track for each transition:**
- *"Bob is IT — he gets everything."*
- *"Carol is a contractor — she only gets what she needs to do her job."*
- *"Dave is HR — he has no business touching these servers. ZPA makes them invisible to him."*
- *"And every attempt, whether allowed or denied, is logged with the user's full identity."*

> **Pre-stage tip:** Run `generate_zpa_traffic.ps1` and `demo_user_access.ps1`
> for all three personas 10 minutes before the meeting so the Log Explorer
> is already populated when you switch to Act 4.

---

## Persona Access Matrix (Quick Reference)

| Resource | bob.jones (IT) | alice.smith (Eng) | carol.white (Contractor) | dave.hr (HR) |
|----------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Web Portal (80/443/8080) | ✅ Allow | ✅ Allow | ✅ Allow | ❌ Deny |
| SSH (22) | ✅ Allow | ✅ Allow | ❌ Deny | ❌ Deny |
| RDP (3389) | ✅ Allow | ❌ Deny | ❌ Deny | ❌ Deny |
| File Share (445) | ✅ Allow | ❌ Deny | ❌ Deny | ❌ Deny |
| Shadow IT App (9090) | ❌ Deny | ❌ Deny | ❌ Deny | ❌ Deny |
| DB ports (1433/5432/6379) | ❌ Deny | ❌ Deny | ❌ Deny | ❌ Deny |

> ❌ Deny = silent timeout. The app is **invisible** — no error, no response,
> no indication the service even exists.

---

## Pre-Demo Checklist

- [ ] ZPA Admin Portal open in a browser tab (split screen or second monitor).
- [ ] Windows 11 machine logged in as **bob.jones** (IT Admin); ZPA Client **Connected** (green tray icon).
- [ ] A second Windows session (or browser profile) ready for **carol.white** (Contractor) persona.
- [ ] Windows Server IIS accessible at `http://192.168.1.20` (confirm before customer joins).
- [ ] Ubuntu Server terminal open (to run traffic scripts).
- [ ] Traffic generator script ready to paste:
      `scripts/linux/generate_zpa_traffic.sh`
- [ ] Have a session **without** ZPA client to show "what it looks like without ZPA".
- [ ] Four access policy rules configured (see Lab_Setup.md §2.4).

---

## Act 1 – Zero-Trust Private App Access (8 min)

### Talking Points

> "Traditional VPN gives users access to the entire network. ZPA is different –
> we connect **users to applications**, never to the network. The app is
> effectively invisible to the internet."

### Steps

1. **Show the Admin Portal – Application Segments**
   - Navigate to **Applications → Application Segments**.
   - Highlight the four authorised segments (`Lab-WebApps`, `Lab-RDP`,
     `Lab-FileShare`, `Lab-SSH`).
   - Point out that each segment is tied to a **Connector Group**, not a
     firewall rule.

   > "Each one of these replaces a firewall hole and a VPN split-tunnel entry."

2. **Show the Policy**
   - Navigate to **Policy → Access Policy**.
   - Show the four rules at a glance — point to `Allow-IT-Admins-Full` as the
     first rule.

   > "Access is conditional on identity. The moment I remove a user from the
   > `IT` group in our IdP, their access disappears in real time — no firewall
   > ticket, no maintenance window."

3. **Live Access Demo – HTTP**
   - On the **Windows 11 client**, open a browser and navigate to
     `http://192.168.1.20`.
   - The IIS demo page loads.
   - Open **ZPA Client → Sessions** to show the active session to `Lab-WebApps`.

4. **Start the traffic generator** (background, keeps dashboards live)
   - On the Ubuntu Server run:
     ```bash
     sudo bash scripts/linux/generate_zpa_traffic.sh &
     ```
   - On the Windows 11 client run (PowerShell, Administrator):
     ```powershell
     .\scripts\windows\generate_zpa_traffic.ps1
     ```

5. **Live Access Demo – RDP in Browser (Privileged Remote Access)**
   - In the ZPA Admin Portal navigate to **Privileged Remote Access**.
   - Open a browser-based RDP session to `192.168.1.20:3389`.
   - Show the desktop loading inside the browser with **no RDP client required**.

   > "This is ZPA Privileged Remote Access – full RDP inside a browser, with
   > session recording, clipboard policies, and watermarking."

6. **Disconnect ZPA Client – show access disappears**
   - Right-click the ZPA tray icon → **Disconnect**.
   - Try `http://192.168.1.20` again – it times out.
   - Reconnect ZPA client – access returns in seconds.

---

## Act 1.5 – Granular Per-User Access Control (8 min)

### Talking Points

> "ZPA doesn't just control whether you can access the network — it controls
> which specific applications each individual user can reach, based on their
> identity. Let me show you what that looks like with three real personas."

### Setup

You need two active ZPA Client sessions: one as **bob.jones** (IT Admin) and
one as **carol.white** (Contractor). Use:
- A second Windows 11 user account on the same machine (`Win + L`, switch user),
- A second physical machine, or
- A Windows sandbox / VM signed in as the contractor.

### Steps

1. **Show the Policy Rules in the Admin Portal**
   - Navigate to **Policy → Access Policy**.
   - Walk through the four rules in order:

   | # | Rule | Who | Gets |
   |---|------|-----|------|
   | 1 | `Allow-IT-Admins-Full` | dept=IT | Everything |
   | 2 | `Allow-Engineers-WebSSH` | dept=Engineering | Web + SSH |
   | 3 | `Allow-Contractors-WebOnly` | dept=Contractor | Web only |
   | 4 | `Block-Shadow-App` | Everyone | Port 9090 blocked |

   > "These rules are evaluated in order. The moment a rule matches, evaluation
   > stops. No user ever gets access to something unless there's an explicit
   > allow rule — that's zero-trust in action."

2. **IT Admin persona (bob.jones) – Full Access**
   - Switch to the session logged in as `bob.jones`.
   - Run the user-access demo script:
     ```powershell
     .\scripts\windows\demo_user_access.ps1 -Persona ITAdmin
     ```
   - The script confirms `bob.jones` can reach **WebApps, RDP, FileShare, SSH**.
   - Open **ZPA Client → Sessions** — show four active app sessions.

   > "Bob is in the IT department, so he gets the full access rule. He can
   > browse the web app, remote-desktop in, mount the file share, and SSH
   > to the Linux server — all through ZPA, with zero VPN."

3. **Contractor persona (carol.white) – Web Only**
   - Switch to the session logged in as `carol.white`.
   - Run the same script with a different persona:
     ```powershell
     .\scripts\windows\demo_user_access.ps1 -Persona Contractor
     ```
   - Web access **succeeds**; RDP, SSH, and SMB are **blocked**.
   - Open **ZPA Client → Sessions** — only the WebApps session appears.

   > "Carol is a contractor. She can use the web portal — that's all her job
   > requires. If she tries to RDP into the server or mount a file share, the
   > connection never even leaves her laptop. The app is invisible to her."

4. **HR persona (dave.hr) – Complete Access Denied**
   - If you have a third session, switch to `dave.hr` and run:
     ```powershell
     .\scripts\windows\demo_user_access.ps1 -Persona HR
     ```
   - **All** connections are blocked.
   - Open **ZPA Client → Sessions** — no sessions whatsoever.

   > "Dave is in HR. There are no allow rules for the HR department in our ZPA
   > policy. Every private-app connection attempt is silently dropped. Dave
   > doesn't get an error message — the apps are simply invisible to him."

5. **Highlight the Log Explorer difference**
   - Navigate to **Analytics → Log Explorer**.
   - Filter by user = `bob.jones` — shows ALLOW entries for all four apps.
   - Filter by user = `carol.white` — shows ALLOW for WebApps; BLOCK for RDP,
     SSH, SMB.
   - Filter by user = `dave.hr` — shows BLOCK entries for every attempt.

   > "Every access attempt — allowed or denied — is logged with the user's
   > full identity context. This is the audit trail compliance teams dream of."

---

## Act 2 – App Discovery (7 min)

### Talking Points

> "The connector scans the segment it can reach. Any service it sees that isn't
> in an Application Segment automatically shows up here. This gives IT a live
> inventory of shadow-IT and undocumented services."

### Steps

1. **Start the discovery demo script on Ubuntu Server**
   ```bash
   sudo bash scripts/linux/demo_discovered_apps.sh
   ```
   This starts several lightweight services on non-standard ports on the Ubuntu
   server that ZPA hasn't seen before.

2. **Show App Discovery in the portal**
   - Navigate to **Applications → App Discovery**.
   - Wait 2–3 minutes (or pre-stage by running the script 5 minutes before
     the call).
   - New entries appear: ports 5000, 6379, 8888, etc.

3. **Explain the workflow**
   - Click one discovered app → **Add to Application Segment**.
   - Show how quickly IT can formalise and apply a policy to a newly
     discovered service.

   > "Before ZPA App Discovery, IT would have no idea this service was running.
   > Now they can immediately decide: 'Do we want to allow this? To whom?
   > With what conditions?' That's IT reclaiming control without slowing the
   > business down."

4. **Stop the discovery services** (after the demo beat)
   ```bash
   sudo bash scripts/linux/demo_discovered_apps.sh --stop
   ```

---

## Act 3 – Policy Blocks & Access Denied (7 min)

### Talking Points

> "ZPA enforces least-privilege at the packet level. Even if an application is
> discoverable on the network, it is **invisible** unless there's an explicit
> policy that grants you access. And the block is silent — the user gets a
> timeout, not a 'permission denied' that could reveal the app exists."

### Steps

1. **From Windows 11 – run the full block demo**
   ```powershell
   .\scripts\windows\demo_policy_blocks.ps1
   ```
   The script attempts connections to:
   - `http://192.168.1.20:9090` — Shadow IT app (no policy for any user)
   - TCP 1433 — SQL Server (not in any segment)
   - TCP 5432 — PostgreSQL (not in any segment)
   - TCP 6379 — Redis (not in any segment)
   - TCP 27017 — MongoDB (not in any segment)
   - `\\192.168.1.20\HiddenShare` — unauthorised SMB share

   All attempts show **green BLOCKED** output.

2. **Show the ZPA Client – No Session Created**
   - Open **ZPA Client → Sessions**.
   - Confirm there is **no session** for port 9090 — the request never left
     the client.

   > "There is no 'deny' packet even reaching the application server. The
   > traffic simply never leaves the device. The app is invisible to the user
   > and their machine."

3. **Contractor trying admin resources**
   - Switch to `carol.white` (Contractor) session.
   - Run:
     ```powershell
     .\scripts\windows\demo_user_access.ps1 -Persona Contractor -ShowDenied
     ```
   - The script tries RDP, SSH, and SMB — all blocked.
   - Show **ZPA Client → Sessions** — only the WebApps session appears.

   > "Carol got exactly what the policy says: web access only. She can't
   > lateral-move to the server even if her machine is compromised, because
   > the policy doesn't allow it."

4. **Show the Log in the Portal**
   - Navigate to **Log Explorer** (or **Analytics → Private Access Logs**).
   - Filter by the Windows 11 machine's user or IP.
   - Show the `BLOCK` entries for port 9090 and for Carol's RDP attempts.

   > "Every attempted access — allowed or blocked — is logged with full
   > user-identity context. You get who, what, when, from where, and with
   > what device posture."

5. **Grant Access in Real Time (optional power move)**
   - In **Policy → Access Policy**, add `Lab-Shadow-App` to the IT Admin rule.
   - Back on Windows 11 (as `bob.jones`), re-run the script — the connection
     succeeds in seconds.
   - Remove the rule again to restore the block.

   > "Policy changes are pushed globally in under 60 seconds. No firewall
   > change tickets, no maintenance windows."

---

## Act 4 – Visibility & Analytics (5 min)

### Talking Points

> "Zero-trust is only as good as the visibility it provides. ZPA gives you a
> complete picture of every private-app session."

### Steps

1. **Log Explorer**
   - Navigate to **Analytics → Log Explorer**.
   - Show logs flowing in real time from the traffic generator scripts.
   - Filter by **Application Segment** = `Lab-WebApps` to see session count,
     bytes transferred, user, device.

2. **App Usage Dashboard**
   - Navigate to **Analytics → App Usage**.
   - Show the heat map / top apps by users and sessions.

3. **Connector Health**
   - Navigate to **Administration → App Connectors**.
   - Show CPU, throughput, session count per connector.

   > "You get full observability on every connector. If one is overloaded or
   > goes offline, ZPA automatically shifts sessions to the next healthy
   > connector in the group."

4. **ZPA Posture (Device Trust – optional)**
   - Show the **Device Posture** profile tied to the access policy.
   - Explain how ZPA can enforce that the device must be domain-joined, have
     AV running, or be compliant in Intune/Jamf before access is granted.

---

## Common Customer Questions & Answers

### "Does this work for legacy apps that can't be modified?"

Yes. ZPA is transparent to the application. Any TCP/UDP application that works
over a LAN will work through ZPA – web apps, thick clients, RDP, SSH, databases,
printing, custom ERP, etc. No code changes are needed.

### "What happens if the ZPA connector goes down?"

ZPA supports multiple connectors in a group for high availability. Sessions
automatically fail over. For this lab there's a single connector, but in
production you deploy at least two per group.

### "How is this different from a VPN?"

| VPN | ZPA |
|-----|-----|
| Network access (broad) | Application access (granular) |
| "Implicit allow" for everything on subnet | Explicit allow per app / per user |
| Client establishes inbound connection | Connector makes outbound-only connection |
| No native app discovery | Built-in app discovery |
| Firewall rules required | No inbound firewall rules |
| Session logs limited | Full identity-aware session logs |

### "Can ZPA replace our bastion host for admin access?"

Yes – ZPA **Privileged Remote Access (PRA)** is a direct replacement for jump
servers and bastion hosts, adding session recording, credential vaulting, and
just-in-time provisioning.

---

## Post-Demo Next Steps

1. Share the [ZPA Architecture White Paper](https://www.zscaler.com/resources/white-papers/zscaler-private-access.pdf).
2. Offer a **Proof of Value (PoV)** with customer's own apps and their real user groups.
3. Discuss integration with customer's IdP (Azure AD, Okta, Ping, etc.) to map their existing groups to ZPA policies.
4. Show how the four-persona policy model maps directly to their org chart.
5. Explore ZPA for Workloads (cloud-to-cloud segmentation).
6. Discuss replacing the customer's VPN concentrator and jump/bastion servers with ZPA + PRA.
