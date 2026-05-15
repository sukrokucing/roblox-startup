# 🐛 BugByte Test Report — 2026-05-15 FINAL

**Triggered by:** Release readiness check — `92f07ff` fix: replace SeedData.SeedData[id] with SeedData.Get(id) — closes B-NEW-1
**Files reviewed:** All 11 Lua source files (full pass)
**Docs read:** GDD.md ✅ | TECHNICAL_SPEC.md ✅ | PLAY_GUIDE.md ✅ | README.md ✅
**Open GitHub issues before this pass:** 0

---

## Regression Confirmation

| Fix | File | Status |
|---|---|---|
| B-NEW-1: `SeedData.SeedData[id]` nil crash (4 sites) | `MainClient.client.lua` L198, L251, L258, L400 | ✅ ALL FIXED — now use `SeedData.Get(id)` |
| B-1: VIP luck idempotent recompute | `GameManager.server.lua` L163 | ✅ Confirmed — `data.luck = (luckLevel * PER_UPGRADE) + VIP_BONUS`, no `+=` |
| B-2: Roll rate limiting | `GameManager.server.lua` L59 + handlers | ✅ Confirmed — `rollCooldowns` checked in both RequestRoll and RequestRollX10 |
| M-1: DEBUG_INSTANT_HARVEST wired | `FarmManager.lua` IsReady() | ✅ Confirmed — `if Config.DEBUG_INSTANT_HARVEST then return true end` |
| M-1: DEBUG_FREE_ROLLS wired | `GameManager.server.lua` RequestRoll + RequestRollX10 | ✅ Confirmed — `if not Config.DEBUG_FREE_ROLLS then data.coins -= ...` |
| M-1: DEBUG_LOG_ROLLS wired | `RNGManager.lua` RollSeed() | ✅ Confirmed — `if Config.DEBUG_LOG_ROLLS then print(...) end` |
| M-2: GetUpgradeCost RF validates payload | `GameManager.server.lua` L481+ | ✅ Confirmed — type, stat string, level number, clamp 0-100, NaN guard |
| M-3: HasGamepass RF validates passId | `GameManager.server.lua` RF handler | ✅ Confirmed — type number, > 0, NaN guard, floor |
| M-4: Daily streak first-login guard | `GameManager.server.lua` HandleDailyStreak | ✅ Confirmed — `if data.lastLogin == 0 then ... return end` |
| N-1: GetSeedInfo type+length guard | `GameManager.server.lua` RF handler | ✅ Confirmed — `type(seedId) ~= "string" or #seedId > 64 → return nil` |
| N-2: BuildGUI.lua `--!strict` | `BuildGUI.lua` line 1 | ✅ Confirmed |
| N-3: DataManager.Init double-register guard | `DataManager.lua` | ✅ Confirmed — `_initialized` flag |
| M-NEW-1: isRolling reset on error notification | `MainClient.client.lua` Notification handler | ✅ Confirmed — `if payload.style == "error" then isRolling = false end` |

---

## 🔴 Blockers

*None.*

---

## 🟡 Major Issues

*None.*

---

## 🟢 Minor Issues

### N-NEW-1: Client harvest timer missing rarity speed modifier — visual drift
**File:** `src/client/MainClient.client.lua` ~L400 (timer loop)

**Finding:**
Server uses `RNGManager.CalcHarvestTime` which applies `seed.harvestTime * rarityMod / speed`.
Client timer loop calculates `math.ceil(baseTime / harvestSpeed)` — `rarityMod` is absent.

| Rarity | Server modifier | Client error |
|---|---|---|
| Common / Uncommon | ×1.00 | None |
| Rare | ×0.95 | +5 % longer shown |
| Epic | ×0.90 | +11 % longer shown |
| Legendary | ×0.85 | +18 % longer shown |
| Mythic | ×0.80 | +25 % longer shown |

A Mythic at base 14 400 s: server marks ready at 11 520 s; client shows ready at 14 400 s — up to 48 minutes late display.

**Impact:** Harvest button appears late visually, but player can click Harvest before the client shows "✅ Ready!" and the server will accept it. No data loss, no exploit, no coins lost.

**Fix:**
```lua
-- Replace:
local baseTime = seedDef and seedDef.harvestTime or 60
local effectiveTime = math.ceil(baseTime / math.max(harvestSpeed, 0.1))

-- With:
local RARITY_MODIFIERS = { Common=1.00, Uncommon=1.00, Rare=0.95, Epic=0.90, Legendary=0.85, Mythic=0.80 }
local rarityMod = (seedDef and RARITY_MODIFIERS[seedDef.rarity]) or 1.0
local effectiveTime = math.ceil((seedDef and seedDef.harvestTime or 60) * rarityMod / math.max(harvestSpeed, 0.1))
```

---

### N-NEW-2: UpgradePanel CloseBtn exists in GUI but is not wired in MainClient
**File:** `src/client/MainClient.client.lua` (button wiring section) / `src/studio/BuildGUI.lua`

**Finding:**
`BuildGUI.lua` creates a `CloseBtn` TextButton inside `UpgradePanel`. `MainClient.client.lua` only wires the HUD `UpgradeButton` toggle — clicking the ✕ inside the panel does nothing.

**Impact:** Minor UX friction. Players can still close the panel by clicking the HUD button again. No functional breakage.

**Fix:**
```lua
-- After the UpgradeBtn.Activated wiring, add:
local UpgradePanelCloseBtn = UpgradePanel:FindFirstChild("CloseBtn") :: TextButton?
if UpgradePanelCloseBtn then
    UpgradePanelCloseBtn.Activated:Connect(function()
        UpgradePanel.Visible = false
    end)
end
```

---

### N-NEW-3: `SeedData.Get()` called without pcall in client timer loop
**File:** `src/client/MainClient.client.lua` ~L400

**Finding:**
`SeedData.Get(state.seedId :: string)` is called directly (no pcall) inside the 1 Hz timer task. `SeedData.Get` uses `assert()` — if `state.seedId` is ever an unknown key (data migration edge case, future schema change), it throws and crashes the entire timer coroutine silently. All plot timers stop updating.

**Impact:** Very low probability in current code (server validates seeds on plant). Defensive coding issue.

**Fix:**
```lua
local ok, seedDef = pcall(SeedData.Get, state.seedId :: string)
if not ok or not seedDef then continue end
local baseTime = seedDef.harvestTime
```

---

## 💡 Suggestions

### S-NEW-1: Dead `if seedDef then` guards are now unreachable
**File:** `MainClient.client.lua` L199, L252

`SeedData.Get()` either returns a valid table or throws (assert). The guards `if seedDef then` and `seedDef and seedDef.emoji or "🌱"` can never reach the else branch. Consider using `pcall` wrappers (see N-NEW-3) for true nil-safety, or accept these as harmless dead code.

### S-NEW-2: GAMEPASS_IDS are all 0 — must fill before publishing
**File:** `src/shared/Config.lua` L82

```lua
Config.GAMEPASS_IDS = { LuckyRollX10 = 0, AutoFarm = 0, VIPPlot = 0 }
```
All gamepasses are disabled while IDs are 0 (`HasGamepass` returns false immediately). This is correct pre-publish behavior and is documented in the README and PLAY_GUIDE. Flag this as a pre-launch checklist item — the game is functional without gamepasses, but VIP/AutoFarm/x10 features are inert until real IDs are set.

### S-NEW-3: AutoFarm "6h offline cap" (GDD §7.1) is not implemented
**File:** `GameManager.server.lua` (AutoFarm loop)

The GDD promises offline income capped at 6 hours. The current implementation only runs `AutoHarvestAll` while the player is in-server (`while player.Parent do`). Crops grow passively while offline (plot timers count down server-side via `plantedAt` timestamp) and all ready plots are harvested when the player rejoins. There is no 6h cap. This is a v1 scope gap, not a security issue. Recommend either implementing a timestamp-based offline cap, or updating GDD §7.1 to reflect "online-only auto-harvest".

---

## Spec Drift

| Doc says | Code does | Verdict |
|---|---|---|
| GDD §4.1: Common 55%, Uncommon 25%, Rare 12%, Epic 5%, Legendary 2.5%, Mythic 0.5% | `Config.RARITY_BASE_WEIGHTS` exact match | ✅ |
| GDD §4.3: 30 seeds, 5 per rarity × 6 rarities | `SeedData.lua` — counted: 30 entries confirmed | ✅ |
| GDD §3: Roll costs 50 / 450 coins | `Config.ROLL_COST_COINS = 50`, `ROLL_X10_COST_COINS = 450` | ✅ |
| GDD §5.1: 3 starting plots, max 25 | `STARTING_PLOTS = 3`, `MAX_PLOTS = 25` | ✅ |
| GDD §5.2: 20 luck levels, +5 per level | `MAX_LUCK_LEVEL = 20`, `LUCK_PER_UPGRADE = 5` | ✅ |
| GDD §5.3: Max speed ≈ 4.86× at level 15 | `1 / (0.9^15) = 4.857×` | ✅ |
| GDD §7.1: VIP = +15 luck + 5 extra plots | `VIP_LUCK_BONUS = 15`, `VIP_EXTRA_PLOTS = 5` | ✅ |
| GDD §8.1: Streak resets at 36h | `DAILY_STREAK_RESET_HOURS = 36` | ✅ |
| GDD §8.1: Daily rewards Day 1–7 | Config `DAILY_STREAK_REWARDS` exact match | ✅ |
| GDD §9.1: Leaderboard top 100 | `LEADERBOARD_SIZE = 100` | ✅ |
| TECH_SPEC §11: All 3 debug flags wired | FarmManager + GameManager + RNGManager | ✅ |
| TECH_SPEC §9: All remote handlers validate inputs | All 10 handlers + 3 RFs verified | ✅ |
| TECH_SPEC §8: Client timer ±1s accuracy | Missing rarity modifier → up to 48 min drift for Mythic | ⚠️ N-NEW-1 |
| GDD §7.1: AutoFarm offline 6h cap | Not implemented — online-only loop | ⚠️ S-NEW-3 |
| GDD §5.1: Plot 4–10 costs ~88K total | Config total = ~79K (GDD figure is "estimate") | ✅ (within estimate range) |

---

## Summary

| Level | Count |
|---|---|
| 🔴 Blockers | **0** |
| 🟡 Major | **0** |
| 🟢 Minor | **3** |
| 💡 Suggestions | **3** |
| Spec drift items | **2** (minor; no data/security impact) |

---

## Pre-Deploy Checklist

Before hitting Publish in Roblox Studio:

- [x] All `--!strict` headers present across all 11 files
- [x] All debug flags set to `false` in Config.lua
- [ ] **`GAMEPASS_IDS` filled in with real Roblox gamepass IDs** (currently all 0)
- [x] `DATASTORE_NAME = "HarvestRNG_PlayerData_v1"` — unique for v1 launch
- [x] `LEADERBOARD_KEY = "TotalHarvested_v1"` — unique key
- [x] No `loadstring` or unsafe patterns found
- [x] BindToClose saves all player data on shutdown
- [x] Roll costs deducted server-side before result sent
- [x] All economy values computed server-side

---

**Release recommendation: ✅ READY TO DEPLOY**

Zero blockers. Zero major issues. All prior findings confirmed fixed, including the core-loop-breaking B-NEW-1 nil crash. The three remaining minor issues are cosmetic/UX (timer visual drift, a close button that does nothing, a defensive code gap). None affect data integrity, security, or gameplay correctness. The only hard requirement before publish is filling in the real Roblox gamepass IDs in `Config.GAMEPASS_IDS`.

---

*Report generated by BugByte 🐛 — Roblox QA Agent*
*Skills applied: roblox-security, roblox-remote-events, roblox-datastores, roblox-performance, code-review-quality, systematic-debugging*
*Commit reviewed: `92f07ff`*
*All 11 source files read. All 4 docs read. Full spec compliance check performed.*
