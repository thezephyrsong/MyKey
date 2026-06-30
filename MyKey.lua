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

-- Calculates the exact Unix epoch timestamp of the most recent Wednesday at 4:00 AM
function core:GetLastResetTime()
    local now = time()
    local current = date("*t", now)
    
    -- Lua weekday format: Sunday = 1, Monday = 2, Tuesday = 3, Wednesday = 4...
    local diff = current.wday - 4
    if diff < 0 then
        diff = diff + 7
    elseif diff == 0 and current.hour < 4 then
        diff = 7
    end
    
    -- Subtract day delta to target the correct calendar date, then hardcode 4:00:00 AM
    local targetDayTime = now - (diff * 86400)
    local resetDate = date("*t", targetDayTime)
    resetDate.hour = 4
    resetDate.min = 0
    resetDate.sec = 0
    
    return time(resetDate)
end

-- Wipes database records that originated prior to the calculated weekly reset cutoff
function core:PruneExpiredKeys()
    local cutoff = core:GetLastResetTime()
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.time and data.time < cutoff then
            MKR_DB[player] = nil
        end
    end
end

function core:Init()
    core:PruneExpiredKeys()
    core:CreateUIFrame()
    core:BroadcastOwnKey()
    
    print("|cffcb9cff[MKR]|r Addon Loaded. Auto-pruning keys set to Wednesdays at 4:00 AM.")
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
    local cutoff = core:GetLastResetTime()
    if timestamp < cutoff then return end -- Shield outbound channel from sending obsolete data
    
    local payload = string.format("%s~%s~%d", targetPlayer, keyStr, timestamp)
    
    if IsInGuild() then
        SendAddonMessage("MKR_MESH", payload, "GUILD")
    end
    
    for i = 1, GetFriendInfo and GetNumFriends() or 0 do
        local name, _, _, _, connected = GetFriendInfo(i)
        if connected and name then
            SendAddonMessage("MKR_MESH", payload, "WHISPER", name)
        end
    end
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

function core:GossipEntireDatabase(targetWhisperPlayer)
    local cutoff = core:GetLastResetTime()
    
    if targetWhisperPlayer then
        for player, data in pairs(MKR_DB) do
            if type(data) == "table" and data.key and data.time and data.time >= cutoff then
                local payload = string.format("%s~%s~%d", player, data.key, data.time)
                SendAddonMessage("MKR_MESH", payload, "WHISPER", targetWhisperPlayer)
            end
        end
        return
    end

    if not IsInGuild() then return end
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.time and data.time >= cutoff then
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
    f:SetWidth(210)
    
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.05, 0.03, 0.09, 0.95)
    f.bg = bg
    
    local pR, pG, pB, pA = 0.52, 0.33, 0.81, 0.85
    
    local borderRight = f:CreateTexture(nil, "BORDER")
    borderRight:SetWidth(1.5)
    borderRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    borderRight:SetTexture(pR, pG, pB, pA)
    
    local borderLeft = f:CreateTexture(nil, "BORDER")
    borderLeft:SetWidth(1.5)
    borderLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    borderLeft:SetTexture(pR, pG, pB, pA)
    
    local borderTop = f:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1.5)
    borderTop:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    borderTop:SetTexture(pR, pG, pB, pA)
    
    local borderBottom = f:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1.5)
    borderBottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture(pR, pG, pB, pA)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Keystones")
    
    local titleLine = f:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
    titleLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -28)
    titleLine:SetTexture(pR, pG, pB, 0.4)
    
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
                if not MythicPlusFrame.mkrCloseButton then
                    local closeBtn = CreateFrame("Button", nil, MythicPlusFrame, "UIPanelCloseButton")
                    closeBtn:SetPoint("TOPRIGHT", MythicPlusFrame, "TOPRIGHT", -4, -4)
                    closeBtn:SetFrameLevel((MythicPlusFrame:GetFrameLevel() or 71) + 10)
                    closeBtn:SetScript("OnClick", function()
                        MythicPlusFrame:Hide()
                    end)
                    MythicPlusFrame.mkrCloseButton = closeBtn
                end

                if MythicPlusFrame:IsShown() then
                    f:SetFrameStrata(MythicPlusFrame:GetFrameStrata() or "MEDIUM")
                    f:SetFrameLevel((MythicPlusFrame:GetFrameLevel() or 71) + 5)
                    
                    f:ClearAllPoints()
                    f:SetPoint("TOPRIGHT", MythicPlusFrame, "TOPLEFT", -4, -32)
                    f:SetPoint("BOTTOMRIGHT", MythicPlusFrame, "BOTTOMLEFT", -4, 32)
                    
                    if not f:IsShown() then
                        f:Show()
                        SendAddonMessage("MKR_REQ", "REQ", "GUILD")
                        
                        for i = 1, GetFriendInfo and GetNumFriends() or 0 do
                            local name, _, _, _, connected = GetFriendInfo(i)
                            if connected and name then
                                SendAddonMessage("MKR_REQ", "REQ", "WHISPER", name)
                            end
                        end
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
    if not core.displayFrame then return end
    local f = core.displayFrame
    
    -- Run a real-time safety prune before redraw cycles
    core:PruneExpiredKeys()
    
    f.rows = f.rows or {}
    for _, row in ipairs(f.rows) do
        row:Hide()
        row.link = nil
    end
    
    local rowId = 1
    
    local function AddLine(labelText, itemLink, isHeader, isPlayer)
        if not f.rows[rowId] then
            local row = CreateFrame("Button", nil, f)
            row:SetHeight(15)
            
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetAllPoints()
            text:SetJustifyH("LEFT")
            row.text = text
            
            row:SetScript("OnEnter", function(self)
                if self.link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.link)
                    GameTooltip:Show()
                end
            end)
            
            row:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(self, button)
                if self.link then
                    if IsModifiedClick() then
                        HandleModifiedItemClick(self.link)
                    else
                        SetItemRef(self.link, self.link, button)
                    end
                end
            end)
            
            f.rows[rowId] = row
        end
        
        local row = f.rows[rowId]
        row.link = itemLink
        row.text:SetText(labelText)
        
        if isHeader then
            row.text:SetFontObject("GameFontNormal")
        elseif isPlayer then
            row.text:SetFontObject("GameFontNormalSmall")
        else
            row.text:SetFontObject("GameFontHighlightSmall")
        end
        
        row:ClearAllPoints()
        if rowId == 1 then
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
            row:SetPoint("RIGHT", f, "RIGHT", -14, 0)
        else
            local spacing = isHeader and -14 or (isPlayer and -8 or -2)
            row:SetPoint("TOPLEFT", f.rows[rowId-1], "BOTTOMLEFT", 0, spacing)
            row:SetPoint("RIGHT", f, "RIGHT", -14, 0)
        end
        
        row:Show()
        rowId = rowId + 1
    end
    
    local guildLines = {}
    local friendLines = {}
    local myName = UnitName("player")
    
    local friendsMap = {}
    for i = 1, GetFriendInfo and GetNumFriends() or 0 do
        local name = GetFriendInfo(i)
        if name then friendsMap[name] = true end
    end
    
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.key ~= "NONE" and player ~= myName then
            if friendsMap[player] then
                table.insert(friendLines, player)
            else
                table.insert(guildLines, player)
            end
        end
    end
    
    if #guildLines > 0 then
        AddLine("[Guild]", nil, true, false)
        for _, player in ipairs(guildLines) do
            AddLine(player .. ":", nil, false, true)
            local data = MKR_DB[player]
            for link in string.gmatch(data.key, "[^,]+") do
                local displayLink = string.gsub(link, "Mythic Keystone:%s*", "")
                AddLine("   " .. displayLink, link, false, false)
            end
        end
    end
    
    if #friendLines > 0 then
        AddLine("[Friends]", nil, true, false)
        for _, player in ipairs(friendLines) do
            AddLine(player .. ":", nil, false, true)
            local data = MKR_DB[player]
            for link in string.gmatch(data.key, "[^,]+") do
                local displayLink = string.gsub(link, "Mythic Keystone:%s*", "")
                AddLine("   " .. displayLink, link, false, false)
            end
        end
    end
    
    if rowId == 1 then
        if not f.emptyText then
            f.emptyText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            f.emptyText:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
            f.emptyText:SetText("No keys stored.")
        end
        f.emptyText:Show()
    else
        if f.emptyText then f.emptyText:Hide() end
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
            if channel == "WHISPER" and sender then
                core:GossipEntireDatabase(sender)
            else
                core:GossipEntireDatabase()
            end
            
        elseif prefix == "MKR_RESP" then
            if sender and text then
                local lastReset = core:GetLastResetTime()
                -- Fallback filter for structural edge cases
                MKR_DB[sender] = { key = text, time = time() }
                core:UpdateUI()
            end
            
        elseif prefix == "MKR_MESH" and text then
            local pName, keyStr, tStamp = string.match(text, "([^~]+)~([^~]+)~([^~]+)")
            tStamp = tonumber(tStamp)
            
            if pName and keyStr and tStamp then
                local lastReset = core:GetLastResetTime()
                
                -- NETWORK FILTER: Permanently drops historical packets originating from previous weeks
                if tStamp >= lastReset then
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

-- Option Panel Commands
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
        print("|cff00ffffToggles (Type /mykey [option]):|r")
        print("  |cffcb9cffguild|r - Guild Channel: " .. (MKR_DB_CONFIG.optGuild and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffparty|r - Party Channel: " .. (MKR_DB_CONFIG.optParty and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffraid|r - Raid Channel: " .. (MKR_DB_CONFIG.optRaid and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        print("  |cffcb9cffofficer|r - Officer Channel: " .. (MKR_DB_CONFIG.optOfficer and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    end
end
SLASH_MYTHICKEYSTONES1 = "/mykeyres"
SLASH_MYTHICKEYSTONES2 = "/mykey"

-- MythicPlusFrame Toggle Window Script Commands (/m+ and /mythic)
SlashCmdList["MYTHICPLUSTOGGLE"] = function(msg)
    if MythicPlusFrame then
        if MythicPlusFrame:IsShown() then
            MythicPlusFrame:Hide()
        else
            MythicPlusFrame:Show()
        end
    else
        print("|cffcb9cff[MKR]|r Error: MythicPlusFrame not detected in this session.")
    end
end
SLASH_MYTHICPLUSTOGGLE1 = "/m+"
SLASH_MYTHICPLUSTOGGLE2 = "/mythic"
