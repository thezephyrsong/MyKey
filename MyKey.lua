-- Mythic Keystones Mesh Network - Core Engine
local AddonName, addon = ...
local core = {}
addon.core = core

-- Database Initialization & Defaults
MKR_DB = MKR_DB or {}
MKR_DB_CONFIG = MKR_DB_CONFIG or {
    optGuild = true,
    optParty = true,
    optRaid = true,
    optOfficer = true,
}

local lastBroadcast = 0
local syncThrottle = {}

function core:Init()
    -- Clear expired database cache (older than 7 days)
    local currentTime = time()
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.time and (currentTime - data.time) > 604800 then
            MKR_DB[player] = nil
        end
    end
    
    core:CreateUIFrame()
    core:BroadcastOwnKey()
    
    -- UPDATED: Command hint on login
    print("|cffcb9cff[MKR]|r Standalone Addon Loaded. Type |cff00ffff/mykey|r to see options.")
end

function core:FindKeys()
    local keys = {}
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID and itemID >= 900000 and itemID <= 1000000 then
                    local itemName = GetItemInfo(itemID)
                    if itemName and (string.find(itemName, "Keystone") or string.find(itemName, "Key")) then
                        table.insert(keys, GetContainerItemLink(bag, slot))
                    end
                end
            end
        end
    end
    return keys
end

function core:GossipRecord(targetPlayer, keyStr, timestamp)
    if not IsInGuild() then return end
    local payload = string.format("%s~%s~%d", targetPlayer, keyStr, timestamp)
    SendAddonMessage("MKR_MESH", payload, "GUILD")
end

function core:BroadcastOwnKey()
    local myName = UnitName("player")
    local myKeys = core:FindKeys()
    local keyStr = (#myKeys > 0) and table.concat(myKeys, ",") or "NONE"
    local now = time()
    
    MKR_DB[myName] = { key = keyStr, time = now }
    core:GossipRecord(myName, keyStr, now)
    core:UpdateUI()
end

function core:GossipEntireDatabase()
    if not IsInGuild() then return end
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.time then
            local delay = math.random(1, 15) * 0.1
            local p, k, t = player, data.key, data.time
            core:DelayExecution(delay, function()
                core:GossipRecord(p, k, t)
            end)
        end
    end
end

function core:DelayExecution(delay, func)
    local f = CreateFrame("Frame")
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, elap)
        elapsed = elapsed + elap
        if elapsed >= delay then
            func()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function core:ReportKeysChat(event)
    local targetChannel = string.match(event, "CHAT_MSG_([^_-]+)")
    if targetChannel == "PARTY" or targetChannel == "RAID" or targetChannel == "GUILD" or targetChannel == "OFFICER" then
        
        local configKey = "opt" .. targetChannel:sub(1,1):upper() .. targetChannel:sub(2):lower()
        if MKR_DB_CONFIG[configKey] == false then return end
        
        local myKeys = core:FindKeys()
        local output = (#myKeys > 0) and table.concat(myKeys, " & ") or nil
        
        if output then
            SendChatMessage(output, targetChannel)
        end
    end
end

function core:CreateUIFrame()
    if core.displayFrame then return end
    
    local f = CreateFrame("Frame", "MKR_GuildKeysSidebar", UIParent)
    f:SetWidth(200)
    
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.05, 0.05, 0.05, 0.92)
    f.bg = bg
    
    local border = f:CreateTexture(nil, "BORDER")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    border:SetTexture(0.3, 0.3, 0.3, 1)
    f.border = border
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Guild Keystones")
    
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    
    f.text = text
    core.displayFrame = f
    f:Hide()
    
    local monitor = CreateFrame("Frame", nil, UIParent)
    local ticker = 0
    local lastState = false
    
    monitor:SetScript("OnUpdate", function(self, elapsed)
        ticker = ticker + elapsed
        if ticker > 0.2 then
            ticker = 0
            if MythicPlusFrame then
                if MythicPlusFrame:IsShown() then
                    f:SetFrameStrata(MythicPlusFrame:GetFrameStrata() or "MEDIUM")
                    f:SetFrameLevel((MythicPlusFrame:GetFrameLevel() or 71) + 5)
                    
                    f:ClearAllPoints()
                    f:SetPoint("TOPRIGHT", MythicPlusFrame, "TOPLEFT", -5, -32)
                    f:SetPoint("BOTTOMRIGHT", MythicPlusFrame, "BOTTOMLEFT", -5, 32)
                    
                    if not f:IsShown() then
                        f:Show()
                        SendAddonMessage("MKR_REQ", "REQ", "GUILD")
                    end
                    lastState = true
                else
                    if lastState then f:Hide() lastState = false end
                end
            else
                if lastState then f:Hide() lastState = false end
            end
        end
    end)
end

function core:UpdateUI()
    if not core.displayFrame or not core.displayFrame.text then return end
    local lines = {}
    
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.key ~= "NONE" then
            local cleanKeys = string.gsub(data.key, ",", "\n   ")
            table.insert(lines, "|cffcb9cff" .. player .. "|r:\n   " .. cleanKeys)
        end
    end
    
    if #lines == 0 then
        core.displayFrame.text:SetText("\n|cff888888No keys stored.|r")
    else
        core.displayFrame.text:SetText(table.concat(lines, "\n\n"))
    end
end

-- Native Event Processing Loop
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_GUILD")
eventFrame:RegisterEvent("CHAT_MSG_OFFICER")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        core:Init()
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = arg1, arg2, arg3, arg4
        if sender then sender = string.match(sender, "([^-]+)") end
        
        if prefix == "MKR_REQ" then
            core:GossipEntireDatabase()
        elseif prefix == "MKR_RESP" then
            if sender and text then
                MKR_DB[sender] = { key = text, time = time() }
                core:UpdateUI()
            end
        elseif prefix == "MKR_MESH" and text then
            local pName, keyStr, tStamp = string.match(text, "([^~]+)~([^~]+)~([^~]+)")
            tStamp = tonumber(tStamp)
            
            if pName and keyStr and tStamp then
                local current = MKR_DB[pName]
                if not current or tStamp > current.time then
                    MKR_DB[pName] = { key = keyStr, time = tStamp }
                    core:UpdateUI()
                elseif current and current.time > tStamp then
                    local now = GetTime()
                    if not syncThrottle[pName] or (now - syncThrottle[pName]) > 5 then
                        syncThrottle[pName] = now
                        core:GossipRecord(pName, current.key, current.time)
                    end
                end
            end
        end
        
    elseif event == "BAG_UPDATE" or event == "PLAYER_LOGIN" then
        local now = GetTime()
        if (now - lastBroadcast) > 3 then
            lastBroadcast = now
            core:BroadcastOwnKey()
        end
        
    elseif string.find(event, "CHAT_MSG_") then
        local msg = arg1
        if msg and type(msg) == "string" and string.lower(msg) == "?keys" then
            core:ReportKeysChat(event)
        end
    end
end)

-- Native Option Control Command Processing Matrix
SlashCmdList["MYTHICKEYSTONES"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "guild" then
        MKR_DB_CONFIG.optGuild = not MKR_DB_CONFIG.optGuild
        print("|cffcb9cff[MKR]|r Guild Chat auto-response is now: " .. (MKR_DB_CONFIG.optGuild and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "party" then
        MKR_DB_CONFIG.optParty = not MKR_DB_CONFIG.optParty
        print("|cffcb9cff[MKR]|r Party Chat auto-response is now: " .. (MKR_DB_CONFIG.optParty and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "raid" then
        MKR_DB_CONFIG.optRaid = not MKR_DB_CONFIG.optRaid
        print("|cffcb9cff[MKR]|r Raid Chat auto-response is now: " .. (MKR_DB_CONFIG.optRaid and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "officer" then
        MKR_DB_CONFIG.optOfficer = not MKR_DB_CONFIG.optOfficer
        print("|cffcb9cff[MKR]|r Officer Chat auto-response is now: " .. (MKR_DB_CONFIG.optOfficer and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    else
        local keys = core:FindKeys()
        print("|cffcb9cff--- Mythic Keystones Local Control Panel ---|r")
        print("Your Active Keys: " .. (#keys > 0 and table.concat(keys, " & ") or "|cff888888None Found|r"))
        -- UPDATED: Updated text hint command context
        print("|cff00ffffToggles (Type /mykey [option]):|r")
        print("  |cffcb9cffguild|r - Guild Channel: " .. (MKR_DB_CONFIG.optGuild and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffparty|r - Party Channel: " .. (MKR_DB_CONFIG.optParty and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffraid|r - Raid Channel: " .. (MKR_DB_CONFIG.optRaid and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffofficer|r - Officer Channel: " .. (MKR_DB_CONFIG.optOfficer and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    end
end

-- NEW COMMAND ASSIGNMENTS:
SLASH_MYTHICKEYSTONES1 = "/mykeyres"
SLASH_MYTHICKEYSTONES2 = "/mykey"
