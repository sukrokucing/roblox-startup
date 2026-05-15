--!strict
-- ============================================================
--  MainClient.client.lua  (LocalScript)
--  Entry point for all client-side game logic.
--  Lives in StarterPlayerScripts (or StarterCharacterScripts).
--
--  Responsibilities:
--    1. Wait for GUI and RemoteEvents to be ready
--    2. Wire UI buttons to RemoteEvent fires
--    3. Handle all S→C events and delegate to UIManager
--    4. Manage client-side plot timer display loop
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Wait for server to create remotes folder
local EventsFolder    = ReplicatedStorage:WaitForChild("Events", 30)
local FunctionsFolder = ReplicatedStorage:WaitForChild("Functions", 30)

if not EventsFolder or not FunctionsFolder then
    error("[MainClient] Remotes folder not found — server may not have started correctly.")
    return
end

local RemoteEventsModule = require(game.ReplicatedStorage.Shared.RemoteEvents)
local UIManager          = require(script.Parent.modules.UIManager)
local SeedData           = require(game.ReplicatedStorage.Shared.SeedData)

-- ── Resolve remote references ─────────────────────────────────

local function GetEvent(name: string): RemoteEvent
    return EventsFolder:WaitForChild(name, 10) :: RemoteEvent
end

local RE: {[string]: RemoteEvent} = {}
for _, name in RemoteEventsModule.Names do
    RE[name] = GetEvent(name)
end

-- ── Resolve GUI elements ──────────────────────────────────────

local GUI          = PlayerGui:WaitForChild("HarvestRNG_GUI") :: ScreenGui
local RollPanel    = GUI:WaitForChild("RollPanel") :: Frame
local RollButton   = RollPanel:WaitForChild("RollButton") :: TextButton
local RollX10Button = RollPanel:WaitForChild("RollX10Button") :: TextButton

local FarmPanel    = GUI:WaitForChild("FarmPanel") :: Frame
local PlotContainer = FarmPanel:WaitForChild("PlotContainer") :: Frame

local UpgradePanel = GUI:WaitForChild("UpgradePanel") :: Frame
local LuckUpgradeBtn  = UpgradePanel:WaitForChild("LuckUpgradeButton") :: TextButton
local SpeedUpgradeBtn = UpgradePanel:WaitForChild("SpeedUpgradeButton") :: TextButton

local InventoryPanel = GUI:WaitForChild("InventoryPanel") :: Frame
local InventoryBtn   = GUI:WaitForChild("HUD"):WaitForChild("InventoryButton") :: TextButton

local LeaderboardPanel = GUI:WaitForChild("LeaderboardPanel") :: Frame
local LeaderboardBtn   = GUI:WaitForChild("HUD"):WaitForChild("LeaderboardButton") :: TextButton

-- ── Client state ──────────────────────────────────────────────

-- Mirrors server plot state; updated on PlotStateUpdate events
type PlotClientState = {
    seedId      : string?,
    plantedAt   : number?,
    isUnlocked  : boolean,
    plotFrame   : Frame?,    -- reference to the GUI frame for this plot
}

local plotStates: {PlotClientState} = {}
local playerStats: {[string]: any} = {}
local playerInventory: {[string]: number} = {}

-- Whether we're currently showing a roll animation (debounce)
local isRolling = false

-- ── Plot UI helpers ───────────────────────────────────────────

local function GetOrCreatePlotFrame(index: number): Frame
    local existing = PlotContainer:FindFirstChild("Plot_" .. index)
    if existing then
        return existing :: Frame
    end

    local frame = Instance.new("Frame")
    frame.Name   = "Plot_" .. index
    frame.Size   = UDim2.fromOffset(90, 90)
    frame.BackgroundColor3 = Color3.fromRGB(80, 55, 30)
    frame.Parent = PlotContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local icon = Instance.new("TextLabel")
    icon.Name                = "Icon"
    icon.Size                = UDim2.new(1, 0, 0.6, 0)
    icon.BackgroundTransparency = 1
    icon.TextScaled          = true
    icon.Font                = Enum.Font.Gotham
    icon.Text                = "🌱"
    icon.Parent              = frame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name           = "Timer"
    timerLabel.Size           = UDim2.new(1, 0, 0.25, 0)
    timerLabel.Position       = UDim2.fromScale(0, 0.65)
    timerLabel.BackgroundTransparency = 1
    timerLabel.TextScaled     = true
    timerLabel.Font           = Enum.Font.Gotham
    timerLabel.Text           = ""
    timerLabel.TextColor3     = Color3.new(1, 1, 1)
    timerLabel.Parent         = frame

    local harvestBtn = Instance.new("TextButton")
    harvestBtn.Name            = "HarvestBtn"
    harvestBtn.Size            = UDim2.new(0.9, 0, 0.25, 0)
    harvestBtn.Position        = UDim2.fromScale(0.05, 0.72)
    harvestBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 50)
    harvestBtn.Text            = "Harvest"
    harvestBtn.TextColor3      = Color3.new(1, 1, 1)
    harvestBtn.Font            = Enum.Font.GothamBold
    harvestBtn.TextScaled      = true
    harvestBtn.Visible         = false
    harvestBtn.Parent          = frame

    -- Wiring harvest button
    harvestBtn.Activated:Connect(function()
        RE[RemoteEventsModule.Names.RequestHarvest]:FireServer(index)
    end)

    -- Plant button (shown when plot is empty)
    local plantBtn = Instance.new("TextButton")
    plantBtn.Name            = "PlantBtn"
    plantBtn.Size            = UDim2.new(0.9, 0, 0.25, 0)
    plantBtn.Position        = UDim2.fromScale(0.05, 0.72)
    plantBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    plantBtn.Text            = "Plant"
    plantBtn.TextColor3      = Color3.new(1, 1, 1)
    plantBtn.Font            = Enum.Font.GothamBold
    plantBtn.TextScaled      = true
    plantBtn.Visible         = true
    plantBtn.Parent          = frame

    -- Plant: opens inventory to pick a seed for this plot
    plantBtn.Activated:Connect(function()
        -- TODO: integrate with inventory seed-picker modal
        -- For now, auto-plant first available seed
        for seedId, count in playerInventory do
            if count > 0 then
                RE[RemoteEventsModule.Names.RequestPlant]:FireServer(index, seedId)
                break
            end
        end
    end)

    -- Unlock button (shown for locked plots)
    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Name            = "UnlockBtn"
    unlockBtn.Size            = UDim2.fromScale(1, 1)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    unlockBtn.BackgroundTransparency = 0.3
    unlockBtn.Text            = "🔒 Unlock"
    unlockBtn.TextColor3      = Color3.new(1, 1, 1)
    unlockBtn.Font            = Enum.Font.GothamBold
    unlockBtn.TextScaled      = true
    unlockBtn.Parent          = frame

    unlockBtn.Activated:Connect(function()
        RE[RemoteEventsModule.Names.RequestUnlockPlot]:FireServer(index)
    end)

    return frame
end

local function RefreshPlotFrame(index: number, state: PlotClientState)
    local frame = GetOrCreatePlotFrame(index)
    local icon       = frame:FindFirstChild("Icon") :: TextLabel
    local timerLbl   = frame:FindFirstChild("Timer") :: TextLabel
    local harvestBtn = frame:FindFirstChild("HarvestBtn") :: TextButton
    local plantBtn   = frame:FindFirstChild("PlantBtn") :: TextButton
    local unlockBtn  = frame:FindFirstChild("UnlockBtn") :: TextButton

    if not state.isUnlocked then
        frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        icon.Text     = "🔒"
        timerLbl.Text = ""
        harvestBtn.Visible = false
        plantBtn.Visible   = false
        unlockBtn.Visible  = true
        return
    end

    unlockBtn.Visible = false
    frame.BackgroundColor3 = Color3.fromRGB(80, 55, 30)

    if state.seedId then
        local seedDef = SeedData.SeedData[state.seedId]
        if seedDef then
            icon.Text = seedDef.emoji
            local rarityColor = UIManager.GetRarityColor(seedDef.rarity)
            icon.TextColor3 = rarityColor
        end
        harvestBtn.Visible = false
        plantBtn.Visible   = false
        -- Timer updated in the heartbeat loop below
    else
        icon.Text = "🌱"
        icon.TextColor3 = Color3.new(1, 1, 1)
        timerLbl.Text   = ""
        harvestBtn.Visible = false
        plantBtn.Visible   = true
    end
end

-- ── Server-to-Client event handlers ──────────────────────────

-- Full initial data load
RE[RemoteEventsModule.Names.PlayerDataLoaded].OnClientEvent:Connect(function(data: {[string]: any})
    playerStats    = data
    playerInventory = (data.inventory :: {[string]: number}?) or {}
    UIManager.UpdateStats(data)
end)

-- Incremental stat updates
RE[RemoteEventsModule.Names.StatsUpdate].OnClientEvent:Connect(function(stats: {[string]: any})
    for k, v in stats do
        playerStats[k] = v
    end
    UIManager.UpdateStats(stats)
end)

-- Plot state sync
RE[RemoteEventsModule.Names.PlotStateUpdate].OnClientEvent:Connect(function(plots: {any})
    for i, plot in plots do
        plotStates[i] = {
            seedId     = plot.seedId,
            plantedAt  = plot.plantedAt,
            isUnlocked = plot.isUnlocked,
            plotFrame  = plotStates[i] and plotStates[i].plotFrame or nil,
        }
        RefreshPlotFrame(i, plotStates[i])
    end
end)

-- Roll results
RE[RemoteEventsModule.Names.RollResult].OnClientEvent:Connect(function(results: {any})
    isRolling = false
    if #results == 1 then
        local r = results[1]
        local seedDef = SeedData.SeedData[r.seedId]
        local emoji   = seedDef and seedDef.emoji or "🌱"
        UIManager.ShowRollResult(emoji, r.seedName, r.rarity)
    else
        -- x10 roll
        local mapped: {{seedName: string, emoji: string, rarity: string}} = {}
        for _, r in results do
            local seedDef = SeedData.SeedData[r.seedId]
            table.insert(mapped, {
                seedName = r.seedName,
                emoji    = seedDef and seedDef.emoji or "🌱",
                rarity   = r.rarity,
            })
        end
        UIManager.ShowRollX10Summary(mapped)
    end

    -- Refresh inventory (seeds added)
    RE[RemoteEventsModule.Names.RequestInventory]:FireServer()
end)

-- Harvest result feedback
RE[RemoteEventsModule.Names.HarvestResult].OnClientEvent:Connect(function(result: {[string]: any})
    UIManager.ShowHarvestPopup(result.coins :: number, result.rarity :: string, nil)
end)

-- Inventory update
RE[RemoteEventsModule.Names.InventoryUpdate].OnClientEvent:Connect(function(payload: {[string]: any})
    playerInventory = (payload.inventory :: {[string]: number}?) or {}
end)

-- Notifications
RE[RemoteEventsModule.Names.Notification].OnClientEvent:Connect(function(payload: {[string]: any})
    UIManager.ShowNotification(payload.message :: string, payload.style :: string?)
end)

-- Daily streak
RE[RemoteEventsModule.Names.DailyStreakClaimed].OnClientEvent:Connect(function(payload: {[string]: any})
    UIManager.ShowStreakBanner(payload.day :: number, payload.coins :: number, payload.gems :: number)
end)

-- Upgrade result
RE[RemoteEventsModule.Names.UpgradeResult].OnClientEvent:Connect(function(payload: {[string]: any})
    UIManager.ShowNotification(
        string.format("✅ %s upgraded to Lv%d!", payload.stat, payload.newLevel),
        "success"
    )
end)

-- Leaderboard data
RE[RemoteEventsModule.Names.LeaderboardData].OnClientEvent:Connect(function(entries: {any})
    -- Populate leaderboard panel (GUI setup lives in Studio)
    -- entries: { rank, name, value }
    local scrollFrame = LeaderboardPanel:FindFirstChild("ScrollFrame") :: ScrollingFrame?
    if not scrollFrame then return end

    scrollFrame:ClearAllChildren()
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent    = scrollFrame

    for i, entry in entries do
        local row = Instance.new("TextLabel")
        row.Size             = UDim2.new(1, 0, 0, 28)
        row.LayoutOrder      = i
        row.BackgroundTransparency = i % 2 == 0 and 0.85 or 0.95
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        row.Text             = string.format("#%d  %s  —  %s 🪙",
            entry.rank,
            tostring(entry.name),
            tostring(entry.value)
        )
        row.TextColor3       = Color3.new(1, 1, 1)
        row.Font             = Enum.Font.Gotham
        row.TextScaled       = true
        row.Parent           = scrollFrame
    end
end)

-- ── Button wiring ─────────────────────────────────────────────

-- Roll (single)
RollButton.Activated:Connect(function()
    if isRolling then return end
    isRolling = true
    RE[RemoteEventsModule.Names.RequestRoll]:FireServer()
end)

-- Roll x10
RollX10Button.Activated:Connect(function()
    if isRolling then return end
    isRolling = true
    RE[RemoteEventsModule.Names.RequestRollX10]:FireServer()
end)

-- Luck upgrade
LuckUpgradeBtn.Activated:Connect(function()
    RE[RemoteEventsModule.Names.RequestUpgradeLuck]:FireServer()
end)

-- Harvest Speed upgrade
SpeedUpgradeBtn.Activated:Connect(function()
    RE[RemoteEventsModule.Names.RequestUpgradeHarvestSpeed]:FireServer()
end)

-- Inventory panel toggle
InventoryBtn.Activated:Connect(function()
    local visible = not InventoryPanel.Visible
    InventoryPanel.Visible = visible
    if visible then
        RE[RemoteEventsModule.Names.RequestInventory]:FireServer()
    end
end)

-- Leaderboard panel toggle
LeaderboardBtn.Activated:Connect(function()
    local visible = not LeaderboardPanel.Visible
    LeaderboardPanel.Visible = visible
    if visible then
        RE[RemoteEventsModule.Names.RequestLeaderboard]:FireServer()
    end
end)

-- Upgrade panel toggle
local UpgradeBtn = GUI:WaitForChild("HUD"):WaitForChild("UpgradeButton") :: TextButton
UpgradeBtn.Activated:Connect(function()
    UpgradePanel.Visible = not UpgradePanel.Visible
end)

-- ── Plot timer update heartbeat ────────────────────────────────
-- Updates timer labels on plots every second without re-fetching from server.

task.spawn(function()
    while true do
        task.wait(1)
        for i, state in plotStates do
            if state.isUnlocked and state.seedId and state.plantedAt then
                local frame = GetOrCreatePlotFrame(i)
                local timerLbl   = frame:FindFirstChild("Timer") :: TextLabel?
                local harvestBtn = frame:FindFirstChild("HarvestBtn") :: TextButton?
                local plantBtn   = frame:FindFirstChild("PlantBtn") :: TextButton?

                if timerLbl then
                    local harvestSpeed   = (playerStats.harvestSpeed :: number?) or 1.0
                    local seedDef        = SeedData.SeedData[state.seedId :: string]
                    local baseTime       = seedDef and seedDef.harvestTime or 60
                    local effectiveTime  = math.ceil(baseTime / math.max(harvestSpeed, 0.1))
                    local elapsed        = os.time() - (state.plantedAt :: number)
                    local remaining      = math.max(0, effectiveTime - elapsed)

                    if remaining == 0 then
                        timerLbl.Text = "✅ Ready!"
                        timerLbl.TextColor3 = Color3.fromRGB(80, 220, 80)
                        if harvestBtn then harvestBtn.Visible = true end
                        if plantBtn  then plantBtn.Visible = false end
                    else
                        local mins = math.floor(remaining / 60)
                        local secs = remaining % 60
                        timerLbl.Text = string.format("%d:%02d", mins, secs)
                        timerLbl.TextColor3 = Color3.new(1, 1, 1)
                        if harvestBtn then harvestBtn.Visible = false end
                    end
                end
            end
        end
    end
end)

-- Request initial inventory
RE[RemoteEventsModule.Names.RequestInventory]:FireServer()

print("[MainClient] Harvest RNG client initialised ✅")
