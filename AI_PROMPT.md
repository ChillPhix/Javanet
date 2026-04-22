# JAVANET — AI Technical Reference

This document provides everything an AI assistant needs to understand, modify, extend, or debug the Javanet codebase.

---

## 1. Project Overview

Javanet is a modular cybersecurity gameplay framework for ComputerCraft: Tweaked (CC:T) in Minecraft. It runs on CC:T's Lua 5.2-compatible runtime with the CraftOS API. Key constraint: all code must work within CC:T's sandbox — no native Lua IO, no `require()` (use `dofile()` or `os.loadAPI()`-style patterns), limited to CraftOS peripherals.

**Architecture**: One mainframe server + N terminal clients, all communicating over rednet/modem. Terminals are assembled from snap-together modules (max 8 per terminal) using a visual Customizer. No hardcoded terminal types exist.

---

## 2. File Map & Dependency Graph

### Core Libraries (`lib/`)
All terminals and the mainframe load these. Order matters for dependencies.

| File | Purpose | Key Exports | Depends On |
|------|---------|-------------|------------|
| `jnet_proto.lua` | Network protocol, HMAC-SHA256 signing, message send/receive | `Proto` table: `.init()`, `.send()`, `.receive()`, `.sign()`, `.verify()`, `.stealth_send()`, `.stealth_listen()` | Nothing |
| `jnet_ui.lua` | Themed UI rendering (16-color themes, borders, panels, dialogs) | `UI` table: `.init()`, `.clear()`, `.box()`, `.panel()`, `.text()`, `.button()`, `.list()`, `.dialog()`, `.input()`, `.progress()`, `.color_picker()` | Nothing |
| `jnet_anim.lua` | Boot sequences, transitions, visual effects | `Anim` table: `.boot()`, `.transition()`, `.typewriter()`, `.glitch()`, `.matrix_rain()`, `.lockout_reveal()`, `.screen_capture()`, `.screen_corrupt()` | `jnet_ui` |
| `jnet_config.lua` | Configuration management, setup wizards | `Config` table: `.load()`, `.save()`, `.wizard()`, `.get()`, `.set()`, `.export_floppy()`, `.import_floppy()` | `jnet_ui` |
| `jnet_monitor.lua` | Multi-monitor detection, layout calculation, touch routing | `Monitor` table: `.detect()`, `.layout()`, `.route_touch()`, `.mirror()`, `.get_size_class()` | `jnet_ui` |
| `jnet_gpu.lua` | Optional DirectGPU wrapper with software fallback | `GPU` table: `.init()`, `.available()`, `.setPixel()`, `.line()`, `.rect()`, `.text()`, `.widget()`, `.rgb_to_cc()` | Nothing |
| `jnet_puzzle.lua` | Puzzle engine with 5 registered tiers | `Puzzle` table: `.start()`, `.render()`, `.handle_event()`, `.check_complete()`, `.get_tier()`, `.register()` | `jnet_ui` |
| `jnet_modules.lua` | Module registry, lifecycle management | `Modules` table: `.register()`, `.instantiate()`, `.load_all()`, `.render()`, `.handle_event()`, `.handle_network()`, `.tick()`, `.cleanup()` | Nothing |

### Mainframe (`mainframe/`)
| File | Purpose |
|------|---------|
| `db.lua` | Flat-file database in `/jnet_db/`. Tables: clearance, factions, zones, personnel, disks, terminals, entities, breaches, doors, mail (500 cap), sessions, cooldowns, infections, archive, sirens, logs (5000 cap, rotated). |
| `mainframe.lua` | Central server. First-boot wizard, rednet message dispatch, attack protocol handling, admin commands, dashboard display. |

### Runtime (`runtime/`)
| File | Purpose |
|------|---------|
| `terminal.lua` | Universal terminal engine. Loads config → applies theme → runs boot animation → loads modules → calculates layout → enters event loop (touch/key/rednet/timer routing + tick loop). Crash recovery wraps main in pcall. |

### Customizer (`customizer/`)
| File | Purpose |
|------|---------|
| `customizer.lua` | Visual terminal builder. Steps: faction setup → module catalog (browse by domain, toggle up to 8) → live monitor preview → theme/boot tweaker → save config & deploy. |

### Payloads (`payloads/`)
These get deployed TO target computers by the offense modules.

| File | Purpose | Persistence |
|------|---------|-------------|
| `lockout.lua` | Visual takeover, shows attacker faction branding | Until rebooted |
| `worm.lua` | Self-replicating, hooks `startup.lua`, probes adjacent computers on SAME NETWORK | Persistent across reboot |
| `backdoor.lua` | Hidden remote command access | Persistent, hidden file |
| `agent.lua` | Stealth `os.pullEventRaw` hook, reports card swipes back to attacker | Persistent, hidden |

### Modules (`modules/{network,offense,defense}/`)
See Section 4 for the full module API. Each file exports a table matching the module interface.

---

## 3. Protocol Specification

### Channels
- **JNET protocol** (standard): Rednet messages signed with HMAC-SHA256 using a shared secret generated at install. Message format:
  ```lua
  {
    type = "auth_request",  -- message type string
    data = { ... },         -- payload table
    ts = os.epoch("utc"),   -- timestamp for replay protection
    sig = "hexstring"       -- HMAC of type..serialized_data..ts
  }
  ```
- **JNET_ATK protocol** (attack): Same signing but uses attack-specific message types (scan_probe, crack_attempt, deploy_payload, etc.)
- **Stealth/raw modem**: Direct modem.transmit() without rednet, used by offense interceptor/replayer. No signing — relies on obscurity.

### Key Message Types
**Network**: `auth_request`, `auth_response`, `status_query`, `status_update`, `door_open`, `door_lock`, `lockdown_zone`, `breach_declare`, `breach_end`, `entity_update`, `facility_state`, `mail_send`, `mail_fetch`, `archive_query`, `log_append`, `admin_cmd`, `terminal_register`, `approval_request`, `approval_response`, `siren_trigger`, `radio_broadcast`

**Attack**: `scan_probe`, `scan_response`, `crack_attempt`, `crack_result`, `deploy_payload`, `deploy_ack`, `worm_spread`, `worm_status`, `agent_report`, `agent_cmd`, `backdoor_cmd`, `backdoor_response`

**Defense**: `firewall_block`, `ids_alert`, `trace_start`, `trace_result`, `counter_hack`, `quarantine_node`, `av_scan`, `integrity_alert`

---

## 4. Module API

Every module file returns a table with this interface:

```lua
return {
    -- METADATA (required)
    id = "card_reader",           -- unique string ID
    name = "Card Reader",         -- display name
    domain = "network",           -- "network" | "offense" | "defense"
    description = "...",          -- short description
    min_width = 15,               -- minimum terminal columns needed
    min_height = 5,               -- minimum terminal rows needed
    
    -- LIFECYCLE (all optional)
    init = function(self, config, proto)
        -- Called once at terminal boot. config = terminal config, proto = Proto instance
    end,
    
    render = function(self, win, theme)
        -- Called to draw the module. win = window object, theme = color table
    end,
    
    on_event = function(self, event, ...)
        -- Called for user input events (mouse_click, key, char, etc.)
        -- Return true to consume the event
    end,
    
    on_network = function(self, msg)
        -- Called when a rednet message arrives for this module's domain
    end,
    
    tick = function(self, elapsed)
        -- Called every tick loop iteration (~0.5s). elapsed = seconds since last tick
    end,
    
    cleanup = function(self)
        -- Called on terminal shutdown
    end,
}
```

### Module Registration
Modules self-register in the registry when their file is loaded:
```lua
local Modules = dofile("/jnet/lib/jnet_modules.lua")
Modules.register(module_table)
```

The Customizer reads the registry to build its catalog. The runtime loads only the modules specified in the terminal's config.

---

## 5. Configuration Format

Terminal configs are saved as serialized Lua tables at `/jnet/config/<terminal_id>.cfg`:

```lua
{
    id = "term_abc123",
    faction = {
        name = "NOVA",
        primary = colors.blue,
        secondary = colors.lightBlue,
        accent = colors.cyan,
        bg = colors.black,
        text = colors.white,
        logo_path = "/.jnet_logo.txt",
    },
    boot = {
        preset = "military",    -- military|hacker|corporate|glitch|stealth|retro
        speed = 1.0,
        sound = true,
        transition = "sweep",
        text_style = "typewriter",
    },
    modules = {
        "card_reader",
        "door_lock",
        "ids",
        -- up to 8 total
    },
    clearance_required = 3,     -- minimum tier to use this terminal
    mainframe_id = 42,          -- computer ID of the mainframe
    secret = "hex_shared_secret",
    network_channel = 7700,
}
```

Configs can be exported/imported via floppy disk for portability.

---

## 6. Database Schema

The mainframe database lives at `/jnet_db/` as flat files (one per table, serialized Lua tables).

| Table File | Key Fields | Notes |
|------------|------------|-------|
| `clearance.dat` | `{tiers={[1]="Guest",[2]="Staff",...}, count=N}` | 2-10 custom tiers |
| `factions.dat` | `{[name]={colors, logo, ...}}` | Faction registry |
| `zones.dat` | `{[name]={status, lockdown, occupants}}` | Fully dynamic |
| `personnel.dat` | `{[id]={name, clearance, faction, status, ...}}` | Player records |
| `disks.dat` | `{[disk_id]={owner, clearance, faction, flagged, burned}}` | Card/disk registry |
| `terminals.dat` | `{[id]={computer_id, modules, location, approved}}` | Registered terminals |
| `entities.dat` | `{[id]={name, class, zone, status, ...}}` | SCP-style entities |
| `breaches.dat` | `{[id]={entity, zone, severity, active, ...}}` | Active breaches |
| `doors.dat` | `{[id]={name, zone, computer_id, locked, ...}}` | Door registry |
| `mail.dat` | `{messages={...}}` | 500 message cap, FIFO |
| `sessions.dat` | `{[token]={computer_id, clearance, expires}}` | Active auth sessions |
| `cooldowns.dat` | `{[computer_id]={until, level}}` | Escalating: 30→60→120→...→600s max |
| `infections.dat` | `{[computer_id]={type, payload, timestamp}}` | Worm/backdoor/agent tracking |
| `archive.dat` | `{folders={[name]={docs={...}}}}` | Server-wide document archive |
| `sirens.dat` | `{active, zones, triggered_by}` | Siren state |
| `logs.dat` | `{entries={...}}` | 5000 cap, oldest rotated out |

---

## 7. Puzzle System Details

Puzzles are registered in `jnet_puzzle.lua`. Each tier is a self-contained mini-game:

### T1 — Pattern Match
Player sees a grid of symbols, must click matching pairs before time expires. 15-30s, 5 attempts.

### T2 — Port Sequence
Numbered ports flash in sequence, player must repeat the sequence. Length increases. 30-60s, 3 attempts.

### T3 — Signal Router
Multi-stage: player routes signals through a node graph by toggling connections. Each stage adds complexity. 1-3min, 3 attempts.

### T4 — Cipher Crack
Substitution cipher with frequency hints. Player maps letters to decode a message. 3-5min, 2 attempts.

### T5 — System Siege
Chain of T2 → T3 → T4 with full reset on failure. 5-10min, 1 attempt.

### Integration Points
- `cracker.lua` (offense): Starts puzzle at tier matching target's clearance level
- `counter_hack.lua` (defense): Defender solves same-tier puzzle to counter an attack
- `tracer.lua` (defense): T2 puzzle to trace an attacker
- `card_spoofer.lua` (offense): T2 for burn cards, T3 for forged cards
- `worm_commander.lua` (offense): T1-T2 mini-puzzle per new target for worm spread

---

## 8. Theming System

### Color Theme Structure
```lua
theme = {
    primary = colors.blue,
    secondary = colors.lightBlue,
    accent = colors.cyan,
    bg = colors.black,
    text = colors.white,
    error = colors.red,
    success = colors.green,
    warning = colors.orange,
}
```

### Role-Based Border Styles
- **Network modules**: Clean single-line borders (`─ │ ┌ ┐ └ ┘`)
- **Offense modules**: Angular/sharp borders (`╱ ╲ ▶ ◀ ╳`)
- **Defense modules**: Heavy/fortified borders (`═ ║ ╔ ╗ ╚ ╝`)

The UI library selects border style automatically based on the module's `domain` field.

### Faction Logo
ASCII art loaded from `/.jnet_logo.txt` on the computer. Displayed during boot, on lockout screens, and in the Customizer preview.

---

## 9. Common Modification Patterns

### Adding a New Module
1. Create `modules/{domain}/my_module.lua` following the module API (Section 4)
2. The module self-registers via `Modules.register()` — no other files need editing
3. The Customizer automatically discovers it in the catalog

### Adding a New Puzzle Tier
1. In `jnet_puzzle.lua`, add a new entry to the `puzzles` table with `id`, `name`, `tier`, `time_limit`, `max_attempts`, `generate()`, `render()`, `handle_event()`, `check_complete()`
2. Reference it in cracker.lua or other offense modules by tier number

### Adding a New Payload
1. Create `payloads/my_payload.lua` with `install()`, `run()`, `cleanup()` functions
2. Add it to `payload_deployer.lua`'s payload list
3. Add detection for it in `antivirus.lua` and `integrity_check.lua`

### Adding a New Message Type
1. Define the message structure in your module's `init()` or `on_network()`
2. Add a handler in `mainframe.lua`'s dispatch table
3. Use `Proto.send()` with the new type string — the protocol handles signing automatically

### Changing Cooldown Behavior
Edit `db.lua`'s `apply_cooldown()` function. Current: escalating (30→60→120→240→600s cap). The `cooldowns.dat` table stores per-computer cooldown level.

---

## 10. Important Constraints

1. **CC:T Lua environment**: No `require()`, no native file IO, no coroutine.wrap in older versions. Use `dofile()`, `fs.*`, and `parallel.*`.
2. **Rednet range**: Wireless modems have limited range. Wired modems (networking cable) have unlimited range. Worms spread on SAME NETWORK ONLY.
3. **Terminal cap**: Max 8 modules per terminal. The Customizer enforces this.
4. **Monitor sizes**: CC:T monitors range from 1x1 (7x5 chars) to 8x6 (164x81 chars). The layout engine in `jnet_monitor.lua` handles all sizes.
5. **No external HTTP**: The framework is entirely local — no pastebin or external API calls at runtime. The installer is the only file that uses `wget`.
6. **GPU is optional**: All rendering works without DirectGPU. GPU-enhanced visuals are additive only (`jnet_gpu.lua` provides a fallback for every function).
7. **Persistence**: All state lives in `/jnet_db/` on the mainframe. Terminals are stateless — they fetch everything from the mainframe on boot.
8. **Security model**: HMAC-SHA256 signing prevents message spoofing. Shared secret generated at install. Stealth/raw modem traffic is unsigned and detectable by `deep_scan.lua`.
