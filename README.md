# MyKey: Mythic Keystone Mesh Network

A lightweight, standalone World of Warcraft micro-addon designed for 3.3.5a private server frameworks. **MyKey** automates the tracking, synchronization, and reporting of custom Mythic+ keystones across your guild completely hands-free using an invisible peer-to-peer gossip protocol.

<img width="1276" height="694" alt="image" src="https://github.com/user-attachments/assets/9c52d3e0-ef34-4112-adcd-4470d7885a5c" />



---

## 🚀 Features

* **Live Sidebar UI Interface:** Automatically attaches itself to the left border of your server's native `MythicPlusFrame`. Dynamically auto-sizes its height and layer strata to perfectly match the main panel on tab changes.
* **Asynchronous P2P Gossip Sync:** Uses background data channels (`SendAddonMessage`) to pass keystone profiles between online guild members. Data updates contain Unix timestamps to ensure your local cache stays flawlessly healed and up-to-date.
* **Persistent Saving:** Saves accumulated guild keystone data directly to your hard drive (`SavedVariables`), meaning your network history survives full relogs, UI reloads, and game closures.
* **Dynamic Range Tracking:** Bypasses tedious individual item ID tables by mathematically scanning the server's custom `900,000` to `1,000,000` item ID block.
* **Chat Command Auto-Responder:** Listens for the classic `?keys` prompt in Party, Raid, Guild, and Officer channels and instantly replies with your active keys (fully customizable via toggles).

---

## 🛠️ Installation

1. Download this as a `MyKey.zip` file using the green `<> Code` button
2. Extract that .zip to your World of Warcraft installation directory in the `Interface\AddOns\` folder.
4. Make sure the new folder is named exactly **`MyKey`** (capitalization matters!).

### Expected Directory Tree:
```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── MyKey/
            ├── MyKey.toc
            └── MyKey.lua
```
## ⌨️ Commands

### Chat Commands
| Trigger | Channel | Description |
| :--- | :--- | :--- |
| `?keys` | Guild, Officer, Party, Raid | Automatically responds to the active channel with your clickable keystone links. |

### Slash Commands
* `/mykey` or `/mykeyres` — Opens the local control panel configuration menu.
* `/m+` or `/mythic` opens the whole Mythic Plus frame for Triumvirate

#### Configuration Options (Toggles)
Type these commands to enable or disable auto-responding to specific text chat invites:
* `/mykey guild` — Toggle Guild channel auto-response.
* `/mykey party` — Toggle Party channel auto-response.
* `/mykey raid` — Toggle Raid channel auto-response.
* `/mykey officer` — Toggle Officer channel auto-response.

---

## 🔬 How the Mesh Network Works

1. **The Handshake:** When you open your server's affix frame, your client sends out a hidden background request packet (`MKR_REQ`) across the guild network.
2. **The Evaluation:** Active guildmates running **MyKey** evaluate your request against their data timestamps. If their data is fresher, your local interface rewrites and populates the player list instantly.
3. **Self-Healing:** If a player logs in with outdated or corrupted history cache, your client detects the superior timestamp in your `SavedVariables` file and quietly pushes a corrective repair packet out to the network.
