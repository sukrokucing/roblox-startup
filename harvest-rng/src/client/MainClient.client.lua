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
local ClientModules      = script.Parent:WaitForChild("modules")
local UIManager          = require(ClientModules:WaitForChild("UIManager"))
local SeedData           = require(game.ReplicatedStorage.Shared.SeedData)
local Config             = require(game.ReplicatedStorage.Shared.Config)

-- ── Resolve remote references ─────────────────────────────────

local function GetEvent(name: string): RemoteEvent
    return EventsFolder:WaitForChild(name, 10) :: RemoteEvent
end

local function GetFunction(name: string): RemoteFunction
    return FunctionsFolder:WaitForChild(name, 10) :: RemoteFunction
end

local RE: {[string]: RemoteEvent} = {}
for _, name in RemoteEventsModule.Names do
    RE[name] = GetEvent(name)
end

local RF: {[string]: RemoteFunction} = {}
for _, name in RemoteEventsModule.FunctionNames do
    RF[name] = GetFunction(name)
end

-- ── Resolve GUI elements ──────────────────────────────────────

local GUI          = PlayerGui:WaitForChild("HarvestRNG_GUI") :: ScreenGui
local HUD          = GUI:WaitForChild("HUD") :: Frame
local RollPanel    = GUI:WaitForChild("RollPanel") :: Frame
local RollButton   = RollPanel:WaitForChild("RollButton") :: TextButton
local RollX10Button = RollPanel:WaitForChild("RollX10Button") :: TextButton

local FarmPanel    = GUI:WaitForChild("FarmPanel") :: Frame
local FarmTitle    = FarmPanel:WaitForChild("Title") :: TextLabel
local FarmToggleButton = FarmPanel:WaitForChild("ToggleFarmButton") :: TextButton
local PlotContainer = FarmPanel:WaitForChild("PlotContainer") :: ScrollingFrame

local UpgradePanel = GUI:WaitForChild("UpgradePanel") :: Frame
local LuckUpgradeBtn  = UpgradePanel:WaitForChild("LuckUpgradeButton") :: TextButton
local SpeedUpgradeBtn = UpgradePanel:WaitForChild("SpeedUpgradeButton") :: TextButton

local InventoryPanel = GUI:WaitForChild("InventoryPanel") :: Frame
local InventoryScrollFrame = InventoryPanel:WaitForChild("ScrollFrame") :: ScrollingFrame
local InventoryBtn   = HUD:WaitForChild("InventoryButton") :: TextButton

local LeaderboardPanel = GUI:WaitForChild("LeaderboardPanel") :: Frame
local LeaderboardBtn   = HUD:WaitForChild("LeaderboardButton") :: TextButton
local LeaderboardCloseBtn = LeaderboardPanel:FindFirstChild("CloseBtn") :: TextButton?

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

type InventoryEntry = {
    seedId: string,
    count: number,
    def: SeedData.SeedDefinition,
}

local WORLD_UNLOCKED_COLOR = Color3.fromRGB(126, 82, 43)
local WORLD_LOCKED_COLOR = Color3.fromRGB(78, 78, 78)
local WORLD_EMPTY_SPROUT_COLOR = Color3.fromRGB(75, 185, 65)

local UI_BG = Color3.fromRGB(13, 15, 24)
local UI_PANEL = Color3.fromRGB(24, 27, 42)
local UI_PANEL_SOFT = Color3.fromRGB(31, 36, 54)
local UI_STROKE = Color3.fromRGB(93, 106, 150)
local UI_GREEN = Color3.fromRGB(61, 190, 94)
local UI_GOLD = Color3.fromRGB(232, 174, 43)
local UI_BLUE = Color3.fromRGB(69, 122, 236)
local UI_RED = Color3.fromRGB(199, 62, 58)

local function EnsureCorner(instance: Instance, radius: number)
    local corner = instance:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.Parent = instance
    end
    corner.CornerRadius = UDim.new(0, radius)
end

local function EnsureStroke(instance: Instance, color: Color3, thickness: number, transparency: number?)
    local stroke = instance:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = instance
    end
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency or 0
end

local function StyleButton(button: TextButton, color: Color3, textColor: Color3?)
    button.BackgroundColor3 = color
    button.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.AutoButtonColor = true
    EnsureCorner(button, 8)
    EnsureStroke(button, Color3.fromRGB(255, 255, 255), 1, 0.82)
end

local function StylePanel(panel: Frame, strokeColor: Color3?)
    panel.BackgroundColor3 = UI_PANEL
    panel.BackgroundTransparency = 0.06
    EnsureCorner(panel, 12)
    EnsureStroke(panel, strokeColor or UI_STROKE, 1.5, 0.18)
end

local function EnsureCloseButton(panel: Frame): TextButton
    local existing = panel:FindFirstChild("CloseBtn")
    if existing and existing:IsA("TextButton") then
        return existing
    end

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseBtn"
    closeButton.ZIndex = panel.ZIndex + 2
    closeButton.Parent = panel
    return closeButton
end

local function ApplyInterfaceRefresh()
    GUI.IgnoreGuiInset = false

    HUD.Size = UDim2.new(1, 0, 0, 52)
    HUD.Position = UDim2.fromOffset(0, 0)
    HUD.BackgroundColor3 = Color3.fromRGB(9, 10, 18)
    HUD.BackgroundTransparency = 0.18

    local hudLayout = HUD:FindFirstChildOfClass("UIListLayout")
    if hudLayout then
        hudLayout.Padding = UDim.new(0, 8)
        hudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    end

    for _, child in HUD:GetChildren() do
        if child:IsA("TextLabel") then
            child.Size = UDim2.fromOffset(if child.Name == "LuckLabel" then 160 else 116, 36)
            child.BackgroundColor3 = Color3.fromRGB(24, 27, 42)
            child.BackgroundTransparency = 0.08
            child.TextColor3 = Color3.fromRGB(244, 247, 255)
            child.TextXAlignment = Enum.TextXAlignment.Center
            child.TextScaled = true
            EnsureCorner(child, 10)
            EnsureStroke(child, Color3.fromRGB(255, 255, 255), 1, 0.88)
        elseif child:IsA("TextButton") then
            child.Size = UDim2.fromOffset(if child.Name == "LeaderboardButton" then 134 else 118, 36)
            StyleButton(child, UI_BLUE)
        end
    end

    StylePanel(RollPanel, Color3.fromRGB(84, 92, 140))
    RollPanel.Size = UDim2.fromOffset(292, 196)
    RollPanel.Position = UDim2.new(0, 12, 1, -208)
    local rollTitle = RollPanel:FindFirstChild("Title")
    if rollTitle and rollTitle:IsA("TextLabel") then
        rollTitle.Size = UDim2.new(1, -20, 0, 34)
        rollTitle.Position = UDim2.fromOffset(10, 8)
        rollTitle.TextXAlignment = Enum.TextXAlignment.Left
    end
    local resultFrame = RollPanel:FindFirstChild("ResultFrame")
    if resultFrame and resultFrame:IsA("Frame") then
        resultFrame.Size = UDim2.new(1, -20, 0, 78)
        resultFrame.Position = UDim2.fromOffset(10, 46)
        resultFrame.BackgroundColor3 = UI_PANEL_SOFT
        resultFrame.BackgroundTransparency = 0.04
        EnsureCorner(resultFrame, 10)
    end
    RollButton.Size = UDim2.new(1, -20, 0, 32)
    RollButton.Position = UDim2.fromOffset(10, 130)
    StyleButton(RollButton, UI_GREEN, Color3.fromRGB(10, 18, 12))
    RollX10Button.Size = UDim2.new(1, -20, 0, 32)
    RollX10Button.Position = UDim2.fromOffset(10, 166)
    StyleButton(RollX10Button, UI_GOLD, Color3.fromRGB(18, 14, 4))

    StylePanel(FarmPanel, Color3.fromRGB(78, 129, 82))
    FarmPanel.Size = UDim2.fromOffset(348, 392)
    FarmPanel.Position = UDim2.new(1, -360, 0, 64)
    FarmPanel.BackgroundTransparency = 0.16
    FarmTitle.Size = UDim2.new(1, -92, 0, 34)
    FarmTitle.Position = UDim2.fromOffset(12, 6)
    FarmTitle.TextXAlignment = Enum.TextXAlignment.Left
    FarmToggleButton.Size = UDim2.fromOffset(70, 28)
    FarmToggleButton.Position = UDim2.new(1, -80, 0, 8)
    StyleButton(FarmToggleButton, Color3.fromRGB(48, 116, 65))
    PlotContainer.Size = UDim2.new(1, -14, 1, -48)
    PlotContainer.Position = UDim2.fromOffset(7, 42)
    PlotContainer.ScrollBarThickness = 4
    local grid = PlotContainer:FindFirstChildOfClass("UIGridLayout")
    if grid then
        grid.CellSize = UDim2.fromOffset(76, 76)
        grid.CellPadding = UDim2.fromOffset(6, 6)
    end

    StylePanel(UpgradePanel, UI_STROKE)
    UpgradePanel.Size = UDim2.fromOffset(360, 254)
    UpgradePanel.Position = UDim2.new(0.5, -180, 0.5, -127)
    StyleButton(LuckUpgradeBtn, Color3.fromRGB(46, 126, 60))
    StyleButton(SpeedUpgradeBtn, Color3.fromRGB(198, 135, 34), Color3.fromRGB(18, 12, 4))
    LuckUpgradeBtn.Size = UDim2.new(1, -24, 0, 64)
    LuckUpgradeBtn.Position = UDim2.fromOffset(12, 58)
    SpeedUpgradeBtn.Size = UDim2.new(1, -24, 0, 64)
    SpeedUpgradeBtn.Position = UDim2.fromOffset(12, 132)

    StylePanel(InventoryPanel, UI_STROKE)
    InventoryPanel.Size = UDim2.fromOffset(380, 430)
    InventoryPanel.Position = UDim2.new(0.5, -190, 0.5, -215)
    InventoryScrollFrame.Size = UDim2.new(1, -16, 1, -56)
    InventoryScrollFrame.Position = UDim2.fromOffset(8, 48)

    StylePanel(LeaderboardPanel, UI_GOLD)
    LeaderboardPanel.Size = UDim2.fromOffset(400, 430)
    LeaderboardPanel.Position = UDim2.new(0.5, -200, 0.5, -215)

    local closeButtons = {
        EnsureCloseButton(UpgradePanel),
        EnsureCloseButton(InventoryPanel),
        EnsureCloseButton(LeaderboardPanel),
    }
    for _, closeButton in closeButtons do
        if closeButton and closeButton:IsA("TextButton") then
            closeButton.Text = "X"
            closeButton.Size = UDim2.fromOffset(30, 30)
            closeButton.Position = UDim2.new(1, -38, 0, 8)
            StyleButton(closeButton, UI_RED)
        end
    end
end

ApplyInterfaceRefresh()

local InventoryCloseBtn = InventoryPanel:FindFirstChild("CloseBtn") :: TextButton?

local FARM_EXPANDED_SIZE = FarmPanel.Size
local FARM_EXPANDED_POSITION = FarmPanel.Position
local FARM_COLLAPSED_SIZE = UDim2.fromOffset(196, 44)
local FARM_COLLAPSED_POSITION = UDim2.new(1, -208, 0, 64)
local farmCollapsed = false

local function SetFarmCollapsed(collapsed: boolean)
    farmCollapsed = collapsed
    PlotContainer.Visible = not collapsed
    FarmPanel.Size = if collapsed then FARM_COLLAPSED_SIZE else FARM_EXPANDED_SIZE
    FarmPanel.Position = if collapsed then FARM_COLLAPSED_POSITION else FARM_EXPANDED_POSITION
    FarmPanel.BackgroundTransparency = if collapsed then 0.12 else 0.16
    FarmTitle.Size = if collapsed then UDim2.new(1, -88, 1, 0) else UDim2.new(1, -92, 0, 34)
    FarmTitle.Position = if collapsed then UDim2.fromOffset(12, 0) else UDim2.fromOffset(12, 6)
    FarmTitle.Text = if collapsed then "Your Farm" else "🌾  Your Farm"
    FarmToggleButton.Text = if collapsed then "Show" else "Hide"
end

FarmToggleButton.Activated:Connect(function()
    SetFarmCollapsed(not farmCollapsed)
end)

local function FormatCoins(amount: number): string
    local formatted = tostring(math.floor(amount))
    while true do
        local nextFormatted, replacements = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        formatted = nextFormatted
        if replacements == 0 then
            break
        end
    end
    return formatted
end

local function CalcFallbackUpgradeCost(stat: string, level: number): number
    if stat == "luck" then
        return math.floor(Config.LUCK_UPGRADE_BASE_COST * (Config.LUCK_UPGRADE_SCALE ^ level))
    elseif stat == "harvestSpeed" then
        return math.floor(Config.HARVEST_SPEED_BASE_COST * (Config.HARVEST_SPEED_SCALE ^ level))
    end
    return 0
end

local function GetUpgradeCost(stat: string, level: number): number
    local fallback = CalcFallbackUpgradeCost(stat, level)
    local remote = RF[RemoteEventsModule.FunctionNames.GetUpgradeCost]
    if not remote then
        return fallback
    end

    local ok, cost = pcall(function()
        return remote:InvokeServer({
            stat = stat,
            level = level,
        })
    end)

    if ok and type(cost) == "number" and cost > 0 and cost < math.huge then
        return math.floor(cost)
    end
    return fallback
end

local upgradeTextRefreshId = 0

local function RefreshUpgradeButtonText()
    upgradeTextRefreshId += 1
    local refreshId = upgradeTextRefreshId

    local luckLevel = math.max(0, math.floor(tonumber(playerStats.luckLevel) or 0))
    local speedLevel = math.max(0, math.floor(tonumber(playerStats.harvestSpeedLevel) or 0))
    local speedReduction = math.floor(((1 - Config.HARVEST_SPEED_FACTOR) * 100) + 0.5)

    task.spawn(function()
        local luckMaxed = luckLevel >= Config.MAX_LUCK_LEVEL
        local speedMaxed = speedLevel >= Config.MAX_HARVEST_SPEED_LEVEL
        local luckCost = if luckMaxed then 0 else GetUpgradeCost("luck", luckLevel)
        local speedCost = if speedMaxed then 0 else GetUpgradeCost("harvestSpeed", speedLevel)

        if refreshId ~= upgradeTextRefreshId then
            return
        end

        LuckUpgradeBtn.Active = not luckMaxed
        LuckUpgradeBtn.AutoButtonColor = not luckMaxed
        LuckUpgradeBtn.Text = if luckMaxed
            then string.format("🍀  Luck Maxed\nLv %d / %d", luckLevel, Config.MAX_LUCK_LEVEL)
            else string.format(
                "🍀  Upgrade Luck\n+%d Luck per level - %s coins",
                Config.LUCK_PER_UPGRADE,
                FormatCoins(luckCost)
            )

        SpeedUpgradeBtn.Active = not speedMaxed
        SpeedUpgradeBtn.AutoButtonColor = not speedMaxed
        SpeedUpgradeBtn.Text = if speedMaxed
            then string.format("⚡  Harvest Speed Maxed\nLv %d / %d", speedLevel, Config.MAX_HARVEST_SPEED_LEVEL)
            else string.format(
                "⚡  Upgrade Harvest Speed\n-%d%% grow time - %s coins",
                speedReduction,
                FormatCoins(speedCost)
            )
    end)
end

local function RenderInventoryPanel()
    InventoryScrollFrame:ClearAllChildren()

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = InventoryScrollFrame

    local rarityOrder: {[string]: number} = {
        Mythic = 6,
        Legendary = 5,
        Epic = 4,
        Rare = 3,
        Uncommon = 2,
        Common = 1,
    }

    local entries: {InventoryEntry} = {}
    for seedId, count in playerInventory do
        if count > 0 then
            local ok, def = pcall(SeedData.Get, seedId)
            if ok then
                table.insert(entries, {
                    seedId = seedId,
                    count = count,
                    def = def,
                })
            end
        end
    end

    table.sort(entries, function(a: InventoryEntry, b: InventoryEntry): boolean
        local rarityA = rarityOrder[a.def.rarity] or 0
        local rarityB = rarityOrder[b.def.rarity] or 0
        if rarityA ~= rarityB then return rarityA > rarityB end
        if a.count ~= b.count then return a.count > b.count end
        return a.def.name < b.def.name
    end)

    if #entries == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -8, 0, 64)
        empty.BackgroundTransparency = 1
        empty.Text = "No seeds yet. Roll first."
        empty.TextColor3 = Color3.fromRGB(170, 170, 190)
        empty.Font = Enum.Font.Gotham
        empty.TextScaled = true
        empty.LayoutOrder = 1
        empty.Parent = InventoryScrollFrame
        return
    end

    for i, entry in entries do
        local row = Instance.new("Frame")
        row.Name = "Seed_" .. entry.seedId
        row.Size = UDim2.new(1, -8, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(32, 32, 48)
        row.BackgroundTransparency = 0.08
        row.LayoutOrder = i
        row.Parent = InventoryScrollFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = row

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.fromOffset(48, 48)
        icon.Position = UDim2.fromOffset(6, 5)
        icon.BackgroundTransparency = 1
        icon.Text = ""
        icon.TextScaled = true
        icon.Parent = row
        UIManager.RenderSeedIcon(icon, entry.def.icon, entry.def.name, icon.ZIndex + 1)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -116, 0, 30)
        nameLabel.Position = UDim2.fromOffset(60, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = entry.def.name
        nameLabel.TextColor3 = UIManager.GetRarityColor(entry.def.rarity)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextScaled = true
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(1, -116, 0, 22)
        rarityLabel.Position = UDim2.fromOffset(60, 32)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = entry.def.rarity
        rarityLabel.TextColor3 = Color3.fromRGB(165, 165, 190)
        rarityLabel.Font = Enum.Font.Gotham
        rarityLabel.TextScaled = true
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
        rarityLabel.Parent = row

        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.fromOffset(52, 34)
        countLabel.Position = UDim2.new(1, -60, 0.5, -17)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = "x" .. tostring(entry.count)
        countLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
        countLabel.Font = Enum.Font.GothamBold
        countLabel.TextScaled = true
        countLabel.TextXAlignment = Enum.TextXAlignment.Right
        countLabel.Parent = row
    end
end

local function SetWorldDescendantsVisible(root: Instance, visible: boolean)
    for _, descendant in root:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Transparency = if visible then 0 else 1
            descendant.CanCollide = visible
        elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
            descendant.Enabled = visible
        elseif descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            descendant.Visible = visible
        end
    end
end

local function EnsureWorldSprout(plotPart: BasePart): BasePart
    local sprout = plotPart:FindFirstChild("StarterSprout")
    if sprout and sprout:IsA("BasePart") then
        return sprout
    end

    local newSprout = Instance.new("Part")
    newSprout.Name = "StarterSprout"
    newSprout.Size = Vector3.new(0.8, 0.8, 0.8)
    newSprout.Shape = Enum.PartType.Block
    newSprout.Material = Enum.Material.Grass
    newSprout.Color = WORLD_EMPTY_SPROUT_COLOR
    newSprout.Anchored = true
    newSprout.CanCollide = false
    newSprout.CFrame = plotPart.CFrame + Vector3.new(0, (plotPart.Size.Y / 2) + 0.45, 0)
    newSprout.Parent = plotPart
    return newSprout
end

local function HideWorldCrop(plotPart: BasePart)
    local crop = plotPart:FindFirstChild("CropVisual")
    if crop then
        crop:Destroy()
    end
end

local function EnsureWorldCrop(plotPart: BasePart, seedId: string): Model
    local seedDef = SeedData.Get(seedId)
    local cropOffset = Vector3.new(0, (plotPart.Size.Y / 2) + 0.33, 0)
    local crop = plotPart:FindFirstChild("CropVisual")
    if crop and crop:IsA("Model") and crop:GetAttribute("SeedId") == seedId then
        local stem = crop:FindFirstChild("Stem")
        if stem and stem:IsA("BasePart") then
            stem.CFrame = plotPart.CFrame + cropOffset
        end
        return crop
    end
    if crop then
        crop:Destroy()
    end

    local newCrop = Instance.new("Model")
    newCrop.Name = "CropVisual"
    newCrop:SetAttribute("SeedId", seedId)
    newCrop.Parent = plotPart

    local stem = Instance.new("Part")
    stem.Name = "Stem"
    stem.Size = Vector3.new(0.28, 0.65, 0.28)
    stem.Material = Enum.Material.Grass
    stem.Color = Color3.fromRGB(70, 180, 70)
    stem.Anchored = true
    stem.CanCollide = false
    stem.CFrame = plotPart.CFrame + cropOffset
    stem.Parent = newCrop

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CropBillboard"
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 70
    billboard.Size = UDim2.fromOffset(42, 42)
    billboard.StudsOffset = Vector3.new(0, 0.65, 0)
    billboard.Parent = stem

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromScale(1, 1)
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.TextScaled = true
    icon.TextColor3 = Color3.new(1, 1, 1)
    icon.TextStrokeColor3 = Color3.fromRGB(12, 12, 18)
    icon.TextStrokeTransparency = 0.35
    icon.Parent = billboard
    UIManager.RenderSeedIcon(icon, seedDef.icon, seedDef.name, icon.ZIndex + 1)

    return newCrop
end

local function SyncWorldPlotVisual(index: number, state: PlotClientState)
    local world = workspace:FindFirstChild("HarvestRNG_World")
    local plotFolder = world and world:FindFirstChild("WorldPlots_5x5")
    local plotPart = plotFolder and plotFolder:FindFirstChild("Plot_" .. index)
    if not plotPart or not plotPart:IsA("BasePart") then return end

    plotPart.Color = if state.isUnlocked then WORLD_UNLOCKED_COLOR else WORLD_LOCKED_COLOR

    local lockedMarker = plotPart:FindFirstChild("LockedMarker")
    if lockedMarker then
        SetWorldDescendantsVisible(lockedMarker, not state.isUnlocked)
        if lockedMarker:IsA("BasePart") then
            lockedMarker.Transparency = if state.isUnlocked then 1 else 0
            lockedMarker.CanCollide = not state.isUnlocked
        end
    end

    local sprout = plotPart:FindFirstChild("StarterSprout")
    if state.isUnlocked and not state.seedId then
        HideWorldCrop(plotPart)
        local visibleSprout = if sprout and sprout:IsA("BasePart") then sprout else EnsureWorldSprout(plotPart)
        visibleSprout.Transparency = 0
    elseif sprout and sprout:IsA("BasePart") then
        sprout.Transparency = 1
    end

    if state.isUnlocked and state.seedId then
        EnsureWorldCrop(plotPart, state.seedId)
    elseif not state.seedId then
        HideWorldCrop(plotPart)
    end
end

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

    -- Plant: open InventoryManager seed-picker modal
    plantBtn.Activated:Connect(function()
        local InventoryManager = require(ClientModules:WaitForChild("InventoryManager"))
        InventoryManager.OpenPicker(index, playerInventory, function(seedId: string)
            RE[RemoteEventsModule.Names.RequestPlant]:FireServer(index, seedId)
        end)
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
        UIManager.ClearSeedIcon(icon)
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
        local seedDef = SeedData.Get(state.seedId)
        if seedDef then
            UIManager.RenderSeedIcon(icon, seedDef.icon, seedDef.name, icon.ZIndex + 1)
            local rarityColor = UIManager.GetRarityColor(seedDef.rarity)
            icon.TextColor3 = rarityColor
        end
        harvestBtn.Visible = false
        plantBtn.Visible   = false
        -- Timer updated in the heartbeat loop below
    else
        UIManager.ClearSeedIcon(icon)
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
    RefreshUpgradeButtonText()
    RenderInventoryPanel()
end)

-- Incremental stat updates
RE[RemoteEventsModule.Names.StatsUpdate].OnClientEvent:Connect(function(stats: {[string]: any})
    for k, v in stats do
        playerStats[k] = v
    end
    UIManager.UpdateStats(stats)
    RefreshUpgradeButtonText()
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
        SyncWorldPlotVisual(i, plotStates[i])
    end
end)

-- Roll results
RE[RemoteEventsModule.Names.RollResult].OnClientEvent:Connect(function(results: {any})
    isRolling = false
    if #results == 1 then
        local r = results[1]
        local seedDef = SeedData.Get(r.seedId)
        local icon = seedDef and seedDef.icon or nil
        UIManager.ShowRollResult(icon, r.seedName, r.rarity)
    else
        -- x10 roll
        local mapped: {{seedName: string, icon: any?, rarity: string}} = {}
        for _, r in results do
            local seedDef = SeedData.Get(r.seedId)
            table.insert(mapped, {
                seedName = r.seedName,
                icon     = seedDef and seedDef.icon or nil,
                rarity   = r.rarity,
            })
        end
        UIManager.ShowRollX10Summary(mapped)
    end

end)

-- Harvest result feedback
RE[RemoteEventsModule.Names.HarvestResult].OnClientEvent:Connect(function(result: {[string]: any})
    UIManager.ShowHarvestPopup(result.coins :: number, result.rarity :: string, nil)
end)

-- Inventory update
RE[RemoteEventsModule.Names.InventoryUpdate].OnClientEvent:Connect(function(payload: {[string]: any})
    playerInventory = (payload.inventory :: {[string]: number}?) or {}
    RenderInventoryPanel()
end)

-- Notifications
RE[RemoteEventsModule.Names.Notification].OnClientEvent:Connect(function(payload: {[string]: any})
    -- FIX #12: server rejections (style="error") never fire RollResult, so reset isRolling here
    -- to prevent the roll button being permanently locked after an insufficient-coins rejection
    if payload.style == "error" then
        isRolling = false
    end
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
    RefreshUpgradeButtonText()
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
        row.Text             = string.format("#%d  %s  -  %s coins",
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
        RenderInventoryPanel()
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

if LeaderboardCloseBtn then
    LeaderboardCloseBtn.Activated:Connect(function()
        LeaderboardPanel.Visible = false
    end)
end

if InventoryCloseBtn then
    InventoryCloseBtn.Activated:Connect(function()
        InventoryPanel.Visible = false
    end)
end

-- Upgrade panel toggle
local UpgradeBtn = GUI:WaitForChild("HUD"):WaitForChild("UpgradeButton") :: TextButton
UpgradeBtn.Activated:Connect(function()
    UpgradePanel.Visible = not UpgradePanel.Visible
    if UpgradePanel.Visible then
        RefreshUpgradeButtonText()
    end
end)

-- FIX N-NEW-2: wire the CloseBtn inside UpgradePanel (created by BuildGUI but never connected)
local UpgradePanelCloseBtn = UpgradePanel:FindFirstChild("CloseBtn") :: TextButton?
if UpgradePanelCloseBtn then
    UpgradePanelCloseBtn.Activated:Connect(function()
        UpgradePanel.Visible = false
    end)
end

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
                    -- FIX N-NEW-1: apply rarity harvest-time modifier (matches server RNGManager.CalcHarvestTime)
                    -- FIX N-NEW-3: pcall SeedData.Get to avoid crashing the entire timer coroutine
                    local ok, seedDef = pcall(SeedData.Get, state.seedId :: string)
                    if not ok or not seedDef then continue end
                    local RARITY_TIME_MODS: {[string]: number} = {
                        Common=1.00, Uncommon=1.00, Rare=0.95,
                        Epic=0.90, Legendary=0.85, Mythic=0.80,
                    }
                    local rarityMod     = RARITY_TIME_MODS[seedDef.rarity] or 1.0
                    local effectiveTime = math.ceil(seedDef.harvestTime * rarityMod / math.max(harvestSpeed, 0.1))
                    local elapsed       = os.time() - (state.plantedAt :: number)
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
RefreshUpgradeButtonText()
RE[RemoteEventsModule.Names.RequestInventory]:FireServer()

print("[MainClient] Harvest RNG client initialised ✅")
