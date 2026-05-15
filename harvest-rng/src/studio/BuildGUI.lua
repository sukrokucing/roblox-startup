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

local function Stroke(parent: Instance, color: Color3, thickness: number)
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness; s.Parent = parent
end

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
    Size = UDim2.new(1, 0, 0, 54),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(14, 14, 24),
    BackgroundTransparency = 0.05,
}) :: Frame

-- stat labels
local function StatLabel(name: string, text: string, order: number)
    local lbl = Make("TextLabel", hud, {
        Name = name,
        Size = UDim2.fromOffset(148, 38),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    })
    return lbl
end

local hudLayout = Make("UIListLayout", hud, {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 10),
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
        Size = UDim2.fromOffset(118, 36),
        BackgroundColor3 = Color3.fromRGB(44, 72, 150),
        Text = text,
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        LayoutOrder = order,
    }) :: TextButton
    Corner(btn, 8)
    return btn
end

NavBtn("InventoryButton",   "🎒 Inventory",  5)
NavBtn("UpgradeButton",     "⬆️ Upgrades",   6)
NavBtn("LeaderboardButton", "🏆 Leaderboard",7)

-- ── Roll Panel ────────────────────────────────────────────────

local rollPanel = Make("Frame", screen, {
    Name = "RollPanel",
    Size = UDim2.fromOffset(300, 210),
    Position = UDim2.new(0, 14, 1, -224),
    BackgroundColor3 = Color3.fromRGB(18, 18, 32),
    BackgroundTransparency = 0.08,
}) :: Frame
Corner(rollPanel, 14)
Stroke(rollPanel, Color3.fromRGB(60, 60, 90), 1.5)

Make("TextLabel", rollPanel, {
    Name = "Title",
    Size = UDim2.new(1,0,0,30),
    Position = UDim2.fromOffset(0,8),
    BackgroundTransparency = 1,
    Text = "🎲  Roll for Seeds",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
})

-- Result display area
local resultFrame = Make("Frame", rollPanel, {
    Name = "ResultFrame",
    Size = UDim2.new(1,-18,0,84),
    Position = UDim2.fromOffset(9,42),
    BackgroundColor3 = Color3.fromRGB(36, 36, 58),
    BackgroundTransparency = 0.25,
}) :: Frame
Corner(resultFrame, 10)

Make("TextLabel", resultFrame, {
    Name = "SeedEmoji",
    Size = UDim2.fromScale(0.22, 1),
    Position = UDim2.fromOffset(4,0),
    BackgroundTransparency = 1,
    Text = "🌱",
    TextScaled = true,
    ZIndex = 2,
})
Make("TextLabel", resultFrame, {
    Name = "SeedName",
    Size = UDim2.new(0.55, 0, 0.52, 0),
    Position = UDim2.fromScale(0.24, 0.04),
    BackgroundTransparency = 1,
    Text = "Roll to discover",
    TextColor3 = Color3.fromRGB(200,200,200),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
})
Make("TextLabel", resultFrame, {
    Name = "RarityLabel",
    Size = UDim2.new(0.55, 0, 0.36, 0),
    Position = UDim2.fromScale(0.24, 0.60),
    BackgroundTransparency = 1,
    Text = "???",
    TextColor3 = Color3.fromRGB(160,160,160),
    Font = Enum.Font.Gotham,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
})

-- Roll buttons
local function RollBtn(name: string, text: string, yPos: number, bgColor: Color3)
    local btn = Make("TextButton", rollPanel, {
        Name = name,
        Size = UDim2.new(1,-18,0,36),
        Position = UDim2.fromOffset(9, yPos),
        BackgroundColor3 = bgColor,
        Text = text,
        TextColor3 = Color3.fromRGB(18,18,18),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
    }) :: TextButton
    Corner(btn, 9)
    return btn
end

RollBtn("RollButton",    "🎲  Roll  (50 coins)",      132, Color3.fromRGB(60, 190, 80))
RollBtn("RollX10Button", "🎰  Roll ×10  (450 coins)", 174, Color3.fromRGB(210, 155, 30))

-- ── Farm Panel ────────────────────────────────────────────────

local farmPanel = Make("Frame", screen, {
    Name = "FarmPanel",
    Size = UDim2.new(1,-330,1,-68),
    Position = UDim2.fromOffset(322, 60),
    BackgroundColor3 = Color3.fromRGB(30, 48, 22),
    BackgroundTransparency = 0.6,
}) :: Frame
Corner(farmPanel, 10)

Make("TextLabel", farmPanel, {
    Name = "Title",
    Size = UDim2.new(1,0,0,28),
    BackgroundTransparency = 1,
    Text = "🌾  Your Farm",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
})

local plotContainer = Make("ScrollingFrame", farmPanel, {
    Name = "PlotContainer",
    Size = UDim2.new(1,-8,1,-32),
    Position = UDim2.fromOffset(4, 30),
    BackgroundTransparency = 1,
    ScrollBarThickness = 5,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0,0,0,0),
}) :: ScrollingFrame

Make("UIGridLayout", plotContainer, {
    CellSize = UDim2.fromOffset(92,92),
    CellPadding = UDim2.fromOffset(5,5),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
Make("UIPadding", plotContainer, {
    PaddingTop = UDim.new(0,4), PaddingLeft = UDim.new(0,4)
})

-- ── Upgrade Panel (hidden) ────────────────────────────────────

local upgradePanel = Make("Frame", screen, {
    Name = "UpgradePanel",
    Size = UDim2.fromOffset(290, 270),
    Position = UDim2.new(0.5,-145,0.5,-135),
    BackgroundColor3 = Color3.fromRGB(18,18,34),
    BackgroundTransparency = 0.04,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(upgradePanel, 14)
Stroke(upgradePanel, Color3.fromRGB(70,70,110), 1.5)

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
        Size = UDim2.new(1,-20,0,62),
        Position = UDim2.fromOffset(10,yPos),
        BackgroundColor3 = Color3.fromRGB(40,75,40),
        Text = text,
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        ZIndex = 11,
    }) :: TextButton
    Corner(btn, 10)
    Stroke(btn, Color3.fromRGB(60,120,60), 1)
    return btn
end

UpgradeBtn("LuckUpgradeButton",  "🍀  Upgrade Luck\n+5 Luck per level - 200 coins",     52)
UpgradeBtn("SpeedUpgradeButton", "⚡  Upgrade Harvest Speed\n-10% grow time - 350 coins", 124)

Make("TextButton", upgradePanel, {
    Name = "CloseBtn",
    Size = UDim2.fromOffset(28,28),
    Position = UDim2.new(1,-34,0,8),
    BackgroundColor3 = Color3.fromRGB(160,40,40),
    Text = "✕",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 12,
})

-- ── Inventory Panel (hidden) ──────────────────────────────────

local inventoryPanel = Make("Frame", screen, {
    Name = "InventoryPanel",
    Size = UDim2.fromOffset(350, 450),
    Position = UDim2.new(0.5,-175,0.5,-225),
    BackgroundColor3 = Color3.fromRGB(16,16,28),
    BackgroundTransparency = 0.04,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(inventoryPanel, 14)
Stroke(inventoryPanel, Color3.fromRGB(60,60,100), 1.5)

Make("TextLabel", inventoryPanel, {
    Name = "Title",
    Size = UDim2.new(1,0,0,36),
    Position = UDim2.fromOffset(0,8),
    BackgroundTransparency = 1,
    Text = "🎒  Inventory",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 11,
})

local invScroll = Make("ScrollingFrame", inventoryPanel, {
    Name = "ScrollFrame",
    Size = UDim2.new(1,-12,1,-50),
    Position = UDim2.fromOffset(6,44),
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
    Size = UDim2.fromOffset(370, 470),
    Position = UDim2.new(0.5,-185,0.5,-235),
    BackgroundColor3 = Color3.fromRGB(16,16,28),
    BackgroundTransparency = 0.04,
    Visible = false,
    ZIndex = 10,
}) :: Frame
Corner(leaderboardPanel, 14)
Stroke(leaderboardPanel, Color3.fromRGB(100,80,20), 1.5)

Make("TextLabel", leaderboardPanel, {
    Name = "Title",
    Size = UDim2.new(1,0,0,36),
    Position = UDim2.fromOffset(0,8),
    BackgroundTransparency = 1,
    Text = "🏆  Leaderboard",
    TextColor3 = Color3.fromRGB(255,200,60),
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    ZIndex = 11,
})

local lbScroll = Make("ScrollingFrame", leaderboardPanel, {
    Name = "ScrollFrame",
    Size = UDim2.new(1,-12,1,-50),
    Position = UDim2.fromOffset(6,44),
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
