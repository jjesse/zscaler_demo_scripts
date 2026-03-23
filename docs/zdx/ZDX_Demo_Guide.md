# ZDX Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Digital Experience
(ZDX) demo with a customer or prospect. It maps every demo beat to the scripts
in this repository so you never lose your place.

---

## Overview

This demo tells a single story in four acts:

| Act | Story Beat | Key ZDX Capability |
|-----|-----------|-------------------|
| 1 | "See every user's digital experience in real time" | ZDX Score Dashboard |
| 2 | "Pinpoint exactly where and why experience is poor" | Path Tracing & Root Cause |
| 3 | "Good scores vs poor scores – show the contrast" | Healthy vs Degraded Experience |
| 4 | "Fix problems before the help desk ever rings" | Proactive Alerting & Remediation |

Total run time: **25–35 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

If you have limited time, run this cut-down version:

| # | What to Show | Time |
|---|-------------|------|
| 1 | ZDX Dashboard – show score map with green (good) and red (poor) endpoints | 2 min |
| 2 | Drill into a low-scoring device – show the degraded path trace | 3 min |
| 3 | Run the poor-score simulation script; show dashboard update in real time | 3 min |
| 4 | Show alert firing and the one-click IT remediation workflow | 2 min |

**Talking track for each transition:**
- *"ZDX gives IT a real-time view of every user's experience — before they call the help desk."*
- *"The red node is sitting in the ISP segment, not inside our network. We can prove it isn't our fault."*
- *"Watch the score drop as I degrade performance on this endpoint — ZDX catches it in seconds."*
- *"An alert fired automatically. IT already knows who is affected, where the problem is, and how to fix it."*

> **Pre-stage tip:** Run `demo_zdx_scores.ps1 -Scenario Good` 10 minutes before
> the meeting so the ZDX dashboard has baseline good-score history to compare
> against when you run the poor-score scenario live.

---

## Understanding ZDX Scores

ZDX synthesises multiple signals into a single **ZDX Score** (0–100):

| Score Range | Label | What It Means |
|-------------|-------|---------------|
| 80 – 100 | 🟢 **Good** | Application and network path fully healthy |
| 60 – 79 | 🟡 **Fair** | Minor degradation; monitor but no action needed |
| 40 – 59 | 🟠 **Degraded** | Noticeable impact on user experience |
| 0 – 39 | 🔴 **Poor** | Severe degradation; immediate attention required |

Scores are computed per **user**, per **device**, and per **application** by
combining:
- **Device health** – CPU, RAM, battery, Wi-Fi signal, and process metrics
- **Network path quality** – latency, jitter, packet loss across each hop
- **Application performance** – DNS resolution, TCP handshake, TLS, and
  server response time for SaaS apps (Microsoft 365, Zoom, Salesforce, etc.)

---

## Pre-Demo Checklist

- [ ] ZDX Admin Portal open in a browser tab (`https://zdx.zscaler.com`).
- [ ] Windows 11 machine with Zscaler Client Connector **Connected** (ZDX data
      collection requires Client Connector v3.7+).
- [ ] Ubuntu machine with Client Connector running and ZDX probes active.
- [ ] At least one monitored application configured in ZDX
      (e.g. `Microsoft 365`, `Zoom`, or `Salesforce`).
- [ ] Scripts ready on both machines:
      - Windows: `scripts/zdx/windows/demo_zdx_scores.ps1`
      - Linux: `scripts/zdx/linux/demo_zdx_scores.sh`
- [ ] ZDX alerting configured: **Administration → Alerts** with at least one
      alert rule for ZDX Score < 60.

---

## Act 1 – ZDX Score Dashboard (6 min)

### Talking Points

> "Help desks are reactive — they wait for users to complain. ZDX flips that
> model. IT sees performance problems in real time, across every user and every
> application, before a single ticket is raised."

### Steps

1. **Open the ZDX Dashboard**
   - Navigate to `https://zdx.zscaler.com` → **Dashboard**.
   - The world map shows every endpoint as a coloured dot: green (good),
     yellow (fair), orange (degraded), red (poor).

   > "Each dot is a real user. The colour tells you their current ZDX Score.
   > Right now I can see at a glance that most users are healthy, but there
   > are a few orange and red dots worth investigating."

2. **Show the Application Score Summary**
   - On the Dashboard, click the **Applications** tab.
   - Show the per-application score table (e.g. Microsoft 365 at 92, Zoom at 74,
     Salesforce at 88).

   > "We monitor each SaaS application independently. Zoom is yellow today —
   > let's find out why."

3. **Drill into a specific application**
   - Click **Zoom** (or any application showing a non-perfect score).
   - The application detail view shows:
     - Score trend over the last 24 hours
     - Top affected users and devices
     - Geographic distribution of the degradation

   > "The problem started 2 hours ago and is only affecting users in the
   > Chicago office — which tells us this is likely a regional ISP issue,
   > not something inside our corporate network."

4. **Run the baseline good-score script** (to populate dashboard history)
   - On Windows 11:
     ```powershell
     .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Good
     ```
   - On Ubuntu:
     ```bash
     bash scripts/zdx/linux/demo_zdx_scores.sh --scenario good
     ```
   - The script simulates a healthy endpoint by running lightweight network
     probes to ZDX-monitored applications and reporting low-latency results.

---

## Act 2 – Path Tracing & Root Cause (8 min)

### Talking Points

> "Knowing that experience is poor is only half the story. ZDX tells you
> *where* in the path the problem is — the device, the local network, the
> corporate network, the ISP, or the SaaS app itself."

### Steps

1. **Open the Path Trace view for an affected user**
   - Navigate to **Users** → select a user with a degraded or poor score.
   - Click **Path Trace**.

   The path trace shows every hop from the endpoint to the application, with
   latency and packet-loss data for each segment:

   ```
   [Device] → [Wi-Fi / LAN] → [Corporate Network] → [Zscaler PoP] → [ISP] → [App]
     ✅ 2 ms       ✅ 4 ms          ✅ 8 ms              ✅ 12 ms       🔴 180 ms   ✅ 5 ms
   ```

   > "The problem is clearly in the ISP segment — latency jumps from 12 ms to
   > 180 ms right after the Zscaler PoP. The corporate network and the app
   > server are both healthy. This is not an IT problem — it's a carrier
   > problem. And ZDX proves it, with data."

2. **Show the Device Health tab**
   - Still on the user view, click **Device Health**.
   - Show CPU usage, available RAM, battery status, Wi-Fi RSSI, and
     active ZPA/ZIA sessions.

   > "Sometimes poor experience isn't a network problem at all — the user's
   > laptop is running at 98% CPU because they have 40 browser tabs open.
   > ZDX surfaces that too, so IT doesn't waste time chasing a 'network issue'
   > that is actually an endpoint issue."

3. **Compare two users side by side**
   - Navigate to **Users** → select a user with a **good** score → **Path Trace**.
   - Open a second browser tab with a user who has a **poor** score → **Path Trace**.
   - Show the contrast: healthy path vs degraded path.

   > "Side by side: Alice in London has a ZDX Score of 91 — all hops green.
   > Bob in Chicago has a score of 38 — one hop is completely red. Both users
   > are on the same application, the same policy, the same Zscaler tenant.
   > The difference is entirely in Bob's ISP path."

---

## Act 3 – Good Scores vs Poor Scores (Live Demo) (10 min)

This act is the "wow moment" — demonstrating the score change live in the
portal as you run the simulation scripts.

### Talking Points

> "Let me show you what ZDX looks like when we deliberately degrade the
> performance of this endpoint. Watch the score drop in real time."

### Steps

1. **Establish the baseline (Good Score)**
   - Open the ZDX dashboard and find the demo machine (Windows 11 or Ubuntu).
   - Confirm the current ZDX Score is in the green range (80+).
   - Run the good-score simulation to confirm a healthy baseline:
     ```powershell
     # Windows 11
     .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Good -Verbose
     ```
     ```bash
     # Ubuntu
     bash scripts/zdx/linux/demo_zdx_scores.sh --scenario good --verbose
     ```
   - The script reports:
     - DNS resolution time for monitored apps (< 50 ms)
     - TCP connect time to app endpoints (< 80 ms)
     - HTTP response time (< 200 ms)
     - Packet loss: 0%
     - Device CPU usage: low
     - Wi-Fi signal: strong

   > "These are the metrics ZDX is collecting continuously from every endpoint.
   > Right now everything looks healthy — scores above 80."

2. **Run the Poor Score simulation**
   - Run the poor-experience simulation on Windows 11:
     ```powershell
     .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Poor
     ```
   - On Ubuntu:
     ```bash
     bash scripts/zdx/linux/demo_zdx_scores.sh --scenario poor
     ```
   - The script simulates degraded conditions by:
     - Generating high CPU/memory load on the machine
     - Adding network congestion via large parallel downloads
     - Introducing artificial latency with routing-layer delays
     - Measuring and reporting the resulting degraded probe results

   > "Watch the console — DNS is now taking 400 ms, TCP connect is 900 ms,
   > and we're seeing packet loss. ZDX will detect this within the next
   > probe cycle."

3. **Show the score drop in the ZDX Portal**
   - Switch back to the ZDX dashboard.
   - Within 2–5 minutes the demo machine's dot will shift from green toward
     orange or red.
   - Navigate to the device detail page to show the score trend graph.

   > "There it is. The score dropped from 87 to 41 in under three minutes.
   > ZDX detected the degradation faster than any user could open a help
   > desk ticket."

4. **Restore good conditions**
   - Run the cleanup / restore script:
     ```powershell
     # Windows 11
     .\scripts\zdx\windows\demo_zdx_scores.ps1 -Scenario Restore
     ```
     ```bash
     # Ubuntu
     bash scripts/zdx/linux/demo_zdx_scores.sh --scenario restore
     ```
   - Show the score recovering in the portal over the next few minutes.

   > "And as conditions improve, ZDX reflects that immediately. IT can confirm
   > the remediation worked without waiting for the user to call back."

---

## Act 4 – Proactive Alerting & Remediation (6 min)

### Talking Points

> "ZDX is not just a dashboard — it is an early-warning system. IT gets
> alerted before users are impacted. And when something does go wrong, ZDX
> gives IT all the context they need to fix it immediately."

### Steps

1. **Show the Alerts configuration**
   - Navigate to **Administration → Alerts**.
   - Walk through an existing alert rule:
     - **Trigger:** ZDX Score < 60 for > 5 minutes
     - **Scope:** All users, Microsoft 365 application
     - **Action:** Email to IT team + Slack webhook

   > "We set this threshold at 60 — anything below 'fair' and IT knows within
   > 5 minutes. No users need to call, no one needs to notice."

2. **Show an alert that fired during the poor-score simulation**
   - Navigate to **Administration → Alert History**.
   - Show the alert that triggered during Act 3's poor-score simulation.
   - Click the alert to see:
     - Exact timestamp
     - Affected users and devices
     - Score at time of alert
     - Link to the path trace at that moment in time

   > "The alert gives IT a direct link to the snapshot — this is exactly what
   > the path looked like when the score dropped. No guessing, no log diving."

3. **Show the Remediation workflow**
   - From the alert detail, click **View Affected Devices**.
   - Show the one-click options available to IT:
     - **Send notification to user** – prompt the user to reconnect Client Connector
     - **Restart ZCC service** – remotely restart Client Connector on the endpoint
     - **Open support ticket** – push device health data to ServiceNow / Jira

   > "IT can act directly from ZDX — they don't need to remote-desktop into
   > the machine or call the user. This reduces mean time to resolution from
   > hours to minutes."

4. **Show Trend Analysis and Capacity Planning**
   - Navigate to **Analytics → Score Trends**.
   - Show the 30-day score trend for a monitored application.
   - Highlight a recurring dip at a specific time of day (e.g. 09:00–10:00 AM).

   > "ZDX reveals patterns. This application consistently degrades every
   > morning during peak login hours. We can see it, quantify it, and take
   > it to the SaaS vendor with data. That's IT moving from reactive to
   > proactive."

---

## ZDX Score Comparison: Good vs Poor

| Metric | 🟢 Good Score (80+) | 🔴 Poor Score (< 40) |
|--------|--------------------|--------------------|
| DNS Resolution | < 50 ms | > 500 ms |
| TCP Connect | < 80 ms | > 800 ms |
| TLS Handshake | < 120 ms | > 1,200 ms |
| HTTP Response | < 200 ms | > 2,000 ms |
| Packet Loss | 0% | > 5% |
| Jitter | < 10 ms | > 100 ms |
| Device CPU | < 40% | > 90% |
| Wi-Fi Signal | > -65 dBm | < -80 dBm |

---

## Common Customer Questions & Answers

### "How is ZDX different from traditional monitoring tools like PRTG or SolarWinds?"

| Traditional Monitoring | ZDX |
|----------------------|-----|
| Monitors infrastructure (servers, switches) | Monitors the *end-user experience* |
| Requires agents deployed to every device | Leverages the existing Zscaler Client Connector |
| No visibility into user-side conditions | Full device health metrics (CPU, RAM, Wi-Fi) |
| Sees your network, not the ISP path | Full path visibility from device to app |
| Reactive — alerts after things break | Continuous scoring — trends visible before failure |

### "Does ZDX require a separate agent?"

No. ZDX is built into the Zscaler Client Connector (ZCC). If your users already
have ZCC installed for ZPA or ZIA, ZDX data collection is enabled with no
additional software. You simply activate ZDX in the ZCC settings.

### "Which applications can ZDX monitor?"

ZDX ships with built-in probes for the most common enterprise SaaS applications:
- **Microsoft 365** (Exchange Online, SharePoint, Teams)
- **Zoom**
- **Salesforce**
- **Workday**
- **ServiceNow**
- **Box, Dropbox, Google Workspace**

You can also create custom application probes for any internal or custom SaaS
application by specifying the URL endpoint and expected response.

### "How quickly does ZDX detect and report degradation?"

ZDX probes run every **1–5 minutes** depending on the configured probe interval.
Score changes are reflected in the portal within the same probe cycle. Alerts
with a 5-minute threshold will fire within 10 minutes of a degradation event
in the worst case.

### "Can ZDX help us during a major incident?"

Yes — ZDX's **Incident Correlation** feature lets you tag an incident in the
portal. ZDX then automatically identifies all users and applications affected
during that time window, shows the path traces and device health from the
incident period, and exports the data for the post-incident review.

---

## Post-Demo Next Steps

1. Share the [ZDX Architecture White Paper](https://www.zscaler.com/resources/white-papers/zscaler-digital-experience.pdf).
2. Offer a **Proof of Value (PoV)** — ZDX can be enabled on the customer's
   existing ZCC deployment in hours; no infrastructure changes required.
3. Ask the customer: *"Which SaaS application causes the most help desk tickets
   for performance complaints?"* — that is the first ZDX probe to configure.
4. Show how ZDX + ZPA + ZIA together create a complete zero-trust + digital
   experience observability platform.
5. Discuss integration with the customer's ITSM (ServiceNow, Jira) so ZDX
   alerts automatically create and enrich tickets.
6. Explore ZDX for Branch Offices — how ZDX gives visibility into remote-site
   performance, not just endpoint performance.
