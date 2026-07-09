local AddonName, addon = ...
local core = addon.core or {}
if not addon.core then addon.core = core end

-- ============================================================================
-- 1. 3.3.5 Skill Engine Scanning Routine (Captures Cleaned Raw & Formatted Links)
-- ============================================================================
function core:ScanLocalProfessions()
    local myName = UnitName("player")
    if not MKR_DB then return end
    
    MKR_DB[myName] = MKR_DB[myName] or {}
    MKR_DB[myName].professions = MKR_DB[myName].professions or {}

    -- Flush legacy records to ensure clean structured initialization
    MKR_DB[myName].professions[1] = nil
    MKR_DB[myName].professions[2] = nil

    local myGUID = UnitGUID("player") or ""
    local cleanGUID = myGUID:gsub("^0x", "") -- Crucial: Strip "0x" for native 3.3.5a trade links

    -- 3.3.5 Localization-safe Spell Reference Map
    local profLookup = {
        [GetSpellInfo(2259) or "Alchemy"] = { castName = GetSpellInfo(2259) or "Alchemy", fallbackID = 2259, defaultIcon = "Interface\\Icons\\Trade_Alchemy" },
        [GetSpellInfo(2018) or "Blacksmithing"] = { castName = GetSpellInfo(2018) or "Blacksmithing", fallbackID = 2018, defaultIcon = "Interface\\Icons\\Trade_BlackSmithing" },
        [GetSpellInfo(7411) or "Enchanting"] = { castName = GetSpellInfo(7411) or "Enchanting", fallbackID = 7411, defaultIcon = "Interface\\Icons\\Trade_Engraving" },
        [GetSpellInfo(4036) or "Engineering"] = { castName = GetSpellInfo(4036) or "Engineering", fallbackID = 4036, defaultIcon = "Interface\\Icons\\Trade_Engineering" },
        [GetSpellInfo(45357) or "Inscription"] = { castName = GetSpellInfo(45357) or "Inscription", fallbackID = 45357, defaultIcon = "Interface\\Icons\\INV_Scroll_08" },
        [GetSpellInfo(25229) or "Jewelcrafting"] = { castName = GetSpellInfo(25229) or "Jewelcrafting", fallbackID = 25229, defaultIcon = "Interface\\Icons\\INV_Misc_Gem_01" },
        [GetSpellInfo(2108) or "Leatherworking"] = { castName = GetSpellInfo(2108) or "Leatherworking", fallbackID = 2108, defaultIcon = "Interface\\Icons\\Trade_LeatherWorking" },
        [GetSpellInfo(3908) or "Tailoring"] = { castName = GetSpellInfo(3908) or "Tailoring", fallbackID = 3908, defaultIcon = "Interface\\Icons\\Trade_Tailoring" },
        [GetSpellInfo(2575) or "Mining"] = { castName = GetSpellInfo(2656) or "Smelting", fallbackID = 2656, defaultIcon = "Interface\\Icons\\Trade_Mining" },
    }

    local count = 0
    -- Loop through the 3.3.5 skills book interface natively
    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        
        if skillName and not isHeader and profLookup[skillName] then
            local info = profLookup[skillName]
            
            -- Dynamic high-tier rank spell ID detection
            local activeSpellID = info.fallbackID
            local spellLink = GetSpellLink(info.castName)
            if spellLink then
                local extractedID = spellLink:match("spell:(%d+)")
                if extractedID then
                    activeSpellID = tonumber(extractedID)
                end
            end
            
            count = count + 1
            if count <= 2 then
                local rawLinkStr = string.format("trade:%d:%d:%d:%s:0", activeSpellID, rank or 0, maxRank or 0, cleanGUID)
                local fullLinkStr = string.format("|cffffd000|H%s|h[%s]|h|r", rawLinkStr, skillName)
                
                MKR_DB[myName].professions[count] = {
                    link = fullLinkStr,
                    rawLink = rawLinkStr,
                    icon = info.defaultIcon,
                    name = skillName,
                    castName = info.castName,
                    rank = rank or 0,
                    maxRank = maxRank or 0
                }
            end
        end
    end
end

-- ============================================================================
-- 2. Construct Authentic 3.3.5 Blizzard-Styled UI Rows (Anchored BELOW Frame)
-- ============================================================================
function core:CreateProfDetailFrame()
    if core.profFrame then return end
    if not GuildMemberDetailFrame then return end

    -- Container frame now anchored directly BELOW the 3.3.5 GuildMemberDetailFrame
    local f = CreateFrame("Frame", "MKR_GuildProfDetailFrame", GuildMemberDetailFrame)
    f:SetPoint("TOPLEFT", GuildMemberDetailFrame, "BOTTOMLEFT", 0, 2)
    f:SetPoint("TOPRIGHT", GuildMemberDetailFrame, "BOTTOMRIGHT", 0, 2)
    f:SetHeight(44)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(1, 1, 1)
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.9)
    f.bg = bg

    -- Decorative divider line between the bottom of GuildMemberDetailFrame and our panel
    local topBorder = f:CreateTexture(nil, "OVERLAY")
    topBorder:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    topBorder:SetHeight(1)
    topBorder:SetTexture(1, 1, 1)
    topBorder:SetVertexColor(0.3, 0.25, 0.2, 0.6)

    -- Helper layout script to build a high-fidelity row component
    local function CreateBlizzardProfButton(parent)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetHeight(18)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(1, 1, 1)
        btnBg:SetVertexColor(0.1, 0.1, 0.1, 0.4)
        btn.bg = btnBg

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(14)
        icon:SetHeight(14)
        icon:SetPoint("LEFT", btn, "LEFT", 6, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon = icon

        local iconBorder = btn:CreateTexture(nil, "OVERLAY")
        iconBorder:SetWidth(16)
        iconBorder:SetHeight(16)
        iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
        iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        btn.iconBorder = iconBorder

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        btn.text = text

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\Buttons\\UI-ListboxHighlight2")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.4)
        btn:SetHighlightTexture(highlight)

        btn:SetScript("OnClick", function(self, button)
            if IsModifiedClick() then
                if self.link then
                    HandleModifiedItemClick(self.link)
                end
            else
                -- 1. Native Override for Local Player Character
                local currentSelectionIndex = GetGuildRosterSelection()
                if currentSelectionIndex and currentSelectionIndex > 0 then
                    local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(currentSelectionIndex)
                    if name then
                        name = Ambiguate(name, "none")
                        if name == UnitName("player") and self.name then
                            CastSpellByName(self.castName or self.name)
                            return
                        end
                        -- 2. Offline guard blocker to avoid dead execution requests
                        if not online then
                            UIErrorsFrame:AddMessage("Cannot inspect recipes while player is offline.", 1.0, 0.1, 0.1, 1.0)
                            PlaySound("igQuestFailed")
                            return
                        end
                    end
                end

                -- 3. Remote Fallback Viewer for other Online Guild Members
                if self.rawLink then
                    if not IsAddOnLoaded("Blizzard_TradeSkillUI") then
                        UIParentLoadAddOn("Blizzard_TradeSkillUI")
                    end
                    SetItemRef(self.rawLink, self.rawLink, button)
                end
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if self.rawLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.rawLink)
                GameTooltip:Show()
            end
            self.bg:SetVertexColor(0.2, 0.2, 0.2, 0.6)
        end)

        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self.bg:SetVertexColor(0.1, 0.1, 0.1, 0.4)
        end)

        return btn
    end

    f.prof1 = CreateBlizzardProfButton(f)
    f.prof1:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    f.prof1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)

    f.prof2 = CreateBlizzardProfButton(f)
    f.prof2:SetPoint("TOPLEFT", f.prof1, "BOTTOMLEFT", 0, -2)
    f.prof2:SetPoint("TOPRIGHT", f.prof1, "BOTTOMRIGHT", 0, -2)

    core.profFrame = f
end

-- ============================================================================
-- 3. Dynamic Roster Context Synchronization (With Offline Status Check)
-- ============================================================================
function core:UpdateDetailFrameProfessions()
    if not GuildMemberDetailFrame or not GuildMemberDetailFrame:IsShown() then
        if core.profFrame then core.profFrame:Hide() end
        return
    end

    local index = GetGuildRosterSelection()
    if not index or index == 0 then
        if core.profFrame then core.profFrame:Hide() end
        return
    end

    -- Query native character values; online status resides at return slot #9
    local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(index)
    if not name then
        if core.profFrame then core.profFrame:Hide() end
        return
    end

    core:CreateProfDetailFrame()
    core.profFrame:Show()

    -- Reset fallbacks cleanly
    core.profFrame.prof1.text:SetText("|cff808080No Profession Data|r")
    core.profFrame.prof1.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    core.profFrame.prof1.icon:SetVertexColor(1, 1, 1, 1)
    core.profFrame.prof1.link = nil
    core.profFrame.prof1.rawLink = nil
    core.profFrame.prof1.name = nil
    core.profFrame.prof1.castName = nil

    core.profFrame.prof2.text:SetText("|cff808080No Profession Data|r")
    core.profFrame.prof2.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    core.profFrame.prof2.icon:SetVertexColor(1, 1, 1, 1)
    core.profFrame.prof2.link = nil
    core.profFrame.prof2.rawLink = nil
    core.profFrame.prof2.name = nil
    core.profFrame.prof2.castName = nil

    local playerData = MKR_DB[name]

    if playerData and playerData.professions then
        -- Process Slot 1
        if playerData.professions[1] then
            local data = playerData.professions[1]
            if type(data) == "table" then
                local displayTxt = string.format("%s (%d/%d)", data.name or "Unknown", data.rank or 0, data.maxRank or 0)
                
                -- Check offline state rules to tint components grey out
                if not online and name ~= UnitName("player") then
                    displayTxt = "|cff808080" .. displayTxt .. " [Offline]|r"
                    core.profFrame.prof1.icon:SetVertexColor(0.4, 0.4, 0.4, 0.7)
                else
                    displayTxt = "|cffffd200" .. displayTxt .. "|r"
                end
                
                core.profFrame.prof1.text:SetText(displayTxt)
                core.profFrame.prof1.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                core.profFrame.prof1.link = data.link
                core.profFrame.prof1.name = data.name
                core.profFrame.prof1.castName = data.castName
                
                local rawLink = data.rawLink or (data.link and data.link:match("|H(.-)|h"))
                if rawLink then rawLink = rawLink:gsub(":(0x)", ":") end
                core.profFrame.prof1.rawLink = rawLink
            end
        end

        -- Process Slot 2
        if playerData.professions[2] then
            local data = playerData.professions[2]
            if type(data) == "table" then
                local displayTxt = string.format("%s (%d/%d)", data.name or "Unknown", data.rank or 0, data.maxRank or 0)
                
                if not online and name ~= UnitName("player") then
                    displayTxt = "|cff808080" .. displayTxt .. " [Offline]|r"
                    core.profFrame.prof2.icon:SetVertexColor(0.4, 0.4, 0.4, 0.7)
                else
                    displayTxt = "|cffffd200" .. displayTxt .. "|r"
                end
                
                core.profFrame.prof2.text:SetText(displayTxt)
                core.profFrame.prof2.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                core.profFrame.prof2.link = data.link
                core.profFrame.prof2.name = data.name
                core.profFrame.prof2.castName = data.castName
                
                local rawLink = data.rawLink or (data.link and data.link:match("|H(.-)|h"))
                if rawLink then rawLink = rawLink:gsub(":(0x)", ":") end
                core.profFrame.prof2.rawLink = rawLink
            end
        end
    end
end

-- ============================================================================
-- 4. Secure Script Hooking & Event Routing
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        core:ScanLocalProfessions()
        
        if GuildMemberDetailFrame then
            GuildMemberDetailFrame:HookScript("OnShow", function()
                core:UpdateDetailFrameProfessions()
            end)
            GuildMemberDetailFrame:HookScript("OnHide", function()
                if core.profFrame then core.profFrame:Hide() end
            end)
        end
        
        if GuildFrame_Update then
            hooksecurefunc("GuildFrame_Update", function()
                core:UpdateDetailFrameProfessions()
            end)
        end
        
        if GuildStatus_Update then
            hooksecurefunc("GuildStatus_Update", function()
                core:UpdateDetailFrameProfessions()
            end)
        end
    end
end)