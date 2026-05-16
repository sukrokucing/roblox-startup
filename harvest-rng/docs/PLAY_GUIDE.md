# Harvest RNG — Play Guide

## Quick Setup with Rojo (Recommended)

### One-time Rokit install

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

Open a new terminal after installing Rokit so `rokit` is available on your PATH.

### Start Rojo sync

```bash
cd harvest-rng
rokit trust rojo-rbx/rojo
rokit install
rojo plugin install
rojo serve default.project.json
```

If you already have Rojo installed, `rojo --version` should report Rojo 7.x. The project pins Rojo in `rokit.toml`, so `rokit install` is the repeatable setup command for this repo.

Then in Roblox Studio: open the Rojo plugin panel → **Connect**.
All files sync automatically on save. Press **Play** (F5) to test.

---

## Manual Setup (No Rojo)

### Step 1 — Create Explorer structure in Studio

```
ServerScriptService/
  GameManager          ← Script
  modules/             ← Folder
    DataManager        ← ModuleScript
    RNGManager         ← ModuleScript
    FarmManager        ← ModuleScript

ReplicatedStorage/
  Shared/              ← Folder
    Config             ← ModuleScript
    RemoteEvents       ← ModuleScript
    SeedData           ← ModuleScript

StarterPlayer/
  StarterPlayerScripts/
    MainClient         ← LocalScript
    modules/           ← Folder
      UIManager        ← ModuleScript
      InventoryManager ← ModuleScript
```

### Step 2 — Copy script contents

| File in repo | Studio destination |
|---|---|
| `src/server/GameManager.server.lua` | ServerScriptService > **GameManager** (Script) |
| `src/server/modules/DataManager.lua` | ServerScriptService > modules > **DataManager** |
| `src/server/modules/RNGManager.lua` | ServerScriptService > modules > **RNGManager** |
| `src/server/modules/FarmManager.lua` | ServerScriptService > modules > **FarmManager** |
| `src/shared/Config.lua` | ReplicatedStorage > Shared > **Config** |
| `src/shared/RemoteEvents.lua` | ReplicatedStorage > Shared > **RemoteEvents** |
| `src/shared/SeedData.lua` | ReplicatedStorage > Shared > **SeedData** |
| `src/client/MainClient.client.lua` | StarterPlayerScripts > **MainClient** (LocalScript) |
| `src/client/modules/UIManager.lua` | StarterPlayerScripts > modules > **UIManager** |
| `src/client/modules/InventoryManager.lua` | StarterPlayerScripts > modules > **InventoryManager** |

### Step 3 — Build the GUI

1. Open **View → Command Bar** in Studio
2. Paste the entire contents of `src/studio/BuildGUI.lua`
3. Press **Enter**
4. You should see: `✅ HarvestRNG_GUI built — N instances. Press Play to test!`

### Step 4 — Play

Press **F5** (Play). No errors should appear in Output.

---

## Gameplay Loop

For a first-session route, see [NEW_PLAYER_WALKTHROUGH.md](NEW_PLAYER_WALKTHROUGH.md).

| Step | Action |
|------|--------|
| 1️⃣ | **Roll** — Click "Roll" (50 coins) or "Roll ×10" (450 coins) to get random seeds. New seeds are added to Inventory immediately, with a color-coded procedural crop icon for each seed. |
| 2️⃣ | **Plant** — Click "Plant" on an empty plot → pick a seed from the modal; the matching 3D plot shows a small centered crop marker while it grows |
| 3️⃣ | **Wait** — Timer counts down on each plot (Common = 30s, Mythic = up to 4h) |
| 4️⃣ | **Harvest** — Click "Harvest" when plot shows ✅ Ready! → coins pop up |
| 5️⃣ | **Hide/Show Farm** — The farm grid is docked on the right side so the center view stays clear. Click **Hide** when you want maximum camera space, then **Show** to bring the grid back. |
| 6️⃣ | **Upgrade** — Spend coins on Luck (better RNG) or Harvest Speed (faster grows). Upgrade buttons show the next scaled coin cost for your current level. |
| 7️⃣ | **Unlock Plots** — Click 🔒 on a locked plot to buy it with coins; the unlock is saved immediately and the matching 3D plot sheds its lock marker |
| 8️⃣ | **Repeat** — Roll more seeds, flex rare finds on the leaderboard |

---

## Rarity Table

| Rarity | Weight | Base Value Range | Harvest Time |
|--------|--------|-----------------|--------------|
| Common | 55% | 10–22 coins | 30–55s |
| Uncommon | 25% | 65–120 coins | 75–115s |
| Rare | 12% | 380–620 coins | 3–5 min |
| Epic | 5% | 2,200–4,800 coins | 10–15 min |
| Legendary | 2.5% | 15,000–42,000 coins | 30–60 min |
| Mythic | 0.5% | 150,000–500,000 coins | 2–4 hours |

---

## Before Publishing

1. Create 3 gamepasses in [Roblox Creator Dashboard](https://create.roblox.com):
   - **Lucky Roll ×10** — replace x10 bundle with free rolls
   - **Auto-Farm** — auto-harvest every 3 seconds  
   - **VIP Plot** — +5 extra plots, +15 luck bonus

2. Update `src/shared/Config.lua`:
```lua
Config.GAMEPASS_IDS = {
    LuckyRollX10 = 12345678,   -- your actual IDs
    AutoFarm     = 12345679,
    VIPPlot      = 12345680,
}
```

3. Change `Config.DATASTORE_NAME` to a unique string before first publish to avoid data conflicts.

4. Set up `OrderedDataStore` key in `Config.LEADERBOARD_KEY` (default: `"TotalHarvested_v1"`).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `WaitForChild timeout` on HarvestRNG_GUI | Run `BuildGUI.lua` from command bar first |
| `attempt to index nil (Events)` | Server started before GUI — wait for server to fully init |
| DataStore errors in Studio | Normal in Studio; works on live server with published place |
| Plots don't show up | Check `PlotContainer` is a ScrollingFrame with UIGridLayout child |
| Picker shows a seed but planting says you don't have it | Reopen the picker after the toast; the server now refreshes inventory after every plant attempt |
| Leaderboard or Inventory covers the screen | Click the red **X** in the panel corner or click the matching HUD button again |
| Inventory looks empty after rolling | Stop/Play after updating; rolls now push `InventoryUpdate` and the Inventory panel renders seed rows |
