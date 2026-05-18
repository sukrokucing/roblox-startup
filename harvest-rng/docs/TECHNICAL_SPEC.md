# Harvest RNG — Technical Specification

**Version:** 1.0  
**Engine:** Roblox (Luau, `--!strict` mode throughout)  
**Target Roblox API surface:** 2024 stable  

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Folder & Service Structure](#2-folder--service-structure)
3. [Client–Server Split](#3-clientserver-split)
4. [Module Dependency Graph](#4-module-dependency-graph)
5. [DataStore Schema](#5-datastore-schema)
6. [Remote Events Reference](#6-remote-events-reference)
7. [State Machine: Plot Lifecycle](#7-state-machine-plot-lifecycle)
8. [Performance Targets](#8-performance-targets)
9. [Security Model](#9-security-model)
10. [Error Handling Strategy](#10-error-handling-strategy)
11. [Testing Conventions](#11-testing-conventions)
12. [Studio Setup Guide](#12-studio-setup-guide)

---

## 1. Architecture Overview

Harvest RNG follows the standard Roblox authoritative-server model:

```
┌─────────────────────────────────────────────────────────────┐
│  SERVER (Script, runs once)                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ GameManager  │  │ DataManager  │  │  RNGManager  │      │
│  │ .server.lua  │─►│    .lua      │  │    .lua      │      │
│  └──────┬───────┘  └──────────────┘  └──────────────┘      │
│         │          ┌──────────────┐                         │
│         └─────────►│ FarmManager  │                         │
│                    │    .lua      │                         │
│                    └──────────────┘                         │
└─────────────────────────────┬───────────────────────────────┘
                              │  RemoteEvents / RemoteFunctions
                              │  (all validated server-side)
┌─────────────────────────────▼───────────────────────────────┐
│  CLIENT (LocalScript, per player)                           │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │  MainClient  │  │  UIManager   │                         │
│  │ .client.lua  │─►│    .lua      │                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│  SHARED (ReplicatedStorage, both sides)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  SeedData    │  │ RemoteEvents │  │   Config     │      │
│  │    .lua      │  │    .lua      │  │    .lua      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Key principle:** The server is the single source of truth for all game state. Clients send intent (RequestRoll, RequestHarvest) and receive computed results. No client-side coin arithmetic is trusted.

---

## 2. Folder & Service Structure

### Roblox Explorer tree

```
game
├── ServerScriptService
│   ├── GameManager                  ← bootstrap Script
│   └── modules
│       ├── DataManager              ← ModuleScript
│       ├── RNGManager               ← ModuleScript
│       └── FarmManager              ← ModuleScript
│
├── ReplicatedStorage
│   ├── Shared
│   │   ├── SeedData                 ← ModuleScript
│   │   ├── RemoteEvents             ← ModuleScript
│   │   └── Config                   ← ModuleScript
│   ├── Events           ← created at runtime by GameManager
│   └── Functions        ← created at runtime by GameManager
│
├── StarterPlayer
│   └── StarterPlayerScripts
│       ├── MainClient               ← LocalScript
│       └── modules
│           ├── UIManager            ← ModuleScript
│           └── InventoryManager     ← ModuleScript
│
└── StarterGui
    └── HarvestRNG_GUI   ← ScreenGui (built in Studio)
        ├── HUD
        ├── RollPanel
        ├── FarmPanel
        ├── InventoryPanel
        ├── UpgradePanel
        ├── LeaderboardPanel
        └── NotificationFrame
```

### Service responsibilities

| Service | Purpose |
|---------|---------|
| `ServerScriptService` | Server scripts (never replicated) |
| `ReplicatedStorage` | Shared modules + runtime remotes folder |
| `StarterPlayerScripts` | Client LocalScripts (cloned per player) |
| `StarterGui` | GUI templates (cloned to PlayerGui) |
| `DataStoreService` | Persistent player data |
| `MarketplaceService` | Gamepass ownership checks |

---

## 3. Client–Server Split

### Server owns:

- All player data (coins, gems, luck, plots, inventory)
- Roll outcomes (RNG is server-only; client never calculates rarity)
- Harvest timing and value calculations
- DataStore reads/writes
- Gamepass validation
- Daily streak logic
- Leaderboard updates

### Client owns:

- UI rendering and animation
- Seed icon rendering: `SeedData.icon` provides Roblox-safe procedural icon metadata, and `UIManager.RenderSeedIcon()` draws crop badges without relying on unsupported emoji glyphs.
- Button input debouncing (visual-only)
- Local plot timer countdown (display only; server re-validates on harvest)
- Sound effects and particles
- Camera / character movement

### Anti-cheat boundaries

Every remote handler on the server:
1. Validates the player has loaded data (`DataManager.IsLoaded`)
2. Validates input types (e.g. plotIndex must be a number, seedId must be a string)
3. Re-runs all business logic (cost checks, cooldown checks) independently of any client-reported state
4. Never trusts client-reported coin balances, timestamps, or rarity outcomes

---

## 4. Module Dependency Graph

```
GameManager.server.lua
    ├── DataManager.lua
    │       └── Config.lua (shared)
    ├── RNGManager.lua
    │       ├── SeedData.lua (shared)
    │       └── Config.lua (shared)
    ├── FarmManager.lua
    │       ├── DataManager.lua
    │       ├── RNGManager.lua
    │       ├── Config.lua (shared)
    │       └── SeedData.lua (shared)
    ├── Config.lua (shared)
    └── RemoteEvents.lua (shared)

MainClient.client.lua
    ├── UIManager.lua
    │       (no sub-dependencies — pure UI)
    ├── SeedData.lua (shared)
    └── RemoteEvents.lua (shared)
```

No circular dependencies. Shared modules have zero requires of their own (pure data tables + utility functions).

---

## 5. DataStore Schema

**DataStore name:** `HarvestRNG_PlayerData_v1`  
**Key format:** `player_{userId}`  
**Leaderboard:** `OrderedDataStore("TotalHarvested_v1")`  
**Display names:** `DataStore("PlayerNames_v1")` — key: `{userId}`, value: `displayName` string; written on every `OnPlayerAdded`, cached in memory, and used by leaderboard rendering

### Player data schema (Luau types)

```lua
type PlotState = {
    seedId      : string?,   -- nil = empty
    plantedAt   : number?,   -- os.time() Unix timestamp
    isUnlocked  : boolean,
}

type PlayerData = {
    -- Economy
    coins           : number,        -- current coin balance
    gems            : number,        -- current gem balance

    -- Stats
    luck            : number,        -- computed = luckLevel × 5
    luckLevel       : number,        -- 0–20
    harvestSpeed    : number,        -- multiplier ≥ 1.0
    harvestSpeedLevel : number,      -- 0–15

    -- Farm
    plots           : {PlotState},   -- array[1..MAX_PLOTS]

    -- Inventory
    inventory       : {[string]: number},  -- seedId → count

    -- Meta
    totalHarvested  : number,        -- lifetime coins (leaderboard)
    dailyStreak     : number,        -- consecutive days
    lastLogin       : number,        -- os.time()
    dataVersion     : number,        -- schema version (currently 1)
}
```

### Data migration strategy

- `dataVersion` increments with breaking schema changes.
- `DataManager.Reconcile()` fills in missing keys with defaults for new fields.
- Old keys are left in place (harmless extra data in DataStore).
- For destructive migrations (field renames), a one-time migration script runs in `GameManager.Init()` guarded by `dataVersion` check.

### DataStore limits & budgets

| Operation | Roblox limit | Our usage |
|-----------|-------------|-----------|
| GetAsync | 60 req/min per key | 1 per player join; 3 retries max |
| SetAsync | 60 req/min per key | Auto-save every 60 s + on remove |
| OrderedDataStore SetAsync | 60 req/min | 1 per player per 5-min leaderboard tick, plus save-on-leave and one guarded save when a player opens the leaderboard |

With 50 concurrent players: ~50 GetAsync on join, ~50 SetAsync/min auto-save. Well within budget.

---

## 6. Remote Events Reference

All remotes live in `ReplicatedStorage/Events` (RemoteEvents) and `ReplicatedStorage/Functions` (RemoteFunctions), created at runtime by `GameManager.server.lua`.

### Client → Server (RemoteEvents)

| Event name | Payload | Server action |
|------------|---------|--------------|
| `RequestRoll` | (none) | Deduct 50 coins, roll 1 seed, add to inventory, fire `RollResult` + `InventoryUpdate` |
| `RequestRollX10` | (none) | Deduct 450 coins, roll 10 seeds, add to inventory, fire `RollResult` + `InventoryUpdate` |
| `RequestPlant` | `plotIndex: number, seedId: string` | Validate ownership, plant seed, fire `InventoryUpdate` + `PlotStateUpdate` |
| `RequestHarvest` | `plotIndex: number` | Validate ready, add coins, clear plot, fire `HarvestResult` + `StatsUpdate` |
| `RequestUnlockPlot` | `plotIndex: number` | Validate cost, unlock, save immediately, fire `StatsUpdate` + `PlotStateUpdate` |
| `RequestUpgradeLuck` | (none) | Validate cost, increment level/stat, fire `UpgradeResult` + `StatsUpdate` |
| `RequestUpgradeHarvestSpeed` | (none) | Validate cost, update multiplier, fire `UpgradeResult` + `StatsUpdate` |
| `RequestClaimStreak` | (none) | Re-run daily streak logic, fire `DailyStreakClaimed` if applicable |
| `RequestInventory` | (none) | Fire `InventoryUpdate` with current inventory |
| `RequestLeaderboard` | (none) | Fetch cached/OrderedDataStore leaderboard, merge online players' current totals, fire `LeaderboardData` |

### Server → Client (RemoteEvents)

| Event name | Payload | Client action |
|------------|---------|--------------|
| `PlayerDataLoaded` | Full stats + inventory snapshot | Initial HUD population |
| `StatsUpdate` | Partial `{coins?, gems?, luck?, ...}` | HUD update |
| `RollResult` | `{RollResult}[]` (1 or 10 items) | Roll reveal animation |
| `PlotStateUpdate` | `{PlotState}[]` (all plots) | Re-render farm panel |
| `HarvestResult` | `{plotIndex, coins, seedName, rarity}` | Floating +coins popup |
| `UpgradeResult` | `{stat, newValue, newLevel}` | Toast notification |
| `DailyStreakClaimed` | `{day, coins, gems}` | Streak banner modal |
| `InventoryUpdate` | `{inventory: {[string]: number}}` | Inventory panel refresh after rolls, plant attempts, or explicit requests |
| `LeaderboardData` | `{rank, name, value}[]` | Leaderboard panel rows; empty array renders a "No harvests yet" row client-side |
| `Notification` | `{message, style?}` | Toast notification |

### Client → Server (RemoteFunctions)

| Function name | Client sends | Server returns |
|---------------|-------------|----------------|
| `GetSeedInfo` | `seedId: string` (max 64 chars, validated) | `SeedDefinition` or `nil` |
| `GetUpgradeCost` | `{stat: string, level: number}` (table validated; level clamped 0–100) | `number` (coin cost, or `0` on invalid input) |
| `HasGamepass` | `passId: number` (must be `> 0`, validated before API call) | `boolean` |

---

## 7. State Machine: Plot Lifecycle

```
         UnlockPlot(coins)
LOCKED ──────────────────────► EMPTY
                                  │
                          PlantSeed(seedId)
                                  │
                                  ▼
                               GROWING
                            (countdown running)
                                  │
                     elapsed ≥ harvestTime / harvestSpeed
                                  │
                                  ▼
                               READY ──► Harvest() ──► EMPTY
                                         (coins added)
```

**Invariants:**
- A plot cannot transition from LOCKED to GROWING directly.
- A plot cannot be planted while GROWING (must harvest first).
- Harvest is a no-op if the plot is EMPTY or LOCKED.
- `plantedAt` is always set as `os.time()` on the server (never client timestamp).
- Plot unlock purchases call `DataManager.Save()` immediately after success so expansion progress survives short Studio sessions.
- `PlotStateUpdate` drives both the ScreenGui plot grid and local 3D plot visuals under `Workspace.HarvestRNG_World.WorldPlots_5x5`, including unlock markers and centered planted crop billboards. Planted seed icons are rendered from `SeedData.icon` metadata rather than raw emoji text.

---

## 8. Performance Targets

| Metric | Target | Method |
|--------|--------|--------|
| Server FPS | ≥ 55 FPS at 50 players | Profile in Play Solo; avoid per-frame loops |
| DataStore saves | ≤ 1 save/60 s per player | Auto-save interval in Config |
| Remote event volume | ≤ 5 events/s per player | Client debounce on buttons |
| Client FPS | ≥ 50 FPS on mid-range device | Minimal part count; no high-poly meshes |
| Memory (client) | ≤ 200 MB | No large textures in local modules |
| Plot timer accuracy | ±1 s visual drift | Client-side countdown, server re-validates on harvest |
| Initial load time | ≤ 3 s to first frame | Lazy-load inventory panel; show HUD immediately after `PlayerDataLoaded` |

### Auto-Farm loop cost

With 50 players owning Auto-Farm pass: 50 × 1 server-side harvest check every 3 seconds = ~17 checks/second. Each check is O(plots) with early-exit if not ready. At 25 plots max, worst case ≈ 425 table reads/second. Negligible.

---

## 9. Security Model

### Remote validation checklist

Every `OnServerEvent` handler:

- [ ] Player must exist and data must be loaded (`DataManager.IsLoaded`)
- [ ] Input types validated with `type()` checks before use
- [ ] Numeric inputs clamped to valid ranges (e.g. `plotIndex` 1–MAX_PLOTS)
- [ ] All costs re-computed server-side (never trust client payload for amounts)
- [ ] Cooldown check where applicable (no harvesting a just-planted plot)

### What clients cannot spoof

| Client could try to... | Mitigated by... |
|------------------------|----------------|
| Send a fake coin balance | Server reads DataManager cache, not client payload |
| Claim a Mythic rolled itself | Roll happens server-side in RNGManager |
| Harvest a crop before it's ready | Server checks `os.time() - plantedAt ≥ harvestTime` |
| Plant a seed it doesn't own | Server checks `inventory[seedId] > 0` |
| Double-harvest a plot | Plot cleared atomically before coins added |
| Unlock a plot they can't afford | Server checks `coins ≥ cost` |

### DataStore key hygiene

- Keys use `player_{userId}` — no player-controlled strings in keys.
- Leaderboard key is a constant (`TotalHarvested_v1`) — value set by server only.
- `BindToClose` saves all loaded players on server shutdown to prevent data loss.

---

## 10. Error Handling Strategy

### DataStore failures

- 3 retries with exponential backoff (1 s, 2 s, 4 s).
- On total failure of `GetAsync`: serve default data (log warning, do not crash).
- On total failure of `SetAsync`: log warning, keep trying on next auto-save cycle.
- `game:BindToClose` attempts final synchronous save before server exits.

### Remote event failures

- If server handler hits an error, it fires a `Notification` back to the client with a generic "Something went wrong" message.
- Server handlers are wrapped in `pcall` for any DataStore or external API calls.
- Client errors in `OnClientEvent` handlers are caught and logged; UI degrades gracefully.

### Missing GUI elements

- `WaitForChild` with 10 s timeout in `MainClient.client.lua`.
- If GUI timeout fires, client prints an error and skips wiring (partial functionality, not crash).

---

## 11. Testing Conventions

### In-Studio testing

1. Use **Play Solo** (local server + client in one window) for basic flow testing.
2. Use **Start Server + 2 clients** (F5) for multiplayer and DataStore save/load tests.
3. Use `game:GetService("DataStoreService"):GetDataStore("…"):SetAsync(key, nil)` in the command bar to wipe a test save.

### Debug flags (Config.lua)

Add to `Config.lua` for development only (remove before publish):

```lua
Config.DEBUG_INSTANT_HARVEST = false   -- FarmManager.IsReady() returns true immediately
Config.DEBUG_FREE_ROLLS       = false   -- RequestRoll / RequestRollX10 skip coin deduction
Config.DEBUG_LOG_ROLLS        = false   -- RNGManager.RollSeed() prints result to output
```

All three flags are **wired into actual game logic** — setting any to `true` has immediate effect. Set all to `false` before publishing.

### Unit-testable modules

The following modules have no Roblox API dependencies and can be tested with [TestEZ](https://roblox.github.io/testez/):

- `RNGManager.lua` — test weight distribution across 10 000 rolls
- `Config.lua` — validate cost tables are monotonically increasing
- `SeedData.lua` — validate all 30 seeds have required fields

---

## 12. Studio Setup Guide

### Step 1: Import source files

Copy `src/` into the corresponding Roblox service locations (see Section 2).

### Step 2: Create GUI hierarchy

In `StarterGui`, create a `ScreenGui` named `HarvestRNG_GUI` with children:

```
HarvestRNG_GUI (ScreenGui, ResetOnSpawn = false)
├── HUD (Frame, top anchor; compact touch layout is applied by MainClient)
│   ├── CoinsLabel    (TextLabel)
│   ├── GemsLabel     (TextLabel)
│   ├── LuckLabel     (TextLabel)
│   ├── StreakLabel   (TextLabel)
│   ├── InventoryButton (TextButton)
│   ├── LeaderboardButton (TextButton)
│   └── UpgradeButton (TextButton)
├── RollPanel (Frame)
│   ├── RollButton    (TextButton, "🎲 Roll (50 coins)")
│   ├── RollX10Button (TextButton, "🎰 Roll ×10 (450 coins)")
│   └── ResultFrame   (Frame, Visible=true)
│       ├── SeedEmoji  (TextLabel)
│       ├── SeedName   (TextLabel)
│       └── RarityLabel (TextLabel)
├── FarmPanel (Frame, compact right-docked panel)
│   ├── ToggleFarmButton (TextButton, defaults to "Show"; switches to "Hide" when expanded)
│   └── PlotContainer (ScrollingFrame, UIGridLayout inside; hidden by default while the panel is collapsed)
├── InventoryPanel (Frame, Visible=false)
│   ├── CloseBtn (TextButton)
│   └── ScrollFrame (ScrollingFrame; rendered with seed rows from `InventoryUpdate`)
├── UpgradePanel (Frame, Visible=false)
│   ├── LuckUpgradeButton   (TextButton)
│   ├── SpeedUpgradeButton  (TextButton)
│   └── CloseBtn (TextButton)
├── LeaderboardPanel (Frame, Visible=false)
│   ├── CloseBtn (TextButton)
│   └── ScrollFrame (ScrollingFrame)
└── NotificationFrame (Frame, Visible=false, anchored bottom-center)
    └── NotifLabel (TextLabel)
```

`MainClient.client.lua` re-applies responsive layout when `HarvestRNG_GUI.AbsoluteSize` changes. Touch/small viewports use abbreviated HUD stats, smaller roll/farm panels, and centered modal panels so phone landscape does not overflow or cover core gameplay controls.

### Step 3: Fill in Gamepass IDs

In `Config.lua`, replace the `0` values in `GAMEPASS_IDS` with your actual Roblox gamepass IDs after creating them on the Creator Hub.

### Step 4: Configure DataStore API access

In **Game Settings → Security**, enable **Enable Studio Access to API Services** for local DataStore testing.

### Step 5: Test checklist

- [ ] Player joins → data loads, HUD populates
- [ ] Roll button → deducts 50 coins, seed added to inventory
- [ ] Plant → plot shows a procedural seed icon and countdown timer
- [ ] Wait for harvest (or use DEBUG_INSTANT_HARVEST) → harvest button appears
- [ ] Harvest → coins added, plot clears
- [ ] Upgrade Luck → level increments, stat updates in HUD
- [ ] Leave game → re-join → coins/plots persist
- [ ] Daily streak → claimed on join, banner shows
