Roblox R6 Rojo Project

Overview
- Rojo-driven Roblox team-based game with all content defined by code.
- Server bootstrap creates baseplate, two teams (Red, Green), and spawns in opposite corners.
- Players are alternately assigned to Red/Green on join. Characters use R6.
- Features round-based gameplay with objectives, weapon firing, and hit registration.
- Client UI shows team indicator, HUD with round state, and input controls.

Philosophy
- Keep code modular and as simple as possible (less code is better).
- Comprehensive error handling and input validation for security.
- Memory leak prevention with proper connection management.

Structure
- `default.project.json` — Rojo project mapping.
- `src/ServerScriptService/Setup.server.lua` — Server bootstrap and team assignment.
- `src/ServerScriptService/Round/` — Round management and state handling.
- `src/ServerScriptService/Gameplay/` — Hit registration, objective system.
- `src/ServerScriptService/AntiCheat/` — Rate limiting and security.
- `src/ReplicatedStorage/Shared/` — Configuration and utility modules.
- `src/ReplicatedStorage/Net/` — Centralized remote event management.
- `src/StarterPlayerScripts/` — Client input controls and UI.

Features
- ✅ Centralized configuration system with fallback handling
- ✅ Comprehensive input validation and error handling
- ✅ Memory leak prevention with proper connection management
- ✅ Rate limiting for anti-cheat protection
- ✅ Round-based gameplay with objective system
- ✅ Team-based spawning with balanced assignment
- ✅ Weapon firing with hit registration
- ✅ Client-side input controls with validation

Usage
1) Install Rojo (CLI) and the Rojo Studio plugin.
2) From this folder, run:
   - `rojo serve default.project.json`
3) In Roblox Studio, open a new place and connect to the Rojo server via the plugin.
4) Press Play. The server will:
   - Force R6 characters.
   - Create a **100x100 baseplate** at the origin (smaller for easier testing).
   - Create Teams `Red` and `Green` (not auto-assignable).
   - Place `RedSpawn` and `GreenSpawn` at opposite corners.
   - Assign each joining player to alternating teams.
   - Spawn **bright yellow objective** 30 units from green team (close for testing).
   - Start 60-second rounds where red team must capture objective.
   - Display team indicator, round state, and timer on client.

Configuration (Testing Mode)
- **Baseplate**: 100x100 (smaller for easy testing)
- **Spawn Distance**: 30 units apart (close for quick testing)
- **Objective**: Bright yellow neon 3x3x3 cube with multiple visual effects:
  - Point light glow (brightness: 3, range: 25)
  - Surface light (brightness: 5, range: 15)
  - Pulsing transparency animation
  - Yellow particle effects
  - Beam effects for extra visibility
- **Time Limit**: 60 seconds per round
- **Teams**: Red vs Green with alternating assignment
- **Win Condition**: Red team carries objective to red spawn

Testing the Objective System
1. Join with 3 players (automatic assignment: Red, Green, Red)
2. Wait for round to start (5-second prep phase)
3. Look for the **bright yellow neon cube** with glow, particles, and pulsing effects
4. **Red team players**: Pick up the objective and carry it to red spawn
5. **Green team players**: Try to prevent red team from delivering
6. Watch the **60-second countdown** - red team must deliver before time runs out
7. Check console for detailed logs showing team assignments and objective positions

**Visibility Features:**
- Bright yellow neon material
- Point light glow effect
- Surface light for extra brightness
- Pulsing transparency animation
- Particle effects around the objective
- Beam effects for maximum visibility

Notes
- Spawns are team-only (`Neutral = false`) with no forcefield (`Duration = 0`).
- All remote events are centrally managed through `Events.lua`.
- Comprehensive error handling prevents crashes from invalid inputs.
- Memory leaks are prevented through proper connection cleanup.
