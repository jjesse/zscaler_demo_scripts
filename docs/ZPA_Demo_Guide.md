# ZPA Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Private Access demo
with a customer or prospect. It maps every demo beat to the scripts in this
repository so you never lose your place.

---

## Overview

This demo tells a single story in four acts:

| Act | Story Beat | Key ZPA Capability |
|-----|-----------|-------------------|
| 1 | "User connects to private apps – no VPN" | Zero-Trust app access |
| 2 | "IT doesn't know about all its apps" | App Discovery |
| 3 | "Block a user from apps they shouldn't reach" | Granular access policy |
| 4 | "Admin gets full visibility" | Log Explorer / Analytics |

Total run time: **20–30 minutes** (adjustable by skipping acts).

---

## Pre-Demo Checklist

- [ ] ZPA Admin Portal open in a browser tab (split screen or second monitor).
- [ ] Windows 11 machine logged in; ZPA Client **Connected** (green tray icon).
- [ ] Windows Server IIS accessible at `http://192.168.1.20` (confirm before customer joins).
- [ ] Ubuntu Server terminal open (to run traffic scripts).
- [ ] Traffic generator script ready to paste:
      `scripts/linux/generate_zpa_traffic.sh`
- [ ] Have a second Windows/browser session **without** ZPA client to show "what it looks like without ZPA".

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
   - Show `Allow-Lab-Users-WebRDP-SMB` – conditional on IdP attribute.

   > "Access is conditional on identity. The moment I remove a user from the
   > `Lab` group in our IdP, their access disappears in real time."

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

## Act 3 – Policy Blocks (7 min)

### Talking Points

> "ZPA enforces least-privilege. Even if an application is discoverable on the
> network, it's invisible unless there's an explicit policy that grants you
> access. Watch what happens when I try to reach the shadow app."

### Steps

1. **From Windows 11 – try to reach the blocked app**
   ```powershell
   .\scripts\windows\demo_policy_blocks.ps1
   ```
   The script attempts HTTP connections to `http://192.168.1.20:9090` and
   `\\192.168.1.20\HiddenShare` and logs the results. Every attempt will
   show a **timeout / connection refused** response.

2. **Show the ZPA Client – No Session Created**
   - Open **ZPA Client → Sessions**.
   - Confirm there is **no session** for port 9090 – the request never left
     the client.

   > "There is no 'deny' packet even reaching the application server. The
   > traffic simply never leaves the device. The app is invisible to the user
   > and their machine."

3. **Show the Log in the Portal**
   - Navigate to **Log Explorer** (or **Analytics → Private Access Logs**).
   - Filter by the Windows 11 machine's user or IP.
   - Show the `BLOCK` entries for port 9090.

   > "Every attempted access – allowed or blocked – is logged with full
   > user-identity context. You get who, what, when, from where, and with
   > what device posture."

4. **Grant Access in Real Time (optional power move)**
   - In **Policy → Access Policy**, add `Lab-Shadow-App` to the allow rule.
   - Back on Windows 11, re-run the script – the connection succeeds in
     seconds.
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
2. Offer a **Proof of Value (PoV)** with customer's own apps.
3. Discuss integration with customer's IdP (Azure AD, Okta, Ping, etc.).
4. Explore ZPA for Workloads (cloud-to-cloud segmentation).
