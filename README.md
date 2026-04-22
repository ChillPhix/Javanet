# JAVANET
### Modular Cybersecurity Framework for ComputerCraft: Tweaked

---

## What Is Javanet?

Javanet is a complete cybersecurity gameplay system for Minecraft servers running ComputerCraft: Tweaked. It gives you everything you need to build secure facilities, hack into them, and defend against attacks — all through in-game computers and monitors.

There are no hardcoded terminal types. Instead, you build custom terminals by snapping together **modules** using a visual builder called the **Customizer**. Want a door that also detects intrusions and has a panic button? Pick those three modules and deploy. Up to 8 modules per terminal.

## Quick Start

### 1. Install the Mainframe
Pick one computer to be your network's brain. Run:
```
wget run https://your-server/javanet/install.lua
```
Select **"Mainframe"** when prompted. Complete the first-boot wizard to set your faction name, colors, clearance tiers, and zones.

### 2. Build Terminals
On any other computer, run the installer and select **"Terminal"**. This launches the **Customizer** — a visual builder where you:
- Pick modules from 3 domains (Network, Offense, Defense)
- See a live preview on an attached monitor
- Tweak your faction theme and boot animation
- Save and deploy

### 3. Play
That's it. Terminals auto-connect to the mainframe on boot.

---

## The Three Domains

### Network (26 modules)
Facility operations — doors, card readers, zone management, personnel tracking, mail, archive browsing, admin controls, and more.

### Offense (11 modules)
Hacking tools — network scanner, puzzle-based cracker, packet interceptor, card spoofer, payload deployer (lockout/worm/backdoor/agent), worm commander, signal jammer, and more.

### Defense (10 modules)
Protection systems — firewall, intrusion detection, deep scan, tracer, counter-hack, antivirus, integrity checking, honeypots, quarantine, and a sentinel dashboard.

---

## Puzzle-Based Hacking

Hacking isn't instant — you solve timed puzzles to crack systems:

| Tier | Puzzle | Time | Attempts |
|------|--------|------|----------|
| T1 | Pattern Match | 15-30s | 5 |
| T2 | Port Sequence | 30-60s | 3 |
| T3 | Signal Router | 1-3min | 3 |
| T4 | Cipher Crack | 3-5min | 2 |
| T5 | System Siege (T2→T3→T4 chain) | 5-10min | 1 |

Failed attempts trigger escalating cooldowns (30s → 60s → 120s, capping at 600s).

---

## Key Features

- **Fully custom clearance** — 2 to 10 tiers, name them whatever you want
- **Faction theming** — 16-color palette, ASCII logo from `/.jnet_logo.txt`, role-based border styles
- **6 boot animations** — Military, Hacker, Corporate, Glitch, Stealth, Retro
- **Multi-monitor support** — auto-layout across 1-8+ attached monitors
- **Config portability** — save terminal configs to floppy disk, carry between computers
- **Server-wide archive** — store and browse documents across the network
- **Internal mail** — send messages between personnel
- **Optional GPU acceleration** — enhanced visuals with DirectGPU when available
- **Worms spread on same network only** — keeps gameplay contained
- **Passive + Active defense** — firewalls auto-block, defenders solve counter-puzzles

---

## File Structure

```
/jnet/
├── lib/           -- 8 core libraries (protocol, UI, animation, config, etc.)
├── modules/
│   ├── network/   -- 26 facility operation modules
│   ├── offense/   -- 11 hacking modules
│   └── defense/   -- 10 protection modules
├── mainframe/     -- Central server + database
├── payloads/      -- Lockout, worm, backdoor, agent
├── customizer/    -- Visual terminal builder
├── runtime/       -- Universal terminal engine
└── docs/          -- Defender & Attacker guides
```

---

## Guides

Two in-character guides are included in `docs/`:

- **NOVA_DEFENDER_GUIDE.txt** — NOVA faction handbook for facility defenders. Covers every defense module, threat types, emergency procedures, recommended builds, and 10 secrets attackers don't want you to know.

- **BLIND_EYE_ATTACKER_GUIDE.txt** — Blind Eye field manual for hackers. Covers the full attack toolkit, a 5-phase attack playbook, puzzle tips for every tier, recommended loadouts, and 10 secrets defenders don't want you to know.

---

## Requirements

- Minecraft with ComputerCraft: Tweaked
- One computer designated as mainframe
- Modem network (wired or wireless) connecting all terminals
- Optional: monitors, speakers, floppy drives, Advanced Peripherals playerDetector

---

## Credits

Built for the San Andreas Communications Department (SACD) gaming community.
Framework designed to support any faction — CTN, NOVA, Blind Eye, or your own.
