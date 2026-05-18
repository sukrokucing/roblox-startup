--!strict
--[[
  BuildGUI.lua — Harvest RNG GUI Builder
  
  Run from Roblox Studio Command Bar:
    1. Paste contents into View > Command Bar
    2. Press Enter — GUI is built under StarterGui instantly
  
  Idempotent: destroys any existing HarvestRNG_GUI first.
  Re-run safely after code changes.
]]

local StarterGui = game:GetService("StarterGui")

-- Remove old if exists
local old = StarterGui:FindFirstChild("HarvestRNG_GUI")
if old then old:Destroy() print("[BuildGUI] Removed old HarvestRNG_GUI") end

-- ── Helpers ───────────────────────────────────────────────────

local function Make(cls: string, parent: Instance, props: {[string]: any}): Instance
    local inst = Instance.new(cls)
    for k, v in props do (inst :: any)[k] = v end
    inst.Parent = parent
    return inst
end

local function Corner(parent: Instance, r: number)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = parent
end

local function Stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.Parent = parent
end

local function TextConstraint(parent: Instance, minSize: number, maxSize: number)
    local c = Instance.new("UITextSizeConstraint")
    c.MinTextSize = minSize
    c.MaxTextSize = maxSize
    c.Parent = parent
end

local UI_PANEL = Color3.fromRGB(24, 27, 42)
local UI_PANEL_SOFT = Color3.fromRGB(31, 36, 54)
local UI_STROKE = Color3.fromRGB(93, 106, 150)
local UI_BLUE = Color3.fromRGB(69, 122, 236)
local UI_GREEN = Color3.fromRGB(61, 190, 94)
local UI_GOLD = Color3.fromRGB(232, 174, 43)
local UI_RED = Color3.fromRGB(199, 62, 58)

-- ── Root ScreenGui ─────────────────────────────────────────────

local screen = Make("ScreenGui", StarterGui, {
    Name = "HarvestRNG_GUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false,
}) :: ScreenGui

-- ── HUD ───────────────────────────────────────────────────────

local hud = Make("Frame", screen, {
    Name = "HUD",
    Size = UDim2.new(1, 0, 0, 52),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(9, 10, 18),
    BackgroundTransparency = 0.18,
    ClipsDescendants = true,
}) :: Frame

-- stat labels
local function StatLabel(name: string, text: string, order: number)
    local lbl = Make("TextLabel", hud, {
        Name = name,
        Size = UDim2.fromOffset(if name == "LuckLabel" then 160 else 116, 36),
        BackgroundColor3 = UI_PANEL,
        BackgroundTransparency = 0.08,
        Text = text,
        TextColor3 = Color3.fromRGB(244,247,255),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = order,
    })
    Corner(lbl, 10)
    Stroke(lbl, Color3.fromRGB(255, 255, 255), 1, 0.88)
    TextConstraint(lbl, 12, 28)
    return lbl
end

local hudLayout = Make("UIListLayout", hud, {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
})
Make("UIPadding", hud, {
    PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12)
})

StatLabel("CoinsLabel",  "Coins 250",    1)
StatLabel("GemsLabel",   "💎 0",          2)
StatLabel("LuckLabel",   "🍀 Luck 0 (Lv0)", 3)
StatLabel("StreakLabel", "🔥 Streak: 0",  4)

-- HUD right side nav buttons
local function NavBtn(name: string, text: string, order: number)
    local btn = Make("TextButton", hud, {
        Name = name,
        Size = UDim2.fromOffset(if name == "LeaderboardButton" then 134 else 118, 36),
        BackgroundColor3 = UI_BLUE,
        Text = text,
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        LayoutOrder = order,
    }) :: TextButton
    Corner(btn, 8)
    Stroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.82)
    TextConstraint(btn, 12, 28)
    return btn
end

NavBtn("InventoryButton",   "🎒 Inventory",  5)
NavBtn("UpgradeButton",     "⬆️ Upgrades",   6)
NavBtn("LeaderboardButton", "🏆 Leaderboard",7)

-- ── Roll Panel ────────────────────────────────────────────────

local rollPanel = Make("Frame", screen, {
    Name = "RollPanel",
    Size = UDim2.fromOffset(292, 196),
    Position = UDim2.new(0, 12, 1, -208),
    BackgroundColor3 = UI_PANEL,
    BackgroundTransparency = 0.06,
}) :: Frame
Corner(rollPanel, 12)
Stroke(rollPanel, Color3.fromRGB(84, 92, 140), 1.5, 0.18)

Make("TextLabel", rollPanel, {
    Name = "Title",
    Size = UDim2.new(1,-20,0,34),
    Position = UDim2.fromOffset(10,8),
    BackgroundTransparency = 1,
    Text = "🎲  Roll for Seeds",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
})
TextConstraint(rollPanel.Title, 14, 32)

-- Result display area
local resultFrame = Make("Frame", rollPanel, {
    Name = "ResultFrame",
    Size = UDim2.new(1,-20,0,78),
    Position = UDim2.fromOffset(10,46),
    BackgroundColor3 = UI_PANEL_SOFT,
    BackgroundTransparency = 0.04,
}) :: Frame
Corner(resultFrame, 10)

Make("TextLabel", resultFrame, {
    Name = "SeedEmoji",
    Size = UDim2.fromOffset(64, 64),
    Position = UDim2.fromOffset(12, 10),
    BackgroundTransparency = 1,
    Text = "🌱",
    TextScaled = true,
    ZIndex = 2,
})
Make("TextLabel", resultFrame, {
    Name = "SeedName",
    Size = UDim2.new(1, -94, 0, 42),
    Position = UDim2.fromOffset(84, 8),
    BackgroundTransparency = 1,
    Text = "Roll to discover",
    TextColor3 = Color3.fromRGB(255,255,255),
    TextStrokeColor3 = Color3.fromRGB(12,12,18),
    TextStrokeTransparency = 0.45,
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
})
TextConstraint(resultFrame.SeedName, 12, 30)
Make("TextLabel", resultFrame, {
    Name = "RarityLabel",
    Size = UDim2.new(1, -94, 0, 28),
    Position = UDim2.fromOffset(84, 50),
    BackgroundTransparency = 1,
    Text = "???",
    TextColor3 = Color3.fromRGB(235,245,255),
    TextStrokeColor3 = Color3.fromRGB(12,12,18),
    TextStrokeTransparency = 0.55,
    Font = Enum.Font.Gotham,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
})
TextConstraint(resultFrame.RarityLabel, 10, 24)

-- Roll buttons
local function RollBtn(name: string, text: string, yPos: number, bgColor: Color3)
    local btn = Make("TextButton", rollPanel, {
        Name = name,
        Size = UDim2.new(1,-20,0,32),
        Position = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = bgColor,
        Text = text,
        TextColor3 = Color3.fromRGB(18,18,18),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
    }) :: TextButton
    Corner(btn, 8)
    Stroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.82)
    TextConstraint(btn, 14, 30)
    return btn
end

RollBtn("RollButton",    "🎲  Roll  (50 coins)",      130, UI_GREEN)
RollBtn("RollX10Button", "🎰  Roll ×10  (450 coins)", 166, UI_GOLD)

-- ── Farm Panel ────────────────────────────────────────────────

local farmPanel = Make("Frame", screen, {
    Name = "FarmPanel",
    Size = UDim2.fromOffset(240, 44),
    Position = UDim2.new(1, -252, 0, 64),
    BackgroundColor3 = UI_PANEL,
    BackgroundTransparency = 0.12,
}) :: Frame
Corner(farmPanel, 12)
Stroke(farmPanel, Color3.fromRGB(78, 129, 82), 1.5, 0.18)

Make("TextLabel", farmPanel, {
    Name = "Title",
    Size = UDim2.new(1,-88,1,0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Text = "Your Farm",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
})
TextConstraint(farmPanel.Title, 14, 34)

local farmToggle = Make("TextButton", farmPanel, {
    Name = "ToggleFarmButton",
    Size = UDim2.fromOffset(70, 28),
    Position = UDim2.new(1, -80, 0, 8),
    BackgroundColor3 = Color3.fromRGB(48, 116, 65),
    Text = "Show",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 3,
}) :: TextButton
Corner(farmToggle, 8)
Stroke(farmToggle, Color3.fromRGB(255, 255, 255), 1, 0.82)
TextConstraint(farmToggle, 13, 26)

local plotContainer = Make("ScrollingFrame", farmPanel, {
    Name = "PlotContainer",
    Size = UDim2.new(1,-14,1,-48),
    Position = UDim2.fromOffset(7, 42),
    BackgroundTransparency = 1,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0,0,0,0),
    Visible = false,
}) :: ScrollingFrame

Make("UIGridLayout", plotContainer, {
    CellSize = UDim2.fromOffset(76,76),
    CellPadding = UDim2.fromOffset(6,6),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
Make("UIPadding", plotContainer, {
    PaddingTop = UDim.new(0,4), PaddingLeft = UDim.new(0,4)
})

-- ── Upgrade Panel (hidden) ────────────────────────────────────

local upgradePanel = Make("Frame", screen, {
    Name = "UpgradePanel",
    Size = UDim2.fromOffset(360, 254),
    Position = UDim2.new(0.5,-180,0.5,-127),
    BackgroundColor3 = UI_PANEL,
    BackgroundTransparency = 0.06,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(upgradePanel, 12)
Stroke(upgradePanel, UI_STROKE, 1.5, 0.18)

Make("TextLabel", upgradePanel, {
    Name = "Title",
    Size = UDim2.new(1,0,0,36),
    Position = UDim2.fromOffset(0,8),
    BackgroundTransparency = 1,
    Text = "⬆️  Upgrades",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 11,
})

local function UpgradeBtn(name: string, text: string, yPos: number)
    local btn = Make("TextButton", upgradePanel, {
        Name = name,
        Size = UDim2.new(1,-24,0,64),
        Position = UDim2.fromOffset(12,yPos),
        BackgroundColor3 = if name == "LuckUpgradeButton" then Color3.fromRGB(46, 126, 60) else Color3.fromRGB(198, 135, 34),
        Text = text,
        TextColor3 = if name == "LuckUpgradeButton" then Color3.new(1,1,1) else Color3.fromRGB(18, 12, 4),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        ZIndex = 11,
    }) :: TextButton
    Corner(btn, 8)
    Stroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.82)
    return btn
end

UpgradeBtn("LuckUpgradeButton",  "🍀  Upgrade Luck\n+5 Luck per level - 200 coins",     58)
UpgradeBtn("SpeedUpgradeButton", "⚡  Upgrade Harvest Speed\n-10% grow time - 350 coins", 132)

local upgradeClose = Make("TextButton", upgradePanel, {
    Name = "CloseBtn",
    Size = UDim2.fromOffset(30,30),
    Position = UDim2.new(1,-38,0,8),
    BackgroundColor3 = UI_RED,
    Text = "X",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 12,
}) :: TextButton
Corner(upgradeClose, 8)
Stroke(upgradeClose, Color3.fromRGB(255, 255, 255), 1, 0.82)

-- ── Inventory Panel (hidden) ──────────────────────────────────

local inventoryPanel = Make("Frame", screen, {
    Name = "InventoryPanel",
    Size = UDim2.fromOffset(380, 430),
    Position = UDim2.new(0.5,-190,0.5,-215),
    BackgroundColor3 = UI_PANEL,
    BackgroundTransparency = 0.06,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(inventoryPanel, 12)
Stroke(inventoryPanel, UI_STROKE, 1.5, 0.18)

Make("TextLabel", inventoryPanel, {
    Name = "Title",
    Size = UDim2.new(1,-48,0,36),
    Position = UDim2.fromOffset(8,8),
    BackgroundTransparency = 1,
    Text = "🎒  Inventory",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 11,
})

local inventoryClose = Make("TextButton", inventoryPanel, {
    Name = "CloseBtn",
    Size = UDim2.fromOffset(30,30),
    Position = UDim2.new(1,-38,0,8),
    BackgroundColor3 = UI_RED,
    Text = "X",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 12,
}) :: TextButton
Corner(inventoryClose, 8)
Stroke(inventoryClose, Color3.fromRGB(255, 255, 255), 1, 0.82)

local invScroll = Make("ScrollingFrame", inventoryPanel, {
    Name = "ScrollFrame",
    Size = UDim2.new(1,-16,1,-56),
    Position = UDim2.fromOffset(8,48),
    BackgroundTransparency = 1,
    ScrollBarThickness = 5,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0,0,0,0),
    ZIndex = 11,
})
Make("UIListLayout", invScroll, {
    Padding = UDim.new(0,5),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

-- ── Leaderboard Panel (hidden) ────────────────────────────────

local leaderboardPanel = Make("Frame", screen, {
    Name = "LeaderboardPanel",
    Size = UDim2.fromOffset(400, 430),
    Position = UDim2.new(0.5,-200,0.5,-215),
    BackgroundColor3 = UI_PANEL,
    BackgroundTransparency = 0.06,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(leaderboardPanel, 12)
Stroke(leaderboardPanel, UI_GOLD, 1.5, 0.18)

Make("TextLabel", leaderboardPanel, {
    Name = "Title",
    Size = UDim2.new(1,-48,0,36),
    Position = UDim2.fromOffset(0,8),
    BackgroundTransparency = 1,
    Text = "🏆  Leaderboard",
    TextColor3 = Color3.fromRGB(255,200,60),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 11,
})

local leaderboardClose = Make("TextButton", leaderboardPanel, {
    Name = "CloseBtn",
    Size = UDim2.fromOffset(30,30),
    Position = UDim2.new(1,-38,0,8),
    BackgroundColor3 = UI_RED,
    Text = "X",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 12,
}) :: TextButton
Corner(leaderboardClose, 8)
Stroke(leaderboardClose, Color3.fromRGB(255, 255, 255), 1, 0.82)

local lbScroll = Make("ScrollingFrame", leaderboardPanel, {
    Name = "ScrollFrame",
    Size = UDim2.new(1,-16,1,-56),
    Position = UDim2.fromOffset(8,48),
    BackgroundTransparency = 1,
    ScrollBarThickness = 5,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0,0,0,0),
    ZIndex = 11,
})
Make("UIListLayout", lbScroll, {
    Padding = UDim.new(0,3),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

-- ── Notification Frame ────────────────────────────────────────

local notifFrame = Make("Frame", screen, {
    Name = "NotificationFrame",
    Size = UDim2.fromOffset(370, 46),
    Position = UDim2.new(0.5,-185,1,-70),
    BackgroundColor3 = Color3.fromRGB(26,26,42),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 20,
}) :: Frame
Corner(notifFrame, 10)

Make("TextLabel", notifFrame, {
    Name = "NotifLabel",
    Size = UDim2.new(1,-16,1,0),
    Position = UDim2.fromOffset(8,0),
    BackgroundTransparency = 1,
    Text = "Notification goes here",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.Gotham,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21,
})

-- ── Done ──────────────────────────────────────────────────────
local count = #screen:GetDescendants()
print(string.format("✅  HarvestRNG_GUI built — %d instances. Press Play to test!", count))
