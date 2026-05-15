--!strict
-- ============================================================
--  RNGManager.lua  (Server Module)
--  Core RNG engine: seed rolling with luck-weighted rarities.
--
--  Usage:
--    local RNGManager = require(script.Parent.RNGManager)
--    local result = RNGManager.RollSeed(playerLuckBonus)
--    local seedDef = RNGManager.GetSeedData("golden_apple")
-- ============================================================

local SeedData  = require(game.ReplicatedStorage.Shared.SeedData)
local Config    = require(game.ReplicatedStorage.Shared.Config)

-- ── Types ─────────────────────────────────────────────────────

export type RollResult = {
    seedId   : string,
    seedName : string,
    rarity   : string,
    baseValue: number,
}

-- ── Build rarity→seeds lookup (cached once at startup) ────────

local rarityToSeeds: {[string]: {SeedData.SeedDefinition}} = {}
for _, rarity in Config.RARITY_ORDER do
    rarityToSeeds[rarity] = SeedData.GetByRarity(rarity)
end

-- ── Weight calculation ────────────────────────────────────────
--
--  Luck bonus (0–100) gradually redistributes weight from Common
--  toward rarer tiers.  Each +1 luck shifts LUCK_WEIGHT_SHIFT
--  weight points away from Common and distributes them proportionally
--  among non-Common tiers (weighted by their base share).
--
--  At luck=0  → exact base weights from Config
--  At luck=100 → Common reduced by ~8 pp; spread across Uncommon→Mythic

local BASE_WEIGHTS: {[string]: number} = {}
for rarity, w in Config.RARITY_BASE_WEIGHTS do
    BASE_WEIGHTS[rarity] = w
end

local function BuildWeights(luckBonus: number): {[string]: number}
    -- Clamp luck to [0, 100]
    local luck = math.clamp(luckBonus, 0, 100)

    -- How many weight points to shift away from Common
    local shift = luck * Config.LUCK_WEIGHT_SHIFT

    -- Total weight of non-Common tiers (for proportional distribution)
    local nonCommonTotal = 0
    for _, rarity in Config.RARITY_ORDER do
        if rarity ~= "Common" then
            nonCommonTotal += BASE_WEIGHTS[rarity]
        end
    end

    local weights: {[string]: number} = {}
    for _, rarity in Config.RARITY_ORDER do
        if rarity == "Common" then
            weights[rarity] = math.max(BASE_WEIGHTS[rarity] - shift, 1.0)
        else
            -- Distribute the shift proportionally
            local proportion = BASE_WEIGHTS[rarity] / nonCommonTotal
            weights[rarity] = BASE_WEIGHTS[rarity] + shift * proportion
        end
    end

    return weights
end

-- ── Weighted random pick ──────────────────────────────────────

local function PickRarity(weights: {[string]: number}): string
    -- Build cumulative ranges
    local total = 0
    for _, rarity in Config.RARITY_ORDER do
        total += weights[rarity]
    end

    local roll = math.random() * total
    local cumulative = 0

    for _, rarity in Config.RARITY_ORDER do
        cumulative += weights[rarity]
        if roll <= cumulative then
            return rarity
        end
    end

    -- Fallback (floating point edge case)
    return Config.RARITY_ORDER[#Config.RARITY_ORDER]
end

local function PickSeedFromRarity(rarity: string): SeedData.SeedDefinition
    local seeds = rarityToSeeds[rarity]
    assert(seeds and #seeds > 0, "RNGManager: no seeds for rarity " .. rarity)
    return seeds[math.random(1, #seeds)]
end

-- ── Value modifier by rarity ──────────────────────────────────

local RARITY_VALUE_MULTIPLIERS: {[string]: number} = {
    Common    = 1.00,
    Uncommon  = 1.10,
    Rare      = 1.25,
    Epic      = 1.50,
    Legendary = 2.00,
    Mythic    = 3.00,
}

local RARITY_HARVEST_TIME_MODIFIERS: {[string]: number} = {
    Common    = 1.00,
    Uncommon  = 1.00,
    Rare      = 0.95,
    Epic      = 0.90,
    Legendary = 0.85,
    Mythic    = 0.80,
}

-- ── Public API ────────────────────────────────────────────────

local RNGManager = {}

---  Roll a single seed, applying the player's luck bonus.
---  @param luckBonus  Player's current luck stat (0–100)
---  @return RollResult
function RNGManager.RollSeed(luckBonus: number): RollResult
    local weights = BuildWeights(luckBonus)
    local rarity  = PickRarity(weights)
    local seed    = PickSeedFromRarity(rarity)

    local result: RollResult = {
        seedId    = seed.id,
        seedName  = seed.name,
        rarity    = seed.rarity,
        baseValue = seed.baseValue,
    }
    -- DEBUG: log every roll result to the server output for testing
    if Config.DEBUG_LOG_ROLLS then
        print(string.format("[RNG DEBUG] luck=%d → rarity=%s seed=%s value=%d",
            luckBonus, result.rarity, result.seedId, result.baseValue))
    end
    return result
end

---  Roll multiple seeds at once (for x10 bundle).
---  @param count      How many seeds to roll
---  @param luckBonus  Player's current luck stat
---  @return {RollResult}
function RNGManager.RollMultiple(count: number, luckBonus: number): {RollResult}
    local results: {RollResult} = {}
    for _ = 1, count do
        table.insert(results, RNGManager.RollSeed(luckBonus))
    end
    return results
end

---  Returns the full SeedDefinition for a given seed id.
function RNGManager.GetSeedData(seedId: string): SeedData.SeedDefinition
    return SeedData.Get(seedId)
end

---  Returns the value multiplier for a rarity tier.
function RNGManager.GetValueMultiplier(rarity: string): number
    return RARITY_VALUE_MULTIPLIERS[rarity] or 1.0
end

---  Returns the harvest-time modifier for a rarity tier.
function RNGManager.GetHarvestTimeModifier(rarity: string): number
    return RARITY_HARVEST_TIME_MODIFIERS[rarity] or 1.0
end

---  Calculates the final coin payout for a harvest.
---  finalCoins = baseValue × rarityMultiplier × (1 + luck/200)
---  (luck adds up to +50 % bonus at max luck=100)
function RNGManager.CalcHarvestValue(seedId: string, luckBonus: number): number
    local seed      = SeedData.Get(seedId)
    local rarityMul = RARITY_VALUE_MULTIPLIERS[seed.rarity] or 1.0
    local luckMul   = 1 + math.clamp(luckBonus, 0, 100) / 200
    return math.floor(seed.baseValue * rarityMul * luckMul)
end

---  Returns effective harvest time in seconds after applying
---  the player's harvestSpeed multiplier and rarity modifier.
---  effectiveTime = baseTime × rarityModifier / harvestSpeedMultiplier
function RNGManager.CalcHarvestTime(seedId: string, harvestSpeedMultiplier: number): number
    local seed        = SeedData.Get(seedId)
    local rarityMod   = RARITY_HARVEST_TIME_MODIFIERS[seed.rarity] or 1.0
    local speed       = math.max(harvestSpeedMultiplier, 0.1)
    return math.ceil(seed.harvestTime * rarityMod / speed)
end

---  Returns the current rarity chance table as percentages
---  for a given luck bonus (useful for UI display).
function RNGManager.GetRarityChances(luckBonus: number): {[string]: number}
    local weights = BuildWeights(luckBonus)
    local total   = 0
    for _, w in weights do total += w end

    local chances: {[string]: number} = {}
    for rarity, w in weights do
        -- Round to 2 decimal places
        chances[rarity] = math.floor((w / total) * 10000 + 0.5) / 100
    end
    return chances
end

return RNGManager
