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

**Every commit that touches `.lua` files MUST also update docs in the same commit.**
Never commit a code change without updating the relevant docs — see Doc Update Rules below.

## Doc Update Rules (MANDATORY)

After every code change, before committing, check and update ALL of the following:

### README.md (`harvest-rng/README.md`)
Update when code changes affect any of these sections:
| Code changed | README section to update |
|---|---|
| New/removed module | `📁 Project Structure` tree + Roblox service table |
| New/changed remote event | `🔑 Key Systems` — mention in relevant system section |
| New DataStore | `DataStore` system description |
| New gamepass / VIP perk | `Monetization` table |
| New upgrade tier | `Adding a new upgrade tier` guide |
| New seed type | `Adding a new seed` guide |
| Behavior change (costs, timings) | `🔑 Key Systems` relevant section |
| Debug flags added/changed | `Pull Request checklist` |
| New CI/workflow | `Contribution Guide` |
| Version status change | `🗺 Roadmap` table |

### GDD.md (`harvest-rng/docs/GDD.md`)
Update when design changes:
| Code changed | GDD section to update |
|---|---|
| Rarity weights | §4.1 Rarity tiers table |
| Luck formula | §4.2 Luck system |
| Plot costs/count | §5.1 Plot progression |
| Luck upgrade levels/costs | §5.2 Luck upgrades |
| Harvest speed levels/costs | §5.3 Harvest Speed upgrades |
| Economy values (roll cost etc) | §6 Economy Design |
| Gamepass perks | §7.1 Gamepasses |
| Daily streak rewards | §8.1 Daily Login Streak |
| New feature added | §12 Feature Roadmap |

### TECHNICAL_SPEC.md (`harvest-rng/docs/TECHNICAL_SPEC.md`)
Update when architecture changes:
| Code changed | TECH_SPEC section to update |
|---|---|
| New remote event/function | §6 Remote Events Reference table |
| New DataStore | §5 DataStore Schema |
| New module added | §2 Folder & Service Structure + §4 Module Dependency Graph |
| Security model change | §9 Security Model |
| New debug flag | §11 Testing Conventions |
| Plot state machine change | §7 State Machine: Plot Lifecycle |

### PLAY_GUIDE.md (`harvest-rng/docs/PLAY_GUIDE.md`)
Update when player-facing behavior changes:
- New mechanic or system available to players
- Changed costs, timings, or rewards
- New gamepass or its benefits

## Doc Update Checklist (run before every commit)

```
[ ] README.md — does Project Structure still match src/ layout?
[ ] README.md — do Key Systems descriptions match current code behavior?
[ ] README.md — does Roadmap status reflect current state?
[ ] GDD.md — do all numbers match Config.lua values?
[ ] TECHNICAL_SPEC.md — do Remote Events tables list all current events?
[ ] TECHNICAL_SPEC.md — does DataStore Schema match PlayerData type?
[ ] PLAY_GUIDE.md — does player-facing info reflect current mechanics?
```

If a section doesn't need changing, leave it alone. If it does — update it in the **same commit** as the code change, with commit type `fix:` or `feat:` (not a separate `docs:` commit).

## Testing

Use Roblox Studio. For logic-only changes, trace through the code path manually.
DataStore changes require Studio playtesting with a real DataStore.
Debug flags in Config.lua speed up iteration:
- `Config.DEBUG_INSTANT_HARVEST = true` — skip grow timers
- `Config.DEBUG_FREE_ROLLS = true` — roll without spending coins
