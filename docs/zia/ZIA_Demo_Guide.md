# ZIA Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Internet Access demo
with a customer or prospect. It maps every demo beat to the scripts in this
repository so you never lose your place.

---

## Overview

This demo tells a single story in five acts:

| Act | Story Beat | Key ZIA Capability |
|-----|-----------|-------------------|
| 1 | "All internet traffic is inspected – no blind spots" | SSL Inspection + Visibility |
| 2 | "Block threats before they reach the user" | Advanced Threat Protection |
| 3 | "Control exactly which cloud apps employees can use" | Cloud App Control |
| 4 | "Prevent sensitive data from leaving the company" | Data Loss Prevention (DLP) |
| 5 | "Every user action is logged with full context" | Log Explorer / Analytics |

Total run time: **25–35 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

If you have limited time, run this cut-down version:

| # | What to Show | Time |
|---|-------------|------|
| 1 | `ip.zscaler.com` — show traffic routing through ZIA | 1 min |
| 2 | Block an EICAR test file download (threat protection) | 2 min |
| 3 | Block a personal Dropbox upload (Cloud App Control) | 3 min |
| 4 | Block a credit card number upload (DLP) | 2 min |
| 5 | Log Explorer — show user identity on every event | 2 min |

**Talking track for each transition:**
- *"Every byte of internet traffic from this machine runs through ZIA — even HTTPS."*
- *"If a user clicks a malware link, ZIA kills it before it reaches the browser."*
- *"Carol tried to upload to her personal Dropbox. Allowed on corporate Dropbox — blocked on personal."*
- *"Dave accidentally typed a credit card number in a form. ZIA caught it and blocked the upload."*
- *"And every event — allow, block, warn — is logged with the user's full identity."*

> **Pre-stage tip:** Run `generate_zia_traffic.ps1` and `demo_url_filtering.ps1`
> 10 minutes before the meeting so the Log Explorer is already populated.

---

## Persona Access Matrix (Quick Reference)

| Capability | bob.jones (IT) | alice.smith (Dev) | carol.white (Contractor) | dave.hr (HR) |
|------------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Business cloud apps | ✅ Allow | ✅ Allow | ✅ Allow | ✅ Allow |
| Personal cloud storage | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| Social media (view) | ✅ Allow | ✅ Allow | ⚠️ Warn | ⚠️ Warn |
| P2P / Torrents | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| Malware / Phishing sites | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| Credit card upload (DLP) | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| Streaming video | ⚠️ Throttled | ⚠️ Throttled | ⚠️ Throttled | ⚠️ Throttled |

---

## Pre-Demo Checklist

- [ ] ZIA Admin Portal open in a browser tab.
- [ ] Windows 11 machine with ZIA Client Connector **Connected** (green tray icon).
- [ ] `https://ip.zscaler.com` confirms traffic is through ZIA.
- [ ] SSL inspection active — check padlock certificate on any HTTPS site.
- [ ] Ubuntu terminal open for Linux traffic scripts.
- [ ] Traffic generator ready: `scripts/zia/linux/generate_zia_traffic.sh`

---

## Act 1 – SSL Inspection & Full Visibility (5 min)

### Talking Points

> "Traditional security tools are blind to HTTPS traffic — and today over 90%
> of internet traffic is encrypted. ZIA inspects every byte, including HTTPS,
> giving you complete visibility into what your users are doing online."

### Steps

1. **Show ZIA is in the path**
   - Open a browser and navigate to `https://ip.zscaler.com`.
   - The page confirms the ZIA node handling the connection, the user's identity,
     and the forwarding method.

   > "This page is served by ZIA. Every HTTPS request from this machine is
   > being decrypted, inspected, and re-encrypted — in milliseconds."

2. **Show the SSL Inspection certificate**
   - Navigate to `https://www.google.com`.
   - Click the padlock in the browser address bar → **Certificate**.
   - The issuer is **Zscaler Root CA**, not Google.

   > "ZIA terminates the TLS session, inspects the content, then re-establishes
   > an encrypted session to Google on behalf of the user. The user experience
   > is identical — it's just no longer a blind spot."

3. **Show live traffic in the portal**
   - In the ZIA Admin Portal navigate to **Analytics → Web Insights**.
   - Start the traffic generator script on Ubuntu:
     ```bash
     sudo bash scripts/zia/linux/generate_zia_traffic.sh &
     ```
   - Watch requests appear in real time with user, URL, category, and action.

4. **Show URL Category Lookup**
   - In the ZIA Admin Portal navigate to **Administration → URL Category
     Lookup**.
   - Enter a few URLs (`https://github.com`, `https://bittorrent.com`,
     `https://example-malware.com`) and show their categories instantly.

---

## Act 2 – Advanced Threat Protection (7 min)

### Talking Points

> "ZIA has a real-time threat intelligence feed updated every few seconds.
> When a user clicks a bad link — phishing email, compromised ad — ZIA blocks
> it before the first TCP packet reaches the malicious server."

### Steps

1. **Attempt to download an EICAR test file (malware simulation)**
   - Run the block demo script on Windows 11:
     ```powershell
     .\scripts\zia\windows\demo_threat_protection.ps1
     ```
   - The script attempts to download known EICAR test files and visits
     test phishing pages.
   - ZIA blocks all of them; the script prints **BLOCKED** in green for each.

   > "The EICAR file is the industry-standard test for anti-malware detection.
   > ZIA identified and blocked it in the inspection layer — the file never
   > reached the disk."

2. **Show the block page in the browser**
   - Open a browser and navigate to `https://malware.wicar.org`.
   - ZIA's block page appears with the category, rule name, and an option to
     request access.

3. **Show the threat event in the portal**
   - Navigate to **Analytics → Threat Insights**.
   - The EICAR/malware attempt appears with user identity, URL, threat name,
     and action taken.

   > "Security ops can see in real time: who clicked what, what the threat was,
   > and that it was stopped. No endpoint agent needed — this is cloud-native."

4. **Demonstrate Sandbox (optional)**
   - Attempt to download a benign executable that triggers sandbox analysis.
   - Show the **Sandbox** queue in the portal.

   > "For unknown files, ZIA Cloud Sandbox detonates them in isolation and
   > returns a verdict in seconds. If the file is malicious, it is blocked
   > retroactively across the entire tenant."

---

## Act 3 – Cloud App Control (7 min)

### Talking Points

> "Employees use dozens of cloud apps every day. ZIA can distinguish between
> sanctioned and unsanctioned versions of the same app. Uploading to corporate
> OneDrive is allowed; uploading to a personal Dropbox is blocked."

### Steps

1. **Run the cloud app control demo script**
   ```powershell
   .\scripts\zia\windows\demo_cloud_app_control.ps1
   ```
   The script simulates:
   - Upload to sanctioned Office 365 OneDrive → **Allowed**
   - Upload to personal Dropbox → **Blocked**
   - Upload to WeTransfer → **Blocked**
   - Social media POST request → **Blocked** (view-only policy)
   - Social media GET request → **Allowed** (viewing permitted)

2. **Show the Cloud App Control policy**
   - Navigate to **Policy → URL & Cloud App Control → Cloud Application
     Control**.
   - Walk through the rules: `Allow-O365-Google`, `Block-Unapproved-Storage`,
     `Restrict-Social-Posts`.

   > "We're not blocking Dropbox entirely — we're blocking *personal* Dropbox
   > while allowing the corporate Dropbox tenant. ZIA can differentiate tenants
   > for the major cloud applications."

3. **Show Cloud App Discovery**
   - Navigate to **Analytics → Cloud Application Report**.
   - Show the full inventory of cloud apps discovered — including ones that
     might surprise the IT team.

   > "This is shadow IT visibility. Every cloud app your users are accessing —
   > even from mobile devices forwarding through ZIA — appears here. You can
   > assess each app's risk score and decide whether to allow or block it."

4. **Assign a risk score**
   - Click any discovered application → **Edit App Classification**.
   - Show the risk score and data protection attributes.
   - Add the app to a **Sanctioned** or **Unsanctioned** list.

---

## Act 4 – Data Loss Prevention (8 min)

### Talking Points

> "DLP is usually a painful, complex on-prem deployment. With ZIA, DLP
> inspects every upload in the cloud — no hardware, no agents, and it works
> for all protocols including HTTPS and email."

### Steps

1. **Run the DLP demo script on Windows 11**
   ```powershell
   .\scripts\zia\windows\demo_dlp.ps1
   ```
   The script attempts to:
   - Upload a text file containing fake credit card numbers → **Blocked**
   - POST a form with a test SSN pattern → **Blocked / Logged**
   - Upload a file with a `CONFIDENTIAL` watermark → **Blocked**
   - Upload a benign file → **Allowed**

2. **Show the DLP block page in the browser**
   - Repeat step 1 manually in a browser: create a file with
     `4111-1111-1111-1111` and try uploading it to any file-sharing site.
   - ZIA's block page appears explaining that the upload violated the DLP policy.

   > "The user sees a clear message explaining why their upload was blocked.
   > They can optionally request a business justification override if the
   > admin has configured that option."

3. **Show the DLP incident in the portal**
   - Navigate to **Analytics → DLP Incident Reports**.
   - The blocked event appears with user identity, matched dictionary, URL,
     and a snippet of the matched content.

   > "Security and compliance teams get a full audit trail of every DLP event.
   > No need for a separate DLP console — it's all in ZIA."

4. **Show the DLP dictionaries**
   - Navigate to **Policy → Data Loss Prevention → Dictionaries**.
   - Walk through built-in dictionaries: Credit Cards, Social Security Numbers,
     Health Information, Financial Data.

   > "These dictionaries are maintained by Zscaler and updated continuously.
   > You can also create custom dictionaries for company-specific IP like
   > contract numbers, product codes, or internal document headers."

---

## Act 5 – Visibility & Analytics (5 min)

### Talking Points

> "Security is only as good as the visibility it provides. ZIA gives every
> security and IT team a single pane of glass for all internet traffic —
> without any on-prem log collectors or SIEM integrations required."

### Steps

1. **Web Insights Dashboard**
   - Navigate to **Analytics → Web Insights**.
   - Show the real-time traffic overview: top users, top categories,
     top destinations, blocked vs. allowed ratio.

2. **Log Explorer (Live)**
   - Navigate to **Analytics → Log Explorer**.
   - Filter by user = `carol.white`.
   - Show the mix of ALLOW, BLOCK, and CAUTION events with:
     - Full URL
     - Cloud application name
     - URL category
     - Policy rule that triggered
     - Bytes transferred
     - Threat name (if applicable)

   > "This is the 'single source of truth' for your internet security posture.
   > Every event, every user, complete context."

3. **Executive Dashboard**
   - Navigate to the **Dashboard** home.
   - Show the security summary: threats blocked today, DLP incidents, top
     risky users, bandwidth by category.

4. **SIEM Integration (optional)**
   - Show the **NSS (Nanolog Streaming Service)** or **Cloud NSS** settings.
   - Explain that logs stream to Splunk, Sentinel, QRadar, etc. in real time.

   > "ZIA logs are already in your SIEM. Security analysts don't need to learn
   > a new tool — they get all this context in their existing workflow."

---

## Common Customer Questions & Answers

### "Does ZIA slow down internet access?"

No — ZIA's global cloud network has over 150 PoPs worldwide. Traffic routes to
the nearest PoP, inspects at line rate, and exits to the internet from there.
In many cases ZIA *improves* performance through connection optimisation and
HTTP/2 multiplexing.

### "What happens if the ZIA cloud goes down?"

ZIA has a 99.999% SLA backed by its globally distributed architecture. In the
event of a connectivity issue, the Client Connector can be configured with a
**fail-open** or **fail-closed** policy — your choice.

### "How is this different from a web proxy?"

| Legacy Proxy | ZIA |
|-------------|-----|
| On-prem hardware (single point of failure) | Cloud-native, globally distributed |
| Limited to HTTP/HTTPS | Full SSL inspection + all ports/protocols |
| No user identity context | Full user + device identity per session |
| Static signature updates (hours/days) | Real-time threat intelligence (seconds) |
| No DLP | Built-in DLP with 100+ dictionaries |
| No cloud app visibility | Cloud Application Report + risk scoring |

### "Can ZIA work alongside our existing NGFW?"

Yes. ZIA complements an NGFW by handling internet-bound traffic inspection.
Many customers forward internet traffic from the NGFW to ZIA via GRE or IPSec
tunnel, keeping their existing network topology intact.

---

## Post-Demo Next Steps

1. Share the [ZIA Architecture White Paper](https://www.zscaler.com/resources/white-papers/zscaler-internet-access.pdf).
2. Offer a **Proof of Value (PoV)** with the customer's own internet traffic
   and their real user groups.
3. Discuss the customer's current proxy / NGFW / DLP solution and map ZIA
   capabilities to each gap.
4. Show how ZIA + ZPA together eliminate both the on-prem proxy and the VPN —
   the full Zscaler Zero Trust Exchange.
5. Explore ZIA for Branch Offices via SD-WAN integration.
6. Discuss SIEM integration with the customer's existing Splunk / Sentinel setup.
