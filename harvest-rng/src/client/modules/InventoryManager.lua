--!strict
-- ============================================================
--  InventoryManager.lua  (Client Module)
--  Renders a seed-picker modal when the player clicks "Plant".
--
--  API:
--    InventoryManager.OpenPicker(plotIndex, inventory, onPick)
--    InventoryManager.Close()
-- ============================================================

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local GUI         = PlayerGui:WaitForChild("HarvestRNG_GUI") :: ScreenGui

local UIManager = require(script.Parent.UIManager)
local SeedData  = require(game.ReplicatedStorage.Shared.SeedData)

local InventoryManager = {}

local activeModal: Frame? = nil

local function CloseModal()
    if activeModal then
        activeModal:Destroy()
        activeModal = nil
    end
end

function InventoryManager.OpenPicker(
    plotIndex : number,
    inventory : {[string]: number},
    onPick    : (seedId: string) -> ()
)
    CloseModal()

    -- dim overlay
    local overlay = Instance.new("TextButton")
    overlay.Name                   = "InventoryPickerOverlay"
    overlay.Size                   = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.AutoButtonColor        = false
    overlay.Text                   = ""
    overlay.ZIndex                 = 30
    overlay.Parent                 = GUI
    activeModal = overlay

    -- modal card
    local modal = Instance.new("Frame")
    modal.Name                     = "PickerModal"
    modal.Size                     = UDim2.fromOffset(380, 420)
    modal.Position                 = UDim2.fromScale(0.5, 0.5)
    modal.AnchorPoint              = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3         = Color3.fromRGB(22, 22, 35)
    modal.BackgroundTransparency   = 0.04
    modal.ZIndex                   = 31
    modal.Parent                   = overlay
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,14); mc.Parent = modal

    -- title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-44,0,36); title.Position = UDim2.fromOffset(20,10)
    title.BackgroundTransparency = 1
    title.Text = string.format("🌱  Plant on Plot %d", plotIndex)
    title.TextColor3 = Color3.new(1,1,1); title.Font = Enum.Font.GothamBold
    title.TextScaled = true; title.ZIndex = 32; title.Parent = modal

    -- close X
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(28,28); closeBtn.Position = UDim2.new(1,-36,0,8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
    closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextScaled = true
    closeBtn.ZIndex = 32; closeBtn.Parent = modal
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,6); cc.Parent = closeBtn
    closeBtn.Activated:Connect(CloseModal)
    overlay.Activated:Connect(CloseModal)

    -- scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-14,1,-56); scroll.Position = UDim2.fromOffset(7,50)
    scroll.BackgroundTransparency = 1; scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,140)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.ZIndex = 32; scroll.Parent = modal
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,5); layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    -- rarity sort order
    local rarityOrder: {[string]: number} = {
        Mythic=6, Legendary=5, Epic=4, Rare=3, Uncommon=2, Common=1
    }

    type Entry = { seedId:string, count:number, def:SeedData.SeedDefinition }
    local entries: {Entry} = {}
    for seedId, count in inventory do
        if count > 0 then
            local ok, def = pcall(SeedData.Get, seedId)
            if ok then table.insert(entries, {seedId=seedId, count=count, def=def}) end
        end
    end
    table.sort(entries, function(a,b)
        local ra = rarityOrder[a.def.rarity] or 0
        local rb = rarityOrder[b.def.rarity] or 0
        if ra ~= rb then return ra > rb end
        return a.count > b.count
    end)

    if #entries == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,0,0,60); empty.BackgroundTransparency = 1
        empty.Text = "No seeds! Roll first 🎲"; empty.TextColor3 = Color3.fromRGB(160,160,160)
        empty.Font = Enum.Font.Gotham; empty.TextScaled = true; empty.ZIndex = 33; empty.Parent = scroll
    end

    for i, e in entries do
        local row = Instance.new("Frame")
        row.Name = "Row_"..e.seedId; row.Size = UDim2.new(1,-6,0,54)
        row.BackgroundColor3 = Color3.fromRGB(32,32,48); row.BackgroundTransparency = 0.08
        row.LayoutOrder = i; row.ZIndex = 33; row.Parent = scroll
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,8); rc.Parent = row

        local emoji = Instance.new("TextLabel")
        emoji.Size = UDim2.fromOffset(44,44); emoji.Position = UDim2.fromOffset(5,5)
        emoji.BackgroundTransparency = 1; emoji.Text = e.def.emoji
        emoji.TextScaled = true; emoji.ZIndex = 34; emoji.Parent = row

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(0.48,0,0.5,0); nameL.Position = UDim2.fromOffset(53,3)
        nameL.BackgroundTransparency = 1; nameL.Text = e.def.name
        nameL.TextColor3 = UIManager.GetRarityColor(e.def.rarity)
        nameL.Font = Enum.Font.GothamBold; nameL.TextScaled = true
        nameL.TextXAlignment = Enum.TextXAlignment.Left; nameL.ZIndex = 34; nameL.Parent = row

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(0.48,0,0.4,0); sub.Position = UDim2.fromOffset(53,28)
        sub.BackgroundTransparency = 1
        sub.Text = e.def.rarity.."  ×"..e.count
        sub.TextColor3 = Color3.fromRGB(150,150,170); sub.Font = Enum.Font.Gotham
        sub.TextScaled = true; sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.ZIndex = 34; sub.Parent = row

        local plantBtn = Instance.new("TextButton")
        plantBtn.Size = UDim2.fromOffset(70,34); plantBtn.Position = UDim2.new(1,-76,0.5,-17)
        plantBtn.BackgroundColor3 = UIManager.GetRarityColor(e.def.rarity)
        plantBtn.Text = "Plant 🌱"; plantBtn.TextColor3 = Color3.fromRGB(15,15,15)
        plantBtn.Font = Enum.Font.GothamBold; plantBtn.TextScaled = true
        plantBtn.ZIndex = 34; plantBtn.Parent = row
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = plantBtn

        local sid = e.seedId
        plantBtn.Activated:Connect(function()
            CloseModal()
            onPick(sid)
        end)
    end

    -- pop-in tween
    modal.Size = UDim2.fromOffset(380, 10)
    TweenService:Create(modal, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(380, 420)
    }):Play()
end

function InventoryManager.Close()
    CloseModal()
end

return InventoryManager
