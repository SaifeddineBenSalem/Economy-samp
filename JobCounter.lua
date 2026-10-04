script_name("DeliveryCounter")
script_author("Saifeddine Ben Salem")

require "lib.moonloader"
local sampev = require "lib.samp.events"

-- =========================================================
-- CONFIGURATION
-- =========================================================

local COUNTER_FILE = getWorkingDirectory() .. "\\DeliveryCounter.txt"
local DEBUG_FILE = getWorkingDirectory() .. "\\DeliveryCounter_debug.log"

-- =========================================================
-- VARIABLES
-- =========================================================

local counters = {}

local currentServer = nil
local currentAccount = nil

local pendingOldBalance = nil

-- =========================================================
-- DEBUG
-- =========================================================

local function debugLog(text)

    local file = io.open(DEBUG_FILE, "a")

    if file then

        file:write(
            string.format(
                "[%s] %s\n",
                os.date("%d/%m/%Y %H:%M:%S"),
                tostring(text)
            )
        )

        file:close()

    end

end

-- =========================================================
-- STRING HELPERS
-- =========================================================

local function trim(text)

    if not text then
        return ""
    end

    return text:match("^%s*(.-)%s*$") or ""

end

-- =========================================================
-- REMOVE SA-MP COLOR CODES
-- =========================================================

local function removeColorCodes(text)

    if not text then
        return ""
    end

    return text:gsub("{%x%x%x%x%x%x}", "")

end

-- =========================================================
-- CLEAN SERVER MESSAGE
-- =========================================================

local function cleanMessage(text)

    if not text then
        return ""
    end

    -- Remove SA-MP color codes.
    text = removeColorCodes(text)

    -- Remove optional timestamp.
    --
    -- [20:34:02] Message
    -- becomes:
    -- Message

    text = text:gsub(
        "^%s*%[%d%d:%d%d:%d%d%]%s*",
        ""
    )

    return trim(text)

end

-- =========================================================
-- SERVER IDENTIFICATION
-- =========================================================

local function getServerIdentifier()

    local success, ip, port =
        pcall(
            sampGetCurrentServerAddress
        )

    if success and ip and port then

        return tostring(ip) .. ":" .. tostring(port)

    end

    debugLog(
        "SERVER IDENTIFICATION FAILED"
    )

    return nil

end

-- =========================================================
-- LOCAL ACCOUNT IDENTIFICATION
-- =========================================================

local function getAccountIdentifier()

    if not isSampAvailable() then

        debugLog(
            "ACCOUNT: SA-MP not available."
        )

        return nil

    end

    -- IMPORTANT:
    --
    -- sampGetPlayerIdByCharHandle()
    -- returns:
    --
    -- result, playerId
    --

    local result, playerId =
        sampGetPlayerIdByCharHandle(
            PLAYER_PED
        )

    debugLog(
        "ACCOUNT RAW ID RESULT | result=" ..
        tostring(result) ..
        " | playerId=" ..
        tostring(playerId)
    )

    if not result then

        debugLog(
            "ACCOUNT: sampGetPlayerIdByCharHandle returned false."
        )

        return nil

    end

    if not playerId then

        debugLog(
            "ACCOUNT: playerId is nil."
        )

        return nil

    end

    playerId = tonumber(playerId)

    if not playerId then

        debugLog(
            "ACCOUNT: playerId is not numeric."
        )

        return nil

    end

    debugLog(
        "ACCOUNT: LOCAL PLAYER ID = " ..
        tostring(playerId)
    )

    -- DO NOT use sampIsPlayerConnected().
    --
    -- The local player can have a valid ID even when
    -- sampIsPlayerConnected() incorrectly reports false.
    --

    local success, nickname =
        pcall(
            sampGetPlayerNickname,
            playerId
        )

    if not success then

        debugLog(
            "ACCOUNT: sampGetPlayerNickname FAILED | ID=" ..
            tostring(playerId) ..
            " | Error=" ..
            tostring(nickname)
        )

        return nil

    end

    debugLog(
        "ACCOUNT: RAW LOCAL NICKNAME = " ..
        tostring(nickname)
    )

    if not nickname then

        debugLog(
            "ACCOUNT: Nickname returned nil."
        )

        return nil

    end

    nickname =
        trim(
            tostring(nickname)
        )

    if nickname == "" then

        debugLog(
            "ACCOUNT: Nickname is empty."
        )

        return nil

    end

    debugLog(
        "ACCOUNT SUCCESS | LOCAL PLAYER ID=" ..
        tostring(playerId) ..
        " | NICKNAME=" ..
        nickname
    )

    return nickname

end

-- =========================================================
-- DATABASE KEY
-- =========================================================

local function makeKey(server, account)

    return tostring(server) ..
        "|" ..
        tostring(account)

end

-- =========================================================
-- FORMAT NUMBERS
-- =========================================================

local function formatMoney(amount)

    amount =
        math.floor(
            tonumber(amount) or 0
        )

    local formatted =
        tostring(amount)

    while true do

        local newResult, count =
            formatted:gsub(
                "^(-?%d+)(%d%d%d)",
                "%1,%2"
            )

        formatted = newResult

        if count == 0 then
            break
        end

    end

    return formatted

end

-- =========================================================
-- SAVE DATABASE
-- =========================================================
--
-- CURRENT FORMAT:
--
-- key
-- truckerDeliveries
-- truckerEarnings
-- materialDeliveries
-- materialsCollected
-- materialsSpent
--
-- Example:
--
-- 213.32.6.232:7777|Marko_Teller
-- 15
-- 25000
-- 8
-- 350
-- 10000
--
-- Everything is kept on ONE line separated by tabs.
--
-- =========================================================

local function saveCounters()

    local file =
        io.open(
            COUNTER_FILE,
            "w"
        )

    if not file then

        debugLog(
            "ERROR: Could not open database for writing."
        )

        return false

    end

    for key, data in pairs(counters) do

        local truckerDeliveries =
            math.floor(
                tonumber(data.deliveries) or 0
            )

        local truckerEarnings =
            math.floor(
                tonumber(data.earnings) or 0
            )

        local materialDeliveries =
            math.floor(
                tonumber(data.materialDeliveries) or 0
            )

        local materialsCollected =
            math.floor(
                tonumber(data.materialsCollected) or 0
            )

        local materialsSpent =
            math.floor(
                tonumber(data.materialsSpent) or 0
            )

        local bankGain =
            math.floor(
                tonumber(data.bankGain) or 0
            )

        file:write(
            key:gsub("\t", " "),
            "\t",
            tostring(truckerDeliveries),
            "\t",
            tostring(truckerEarnings),
            "\t",
            tostring(materialDeliveries),
            "\t",
            tostring(materialsCollected),
            "\t",
            tostring(materialsSpent),
            "\t",
            tostring(bankGain),
            "\n"
        )

    end

    file:close()

    debugLog(
        "DATABASE SAVED"
    )

    return true

end

-- =========================================================
-- LOAD DATABASE
-- =========================================================

local function loadCounters()

    counters = {}

    local file =
        io.open(
            COUNTER_FILE,
            "r"
        )

    if not file then

        debugLog(
            "COUNTER DATABASE DOES NOT EXIST - Starting new database."
        )

        return

    end

    for line in file:lines() do

        -- =================================================
        -- CURRENT FORMAT - 7 FIELDS
        -- =================================================

        local key,
              deliveries,
              earnings,
              materialDeliveries,
              materialsCollected,
              materialsSpent,
              bankGain =
            line:match(
                "^(.-)\t(%d+)\t([%d%.]+)\t(%d+)\t([%d%.]+)\t([%d%.]+)\t(%-?[%d%.]+)$"
            )

        if key
           and deliveries
           and earnings
           and materialDeliveries
           and materialsCollected
           and materialsSpent
           and bankGain then

            counters[key] = {

                deliveries =
                    tonumber(deliveries) or 0,

                earnings =
                    tonumber(earnings) or 0,

                materialDeliveries =
                    tonumber(materialDeliveries) or 0,

                materialsCollected =
                    tonumber(materialsCollected) or 0,

                materialsSpent =
                    tonumber(materialsSpent) or 0,

                bankGain =
                    tonumber(bankGain) or 0

            }

            debugLog(
                "DATABASE ENTRY LOADED | " ..
                "Key=" .. tostring(key) ..
                " | Trucker Deliveries=" ..
                tostring(deliveries) ..
                " | Trucker Earnings=" ..
                tostring(earnings) ..
                " | Material Deliveries=" ..
                tostring(materialDeliveries) ..
                " | Materials Collected=" ..
                tostring(materialsCollected) ..
                " | Materials Spent=" ..
                tostring(materialsSpent) ..
                " | Bank Gain=" ..
                tostring(bankGain)
            )

        else

            -- =================================================
            -- PREVIOUS FORMAT - 6 FIELDS
            -- =================================================

            local key6,
                  deliveries6,
                  earnings6,
                  materialDeliveries6,
                  materialsCollected6,
                  materialsSpent6 =
                line:match(
                    "^(.-)\t(%d+)\t([%d%.]+)\t(%d+)\t([%d%.]+)\t([%d%.]+)$"
                )

            if key6
               and deliveries6
               and earnings6
               and materialDeliveries6
               and materialsCollected6
               and materialsSpent6 then

                counters[key6] = {

                    deliveries =
                        tonumber(deliveries6) or 0,

                    earnings =
                        tonumber(earnings6) or 0,

                    materialDeliveries =
                        tonumber(materialDeliveries6) or 0,

                    materialsCollected =
                        tonumber(materialsCollected6) or 0,

                    materialsSpent =
                        tonumber(materialsSpent6) or 0,

                    bankGain = 0

                }

                debugLog(
                    "6-FIELD DATABASE ENTRY MIGRATED | " ..
                    "Key=" .. tostring(key6) ..
                    " | Trucker Deliveries=" ..
                    tostring(deliveries6) ..
                    " | Trucker Earnings=" ..
                    tostring(earnings6) ..
                    " | Material Deliveries=" ..
                    tostring(materialDeliveries6) ..
                    " | Materials Collected=" ..
                    tostring(materialsCollected6) ..
                    " | Materials Spent=" ..
                    tostring(materialsSpent6) ..
                    " | Bank Gain=0"
                )

            else

            -- =================================================
            -- PREVIOUS FORMAT - 5 FIELDS
            -- =================================================
            --
            -- key
            -- trucker deliveries
            -- trucker earnings
            -- material deliveries
            -- materials collected
            --
            -- New materialsSpent starts at 0.
            --
            -- IMPORTANT:
            -- ALL OLD DATA IS PRESERVED.
            --

            local oldKey,
                  oldDeliveries,
                  oldEarnings,
                  oldMaterialDeliveries,
                  oldMaterialsCollected =
                line:match(
                    "^(.-)\t(%d+)\t([%d%.]+)\t(%d+)\t([%d%.]+)$"
                )

            if oldKey
               and oldDeliveries
               and oldEarnings
               and oldMaterialDeliveries
               and oldMaterialsCollected then

                counters[oldKey] = {

                    deliveries =
                        tonumber(oldDeliveries) or 0,

                    earnings =
                        tonumber(oldEarnings) or 0,

                    materialDeliveries =
                        tonumber(oldMaterialDeliveries) or 0,

                    materialsCollected =
                        tonumber(oldMaterialsCollected) or 0,

                    materialsSpent = 0,

                    bankGain = 0

                }

                debugLog(
                    "5-FIELD DATABASE ENTRY MIGRATED | " ..
                    "Key=" .. tostring(oldKey) ..
                    " | Trucker Deliveries=" ..
                    tostring(oldDeliveries) ..
                    " | Trucker Earnings=" ..
                    tostring(oldEarnings) ..
                    " | Material Deliveries=" ..
                    tostring(oldMaterialDeliveries) ..
                    " | Materials Collected=" ..
                    tostring(oldMaterialsCollected) ..
                    " | Materials Spent=0"
                )

            else

                -- =================================================
                -- OLD FORMAT - 3 FIELDS
                -- =================================================
                --
                -- key
                -- trucker deliveries
                -- trucker earnings
                --
                -- New material counters start at 0.
                --

                local oldKey3,
                      oldDeliveries3,
                      oldEarnings3 =
                    line:match(
                        "^(.-)\t(%d+)\t([%d%.]+)$"
                    )

                if oldKey3
                   and oldDeliveries3
                   and oldEarnings3 then

                    counters[oldKey3] = {

                        deliveries =
                            tonumber(oldDeliveries3) or 0,

                        earnings =
                            tonumber(oldEarnings3) or 0,

                        materialDeliveries = 0,

                        materialsCollected = 0,

                        materialsSpent = 0,

                        bankGain = 0

                    }

                    debugLog(
                        "3-FIELD DATABASE ENTRY MIGRATED | " ..
                        "Key=" .. tostring(oldKey3) ..
                        " | Trucker Deliveries=" ..
                        tostring(oldDeliveries3) ..
                        " | Trucker Earnings=" ..
                        tostring(oldEarnings3) ..
                        " | Material Counters=0"
                    )

                else

                    -- =================================================
                    -- VERY OLD FORMAT - 2 FIELDS
                    -- =================================================

                    local veryOldKey,
                          veryOldCounter =
                        line:match(
                            "^(.-)\t(%d+)$"
                        )

                    if veryOldKey
                       and veryOldCounter then

                        counters[veryOldKey] = {

                            deliveries =
                                tonumber(veryOldCounter) or 0,

                            earnings = 0,

                            materialDeliveries = 0,

                            materialsCollected = 0,

                            materialsSpent = 0,

                            bankGain = 0

                        }

                        debugLog(
                            "2-FIELD DATABASE ENTRY MIGRATED | " ..
                            "Key=" .. tostring(veryOldKey) ..
                            " | Trucker Deliveries=" ..
                            tostring(veryOldCounter)
                        )

                    else

                        debugLog(
                            "INVALID DATABASE LINE IGNORED: " ..
                            tostring(line)
                        )

                    end

                end

            end

        end

        end

    end

    file:close()

    debugLog(
        "DATABASE LOAD COMPLETE"
    )

end

-- =========================================================
-- UPDATE IDENTITY
-- =========================================================

local function updateIdentity()

    local server =
        getServerIdentifier()

    if not server then

        debugLog(
            "IDENTITY: Server unavailable."
        )

        return false

    end

    local account =
        getAccountIdentifier()

    if not account then

        debugLog(
            "IDENTITY: Local account unavailable."
        )

        return false

    end

    if server == currentServer
       and account == currentAccount then

        return true

    end

    currentServer = server
    currentAccount = account

    debugLog(
        "=============================================="
    )

    debugLog(
        "IDENTITY CONFIRMED"
    )

    debugLog(
        "SERVER = " ..
        currentServer
    )

    debugLog(
        "ACCOUNT = " ..
        currentAccount
    )

    debugLog(
        "=============================================="
    )

    local key =
        makeKey(
            currentServer,
            currentAccount
        )

    if counters[key] == nil then

        counters[key] = {

            deliveries = 0,
            earnings = 0,

            materialDeliveries = 0,
            materialsCollected = 0,

            materialsSpent = 0,

            bankGain = 0

        }

        saveCounters()

        debugLog(
            "NEW SERVER/ACCOUNT ENTRY CREATED | " ..
            "Key=" .. key
        )

    else

        -- =================================================
        -- SAFETY INITIALIZATION
        -- =================================================

        if counters[key].deliveries == nil then
            counters[key].deliveries = 0
        end

        if counters[key].earnings == nil then
            counters[key].earnings = 0
        end

        if counters[key].materialDeliveries == nil then
            counters[key].materialDeliveries = 0
        end

        if counters[key].materialsCollected == nil then
            counters[key].materialsCollected = 0
        end

        if counters[key].materialsSpent == nil then
            counters[key].materialsSpent = 0
        end

        if counters[key].bankGain == nil then
            counters[key].bankGain = 0
        end

        debugLog(
            "EXISTING SERVER/ACCOUNT ENTRY LOADED | " ..
            "Key=" .. key ..
            " | Trucker Deliveries=" ..
            tostring(counters[key].deliveries) ..
            " | Trucker Earnings=" ..
            tostring(counters[key].earnings) ..
            " | Material Deliveries=" ..
            tostring(counters[key].materialDeliveries) ..
            " | Materials Collected=" ..
            tostring(counters[key].materialsCollected) ..
            " | Materials Spent=" ..
            tostring(counters[key].materialsSpent)
        )

    end

    return true

end

-- =========================================================
-- GET CURRENT DATA
-- =========================================================

local function getCurrentData()

    local success, result =
        pcall(
            updateIdentity
        )

    if not success then

        debugLog(
            "GET DATA: updateIdentity ERROR = " ..
            tostring(result)
        )

        return nil

    end

    if not result then

        debugLog(
            "GET DATA: Identity unavailable."
        )

        return nil

    end

    local key =
        makeKey(
            currentServer,
            currentAccount
        )

    if counters[key] == nil then

        counters[key] = {

            deliveries = 0,
            earnings = 0,

            materialDeliveries = 0,
            materialsCollected = 0,

            materialsSpent = 0,

            bankGain = 0

        }

        saveCounters()

    end

    -- Safety initialization.

    if counters[key].deliveries == nil then
        counters[key].deliveries = 0
    end

    if counters[key].earnings == nil then
        counters[key].earnings = 0
    end

    if counters[key].materialDeliveries == nil then
        counters[key].materialDeliveries = 0
    end

    if counters[key].materialsCollected == nil then
        counters[key].materialsCollected = 0
    end

    if counters[key].materialsSpent == nil then
        counters[key].materialsSpent = 0
    end

    if counters[key].bankGain == nil then
        counters[key].bankGain = 0
    end

    return counters[key]

end

-- =========================================================
-- INCREMENT TRUCKER DELIVERY
-- =========================================================

local function incrementTruckerCounter(amount)

    local data =
        getCurrentData()

    if not data then

        debugLog(
            "TRUCKER DELIVERY IGNORED: Could not determine local account."
        )

        return

    end

    data.deliveries =
        tonumber(
            data.deliveries
        ) or 0

    data.earnings =
        tonumber(
            data.earnings
        ) or 0

    data.deliveries =
        data.deliveries + 1

    data.earnings =
        data.earnings + amount

    saveCounters()

    debugLog(
        "=============================================="
    )

    debugLog(
        "TRUCKER DELIVERY DETECTED"
    )

    debugLog(
        "SERVER = " ..
        tostring(currentServer)
    )

    debugLog(
        "ACCOUNT = " ..
        tostring(currentAccount)
    )

    debugLog(
        "REWARD = $" ..
        tostring(amount)
    )

    debugLog(
        "TRUCKER DELIVERIES = " ..
        tostring(data.deliveries)
    )

    debugLog(
        "TRUCKER TOTAL EARNINGS = $" ..
        tostring(data.earnings)
    )

    debugLog(
        "=============================================="
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Delivery #{FFFF00}%d {FFFFFF}| Earned: {00FF00}$%s",
            data.deliveries,
            formatMoney(amount)
        ),
        -1
    )

end

-- =========================================================
-- INCREMENT MATERIAL DELIVERY
-- =========================================================

local function incrementMaterialCounter(amount)

    local data =
        getCurrentData()

    if not data then

        debugLog(
            "MATERIAL DELIVERY IGNORED: Could not determine local account."
        )

        return

    end

    data.materialDeliveries =
        tonumber(
            data.materialDeliveries
        ) or 0

    data.materialsCollected =
        tonumber(
            data.materialsCollected
        ) or 0

    data.materialDeliveries =
        data.materialDeliveries + 1

    data.materialsCollected =
        data.materialsCollected + amount

    saveCounters()

    debugLog(
        "=============================================="
    )

    debugLog(
        "MATERIAL DELIVERY DETECTED"
    )

    debugLog(
        "SERVER = " ..
        tostring(currentServer)
    )

    debugLog(
        "ACCOUNT = " ..
        tostring(currentAccount)
    )

    debugLog(
        "MATERIALS RECEIVED (Y) = " ..
        tostring(amount)
    )

    debugLog(
        "MATERIAL DELIVERY COUNT = " ..
        tostring(data.materialDeliveries)
    )

    debugLog(
        "TOTAL MATERIALS COLLECTED = " ..
        tostring(data.materialsCollected)
    )

    debugLog(
        "=============================================="
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Materials delivery #{FFFF00}%d {FFFFFF}| Collected: {00FF00}%s materials",
            data.materialDeliveries,
            formatMoney(amount)
        ),
        -1
    )

end

-- =========================================================
-- INCREMENT MATERIAL SPENDING
-- =========================================================
--
-- Message:
--
-- * You bought 10 Material Packages for $X.
--
-- We ignore:
--
-- 10
--
-- We only save:
--
-- X
--
-- Every matching message adds X to the total.
--
-- =========================================================

local function incrementMaterialSpending(amount, packages)

    local data =
        getCurrentData()

    if not data then

        debugLog(
            "MATERIAL PURCHASE IGNORED: Could not determine local account."
        )

        return

    end

    data.materialsSpent =
        tonumber(
            data.materialsSpent
        ) or 0

    -- Add purchase amount.
    data.materialsSpent =
        data.materialsSpent + amount

    saveCounters()

    debugLog(
        "=============================================="
    )

    debugLog(
        "MATERIAL PACKAGE PURCHASE DETECTED"
    )

    debugLog(
        "SERVER = " ..
        tostring(currentServer)
    )

    debugLog(
        "ACCOUNT = " ..
        tostring(currentAccount)
    )

    debugLog(
        "PACKAGES BOUGHT = " ..
        tostring(packages)
    )

    debugLog(
        "PURCHASE AMOUNT = $" ..
        tostring(amount)
    )

    debugLog(
        "TOTAL MATERIALS SPENT = $" ..
        tostring(data.materialsSpent)
    )

    debugLog(
        "=============================================="
    )

    -- In-game notification.
    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Bought {FFFF00}%s {FFFFFF}material packages | Spent: {FF4444}$%s {FFFFFF}| Total spent: {FF4444}$%s",
            formatMoney(packages),
            formatMoney(amount),
            formatMoney(data.materialsSpent)
        ),
        -1
    )

end

-- =========================================================
-- TRUCKER MESSAGE DETECTION
-- =========================================================

local function isDeliveryRewardMessage(text)

    if not text then
        return false, nil
    end

    local amountString =
        text:match(
            "^%*%s*You were paid %$([%d,]+)%s+for delivering the goods and returning the truck%.%s*$"
        )

    if not amountString then

        return false, nil

    end

    local cleanAmount =
        amountString:gsub(
            ",",
            ""
        )

    local numericAmount =
        tonumber(
            cleanAmount
        )

    if not numericAmount then

        debugLog(
            "TRUCKER REWARD ERROR: Cannot convert $" ..
            tostring(amountString)
        )

        return false, nil

    end

    if numericAmount <= 0 then

        return false, nil

    end

    return true, numericAmount

end

-- =========================================================
-- MATERIAL DELIVERY MESSAGE DETECTION
-- =========================================================

local function isMaterialDeliveryMessage(text)

    if not text then
        return false, nil
    end

    -- Y is captured.
    -- Z is intentionally ignored.
    --
    -- Example:
    --
    -- The factory gave you 100 materials for your delivery,
    -- on top of the 50 materials you already have.
    --

    local amountString =
        text:match(
            "^The factory gave you ([%d,]+) materials for your delivery, on top of the [%d,]+ materials you already have%.%s*$"
        )

    if not amountString then

        return false, nil

    end

    local cleanAmount =
        amountString:gsub(
            ",",
            ""
        )

    local numericAmount =
        tonumber(
            cleanAmount
        )

    if not numericAmount then

        debugLog(
            "MATERIAL ERROR: Cannot convert Y=" ..
            tostring(amountString)
        )

        return false, nil

    end

    if numericAmount <= 0 then

        return false, nil

    end

    return true, numericAmount

end

-- =========================================================
-- MATERIAL PACKAGE PURCHASE MESSAGE DETECTION
-- =========================================================
--
-- Example:
--
-- * You bought 10 Material Packages for $500.
--
-- Captures:
--
-- packages = 10
-- amount   = 500
--
-- Only amount is accumulated.
--
-- Supports comma amounts:
--
-- $1,000
-- $25,000
-- $1,250,000
--
-- =========================================================

local function isMaterialPurchaseMessage(text)

    if not text then
        return false, nil, nil
    end

    local packagesString,
          amountString =
        text:match(
            "^%*%s*You bought ([%d,]+) Material Packages for %$([%d,]+)%.%s*$"
        )

    if not packagesString or not amountString then

        return false, nil, nil

    end

    local cleanPackages =
        packagesString:gsub(
            ",",
            ""
        )

    local cleanAmount =
        amountString:gsub(
            ",",
            ""
        )

    local packages =
        tonumber(
            cleanPackages
        )

    local amount =
        tonumber(
            cleanAmount
        )

    if not packages then

        debugLog(
            "MATERIAL PURCHASE ERROR: Invalid package count = " ..
            tostring(packagesString)
        )

        return false, nil, nil

    end

    if not amount then

        debugLog(
            "MATERIAL PURCHASE ERROR: Invalid amount = $" ..
            tostring(amountString)
        )

        return false, nil, nil

    end

    if packages <= 0 then

        return false, nil, nil

    end

    if amount <= 0 then

        return false, nil, nil

    end

    return true, amount, packages

end

-- =========================================================
-- BANK STATEMENT OLD BALANCE LINE DETECTION
-- =========================================================
--
-- Example (after cleanMessage):
--   Old balance: $914,734  |  Interest rate: 0.5 percent (3k max)
--
-- =========================================================

local function isBankOldBalanceLine(text)

    if not text then
        return false, nil
    end

    local amountString =
        text:match(
            "^%s*Old balance:%s*%$([%d,]+)%s*|"
        )

    if not amountString then
        return false, nil
    end

    local amount =
        tonumber(
            (amountString:gsub(",", ""))
        )

    if not amount or amount < 0 then
        return false, nil
    end

    return true, amount

end

-- =========================================================
-- BANK STATEMENT NEW BALANCE LINE DETECTION
-- =========================================================
--
-- Example (after cleanMessage):
--   New balance: $919,370 |  Rent paid: $0
--
-- =========================================================

local function isBankNewBalanceLine(text)

    if not text then
        return false, nil
    end

    local amountString =
        text:match(
            "^%s*New balance:%s*%$([%d,]+)%s*|"
        )

    if not amountString then
        return false, nil
    end

    local amount =
        tonumber(
            (amountString:gsub(",", ""))
        )

    if not amount or amount < 0 then
        return false, nil
    end

    return true, amount

end

-- =========================================================
-- INCREMENT BANK GAIN
-- =========================================================

local function incrementBankGain(diff)

    local data =
        getCurrentData()

    if not data then

        debugLog(
            "BANK GAIN IGNORED: Could not determine local account."
        )

        return

    end

    data.bankGain =
        (tonumber(data.bankGain) or 0) + diff

    saveCounters()

    debugLog(
        "=============================================="
    )

    debugLog(
        "BANK STATEMENT GAIN RECORDED"
    )

    debugLog(
        "SERVER = " ..
        tostring(currentServer)
    )

    debugLog(
        "ACCOUNT = " ..
        tostring(currentAccount)
    )

    debugLog(
        "THIS GAIN = $" ..
        tostring(diff)
    )

    debugLog(
        "TOTAL BANK GAIN = $" ..
        tostring(data.bankGain)
    )

    debugLog(
        "=============================================="
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Bank gain: {00FF00}+$%s {FFFFFF}| Total bank gain: {00FF00}$%s",
            formatMoney(diff),
            formatMoney(data.bankGain)
        ),
        -1
    )

end

-- =========================================================
-- SERVER MESSAGE HANDLER
-- =========================================================

function sampev.onServerMessage(color, text)

    if not text then
        return
    end

    -- =====================================================
    -- LOG ORIGINAL MESSAGE
    -- =====================================================

    debugLog(
        "SERVER MESSAGE: " ..
        tostring(text)
    )

    -- =====================================================
    -- CLEAN MESSAGE
    -- =====================================================

    local cleanText =
        cleanMessage(text)

    debugLog(
        "CLEAN MESSAGE: " ..
        tostring(cleanText)
    )

    -- =====================================================
    -- CHECK TRUCKER
    -- =====================================================

    local isTruckerReward, truckerAmount =
        isDeliveryRewardMessage(
            cleanText
        )

    if isTruckerReward then

        debugLog(
            "***** TRUCKER REWARD MATCHED *****"
        )

        incrementTruckerCounter(
            truckerAmount
        )

        return

    end

    -- =====================================================
    -- CHECK MATERIAL DELIVERY
    -- =====================================================

    local isMaterialReward, materialAmount =
        isMaterialDeliveryMessage(
            cleanText
        )

    if isMaterialReward then

        debugLog(
            "***** MATERIAL DELIVERY MATCHED *****"
        )

        incrementMaterialCounter(
            materialAmount
        )

        return

    end

    -- =====================================================
    -- CHECK MATERIAL PURCHASE
    -- =====================================================

    local isMaterialPurchase,
          purchaseAmount,
          packages =
        isMaterialPurchaseMessage(
            cleanText
        )

    if isMaterialPurchase then

        debugLog(
            "***** MATERIAL PACKAGE PURCHASE MATCHED *****"
        )

        incrementMaterialSpending(
            purchaseAmount,
            packages
        )

        return

    end

    -- =====================================================
    -- CHECK BANK OLD BALANCE
    -- =====================================================

    local isOldBalance, oldBalance =
        isBankOldBalanceLine(
            cleanText
        )

    if isOldBalance then

        pendingOldBalance = oldBalance

        debugLog(
            "BANK OLD BALANCE CAPTURED: $" ..
            tostring(oldBalance)
        )

        return

    end

    -- =====================================================
    -- CHECK BANK NEW BALANCE
    -- =====================================================

    local isNewBalance, newBalance =
        isBankNewBalanceLine(
            cleanText
        )

    if isNewBalance then

        if pendingOldBalance then

            local diff =
                newBalance - pendingOldBalance

            debugLog(
                "***** BANK STATEMENT GAIN MATCHED *****"
            )

            debugLog(
                "OLD BALANCE = $" ..
                tostring(pendingOldBalance) ..
                " | NEW BALANCE = $" ..
                tostring(newBalance) ..
                " | DIFF = $" ..
                tostring(diff)
            )

            pendingOldBalance = nil

            incrementBankGain(diff)

        else

            debugLog(
                "BANK NEW BALANCE SKIPPED: no pending old balance."
            )

        end

        return

    end

end

-- =========================================================
-- /JOBCOUNTERS
-- =========================================================

function sampev.onSendCommand(command)

    if not command then
        return
    end

    local cleanCommand =
        trim(command):lower()

    if cleanCommand ~= "/jobcounters" then

        return

    end

    debugLog(
        "COMMAND /jobcounters USED"
    )

    local data =
        getCurrentData()

    if not data then

        sampAddChatMessage(
            "{FF0000}[DeliveryCounter] {FFFFFF}Could not identify your account. Check DeliveryCounter_debug.log.",
            -1
        )

        return false

    end

    local deliveries =
        tonumber(
            data.deliveries
        ) or 0

    local earnings =
        tonumber(
            data.earnings
        ) or 0

    local materialDeliveries =
        tonumber(
            data.materialDeliveries
        ) or 0

    local materialsCollected =
        tonumber(
            data.materialsCollected
        ) or 0

    local materialsSpent =
        tonumber(
            data.materialsSpent
        ) or 0

    local bankGain =
        tonumber(
            data.bankGain
        ) or 0

    -- =====================================================
    -- TRUCKER
    -- =====================================================

    sampAddChatMessage(
        string.format(
            "You have delivered %d times using trucker job. You had earned %s amount.",
            deliveries,
            formatMoney(earnings)
        ),
        -1
    )

    -- =====================================================
    -- MATERIALS
    -- =====================================================

    sampAddChatMessage(
        string.format(
            "You delivered materials %d times. You collected %s materials and spent a total of %s.",
            materialDeliveries,
            formatMoney(materialsCollected),
            formatMoney(materialsSpent)
        ),
        -1
    )

    -- =====================================================
    -- BANK GAIN
    -- =====================================================

    sampAddChatMessage(
        string.format(
            "Total bank gain from paychecks: $%s.",
            formatMoney(bankGain)
        ),
        -1
    )

    debugLog(
        "JOBCOUNTERS RESULT | " ..
        "Server=" ..
        tostring(currentServer) ..
        " | Account=" ..
        tostring(currentAccount) ..
        " | Trucker Deliveries=" ..
        tostring(deliveries) ..
        " | Trucker Earnings=$" ..
        tostring(earnings) ..
        " | Material Deliveries=" ..
        tostring(materialDeliveries) ..
        " | Materials Collected=" ..
        tostring(materialsCollected) ..
        " | Materials Spent=$" ..
        tostring(materialsSpent) ..
        " | Bank Gain=$" ..
        tostring(bankGain)
    )

    -- Don't send command to server.
    return false

end

-- =========================================================
-- MAIN
-- =========================================================

function main()

    -- =====================================================
    -- WAIT FOR SA-MP
    -- =====================================================

    repeat

        wait(100)

    until isSampAvailable()

    debugLog(
        "=============================================="
    )

    debugLog(
        "DeliveryCounter STARTING"
    )

    debugLog(
        "=============================================="
    )

    -- =====================================================
    -- LOAD DATABASE
    -- =====================================================

    loadCounters()

    -- =====================================================
    -- WAIT FOR LOCAL PLAYER
    -- =====================================================

    local identityReady = false

    while not identityReady do

        wait(1000)

        local success, result =
            pcall(
                updateIdentity
            )

        if success then

            identityReady =
                result == true

        else

            identityReady = false

            debugLog(
                "STARTUP IDENTITY ERROR: " ..
                tostring(result)
            )

        end

        if not identityReady then

            debugLog(
                "STARTUP: Waiting for local account..."
            )

        end

    end

    -- =====================================================
    -- GET DATA
    -- =====================================================

    local data =
        getCurrentData()

    if not data then

        debugLog(
            "ERROR: Failed to get current account data."
        )

        return

    end

    local deliveries =
        tonumber(
            data.deliveries
        ) or 0

    local earnings =
        tonumber(
            data.earnings
        ) or 0

    local materialDeliveries =
        tonumber(
            data.materialDeliveries
        ) or 0

    local materialsCollected =
        tonumber(
            data.materialsCollected
        ) or 0

    local materialsSpent =
        tonumber(
            data.materialsSpent
        ) or 0

    local bankGainStartup =
        tonumber(
            data.bankGain
        ) or 0

    -- =====================================================
    -- STARTUP MESSAGE
    -- =====================================================

    sampAddChatMessage(
        "{00FF00}[DeliveryCounter] {FFFFFF}Script loaded.",
        -1
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Account: {FFFF00}%s {FFFFFF}| Trucker: {FFFF00}%d {FFFFFF}| Earned: {00FF00}$%s",
            currentAccount,
            deliveries,
            formatMoney(earnings)
        ),
        -1
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Materials: {FFFF00}%d {FFFFFF}| Collected: {00FF00}%s {FFFFFF}| Spent: {FF4444}$%s",
            materialDeliveries,
            formatMoney(materialsCollected),
            formatMoney(materialsSpent)
        ),
        -1
    )

    sampAddChatMessage(
        string.format(
            "{00FF00}[DeliveryCounter] {FFFFFF}Bank gain: {00FF00}$%s",
            formatMoney(bankGainStartup)
        ),
        -1
    )

    -- =====================================================
    -- STARTUP DEBUG
    -- =====================================================

    debugLog(
        "STARTUP SUCCESS"
    )

    debugLog(
        "SERVER = " ..
        tostring(currentServer)
    )

    debugLog(
        "ACCOUNT = " ..
        tostring(currentAccount)
    )

    debugLog(
        "TRUCKER DELIVERIES = " ..
        tostring(deliveries)
    )

    debugLog(
        "TRUCKER EARNINGS = $" ..
        tostring(earnings)
    )

    debugLog(
        "MATERIAL DELIVERIES = " ..
        tostring(materialDeliveries)
    )

    debugLog(
        "MATERIALS COLLECTED = " ..
        tostring(materialsCollected)
    )

    debugLog(
        "MATERIALS SPENT = $" ..
        tostring(materialsSpent)
    )

    debugLog(
        "BANK GAIN = $" ..
        tostring(bankGainStartup)
    )

    debugLog(
        "DATABASE = " ..
        COUNTER_FILE
    )

    debugLog(
        "=============================================="
    )

    -- =====================================================
    -- MAIN LOOP
    -- =====================================================

    while true do

        wait(1000)

        local success, result =
            pcall(
                updateIdentity
            )

        if not success then

            debugLog(
                "UPDATE IDENTITY ERROR: " ..
                tostring(result)
            )

        end

    end

end
