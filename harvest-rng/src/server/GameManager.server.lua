--!strict
-- ============================================================
--  GameManager.server.lua  (ServerScript)
--  Bootstrap script — runs once when the server starts.
--  Responsibilities:
--    1. Create all RemoteEvent / RemoteFunction instances
--    2. Initialise server modules (DataManager, etc.)
--    3. Wire PlayerAdded / PlayerRemoving
--    4. Handle all inbound remote calls from clients
--    5. Drive daily-streak logic and auto-farm loop
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Module requires
local DataManager  = require(script.Parent.modules.DataManager)
local RNGManager   = require(script.Parent.modules.RNGManager)
local FarmManager  = require(script.Parent.modules.FarmManager)
local Config       = require(game.ReplicatedStorage.Shared.Config)
local RemoteEvents = require(game.ReplicatedStorage.Shared.RemoteEvents)

-- ── 1. Create RemoteEvent / RemoteFunction instances ──────────

local eventsFolder = Instance.new("Folder")
eventsFolder.Name  = "Events"
eventsFolder.Parent = ReplicatedStorage

local functionsFolder = Instance.new("Folder")
functionsFolder.Name  = "Functions"
functionsFolder.Parent = ReplicatedStorage

-- Create all RemoteEvents
local RE: {[string]: RemoteEvent} = {}
for _, name in RemoteEvents.Names do
    local event = Instance.new("RemoteEvent")
    event.Name  = name
    event.Parent = eventsFolder
    RE[name] = event
end

-- Create all RemoteFunctions
local RF: {[string]: RemoteFunction} = {}
for _, name in RemoteEvents.FunctionNames do
    local func = Instance.new("RemoteFunction")
    func.Name   = name
    func.Parent = functionsFolder
    RF[name] = func
end

-- ── 2. Initialise modules ─────────────────────────────────────

DataManager.Init()

-- ── 3. Helpers ────────────────────────────────────────────────

local function HasGamepass(player: Player, passName: string): boolean
    local passId = Config.GAMEPASS_IDS[passName]
    if not passId or passId == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    return ok and owns
end

local function CalcLuckUpgradeCost(currentLevel: number): number
    return math.floor(Config.LUCK_UPGRADE_BASE_COST * (Config.LUCK_UPGRADE_SCALE ^ currentLevel))
end

local function CalcHarvestSpeedUpgradeCost(currentLevel: number): number
    return math.floor(Config.HARVEST_SPEED_BASE_COST * (Config.HARVEST_SPEED_SCALE ^ currentLevel))
end

local function SendStatsUpdate(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end
    RE[RemoteEvents.Names.StatsUpdate]:FireClient(player, {
        coins             = data.coins,
        gems              = data.gems,
        luck              = data.luck,
        luckLevel         = data.luckLevel,
        harvestSpeed      = data.harvestSpeed,
        harvestSpeedLevel = data.harvestSpeedLevel,
        totalHarvested    = data.totalHarvested,
        dailyStreak       = data.dailyStreak,
    })
end

local function SendPlotUpdate(player: Player)
    local snapshot = FarmManager.GetPlotSnapshot(player)
    if snapshot then
        RE[RemoteEvents.Names.PlotStateUpdate]:FireClient(player, snapshot)
    end
end

local function HandleDailyStreak(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end

    local now        = os.time()
    local hoursSince = (now - data.lastLogin) / 3600

    if hoursSince >= Config.DAILY_STREAK_RESET_HOURS then
        -- Streak broken — reset
        data.dailyStreak = 0
    end

    if hoursSince >= 20 then
        -- New day — increment streak and grant reward
        data.dailyStreak += 1
        data.lastLogin    = now

        local day         = ((data.dailyStreak - 1) % 7) + 1
        local reward      = Config.DAILY_STREAK_REWARDS[day]
        data.coins += reward.coins
        data.gems  += reward.gems

        DataManager.MarkDirty(player)

        RE[RemoteEvents.Names.DailyStreakClaimed]:FireClient(player, {
            day   = data.dailyStreak,
            coins = reward.coins,
            gems  = reward.gems,
        })
    else
        -- Same-day login — just update timestamp silently
        data.lastLogin = now
        DataManager.MarkDirty(player)
    end
end

-- ── 4. PlayerAdded ────────────────────────────────────────────

local function OnPlayerAdded(player: Player)
    -- Load data (blocks until loaded or defaults given)
    local data = DataManager.Load(player)

    -- Apply VIP perks
    if HasGamepass(player, "VIPPlot") then
        data.luck += Config.VIP_LUCK_BONUS
        -- Unlock extra VIP plots
        for i = Config.STARTING_PLOTS + 1, Config.STARTING_PLOTS + Config.VIP_EXTRA_PLOTS do
            if data.plots[i] and not data.plots[i].isUnlocked then
                data.plots[i].isUnlocked = true
            end
        end
        DataManager.MarkDirty(player)
    end

    -- Send full initial data snapshot
    RE[RemoteEvents.Names.PlayerDataLoaded]:FireClient(player, {
        coins             = data.coins,
        gems              = data.gems,
        luck              = data.luck,
        luckLevel         = data.luckLevel,
        harvestSpeed      = data.harvestSpeed,
        harvestSpeedLevel = data.harvestSpeedLevel,
        totalHarvested    = data.totalHarvested,
        dailyStreak       = data.dailyStreak,
        inventory         = data.inventory,
    })

    -- Send initial plot state
    SendPlotUpdate(player)

    -- Handle daily streak (checks if new day)
    task.delay(0.5, function()
        HandleDailyStreak(player)
    end)

    -- AutoFarm loop (only if player owns the gamepass)
    task.spawn(function()
        while player.Parent do
            task.wait(Config.AUTOFARM_POLL_INTERVAL)
            if not player.Parent then break end
            if HasGamepass(player, "AutoFarm") then
                local earned = FarmManager.AutoHarvestAll(player)
                if earned > 0 then
                    SendStatsUpdate(player)
                    SendPlotUpdate(player)
                    RE[RemoteEvents.Names.Notification]:FireClient(player, {
                        message = string.format("🤖 Auto-Farm collected %d coins!", earned),
                        style   = "info",
                    })
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(OnPlayerAdded)

-- Handle players who joined before this script ran
for _, player in Players:GetPlayers() do
    task.spawn(OnPlayerAdded, player)
end

-- ── 5. PlayerRemoving ─────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player: Player)
    DataManager.Unload(player)
end)

-- ── 6. Remote event handlers ──────────────────────────────────

-- Roll (single)
RE[RemoteEvents.Names.RequestRoll].OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data then return end

    if data.coins < Config.ROLL_COST_COINS then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = "Not enough coins to roll!",
            style   = "error",
        })
        return
    end

    data.coins -= Config.ROLL_COST_COINS
    local result = RNGManager.RollSeed(data.luck)

    -- Add seed to inventory
    data.inventory[result.seedId] = (data.inventory[result.seedId] or 0) + 1

    DataManager.MarkDirty(player)

    RE[RemoteEvents.Names.RollResult]:FireClient(player, { result })
    SendStatsUpdate(player)
end)

-- Roll x10
RE[RemoteEvents.Names.RequestRollX10].OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data then return end

    local cost = Config.ROLL_X10_COST_COINS
    if data.coins < cost then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = string.format("Need %d coins for x10 roll!", cost),
            style   = "error",
        })
        return
    end

    data.coins -= cost
    local results = RNGManager.RollMultiple(10, data.luck)

    for _, r in results do
        data.inventory[r.seedId] = (data.inventory[r.seedId] or 0) + 1
    end

    DataManager.MarkDirty(player)

    RE[RemoteEvents.Names.RollResult]:FireClient(player, results)
    SendStatsUpdate(player)
end)

-- Plant
RE[RemoteEvents.Names.RequestPlant].OnServerEvent:Connect(function(player, plotIndex: number, seedId: string)
    if type(plotIndex) ~= "number" or type(seedId) ~= "string" then return end
    local result = FarmManager.PlantSeed(player, plotIndex, seedId)
    if result.success then
        SendPlotUpdate(player)
        SendStatsUpdate(player)
    else
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = result.reason or "Cannot plant.",
            style   = "error",
        })
    end
end)

-- Harvest
RE[RemoteEvents.Names.RequestHarvest].OnServerEvent:Connect(function(player, plotIndex: number)
    if type(plotIndex) ~= "number" then return end
    local result = FarmManager.Harvest(player, plotIndex)
    if result.success then
        RE[RemoteEvents.Names.HarvestResult]:FireClient(player, {
            plotIndex = plotIndex,
            coins     = result.coins,
            seedName  = result.seedName,
            rarity    = result.rarity,
        })
        SendStatsUpdate(player)
        SendPlotUpdate(player)
    else
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = result.reason or "Cannot harvest.",
            style   = "error",
        })
    end
end)

-- Unlock plot
RE[RemoteEvents.Names.RequestUnlockPlot].OnServerEvent:Connect(function(player, plotIndex: number)
    if type(plotIndex) ~= "number" then return end
    local result = FarmManager.UnlockPlot(player, plotIndex)
    if result.success then
        SendStatsUpdate(player)
        SendPlotUpdate(player)
    else
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = result.reason or "Cannot unlock plot.",
            style   = "error",
        })
    end
end)

-- Upgrade Luck
RE[RemoteEvents.Names.RequestUpgradeLuck].OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data then return end
    if data.luckLevel >= Config.MAX_LUCK_LEVEL then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = "Luck is already maxed out!",
            style   = "info",
        })
        return
    end
    local cost = CalcLuckUpgradeCost(data.luckLevel)
    if data.coins < cost then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = string.format("Need %d coins for Luck upgrade.", cost),
            style   = "error",
        })
        return
    end
    data.coins     -= cost
    data.luckLevel += 1
    data.luck       = data.luckLevel * Config.LUCK_PER_UPGRADE

    DataManager.MarkDirty(player)
    SendStatsUpdate(player)
    RE[RemoteEvents.Names.UpgradeResult]:FireClient(player, {
        stat     = "luck",
        newValue = data.luck,
        newLevel = data.luckLevel,
    })
end)

-- Upgrade Harvest Speed
RE[RemoteEvents.Names.RequestUpgradeHarvestSpeed].OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data then return end
    if data.harvestSpeedLevel >= Config.MAX_HARVEST_SPEED_LEVEL then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = "Harvest Speed is already maxed out!",
            style   = "info",
        })
        return
    end
    local cost = CalcHarvestSpeedUpgradeCost(data.harvestSpeedLevel)
    if data.coins < cost then
        RE[RemoteEvents.Names.Notification]:FireClient(player, {
            message = string.format("Need %d coins for Harvest Speed upgrade.", cost),
            style   = "error",
        })
        return
    end
    data.coins              -= cost
    data.harvestSpeedLevel  += 1
    -- Multiply current speed by HARVEST_SPEED_FACTOR for each level
    data.harvestSpeed = Config.STARTING_HARVEST_SPEED / (Config.HARVEST_SPEED_FACTOR ^ data.harvestSpeedLevel)

    DataManager.MarkDirty(player)
    SendStatsUpdate(player)
    RE[RemoteEvents.Names.UpgradeResult]:FireClient(player, {
        stat     = "harvestSpeed",
        newValue = data.harvestSpeed,
        newLevel = data.harvestSpeedLevel,
    })
end)

-- Inventory request
RE[RemoteEvents.Names.RequestInventory].OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data then return end
    RE[RemoteEvents.Names.InventoryUpdate]:FireClient(player, { inventory = data.inventory })
end)

-- Daily streak claim (manual button)
RE[RemoteEvents.Names.RequestClaimStreak].OnServerEvent:Connect(function(player)
    HandleDailyStreak(player)
    SendStatsUpdate(player)
end)

-- Leaderboard request
RE[RemoteEvents.Names.RequestLeaderboard].OnServerEvent:Connect(function(player)
    -- Fetch ordered DataStore leaderboard
    task.spawn(function()
        local leaderboardStore = game:GetService("DataStoreService")
            :GetOrderedDataStore(Config.LEADERBOARD_KEY)
        local ok, pages = pcall(function()
            return leaderboardStore:GetSortedAsync(false, Config.LEADERBOARD_SIZE)
        end)
        if not ok then return end
        local entries: {[string]: any} = {}
        local rank = 1
        while true do
            local page = pages:GetCurrentPage()
            for _, entry in page do
                table.insert(entries, {
                    rank  = rank,
                    name  = entry.key,   -- userId; resolve name client-side or store separately
                    value = entry.value,
                })
                rank += 1
            end
            if pages.IsFinished then break end
            pages:AdvanceToNextPageAsync()
        end
        RE[RemoteEvents.Names.LeaderboardData]:FireClient(player, entries)
    end)
end)

-- ── 7. RemoteFunction handlers ────────────────────────────────

local SeedDataModule = require(game.ReplicatedStorage.Shared.SeedData)

RF[RemoteEvents.FunctionNames.GetSeedInfo].OnServerInvoke = function(_player, seedId: string)
    local ok, def = pcall(SeedDataModule.Get, seedId)
    return ok and def or nil
end

RF[RemoteEvents.FunctionNames.GetUpgradeCost].OnServerInvoke = function(_player, payload: {stat: string, level: number})
    if payload.stat == "luck" then
        return CalcLuckUpgradeCost(payload.level)
    elseif payload.stat == "harvestSpeed" then
        return CalcHarvestSpeedUpgradeCost(payload.level)
    end
    return 0
end

RF[RemoteEvents.FunctionNames.HasGamepass].OnServerInvoke = function(player, passId: number)
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    return ok and owns
end

-- ── 8. Leaderboard update loop ────────────────────────────────
-- Periodically writes totalHarvested to the OrderedDataStore.
task.spawn(function()
    while true do
        task.wait(300)  -- update leaderboard every 5 minutes
        local leaderboardStore = game:GetService("DataStoreService")
            :GetOrderedDataStore(Config.LEADERBOARD_KEY)
        for _, player in Players:GetPlayers() do
            local data = DataManager.GetData(player)
            if data and data.totalHarvested > 0 then
                pcall(function()
                    leaderboardStore:SetAsync(tostring(player.UserId), data.totalHarvested)
                end)
            end
        end
    end
end)

print("[GameManager] Harvest RNG server initialised ✅")
