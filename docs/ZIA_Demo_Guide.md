# ZIA Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Internet Access (ZIA)
demo with a customer or prospect. It maps every demo beat to the scripts in
this repository so you never lose your place.

---

## Overview

This demo tells a single story in four acts:

| Act | Story Beat | Key ZIA Capability |
|-----|-----------|-------------------|
| 1 | "All internet traffic is inspected — with full SSL visibility" | Inline proxy, SSL inspection |
| 2 | "Traffic is categorised and policies enforced in real time" | URL Filtering + Cloud Firewall |
| 3 | "Threats are blocked before they reach the user" | Advanced Threat Protection, Sandboxing |
| 4 | "Admins get complete visibility into what users are doing" | Analytics, Web Insights, Shadow IT |

Total run time: **25–35 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

| # | What to Show | Time |
|---|-------------|------|
| 1 | Traffic generator running — show ZIA Web Insights logging every site visited | 2 min |
| 2 | Attempt a blocked category (gambling) — show block page in browser | 2 min |
| 3 | Attempt EICAR malware test — show ZIA threat block and sandbox submission | 3 min |
| 4 | Show shadow-IT discovery (unsanctioned app usage) in ZIA Cloud App Control | 3 min |

**Talking track:**
- *"Every request — HTTP and HTTPS — is inspected inline. There's no traffic that doesn't go through us."*
- *"We enforce your acceptable-use policy in real time, with categories you control."*
- *"When we see malware, we block it before it reaches the user's machine."*
- *"And you get full visibility into every app your users are accessing — including the ones you didn't sanction."*

> **Pre-stage tip:** Run `generate_zia_traffic.ps1` for 5–10 minutes before the meeting
> so the Analytics dashboards are already populated when you switch to Act 4.

---

## Lab Topology

The same three-machine lab used for ZPA demos handles ZIA:

```
Internet / Zscaler Cloud (ZIA)
        │
    ┌───┴──────────────────────────────────────────────┐
    │   ZIA Tenant (cloud) – SSL Inspection, URL       │
    │   Filtering, Threat Protection, DLP, CASB        │
    └───┬──────────────────────────────────────────────┘
        │  All internet-bound traffic proxied to ZIA
┌───────┴──────────────────────────────────────────────────┐
│                 Lab Network (192.168.1.0/24)              │
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐              │
│  │  Windows 11      │  │  Ubuntu 22.04    │              │
│  │  ZIA Client      │  │  ZIA Client or   │              │
│  │  Connector       │  │  PAC/Proxy cfg   │              │
│  │  192.168.1.30    │  │  192.168.1.10    │              │
│  └──────────────────┘  └──────────────────┘              │
└───────────────────────────────────────────────────────────┘
```

**Traffic flow:** Client → ZIA Cloud (SSL inspection + policy enforcement) → Internet

---

## Pre-Demo Checklist

- [ ] ZIA Admin Portal open in a browser tab (second monitor or split screen).
- [ ] Windows 11 machine: Zscaler Client Connector installed and **Connected** (green tray icon).
- [ ] Ubuntu client: Client Connector installed, OR ZIA PAC/proxy configured system-wide.
- [ ] Verify SSL inspection is enabled: browse to `https://www.google.com`, click the lock
      icon, confirm the certificate issuer is `Zscaler` (not Google).
- [ ] ZIA URL-Filtering policy configured: gambling, anonymizers, and P2P in a **Block** rule.
- [ ] ZIA Advanced Threat Protection enabled for malware, phishing, and botnets.
- [ ] Traffic generator ready to paste (run in background during opening):
      `scripts/windows/generate_zia_traffic.ps1`
- [ ] ZIA Analytics → Web Insights: confirm logs are flowing (baseline traffic visible).

---

## Act 1 – Inline Inspection & SSL Visibility (7 min)

### Talking Points

> "Traditional firewalls can't inspect encrypted traffic without significant
> performance impact. ZIA inspects 100% of SSL traffic — including traffic to
> cloud apps like Microsoft 365, Salesforce, and Google Workspace — with no
> performance penalty to your users."

### Steps

1. **Verify ZIA is inspecting SSL**
   - On the Windows 11 client, open a browser and go to `https://www.google.com`.
   - Click the padlock → **Certificate**.
   - Show that the certificate is issued by **Zscaler** — not Google.

   > "ZIA is performing SSL inspection inline. The user sees Google, but
   > every byte of that HTTPS session has been decrypted, inspected, and
   > re-encrypted by Zscaler — in milliseconds."

2. **Start the traffic generator in the background**

   On Windows 11 (PowerShell, no admin required):
   ```powershell
   .\scripts\windows\generate_zia_traffic.ps1
   ```

   On Ubuntu:
   ```bash
   bash scripts/linux/generate_zia_traffic.sh &
   ```

3. **Show ZIA Web Insights flowing**
   - Navigate to **Analytics → Web Insights** in the ZIA Admin Portal.
   - Filter by **User** = the Windows 11 client's logged-in user.
   - Show requests to CNN, LinkedIn, ESPN, YouTube being logged in real time
     with **Category**, **Action** (Allow), **Bytes**, and **Risk Score**.

   > "Every site visit — even HTTPS — is logged with the full URL, the
   > user's identity, the device, and the risk score. Your SOC team gets
   > complete context for every internet transaction."

4. **Show the ZIA Client Connector status**
   - Open the Zscaler Client Connector tray application.
   - Show **Connected** status and the tunnel statistics.
   - Click **Traffic Forwarding** to show that all internet traffic is routed
     through ZIA.

---

## Act 2 – URL Filtering & Category-Based Policy (8 min)

### Talking Points

> "ZIA categorises every URL into one of 200+ categories and enforces your
> policy in real time. You define what's allowed, what's blocked, and what
> gets a warning — for each department or user group."

### Steps

1. **Show the URL-Filtering policy in the Admin Portal**
   - Navigate to **Policy → URL & Cloud App Control → URL Filtering**.
   - Point out rules for:
     - **Streaming** (YouTube, Twitch) — may be allowed or bandwidth-limited.
     - **Social Media** (LinkedIn allowed; Facebook/Instagram restricted by time-of-day or department).
     - **Gambling** — Blocked.
     - **News** — Allowed.
     - **Anonymizers & Proxies** — Blocked.

   > "Each of these rules maps to a category that ZIA maintains and updates
   > continuously. You don't need to manage a blocklist — Zscaler does."

2. **Show allowed categories working** (from traffic generator)
   - Browse `https://www.cnn.com` — loads (News category, Allowed).
   - Browse `https://www.espn.com` — loads (Sports category, Allowed).
   - Browse `https://www.linkedin.com` — loads (Social Media, Allowed per policy).
   - Switch to **ZIA → Web Insights** and show these logged as `ALLOW`.

3. **Demonstrate a URL-filter block**

   On Windows 11:
   ```powershell
   .\scripts\windows\demo_zia_blocks.ps1
   ```

   Or manually in a browser:
   - Navigate to a gambling site (e.g., `https://www.bet365.com`).
   - Show **ZIA block page** appearing in the browser.
   - Point out: block-page message, the blocked URL, the category, and the
     company name/logo if your block page is customised.

   > "The user gets a clear, branded message explaining why the site is blocked.
   > IT can customise this page to include a helpdesk link or override mechanism
   > for business justification."

4. **Time-of-Day / Group-based override (optional power move)**
   - In **URL Filtering**, show a rule that allows Social Media for Engineering
     during lunch hours (12:00–13:00) but blocks it otherwise.

   > "ZIA policies are this granular. You can say: 'Engineering can use Twitter
   > during lunch. Everyone else can't. And it changes automatically by the clock.'"

---

## Act 3 – Threat Protection & Malware Blocking (8 min)

### Talking Points

> "ZIA's threat protection isn't a signature database on a device — it's
> backed by the Zscaler ThreatLabZ team and updated in real time, globally.
> Every new threat discovered by any Zscaler customer is immediately protected
> against for all customers."

### Steps

1. **Run the full block demo script**

   On Windows 11:
   ```powershell
   .\scripts\windows\demo_zia_blocks.ps1
   ```

   On Ubuntu:
   ```bash
   bash scripts/linux/demo_zia_blocks.sh
   ```

   The script attempts connections to:
   - `http://www.eicar.org/download/eicar.com.txt` — EICAR malware test (safe)
   - `https://security.zscaler.com/` — Zscaler security test page
   - `https://testsafebrowsing.appspot.com/s/phishing.html` — phishing test
   - `https://testsafebrowsing.appspot.com/s/malware.html` — malware test
   - Gambling, anonymizer, and P2P sites

   All should show **green BLOCKED** output.

2. **Show the EICAR block page in a browser**
   - On the Windows 11 client, open a browser and attempt to navigate to:
     `http://www.eicar.org/download/eicar.com.txt`
   - ZIA shows a **threat block page** with the threat name and category.

   > "ZIA intercepted that download before a single byte of the file reached
   > this machine. The EICAR test is universally recognised as harmless, but
   > it proves ZIA's threat detection is active. In a real scenario, this would
   > be real malware that never reaches your endpoint."

3. **Show the block in ZIA Web Insights**
   - Navigate to **Analytics → Web Insights**.
   - Filter by **Action = Block** and **Threat Type = Malware**.
   - Show the EICAR attempt: URL, user, timestamp, threat name, action.

   > "Every blocked threat is logged with full context: what was attempted,
   > by whom, from which device, and with what threat classification."

4. **Sandbox (optional — requires ZIA Advanced Threat license)**
   - Navigate to **Analytics → Sandbox Report**.
   - Show recent sandbox submissions and verdicts.
   - Click a submission to show the full sandbox analysis: behaviours,
     network calls, dropped files, verdict.

   > "For unknown files, ZIA sends them to our cloud sandbox for dynamic analysis.
   > The verdict comes back in seconds. If it's malicious, ZIA blocks the download
   > and updates threat intelligence globally for all customers."

---

## Act 4 – Visibility, Analytics & Shadow-IT Discovery (7 min)

### Talking Points

> "Zero-trust only works if you have complete visibility. ZIA gives you a
> real-time dashboard of everything your users are doing on the internet —
> including the apps IT never approved."

### Steps

1. **Web Insights Dashboard**
   - Navigate to **Analytics → Web Insights**.
   - Show the **Top Categories** view — point out Traffic Distribution across
     News, Streaming, Social, Business.
   - Show **Top Users** — who is generating the most traffic.
   - Show **Bandwidth by Category** — highlight Streaming as highest volume.

   > "Streaming media alone can consume 30–50% of internet bandwidth in some
   > organisations. ZIA lets you see it, manage it, or limit it by user group
   > — without blocking it entirely for users who have a business need."

2. **Cloud App Control / Shadow IT**
   - Navigate to **Policy → URL & Cloud App Control → Cloud App Control**.
   - Show the **Cloud App Discovery** report (or **Shadow IT** report).
   - Point out unsanctioned SaaS apps — personal Dropbox, personal Google
     Drive, Pastebin, etc.

   > "These apps are categorised by their risk score: data residency, encryption
   > strength, terms of service, breach history. IT can see exactly which shadow
   > apps are in use and with how much data — without having to inspect packets."

3. **Block Unsanctioned App in Real Time**
   - In **Cloud App Control**, find a high-risk unsanctioned app.
   - Add a rule to **Block** the app.
   - Attempt to access the app from the Windows 11 client — show the ZIA
     block page.
   - Remove the rule to restore access.

   > "Policy changes are applied globally in seconds — no firewall tickets,
   > no maintenance windows."

4. **DLP (Data Loss Prevention — optional)**
   - Navigate to **Policy → DLP**.
   - Show a DLP rule that blocks uploads of credit-card numbers or SSNs to
     non-corporate cloud storage.
   - Demonstrate by attempting to upload a test file with dummy PII to a
     personal Google Drive.

   > "ZIA's DLP inspects SSL traffic inline — it can catch a file with 16-digit
   > patterns (credit-card numbers) before it leaves the corporate perimeter,
   > even if the user is uploading to a legitimate cloud app."

---

## URL Category Reference

Categories exercised by the demo scripts:

| Category | Example Sites | Typical Policy |
|----------|---------------|----------------|
| News | cnn.com, bbc.co.uk, reuters.com, apnews.com | Allow |
| Social Media | linkedin.com, twitter.com, reddit.com | Allow (or time-of-day restricted) |
| Sports | espn.com, nfl.com, nba.com | Allow |
| Streaming / Entertainment | youtube.com, twitch.tv, spotify.com | Allow or Bandwidth-limited |
| Business & Cloud | microsoft.com, salesforce.com, zoom.us, github.com | Allow |
| Search Engines | google.com, bing.com, duckduckgo.com | Allow |
| Gambling | bet365.com, draftkings.com | Block |
| Anonymizers & Proxies | hidemyass.com, anonymouse.org | Block |
| Peer-to-Peer / Torrents | thepiratebay.org | Block |
| Malware (test) | eicar.org test URL | Block (Threat Protection) |
| Phishing (test) | testsafebrowsing.appspot.com | Block (Threat Protection) |

---

## Common Customer Questions & Answers

### "How does ZIA handle SSL inspection without breaking apps?"

ZIA maintains a bypass list for apps that pin certificates (banking apps, some
security tools) and applies SSL inspection selectively. You control which
categories and domains are inspected vs bypassed. Mobile apps and thick clients
that don't respect proxy settings can be covered by GRE/IPsec tunnel from the
office.

### "What's the performance impact of inspecting all traffic?"

Zscaler's cloud is purpose-built for inline inspection at scale. Because traffic
goes to the nearest Zscaler PoP (there are 150+ globally), latency is typically
lower than backhauling to a corporate proxy. Benchmarks show sub-5ms added
latency in most regions.

### "Can ZIA handle remote and branch users the same way?"

Yes. Remote users use the Client Connector (on laptops, phones, tablets). Branch
offices use GRE or IPsec tunnels to the nearest ZIA PoP. Both paths enforce the
same policy — there's no "inside the perimeter" exemption.

### "How is this different from our current web proxy / NGFW?"

| Traditional Proxy / NGFW | ZIA |
|--------------------------|-----|
| On-premises, single point of failure | Cloud-native, 99.999% SLA |
| Can't inspect all SSL (performance) | Inspects 100% of SSL at line rate |
| Manual signature updates | Real-time threat intel from 300B+ daily transactions |
| Limited cloud-app visibility | Built-in CASB for 50,000+ cloud apps |
| No shadow-IT discovery | Automatic cloud-app risk scoring |
| Complex ruleset management | Category-based, intent-driven policy |

### "Does ZIA work for SaaS apps like Microsoft 365?"

Yes. ZIA has purpose-built connectors for Microsoft 365, Google Workspace,
Salesforce, and others. It can tenant-restrict (block personal accounts on
corporate devices), apply DLP to SharePoint/OneDrive uploads, and enforce MFA
prompts inline.

---

## Post-Demo Next Steps

1. Share the [ZIA Architecture White Paper](https://www.zscaler.com/resources/white-papers/zscaler-internet-access.pdf).
2. Offer a **Proof of Value (PoV)** — route 10% of internet traffic through ZIA
   and let the customer see their own shadow IT and threat landscape.
3. Discuss SSL inspection scope: which categories to inspect, which to bypass.
4. Explore DLP use cases — what data classifications matter most to the customer.
5. Show ZIA + ZPA together as the **Zscaler Zero Trust Exchange** — private apps
   AND internet access under one policy framework with one identity store.
6. Discuss the customer's current proxy/NGFW refresh cycle as a migration hook.
