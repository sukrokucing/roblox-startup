# 🌾 Harvest RNG

> Roll random seeds. Plant. Grow. Harvest. Flex your luck.

**Harvest RNG** is a Roblox idle/incremental farming simulator built around gacha RNG mechanics. Players roll seeds from a pool of 30 varieties across six rarity tiers — Common through Mythic — then plant, grow, and harvest them for coins to roll again. The higher your Luck stat, the better your odds. Think *Pet Simulator X* meets *Stardew Valley* meets a slot machine.

---

## 🎮 Core Loop

```
COINS → ROLL (RNG) → SEED → PLANT PLOT → WAIT → HARVEST → COINS
  ↑_____________________________________________|
```

1. **Roll** — Spend 50 coins for a random seed. Rarity is luck-weighted.
2. **Plant** — Place the seed on an unlocked farm plot.
3. **Wait** — The crop grows in real time (seconds to hours depending on rarity).
4. **Harvest** — Collect coins based on seed rarity × value multiplier × luck bonus.
5. **Reinvest** — Buy more rolls, unlock plots, upgrade Luck/Speed stats.

---

## 📁 Project Structure

```
harvest-rng/
├── README.md                          ← You are here
├── default.project.json                ← Rojo 7 project mapping
├── rokit.toml                          ← Rokit tool manifest (pins Rojo)
├── docs/
│   ├── GDD.md                         ← Full Game Design Document
│   ├── TECHNICAL_SPEC.md              ← Architecture & data schema
│   ├── PLAY_GUIDE.md                  ← Setup and gameplay guide
│   └── NEW_PLAYER_WALKTHROUGH.md      ← First-session player walkthrough
└── src/
    ├── server/
    │   ├── GameManager.server.lua     ← Server bootstrap + remote handlers
    │   └── modules/
    │       ├── DataManager.lua        ← DataStore load/save/cache
    │       ├── RNGManager.lua         ← Seed rolling engine
    │       └── FarmManager.lua        ← Plot plant/harvest/unlock logic
    ├── client/
    │   ├── MainClient.client.lua      ← Client entry point + UI wiring
    │   └── modules/
    │       ├── UIManager.lua          ← All UI updates and animations
    │       └── InventoryManager.lua   ← Client-side inventory display and management
    ├── shared/
    │   ├── SeedData.lua               ← 30 seed definitions (both sides)
    │   ├── RemoteEvents.lua           ← Remote event name constants
    │   └── Config.lua                 ← All game constants
    └── studio/
        └── BuildGUI.lua               ← Studio command-bar GUI builder
```

### Roblox service placement

| File | Roblox service |
|------|---------------|
| `src/server/GameManager.server.lua` | `ServerScriptService/GameManager` |
| `src/server/modules/*.lua` | `ServerScriptService/modules/` |
| `src/client/MainClient.client.lua` | `StarterPlayerScripts/MainClient` |
| `src/client/modules/UIManager.lua` | `StarterPlayerScripts/modules/UIManager` |
| `src/client/modules/InventoryManager.lua` | `StarterPlayerScripts/modules/InventoryManager` |
| `src/shared/*.lua` | `ReplicatedStorage/Shared/` |

---

## 🚀 Setup Instructions

### Prerequisites

- [Roblox Studio](https://www.roblox.com/create) (latest version)
- A Roblox account with Creator Hub access
- (Optional) [Rokit](https://github.com/rojo-rbx/rokit) + [Rojo](https://rojo.space/) 7.x for file-sync workflow

### Option A — Manual import (Studio only)

1. Open Roblox Studio and create a new **Baseplate** place.
2. In **Game Settings → Security**, enable **Studio Access to API Services** (required for DataStore in Play Solo).
3. Create the folder hierarchy in the Explorer as described in `docs/TECHNICAL_SPEC.md § 12`.
4. Copy each Lua file's content into a new `Script` / `LocalScript` / `ModuleScript` in the correct location.
5. Build the `HarvestRNG_GUI` ScreenGui in StarterGui following the hierarchy in `TECHNICAL_SPEC.md § 12`.
6. Fill in your Gamepass IDs in `src/shared/Config.lua` → `GAMEPASS_IDS`.
7. Press **Play** (F5) to test.

### Option B — Rojo sync (recommended for teams)

1. Install Rokit if it is not already available:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
2. Open a new terminal so `rokit` is available on your PATH.
3. Install the project-pinned Rojo tool:
   ```bash
   cd harvest-rng
   rokit trust rojo-rbx/rojo
   rokit install
   ```
4. Install or update the Studio plugin: `rojo plugin install`.
5. Run `rojo serve default.project.json` from the `harvest-rng/` directory.
6. In Studio, open the Rojo plugin and click **Connect**.

The repo pins Rojo in `rokit.toml`, so `rokit install` is the repeatable setup command. If you prefer another installer, Rojo also publishes GitHub release binaries and supports `cargo install rojo --version ^7`. Avoid `npm install -g rojo`; the npm wrapper is deprecated.

#### Example `default.project.json`

```json
{
  "name": "HarvestRNG",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "GameManager": {
        "$path": "src/server/GameManager.server.lua"
      },
      "modules": {
        "$className": "Folder",
        "DataManager": { "$path": "src/server/modules/DataManager.lua" },
        "RNGManager": { "$path": "src/server/modules/RNGManager.lua" },
        "FarmManager": { "$path": "src/server/modules/FarmManager.lua" }
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": {
        "$className": "Folder",
        "Config": { "$path": "src/shared/Config.lua" },
        "RemoteEvents": { "$path": "src/shared/RemoteEvents.lua" },
        "SeedData": { "$path": "src/shared/SeedData.lua" }
      }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "MainClient": {
          "$path": "src/client/MainClient.client.lua"
        },
        "modules": {
          "$className": "Folder",
          "UIManager": { "$path": "src/client/modules/UIManager.lua" },
          "InventoryManager": { "$path": "src/client/modules/InventoryManager.lua" }
        }
      }
    }
  }
}
```

---

## 🔑 Key Systems

### RNG Engine (`RNGManager.lua`)

Seed rolls use a weighted random algorithm. Base weights:

| Rarity | Chance |
|--------|--------|
| Common | 55 % |
| Uncommon | 25 % |
| Rare | 12 % |
| Epic | 5 % |
| Legendary | 2.5 % |
| Mythic | 0.5 % |

Each point of Luck shifts `0.08 %` weight from Common toward rarer tiers. Max luck (100) roughly doubles Mythic chance to ~0.9 %.

### DataStore (`DataManager.lua`)

- Auto-saves every 60 seconds for all dirty player sessions.
- `GetAsync` / `SetAsync` each retry 3 times with exponential backoff.
- `game:BindToClose` saves all loaded players before server shutdown.
- Schema migrations handled by `Reconcile()` — missing fields get defaults.
- `PlayerNames_v1` DataStore caches `userId → displayName` on every join for leaderboard name resolution.

### Farm System (`FarmManager.lua`)

- Plot states: `LOCKED → EMPTY → GROWING → READY → EMPTY`
- Harvest timing: `seed.harvestTime × rarityModifier ÷ harvestSpeedMultiplier`
- Harvest value: `seed.baseValue × rarityMultiplier × (1 + luck/200)`
- All validation runs server-side — clients cannot fake harvest readiness.

### Monetization

| Pass | Robux | Benefit |
|------|-------|---------|
| Lucky Roll x10 | 199 | Unlocks 10-roll bundle (10 % cheaper) + shows odds |
| Auto-Farm | 399 | Server auto-harvests every 3 s; works offline (6 h cap) |
| VIP Plot | 299 | +5 extra plot slots + +15 Luck + golden plot border |

---

## 🛠 Coding Conventions

### Language

- All Lua files use `--!strict` at the top. No exceptions.
- Use explicit type annotations on function parameters and return types.
- Prefer `type` aliases for complex data shapes (see `DataManager.lua`).

### Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| Modules | PascalCase | `DataManager` |
| Functions | PascalCase | `RollSeed()` |
| Local variables | camelCase | `luckBonus` |
| Constants | SCREAMING_SNAKE | `MAX_PLOTS` |
| RemoteEvent names | PascalCase | `"RequestRoll"` |
| Seed IDs | snake_case | `"golden_apple"` |

### Module structure

Every module follows this layout:

```lua
--!strict
-- Module description

local ModuleName = {}

-- Private state (module-local variables)

-- Private helpers (local functions)

-- Public API (ModuleName.FunctionName)

return ModuleName
```

### Error handling

- Use `pcall` for any external API call (DataStore, MarketplaceService).
- Log warnings with `warn("[ModuleName] ...")` for recoverable errors.
- Use `error(...)` / `assert(...)` only for programmer errors (wrong argument types).
- Never `error()` inside a `PlayerAdded` handler — use graceful fallback.

### Remote event security

- Server never trusts client input values. Always re-validate.
- Check `type()` of every remote payload field before use.
- Clamp numeric inputs to valid ranges before business logic.

---

## 🤝 Contribution Guide

### Branching

```
main          ← production; always deployable
dev           ← integration branch; PR target for features
feature/xyz   ← feature branches (from dev)
fix/xyz       ← bug fix branches (from dev or main for hotfixes)
```

### Adding a new seed

1. Open `src/shared/SeedData.lua`.
2. Add a new entry following the `SeedDefinition` type exactly:
   ```lua
   SeedData["my_seed"] = {
       id          = "my_seed",
       name        = "My Seed",
       emoji       = "🌿",
       rarity      = "Rare",         -- must be a valid rarity tier
       baseValue   = 500,
       harvestTime = 240,
       description = "A mysterious seed of unknown origin.",
   }
   ```
3. No server or client code changes needed — the RNG engine picks seeds dynamically from `SeedData.GetByRarity()`.

### Adding a new upgrade tier

1. Add constants to `src/shared/Config.lua` (base cost, scale, max level).
2. Add the upgrade calculation in `GameManager.server.lua` (following the Luck/Speed pattern).
3. Add a `RequestUpgradeXxx` RemoteEvent name to `RemoteEvents.lua`.
4. Wire the server handler in `GameManager.server.lua`.
5. Wire the client button in `MainClient.client.lua`.

### Pull Request checklist

- [ ] `--!strict` passes with no type errors in Studio
- [ ] Tested in Play Solo (single player) and multi-client (2+ players)
- [ ] DataStore save/load verified: leave game, re-join, state persists
- [ ] No new warnings in the Output panel
- [ ] `Config.lua` debug flags are all `false`
- [ ] Gamepass IDs are `0` (dev placeholder, not live IDs)
- [ ] PR description explains *what* changed and *why*

### Code review focus areas

- **Security:** Does any new server handler trust client input without validation?
- **DataStore budget:** Does the change add new DataStore calls per player per minute?
- **Performance:** Are there any new per-frame loops? Any O(n²) operations on the plot list?
- **Type safety:** Are all new functions annotated? No `any` escapes?

---

## 📄 License

This project scaffold is released for educational and personal use. For commercial Roblox publication, ensure all assets, sounds, and GUI elements comply with Roblox's Terms of Service.

---

## 🗺 Roadmap

See `docs/GDD.md § 12` for the full feature roadmap.

| Version | Status | Highlights |
|---------|--------|-----------|
| v1.0 | ✅ Feature complete — QA pass in progress | Core loop, 30 seeds, 3 gamepasses, daily streak |
| v1.1 | 📋 Planned | Seed Dex, developer products, improved animations |
| v1.2 | 📋 Planned | Seasonal events, weekly leaderboard, social flex |
| v2.0 | 💭 Concept | Prestige system, pet companions, player trading |
