--!strict
-- ============================================================
--  FarmManager.lua  (Server Module)
--  Manages farm plots: planting, growing, harvesting,
--  and plot unlocking.  All mutations go through DataManager.
--
--  Usage (called from GameManager):
--    FarmManager.PlantSeed(player, plotIndex, seedId)
--    FarmManager.Harvest(player, plotIndex)
--    FarmManager.UnlockPlot(player, plotIndex)
-- ============================================================

local DataManager = require(script.Parent.DataManager)
local RNGManager  = require(script.Parent.RNGManager)
local Config      = require(game.ReplicatedStorage.Shared.Config)
local SeedData    = require(game.ReplicatedStorage.Shared.SeedData)

-- ── Types ─────────────────────────────────────────────────────

export type PlantResult = {
    success    : boolean,
    reason     : string?,
}

export type HarvestResult = {
    success    : boolean,
    coins      : number,
    seedId     : string,
    seedName   : string,
    rarity     : string,
    reason     : string?,
}

export type UnlockResult = {
    success    : boolean,
    reason     : string?,
    newBalance : number,
}

-- ── Helpers ───────────────────────────────────────────────────

local function GetPlot(player: Player, index: number): (DataManager.PlotState?, DataManager.PlayerData?)
    local data = DataManager.GetData(player)
    if not data then
        return nil, nil
    end
    local plot = data.plots[index]
    if not plot then
        return nil, data
    end
    return plot, data
end

-- ── Public API ────────────────────────────────────────────────

local FarmManager = {}

---  Attempts to plant `seedId` on plot `plotIndex` for `player`.
---  The seed must be in the player's inventory.
function FarmManager.PlantSeed(player: Player, plotIndex: number, seedId: string): PlantResult
    local plot, data = GetPlot(player, plotIndex)
    if not plot or not data then
        return { success = false, reason = "Data not loaded." }
    end
    if not plot.isUnlocked then
        return { success = false, reason = "Plot is locked." }
    end
    if plot.seedId ~= nil then
        return { success = false, reason = "Plot already has a crop." }
    end

    -- Validate seed exists (use public API instead of direct table access)
    local seedOk, seedDef = pcall(SeedData.Get, seedId)
    if not seedOk or not seedDef then
        return { success = false, reason = "Unknown seed: " .. seedId }
    end

    -- Check inventory
    local inv = data.inventory
    local held = inv[seedId] or 0
    if held <= 0 then
        return { success = false, reason = "You don't have that seed." }
    end

    -- Plant it
    inv[seedId] = held - 1
    if inv[seedId] == 0 then
        inv[seedId] = nil  -- keep inventory clean
    end
    plot.seedId    = seedId
    plot.plantedAt = os.time()

    DataManager.MarkDirty(player)
    return { success = true }
end

---  Checks if a plot is ready to harvest right now.
function FarmManager.IsReady(player: Player, plotIndex: number): boolean
    local plot, data = GetPlot(player, plotIndex)
    if not plot or not data then return false end
    if not plot.seedId or not plot.plantedAt then return false end
    -- DEBUG: skip grow timer entirely so devs can test harvest flow immediately
    if Config.DEBUG_INSTANT_HARVEST then return true end

    local growTime   = RNGManager.CalcHarvestTime(plot.seedId :: string, data.harvestSpeed)
    local elapsed    = os.time() - (plot.plantedAt :: number)
    return elapsed >= growTime
end

---  Returns seconds remaining until a plot is harvestable (0 if ready).
function FarmManager.TimeRemaining(player: Player, plotIndex: number): number
    local plot, data = GetPlot(player, plotIndex)
    if not plot or not data then return 0 end
    if not plot.seedId or not plot.plantedAt then return 0 end

    local growTime = RNGManager.CalcHarvestTime(plot.seedId :: string, data.harvestSpeed)
    local elapsed  = os.time() - (plot.plantedAt :: number)
    return math.max(0, growTime - elapsed)
end

---  Harvests the crop on `plotIndex` if it is ready.
---  Adds coins to the player and clears the plot.
function FarmManager.Harvest(player: Player, plotIndex: number): HarvestResult
    local plot, data = GetPlot(player, plotIndex)
    if not plot or not data then
        return { success = false, coins = 0, seedId = "", seedName = "", rarity = "", reason = "Data not loaded." }
    end
    if not plot.isUnlocked then
        return { success = false, coins = 0, seedId = "", seedName = "", rarity = "", reason = "Plot is locked." }
    end
    if not plot.seedId then
        return { success = false, coins = 0, seedId = "", seedName = "", rarity = "", reason = "Nothing planted." }
    end
    if not FarmManager.IsReady(player, plotIndex) then
        local remaining = FarmManager.TimeRemaining(player, plotIndex)
        return {
            success  = false, coins = 0,
            seedId   = plot.seedId :: string,
            seedName = "", rarity = "",
            reason   = string.format("Not ready yet. %d seconds remaining.", remaining)
        }
    end

    local seedId  = plot.seedId :: string
    local seedDef = SeedData.Get(seedId)
    local coins   = RNGManager.CalcHarvestValue(seedId, data.luck)

    -- Apply rewards
    data.coins          += coins
    data.totalHarvested += coins

    -- Clear plot
    plot.seedId    = nil
    plot.plantedAt = nil

    DataManager.MarkDirty(player)

    return {
        success  = true,
        coins    = coins,
        seedId   = seedId,
        seedName = seedDef.name,
        rarity   = seedDef.rarity,
    }
end

---  Unlocks the next plot if the player has enough coins.
function FarmManager.UnlockPlot(player: Player, plotIndex: number): UnlockResult
    local plot, data = GetPlot(player, plotIndex)
    if not plot or not data then
        return { success = false, reason = "Data not loaded.", newBalance = 0 }
    end
    if plot.isUnlocked then
        return { success = false, reason = "Plot already unlocked.", newBalance = data.coins }
    end
    if plotIndex > Config.MAX_PLOTS then
        return { success = false, reason = "Max plots reached.", newBalance = data.coins }
    end

    -- Check sequential unlock (must unlock in order)
    if plotIndex > 1 and not data.plots[plotIndex - 1].isUnlocked then
        return { success = false, reason = "Must unlock previous plot first.", newBalance = data.coins }
    end

    local cost = Config.PLOT_UNLOCK_COSTS[plotIndex]
    if not cost then
        return { success = false, reason = "No cost defined for plot " .. plotIndex, newBalance = data.coins }
    end
    if data.coins < cost then
        return {
            success    = false,
            reason     = string.format("Need %d coins (have %d).", cost, data.coins),
            newBalance = data.coins,
        }
    end

    data.coins        -= cost
    plot.isUnlocked    = true

    DataManager.MarkDirty(player)

    return { success = true, newBalance = data.coins }
end

---  Returns a snapshot of all plot states for UI sync.
function FarmManager.GetPlotSnapshot(player: Player): {DataManager.PlotState}?
    local data = DataManager.GetData(player)
    if not data then return nil end
    -- Return a shallow copy to prevent external mutation
    local snapshot: {DataManager.PlotState} = {}
    for i, plot in data.plots do
        snapshot[i] = {
            seedId     = plot.seedId,
            plantedAt  = plot.plantedAt,
            isUnlocked = plot.isUnlocked,
        }
    end
    return snapshot
end

---  Auto-harvest all ready plots for a player.
---  Called by the AutoFarm gamepass loop on the server.
---  Returns total coins earned this pass.
function FarmManager.AutoHarvestAll(player: Player): number
    local data = DataManager.GetData(player)
    if not data then return 0 end

    local totalCoins = 0
    for i, plot in data.plots do
        if plot.isUnlocked and plot.seedId and FarmManager.IsReady(player, i) then
            local result = FarmManager.Harvest(player, i)
            if result.success then
                totalCoins += result.coins
            end
        end
    end
    return totalCoins
end

return FarmManager
