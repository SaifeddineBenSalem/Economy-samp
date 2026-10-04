# 🚚 DeliveryCounter

A **SA-MP MoonLoader Lua script** that automatically tracks job-related statistics for the current player and stores them locally.

`DeliveryCounter` monitors SA-MP server messages and automatically detects:

* 🚛 Trucker deliveries
* 📦 Material deliveries
* 💰 Material package purchases
* 🏦 Bank/paycheck gains
* 👤 Current account identity
* 🌐 Current SA-MP server
* 📊 Persistent job statistics

All collected statistics are stored locally and associated with both the **server address** and the **player nickname**, allowing the same script to maintain separate statistics for different servers and accounts.

---

## ✨ Features

### 🚛 Trucker Delivery Tracking

The script automatically detects successful trucker deliveries by monitoring the server message:

```text
* You were paid $25,000 for delivering the goods and returning the truck.
```

When a valid reward is detected, the script:

1. Extracts the payment amount.
2. Converts the amount into a numeric value.
3. Increments the trucker delivery counter.
4. Adds the payment to total trucker earnings.
5. Saves the updated statistics to the local database.
6. Displays a notification in the SA-MP chat.
7. Records the event in the debug log.

Example notification:

```text
[DeliveryCounter] Delivery #15 | Earned: $25,000
```

---

### 📦 Material Delivery Tracking

The script also tracks material deliveries.

It recognizes messages following this structure:

```text
The factory gave you 100 materials for your delivery, on top of the 50 materials you already have.
```

The script extracts the amount of materials received from the delivery while intentionally ignoring the amount already possessed.

For every detected material delivery, it records:

* Number of material deliveries
* Materials received from deliveries
* Total materials collected

Example:

```text
[DeliveryCounter] Materials delivery #8 | Collected: 100 materials
```

---

### 💸 Material Package Purchase Tracking

The script detects material package purchases such as:

```text
* You bought 10 Material Packages for $500.
```

It extracts:

* Number of packages purchased
* Amount spent

The package quantity is displayed in the notification, while the **money spent** is accumulated into the persistent `materialsSpent` counter.

It supports amounts containing commas:

```text
$1,000
$25,000
$1,250,000
```

Example notification:

```text
[DeliveryCounter] Bought 10 material packages | Spent: $500 | Total spent: $5,000
```

---

### 🏦 Bank Gain Tracking

`DeliveryCounter` can calculate bank gains from paycheck/bank statement messages.

It detects two separate lines:

```text
Old balance: $914,734 | Interest rate: 0.5 percent (3k max)
```

and:

```text
New balance: $919,370 | Rent paid: $0
```

The script temporarily stores the old balance.

When the corresponding new balance arrives, it calculates:

```text
Bank Gain = New Balance - Old Balance
```

For example:

```text
$919,370 - $914,734 = $4,636
```

The resulting gain is added to the player's cumulative bank gain.

Example:

```text
[DeliveryCounter] Bank gain: +$4,636 | Total bank gain: $25,000
```

If a new balance is received without a previously captured old balance, the script does not calculate a gain.

---

## 👤 Server & Account Separation

One of the core features of `DeliveryCounter` is its ability to maintain independent statistics for different server/account combinations.

The script identifies the current SA-MP server using:

```text
IP:PORT
```

It also identifies the local player's nickname.

These two values are combined into a unique database key:

```text
server|account
```

Example:

```text
213.32.6.232:7777|Marko_Teller
```

This prevents statistics from different servers or accounts from being mixed together.

### Example

If the same player uses the script on:

```text
Server A
```

and:

```text
Server B
```

their statistics remain separate.

Likewise, different player accounts on the same server receive separate records.

---

# 💾 Persistent Local Database

The script uses a simple local text file instead of an external database.

The database file is:

```text
DeliveryCounter.txt
```

It is created inside the MoonLoader working directory.

Each database record is stored on one line using tab-separated values.

The current format contains seven fields:

```text
key
truckerDeliveries
truckerEarnings
materialDeliveries
materialsCollected
materialsSpent
bankGain
```

Example:

```text
213.32.6.232:7777|Marko_Teller    15    25000    8    350    10000    5000
```

The actual file uses tab characters between fields.

---

## 🛡️ Database Migration & Data Preservation

`DeliveryCounter` includes compatibility logic for previous database formats.

The script can recognize and load several historical formats.

### Current format — 7 fields

```text
key
deliveries
earnings
materialDeliveries
materialsCollected
materialsSpent
bankGain
```

### Previous format — 6 fields

```text
key
deliveries
earnings
materialDeliveries
materialsCollected
materialsSpent
```

The missing `bankGain` value is initialized to:

```text
0
```

### Previous format — 5 fields

```text
key
deliveries
earnings
materialDeliveries
materialsCollected
```

The newly introduced counters are initialized to zero.

### Older format — 3 fields

```text
key
deliveries
earnings
```

Material and bank counters are initialized to zero.

### Very old format — 2 fields

```text
key
deliveries
```

The remaining counters are initialized to zero.

This migration system is designed to preserve existing statistics when the database structure evolves.

Invalid database lines are ignored rather than causing the entire database to fail.

---

# 📊 Tracked Statistics

For each server/account combination, the script maintains the following information:

| Statistic            | Description                                |
| -------------------- | ------------------------------------------ |
| `deliveries`         | Number of successful trucker deliveries    |
| `earnings`           | Total money earned from trucker deliveries |
| `materialDeliveries` | Number of material deliveries              |
| `materialsCollected` | Total materials received from deliveries   |
| `materialsSpent`     | Total money spent on material packages     |
| `bankGain`           | Total calculated bank/paycheck gains       |

---

# 💻 `/jobcounters`

The script provides a custom command:

```text
/jobcounters
```

This command is handled locally and is **not sent to the SA-MP server**.

When executed, it displays the player's accumulated statistics.

Example:

```text
You have delivered 15 times using trucker job. You had earned 25,000 amount.

You delivered materials 8 times. You collected 350 materials and spent a total of 10,000.

Total bank gain from paychecks: $5,000.
```

The command retrieves the statistics belonging to the currently detected:

```text
Server + Account
```

combination.

---

# 🔍 Message Detection

The script listens to SA-MP server messages through:

```lua
sampev.onServerMessage(color, text)
```

Before processing a message, it performs several cleaning operations.

### Color-code removal

SA-MP color codes such as:

```text
{FFFFFF}
{00FF00}
{FFFF00}
```

are removed before pattern matching.

### Timestamp removal

Messages containing timestamps such as:

```text
[20:34:02] Message
```

are converted into:

```text
Message
```

This makes message matching more reliable.

---

# 🧠 Detection Pipeline

Every incoming server message goes through the following process:

```text
SA-MP Server Message
        │
        ▼
Remove Color Codes
        │
        ▼
Remove Optional Timestamp
        │
        ▼
Trim Whitespace
        │
        ▼
Check Trucker Reward
        │
        ├── Match → Update Trucker Statistics
        │
        ▼
Check Material Delivery
        │
        ├── Match → Update Material Statistics
        │
        ▼
Check Material Purchase
        │
        ├── Match → Update Spending
        │
        ▼
Check Bank Old Balance
        │
        ├── Match → Store Temporary Balance
        │
        ▼
Check Bank New Balance
        │
        └── Match → Calculate Bank Gain
```

The detection functions use Lua pattern matching to identify only the expected message structures.

---

# 🗂️ File Structure

A typical installation contains:

```text
MoonLoader/
│
├── DeliveryCounter.lua
│
├── DeliveryCounter.txt
│
└── DeliveryCounter_debug.log
```

### `DeliveryCounter.lua`

The main MoonLoader script.

Contains:

* Server/account identification
* Message parsing
* Counter management
* Database handling
* Migration logic
* `/jobcounters`
* Debug logging
* Startup logic

### `DeliveryCounter.txt`

Persistent local statistics database.

The file is automatically created when necessary.

### `DeliveryCounter_debug.log`

Debug and diagnostic log.

The script writes timestamps and detailed information about:

* Script startup
* Server identification
* Account identification
* Database loading
* Database migration
* Message detection
* Counter updates
* Database saving
* Command execution
* Errors

---

# 🐛 Debug Logging

A dedicated debug system is included to make troubleshooting easier.

The log file is:

```text
DeliveryCounter_debug.log
```

Log entries contain timestamps in the format:

```text
DD/MM/YYYY HH:MM:SS
```

Example:

```text
[04/10/2026 17:10:25] DeliveryCounter STARTING
```

The script records both original and cleaned server messages:

```text
SERVER MESSAGE:
CLEAN MESSAGE:
```

It also records important events such as:

```text
TRUCKER DELIVERY DETECTED
MATERIAL DELIVERY DETECTED
MATERIAL PACKAGE PURCHASE DETECTED
BANK STATEMENT GAIN RECORDED
DATABASE SAVED
DATABASE LOAD COMPLETE
```

This makes it easier to diagnose message-format changes or unexpected behavior.

---

# ⚙️ Requirements

The script is designed for a SA-MP environment using MoonLoader.

Required components include:

* **GTA: San Andreas**
* **SA-MP**
* **MoonLoader**
* Lua support provided by MoonLoader
* `lib.moonloader`
* `lib.samp.events`

The script imports:

```lua
require "lib.moonloader"
```

and:

```lua
local sampev = require "lib.samp.events"
```

---

# 📥 Installation

## 1. Install MoonLoader

Make sure MoonLoader is installed and working with your GTA: San Andreas / SA-MP installation.

---

## 2. Download the script

Download:

```text
DeliveryCounter.lua
```

---

## 3. Place the script in MoonLoader

Copy:

```text
DeliveryCounter.lua
```

into your MoonLoader scripts directory:

```text
GTA San Andreas/
└── moonloader/
    └── DeliveryCounter.lua
```

---

## 4. Start SA-MP

Launch GTA: San Andreas and connect to your SA-MP server.

The script waits until SA-MP becomes available before continuing.

---

## 5. Wait for account identification

After SA-MP becomes available, the script attempts to identify:

```text
Server IP:Port
```

and:

```text
Local player nickname
```

Once the identity is successfully detected, the corresponding database entry is loaded or created.

---

# 🚀 Startup Behavior

When the script starts, it follows this sequence:

```text
Start Script
     │
     ▼
Wait for SA-MP
     │
     ▼
Load Local Database
     │
     ▼
Wait for Local Player
     │
     ▼
Identify Server
     │
     ▼
Identify Account
     │
     ▼
Create / Load Account Record
     │
     ▼
Display Current Statistics
     │
     ▼
Begin Monitoring Server Messages
```

The script continuously checks the player's identity while running.

---

# 🔐 Data Safety

The script stores its statistics locally.

It does **not** use an external web server or remote database.

The statistics are written to:

```text
DeliveryCounter.txt
```

The script also does not send the `/jobcounters` command to the server. It returns `false` from the command hook after processing it locally.

---

# 🧩 Internal Architecture

The script is divided into several logical sections.

### Configuration

Defines local database and debug-log paths.

```lua
local COUNTER_FILE = getWorkingDirectory() .. "\\DeliveryCounter.txt"
local DEBUG_FILE = getWorkingDirectory() .. "\\DeliveryCounter_debug.log"
```

### Variables

Maintains:

```lua
counters
currentServer
currentAccount
pendingOldBalance
```

### String Helpers

Provides utility functions such as:

```lua
trim()
```

### Message Cleaning

Provides:

```lua
removeColorCodes()
cleanMessage()
```

### Identity Management

Provides:

```lua
getServerIdentifier()
getAccountIdentifier()
updateIdentity()
```

### Database

Provides:

```lua
saveCounters()
loadCounters()
```

### Statistics

Provides functions for updating:

```text
Trucker deliveries
Trucker earnings
Material deliveries
Materials collected
Materials spent
Bank gains
```

### Detection

Provides specialized message detectors for each supported activity.

### SA-MP Event Handlers

The script uses:

```lua
sampev.onServerMessage()
```

and:

```lua
sampev.onSendCommand()
```

### Main Loop

The `main()` function initializes the script and continuously maintains player identity.

---

# 📐 Data Model

Each player/server entry is represented internally as:

```lua
{
    deliveries = 0,
    earnings = 0,

    materialDeliveries = 0,
    materialsCollected = 0,

    materialsSpent = 0,

    bankGain = 0
}
```

The record is stored under a unique key:

```text
SERVER_IP:PORT|PLAYER_NICKNAME
```

Example:

```text
213.32.6.232:7777|Marko_Teller
```

---

# 💰 Number Formatting

The script includes a custom money-formatting function.

Large numbers are displayed with comma separators.

For example:

```text
25000
```

becomes:

```text
25,000
```

and:

```text
1250000
```

becomes:

```text
1,250,000
```

This formatting is used for in-game notifications and statistics.

---

# ⚠️ Message Format Dependency

`DeliveryCounter` relies on the exact structure of SA-MP server messages.

For example, the trucker detection expects a message matching the structure:

```text
* You were paid $AMOUNT for delivering the goods and returning the truck.
```

Similarly, material and bank detection depend on their expected server messages.

If the server changes its message wording, capitalization, punctuation, or formatting, the corresponding detector may stop matching.

If this happens, check:

```text
DeliveryCounter_debug.log
```

The original server messages are recorded there to help update the matching patterns.

---

# 🛠️ Troubleshooting

## Script does not load

Verify:

* MoonLoader is installed correctly.
* `DeliveryCounter.lua` is inside the MoonLoader folder.
* The required SA-MP libraries are available.
* GTA: San Andreas and SA-MP are running correctly.

---

## Account cannot be identified

Check:

```text
DeliveryCounter_debug.log
```

The script logs account-identification failures.

The account identification process uses the local player's SA-MP player ID and nickname.

---

## Delivery is not detected

Check the debug log for:

```text
SERVER MESSAGE:
```

and:

```text
CLEAN MESSAGE:
```

Compare the actual server message with the expected message format.

---

## Statistics are not saved

Check whether:

```text
DeliveryCounter.txt
```

can be created/written inside the MoonLoader working directory.

The script logs database-writing errors.

---

## Old statistics disappeared

The script is designed to support multiple previous database formats and migrate missing fields while preserving existing values.

Before manually deleting or modifying:

```text
DeliveryCounter.txt
```

make a backup.

---

# 🔄 Database Compatibility

The project intentionally includes backward-compatible loading logic.

This means new versions can introduce additional counters without requiring users to manually recreate their existing database.

For example, when `bankGain` was introduced, older records without the field are loaded with:

```text
bankGain = 0
```

Likewise, older material-related records receive zero values for newly introduced counters.

This approach allows the script to evolve while keeping existing statistics.

---

# 📋 Example Usage

After starting the game and loading the script:

```text
[DeliveryCounter] Script loaded.
[DeliveryCounter] Account: Marko_Teller | Trucker: 15 | Earned: $25,000
[DeliveryCounter] Materials: 8 | Collected: 350 | Spent: $10,000
[DeliveryCounter] Bank gain: $5,000
```

After completing another trucker delivery:

```text
[DeliveryCounter] Delivery #16 | Earned: $20,000
```

After receiving materials:

```text
[DeliveryCounter] Materials delivery #9 | Collected: 100 materials
```

After purchasing packages:

```text
[DeliveryCounter] Bought 10 material packages | Spent: $500 | Total spent: $10,500
```

After a bank statement gain:

```text
[DeliveryCounter] Bank gain: +$4,636 | Total bank gain: $9,636
```

Running:

```text
/jobcounters
```

displays the current accumulated statistics.

---

# 🧪 Example Database

A database entry conceptually looks like:

```text
213.32.6.232:7777|Marko_Teller    16    45000    9    450    10500    9636
```

Representing:

```text
Server:
213.32.6.232:7777

Account:
Marko_Teller

Trucker deliveries:
16

Trucker earnings:
$45,000

Material deliveries:
9

Materials collected:
450

Materials spent:
$10,500

Bank gain:
$9,636
```

---

# 🔧 Customization

The script can be customized by modifying its Lua source.

Potential customization areas include:

* Detection patterns
* Chat notifications
* Database fields
* Statistics displayed by `/jobcounters`
* Debug logging
* Supported job messages
* Number formatting
* Database migration logic

When modifying detection patterns, make sure the new patterns continue to safely validate numeric values before updating statistics.

---

# 📌 Important Implementation Details

### Local statistics

All statistics are maintained locally.

### Server-specific records

Statistics are separated by server address.

### Account-specific records

Statistics are separated by player nickname.

### Automatic persistence

Statistics are saved whenever a counter changes.

### Automatic migration

Older database formats can be loaded and upgraded.

### Local command

`/jobcounters` is processed locally and is not transmitted to the server.

### Debugging

Detailed diagnostic information is written to a dedicated log file.

---

# 📁 Recommended Project Structure

```text
DeliveryCounter/
│
├── DeliveryCounter.lua
├── DeliveryCounter.txt
├── DeliveryCounter_debug.log
└── README.md
```

The database and debug files are generated/used at runtime and do not necessarily need to be included in the Git repository.

For a clean GitHub repository, the recommended tracked files are:

```text
DeliveryCounter.lua
README.md
```

---

# 🧹 Git Ignore Recommendation

If you do not want personal runtime statistics and debug logs uploaded to GitHub, add them to `.gitignore`:

```gitignore
DeliveryCounter.txt
DeliveryCounter_debug.log
```

This keeps your repository focused on the source code while preventing personal runtime data from being committed.

---

# 🔒 Privacy Considerations

The local database contains information used to identify a server/account combination, including:

* Server IP and port
* Player nickname
* Accumulated statistics

If publishing the runtime database publicly, review its contents first.

For a public GitHub repository, it is recommended to keep:

```text
DeliveryCounter.txt
```

and:

```text
DeliveryCounter_debug.log
```

out of version control.

---

# 🧑‍💻 Author

**Saifeddine Ben Salem**

Lua / SA-MP MoonLoader development project.

---

# 📜 License

No license is currently specified by the project.

If you intend to allow others to use, modify, or redistribute the script, consider adding an explicit open-source license such as MIT.

Without a license, the default copyright rules generally apply.

---

# ⭐ Project Overview

`DeliveryCounter` is a lightweight local statistics tracker for SA-MP players who want to keep historical records of job activity without manually counting deliveries or maintaining external spreadsheets.

Its main design principles are:

```text
Automatic Detection
        +
Persistent Local Storage
        +
Server/Account Separation
        +
Backward-Compatible Database
        +
Debug Logging
        =
Reliable Job Statistics
```

The script operates entirely through MoonLoader and SA-MP event hooks, automatically interpreting relevant server messages and updating the corresponding local statistics.

---

## 🚀 Future Expansion Ideas

Possible future improvements could include:

* 📊 In-game graphical statistics
* 📈 Earnings-per-hour calculations
* 📅 Daily/weekly/monthly statistics
* 🚛 Separate statistics for additional jobs
* 💾 Database export/import
* 🔎 Searchable historical records
* 📋 Detailed delivery history
* 📊 Session statistics
* 🏆 Personal records
* 📈 Earnings graphs
* ⚙️ Configurable detection patterns
* 🌐 Multi-server statistics overview
* 🖥️ Custom MoonLoader UI

These are potential extensions and are **not currently implemented** in the provided version.
