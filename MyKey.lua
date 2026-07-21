-- MyKey Mesh Network - Core Engine V2
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
    mySequence = 1,     -- Tracks your personal data update version history
    lastMyKeyStr = "",   -- Detects structural changes to prevent unnecessary increments
}

local lastBroadcast = 0
local syncThrottle = {}

-- Calculates the exact Unix epoch timestamp of the most recent Wednesday at 4:00 AM
function core:GetLastResetTime()
    local now = time()
    local current = date("*t", now)
    
    local diff = current.wday - 4
    if diff < 0 then
        diff = diff + 7
    elseif diff == 0 and current.hour < 4 then
        diff = 7
    end
    
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
    
    print("|cffcb9cff[MKR]|r V2 Active. Guildmates are now prioritized in the Guild category.")
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

function core:GossipRecord(targetPlayer, keyStr, timestamp, sequence)
    local cutoff = core:GetLastResetTime()
    if timestamp < cutoff then return end
    
    local payload = string.format("%s~%s~%d~%d", targetPlayer, keyStr, timestamp, sequence)
    
    if IsInGuild() then
        SendAddonMessage("MKR_MESH2", payload, "GUILD")
    end
    
    for i = 1, GetFriendInfo and GetNumFriends() or 0 do
        local name, _, _, _, connected = GetFriendInfo(i)
        if connected and name then
            SendAddonMessage("MKR_MESH2", payload, "WHISPER", name)
        end
    end
end

function core:BroadcastOwnKey()
    local myName = UnitName("player")
    local myKeys = core:FindKeys()
    local keyStr = (#myKeys > 0) and table.concat(myKeys, ",") or "NONE"
    local now = time()
    
    if keyStr ~= MKR_DB_CONFIG.lastMyKeyStr then
        MKR_DB_CONFIG.mySequence = (MKR_DB_CONFIG.mySequence or 0) + 1
        MKR_DB_CONFIG.lastMyKeyStr = keyStr
    end
    
    MKR_DB[myName] = { key = keyStr, time = now, seq = MKR_DB_CONFIG.mySequence }
    core:GossipRecord(myName, keyStr, now, MKR_DB_CONFIG.mySequence)
    core:UpdateUI()
end

function core:GossipEntireDatabase(targetWhisperPlayer)
    local cutoff = core:GetLastResetTime()
    
    if targetWhisperPlayer then
        for player, data in pairs(MKR_DB) do
            if type(data) == "table" and data.key and data.time and data.time >= cutoff then
                local seq = data.seq or 1
                local payload = string.format("%s~%s~%d~%d", player, data.key, data.time, seq)
                SendAddonMessage("MKR_MESH2", payload, "WHISPER", targetWhisperPlayer)
            end
        end
        return
    end

    if not IsInGuild() then return end
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.time and data.time >= cutoff then
            local delay = math.random(1, 15) * 0.1
            local p, k, t, s = player, data.key, data.time, (data.seq or 1)
            core:DelayExecution(delay, function()
                core:GossipRecord(p, k, t, s)
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
    
    local borders = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
    for _, p in ipairs(borders) do
        local b = f:CreateTexture(nil, "BORDER")
        if string.find(p, "TOP") or string.find(p, "BOTTOM") then
            b:SetHeight(1.5)
            b:SetPoint(p:gsub("LEFT","RIGHT"), f, p:gsub("LEFT","RIGHT"), 0, 0)
        else
            b:SetWidth(1.5)
            b:SetPoint(p:gsub("TOP","BOTTOM"), f, p:gsub("TOP","BOTTOM"), 0, 0)
        end
        b:SetPoint(p, f, p, 0, 0)
        b:SetTexture(pR, pG, pB, pA)
    end
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Keystones")
    
    local titleLine = f:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
    titleLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -28)
    titleLine:SetTexture(pR, pG, pB, 0.4)
    
    local sbBox = CreateFrame("EditBox", nil, f)
    sbBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
    sbBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -34)
    sbBox:SetHeight(18)
    sbBox:SetFontObject("GameFontHighlightSmall")
    sbBox:SetAutoFocus(false)
    sbBox:SetTextInsets(6, 6, 0, 0)
    
    local sbBorder = sbBox:CreateTexture(nil, "BORDER") sbBorder:SetPoint("TOPLEFT", sbBox, "TOPLEFT", -1, 1) sbBorder:SetPoint("BOTTOMRIGHT", sbBox, "BOTTOMRIGHT", 1, -1) sbBorder:SetTexture(pR, pG, pB, 0.4)
    local sbBg = sbBox:CreateTexture(nil, "BACKGROUND") sbBg:SetAllPoints() sbBg:SetTexture(0.02, 0.01, 0.04, 1)
    
    local ph = sbBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", sbBox, "LEFT", 6, 0)
    ph:SetText("Search keys...")
    
    sbBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then ph:Show() else ph:Hide() end
        core:UpdateUI()
    end)
    sbBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.searchBox = sbBox
    
    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -62)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 12)
    sf:EnableMouseWheel(true)
    f.scrollFrame = sf
    
    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(174)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    f.scrollChild = sc
    
    local sb = CreateFrame("Slider", nil, f)
    sb:SetWidth(4)
    sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -62)
    sb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 12)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    sb:SetValueStep(1)
    
    local thumb = sb:CreateTexture(nil, "BACKGROUND") thumb:SetTexture(pR, pG, pB, pA) thumb:SetWidth(4) thumb:SetHeight(32)
    sb:SetThumbTexture(thumb)
    f.slider = sb
    
    sf:SetScript("OnMouseWheel", function(self, delta)
        local curr = sb:GetValue()
        sb:SetValue(curr - (delta * 25))
    end)
    sb:SetScript("OnValueChanged", function(self, value)
        sf:SetVerticalScroll(value)
    end)
    
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
                    closeBtn:SetPoint("TOPRIGHT", MythicPlusFrame, "TOPRIGHT", -6, -62)
                    closeBtn:SetFrameLevel((MythicPlusFrame:GetFrameLevel() or 71) + 10)
                    closeBtn:SetScript("OnClick", function() MythicPlusFrame:Hide() end)
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
                        SendAddonMessage("MKR_REQ2", "REQ", "GUILD")
                        
                        for i = 1, GetFriendInfo and GetNumFriends() or 0 do
                            local name, _, _, _, connected = GetFriendInfo(i)
                            if connected and name then
                                SendAddonMessage("MKR_REQ2", "REQ", "WHISPER", name)
                            end
                        end
                    end
                    lastState = true
                else
                    if lastState then f.searchBox:ClearFocus() f:Hide() lastState = false end
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
    
    core:PruneExpiredKeys()
    
    f.rows = f.rows or {}
    for _, row in ipairs(f.rows) do row:Hide() row.link = nil end
    
    local rowId = 1
    local currentY = 0
    
    local function AddLine(labelText, itemLink, isHeader, isPlayer)
        if not f.rows[rowId] then
            local row = CreateFrame("Button", nil, f.scrollChild)
            row:SetHeight(15)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetAllPoints() text:SetJustifyH("LEFT") row.text = text
            
            row:SetScript("OnEnter", function(self)
                if self.link then GameTooltip:SetOwner(f, "ANCHOR_RIGHT") GameTooltip:SetHyperlink(self.link) GameTooltip:Show() end
            end)
            row:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(self, button)
                if self.link then
                    if IsModifiedClick() then HandleModifiedItemClick(self.link) else SetItemRef(self.link, self.link, button) end
                end
            end)
            f.rows[rowId] = row
        end
        
        local row = f.rows[rowId]
        row.link = itemLink
        row.text:SetText(labelText)
        
        if isHeader then row.text:SetFontObject("GameFontNormal")
        elseif isPlayer then row.text:SetFontObject("GameFontNormalSmall")
        else row.text:SetFontObject("GameFontHighlightSmall") end
        
        local extraSpacing = 0
        if rowId > 1 then extraSpacing = isHeader and 14 or (isPlayer and 8 or 2) end
        currentY = currentY + extraSpacing
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.scrollChild, "TOPLEFT", 0, -currentY)
        row:SetPoint("RIGHT", f.scrollChild, "RIGHT", 0, 0)
        
        currentY = currentY + 15
        row:Show()
        rowId = rowId + 1
    end
    
    local searchText = f.searchBox:GetText():lower()
    local guildLines = {}
    local friendLines = {}
    local myName = UnitName("player")
    
    -- Helper function to apply class color or offline grey
    local function GetColoredPlayerName(name, info)
        if not info or not info.online then
            return "|cff888888" .. name .. "|r"
        elseif info.class and RAID_CLASS_COLORS[info.class] then
            local color = RAID_CLASS_COLORS[info.class]
            local colorStr = color.colorStr or string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            return "|c" .. colorStr .. name .. "|r"
        end
        return name
    end

    -- PRIORITY FIX: Map live online friends list with class & online status
    local friendsMap = {}
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name then
                local shortName = string.match(info.name, "([^-]+)")
                friendsMap[shortName] = { class = info.className, online = info.connected }
            end
        end
    elseif GetFriendInfo then
        for i = 1, GetNumFriends() or 0 do
            local name, _, class, _, connected = GetFriendInfo(i)
            if name then
                local shortName = string.match(name, "([^-]+)")
                friendsMap[shortName] = { class = class, online = connected }
            end
        end
    end
    
    -- PRIORITY FIX: Map live local guild roster structure with class & online status
    local guildMap = {}
    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, _, online, _, classFileName = GetGuildRosterInfo(i)
            if name then
                local shortName = string.match(name, "([^-]+)")
                guildMap[shortName] = { class = classFileName, online = online }
            end
        end
    end
    
    for player, data in pairs(MKR_DB) do
        if type(data) == "table" and data.key and data.key ~= "NONE" and player ~= myName then
            local pMatch = string.find(player:lower(), searchText, 1, true)
            local matchedKeysForPlayer = {}
            
            for link in string.gmatch(data.key, "[^,]+") do
                local displayLink = string.gsub(link, "Mythic Keystone:%s*", "")
                local kMatch = string.find(displayLink:lower(), searchText, 1, true)
                if pMatch or kMatch then
                    table.insert(matchedKeysForPlayer, { link = link, display = displayLink })
                end
            end
            
            if #matchedKeysForPlayer > 0 then
                -- PRIORITY FIX: Guildmates take absolute sorting precedence over friend list assignment
                if guildMap[player] then
                    table.insert(guildLines, { player = player, keys = matchedKeysForPlayer, info = guildMap[player] })
                elseif friendsMap[player] then
                    table.insert(friendLines, { player = player, keys = matchedKeysForPlayer, info = friendsMap[player] })
                else
                    -- Fallback case for mesh sync profiles
                    table.insert(guildLines, { player = player, keys = matchedKeysForPlayer, info = nil })
                end
            end
        end
    end
    
    if #guildLines > 0 then
        AddLine("[Guild]", nil, true, false)
        for _, entry in ipairs(guildLines) do
            local displayName = GetColoredPlayerName(entry.player, entry.info)
            AddLine(displayName .. ":", nil, false, true)
            for _, kInfo in ipairs(entry.keys) do AddLine("   " .. kInfo.display, kInfo.link, false, false) end
        end
    end
    
    if #friendLines > 0 then
        AddLine("[Friends]", nil, true, false)
        for _, entry in ipairs(friendLines) do
            local displayName = GetColoredPlayerName(entry.player, entry.info)
            AddLine(displayName .. ":", nil, false, true)
            for _, kInfo in ipairs(entry.keys) do AddLine("   " .. kInfo.display, kInfo.link, false, false) end
        end
    end
    
    if rowId == 1 then
        if not f.emptyText then
            f.emptyText = f.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            f.emptyText:SetPoint("TOPLEFT", f.scrollChild, "TOPLEFT", 0, 0)
        end
        f.emptyText:SetText(searchText ~= "" and "No search results found." or "No keys stored.")
        f.emptyText:Show()
        f.scrollChild:SetHeight(15)
        f.slider:SetMinMaxValues(0, 0) f.slider:Hide()
    else
        if f.emptyText then f.emptyText:Hide() end
        f.scrollChild:SetHeight(currentY)
        local maxScroll = math.max(0, currentY - f.scrollFrame:GetHeight())
        f.slider:SetMinMaxValues(0, maxScroll)
        if maxScroll == 0 then f.slider:Hide() f.slider:SetValue(0) else f.slider:Show() end
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
        
        if prefix == "MKR_REQ2" then
            if channel == "WHISPER" and sender then
                core:GossipEntireDatabase(sender)
            else
                core:GossipEntireDatabase()
            end
            
        elseif prefix == "MKR_MESH2" and text then
            local pName, keyStr, tStamp, seqNum = string.match(text, "([^~]+)~([^~]+)~([^~]+)~([^~]+)")
            tStamp = tonumber(tStamp)
            seqNum = tonumber(seqNum)
            
            if pName and keyStr and tStamp and seqNum then
                local lastReset = core:GetLastResetTime()
                
                if tStamp >= lastReset then
                    local current = MKR_DB[pName]
                    if not current or seqNum > (current.seq or 0) then
                        MKR_DB[pName] = { key = keyStr, time = tStamp, seq = seqNum }
                        core:UpdateUI()
                    elseif current and (current.seq or 0) > seqNum then
                        local now = GetTime()
                        if not syncThrottle[pName] or (now - syncThrottle[pName]) > 5 then
                            syncThrottle[pName] = now
                            core:GossipRecord(pName, current.key, current.time, current.seq or 1)
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
        if msg and type(msg) == "string" then
            local lowerMsg = string.lower(msg)
            if lowerMsg == "?keys" or lowerMsg == "#keys" then
                core:ReportKeysChat(event)
            end
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

-- MythicPlusFrame Toggle Window Script Commands
SlashCmdList["MYTHICPLUSTOGGLE"] = function(msg)
    if MythicPlusFrame then if MythicPlusFrame:IsShown() then MythicPlusFrame:Hide() else MythicPlusFrame:Show() end
    else print("|cffcb9cff[MKR]|r Error: MythicPlusFrame not detected in this session.") end
end
SLASH_MYTHICPLUSTOGGLE1 = "/m+"
SLASH_MYTHICPLUSTOGGLE2 = "/mythic"