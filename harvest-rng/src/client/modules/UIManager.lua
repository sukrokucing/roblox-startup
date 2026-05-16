--!strict
-- ============================================================
--  UIManager.lua  (Client Module)
--  Handles all UI updates, animations, and visual feedback.
--  Requires a ScreenGui structure already present in PlayerGui.
--
--  Expected GUI tree (create in Studio):
--    PlayerGui
--    └─ HarvestRNG_GUI (ScreenGui)
--       ├─ HUD (Frame)
--       │  ├─ CoinsLabel  (TextLabel)
--       │  ├─ GemsLabel   (TextLabel)
--       │  ├─ LuckLabel   (TextLabel)
--       │  └─ StreakLabel (TextLabel)
--       ├─ RollPanel (Frame)
--       │  ├─ RollButton    (TextButton)
--       │  ├─ RollX10Button (TextButton)
--       │  └─ ResultFrame   (Frame)
--       │     ├─ SeedEmoji  (TextLabel)
--       │     ├─ SeedName   (TextLabel)
--       │     └─ RarityLabel (TextLabel)
--       ├─ FarmPanel (Frame)
--       │  ├─ ToggleFarmButton (TextButton)
--       │  └─ PlotContainer (Frame — plots spawned dynamically)
--       ├─ InventoryPanel (Frame, Visible=false)
--       │  └─ ScrollFrame
--       ├─ UpgradePanel (Frame, Visible=false)
--       │  ├─ LuckUpgradeButton   (TextButton)
--       │  └─ SpeedUpgradeButton  (TextButton)
--       ├─ LeaderboardPanel (Frame, Visible=false)
--       │  └─ CloseBtn (TextButton)
--       └─ NotificationFrame (Frame, Visible=false)
--          └─ NotifLabel (TextLabel)
-- ============================================================

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local GUI         = PlayerGui:WaitForChild("HarvestRNG_GUI") :: ScreenGui

-- ── Rarity palette ────────────────────────────────────────────

local RarityColors: {[string]: Color3} = {
    Common    = Color3.fromRGB(200, 200, 200),   -- silver-white
    Uncommon  = Color3.fromRGB( 80, 200,  80),   -- green
    Rare      = Color3.fromRGB( 70, 130, 240),   -- blue
    Epic      = Color3.fromRGB(170,  70, 230),   -- purple
    Legendary = Color3.fromRGB(255, 160,  30),   -- orange
    Mythic    = Color3.fromRGB(230,  40,  50),   -- red
}

local RarityGlow: {[string]: Color3} = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB( 50, 180,  50),
    Rare      = Color3.fromRGB( 50, 100, 220),
    Epic      = Color3.fromRGB(150,  40, 210),
    Legendary = Color3.fromRGB(240, 130,   0),
    Mythic    = Color3.fromRGB(200,  10,  20),
}

-- ── GUI references (resolved once) ───────────────────────────

local HUD: Frame              = GUI:WaitForChild("HUD") :: Frame
local CoinsLabel: TextLabel   = HUD:WaitForChild("CoinsLabel") :: TextLabel
local GemsLabel: TextLabel    = HUD:WaitForChild("GemsLabel") :: TextLabel
local LuckLabel: TextLabel    = HUD:WaitForChild("LuckLabel") :: TextLabel
local StreakLabel: TextLabel  = HUD:WaitForChild("StreakLabel") :: TextLabel

local RollPanel: Frame        = GUI:WaitForChild("RollPanel") :: Frame
local ResultFrame: Frame      = RollPanel:WaitForChild("ResultFrame") :: Frame
local SeedEmoji: TextLabel    = ResultFrame:WaitForChild("SeedEmoji") :: TextLabel
local SeedName: TextLabel     = ResultFrame:WaitForChild("SeedName") :: TextLabel
local RarityLabel: TextLabel  = ResultFrame:WaitForChild("RarityLabel") :: TextLabel

local NotifFrame: Frame       = GUI:WaitForChild("NotificationFrame") :: Frame
local NotifLabel: TextLabel   = NotifFrame:WaitForChild("NotifLabel") :: TextLabel

-- Active tween handles so we can cancel mid-animation
local activeTweens: {Tween} = {}

local function KillTweens()
    for _, tw in activeTweens do
        tw:Cancel()
    end
    table.clear(activeTweens)
end

local function Tween(instance: Instance, info: TweenInfo, goals: {[string]: any}): Tween
    local tw = TweenService:Create(instance, info, goals)
    table.insert(activeTweens, tw)
    tw:Play()
    return tw
end

-- ── Format helpers ────────────────────────────────────────────

local function FormatNumber(n: number): string
    if n >= 1_000_000 then
        return string.format("%.1fM", n / 1_000_000)
    elseif n >= 1_000 then
        return string.format("%.1fK", n / 1_000)
    end
    return tostring(n)
end

-- ── Public API ────────────────────────────────────────────────

local UIManager = {}

--- Updates the coin counter in the HUD.
function UIManager.UpdateCoins(amount: number)
    CoinsLabel.Text = "Coins " .. FormatNumber(amount)
    -- Quick bounce
    Tween(CoinsLabel, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = CoinsLabel.TextSize + 4
    }).Completed:Wait()
    Tween(CoinsLabel, TweenInfo.new(0.12), { TextSize = CoinsLabel.TextSize })
end

--- Updates the gem counter in the HUD.
function UIManager.UpdateGems(amount: number)
    GemsLabel.Text = "💎 " .. FormatNumber(amount)
end

--- Updates the luck display in the HUD.
function UIManager.UpdateLuck(luckStat: number, level: number)
    LuckLabel.Text = string.format("🍀 Luck %d (Lv%d)", luckStat, level)
end

--- Updates the daily streak counter.
function UIManager.UpdateStreak(streak: number)
    StreakLabel.Text = string.format("🔥 Streak: %d", streak)
end

--- Bulk update from a StatsUpdate event payload.
function UIManager.UpdateStats(stats: {[string]: any})
    if stats.coins ~= nil then
        UIManager.UpdateCoins(stats.coins :: number)
    end
    if stats.gems ~= nil then
        UIManager.UpdateGems(stats.gems :: number)
    end
    if stats.luck ~= nil and stats.luckLevel ~= nil then
        UIManager.UpdateLuck(stats.luck :: number, stats.luckLevel :: number)
    end
    if stats.dailyStreak ~= nil then
        UIManager.UpdateStreak(stats.dailyStreak :: number)
    end
end

--- Plays the roll-result reveal animation for a single result.
--- Call sequentially for x10 roll, or show a summary panel instead.
function UIManager.ShowRollResult(seedEmoji: string, seedNameStr: string, rarity: string)
    KillTweens()

    local color   = RarityColors[rarity] or RarityColors["Common"]

    -- Set initial hidden state
    ResultFrame.BackgroundColor3 = color
    ResultFrame.BackgroundTransparency = 1
    SeedEmoji.Text    = seedEmoji
    SeedEmoji.TextColor3 = Color3.fromRGB(255, 255, 255)
    SeedEmoji.BackgroundTransparency = 1
    SeedEmoji.TextTransparency = 1
    SeedName.Text     = seedNameStr
    SeedName.TextTransparency = 1
    SeedName.TextColor3 = Color3.fromRGB(255, 255, 255)
    RarityLabel.Text  = rarity
    RarityLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
    RarityLabel.TextTransparency = 1

    local fadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local bounce = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- Fade in background
    Tween(ResultFrame, fadeIn, { BackgroundTransparency = 0.35 })

    -- Pop in emoji with scale
    SeedEmoji.Size = UDim2.fromOffset(48, 48)
    SeedEmoji.Position = UDim2.fromOffset(20, 18)
    Tween(SeedEmoji, bounce, {
        TextTransparency = 0,
        Size = UDim2.fromOffset(64, 64),
        Position = UDim2.fromOffset(12, 10),
    })

    task.delay(0.2, function()
        Tween(SeedName, fadeIn, { TextTransparency = 0 })
        task.delay(0.15, function()
            Tween(RarityLabel, fadeIn, { TextTransparency = 0 })
        end)
    end)

    -- Glow pulse for Legendary / Mythic
    if rarity == "Legendary" or rarity == "Mythic" then
        local glowColor = RarityGlow[rarity]
        local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true)
        task.delay(0.4, function()
            Tween(ResultFrame, pulseInfo, { BackgroundColor3 = glowColor })
        end)
    end
end

--- Shows a floating "+N coins" popup that drifts up and fades.
--- Spawns a temporary BillboardGui above the plot's Part, or falls
--- back to a screen-space label if `part` is nil.
function UIManager.ShowHarvestPopup(coins: number, rarity: string, part: BasePart?)
    local color = RarityColors[rarity] or Color3.new(1, 1, 0)

    if part then
        -- Billboard popup above the plot
        local billboard = Instance.new("BillboardGui")
        billboard.AlwaysOnTop = true
        billboard.Size        = UDim2.fromOffset(120, 40)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent      = part

        local label = Instance.new("TextLabel")
        label.Size             = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text             = "+" .. FormatNumber(coins) .. " coins"
        label.TextColor3       = color
        label.TextScaled       = true
        label.Font             = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.6
        label.Parent           = billboard

        -- Drift up and fade
        local driftInfo = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        Tween(billboard, driftInfo, { StudsOffset = Vector3.new(0, 8, 0) })
        task.delay(0.6, function()
            Tween(label, TweenInfo.new(0.8), { TextTransparency = 1 })
        end)
        game:GetService("Debris"):AddItem(billboard, 2)
    else
        -- Fallback: screen label in top-right area
        local screenLabel = Instance.new("TextLabel")
        screenLabel.Size             = UDim2.fromOffset(200, 35)
        screenLabel.Position         = UDim2.new(0.75, 0, 0.35, 0)
        screenLabel.BackgroundTransparency = 1
        screenLabel.Text             = "+" .. FormatNumber(coins) .. " coins"
        screenLabel.TextColor3       = color
        screenLabel.TextScaled       = true
        screenLabel.Font             = Enum.Font.GothamBold
        screenLabel.TextStrokeTransparency = 0.5
        screenLabel.ZIndex           = 10
        screenLabel.Parent           = GUI

        local driftInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        Tween(screenLabel, driftInfo, { Position = UDim2.new(0.75, 0, 0.25, 0) })
        task.delay(0.5, function()
            Tween(screenLabel, TweenInfo.new(0.7), { TextTransparency = 1 })
        end)
        game:GetService("Debris"):AddItem(screenLabel, 2)
    end
end

--- Shows a toast-style notification at the bottom of the screen.
--- `style` can be "info" | "error" | "success"
function UIManager.ShowNotification(message: string, style: string?)
    local styleColor: Color3
    if style == "error" then
        styleColor = Color3.fromRGB(230, 60, 60)
    elseif style == "success" then
        styleColor = Color3.fromRGB(60, 200, 100)
    else
        styleColor = Color3.fromRGB(200, 200, 200)
    end

    NotifLabel.Text        = message
    NotifLabel.TextColor3  = styleColor
    NotifFrame.BackgroundTransparency = 1
    NotifFrame.Visible     = true

    KillTweens()

    -- Slide in
    local slideIn = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Tween(NotifFrame, slideIn, { BackgroundTransparency = 0.2 })

    task.delay(2.5, function()
        local fadeOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        Tween(NotifFrame, fadeOut, { BackgroundTransparency = 1 }).Completed:Wait()
        NotifFrame.Visible = false
    end)
end

--- Renders a daily-streak banner popup.
function UIManager.ShowStreakBanner(day: number, coins: number, gems: number)
    -- Build a temporary modal frame
    local modal = Instance.new("Frame")
    modal.Size                  = UDim2.fromOffset(320, 180)
    modal.Position              = UDim2.fromScale(0.5, 0.5)
    modal.AnchorPoint           = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3      = Color3.fromRGB(30, 30, 40)
    modal.BackgroundTransparency = 1
    modal.ZIndex                = 20
    modal.Parent                = GUI

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent       = modal

    local title = Instance.new("TextLabel")
    title.Size             = UDim2.new(1, 0, 0.3, 0)
    title.BackgroundTransparency = 1
    title.Text             = string.format("🔥 Day %d Streak!", day)
    title.TextColor3       = Color3.fromRGB(255, 200, 60)
    title.TextScaled       = true
    title.Font             = Enum.Font.GothamBold
    title.ZIndex           = 21
    title.Parent           = modal

    local rewards = Instance.new("TextLabel")
    rewards.Size             = UDim2.new(1, 0, 0.4, 0)
    rewards.Position         = UDim2.fromScale(0, 0.35)
    rewards.BackgroundTransparency = 1
    rewards.Text             = string.format("+%s coins  +%d gems", FormatNumber(coins), gems)
    rewards.TextColor3       = Color3.new(1, 1, 1)
    rewards.TextScaled       = true
    rewards.Font             = Enum.Font.Gotham
    rewards.ZIndex           = 21
    rewards.Parent           = modal

    -- Pop in
    Tween(modal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.1
    })

    -- Auto-dismiss after 3 s
    task.delay(3, function()
        Tween(modal, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }).Completed:Wait()
        modal:Destroy()
    end)
end

--- Renders the x10 roll summary list.
--- results: array of { seedName, emoji, rarity }
function UIManager.ShowRollX10Summary(results: {{seedName: string, emoji: string, rarity: string}})
    -- For now, play the highest-rarity result as the hero card,
    -- then list the rest as a scrolling log.
    -- Full panel layout lives in Studio; this is the logic layer.
    local rarityOrder: {[string]: number} = {
        Mythic = 6, Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1
    }

    -- Find best result
    local best = results[1]
    for _, r in results do
        if (rarityOrder[r.rarity] or 0) > (rarityOrder[best.rarity] or 0) then
            best = r
        end
    end

    UIManager.ShowRollResult(best.emoji, best.seedName, best.rarity)
end

--- Returns the Color3 for a rarity string.
function UIManager.GetRarityColor(rarity: string): Color3
    return RarityColors[rarity] or Color3.new(1, 1, 1)
end

return UIManager
