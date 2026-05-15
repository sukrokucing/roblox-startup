--!strict
-- ============================================================
--  Config.lua  (Shared)
--  Single source of truth for all game-wide constants.
--  Import with:  local Config = require(game.ReplicatedStorage.Shared.Config)
-- ============================================================

local Config = {}

-- ── Economy ────────────────────────────────────────────────
Config.ROLL_COST_COINS         = 50          -- coins per single roll
Config.ROLL_COST_GEMS          = 0           -- gems per single roll (0 = coin-only)
Config.ROLL_X10_COST_COINS     = 450         -- 10-roll bundle (10% discount)
Config.ROLL_X10_COST_GEMS      = 0

-- ── Starting stats ─────────────────────────────────────────
Config.STARTING_COINS          = 250
Config.STARTING_GEMS           = 0
Config.STARTING_LUCK           = 0          -- additive luck bonus (0–100 scale)
Config.STARTING_HARVEST_SPEED  = 1.0        -- multiplier; 1.0 = normal speed
Config.STARTING_PLOTS          = 3          -- plots unlocked at start

-- ── Plot system ────────────────────────────────────────────
Config.MAX_PLOTS               = 25

-- Cost in coins to unlock each successive plot slot (index = slot number)
Config.PLOT_UNLOCK_COSTS = {
    [4]  = 500,
    [5]  = 1_000,
    [6]  = 2_500,
    [7]  = 5_000,
    [8]  = 10_000,
    [9]  = 20_000,
    [10] = 40_000,
    [11] = 75_000,
    [12] = 125_000,
    [13] = 200_000,
    [14] = 350_000,
    [15] = 500_000,
    [16] = 750_000,
    [17] = 1_000_000,
    [18] = 1_500_000,
    [19] = 2_000_000,
    [20] = 3_000_000,
    [21] = 4_500_000,
    [22] = 6_500_000,
    [23] = 9_000_000,
    [24] = 13_000_000,
    [25] = 18_000_000,
}

-- ── Luck upgrades ──────────────────────────────────────────
-- Each tier adds +LUCK_PER_UPGRADE to the player's luck stat
Config.LUCK_PER_UPGRADE        = 5
Config.MAX_LUCK_LEVEL          = 20         -- max 20 upgrades → +100 luck
Config.LUCK_UPGRADE_BASE_COST  = 200        -- coins; scales by LUCK_UPGRADE_SCALE^level
Config.LUCK_UPGRADE_SCALE      = 1.65

-- ── Harvest Speed upgrades ─────────────────────────────────
-- Each tier multiplies harvest time by HARVEST_SPEED_FACTOR
Config.HARVEST_SPEED_FACTOR    = 0.90       -- −10 % per level
Config.MAX_HARVEST_SPEED_LEVEL = 15
Config.HARVEST_SPEED_BASE_COST = 350
Config.HARVEST_SPEED_SCALE     = 1.80

-- ── Timing ─────────────────────────────────────────────────
Config.AUTOSAVE_INTERVAL       = 60         -- seconds between auto-saves
Config.DAILY_STREAK_RESET_HOURS = 36        -- hours before streak resets (generous window)
Config.ROLL_ANIMATION_DURATION = 1.8        -- seconds for roll reveal tween

-- ── Daily streak rewards ────────────────────────────────────
-- rewards[day] = { coins = N, gems = N }; days > #table wrap to index 7
Config.DAILY_STREAK_REWARDS = {
    [1] = { coins = 100,   gems = 0  },
    [2] = { coins = 200,   gems = 0  },
    [3] = { coins = 300,   gems = 1  },
    [4] = { coins = 500,   gems = 1  },
    [5] = { coins = 750,   gems = 2  },
    [6] = { coins = 1_000, gems = 3  },
    [7] = { coins = 2_000, gems = 5  },  -- "Big Sunday" reward
}

-- ── Leaderboard ────────────────────────────────────────────
Config.LEADERBOARD_KEY         = "TotalHarvested_v1"
Config.LEADERBOARD_SIZE        = 100        -- entries to store in OrderedDataStore

-- ── DataStore ──────────────────────────────────────────────
Config.DATASTORE_NAME          = "HarvestRNG_PlayerData_v1"
Config.DATASTORE_RETRY_ATTEMPTS = 3
Config.DATASTORE_RETRY_BASE_DELAY = 1.0    -- seconds; doubles each attempt

-- ── Gamepasses (fill in actual Roblox IDs before publishing) ─
Config.GAMEPASS_IDS = {
    LuckyRollX10  = 0,   -- TODO: replace with real gamepass ID
    AutoFarm      = 0,
    VIPPlot       = 0,
}

-- ── VIP Perks ──────────────────────────────────────────────
Config.VIP_EXTRA_PLOTS         = 5          -- extra plots for VIP Plot gamepass owners
Config.VIP_LUCK_BONUS          = 15         -- flat luck added for VIP owners
Config.AUTOFARM_POLL_INTERVAL  = 3          -- seconds between auto-harvest checks

-- ── Rarity system (mirrors RNGManager weights) ─────────────
Config.RARITY_ORDER = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"
}

Config.RARITY_BASE_WEIGHTS = {
    Common    = 55.0,
    Uncommon  = 25.0,
    Rare      = 12.0,
    Epic      =  5.0,
    Legendary =  2.5,
    Mythic    =  0.5,
}

-- How much each +1 luck point shifts weight away from Common toward rarer tiers
Config.LUCK_WEIGHT_SHIFT       = 0.08

-- ── Debug flags (set ALL to false before publishing!) ───────
-- S-3: These were documented in TECHNICAL_SPEC §11 but were missing from code.
Config.DEBUG_INSTANT_HARVEST   = false   -- skip grow timer; plots ready immediately
Config.DEBUG_FREE_ROLLS        = false   -- roll without spending coins
Config.DEBUG_LOG_ROLLS         = false   -- print RNG roll details to server console

return Config
