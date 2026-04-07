# Zscaler Deception Demo Guide – Narrated Customer Walkthrough

Use this guide to run a compelling, story-driven Zscaler Deception demo with a
customer or prospect. It maps every demo beat to the scripts in this repository
so you never lose your place.

---

## Overview

This demo tells the story of an attacker who slipped past the perimeter — and
got caught anyway. Every act uses the same lab topology as the ZPA and ZIA
demos, extended with a dedicated attacker machine that simulates real
post-breach behaviour.

| Act | Story Beat | Key Deception Capability |
|-----|-----------|--------------------------|
| 1 | "We assume breach — here's how we prepared" | Decoy asset inventory + Lure deployment |
| 2 | "An attacker is moving through our network right now" | Attacker simulation scripts |
| 3 | "Watch the alerts fire — zero false positives" | Real-time alert feed + kill chain |
| 4 | "Stop the attacker and investigate in seconds" | SOAR response + attack timeline |

Total run time: **30–40 minutes** (adjustable by skipping acts).

---

## ⚡ Boss-Friendly 10-Minute Highlight Reel

If you have limited time, run this cut-down version:

| # | What to Show | Time |
|---|-------------|------|
| 1 | Deception dashboard – decoys deployed across the lab, all green | 1 min |
| 2 | Run attacker simulation – watch alerts fire in real time | 4 min |
| 3 | Attack timeline – show the attacker's kill chain from first probe to decoy | 3 min |
| 4 | SOAR response – one-click quarantine of the attacker's machine | 2 min |

**Talking track for each transition:**
- *"Traditional security tries to keep attackers out. Deception assumes they're already in — and sets a trap."*
- *"Watch the console. The attacker just used a fake credential we planted on the compromised endpoint."*
- *"Every step the attacker took is logged here — recon, credential discovery, lateral movement, decoy touch."*
- *"One click. The attacker's machine is quarantined, a ticket is opened in ServiceNow, and our SOC team is paged."*

> **Pre-stage tip:** Run `setup_decoy_services.sh` and `deploy_deception_tokens.ps1`
> at least 5 minutes before the meeting so the Deception dashboard shows a
> healthy baseline. Start the attacker simulation **live** during the meeting.

---

## The "Assume Breach" Story

Traditional security tools — firewalls, SWG, VPN replacements — operate on the
assumption that if you build walls high enough, threats stay outside. But
attackers routinely get in through phishing, supply-chain compromises, and
stolen credentials. Once inside, they move slowly and quietly, dwelling
undetected for an average of **200+ days** before discovery.

Zscaler Deception flips the detection model:

1. **Deploy fake assets everywhere an attacker would look first** — fake servers,
   file shares, web portals, cloud credentials, SSH keys, and browser-saved
   passwords all scattered across the network.

2. **No legitimate user ever touches a decoy.** A sales engineer does not SSH
   to an unmarked server on port 2222. A developer does not use an AWS key
   buried in an old config file. If anything touches a decoy, it is an attacker
   — and the alert fires with absolute certainty.

3. **Every fake asset produces a full intelligence trail** — which machine the
   attacker used, what credentials they found, which decoy they tried, and what
   they did next. The attacker's entire kill chain is reconstructed automatically.

4. **Complements ZIA and ZPA perfectly:**
   - ZIA stops threats at the internet perimeter
   - ZPA limits lateral movement to explicitly allowed apps
   - Zscaler Deception catches the attacker the moment they probe beyond what
     ZPA allows

---

## Lab Topology (Deception Extension)

```
Internet / ZIA Cloud / ZPA Cloud
         │
    ┌────┴───────────────────────────────────────────────────┐
    │          Zscaler Zero Trust Exchange + Deception Cloud  │
    │  ┌──────────────┐   ┌─────────────┐  ┌──────────────┐  │
    │  │  ZPA Broker  │   │ ZIA Gateway │  │  Deception   │  │
    │  └──────┬───────┘   └─────────────┘  │  Orchestrator│  │
    │         │                            └──────┬───────┘  │
    └─────────┼───────────────────────────────────┼──────────┘
              │                                   │ alert telemetry
    ┌─────────┴──────────────────────────────────┴──────────┐
    │                Lab Network (192.168.1.0/24)             │
    │                                                         │
    │  ┌──────────────────┐  ┌──────────────────────────┐    │
    │  │  Ubuntu 22.04    │  │  Windows Server 2022     │    │
    │  │  ZPA Connector   │  │  IIS, RDP, SMB           │    │
    │  │  Decoy Services  │  │  Deception Tokens        │    │
    │  │  192.168.1.10    │  │  192.168.1.20            │    │
    │  └──────────────────┘  └──────────────────────────┘    │
    │                                                         │
    │  ┌──────────────────┐  ┌──────────────────────────┐    │
    │  │  Windows 11      │  │  "Attacker" Machine      │    │
    │  │  192.168.1.30    │  │  Ubuntu or Kali          │    │
    │  │  Deception Tokens│  │  simulate_attacker.sh    │    │
    │  └──────────────────┘  │  192.168.1.40            │    │
    │                         └──────────────────────────┘    │
    └─────────────────────────────────────────────────────────┘
```

> **Two-machine shortcut:** If you do not have a fourth machine, run the
> attacker simulation from the Ubuntu server using `--local` mode. This
> simulates an attacker with a foothold on the Ubuntu server itself.

---

## Decoy Architecture Overview

Zscaler Deception deploys assets in two categories:

### Decoys (Fake Servers and Services)

| Decoy Type | IP / Port | What It Simulates |
|-----------|-----------|-------------------|
| Fake Internal Web Portal | 192.168.1.10:8081 | Employee intranet / HR portal |
| Fake SSH Server | 192.168.1.10:2222 | Legacy admin jump host |
| Fake Database Server | 192.168.1.10:3307 | MySQL database server |
| Fake File Server | 192.168.1.10:4445 | SMB / NFS file share |
| Fake Windows RDP Host | 192.168.1.20:3388 | Unlisted workstation (not in ZPA) |
| Fake Cloud Storage API | api.fake-storage.internal | S3-compatible object store |

### Lures / Deception Tokens (Breadcrumbs on Real Endpoints)

| Token Type | Location on Endpoint | Purpose |
|-----------|---------------------|---------|
| Fake AWS credentials | `~/.aws/credentials` | Lead attacker to fake cloud console |
| Fake SSH config entry | `~/.ssh/config` | Point attacker to fake SSH decoy |
| Fake `.env` config file | `/opt/app/.env` | Expose fake DB password |
| Fake backup SQL file | `/tmp/db_backup.sql` | Contain fake DB connection string |
| Fake KeePass database | `C:\Users\...\Documents\vault.kdbx` | Bait for credential-hunting tools |
| Fake Windows credential | Windows Credential Manager | Lead attacker to fake SMB share |
| Fake browser password CSV | `C:\Users\...\Downloads\passwords.csv` | Lead attacker to fake web portals |

---

## Pre-Demo Checklist

- [ ] Zscaler Deception Admin Portal open in a browser tab.
- [ ] Decoy services running on Ubuntu (run `setup_decoy_services.sh` in advance).
- [ ] Deception tokens deployed on Windows 11 (run `deploy_deception_tokens.ps1`).
- [ ] Attacker machine ready — either a separate Ubuntu/Kali, or Ubuntu with `--local`.
- [ ] ZPA Admin Portal open (show lateral movement is limited — backdrop for Deception story).
- [ ] ZIA Admin Portal open (contrast: perimeter blocked; what about inside the network?).
- [ ] Deception portal: navigate to **Dashboard** — confirm all decoys show as **Active**.
- [ ] Deception portal: navigate to **Lures** — confirm tokens show as **Deployed** on endpoints.
- [ ] Clear any old alerts: **Alerts → Active Alerts → Archive All** before the demo.

---

## Act 1 – The Deception Posture: "We Assumed Breach" (8 min)

### Talking Points

> "ZIA inspects every byte leaving the network. ZPA ensures users can only reach
> the applications they're explicitly allowed to use. But what if an attacker
> gets in through a phishing email, a stolen laptop, or a compromised vendor?
> That's where Zscaler Deception comes in.
>
> We don't wait for the attacker to find something real. We surround them with
> fake assets — and the moment they touch any of them, we know exactly who they
> are and what they're doing."

### Steps

1. **Open the Deception Dashboard**
   - Navigate to the Zscaler Deception Admin Portal → **Dashboard**.
   - Show the overview:
     - Total decoys deployed across the environment
     - Total lures (deception tokens) planted on endpoints
     - Recent alert history (should be clear from pre-demo reset)
     - Coverage heat map (what percentage of internal subnets have decoys)

   > "Every green icon is a fake asset we've deployed. Attackers can't tell
   > real from fake — they have to probe everything. The moment they probe
   > a fake, we know."

2. **Show the Decoy Inventory**
   - Navigate to **Decoys → All Decoys**.
   - Walk through the decoy types:
     - **Network Decoys**: Fake servers at IP addresses that respond like real services
     - **Application Decoys**: Fake web portals, fake login pages
     - **Service Decoys**: Fake SSH, fake RDP, fake databases

   > "We deploy decoys on the same subnet as your real servers. An attacker
   > doing a port scan sees real servers and fake servers side by side. There's
   > no way to tell them apart without interacting with them — and every
   > interaction is an alert."

3. **Show the Lure (Token) Inventory**
   - Navigate to **Lures → All Lures**.
   - Walk through the token categories:
     - **Credential Tokens**: Fake usernames and passwords embedded in files
     - **Cloud Tokens**: Fake AWS access keys, Azure SPN credentials
     - **File Tokens**: Fake backup files, fake database exports, fake config files
     - **Network Tokens**: Fake SSH configs, fake RDP shortcuts

   - Click any deployed lure to show which endpoint it is deployed on.

   > "These tokens are planted on *real* endpoints. When an attacker compromises
   > a machine — which they will, through phishing or a stolen laptop — the first
   > thing they do is look for credentials to move laterally. They find our fake
   > credential. They use it. Alert fires. Game over."

4. **Explain the Zero-False-Positive Guarantee**
   - Navigate to **Alerts → Alert Policy**.
   - Show the alert policy: any interaction with a decoy = Critical alert.

   > "There is no tuning, no threshold, no correlation required. A legitimate
   > user has no business connecting to an unmarked server on port 2222.
   > A legitimate process has no reason to use an AWS key hidden in an old
   > backup file. Every alert is real. Every alert is actionable."

5. **Show the Deception Tokens on the lab endpoints**
   - Navigate to **Lures → Deployed Lures**.
   - Show the Windows 11 endpoint (192.168.1.30) — confirm these tokens are active:
     - Fake AWS credentials: `C:\Users\demouser\.aws\credentials`
     - Fake intranet bookmark: browser favourite pointing to decoy portal
     - Fake saved password: Windows Credential Manager entry for decoy SMB share

   > "These tokens were deployed silently, in seconds. There's no agent
   > installation, no endpoint reboot. The attacker sees what looks like
   > real credentials left by a careless administrator."

---

## Act 2 – The Attacker Is Inside (Live Simulation) (10 min)

### Talking Points

> "Let me be the attacker. I've just phished an employee and have a shell on
> their machine. I don't know the network — I need to explore. Watch what
> happens."

### Setup

Ensure the attacker terminal is open and the network is visible from the
attacker machine.

### Steps

1. **Start the attacker simulation on the Linux attacker machine**
   ```bash
   sudo bash scripts/deception/linux/simulate_attacker.sh \
       --subnet 192.168.1.0/24 \
       --attacker-ip 192.168.1.40 \
       --target-host 192.168.1.10
   ```
   Or from the Ubuntu server itself (two-machine shortcut):
   ```bash
   sudo bash scripts/deception/linux/simulate_attacker.sh --local
   ```

   > "Phase 1: I'm mapping the network. ARP table, ping sweep. Let me find
   > out what's alive."

2. **Let Phase 1 (Recon) complete — narrate as it runs**
   - The script prints each discovered host.
   - Show `192.168.1.10`, `192.168.1.20`, `192.168.1.30` appearing.

   > "I can see the network. Three live hosts. One is the server
   > I compromised — the other two I don't know yet."

3. **Let Phase 2 (Service Discovery) run — narrate**
   - The script scans each host for open ports and banner-grabs.
   - Show the scan output — real ports (80, 443, 22, 3389) plus decoy ports
     (8081, 2222, 3307, 4445).

   > "I'm looking for open doors. An internal web portal on 8081 — interesting.
   > An SSH server on 2222 I haven't seen before. A database port on 3307.
   > These are all things I want to explore."

4. **Let Phase 3 (Credential Discovery) run — pause here**
   - The script simulates finding the deception token files on the compromised
     machine (fake AWS creds, fake SSH config pointing to the decoy).

   > "This is the moment. I found credentials left by an admin. AWS access key,
   > an SSH config pointing to that mystery server on 2222. I'm going to use these."

   - **Switch to the Deception Portal** — the lure has been "discovered" and
     a Phase 3 alert fires.

   Navigate to **Alerts → Active Alerts** — show the first alert:
   ```
   [HIGH] Lure Accessed – Credential Token Read
   Endpoint:  192.168.1.30 (Windows 11 – demouser)
   Lure:      Fake AWS credentials file
   Timestamp: <now>
   ```

   > "The lure was accessed. We know an attacker read that file. We don't know
   > yet if they used it — but we flagged the machine for monitoring."

5. **Let Phase 4 (Decoy Interaction) run — the "wow moment"**
   - The script uses the fake credentials to attempt SSH login to port 2222.
   - The script makes an HTTP POST to the decoy web portal (port 8081) with
     the fake credentials.
   - The script tries to connect to the fake database on port 3307.

   - **Stay on the Deception Portal** — watch the alerts cascade in real time.

   Navigate to **Alerts → Active Alerts** — new Critical alerts appear:
   ```
   [CRITICAL] Decoy Interaction – SSH Honeypot Touched
   Attacker:  192.168.1.40 (or 192.168.1.30 in --local mode)
   Decoy:     Fake SSH Server (192.168.1.10:2222)
   Credential Used: lab-admin / P@ssw0rd!fake
   Timestamp: <now>

   [CRITICAL] Decoy Interaction – Web Portal Login Attempt
   Attacker:  192.168.1.40
   Decoy:     Fake Internal Web Portal (192.168.1.10:8081)
   Credential Used: admin / Welcome1!fake
   Timestamp: <now>
   ```

   > "There it is. Two Critical alerts. Zero false positives. The attacker
   > just told us exactly who they are, where they are, and what credentials
   > they're using. They don't know we know."

6. **Let Phase 5 (Post-Exploitation) run — wrap the attack story**
   - The script simulates lateral movement, fake cloud credential use, and
     an exfiltration probe.
   - Additional alerts fire for each decoy interaction.

---

## Act 3 – Inside the Portal: Zero False Positives (8 min)

### Talking Points

> "Traditional SIEMs generate thousands of alerts a day. Security teams are
> drowning. Deception generates alerts you can act on immediately — every one
> is real, every one has full context, and every one tells you the attacker's
> exact location and method."

### Steps

1. **Alert Feed Overview**
   - Navigate to **Alerts → Active Alerts**.
   - Show all alerts from the simulation — typically 6–10 Critical alerts.
   - Point to the severity: every Deception alert is High or Critical.
   - Point to the zero-noise nature: no informational alerts, no false positives.

   > "Traditional IDS/IPS generates thousands of low-severity events. Security
   > teams learn to ignore them. Deception generates only high-confidence,
   > high-severity alerts — and there is no volume to tune out."

2. **Drill Into an Alert**
   - Click the **SSH Honeypot** alert.
   - Walk through the alert detail:
     - **Source**: Attacker's IP and machine name
     - **Target**: Decoy identifier, IP, port
     - **Credential used**: The exact username and password the attacker tried
     - **Lure chain**: Which fake credential the attacker found to get here
     - **Session recording**: Partial SSH session capture (commands attempted)

   > "We know the attacker's IP. We know the machine they're on. We know the
   > credential they used — which tells us which endpoint they compromised to
   > find it. We have all of this in the first 30 seconds of the alert."

3. **The Attack Timeline (Kill Chain)**
   - Navigate to **Investigation → Attack Timeline**.
   - Show the full kill chain visualised as a timeline:
     ```
     T+00:00  Lure accessed on Windows11 (demouser)
                → Fake AWS credentials file read
     T+00:45  Decoy interaction – SSH honeypot
                → 192.168.1.10:2222 — credential: lab-admin
     T+01:10  Decoy interaction – Web portal login
                → 192.168.1.10:8081 — credential: admin
     T+02:30  Decoy interaction – Database probe
                → 192.168.1.10:3307 — credential: dbadmin
     T+03:15  Cloud token used – Fake AWS key
                → STS:GetCallerIdentity call from 192.168.1.40
     ```

   > "This is the attacker's kill chain, reconstructed automatically. In a
   > traditional environment, building this timeline would take hours or days
   > of log correlation. Deception gives it to you in real time."

4. **The Attack Graph (Lateral Movement Map)**
   - Navigate to **Investigation → Attack Graph**.
   - Show the visual graph:
     - Compromised endpoint (Windows 11) at the origin
     - Lines showing lateral movement attempts to each decoy
     - Red nodes for decoys that were touched

   > "This is the blast radius. We can see exactly where the attacker went
   > and what they tried. More importantly, we can see what they *did not*
   > reach — which tells us what our real assets are safe."

5. **Attacker Intelligence**
   - Navigate to **Investigation → Attacker Intelligence**.
   - Show the tools and techniques detected:
     - TCP port scanner (Phase 2)
     - Credential harvesting (Phase 3)
     - SSH brute-force attempt (Phase 4)
     - Database authentication probe (Phase 4)

   > "ZIA knows what sites your users visit. ZPA knows which apps they access.
   > Deception knows how an attacker *operates* inside your network. This is
   > the intelligence your threat hunters need."

---

## Act 4 – Response: Stop the Attacker in Seconds (8 min)

### Talking Points

> "Detection without response is just expensive logging. Deception integrates
> with your SOAR, your SIEM, and your endpoint tools to take immediate action
> the moment a decoy is touched. Let me show you what that looks like."

### Steps

1. **Quarantine the Attacker's Machine (SOAR Integration)**
   - Navigate to the **SSH Honeypot** alert.
   - Click **Respond → Isolate Endpoint**.
   - The SOAR playbook runs:
     - ZPA: Access policy updated to block the attacker's machine from all
       private applications
     - ZIA: Machine tagged as Compromised; all internet access blocked
     - SIEM: Event forwarded with full context (Splunk / Microsoft Sentinel)
     - Ticket: ServiceNow/Jira incident opened automatically

   > "One click. The attacker's machine is offline from a network perspective —
   > they can't reach any ZPA-protected app, they can't reach the internet.
   > Their lateral movement stops immediately."

2. **Show the ZPA Policy Change in Real Time**
   - Switch to ZPA Admin Portal → **Policy → Access Policy**.
   - Show the new dynamic rule that was injected by the SOAR playbook:
     ```
     Rule: Quarantine-Compromised-192.168.1.40
     Condition: Source IP = 192.168.1.40
     Action: BLOCK (all applications)
     Expiry: 24 hours (auto-expiry with analyst review)
     ```

   > "The ZPA policy was updated in under 30 seconds — no firewall ticket,
   > no change management window. The attacker is isolated while your analysts
   > investigate."

3. **SIEM Integration – Context Enrichment**
   - Navigate to **Settings → Integrations → SIEM**.
   - Show the log format streamed to Splunk / Microsoft Sentinel.
   - The Deception alert event includes:
     - Full JSON with attacker IP, machine identity, user context
     - Deception kill chain summary
     - Confidence score (always 100% for a decoy interaction)
     - Recommended remediation actions

   > "Your SOC team receives a ticket with a confidence score of 100%. They
   > don't need to triage or de-duplicate. They go straight to investigation
   > and containment."

4. **Investigate the Compromised Endpoint**
   - From the alert, click **View Endpoint Details**.
   - Show the endpoint health data:
     - Which user was logged in (demouser)
     - ZIA traffic at the time of the breach (suspicious outbound connection)
     - ZPA sessions open at the time
     - Process list snapshot at the time of the lure access

   > "We know who was logged on, what they were doing online, what private apps
   > they had open — all from a single pane of glass. This replaces hours of
   > manual forensics."

5. **Deception-Driven Threat Hunting (Optional Power Move)**
   - Navigate to **Threat Hunting → Correlated Indicators**.
   - Show any other machines on the network that accessed the same lure or
     used the same fake credential.
   - This could indicate multiple compromised machines from the same campaign.

   > "Deception doesn't just tell you about the one attacker you caught.
   > It correlates across the entire environment to find other machines that
   > may have been exposed to the same campaign. You don't catch one attacker —
   > you catch the entire operation."

6. **Reset the Lab After the Demo**
   ```bash
   # Linux – stop all attacker simulation and decoy services
   sudo bash scripts/reset_lab.sh --deception

   # Windows – stop tokens and clear credentials
   .\scripts\reset_lab.ps1 -Deception
   ```

---

## Deception vs Traditional Detection: Side-by-Side

| | Traditional SIEM/IDS | Zscaler Deception |
|--|---------------------|-------------------|
| Alert volume | Thousands per day | Dozens per day (all real) |
| False positive rate | 95%+ | 0% — every alert is confirmed |
| Time to detect | Days to months (avg. 200+ days) | Minutes |
| Kill chain reconstruction | Manual – hours to days | Automatic – real time |
| Attacker intelligence | IP and port only | Full credential, TTPs, lateral movement |
| Response integration | Manual playbook trigger | Automatic SOAR playbook |
| Agent required | Yes (EDR on every endpoint) | No – tokens and decoys are agentless |
| Covers insider threat | Limited | Yes – insider touching a decoy is caught |

---

## Common Customer Questions & Answers

### "Won't attackers learn to avoid fake assets?"

Sophisticated attackers may eventually develop techniques to identify some
decoys. Zscaler Deception counters this with:
- **Dynamic decoys**: Decoy configurations rotate automatically to avoid
  fingerprinting
- **Authentic emulation**: Decoy services respond identically to the real
  services they impersonate — including version banners, TLS certificates,
  and realistic HTML content
- **Breadcrumb diversity**: Lures use different credential formats, file types,
  and storage locations per endpoint — no two endpoints look the same

### "How does Deception fit with our existing EDR?"

Deception and EDR complement each other:
- EDR focuses on **what runs on the endpoint** (processes, file changes, memory)
- Deception focuses on **what the attacker does on the network** (lateral movement,
  service probing, credential reuse)
- Deception alerts can be sent to EDR for correlated investigation
- Many customers use Deception alerts to trigger deep EDR forensic collection

### "What if a legitimate admin accidentally hits a decoy?"

This is a policy and process question, not a technology limitation. Best practices:
- Document all decoy IP addresses in your internal IPAM as "DO NOT USE"
- Add decoy IPs to a monitoring exclusion list for automated scanning tools
  (e.g. Qualys, Tenable) — use separate exclusion, not suppression
- The Deception platform tracks which machines generated the alert; a known
  scanner IP can be filtered in the alert policy while still logging the event

### "How long does it take to deploy Deception?"

- **Decoy deployment**: 1–2 days per subnet (Zscaler deploys decoys via the
  Deception Orchestrator; no manual server provisioning required)
- **Lure deployment**: Hours — the Deception agent or GPO-based policy pushes
  tokens to endpoints automatically
- **SOAR integration**: 1–2 days for the initial playbook configuration
- **Full production coverage**: 1–2 weeks for a medium-sized enterprise

### "Is Deception only for detecting external attackers?"

No — Deception is equally effective against:
- **Malicious insiders**: An employee snooping in areas they should not be
  in will trigger the same high-confidence alert
- **Supply-chain compromises**: A vendor's machine that has been compromised
  will touch a decoy when it begins lateral movement
- **Automated malware**: Ransomware that performs file share enumeration will
  touch decoy shares before reaching real shares, triggering an alert and
  allowing isolation before encryption begins

---

## Post-Demo Next Steps

1. Share the [Zscaler Deception Data Sheet](https://www.zscaler.com/resources/data-sheets/zscaler-deception.pdf).
2. Offer a **Proof of Value (PoV)** — Deception can be deployed alongside the
   customer's existing infrastructure with no network changes; it is read-only
   from the network's perspective.
3. Map the customer's **highest-risk subnets** (e.g. finance, R&D, OT/IoT) to
   specific decoy coverage recommendations.
4. Show how Deception + ZPA together create a **detection-and-prevention** layer:
   - ZPA prevents lateral movement between authorised segments
   - Deception detects any movement attempt that ZPA doesn't block
5. Discuss **SOAR integration** with the customer's existing Splunk SOAR,
   Microsoft Sentinel, Palo Alto XSOAR, or Rapid7 InsightConnect deployment.
6. Explore **OT/IoT use cases** — Deception deploys fake PLCs, SCADA HMIs, and
   IP cameras for customers with operational technology environments.
