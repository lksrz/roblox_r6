ReplicatedStorage/Assets
========================

Place the Briefcase asset here so Rojo syncs it to `ReplicatedStorage/Assets/Briefcase` in Studio.

Supported formats
- `.rbxmx` or `.rbxm` files exported from Roblox Studio
- Rojo `.model.json` files

Naming
- Name the file/folder `Briefcase.rbxmx` (or a folder `Briefcase.model.json`).
- In Studio, it will appear as a child named `Briefcase` under `ReplicatedStorage/Assets`.

Notes
- The game will first look for `ReplicatedStorage/Assets/Briefcase` (Model or Tool) and use it.
- If not present, it tries `ServerStorage/Assets/Briefcase`.
- If neither exist, it attempts `InsertService:LoadAsset(530795465)` (may fail if third‑party assets are blocked).
- If all else fails, the fallback neon cube is used.
