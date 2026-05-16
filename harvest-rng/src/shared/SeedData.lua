--!strict
-- ============================================================
--  SeedData.lua  (Shared)
--  Master table of all 30 seed definitions — 5 per rarity tier.
--  Both server (RNGManager) and client (UI) require this module.
-- ============================================================

export type SeedDefinition = {
    id          : string,   -- unique snake_case key
    name        : string,   -- display name
    emoji       : string,   -- decorative emoji shown in UI
    rarity      : string,   -- "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
    baseValue   : number,   -- coins earned per harvest (before multipliers)
    harvestTime : number,   -- seconds to grow (before harvestSpeed multiplier)
    description : string,   -- flavour text shown in hover tooltip
}

local SeedData: {[string]: SeedDefinition} = {}

-- ── COMMON (55 % weight) ──────────────────────────────────────
--    baseValue   ~10–30 coins | harvestTime ~30–60 s
SeedData["wheat"] = {
    id          = "wheat",
    name        = "Wheat",
    emoji       = "🌾",
    rarity      = "Common",
    baseValue   = 10,
    harvestTime = 30,
    description = "Plain old wheat. Not glamorous, but it pays the bills.",
}
SeedData["carrot"] = {
    id          = "carrot",
    name        = "Carrot",
    emoji       = "🥕",
    rarity      = "Common",
    baseValue   = 14,
    harvestTime = 35,
    description = "Crunchy and reliable. A farmer's best friend.",
}
SeedData["potato"] = {
    id          = "potato",
    name        = "Potato",
    emoji       = "🥔",
    rarity      = "Common",
    baseValue   = 12,
    harvestTime = 32,
    description = "Humble spud. Grows almost anywhere.",
}
SeedData["corn"] = {
    id          = "corn",
    name        = "Corn",
    emoji       = "🌽",
    rarity      = "Common",
    baseValue   = 18,
    harvestTime = 45,
    description = "Tall and golden. Makes for great popcorn.",
}
SeedData["tomato"] = {
    id          = "tomato",
    name        = "Tomato",
    emoji       = "🍅",
    rarity      = "Common",
    baseValue   = 22,
    harvestTime = 55,
    description = "Is it a fruit or a vegetable? Either way, it sells.",
}

-- ── UNCOMMON (25 % weight) ────────────────────────────────────
--    baseValue   ~60–130 coins | harvestTime ~70–120 s
SeedData["sunflower"] = {
    id          = "sunflower",
    name        = "Sunflower",
    emoji       = "🌻",
    rarity      = "Uncommon",
    baseValue   = 65,
    harvestTime = 75,
    description = "Always faces the sun. Radiates good vibes.",
}
SeedData["pumpkin"] = {
    id          = "pumpkin",
    name        = "Pumpkin",
    emoji       = "🎃",
    rarity      = "Uncommon",
    baseValue   = 80,
    harvestTime = 90,
    description = "Spooky season or not, this orange globe is worth harvesting.",
}
SeedData["watermelon"] = {
    id          = "watermelon",
    name        = "Watermelon",
    emoji       = "🍉",
    rarity      = "Uncommon",
    baseValue   = 95,
    harvestTime = 100,
    description = "Big, juicy, and takes up a whole plot. Worth every coin.",
}
SeedData["eggplant"] = {
    id          = "eggplant",
    name        = "Eggplant",
    emoji       = "🍆",
    rarity      = "Uncommon",
    baseValue   = 70,
    harvestTime = 80,
    description = "Purple and peculiar. The underground farming community loves it.",
}
SeedData["strawberry"] = {
    id          = "strawberry",
    name        = "Strawberry",
    emoji       = "🍓",
    rarity      = "Uncommon",
    baseValue   = 120,
    harvestTime = 115,
    description = "Small but worth a pretty penny at the market.",
}

-- ── RARE (12 % weight) ────────────────────────────────────────
--    baseValue   ~350–700 coins | harvestTime ~180–300 s
SeedData["blueberry"] = {
    id          = "blueberry",
    name        = "Blueberry",
    emoji       = "🔵",
    rarity      = "Rare",
    baseValue   = 380,
    harvestTime = 190,
    description = "Tiny berries, big prices. Hard to find, easy to sell.",
}
SeedData["cherry"] = {
    id          = "cherry",
    name        = "Cherry",
    emoji       = "🍒",
    rarity      = "Rare",
    baseValue   = 440,
    harvestTime = 210,
    description = "Always comes in pairs. Double the elegance.",
}
SeedData["mango"] = {
    id          = "mango",
    name        = "Mango",
    emoji       = "🥭",
    rarity      = "Rare",
    baseValue   = 510,
    harvestTime = 240,
    description = "Tropical royalty. Needs warmth, rewards patience.",
}
SeedData["kiwi"] = {
    id          = "kiwi",
    name        = "Kiwi",
    emoji       = "🥝",
    rarity      = "Rare",
    baseValue   = 470,
    harvestTime = 225,
    description = "Fuzzy on the outside, brilliant inside.",
}
SeedData["lemon_tree"] = {
    id          = "lemon_tree",
    name        = "Lemon Tree",
    emoji       = "🍋",
    rarity      = "Rare",
    baseValue   = 620,
    harvestTime = 290,
    description = "When life gives you lemons, sell them for 620 coins.",
}

-- ── EPIC (5 % weight) ─────────────────────────────────────────
--    baseValue   ~2 000–5 000 coins | harvestTime ~600–900 s
SeedData["dragon_fruit"] = {
    id          = "dragon_fruit",
    name        = "Dragon Fruit",
    emoji       = "🐉",
    rarity      = "Epic",
    baseValue   = 2_200,
    harvestTime = 620,
    description = "Fierce exterior, sweet interior. Breathes profit.",
}
SeedData["rainbow_melon"] = {
    id          = "rainbow_melon",
    name        = "Rainbow Melon",
    emoji       = "🌈",
    rarity      = "Epic",
    baseValue   = 2_800,
    harvestTime = 700,
    description = "No one knows how it became multicolored. No one asks.",
}
SeedData["starfruit"] = {
    id          = "starfruit",
    name        = "Starfruit",
    emoji       = "⭐",
    rarity      = "Epic",
    baseValue   = 3_300,
    harvestTime = 780,
    description = "Shaped like a star, priced like one too.",
}
SeedData["moonfruit"] = {
    id          = "moonfruit",
    name        = "Moonfruit",
    emoji       = "🌙",
    rarity      = "Epic",
    baseValue   = 4_100,
    harvestTime = 850,
    description = "Only ripens at night. Has an otherworldly glow.",
}
SeedData["phantom_pepper"] = {
    id          = "phantom_pepper",
    name        = "Phantom Pepper",
    emoji       = "👻",
    rarity      = "Epic",
    baseValue   = 4_800,
    harvestTime = 900,
    description = "So spicy it vanishes from the plate. Buyers pay a premium.",
}

-- ── LEGENDARY (2.5 % weight) ──────────────────────────────────
--    baseValue   ~15 000–40 000 coins | harvestTime ~1 800–3 600 s
SeedData["golden_apple"] = {
    id          = "golden_apple",
    name        = "Golden Apple",
    emoji       = "🍎",
    rarity      = "Legendary",
    baseValue   = 15_000,
    harvestTime = 1_800,
    description = "Forged from sunlight and luck. Every farmer's dream.",
}
SeedData["celestial_pear"] = {
    id          = "celestial_pear",
    name        = "Celestial Pear",
    emoji       = "✨",
    rarity      = "Legendary",
    baseValue   = 22_000,
    harvestTime = 2_200,
    description = "Fell from the sky. Definitely not cursed. Probably.",
}
SeedData["solar_bloom"] = {
    id          = "solar_bloom",
    name        = "Solar Bloom",
    emoji       = "☀️",
    rarity      = "Legendary",
    baseValue   = 30_000,
    harvestTime = 2_700,
    description = "A flower that concentrates sunlight into pure value.",
}
SeedData["ancient_oak_fruit"] = {
    id          = "ancient_oak_fruit",
    name        = "Ancient Oak Fruit",
    emoji       = "🌳",
    rarity      = "Legendary",
    baseValue   = 35_000,
    harvestTime = 3_200,
    description = "Grown from seeds older than the game itself.",
}
SeedData["prism_grape"] = {
    id          = "prism_grape",
    name        = "Prism Grape",
    emoji       = "💎",
    rarity      = "Legendary",
    baseValue   = 42_000,
    harvestTime = 3_600,
    description = "Each bunch refracts light into a full spectrum. Collectors adore them.",
}

-- ── MYTHIC (0.5 % weight) ─────────────────────────────────────
--    baseValue   ~150 000–500 000 coins | harvestTime ~7 200–14 400 s
SeedData["void_crystal"] = {
    id          = "void_crystal",
    name        = "Void Crystal",
    emoji       = "🔮",
    rarity      = "Mythic",
    baseValue   = 150_000,
    harvestTime = 7_200,
    description = "Crystallized darkness. The market goes wild for it.",
}
SeedData["nebula_bloom"] = {
    id          = "nebula_bloom",
    name        = "Nebula Bloom",
    emoji       = "🌌",
    rarity      = "Mythic",
    baseValue   = 220_000,
    harvestTime = 9_000,
    description = "A galaxy compressed into a single flower. Unfathomable beauty.",
}
SeedData["eternal_lotus"] = {
    id          = "eternal_lotus",
    name        = "Eternal Lotus",
    emoji       = "🪷",
    rarity      = "Mythic",
    baseValue   = 300_000,
    harvestTime = 10_800,
    description = "Never wilts. Sells for enough to retire three generations.",
}
SeedData["dragon_heart_fruit"] = {
    id          = "dragon_heart_fruit",
    name        = "Dragon Heart Fruit",
    emoji       = "❤️‍🔥",
    rarity      = "Mythic",
    baseValue   = 420_000,
    harvestTime = 12_600,
    description = "Pulsates with ancient energy. Handle with fireproof gloves.",
}
SeedData["genesis_seed"] = {
    id          = "genesis_seed",
    name        = "Genesis Seed",
    emoji       = "🌠",
    rarity      = "Mythic",
    baseValue   = 500_000,
    harvestTime = 14_400,
    description = "The first seed. The last seed. Worth everything.",
}

-- ── Utility helpers ───────────────────────────────────────────

--- Returns all seeds of a given rarity as an array.
function SeedData.GetByRarity(rarity: string): {SeedDefinition}
    local results: {SeedDefinition} = {}
    for _, seed in SeedData do
        if type(seed) == "table" and seed.rarity == rarity then
            table.insert(results, seed)
        end
    end
    return results
end

--- Returns a flat array of all 30 seed definitions.
function SeedData.GetAll(): {SeedDefinition}
    local results: {SeedDefinition} = {}
    for _, seed in SeedData do
        if type(seed) == "table" and seed.id ~= nil then
            table.insert(results, seed)
        end
    end
    return results
end

--- Looks up a seed by id; errors loudly if not found.
function SeedData.Get(id: string): SeedDefinition
    local entry = SeedData[id]
    assert(type(entry) == "table", "SeedData.Get: unknown seed id '" .. id .. "'")
    return entry :: SeedDefinition
end

return SeedData
