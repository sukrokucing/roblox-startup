--!strict
-- ============================================================
--  RemoteEvents.lua  (Shared)
--  Central registry of all RemoteEvent and RemoteFunction names.
--
--  Usage (server):
--    local RE = require(game.ReplicatedStorage.Shared.RemoteEvents)
--    RE.Events.RollSeed:FireClient(player, result)
--
--  Usage (client):
--    local RE = require(game.ReplicatedStorage.Shared.RemoteEvents)
--    RE.Events.RollSeed.OnClientEvent:Connect(function(result) ... end)
--
--  The server GameManager is responsible for creating the actual
--  RemoteEvent / RemoteFunction instances inside ReplicatedStorage
--  using the names listed here.
-- ============================================================

export type RemoteEventName    = string
export type RemoteFunctionName = string

local RemoteEvents = {}

-- ── Event names (Server → Client  or  Client → Server) ────────
RemoteEvents.Names = {

    -- ── Roll / RNG ───────────────────────────────────────────
    RequestRoll        = "RequestRoll",         -- C→S: player wants to roll (single)
    RequestRollX10     = "RequestRollX10",       -- C→S: player wants 10-roll bundle
    RollResult         = "RollResult",           -- S→C: broadcast roll outcome(s)

    -- ── Farm / Plot ──────────────────────────────────────────
    RequestPlant       = "RequestPlant",         -- C→S: { plotIndex, seedId }
    RequestHarvest     = "RequestHarvest",       -- C→S: { plotIndex }
    RequestUnlockPlot  = "RequestUnlockPlot",    -- C→S: { plotIndex }
    PlotStateUpdate    = "PlotStateUpdate",      -- S→C: full plot state for a player
    HarvestResult      = "HarvestResult",        -- S→C: { plotIndex, coins, seedName, rarity }

    -- ── Player Data ──────────────────────────────────────────
    PlayerDataLoaded   = "PlayerDataLoaded",     -- S→C: full initial data snapshot
    StatsUpdate        = "StatsUpdate",          -- S→C: partial { coins?, gems?, luck?, ... }

    -- ── Upgrades ─────────────────────────────────────────────
    RequestUpgradeLuck          = "RequestUpgradeLuck",
    RequestUpgradeHarvestSpeed  = "RequestUpgradeHarvestSpeed",
    UpgradeResult               = "UpgradeResult",   -- S→C: { stat, newValue, newLevel }

    -- ── Daily Streak ─────────────────────────────────────────
    DailyStreakClaimed = "DailyStreakClaimed",   -- S→C: { day, coins, gems }
    RequestClaimStreak = "RequestClaimStreak",   -- C→S: (no args) player opens daily modal

    -- ── Leaderboard ──────────────────────────────────────────
    RequestLeaderboard = "RequestLeaderboard",   -- C→S: (no args)
    LeaderboardData    = "LeaderboardData",      -- S→C: array of { rank, name, value }

    -- ── Inventory ────────────────────────────────────────────
    RequestInventory   = "RequestInventory",     -- C→S: open inventory panel
    InventoryUpdate    = "InventoryUpdate",      -- S→C: { inventory table }

    -- ── Notifications ────────────────────────────────────────
    Notification       = "Notification",         -- S→C: { message, style? }
}

-- ── RemoteFunction names (Client calls, Server responds) ──────
RemoteEvents.FunctionNames = {
    GetSeedInfo        = "GetSeedInfo",          -- C→S: seedId → SeedDefinition
    GetUpgradeCost     = "GetUpgradeCost",       -- C→S: { stat, currentLevel } → number
    HasGamepass        = "HasGamepass",           -- C→S: gamepassId → boolean
}

-- ── Helper: event category checks (optional utility) ──────────
function RemoteEvents.IsClientToServer(name: string): boolean
    local c2s = {
        RequestRoll = true, RequestRollX10 = true,
        RequestPlant = true, RequestHarvest = true, RequestUnlockPlot = true,
        RequestUpgradeLuck = true, RequestUpgradeHarvestSpeed = true,
        RequestClaimStreak = true, RequestLeaderboard = true,
        RequestInventory = true,
    }
    return c2s[name] == true
end

function RemoteEvents.IsServerToClient(name: string): boolean
    return not RemoteEvents.IsClientToServer(name)
end

return RemoteEvents
