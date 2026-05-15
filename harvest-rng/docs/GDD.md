# Harvest RNG — Game Design Document (GDD)

**Version:** 1.0  
**Status:** In Development  
**Genre:** Idle / Incremental Simulator · RNG Gacha  
**Platform:** Roblox  

---

## Table of Contents

1. [Concept & Vision](#1-concept--vision)
2. [Target Audience](#2-target-audience)
3. [Core Loop](#3-core-loop)
4. [RNG System Design](#4-rng-system-design)
5. [Progression Systems](#5-progression-systems)
6. [Economy Design](#6-economy-design)
7. [Monetization](#7-monetization)
8. [Retention & Live Ops](#8-retention--live-ops)
9. [Competitive Layer](#9-competitive-layer)
10. [World & Visual Tone](#10-world--visual-tone)
11. [Audio Direction](#11-audio-direction)
12. [Feature Roadmap](#12-feature-roadmap)

---

## 1. Concept & Vision

**Harvest RNG** is a Roblox idle/incremental farming simulator built around the excitement of gacha rolls. Players spend coins to roll random seeds from a pool of 30 varieties spanning six rarity tiers — then plant, grow, harvest, and sell their crops for coins to roll again.

The core fantasy is **"what did I get this time?"** — the thrill of each roll, the dopamine spike of landing a Legendary, and the quiet satisfaction of optimising a full farm of plots to maximise passive income. Think *Pet Simulator X* meets *Stardew Valley* meets a slot machine.

**Design pillars:**

| Pillar | Meaning |
|--------|---------|
| **Lucky Moments** | Every roll is a potential big hit. Rare pulls should feel exceptional. |
| **Always Growing** | There is always something to do: roll, plant, upgrade, or unlock. |
| **Social Flex** | Rare crops are visible to other players. The leaderboard matters. |
| **Fair Core** | The entire game is playable F2P. Robux buys convenience, not power. |

---

## 2. Target Audience

**Primary:** Roblox players aged 10–16  
**Secondary:** Simulator veterans 16–25 seeking a casual idle experience

### Player archetypes

| Archetype | Description | What keeps them playing |
|-----------|-------------|------------------------|
| **Lucky Chaser** | Lives for the rare pull. Watches roll animations obsessively. | Rarity reveal animation, Mythic seed rarity, lucky streaks |
| **Optimizer** | Builds the most efficient farm layout. Min-maxes luck upgrades. | Upgrade tree depth, multi-plot synergy, leaderboard rank |
| **Collector** | Wants to own every seed at least once. Fills the Seed Dex. | Seed Dex completion %, seasonal exclusives |
| **Casual Idler** | Logs in, plants, closes game, harvests next time. | Auto-Farm pass, generous harvest windows, daily streak |

---

## 3. Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│                     CORE LOOP (1–5 min)                     │
│                                                             │
│   COINS ──► ROLL ──► SEED (RNG) ──► PLANT ──► WAIT         │
│     ▲                                          │            │
│     └────────── SELL / HARVEST ◄───────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### Step-by-step

1. **Roll** — Spend 50 coins (or 450 for x10) to draw a random seed from the pool. The rarity is determined by weighted RNG modified by the player's Luck stat.

2. **Plant** — Drag the seed to an unlocked farm plot. The plot begins a countdown based on the seed's base harvest time and the player's Harvest Speed stat.

3. **Wait / Return** — The crop grows in real time. Players can check back at any point. Auto-Farm gamepass owners never need to manually harvest.

4. **Harvest** — Tap the glowing plot to collect coins. The payout is `baseValue × rarityMultiplier × luckBonus`.

5. **Sell & Reinvest** — Coins go directly to the wallet. Spend on more rolls, plot unlocks, or stat upgrades.

6. **Repeat** — The loop tightens as plots, speed, and luck scale up.

### Session intent

| Session length | Expected progress |
|----------------|------------------|
| 2 min (mobile check-in) | Harvest 1-3 ready plots, roll 1-3 seeds |
| 10 min (active play) | Full roll session, plant all plots, claim daily streak |
| 30 min+ (grinder) | Upgrade sprint, leaderboard push, re-rolling for specific rarities |

---

## 4. RNG System Design

### 4.1 Rarity tiers

| Rarity | Base Weight | Value Multiplier | Harvest Time Modifier | Colour |
|--------|------------|------------------|-----------------------|--------|
| Common    | 55.0 % | ×1.00 | ×1.00 | White / Silver |
| Uncommon  | 25.0 % | ×1.10 | ×1.00 | Green |
| Rare      | 12.0 % | ×1.25 | ×0.95 | Blue |
| Epic      |  5.0 % | ×1.50 | ×0.90 | Purple |
| Legendary |  2.5 % | ×2.00 | ×0.85 | Orange |
| Mythic    |  0.5 % | ×3.00 | ×0.80 | Red |

*Total base weight = 100 %. Harvest time modifier means higher rarities grow slightly faster.*

### 4.2 Luck system

Luck is an additive stat (0–100) earned through upgrades and gamepasses. Each +1 luck point shifts `0.08` weight points away from Common and distributes them proportionally across all non-Common tiers.

**At Luck 0:** exact base weights above.  
**At Luck 100:** Common drops by ~8 pp; Mythic roughly doubles from 0.5 % to ~0.9 %.

The effect is meaningful but never game-breaking — a high-luck player still rolls mostly Commons, but Legendary/Mythic sightings become noticeably more frequent. This prevents pay-to-win perception while still making Luck upgrades satisfying.

### 4.3 Seed pool (30 seeds)

| Tier | Seeds |
|------|-------|
| Common    | Wheat 🌾, Carrot 🥕, Potato 🥔, Corn 🌽, Tomato 🍅 |
| Uncommon  | Sunflower 🌻, Pumpkin 🎃, Watermelon 🍉, Eggplant 🍆, Strawberry 🍓 |
| Rare      | Blueberry 🫐, Cherry 🍒, Mango 🥭, Kiwi 🥝, Lemon Tree 🍋 |
| Epic      | Dragon Fruit 🐉, Rainbow Melon 🌈, Starfruit ⭐, Moonfruit 🌙, Phantom Pepper 👻 |
| Legendary | Golden Apple 🍎, Celestial Pear ✨, Solar Bloom ☀️, Ancient Oak Fruit 🌳, Prism Grape 💎 |
| Mythic    | Void Crystal 🔮, Nebula Bloom 🌌, Eternal Lotus 🪷, Dragon Heart Fruit ❤️‍🔥, Genesis Seed 🌠 |

### 4.4 Roll animations

- **Single roll:** 1.8 s reveal animation — rarity panel fades in with colour-coded glow. Legendary/Mythic pulses.
- **x10 roll:** Rapid-fire display of all 10 in a scrolling panel; best pull gets a hero-card reveal at the end.
- **Sound:** Each rarity tier has its own sound cue (escalating pitch/drama).

---

## 5. Progression Systems

### 5.1 Plot progression

Players start with **3 plots**. Unlocking more costs coins. Maximum 25 plots.

| Plots | Total cost to reach |
|-------|----------------------|
| 5  | ~1 500 coins |
| 10 | ~88 000 coins |
| 15 | ~875 000 coins |
| 20 | ~10 million coins |
| 25 | ~50 million coins |

Late-game plot unlocks are intentionally expensive — they're status symbols and long-term goals.

### 5.2 Luck upgrades

- 20 levels available. Each level adds +5 to the Luck stat (max Luck = 100).
- Cost scales: `200 × 1.65^level`. Level 20 costs roughly 50 000 coins.
- Display: "🍀 Luck 35 (Lv7)" in the HUD.

### 5.3 Harvest Speed upgrades

- 15 levels available. Each level divides harvest time by 0.90 (×1.111 speed per level, multiplicative).
- Max speed = `1 / 0.9^15 ≈ 4.86×` faster than base. <!-- M-5: corrected from 4.7× — formula is 1/factor^level, not ×(1-0.10)^level; actual result at level 15 is 4.857× -->
- Cost scales: `350 × 1.80^level`. Level 15 costs roughly 300 000 coins.

### 5.4 Seed Dex (future)

Track which seeds have been obtained at least once. A complete Dex entry for a seed requires harvesting it 5 times. Completion rewards exclusive cosmetic titles ("Master Farmer", "Mythic Hunter").

---

## 6. Economy Design

### 6.1 Currencies

| Currency | Source | Sink |
|----------|--------|------|
| **Coins 🪙** | Harvesting crops | Rolls, upgrades, plot unlocks |
| **Gems 💎** | Daily streak, limited events | Future: premium rolls, cosmetics |
| **Robux** | Real money | Gamepass one-time purchases |

Gems are intentionally rare and saved for a future premium roll track. In v1 they are earned only through daily streaks.

### 6.2 Coin flow (mid-game player, 10 plots)

| Activity | Coins/hour (estimate) |
|----------|-----------------------|
| Rolling all coins | −3 000 |
| 10 × Common harvest | +1 200 |
| 2 × Uncommon harvest | +960 |
| 1 × Rare harvest | +1 240 |
| Lucky Legendary hit (~5 % session) | +15 000 expected value |
| **Net** | ≈ +15 400 (positive loop) |

The economy is designed so players always net-positive over time, keeping the roll habit sustainable. The gap widens dramatically with higher rarities, motivating continued upgrades.

### 6.3 Inflation control

- Plot unlock costs act as a major long-term coin sink.
- Upgrade costs use exponential scaling to absorb coin windfalls.
- No auction house or player trading to prevent economy disruption.

---

## 7. Monetization

All Robux purchases are **convenience and cosmetic only**. No seed can be purchased with Robux. No Robux purchase changes expected rarity outcomes beyond the shared Luck system.

### 7.1 Gamepasses

| Pass | Price (Robux) | Description |
|------|--------------|-------------|
| **Lucky Roll x10** | 199 | Unlocks the x10 roll bundle for 450 coins (vs. 500 for 10 singles). Also permanently shows odds percentage in the roll panel. |
| **Auto-Farm** | 399 | Server automatically harvests ready plots every 3 seconds. Player earns coins even while offline (capped at 6 hours offline AFK income). |
| **VIP Plot** | 299 | Unlocks 5 extra plot slots beyond normal max. Player starts with +5 unlocked. Also grants +15 flat Luck bonus and a golden plot border cosmetic. |

**Design intent:** Lucky Roll x10 is the entry-level purchase for engaged players. Auto-Farm is the "life quality" pass for busy/returning players. VIP Plot is for hardcore optimisers.

### 7.2 Developer Products (future)

| Product | Price | Description |
|---------|-------|-------------|
| Lucky Boost (1h) | 75 R$ | +20 Luck for 1 hour |
| Coin Boost (1h) | 75 R$ | +25 % harvest coin value for 1 hour |
| Instant Harvest | 25 R$ | Instantly ready all plots once |

Developer products will not be introduced until v1.1 to avoid launching with a pay-to-win perception.

---

## 8. Retention & Live Ops

### 8.1 Daily Login Streak

Rewarded on first login of each calendar day. Streak resets if 36+ hours pass without login (generous window for timezone variance).

| Day | Coins | Gems |
|-----|-------|------|
| 1 | 100 | 0 |
| 2 | 200 | 0 |
| 3 | 300 | 1 |
| 4 | 500 | 1 |
| 5 | 750 | 2 |
| 6 | 1 000 | 3 |
| 7 | 2 000 | 5 |

Day 7 ("Big Sunday") is designed to feel rewarding enough to maintain the 7-day habit loop. The cycle repeats.

### 8.2 Seasonal Seeds

Every major real-world season / Roblox event window, 1–2 limited seeds are added to the pool (e.g. "Jack-O-Lantern Seed" for Halloween, "Snowflake Crystal" for Winter). These:

- Have boosted value (1.5× seasonal multiplier)
- Are announced via in-game popup on login
- Disappear from the roll pool after the event ends
- Remain harvestable if already owned (no forced expiry)

### 8.3 Streak Bonuses

Milestone streaks (7, 14, 30, 100 days) grant cosmetic rewards: plot border colours, title badges, and an exclusive limited seed.

### 8.4 Social nudges

- "Your friend [X] just rolled a Mythic!" — proximity popup when a nearby player gets Legendary+
- Leaderboard appears on spawn — creates immediate status awareness
- Rare harvests have a visible particle effect visible to all players in the server

---

## 9. Competitive Layer

### 9.1 Leaderboard: Total Value Harvested

The primary leaderboard ranks players by cumulative lifetime coin value harvested (not current wallet balance — avoids discouraging spending). Stored in an `OrderedDataStore`.

- **Scope:** Global (server-wide visible, globally ranked)
- **Refresh:** Every 5 minutes
- **Display:** Top 100 on the leaderboard panel; top 3 highlighted with gold/silver/bronze

### 9.2 Weekly Leaderboard (future)

A rolling 7-day window leaderboard resets every Monday at midnight UTC. Top 3 receive cosmetic prizes (exclusive plot border, seed trail effect).

### 9.3 Luck Flex

The HUD shows each player's Luck stat publicly above their character as a floating badge. High-luck players stand out in the server and attract aspiration from newcomers.

---

## 10. World & Visual Tone

**Style:** Bright, cartoonish 3D — think Roblox Simulator aesthetic. Saturated colours, chunky rounded shapes.

**Environment:**
- Overworld: a sunny farm island with tiered elevated plots
- Plot grid: visible 5×5 tile arrangement, unlocked plots highlighted, locked ones greyed out
- Background: rolling hills, windmill, barn silhouette — creates the farming atmosphere

**Rarity VFX:**
- Common: small sparkle on harvest
- Uncommon: green leaf burst
- Rare: blue crystal shimmer
- Epic: purple energy spiral
- Legendary: orange flame pillar + screen vignette flash
- Mythic: full-screen red/black pulse + server-wide announcement particle

---

## 11. Audio Direction

| Context | Sound design |
|---------|-------------|
| Roll (Common) | Simple chime |
| Roll (Uncommon) | Brighter chime chord |
| Roll (Rare) | Rising arpeggio |
| Roll (Epic) | Dramatic fanfare sting |
| Roll (Legendary) | Full orchestral hit + reverb tail |
| Roll (Mythic) | Booming cinematic swell + choir |
| Harvest | Satisfying pluck/pop depending on rarity |
| Coin collect | Coin clink (pitch-shifted by amount) |
| UI clicks | Soft tap |
| Background music | Upbeat lo-fi farm ambient loop |

---

## 12. Feature Roadmap

### v1.0 (Launch)
- Core roll/plant/harvest loop
- 30 seeds across 6 rarities
- 25 plots, Luck + Harvest Speed upgrades
- Daily streak system
- Global leaderboard
- 3 gamepasses (Lucky x10, Auto-Farm, VIP Plot)

### v1.1
- Seed Dex (collection tracker)
- Developer Products (boosts)
- Improved roll animation with sound effects
- Admin commands for event seeds

### v1.2
- Seasonal seed event system
- Weekly leaderboard with prizes
- Luck Flex badge above characters
- Social "rare pull" server announcement

### v2.0
- Prestige system: reset farm for a permanent multiplier bonus
- Pet companions (separate gacha layer)
- Player trades (seeds only, limited to same rarity tier)
- Guild/Team farms
