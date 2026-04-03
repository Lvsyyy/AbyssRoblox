# AbyssRoblox
If you somehow find this feel free to use these scripts for your own quality of life.
If you use this inside a public script / hub do not obfuscate it support Open Source don't be a skid.

## [Roblox Abyss](https://www.roblox.com/games/127794225497302/Abyss)

## Files
| File | Description |
| --- | --- |
| `abyss_Framework.lua` | Shared helpers (list UI, inventory pipeline, sell-all, anti-AFK, etc). |
| `abyss_GUI.lua` | Tabbed GUI that loads and calls the other scripts via loadstring. |
| `abyss_ArtifactManager.lua` | Artifact scan/update/delete logic used by the GUI. |
| `abyss_AutoDaily.lua` | Auto-claims daily rewards using data timestamps (no polling). |
| `abyss_AutoFishDelete.lua` | Deletes fish by exact name match (no UI scanning). |
| `abyss_AutoGeode.lua` | Opens selected geodes based on backpack/hotbar counts. |
| `abyss_GeodeOnly.lua` | Cancels non-reward minigame progress updates for geode-only flow. |
| `abyss_AutoRoe.lua` | Auto-collects roe when pond reaches threshold. |
| `abyss_AutoShopBuyer.lua` | Auto-buys selected merchant items when stock changes. |
| `abyss_AutoRejoin.lua` | Rejoins after kick/error prompt and re-executes the configured script on teleport. |
| `abyss_FishPond.lua` | Pond deposit/withdraw logic using value calculator. |
| `abyss_PortableStash.lua` | Deposits and withdraws fish with weight-based ordering. |
| `abyss_ValueCalculator.lua` | Scans base values/mutations and computes fish value. |

## Run This
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_GUI.lua"))()
```

## Preview (Outdated)
<img width="960" height="540" alt="{DA3943A9-F18B-4D2F-BD5C-835F9CE1FB14}" src="https://github.com/user-attachments/assets/e13312cd-f0a5-4ca3-9917-751ca9c9ef9c" />
<img width="960" height="540" alt="{B94F9FEA-E131-4FE2-A5FE-4D1C4E9C104A}" src="https://github.com/user-attachments/assets/fad1e1a5-d906-40c2-88f5-723b60520bf2" />
<img width="960" height="540" alt="{366D15E7-21F3-409C-B593-D0E2F3FDCCB9}" src="https://github.com/user-attachments/assets/18803b1a-e2b0-466d-8606-cc5a8874655d" />
<img width="960" height="540" alt="{5A7ADC19-733D-4416-82D7-E39D7794D8C1}" src="https://github.com/user-attachments/assets/55deeb11-acef-4dca-8bd6-7358c5939106" />
