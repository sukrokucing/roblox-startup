# Harvest RNG — Project Context for RoboLuau

## Project

Harvest RNG is a Roblox simulator — players roll seeds, plant them on farm plots, harvest for coins, and upgrade stats. Server-authoritative economy with DataStore persistence.

## Repository

- GitHub: `sukrokucing/roblox-startup`
- Main branch: `main`
- Push directly to main after review

## Source Layout

```
harvest-rng/
├── src/
│   ├── server/
│   │   ├── GameManager.server.lua      ← All remote handlers, OnPlayerAdded, streak, leaderboard
│   │   └── modules/
│   │       ├── DataManager.lua         ← DataStore CRUD, cache, dirty tracking, auto-save
│   │       ├── FarmManager.lua         ← Plot planting/harvesting/unlocking, AutoHarvest
│   │       └── RNGManager.lua          ← BuildWeights, RollSeed, CalcHarvestTime/Value
│   ├── client/
│   │   ├── MainClient.client.lua       ← Client bootstrap, connects remotes to UI
│   │   └── modules/
│   │       ├── UIManager.lua           ← All ScreenGui updates, Tween animations
│   │       └── InventoryManager.lua    ← Client-side inventory display
│   ├── shared/
│   │   ├── Config.lua                  ← ALL tunables (never hardcode values)
│   │   ├── RemoteEvents.lua            ← Names + FunctionNames tables
│   │   └── SeedData.lua                ← 30 seed definitions with rarity/value/growTime
│   └── studio/
│       └── BuildGUI.lua                ← Studio helper, not shipped
└── docs/
    ├── GDD.md                          ← Game Design Document (source of truth for design)
    ├── TECHNICAL_SPEC.md               ← Architecture decisions and contracts
    ├── PLAY_GUIDE.md                   ← Player-facing documentation
    └── test-reports/                   ← BugByte automated QA reports
```

## Key Patterns

### Remote Handler Template
```lua
-- Rate limit
local now = os.clock()
if (now - (cooldowns[player.UserId] or 0)) < COOLDOWN then return end
cooldowns[player.UserId] = now

-- Load guard
local data = DataManager.GetData(player)
if not data then return end

-- Input validation
if type(arg) ~= "number" then return end
arg = math.clamp(math.floor(arg), MIN, MAX)
if arg ~= arg then return end  -- NaN guard
```

### VIP Luck (never accumulate on rejoin)
```lua
-- CORRECT: always recompute
data.luck = (data.luckLevel * Config.LUCK_PER_UPGRADE) + Config.VIP_LUCK_BONUS
-- WRONG: data.luck += Config.VIP_LUCK_BONUS  ← stacks on every rejoin
```

### DataStore (always pcall)
```lua
local ok, result = pcall(function()
    return store:GetAsync(key)
end)
if not ok then warn("[DataManager] failed:", result) end
```

## Current State

- ✅ All BugByte blockers fixed (B-1 VIP stacking, B-2 roll rate limit)
- ✅ All majors fixed (M-1 through M-5)
- ✅ All minors fixed (N-1 through N-4)
- ✅ Debug flags added to Config (S-3)
- 📋 S-1 (WithData helper), S-2 (vipLuckApplied flag), S-4 (leaderboard names) still open

## Commit Convention

```
fix: short description (closes #N)
feat: short description
refactor: short description
docs: short description
```

## Testing

Use Roblox Studio. For logic-only changes, trace through the code path manually.
DataStore changes require Studio playtesting with a real DataStore.
Debug flags in Config.lua speed up iteration:
- `Config.DEBUG_INSTANT_HARVEST = true` — skip grow timers
- `Config.DEBUG_FREE_ROLLS = true` — roll without spending coins
