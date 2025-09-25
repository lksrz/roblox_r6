# Roblox R6 Objective-Based Game

## Overview
A fast-paced team-based objective game built with Rojo. Red team (Attack) must capture and deliver a glowing objective to their spawn while Green team (Defense) tries to prevent them within a 60-second time limit.

**Game Flow:** Lobby (10s countdown) → Prep (5s) → Live gameplay (60s) → End (4s) → Repeat

### Core Gameplay
- **Red Team (Attack):** Capture the objective and deliver it to Red spawn to score
- **Green Team (Defense):** Prevent Red team from delivering until time expires
- **Match System:** First team to 3 round wins, then automatic new match
- **Lobby System:** Automatic 10-second countdown when 2+ players join

## Project Structure
- `src/ServerScriptService/Setup.server.lua` — Team setup and R6 character enforcement
- `src/ServerScriptService/LobbyManager.lua` — Automatic lobby countdown system
- `src/ServerScriptService/Round/RoundService.lua` — Round management and scoring
- `src/ServerScriptService/Gameplay/ObjectiveService.lua` — Objective spawning, pickup, and delivery
- `src/StarterPlayerScripts/UI/Hud.client.lua` — Enhanced HUD with score display and timer
- `src/StarterPlayerScripts/DisableClassicChat.client.lua` — Chat system fixes
- `default.project.json` — Rojo project configuration
  - Includes a dedicated mapping for `ReplicatedStorage/Assets` from `assets/ReplicatedStorage/Assets`

## Features
- ✅ **Automatic Lobby System:** 10-second countdown when 2+ players join
- ✅ **Team-Based Gameplay:** Red (Attack) vs Green (Defense) with alternating assignment
- ✅ **Objective System:** Glowing yellow objective with pickup, carry, steal, and drop mechanics
- ✅ **Round Management:** 5s prep → 60s gameplay → 4s end screen
- ✅ **Scoring System:** First team to 3 wins, automatic match restart
- ✅ **Enhanced HUD:** Clean UI with team indicators, scores, timer, and phase display
- ✅ **Visual Effects:** Neon objective with particles, glow, and pulsing animation
- ✅ **Win Conditions:** Red team delivers to spawn OR Green team runs out the clock
- ✅ **Memory Management:** Proper cleanup and connection handling

## Getting Started

### Setup
1. Install [Rojo CLI](https://rojo.space/) and the Rojo Studio plugin
2. Clone this repository and navigate to the project folder
3. Run `rojo serve default.project.json`
4. In Roblox Studio, connect to the Rojo server via the plugin
5. Press Play to start testing

### Adding the Briefcase Asset (Rojo‑synced)
- Export your Briefcase model from Studio as `.rbxmx` and place it at `assets/ReplicatedStorage/Assets/Briefcase.rbxmx` (or use a `.model.json` with the name `Briefcase`).
- Rojo will sync it into `ReplicatedStorage/Assets/Briefcase` in Studio.
- The game will automatically use this bundled model and skip InsertService.

### Auto‑fetch referenced assets
- Use `scripts/fetch_assets.sh` to scan the codebase for asset IDs (e.g., `InsertService:LoadAsset(…)`, `ModelAssetId = …`) and download any missing ones into `assets/ReplicatedStorage/Assets`.
- Example:
  - `./scripts/fetch_assets.sh`
- Downloaded files are saved as `<id>.rbxm`. The objective loader now also checks for an asset named with the numeric ID (e.g., `ReplicatedStorage/Assets/530795465`).

### What Happens on Server Start
- **Map Creation:** 100x100 baseplate with Red and Green team spawns in opposite corners
- **Team Setup:** Red (Attack) and Green (Defense) teams with alternating player assignment
- **Character Setup:** Forces R6 character rigs for all players
- **Lobby System:** Shows "Waiting for players..." until 2+ players join

### Gameplay Flow
1. **Lobby Phase:** 10-second countdown when 2+ players are present
2. **Prep Phase (5s):** Bright yellow objective spawns randomly, teams get ready
3. **Live Phase (60s):** Red team tries to capture and deliver objective to Red spawn
4. **End Phase (4s):** Shows round results and updates scores
5. **Repeat:** Automatic match restart until one team reaches 3 wins

## Objective Mechanics

### Visual Design
The objective is a **briefcase model** (asset `530795465`) enhanced with bright yellow neon highlights and multiple visual effects:
- Point light glow (brightness: 3, range: 25)
- Surface light (brightness: 5, range: 15)
- Pulsing transparency animation
- Yellow particle effects
- Beam effects for maximum visibility

### Interaction System
- **Pickup:** Any team can pick up the objective (appears above player's head)
- **Drop:** Current carrier can drop the objective at their current position
- **Steal:** Opposing team can steal from the carrier by interacting
- **Delivery:** Red team wins by bringing objective within 15 units of Red spawn

### Win Conditions
- **Red Team (Attack) Wins:** Successfully deliver objective to Red spawn
- **Green Team (Defense) Wins:** Prevent delivery until 60-second timer expires

## Technical Notes
- **Character System:** Forces R6 character rigs for all players
- **Team Assignment:** Alternating Red/Green assignment on player join
- **Memory Management:** Proper connection cleanup prevents memory leaks
- **Error Handling:** Comprehensive input validation for security
- **Chat System:** Fixes for Roblox Studio chat script conflicts

## Development Philosophy
- Modular code architecture with clear separation of concerns
- Minimal dependencies and simple, readable code
- Comprehensive error handling and input validation
- Performance-optimized with proper cleanup patterns
