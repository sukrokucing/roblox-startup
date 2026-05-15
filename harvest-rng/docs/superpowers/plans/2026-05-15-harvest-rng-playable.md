# Harvest RNG — Make It Playable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Harvest RNG to a fully playable state — all GUI, all wiring, Rojo project file, and a Studio setup script so everything can be loaded and played immediately.

**Architecture:** The game is already 100% logic-complete on server and client Luau. What's missing is: (1) the GUI hierarchy (currently referenced but not built), (2) the InventoryManager UI module for seed-picking, (3) a Rojo `default.project.json` so the repo maps to Studio services correctly, and (4) a `StudioSetup.plugin.lua` script that programmatically builds the full GUI tree in one click.

**Tech Stack:** Luau --!strict, Roblox Studio, Rojo 7.x, TweenService, BillboardGui

---

## Gap Analysis (what exists vs. what's missing)

### ✅ Exists (complete)
- `src/shared/Config.lua` — all constants
- `src/shared/RemoteEvents.lua` — all event names
- `src/shared/SeedData.lua` — all 30 seeds
- `src/server/GameManager.server.lua` — full server bootstrap + all remote handlers
- `src/server/modules/DataManager.lua` — DataStore + autosave
- `src/server/modules/RNGManager.lua` — luck-weighted RNG
- `src/server/modules/FarmManager.lua` — plant/grow/harvest/unlock
- `src/client/MainClient.client.lua` — all client wiring (references GUI by name)
- `src/client/modules/UIManager.lua` — all animation + display logic

### ❌ Missing (blocks playability)
1. **`default.project.json`** — Rojo project file mapping src/ → Studio services
2. **`src/client/modules/InventoryManager.lua`** — seed-picker modal (plant workflow)
3. **`src/studio/BuildGUI.plugin.lua`** — Studio plugin that creates the entire GUI tree
4. **`src/studio/StudioSetup.server.lua`** — Server script version of GUI builder (runs in Studio only)
5. **`docs/PLAY_GUIDE.md`** — How to set up and playtest in Roblox Studio

---

## Task 1: Rojo Project File

**Files:**
- Create: `harvest-rng/default.project.json`

- [ ] **Step 1: Write default.project.json**

```json
{
  "name": "HarvestRNG",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "GameManager": {
        "$path": "src/server/GameManager.server.lua"
      },
      "modules": {
        "$className": "Folder",
        "DataManager": { "$path": "src/server/modules/DataManager.lua" },
        "RNGManager":  { "$path": "src/server/modules/RNGManager.lua" },
        "FarmManager": { "$path": "src/server/modules/FarmManager.lua" }
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": {
        "$className": "Folder",
        "Config":       { "$path": "src/shared/Config.lua" },
        "RemoteEvents": { "$path": "src/shared/RemoteEvents.lua" },
        "SeedData":     { "$path": "src/shared/SeedData.lua" }
      }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "MainClient": { "$path": "src/client/MainClient.client.lua" },
        "modules": {
          "$className": "Folder",
          "UIManager":        { "$path": "src/client/modules/UIManager.lua" },
          "InventoryManager": { "$path": "src/client/modules/InventoryManager.lua" }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Commit**
```bash
cd /tmp/roblox-startup
git add harvest-rng/default.project.json
git commit -m "feat: add Rojo project file"
```

---

## Task 2: InventoryManager Client Module

The plant button in MainClient currently auto-plants the first seed found. InventoryManager replaces that with a proper modal showing all seeds in inventory with rarity colours, counts, and a "Plant" button per row.

**Files:**
- Create: `src/client/modules/InventoryManager.lua`
- Modify: `src/client/MainClient.client.lua` — replace auto-plant logic with `InventoryManager.OpenPicker(plotIndex)`

- [ ] **Step 1: Write InventoryManager.lua**

Full module — opens a seed-picker modal, fires RequestPlant on selection, closes modal.

```lua
--!strict
-- InventoryManager.lua (Client Module)
-- Renders a seed-picker modal when the player clicks "Plant" on a plot.
-- Caller: MainClient calls InventoryManager.OpenPicker(plotIndex, inventory, onPick)

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local GUI         = PlayerGui:WaitForChild("HarvestRNG_GUI") :: ScreenGui

local UIManager = require(script.Parent.UIManager)
local SeedData  = require(game.ReplicatedStorage.Shared.SeedData)

local InventoryManager = {}

-- Active modal reference (only one open at a time)
local activeModal: Frame? = nil

local function CloseModal()
    if activeModal then
        activeModal:Destroy()
        activeModal = nil
    end
end

--- Opens a seed-picker modal for a specific plot.
--- @param plotIndex  Which plot the player wants to plant in
--- @param inventory  Current {seedId → count} table
--- @param onPick     Callback(seedId: string) fired when player picks a seed
function InventoryManager.OpenPicker(
    plotIndex: number,
    inventory: {[string]: number},
    onPick: (seedId: string) -> ()
)
    CloseModal()

    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name                 = "InventoryPickerOverlay"
    overlay.Size                 = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex               = 30
    overlay.Parent               = GUI
    activeModal = overlay

    -- Modal container
    local modal = Instance.new("Frame")
    modal.Name                   = "PickerModal"
    modal.Size                   = UDim2.fromOffset(380, 420)
    modal.Position               = UDim2.fromScale(0.5, 0.5)
    modal.AnchorPoint            = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3       = Color3.fromRGB(25, 25, 35)
    modal.BackgroundTransparency = 0.05
    modal.ZIndex                 = 31
    modal.Parent                 = overlay

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = modal

    -- Title
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, -40, 0, 36)
    title.Position               = UDim2.fromOffset(20, 12)
    title.BackgroundTransparency = 1
    title.Text                   = string.format("🌱 Plant on Plot %d", plotIndex)
    title.TextColor3             = Color3.new(1, 1, 1)
    title.Font                   = Enum.Font.GothamBold
    title.TextScaled             = true
    title.ZIndex                 = 32
    title.Parent                 = modal

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size                = UDim2.fromOffset(28, 28)
    closeBtn.Position            = UDim2.new(1, -36, 0, 10)
    closeBtn.BackgroundColor3    = Color3.fromRGB(180, 50, 50)
    closeBtn.Text                = "✕"
    closeBtn.TextColor3          = Color3.new(1, 1, 1)
    closeBtn.Font                = Enum.Font.GothamBold
    closeBtn.TextScaled          = true
    closeBtn.ZIndex              = 32
    closeBtn.Parent              = modal

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.Activated:Connect(CloseModal)
    overlay.Activated:Connect(CloseModal)  -- click backdrop to close

    -- Scroll frame for seed rows
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                  = UDim2.new(1, -20, 1, -70)
    scroll.Position              = UDim2.fromOffset(10, 58)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness    = 6
    scroll.ScrollBarImageColor3  = Color3.fromRGB(100, 100, 130)
    scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex                = 32
    scroll.Parent                = modal

    local layout = Instance.new("UIListLayout")
    layout.Padding      = UDim.new(0, 6)
    layout.SortOrder    = Enum.SortOrder.LayoutOrder
    layout.Parent       = scroll

    -- Sort seeds: by rarity (rarest first), then by count
    local rarityOrder: {[string]: number} = {
        Mythic = 6, Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1
    }

    type SeedEntry = { seedId: string, count: number, def: SeedData.SeedDefinition }
    local entries: {SeedEntry} = {}
    for seedId, count in inventory do
        if count > 0 then
            local ok, def = pcall(SeedData.Get, seedId)
            if ok and def then
                table.insert(entries, { seedId = seedId, count = count, def = def })
            end
        end
    end
    table.sort(entries, function(a, b)
        local ra = rarityOrder[a.def.rarity] or 0
        local rb = rarityOrder[b.def.rarity] or 0
        if ra ~= rb then return ra > rb end
        return a.count > b.count
    end)

    if #entries == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size                   = UDim2.new(1, 0, 0, 50)
        empty.BackgroundTransparency = 1
        empty.Text                   = "No seeds in inventory!\nRoll to get seeds first. 🎲"
        empty.TextColor3             = Color3.fromRGB(160, 160, 160)
        empty.Font                   = Enum.Font.Gotham
        empty.TextScaled             = true
        empty.ZIndex                 = 33
        empty.Parent                 = scroll
    end

    for i, entry in entries do
        local row = Instance.new("Frame")
        row.Name                 = "SeedRow_" .. entry.seedId
        row.Size                 = UDim2.new(1, -8, 0, 52)
        row.BackgroundColor3     = Color3.fromRGB(35, 35, 50)
        row.BackgroundTransparency = 0.1
        row.LayoutOrder          = i
        row.ZIndex               = 33
        row.Parent               = scroll

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 8)
        rowCorner.Parent = row

        -- Emoji
        local emojiLabel = Instance.new("TextLabel")
        emojiLabel.Size                   = UDim2.fromOffset(44, 44)
        emojiLabel.Position               = UDim2.fromOffset(6, 4)
        emojiLabel.BackgroundTransparency = 1
        emojiLabel.Text                   = entry.def.emoji
        emojiLabel.TextScaled             = true
        emojiLabel.ZIndex                 = 34
        emojiLabel.Parent                 = row

        -- Name + rarity
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size                   = UDim2.new(0.45, 0, 0.5, 0)
        nameLabel.Position               = UDim2.fromOffset(54, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text                   = entry.def.name
        nameLabel.TextColor3             = UIManager.GetRarityColor(entry.def.rarity)
        nameLabel.Font                   = Enum.Font.GothamBold
        nameLabel.TextScaled             = true
        nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
        nameLabel.ZIndex                 = 34
        nameLabel.Parent                 = row

        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size                   = UDim2.new(0.45, 0, 0.4, 0)
        rarityLabel.Position               = UDim2.fromOffset(54, 26)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text                   = entry.def.rarity .. " · ×" .. entry.count
        rarityLabel.TextColor3             = Color3.fromRGB(160, 160, 180)
        rarityLabel.Font                   = Enum.Font.Gotham
        rarityLabel.TextScaled             = true
        rarityLabel.TextXAlignment         = Enum.TextXAlignment.Left
        rarityLabel.ZIndex                 = 34
        rarityLabel.Parent                 = row

        -- Plant button
        local plantBtn = Instance.new("TextButton")
        plantBtn.Size                = UDim2.fromOffset(72, 34)
        plantBtn.Position            = UDim2.new(1, -80, 0.5, -17)
        plantBtn.BackgroundColor3    = UIManager.GetRarityColor(entry.def.rarity)
        plantBtn.Text                = "Plant"
        plantBtn.TextColor3          = Color3.fromRGB(20, 20, 20)
        plantBtn.Font                = Enum.Font.GothamBold
        plantBtn.TextScaled          = true
        plantBtn.ZIndex              = 34
        plantBtn.Parent              = row

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = plantBtn

        local capturedSeedId = entry.seedId
        plantBtn.Activated:Connect(function()
            CloseModal()
            onPick(capturedSeedId)
        end)
    end

    -- Pop-in tween
    modal.Size = UDim2.fromOffset(380, 0)
    TweenService:Create(modal, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(380, 420)
    }):Play()
end

function InventoryManager.Close()
    CloseModal()
end

return InventoryManager
```

- [ ] **Step 2: Update PlantBtn wiring in MainClient.client.lua**

Find the `plantBtn.Activated` block (around line 162) and replace it:

```lua
-- OLD (auto-plant first seed):
plantBtn.Activated:Connect(function()
    for seedId, count in playerInventory do
        if count > 0 then
            RE[RemoteEventsModule.Names.RequestPlant]:FireServer(index, seedId)
            break
        end
    end
end)

-- NEW (open picker modal):
plantBtn.Activated:Connect(function()
    local InventoryManager = require(script.Parent.modules.InventoryManager)
    InventoryManager.OpenPicker(index, playerInventory, function(seedId: string)
        RE[RemoteEventsModule.Names.RequestPlant]:FireServer(index, seedId)
    end)
end)
```

- [ ] **Step 3: Commit**
```bash
cd /tmp/roblox-startup
git add harvest-rng/src/client/modules/InventoryManager.lua harvest-rng/src/client/MainClient.client.lua
git commit -m "feat: InventoryManager seed-picker modal"
```

---

## Task 3: Studio GUI Builder Script

This is the most critical missing piece. MainClient and UIManager reference GUI elements by name — they must exist in Studio. This script creates the entire GUI tree programmatically so the developer just runs it once in Studio's command bar (or as a plugin).

**Files:**
- Create: `src/studio/BuildGUI.lua` — run from Studio command bar to create the full ScreenGui

- [ ] **Step 1: Write BuildGUI.lua**

```lua
--[[
  BuildGUI.lua — Harvest RNG GUI Builder
  
  Run this script from the Roblox Studio Command Bar to create
  the complete HarvestRNG_GUI ScreenGui under StarterGui.
  
  USAGE:
    1. Open Roblox Studio with the game loaded
    2. Open View > Command Bar
    3. Paste and run: require(game.ServerStorage.BuildGUI)
       OR copy-paste the full script body into the command bar

  This script is idempotent — running it twice replaces the old GUI.
]]

local StarterGui = game:GetService("StarterGui")

-- Remove old GUI if it exists
local old = StarterGui:FindFirstChild("HarvestRNG_GUI")
if old then old:Destroy() end

-- Helper
local function Make(className: string, parent: Instance, props: {[string]: any}): Instance
    local inst = Instance.new(className)
    for k, v in props do
        (inst :: any)[k] = v
    end
    inst.Parent = parent
    return inst
end

local function Corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

-- ── Root ScreenGui ────────────────────────────────────────────
local screenGui = Make("ScreenGui", StarterGui, {
    Name               = "HarvestRNG_GUI",
    ResetOnSpawn       = false,
    ZIndexBehavior     = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset     = false,
}) :: ScreenGui

-- ── HUD ──────────────────────────────────────────────────────
local hud = Make("Frame", screenGui, {
    Name                   = "HUD",
    Size                   = UDim2.new(1, 0, 0, 52),
    Position               = UDim2.fromScale(0, 0),
    BackgroundColor3       = Color3.fromRGB(18, 18, 28),
    BackgroundTransparency = 0.1,
}) :: Frame
Corner(hud, 0)

Make("UIListLayout", hud, {
    FillDirection   = Enum.FillDirection.Horizontal,
    Padding         = UDim.new(0, 14),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Center,
})
Make("UIPadding", hud, {
    PaddingLeft  = UDim.new(0, 14),
    PaddingRight = UDim.new(0, 14),
})

local function HudLabel(name: string, defaultText: string)
    return Make("TextLabel", hud, {
        Name                   = name,
        Size                   = UDim2.fromOffset(130, 36),
        BackgroundTransparency = 1,
        Text                   = defaultText,
        TextColor3             = Color3.new(1, 1, 1),
        Font                   = Enum.Font.GothamBold,
        TextScaled             = true,
        TextXAlignment         = Enum.TextXAlignment.Left,
    })
end

HudLabel("CoinsLabel",  "🪙 0")
HudLabel("GemsLabel",   "💎 0")
HudLabel("LuckLabel",   "🍀 Luck 0 (Lv0)")
HudLabel("StreakLabel", "🔥 Streak: 0")

-- HUD right-side buttons
local function HudBtn(name: string, text: string, xOffset: number)
    local btn = Make("TextButton", hud, {
        Name             = name,
        Size             = UDim2.fromOffset(110, 36),
        BackgroundColor3 = Color3.fromRGB(50, 80, 160),
        Text             = text,
        TextColor3       = Color3.new(1, 1, 1),
        Font             = Enum.Font.GothamBold,
        TextScaled       = true,
    }) :: TextButton
    Corner(btn, 8)
    return btn
end

HudBtn("InventoryButton",   "🎒 Inventory",  0)
HudBtn("UpgradeButton",     "⬆️ Upgrades",   0)
HudBtn("LeaderboardButton", "🏆 Leaderboard", 0)

-- ── Roll Panel ───────────────────────────────────────────────
local rollPanel = Make("Frame", screenGui, {
    Name             = "RollPanel",
    Size             = UDim2.fromOffset(300, 200),
    Position         = UDim2.new(0, 16, 1, -216),
    BackgroundColor3 = Color3.fromRGB(20, 20, 32),
    BackgroundTransparency = 0.1,
}) :: Frame
Corner(rollPanel, 14)

Make("TextLabel", rollPanel, {
    Name                   = "Title",
    Size                   = UDim2.new(1, 0, 0, 30),
    Position               = UDim2.fromOffset(0, 8),
    BackgroundTransparency = 1,
    Text                   = "🎲 Roll for Seeds",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
})

-- Result frame (hidden by default, revealed during animation)
local resultFrame = Make("Frame", rollPanel, {
    Name             = "ResultFrame",
    Size             = UDim2.new(1, -20, 0, 80),
    Position         = UDim2.fromOffset(10, 42),
    BackgroundColor3 = Color3.fromRGB(40, 40, 60),
    BackgroundTransparency = 0.3,
}) :: Frame
Corner(resultFrame, 10)

Make("TextLabel", resultFrame, {
    Name                   = "SeedEmoji",
    Size                   = UDim2.fromScale(0.25, 1),
    BackgroundTransparency = 1,
    Text                   = "🌱",
    TextScaled             = true,
})
Make("TextLabel", resultFrame, {
    Name                   = "SeedName",
    Size                   = UDim2.new(0.5, 0, 0.55, 0),
    Position               = UDim2.fromScale(0.27, 0.05),
    BackgroundTransparency = 1,
    Text                   = "???",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
    TextXAlignment         = Enum.TextXAlignment.Left,
})
Make("TextLabel", resultFrame, {
    Name                   = "RarityLabel",
    Size                   = UDim2.new(0.5, 0, 0.35, 0),
    Position               = UDim2.fromScale(0.27, 0.62),
    BackgroundTransparency = 1,
    Text                   = "✦ Common ✦",
    TextColor3             = Color3.fromRGB(200, 200, 200),
    Font                   = Enum.Font.Gotham,
    TextScaled             = true,
    TextXAlignment         = Enum.TextXAlignment.Left,
})

-- Roll buttons
local function RollBtn(name: string, text: string, yPos: number, color: Color3)
    local btn = Make("TextButton", rollPanel, {
        Name             = name,
        Size             = UDim2.new(1, -20, 0, 36),
        Position         = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = color,
        Text             = text,
        TextColor3       = Color3.fromRGB(20, 20, 20),
        Font             = Enum.Font.GothamBold,
        TextScaled       = true,
    }) :: TextButton
    Corner(btn, 8)
    return btn
end

RollBtn("RollButton",   "🎲 Roll (50 🪙)",      130, Color3.fromRGB(80, 200, 80))
RollBtn("RollX10Button","🎰 Roll ×10 (450 🪙)", 172, Color3.fromRGB(200, 160, 40))

-- ── Farm Panel ───────────────────────────────────────────────
local farmPanel = Make("Frame", screenGui, {
    Name             = "FarmPanel",
    Size             = UDim2.new(1, -340, 1, -68),
    Position         = UDim2.fromOffset(332, 60),
    BackgroundColor3 = Color3.fromRGB(40, 60, 30),
    BackgroundTransparency = 0.7,
}) :: Frame
Corner(farmPanel, 10)

Make("TextLabel", farmPanel, {
    Name                   = "Title",
    Size                   = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    Text                   = "🌾 Your Farm",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
})

local plotContainer = Make("ScrollingFrame", farmPanel, {
    Name                  = "PlotContainer",
    Size                  = UDim2.new(1, -10, 1, -36),
    Position              = UDim2.fromOffset(5, 30),
    BackgroundTransparency = 1,
    ScrollBarThickness    = 6,
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
}) :: ScrollingFrame

local gridLayout = Make("UIGridLayout", plotContainer, {
    CellSize    = UDim2.fromOffset(92, 92),
    CellPadding = UDim2.fromOffset(6, 6),
})

-- ── Upgrade Panel (hidden by default) ───────────────────────
local upgradePanel = Make("Frame", screenGui, {
    Name                   = "UpgradePanel",
    Size                   = UDim2.fromOffset(280, 250),
    Position               = UDim2.new(0.5, -140, 0.5, -125),
    BackgroundColor3       = Color3.fromRGB(20, 20, 35),
    BackgroundTransparency = 0.05,
    Visible                = false,
}) :: Frame
Corner(upgradePanel, 14)

Make("TextLabel", upgradePanel, {
    Name                   = "Title",
    Size                   = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text                   = "⬆️ Upgrades",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
})

local function UpgradeBtn(name: string, text: string, yPos: number)
    local btn = Make("TextButton", upgradePanel, {
        Name             = name,
        Size             = UDim2.new(1, -20, 0, 54),
        Position         = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = Color3.fromRGB(50, 80, 50),
        Text             = text,
        TextColor3       = Color3.new(1, 1, 1),
        Font             = Enum.Font.GothamBold,
        TextScaled       = true,
    }) :: TextButton
    Corner(btn, 8)
    return btn
end

UpgradeBtn("LuckUpgradeButton",  "🍀 Upgrade Luck\n+5 Luck · 200 🪙",    46)
UpgradeBtn("SpeedUpgradeButton", "⚡ Upgrade Speed\n×0.9 Time · 350 🪙", 108)

-- ── Inventory Panel (hidden by default) ─────────────────────
local inventoryPanel = Make("Frame", screenGui, {
    Name                   = "InventoryPanel",
    Size                   = UDim2.fromOffset(340, 440),
    Position               = UDim2.new(0.5, -170, 0.5, -220),
    BackgroundColor3       = Color3.fromRGB(18, 18, 30),
    BackgroundTransparency = 0.05,
    Visible                = false,
}) :: Frame
Corner(inventoryPanel, 14)

Make("TextLabel", inventoryPanel, {
    Name                   = "Title",
    Size                   = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text                   = "🎒 Inventory",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
})

Make("ScrollingFrame", inventoryPanel, {
    Name                  = "ScrollFrame",
    Size                  = UDim2.new(1, -10, 1, -46),
    Position              = UDim2.fromOffset(5, 40),
    BackgroundTransparency = 1,
    ScrollBarThickness    = 6,
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
})

-- ── Leaderboard Panel (hidden by default) ───────────────────
local leaderboardPanel = Make("Frame", screenGui, {
    Name                   = "LeaderboardPanel",
    Size                   = UDim2.fromOffset(360, 460),
    Position               = UDim2.new(0.5, -180, 0.5, -230),
    BackgroundColor3       = Color3.fromRGB(18, 18, 30),
    BackgroundTransparency = 0.05,
    Visible                = false,
}) :: Frame
Corner(leaderboardPanel, 14)

Make("TextLabel", leaderboardPanel, {
    Name                   = "Title",
    Size                   = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text                   = "🏆 Leaderboard",
    TextColor3             = Color3.fromRGB(255, 200, 60),
    Font                   = Enum.Font.GothamBold,
    TextScaled             = true,
})

Make("ScrollingFrame", leaderboardPanel, {
    Name                  = "ScrollFrame",
    Size                  = UDim2.new(1, -10, 1, -46),
    Position              = UDim2.fromOffset(5, 40),
    BackgroundTransparency = 1,
    ScrollBarThickness    = 6,
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
})

-- ── Notification Frame ───────────────────────────────────────
local notifFrame = Make("Frame", screenGui, {
    Name                   = "NotificationFrame",
    Size                   = UDim2.fromOffset(360, 44),
    Position               = UDim2.new(0.5, -180, 1, -70),
    BackgroundColor3       = Color3.fromRGB(30, 30, 45),
    BackgroundTransparency = 1,
    Visible                = false,
}) :: Frame
Corner(notifFrame, 10)

Make("TextLabel", notifFrame, {
    Name                   = "NotifLabel",
    Size                   = UDim2.new(1, -16, 1, 0),
    Position               = UDim2.fromOffset(8, 0),
    BackgroundTransparency = 1,
    Text                   = "Notification",
    TextColor3             = Color3.new(1, 1, 1),
    Font                   = Enum.Font.Gotham,
    TextScaled             = true,
    TextXAlignment         = Enum.TextXAlignment.Left,
})

print("✅ HarvestRNG_GUI built successfully! " .. tostring(#screenGui:GetDescendants()) .. " instances created.")
```

- [ ] **Step 2: Commit**
```bash
cd /tmp/roblox-startup
git add harvest-rng/src/studio/BuildGUI.lua
git commit -m "feat: Studio GUI builder script (BuildGUI.lua)"
```

---

## Task 4: Play Guide

**Files:**
- Create: `harvest-rng/docs/PLAY_GUIDE.md`

- [ ] **Step 1: Write PLAY_GUIDE.md**

```markdown
# Harvest RNG — Play Guide

## Quick Setup (Rojo)

```bash
# Prerequisites: Roblox Studio, Rojo plugin, Node.js
npm install -g rojo
cd harvest-rng
rojo serve default.project.json
```

Then in Roblox Studio: Rojo panel → Connect.

## Quick Setup (Manual)

1. Open a new Roblox place in Studio
2. Create folder structure in Explorer:
   - `ServerScriptService/modules/`
   - `ReplicatedStorage/Shared/`
   - `StarterPlayer/StarterPlayerScripts/modules/`
3. Copy each `.lua` file into the matching Studio location
4. Open View → Command Bar, paste and run the contents of `src/studio/BuildGUI.lua`
5. Press Play (F5) to test

## File → Studio Mapping

| File | Studio Location |
|------|----------------|
| `src/server/GameManager.server.lua` | ServerScriptService > GameManager (Script) |
| `src/server/modules/DataManager.lua` | ServerScriptService > modules > DataManager (ModuleScript) |
| `src/server/modules/RNGManager.lua` | ServerScriptService > modules > RNGManager (ModuleScript) |
| `src/server/modules/FarmManager.lua` | ServerScriptService > modules > FarmManager (ModuleScript) |
| `src/shared/Config.lua` | ReplicatedStorage > Shared > Config (ModuleScript) |
| `src/shared/RemoteEvents.lua` | ReplicatedStorage > Shared > RemoteEvents (ModuleScript) |
| `src/shared/SeedData.lua` | ReplicatedStorage > Shared > SeedData (ModuleScript) |
| `src/client/MainClient.client.lua` | StarterPlayer > StarterPlayerScripts > MainClient (LocalScript) |
| `src/client/modules/UIManager.lua` | StarterPlayer > StarterPlayerScripts > modules > UIManager (ModuleScript) |
| `src/client/modules/InventoryManager.lua` | StarterPlayer > StarterPlayerScripts > modules > InventoryManager (ModuleScript) |

## Gameplay Loop

1. **Roll** — Click "Roll" (50 coins) or "Roll ×10" (450 coins) to get random seeds
2. **Plant** — Click "Plant" on any empty plot, then pick a seed from the modal
3. **Wait** — Watch the timer count down on each plot
4. **Harvest** — Click "Harvest" when the plot shows ✅ Ready!
5. **Upgrade** — Spend coins on Luck (better rolls) or Speed (faster harvests)
6. **Unlock Plots** — Click the 🔒 lock on a locked plot to unlock it with coins

## Before Publishing

1. Create gamepasses in the Roblox Creator Dashboard:
   - Lucky Roll ×10 (replaces x10 bundle with free rolls)
   - Auto-Farm (automatic harvesting every 3 seconds)
   - VIP Plot (+5 extra plots, +15 luck)
2. Update gamepass IDs in `src/shared/Config.lua` under `GAMEPASS_IDS`
3. Set `Config.DATASTORE_NAME` to a new unique string before first publish
```

- [ ] **Step 2: Commit**
```bash
cd /tmp/roblox-startup
git add harvest-rng/docs/PLAY_GUIDE.md
git commit -m "docs: add PLAY_GUIDE.md"
```

---

## Task 5: Final Push

- [ ] **Step 1: Push everything**
```bash
cd /tmp/roblox-startup
git push origin main
```

- [ ] **Step 2: Verify on GitHub**
Visit https://github.com/sukrokucing/roblox-startup and confirm all files are present.

---

## Playability Checklist

After completing all tasks, the game is playable when:

- [ ] `default.project.json` exists → Rojo can sync
- [ ] `BuildGUI.lua` runs without errors in Studio → full GUI tree created
- [ ] `InventoryManager.lua` exists → seed-picker modal works
- [ ] Press Play in Studio → no script errors in Output
- [ ] Player spawns → HUD shows "🪙 250" starting coins
- [ ] Roll button works → seed appears in inventory
- [ ] Plant button opens picker modal → selecting a seed plants it on the plot
- [ ] Plot timer counts down → "✅ Ready!" appears
- [ ] Harvest button fires → coins pop up, HUD updates
- [ ] Upgrade buttons work → luck/speed increase
- [ ] Plot unlock button works (plot 4 costs 500 coins)
