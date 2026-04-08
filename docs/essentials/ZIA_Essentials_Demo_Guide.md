# ZIA Essentials Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Internet Access
**Essentials** demo with a customer or prospect. It focuses on the core
capabilities included in the Essentials bundle and concludes with a clear
upsell path to Zscaler Platform.

---

## Overview

This demo tells a single story in four acts:

| Act | Story Beat | Key Essentials Capability |
|-----|-----------|--------------------------|
| 1 | "All internet traffic is inspected – no blind spots" | SSL Inspection + Visibility |
| 2 | "Block threats before they reach the user" | Threat Protection (Anti-Virus, Anti-Phishing) |
| 3 | "Control which websites employees can visit" | URL Filtering (200+ categories) |
| 4 | "See every user action with full context" | Standard Analytics & Reporting |

Total run time: **20–30 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

If you have limited time, run this cut-down version:

| # | What to Show | Time |
|---|-------------|------|
| 1 | `ip.zscaler.com` — show traffic routing through ZIA | 1 min |
| 2 | Block an EICAR test file download (threat protection) | 3 min |
| 3 | Block a gambling / anonymizer site (URL filtering) | 3 min |
| 4 | Web Insights dashboard — show user identity on every event | 3 min |

**Talking track for each transition:**
- *"Every byte of internet traffic from this machine runs through ZIA — even HTTPS."*
- *"A user clicked a malware link. ZIA killed it before it reached the browser — no endpoint agent required."*
- *"Dave tried to visit an online gambling site. ZIA blocked it according to company policy — instantly."*
- *"And every event — allow, block, warn — is logged with the user's full identity and context."*

> **Pre-stage tip:** Run `generate_zia_traffic.ps1` and `demo_url_filtering.ps1`
> 10 minutes before the meeting so the dashboards are already populated.

---

## What's Included in Zscaler Essentials

Before diving in, here is a quick reference for what the Essentials bundle
covers. Use this when customers ask "What do I get out of the box?"

| Capability | Included in Essentials | Notes |
|------------|:---------------------:|-------|
| Secure Web Gateway | ✅ | Full cloud-native SWG |
| SSL / TLS Inspection | ✅ | Decrypt and inspect HTTPS traffic |
| URL Filtering (200+ categories) | ✅ | Allow, block, warn, or throttle per category |
| Anti-Virus / Anti-Phishing | ✅ | Signature + heuristic threat detection |
| DNS Filtering | ✅ | Block known-bad domains at the DNS layer |
| Bandwidth Control | ✅ | Throttle streaming, P2P, social media |
| Standard Reporting & Analytics | ✅ | Web Insights, Log Explorer, dashboards |
| Cloud Firewall (basic) | ✅ | L3/L4 firewall rules in the cloud |
| Client Connector (ZCC) | ✅ | Cross-platform endpoint agent |
| Cloud Sandbox | ❌ | Platform only |
| Advanced Threat Protection (ATP) | ❌ | Platform only |
| Inline CASB / Cloud App Control | ❌ | Platform only |
| Data Loss Prevention (DLP) | ❌ | Platform only |
| Browser Isolation | ❌ | Platform only |
| Advanced Analytics | ❌ | Platform only |
| Deception Technology | ❌ | Platform only |

---

## Persona Access Matrix (Quick Reference)

| Capability | bob.jones (IT) | alice.smith (Dev) | carol.white (Contractor) | dave.hr (HR) |
|------------|:--------------:|:-----------------:|:------------------------:|:------------:|
| Business cloud apps | ✅ Allow | ✅ Allow | ✅ Allow | ✅ Allow |
| Social media (view) | ✅ Allow | ✅ Allow | ⚠️ Warn | ⚠️ Warn |
| Streaming video | ⚠️ Throttled | ⚠️ Throttled | ⚠️ Throttled | ⚠️ Throttled |
| Gambling / Anonymizers | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| P2P / Torrents | ❌ Block | ❌ Block | ❌ Block | ❌ Block |
| Malware / Phishing sites | ❌ Block | ❌ Block | ❌ Block | ❌ Block |

---

## Pre-Demo Checklist

> **Lab configuration:** Copy `.env.example` → `.env` at the repo root and set
> `WINDOWS_SERVER_IP`, `LINUX_SERVER_IP`, `LAB_SUBNET`, and `LAB_SUBNET_CIDR` to match
> your environment. All scripts pick up these values automatically.
> See [README § Customising Your Lab](../../README.md#customising-your-lab).

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
> of internet traffic is encrypted. With Zscaler Essentials, every byte of
> traffic is inspected inline, including HTTPS, giving you complete visibility
> from day one."

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

## Act 2 – Threat Protection (7 min)

### Talking Points

> "Even in the Essentials package, Zscaler includes real-time anti-virus,
> anti-phishing, and DNS filtering — all powered by a threat intelligence
> feed updated every few seconds. When a user clicks a bad link, ZIA blocks
> it before the first byte reaches their browser."

### Steps

1. **Attempt to download an EICAR test file (malware simulation)**
   - Run the threat protection demo script on Windows 11:
     ```powershell
     .\scripts\zia\windows\demo_threat_protection.ps1
     ```
   - The script attempts to download known EICAR test files and visits
     test phishing pages.
   - ZIA blocks all of them; the script prints **BLOCKED** in green for each.

   > "The EICAR file is the industry-standard test for anti-malware detection.
   > ZIA identified and blocked it in the inspection layer — the file never
   > reached the disk. This is included out of the box with Essentials."

2. **Show the block page in the browser**
   - Open a browser and navigate to `https://malware.wicar.org`.
   - ZIA's block page appears with the category, rule name, and an option to
     request access.

3. **Show the threat event in the portal**
   - Navigate to **Analytics → Threat Insights**.
   - The EICAR/malware attempt appears with user identity, URL, threat name,
     and action taken.

   > "Security ops can see in real time: who clicked what, what the threat was,
   > and that it was stopped — all without any on-prem hardware."

4. **Demonstrate DNS Filtering**
   - Show the DNS policy in **Policy → DNS Control**.
   - Explain how known-bad domains are blocked at the DNS layer before a TCP
     connection is even established.

   > "DNS filtering adds another ring of defence. Even if the user types a
   > known malicious domain directly, ZIA intercepts the DNS query and blocks
   > resolution. No network connection is ever made."

---

## Act 3 – URL Filtering & Bandwidth Control (8 min)

### Talking Points

> "URL filtering is at the heart of Zscaler Essentials. Over 200 URL
> categories are maintained and updated continuously by Zscaler. You can
> allow, block, warn, or throttle traffic for each category — per user group,
> per location, per time window."

### Steps

1. **Run the URL filtering demo script**
   - On Ubuntu:
     ```bash
     sudo bash scripts/zia/linux/demo_url_filtering.sh
     ```
   - The script visits sites across multiple categories and reports which are
     allowed, warned, and blocked.

2. **Show the URL Filter policy**
   - Navigate to **Policy → URL & Cloud App Control → URL Filter Policy**.
   - Walk through the rules:
     - `Allow-Business-Apps` — Microsoft, Google, Salesforce
     - `Warn-Social-Media-Contractors` — LinkedIn, Twitter (caution page)
     - `Block-Gambling-Anonymizers` — Gambling, anonymizer, and P2P categories
     - `Throttle-Streaming` — YouTube, Spotify, Twitch (bandwidth control)

   > "We're not blocking the entire internet. We're applying policy per
   > category and per user group. IT can browse freely; contractors see a
   > caution page for social media; gambling is blocked for everyone."

3. **Show the Caution page live**
   - Log in as `carol.white` (Contractor persona).
   - Navigate to a social media site (e.g., `https://twitter.com`).
   - A ZIA **Caution** page appears, letting the user acknowledge the policy
     and continue if needed.

   > "The Caution page is a softer touch. It reminds the user of the company
   > policy without hard-blocking. The user can acknowledge and continue — but
   > the event is logged."

4. **Show Bandwidth Control**
   - Navigate to **Policy → Bandwidth Control**.
   - Show how streaming-video category traffic is throttled to a specified
     Mbps limit.

   > "Bandwidth control is included in Essentials. Instead of blocking YouTube
   > entirely, you can throttle it so streaming doesn't starve business-critical
   > apps."

5. **Show blocked category in the browser**
   - Navigate to `https://www.bet365.com` (or any gambling site).
   - ZIA's block page appears with the URL category and rule that triggered.

   > "This is a hard block — no acknowledge button, no override. The policy
   > says gambling is blocked, and ZIA enforces it everywhere, on every device,
   > on every network."

---

## Act 4 – Reporting & Analytics (5 min)

### Talking Points

> "Security is only as good as the visibility it provides. Even with
> Essentials, ZIA gives IT and security teams a real-time view of all
> internet traffic — who is going where, what was blocked, and why."

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
     - URL category
     - Policy rule that triggered
     - Bytes transferred
     - Threat name (if applicable)

   > "This is the single source of truth for your internet security posture.
   > Every event, every user, complete context."

3. **Executive Dashboard**
   - Navigate to the **Dashboard** home.
   - Show the security summary: threats blocked today, top risky users,
     bandwidth by category.

4. **Scheduled Reports**
   - Navigate to **Analytics → Scheduled Reports**.
   - Show how weekly/monthly summary reports are emailed to stakeholders
     automatically.

   > "Executives don't need portal access to stay informed. Scheduled reports
   > deliver the highlights straight to their inbox."

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

| Legacy Proxy | ZIA Essentials |
|-------------|----------------|
| On-prem hardware (single point of failure) | Cloud-native, globally distributed |
| Limited to HTTP/HTTPS | Full SSL inspection + DNS filtering |
| No user identity context | Full user + device identity per session |
| Static signature updates (hours/days) | Real-time threat intelligence (seconds) |
| Limited URL categories | 200+ categories, continuously maintained |
| No bandwidth control | Built-in bandwidth control per category |

### "Is Essentials enough, or should we start with Platform?"

Essentials is perfect for organisations that need a cloud-delivered Secure Web
Gateway with **SSL inspection, URL filtering, basic threat protection, DNS
filtering, and bandwidth control**. If you also need advanced threat sandboxing,
DLP, inline CASB, or browser isolation, those capabilities are available in the
Platform bundle — and the upgrade is seamless because the infrastructure is the
same.

---

## Post-Demo Next Steps

1. Share the [ZIA Architecture White Paper](https://www.zscaler.com/resources/white-papers/zscaler-internet-access.pdf).
2. Offer a **Proof of Value (PoV)** with the customer's own internet traffic
   and their real user groups.
3. Discuss the customer's current proxy / NGFW solution and map Essentials
   capabilities to each gap.
4. Walk through the **Upsell to Zscaler Platform** section below.
5. Discuss a phased rollout: start with Essentials and add Platform capabilities
   as the customer matures.

---

## Upsell to Zscaler Platform

> **Transition:** *"Everything you've seen today — SSL inspection, URL
> filtering, threat protection, analytics — is included in Zscaler Essentials.
> Now let me show you what happens when you move to Zscaler Platform."*

### Side-by-Side Comparison

| Capability | Essentials | Platform |
|------------|:----------:|:--------:|
| Secure Web Gateway (SWG) | ✅ | ✅ |
| SSL / TLS Inspection | ✅ | ✅ |
| URL Filtering (200+ categories) | ✅ | ✅ |
| Anti-Virus / Anti-Phishing | ✅ | ✅ |
| DNS Filtering | ✅ | ✅ |
| Bandwidth Control | ✅ | ✅ |
| Cloud Firewall (basic) | ✅ | ✅ |
| Standard Reporting & Analytics | ✅ | ✅ |
| Cloud Sandbox (zero-day threats) | ❌ | ✅ |
| Advanced Threat Protection (ATP) | ❌ | ✅ |
| Inline CASB / Cloud App Control | ❌ | ✅ |
| Data Loss Prevention (DLP) | ❌ | ✅ |
| Browser Isolation | ❌ | ✅ |
| Advanced Analytics & Insights | ❌ | ✅ |
| Deception Technology | ❌ | ✅ |

### Key Upsell Talking Points

Use these talking points to frame the upgrade as a natural next step,
not as a gap in Essentials.

#### 1. Cloud Sandbox – Stop Zero-Day Threats

> "The anti-virus engine you just saw catches known threats instantly. But
> what about a brand-new piece of malware that nobody has seen before?
> Platform adds the **Cloud Sandbox** — ZIA detonates unknown files in an
> isolated environment and delivers a verdict in seconds. If the file is
> malicious, it's blocked retroactively for every user across your tenant."

**Demo tie-in:** During Act 2, after showing the EICAR block, say:
*"EICAR is a known signature. With Platform, even a completely new,
never-before-seen binary would be caught by the Cloud Sandbox before it
reaches your users."*

#### 2. Inline CASB / Cloud App Control – Sanctioned vs. Unsanctioned Apps

> "Today you saw URL filtering — we can allow or block entire websites. But
> what if you want to allow corporate Dropbox and block personal Dropbox?
> What if you want to let users view social media but block them from posting?
> Platform adds **inline CASB** with granular, per-action cloud app control."

**Demo tie-in:** After showing URL filtering in Act 3, say:
*"We blocked the entire gambling category. But for cloud apps like Office 365,
Dropbox, and Slack, you need finer controls — allow the corporate tenant,
block the personal one. That's what Cloud App Control in Platform gives you."*

#### 3. Data Loss Prevention (DLP) – Protect Sensitive Data

> "Today, we're inspecting what comes *into* the organisation — threats,
> malware, phishing. But what about data going *out*? With Platform, ZIA's
> built-in DLP inspects every upload for credit card numbers, SSNs, health
> information, intellectual property, and custom patterns — and blocks the
> upload before it leaves."

**Demo tie-in:** Say:
*"Imagine Carol tries to upload a spreadsheet with customer credit card
numbers to a file-sharing site. With Essentials, that upload goes through
(we only see the URL category). With Platform's DLP, ZIA inspects the
content of the file, matches the credit card pattern, and blocks the upload
instantly."*

#### 4. Browser Isolation – Render Risky Sites Safely

> "Some websites are too risky to allow but too important to block —
> think webmail, personal sites from new partners, or uncategorised URLs.
> With Platform, **Browser Isolation** renders these pages in a secure
> container in the Zscaler cloud and streams only the pixels to the user.
> No code ever reaches their browser."

**Demo tie-in:** Say:
*"In the demo, we blocked anonymizer sites outright. But what about a site
that's 'Miscellaneous' — not clearly good or bad? Browser Isolation lets
you safely render it without any risk to the endpoint."*

#### 5. Advanced Analytics – Deeper Insights for SOC Teams

> "The dashboards and Log Explorer you saw today cover the essentials.
> Platform unlocks **Advanced Analytics** with interactive drill-downs,
> trend analysis, executive reports, and the ability to correlate events
> across ZIA, ZPA, and ZDX for a single-pane-of-glass view."

**Demo tie-in:** After Act 4, say:
*"What you see here is great for day-to-day monitoring. For your SOC team
and compliance reporting, Platform's Advanced Analytics takes this to the
next level with deep drill-downs, custom dashboards, and cross-product
correlation."*

#### 6. Deception Technology – Catch Post-Breach Attackers

> "Everything we've shown today protects the perimeter — we inspect every
> byte entering or leaving the organisation. But what about a threat that's
> already inside? A phished credential, a compromised laptop, a supply-chain
> attack? Zscaler Platform includes **Deception Technology**: fake servers,
> fake credentials, and fake files scattered throughout the environment.
> No legitimate user ever touches a decoy. If anything does, it's an attacker
> — and the alert fires with 100% confidence, zero false positives.
> The attacker's entire kill chain is reconstructed automatically."

**Demo tie-in:** Say:
*"Imagine an attacker got in through a phishing email. With Essentials, ZIA
blocked the original malicious link. But suppose they used a different path.
With Platform's Deception, the moment they start probing the internal
network — checking open ports, trying a saved credential — they hit one of
our fake assets. Alert fires. SOAR playbook isolates the machine. They don't
get a second move."*

For a live demonstration, see the [Deception Demo Guide](../deception/Deception_Demo_Guide.md)
and the attacker simulation scripts in `scripts/deception/`.

### Closing the Upsell Conversation

> "Here's the best part: **upgrading from Essentials to Platform requires
> zero infrastructure changes.** Same Client Connector. Same cloud. Same
> admin portal. You flip a licence switch and the advanced capabilities
> light up instantly. Many customers start with Essentials, prove the value,
> and upgrade within six months."

**Recommended next steps after showing the upsell:**

1. Walk through the full [ZIA Demo Guide](../zia/ZIA_Demo_Guide.md) to show
   Cloud App Control and DLP live (these are Platform features demoed there).
2. Run the [Deception Demo Guide](../deception/Deception_Demo_Guide.md) to
   show the post-breach detection story — fake credentials, live attacker
   simulation, zero-false-positive alerts, and one-click SOAR response.
3. Propose a **phased Proof of Value**: Phase 1 with Essentials, Phase 2
   adding Platform capabilities.
4. Share the [Zscaler Platform data sheet](https://www.zscaler.com/resources/data-sheets) and pricing comparison.
5. Discuss the customer's compliance requirements (PCI-DSS, HIPAA, GDPR) —
   DLP and Advanced Analytics are often deal-clinchers for regulated industries.
6. Position ZPA and ZDX as complementary products for a full Zero Trust
   Exchange deployment.
