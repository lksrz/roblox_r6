# Game Design Document - "Steal & Secure" (R6 x Brainrot)

**Status: MVP Phase - Core mechanics implemented, expanding toward full vision**

## High-Concept (R6 x Brainrot, kids-safe)
- **Pitch:** "Rainbow Siege: Steal the Beat" – tactical 4v4, break through cardboard walls, scan, build barricades, steal "BoomBox/Core" and deliver it to extraction zone
- **Tone:** Colorful, memey, zero violence (foam, confetti, slime)
- **Round Time:** 3 min. BO5 (first to 3). Switch sides every 2 rounds
- **TTK (time-to-tag):** High; players "tagged" with paint → short KO (5s) instead of death

---

## Current Implementation Status

### ✅ IMPLEMENTED (MVP Core)
- **Basic Teams:** Red (Attack) vs Green (Defense) with alternating assignment
- **Objective System:** Bright yellow glowing cube with pickup/carry/drop/steal mechanics
- **Round Management:** 5s prep → 60s gameplay → 4s end → automatic restart
- **Lobby System:** 10-second countdown when 2+ players join
- **Match System:** First team to 3 wins, then new match starts
- **Enhanced HUD:** Score display, timer, team indicators, phase states
- **Win Conditions:** Red delivers to spawn OR time expires (Green wins)

### 🚧 PLANNED (Full Vision)
- **4v4 Team Size:** Currently unlimited players
- **3 Roles:** Breacher, Scout, Builder (currently no role restrictions)
- **6 Gadgets:** Confetti Charge, Mini-drone, Smoke, Barricade, Alarm, Foam Mine
- **Destructible Environment:** Cardboard walls/doors with "soft destruction"
- **Weapons:** Foam pistol, carbine, shotgun, Bubble-Launcher
- **KO System:** 5-second down state instead of respawn
- **Modular Map System:** 4-6 rooms with multiple layouts

---

## MVP Scope (What We're Building Toward)

### Game Mode: Steal & Secure (only mode at launch)
- **Teams:** 4v4 (simple MMR-lite matchmaking)
- **Map:** 1 modular map (4-6 rooms from blocks), 2 layout variants on server start

### Roles (3 types) - "mini-operators"
1. **Breacher** – foam "Confetti Charge" (opens cardboard walls/doors)
2. **Scout** – scanner pinging through walls (short "ping" every 20s)
3. **Builder** – barricades + foam shields (quick cover setup)

*(Defenders choose max 2 Builders; Attackers min 1 Breacher)*

### Gadgets (6 total at launch)
- **Attack:** Confetti Charge, Mini-drone (small range), Confetti Smoke (screen)
- **Defense:** Cardboard Barricade, Alarm-rubber (beeps on passage), Foam Mine (knockback)

### Weapons (foam-based)
- **Pistol, Carbine, Foam Shotgun, Special:** "Bubble-Launcher" (short root)
- *(Stats differ in range/spread; zero realistic violence)*

### Round Objective
- **Attack:** Steal Core from target room and deliver to extraction zone
- **Defense:** Delay/recover. Recovery = put Core back in room or prevent extraction

### Controls/UX
- **Auto-pickup** ammo, light aim assist, large UI buttons

---

## Motivation Loop (ethically "sticky")

### Short Loop
Match → rank points + soft currency → cosmetic/gadget packs

### Medium Loop
Daily/weekly challenges (3 simple goals, e.g. "2 Core extractions")

### Long Loop
Seasonal ranking (Bronze → Silver → Gold → Diamond – visual only + light MMR)

### Collectibles
Gadget Cards (frames, stickers, paint trails); Weapon "Mastery" (levels 1-10)

### Economy Safety
No "pay-to-win": paid items only skins, animations, emblems

---

## Economy (simple, transparent)

| Currency | Source | Spending | Balance |
|----------|--------|----------|---------|
| Tickets (soft) | matches, challenges | cosmetic packs, gadget reskins | main progress |
| Robux (hard) | purchase | mini-pass, premium cosmetic packs | cosmetics only |

- **No RNG boxes:** always show 3 possible drops before purchase ("pick 1 of 3")
- **Battle-mini:** free path + premium (short, 10 levels)
- **Sinks:** reroll challenges, profile/rank customization

---

## Core Mechanics (like R6, but light)

### Soft Destruction
Only marked walls/windows (from blocks) → states: full / hole / broken

### Information & Counter-info
Scout ping, Alarms for defenders

### Space Control
Builder barricades and shields; Breacher unlocks paths

### Core Extraction
When carrying – visible "trail" (counterplay!), slower movement

---

## Map & Assets (low-asset pipeline)

### Tileset blocks
Walls, doors, windows, floors – 1 style + 3 color palettes

### Core/Boombox prop
1 style, 3 skins (common/rare/legend)

### Decals + UI > models
Memey stickers, banners, confetti VFX, outlines

### Modularity
6 rooms (A-F) connected randomly: 2 layout generations on server start

### Destruction markers
Sprites/mesh-chunks instead of complex fracture

---

## UX & Accessibility (for kids)

### No blood/screaming
Sounds – funny "plop", "poof"

### Readability
Thick team outlines, colorful paths, waypoints

### FTUE (90s onboarding)
Interactive "press X to place barricade", "use scanner"

---

## Ranking & Matchmaking

### MMR-lite
Hidden rating (Glicko-lite), public visual ranks

### Matchmaking
Weight: wins > statistics; priority: ping/region

### Anti-smurf
Quick promotion with high WR at low ranks

---

## Progression System (details)

### Ranks
Bronze (0-999), Silver (1000-1999), Gold (2000-2799), Diamond (2800+)

### Weapon Mastery
XP for hits/extractions; thresholds 1-10 unlock stickers and shot effects

### Gadgets
Each has 3 modes (e.g. Charge: faster/bigger hole/lower noise) – modes are cosmetic or QoL only (different effect, NOT stats)

---

## Live-ops (ethical retention)

### Daily Streak (max 7)
Tickets + random sticker

### Weekend Event
Double Tickets for extractions

### Skin Rotation
2-3 items weekly, clearly announced (no FOMO panic)

---

## Technical Architecture (Roblox Studio / Luau)

### Server
Round logic, MMR-lite, destruction, Core battle

### Client
Animations, VFX, UI, movement prediction

### DataStoreService
Ranks, inventory, streak. Backup + schema validation

### RemoteEvents/Functions
Minimal payload; anti-cheat validation (server-side cooldowns)

### Hit-reg
Server raycast with client confirmation (anti-lag compromise)

### Destruction
List of "breakable parts" with HP; change to predefined mesh variants

### Map loader
Map seed → repeatable room layout (easy A/B)

---

## Analytics/KPI (measure for real)

### Metrics
D1/D7/D30, Avg Match Length, Round Win Delta (attack/def), Core Carry%, Abandon%, Conversion (Robux), % kids completing FTUE tutorial

### Telemetry Events
Wall destruction, scout ping, barricades used, pack drops

---

## Anti-toxic & Safety

### Quick-chat predefined
(bravo, need barricade, watch out drone)

### Chat filter, mute all, quick report (1 click UI)

### AFK-kick gentle
Warning → ghost spectator

---

## Development Roadmap (post-MVP)

1. **New modular map #2** (school/meme museum theme)
2. **New role "Trickster"** (fake barricades / mannequins)
3. **"Quick Heist 3v3" mode** (1 round, 90s, for mobile)
4. **Clubs** (mini-clans): banners, badges, leaderboards
5. **Ranked mode** (seasonal): soft rank reset, seasonal rewards (flair, skins)

---

## Production – Minimal Asset Cost

### 3D Models
1 Core/Boombox, 3 base weapons, 6 low-poly gadgets

### Tileset
20-30 blocks (wall/window/door/floor/stairs)

### UI
30 icons (vector), 10 starter stickers

### VFX
Confetti, smoke, ping, Core trail (materials + particles)

---

## Balance – Starting Parameters (for testing)

- **Round:** 180s
- **Extraction:** 6s standing in zone; drop on KO
- **Confetti Charge:** 2 per round, 2s placement time, door/window radius
- **Scout Ping:** every 20s, 1.2s delay, 1.5s outline on enemy
- **Barricade:** 4 per player, HP: 2 shotgun hits / 5 carbine hits
- **Bubble-Launcher:** 15s cooldown, 1.2s root (doesn't work through walls)
- **Respawn:** none; 10s revival only in "Quick Heist" (later)

---

## Testing & Risks

### Risks
- **Too hard tactical communication for kids** → quick-chat + contextual pings
- **Destruction too performance-expensive** → predefined states, minimal rigidbody
- **"Pay-to-win" perception** → hard cosmetic-only monetization

### A/B Tests (short)
- **TTK:** high vs medium; ping 1.2s vs 2.0s; charge 2 vs 3
- **Map:** narrow vs medium corridors; number of breakables per room

---

## Why This Will Work (mechanism)

### Familiar R6 pattern
Clear roles and decisions (enter / scan / reinforce)

### Brainrot appeal
Clear, funny theft objective (strong narrative moment on extraction)

### Short round + BO5
"Just one more" effect (slot-machine without gambling)

### Visual progress
Ranks, mastery, stickers → natural collectible goals

### Low content cost
Thanks to modularity and UI-driven cosmetics

---

## Recommendations (clear)

1. **Build MVP exactly as above:** 1 modular map, 3 roles, 6 gadgets, 3 weapons, 1 mode
2. **Focus on:** rank loop + daily challenges + mastery (zero P2W)

**Applicability conditions:** target mobile + PC; team has limited 3D pipeline; goal – quick retention test

---

## Next Step (concrete)

### Greybox map + prototype gadgets
Charge, ping, barricade + round telemetry

### Internal test
Does Attack/Defense have ~50/50 WR; is extraction clear and exciting

---

## Current Development Status

**✅ COMPLETED:**
- Basic objective delivery system (simplified version)
- Team assignment and lobby management
- Round structure with timer
- Enhanced HUD system
- Auto-restart match system

**🚧 IN PROGRESS:**
- Converting from simplified to full vision
- Adding role restrictions and gadget system
- Implementing destruction mechanics
- Building modular map system

**📋 TODO:**
- 4v4 team size limits
- Role-based gameplay (Breacher/Scout/Builder)
- Gadget implementation (6 types)
- Soft destruction system
- KO system instead of respawn
- MMR and progression systems
- Mobile optimization

---

**The goal is to evolve from the current working MVP into the full "Steal & Secure" vision outlined above, maintaining the core fun while adding tactical depth through roles, gadgets, and environmental destruction.**