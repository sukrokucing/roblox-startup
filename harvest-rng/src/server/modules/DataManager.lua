--!strict
-- ============================================================
--  DataManager.lua  (Server Module)
--  Handles all DataStore reads, writes, and the auto-save loop.
--
--  Usage:
--    local DataManager = require(script.Parent.DataManager)
--    DataManager.Init()
--    local data = DataManager.GetData(player)
--    DataManager.SetData(player, data)
-- ============================================================

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)

-- ── Types ─────────────────────────────────────────────────────

export type PlotState = {
    seedId      : string?,   -- nil = empty plot
    plantedAt   : number?,   -- os.time() when planted
    isUnlocked  : boolean,
}

export type PlayerData = {
    coins           : number,
    gems            : number,
    luck            : number,       -- raw stat, not level
    luckLevel       : number,
    harvestSpeed    : number,       -- multiplier
    harvestSpeedLevel : number,
    plots           : {PlotState},
    inventory       : {[string]: number},   -- seedId → count held (unplanted)
    totalHarvested  : number,       -- lifetime coins harvested (leaderboard)
    dailyStreak     : number,
    lastLogin       : number,       -- os.time()
    dataVersion     : number,
}

-- ── Private state ─────────────────────────────────────────────

local dataStore: DataStore = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

-- Cache of loaded player data; keyed by UserId (as string)
local cache: {[string]: PlayerData} = {}

-- Tracks which players have unsaved dirty data
local dirty: {[string]: boolean} = {}

-- ── Default schema factory ────────────────────────────────────

local function BuildDefaultData(): PlayerData
    local plots: {PlotState} = {}
    for i = 1, Config.MAX_PLOTS do
        plots[i] = {
            seedId     = nil,
            plantedAt  = nil,
            isUnlocked = i <= Config.STARTING_PLOTS,
        }
    end

    return {
        coins               = Config.STARTING_COINS,
        gems                = Config.STARTING_GEMS,
        luck                = Config.STARTING_LUCK,
        luckLevel           = 0,
        harvestSpeed        = Config.STARTING_HARVEST_SPEED,
        harvestSpeedLevel   = 0,
        plots               = plots,
        inventory           = {},
        totalHarvested      = 0,
        dailyStreak         = 0,
        lastLogin           = 0,
        dataVersion         = 1,
    }
end

-- ── Reconcile: fill in missing keys for returning players ─────
-- Ensures schema migrations don't break existing saves.

local function Reconcile(data: {[string]: any}): PlayerData
    local defaults = BuildDefaultData()
    for key, defaultVal in defaults :: {[string]: any} do
        if data[key] == nil then
            data[key] = defaultVal
        end
    end
    -- Ensure plots array has correct length
    local plots = data.plots :: {PlotState}
    for i = #plots + 1, Config.MAX_PLOTS do
        plots[i] = {
            seedId     = nil,
            plantedAt  = nil,
            isUnlocked = false,
        }
    end
    return data :: PlayerData
end

-- ── DataStore load with retry ─────────────────────────────────

local function LoadFromStore(userId: string): PlayerData
    local attempts = Config.DATASTORE_RETRY_ATTEMPTS
    local delay    = Config.DATASTORE_RETRY_BASE_DELAY
    local key      = "player_" .. userId

    for attempt = 1, attempts do
        local success, result = pcall(function()
            return dataStore:GetAsync(key)
        end)

        if success then
            if result ~= nil then
                return Reconcile(result)
            else
                return BuildDefaultData()
            end
        else
            warn(string.format(
                "[DataManager] GetAsync attempt %d/%d failed for %s: %s",
                attempt, attempts, userId, tostring(result)
            ))
            if attempt < attempts then
                task.wait(delay)
                delay = delay * 2  -- exponential backoff
            end
        end
    end

    warn("[DataManager] All GetAsync attempts failed for " .. userId .. ". Using default data.")
    return BuildDefaultData()
end

-- ── DataStore save with retry ─────────────────────────────────

local function SaveToStore(userId: string, data: PlayerData): boolean
    local attempts = Config.DATASTORE_RETRY_ATTEMPTS
    local delay    = Config.DATASTORE_RETRY_BASE_DELAY
    local key      = "player_" .. userId

    for attempt = 1, attempts do
        local success, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)

        if success then
            return true
        else
            warn(string.format(
                "[DataManager] SetAsync attempt %d/%d failed for %s: %s",
                attempt, attempts, userId, tostring(err)
            ))
            if attempt < attempts then
                task.wait(delay)
                delay = delay * 2
            end
        end
    end

    warn("[DataManager] All SetAsync attempts failed for " .. userId .. ". Data may be lost!")
    return false
end

-- ── Public API ────────────────────────────────────────────────

local DataManager = {}

--- Loads player data from DataStore and caches it.
--- Call this in PlayerAdded.
function DataManager.Load(player: Player): PlayerData
    local key = tostring(player.UserId)
    if cache[key] then
        return cache[key]
    end

    local data = LoadFromStore(key)
    cache[key]  = data
    dirty[key]  = false
    return data
end

--- Returns the in-memory cached data for a player.
--- Returns nil if the player hasn't loaded yet.
function DataManager.GetData(player: Player): PlayerData?
    return cache[tostring(player.UserId)]
end

--- Marks the player's data as dirty (will be saved on next auto-save or remove).
--- Use this after any mutation to player data.
function DataManager.MarkDirty(player: Player)
    dirty[tostring(player.UserId)] = true
end

--- Immediately saves player data and removes from cache.
--- Call this in PlayerRemoving.
function DataManager.Unload(player: Player)
    local key  = tostring(player.UserId)
    local data = cache[key]
    if data then
        SaveToStore(key, data)
    end
    cache[key] = nil
    dirty[key] = nil
end

--- Manually save a player's data right now (e.g. after a purchase).
function DataManager.Save(player: Player): boolean
    local key  = tostring(player.UserId)
    local data = cache[key]
    if not data then
        return false
    end
    local ok = SaveToStore(key, data)
    if ok then
        dirty[key] = false
    end
    return ok
end

--- Returns true if there is cached (loaded) data for this player.
function DataManager.IsLoaded(player: Player): boolean
    return cache[tostring(player.UserId)] ~= nil
end

--- Initialises the auto-save heartbeat loop.
--- Should only be called once from GameManager.
local _initialized = false
function DataManager.Init()
    if _initialized then return end
    _initialized = true
    task.spawn(function()
        while true do
            task.wait(Config.AUTOSAVE_INTERVAL)
            for key, isDirty in dirty do
                if isDirty and cache[key] then
                    local player = Players:GetPlayerByUserId(tonumber(key) :: number)
                    if player then
                        local ok = SaveToStore(key, cache[key])
                        if ok then
                            dirty[key] = false
                        end
                    end
                end
            end
        end
    end)

    -- Bind PlayerRemoving at the game level so saves happen even during server shutdown
    game:BindToClose(function()
        -- Save all loaded players synchronously before shutdown
        for key, data in cache do
            if data then
                SaveToStore(key, data)
            end
        end
    end)
end

--- Resets a player's data to defaults (for debugging / admin use).
--- USE WITH CARE — destructive.
function DataManager.ResetData(player: Player)
    local key = tostring(player.UserId)
    cache[key] = BuildDefaultData()
    dirty[key] = true
    SaveToStore(key, cache[key])
end

return DataManager
