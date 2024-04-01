local GladiusEx = _G.GladiusEx
local L = LibStub("AceLocale-3.0"):GetLocale("GladiusEx")
local fn = LibStub("LibFunctional-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local DRData = LibStub("DRData-1.0")
local LibAuraInfo = LibStub("LibAuraInfo-1.0")

-- global functions
local strfind = string.find
local pairs, unpack = pairs, unpack
local GetTime, GetSpellTexture, UnitGUID = GetTime, GetSpellTexture, UnitGUID

local Spectate = GladiusEx:GetModule("Spectate", true)

local UnitAura = Spectate and Spectate.UnitAura or UnitAura
local GetUnitIdByGUID = Spectate and function(guid) return Spectate:GetUnitIdByGUID(guid) end or function(guid) return GladiusEx:GetUnitIdByGUID(guid) end

local defaults = {
    drTrackerAdjustSize = true,
    drTrackerMargin = 1,
    drTrackerSize = 40,
    drTrackerCrop = true,
    drTrackerOffsetX = 0,
    drTrackerOffsetY = 0,
    drTrackerFrameLevel = 8,
    drTrackerGloss = false,
    drTrackerGlossColor = { r = 1, g = 1, b = 1, a = 0.4 },
    drTrackerCooldown = true,
    drTrackerCooldownReverse = false,
    drFontSize = 18,
    drCategories = {},
    drIcons = {},
    showOnApply = true,
}

local DRTracker = GladiusEx:NewGladiusExModule("DRTracker",
    fn.merge(defaults, {
        drTrackerAttachTo = "ClassIcon",
        drTrackerAnchor = "RIGHT",
        drTrackerRelativePoint = "LEFT",
        drTrackerGrowDirection = "LEFT",
        drTrackerOffsetX = -2,
    }),
    fn.merge(defaults, {
        drTrackerAttachTo = "ClassIcon",
        drTrackerAnchor = "LEFT",
        drTrackerRelativePoint = "RIGHT",
        drTrackerGrowDirection = "RIGHT",
        drTrackerOffsetX = 2,
    }))

local drTexts = {
    [1] =    { "½", 0, 1, 0 },
    [0.5] =  { "¼", 1, 0.65,0 },
    [0.25] = { "Ø", 1, 0, 0 },
    [0] =    { "Ø", 1, 0, 0 },
}

function DRTracker:OnEnable()
    if not self.frame then
        self.frame = {}
    end

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function DRTracker:OnDisable()
    self:UnregisterAllEvents()

    for _, frame in pairs(self.frame) do
        frame:Hide()
    end
end

function DRTracker:GetFrames()
    return nil
end

function DRTracker:GetModuleAttachPoints()
    return {
        ["DRTracker"] = L["DRTracker"],
    }
end

function DRTracker:GetModuleAttachFrame(unit)
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    return self.frame[unit]
end

function DRTracker:CreateIcon(unit, drCat)
    local f = CreateFrame("CheckButton", "GladiusEx" .. self:GetName() .. "FrameCat" .. drCat .. unit, self.frame[unit], "ActionButtonTemplate")
    f.texture = _G[f:GetName().."Icon"]
    f.normalTexture = _G[f:GetName().."NormalTexture"]
    f.cooldown = _G[f:GetName().."Cooldown"]
    f.text = f:CreateFontString(nil, "OVERLAY")

    self.frame[unit].tracker[drCat] = f
end

function DRTracker:UpdateIcon(unit, drCat)
    local tracked = self.frame[unit].tracker[drCat]

    tracked:EnableMouse(false)
    tracked.reset_time = 0

    tracked:SetWidth(self.frame[unit]:GetHeight())
    tracked:SetHeight(self.frame[unit]:GetHeight())

    tracked:SetNormalTexture([[Interface\AddOns\GladiusEx\media\gloss]])
    tracked.normalTexture:SetVertexColor(self.db[unit].drTrackerGlossColor.r, self.db[unit].drTrackerGlossColor.g,
        self.db[unit].drTrackerGlossColor.b, self.db[unit].drTrackerGloss and self.db[unit].drTrackerGlossColor.a or 0)

    -- cooldown
    tracked.cooldown:SetReverse(self.db[unit].drTrackerCooldownReverse)
    if self.db[unit].drTrackerCooldown then
        tracked.cooldown:Show()
    else
        tracked.cooldown:Hide()
    end

    -- text
    tracked.text:SetFont(LSM:Fetch(LSM.MediaType.FONT, "2002"), self.db[unit].drFontSize, "OUTLINE")
    tracked.text:ClearAllPoints()
    tracked.text:SetPoint("BOTTOMRIGHT", tracked, -2, 0)
    tracked.text:SetDrawLayer("OVERLAY")
    tracked.text:SetJustifyH("RIGHT")

    -- style action button
    tracked.normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
    tracked.normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)

    tracked.normalTexture:ClearAllPoints()
    tracked.normalTexture:SetPoint("CENTER", 0, 0)

    tracked.texture:ClearAllPoints()
    tracked.texture:SetPoint("TOPLEFT", tracked, "TOPLEFT")
    tracked.texture:SetPoint("BOTTOMRIGHT", tracked, "BOTTOMRIGHT")
    if self.db[unit].drTrackerCrop then
        local n = 5
        tracked.texture:SetTexCoord(n / 64, 1 - n / 64, n / 64, 1 - n / 64)
    else
        tracked.texture:SetTexCoord(0, 1, 0, 1)
    end
end


function DRTracker:SortIcons(unit)
    local lastFrame

    for cat, frame in pairs(self.frame[unit].tracker) do
        frame:ClearAllPoints()

        if frame.active then
            if not lastFrame then
                -- frame:SetPoint(self.db[unit].drTrackerAnchor, self.frame[unit], self.db[unit].drTrackerRelativePoint, self.db[unit].drTrackerOffsetX, self.db[unit].drTrackerOffsetY)
                frame:SetPoint("TOPLEFT", self.frame[unit])
            elseif self.db[unit].drTrackerGrowDirection == "RIGHT" then
                frame:SetPoint("TOPLEFT", lastFrame, "TOPRIGHT", self.db[unit].drTrackerMargin, 0)
            elseif self.db[unit].drTrackerGrowDirection == "LEFT" then
                frame:SetPoint("TOPRIGHT", lastFrame, "TOPLEFT", -self.db[unit].drTrackerMargin, 0)
            elseif self.db[unit].drTrackerGrowDirection == "UP" then
                frame:SetPoint("BOTTOMLEFT", lastFrame, "TOPLEFT", 0, self.db[unit].drTrackerMargin)
            elseif self.db[unit].drTrackerGrowDirection == "DOWN" then
                frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -self.db[unit].drTrackerMargin)
            end

            lastFrame = frame

            frame:Show()
        else
            frame:Hide()
        end
    end
end

function DRTracker:DRFaded(unit, spellID, event)
    local drCat = DRData:GetSpellCategory(spellID)
    if self.db[unit].drCategories[drCat] == false then return end

    if not self.frame[unit].tracker[drCat] then
        self:CreateIcon(unit, drCat)
        self:UpdateIcon(unit, drCat)
    end
    
    local useApplied = self.db[unit].showOnApply

    local applied = useApplied and (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH") or (event == "SPELL_AURA_APPLIED")

    if not useApplied and applied then
        return -- K: If we're not showing on apply then _APPLIED events are not relevant
    end

    local tracked = self.frame[unit].tracker[drCat]

    -- Update DR levels
    if (not applied and not useApplied) or (applied and useApplied) then
        if tracked.active then
            local oldDiminished = tracked.diminished
            tracked.diminished = DRData:NextDR(tracked.diminished)
            
            -- K: Fallback edge-case early DR reset detection
            if oldDiminished and oldDiminished == 0.25 and tracked.diminished == 0 then
                tracked.diminished = 1
            end
        else
            tracked.active = true
            tracked.diminished = 1
        end
    end
    
    -- K: This could happen if a _REMOVED is received before an _APPLIED/_REFRESH
    -- when using showOnApply (e.g, due to joining late/spectate etc) 
    if not tracked.active then
        return 
    end

    local text, r, g, b = unpack(drTexts[tracked.diminished])
    tracked.text:SetText(text)
    tracked.text:SetTextColor(r,g,b)
    
    local txtID = spellID 
    if self.db[unit].drIcons[drCat] ~= nil then
        txtID = self.db[unit].drIcons[drCat]
    end
    
    local _,_,texture = GetSpellInfo(txtID)
    tracked.texture:SetTexture(texture)
    
    local time_left = DRData:GetResetTime()
    tracked.reset_time = time_left + GetTime()

    -- Show the cooldown swirl
    if self.db[unit].drTrackerCooldown then
        if useApplied and applied then -- K: Don't show swirl on _APPLIED/REFRESH when using showOnApply
            tracked.cooldown:SetCooldown(0, 0)
            tracked.cooldown:Hide()
        else
            tracked.cooldown:SetCooldown(GetTime(), time_left)
            tracked.cooldown:Show()
            --tracked.cooldown:SetBlingDuration(50)
        end
    end
    
    if not applied then
        tracked:SetScript("OnUpdate", function(f, elapsed)
            -- add extra time to allow the cooldown frame to play the bling animation
            if GetTime() >= (f.reset_time + 0.5) then
                tracked.active = false
                self:SortIcons(unit)
                f:SetScript("OnUpdate", nil)
            end
        end)
    elseif (applied and useApplied) then
        tracked:SetScript("OnUpdate", nil)
    end

    tracked:Show()
    self:SortIcons(unit)
end

function DRTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ctime, eventType, cGUID, cName, cFlags, destGUID, dName, dFlags, spellID, spellName, spellSchool, auraType)
    -- Enemy had a debuff refreshed before it faded
    -- Buff or debuff faded from an enemy
    if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_REMOVED" then
        local drCat = DRData:GetSpellCategory(spellID)
        if drCat and auraType == "DEBUFF" then
            local unit = GetUnitIdByGUID(destGUID)
            if unit and self.frame[unit] then
                
                -- Bug workaround: for some spells, when spectating (only), _REFRESH is fired right after _APPLIED causing bugs (on many servers)
                if GladiusEx:IsSpectating() and cGUID and spellID and destGUID then
                    if eventType == "SPELL_AURA_APPLIED" then
                        self[cGUID..spellID..destGUID] = { lastTime = ctime, timer = GladiusEx:ScheduleTimer(self.ClearData, 20, self, cGUID, spellID, destGUID) }
                    else
                        local data = self[cGUID..spellID..destGUID]
                        if data and data.lastTime + 0.5 > ctime then
                            self:ClearData(cGUID, spellID, destGUID)
                            return
                        end
                    end
                end
                
                -- Dynamic DR reset early if we have a full duration aura on _REFRESH / _APPLIED 
                local tracked = (self.frame[unit] and self.frame[unit].tracker) and self.frame[unit].tracker[drCat] or nil
                if tracked and (eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_APPLIED") then
                    if self:HasFullDurationAura(unit, cGUID, spellID) then
                        tracked.active = false
                    end
                end
                
                
                self:DRFaded(unit, spellID, eventType)
            end
        end
    end
end

function DRTracker:ClearData(cGUID, spellID, destGUID)
    local data = self[cGUID..spellID..destGUID]
    
    if data then
        GladiusEx:CancelTimer(data.timer)
        self[cGUID..spellID..destGUID] = nil
    end
end

function DRTracker:HasFullDurationAura(unit, cGUID, spellID)
    local fullDuration = GladiusEx.auraDurations[spellID]
    
    if fullDuration then
        local srcUnit = GetUnitIdByGUID(srcGUID)

        for i=1, 40 do
            local name, _, _, _, _, duration, _, unitCaster, _, _, sSpellID, srcGUID = UnitAura(unit, i, "HARMFUL")
            if not name then break end
            if sSpellID == spellID then
                if ((not srcGUID or srcGUID == cGUID) or ((not unitCaster and not scrUnit) or (unitCaster and srcUnit and unitCaster == srcUnit))) then
                    -- Some classes/races have CC duration reduction effects, thus we have to check if it's at least longer than 50% of fullDuration
                    -- which would imply it's possibly reduced by effects - but at least not DRd (which would be less than or equal to 50%)
                    -- Note: No class/race/comp combo has the possibility to reduce a CC more than than 50%
                    if duration == fullDuration or duration > (fullDuration / 2) then
                        return true
                    end
                end
            end
        end
    end
end

function DRTracker:CreateFrame(unit)
    local button = GladiusEx.buttons[unit]
    if not button then return end

    -- create frame
    self.frame[unit] = CreateFrame("Frame", "GladiusEx" .. self:GetName() .. "Frame" .. unit, button, "ActionButtonTemplate")
end

function DRTracker:Update(unit)
    -- create frame
    if not self.frame[unit] then
        self:CreateFrame(unit)
    end

    -- update frame
    self.frame[unit]:ClearAllPoints()

    -- anchor point
    local parent = GladiusEx:GetAttachFrame(unit, self.db[unit].drTrackerAttachTo)
    self.frame[unit]:SetPoint(self.db[unit].drTrackerAnchor, parent, self.db[unit].drTrackerRelativePoint, self.db[unit].drTrackerOffsetX, self.db[unit].drTrackerOffsetY)

    -- frame level
    self.frame[unit]:SetFrameLevel(self.db[unit].drTrackerFrameLevel)

    local size = self.db[unit].drTrackerSize
    if self.db[unit].drTrackerAdjustSize then
        size = parent:GetHeight()
    end
    self.frame[unit]:SetSize(size, size)

    -- update icons
    if not self.frame[unit].tracker then
        self.frame[unit].tracker = {}
    else
        for cat, frame in pairs(self.frame[unit].tracker) do
            frame:SetWidth(self.frame[unit]:GetHeight())
            frame:SetHeight(self.frame[unit]:GetHeight())

            frame.normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
            frame.normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)

            self:UpdateIcon(unit, cat)
        end
        self:SortIcons(unit)
    end

    -- hide
    self.frame[unit]:Hide()
end

function DRTracker:Show(unit)
    -- show frame
    self.frame[unit]:Show()
end

function DRTracker:Reset(unit)
    if not self.frame[unit] then return end

    -- hide icons
    for _, frame in pairs(self.frame[unit].tracker) do
        frame.active = false
        frame.diminished = 1
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end

    -- hide
    self.frame[unit]:Hide()
end

function DRTracker:Test(unit)
    self:DRFaded(unit, 64058, "SPELL_AURA_APPLIED")
    self:DRFaded(unit, 64058, "SPELL_AURA_REMOVED")

    self:DRFaded(unit, 118, "SPELL_AURA_APPLIED")
	self:DRFaded(unit, 118, "SPELL_AURA_REMOVED")
    self:DRFaded(unit, 118, "SPELL_AURA_APPLIED")
    self:DRFaded(unit, 118, "SPELL_AURA_REMOVED")
    
    self:DRFaded(unit, 33786, "SPELL_AURA_APPLIED")
    self:DRFaded(unit, 33786, "SPELL_AURA_REMOVED")
    self:DRFaded(unit, 33786, "SPELL_AURA_APPLIED")
    self:DRFaded(unit, 33786, "SPELL_AURA_REMOVED")
    self:DRFaded(unit, 33786, "SPELL_AURA_APPLIED")
    self:DRFaded(unit, 33786, "SPELL_AURA_REMOVED")
end

function DRTracker:GetOptions(unit)
    local options = {
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                widget = {
                    type = "group",
                    name = L["Widget"],
                    desc = L["Widget settings"],
                    inline = true,
                    order = 1,
                    args = {
                        drTrackerCooldown = {
                            type = "toggle",
                            name = L["Cooldown spiral"],
                            desc = L["Display the cooldown spiral for the drTracker icons"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 10,
                        },
                        drTrackerCooldownReverse = {
                            type = "toggle",
                            name = L["Cooldown reverse"],
                            desc = L["Invert the dark/bright part of the cooldown spiral"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 15,
                        },
                        drTrackerCrop = {
                            type = "toggle",
                            name = L["Crop borders"],
                            desc = L["Toggle if the icon borders should be cropped or not"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 16,
                        },
                        sep3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 17,
                        },
                        drTrackerGloss = {
                            type = "toggle",
                            name = L["Gloss"],
                            desc = L["Toggle gloss on the icon"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 25,
                        },
                        drTrackerGlossColor = {
                            type = "color",
                            name = L["Gloss color"],
                            desc = L["Color of the gloss"],
                            get = function(info) return GladiusEx:GetColorOption(self.db[unit], info) end,
                            set = function(info, r, g, b, a) return GladiusEx:SetColorOption(self.db[unit], info, r, g, b, a) end,
                            hasAlpha = true,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 30,
                        },
                        showOnApply = {
                            type = "toggle",
                            name = L["Show on Apply"],
                            desc = L["Show DRs on start instead of on refresh/removal"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 35,
                        },
                        sep4 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 40,
                        },
                        drTrackerFrameLevel = {
                            type = "range",
                            name = L["Frame level"],
                            desc = L["Frame level of the frame"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            hidden = function() return not GladiusEx.db.base.advancedOptions end,
                            softMin = 1, softMax = 100, step = 1,
                            order = 45,
                        },
                    },
                },
                size = {
                    type = "group",
                    name = L["Size"],
                    desc = L["Size settings"],
                    inline = true,
                    order = 2,
                    args = {
                        drTrackerMargin = {
                            type = "range",
                            name = L["Spacing"],
                            desc = L["Space between the icons"],
                            min = 0, max = 100, step = 1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 5,
                        },
                        drTrackerSize = {
                            type = "range",
                            name = L["Icon size"],
                            desc = L["Size of the icons"],
                            min = 1, softMin = 10, softMax = 100, bigStep = 1,
                            disabled = function() return self.db[unit].drTrackerAdjustSize or not self:IsUnitEnabled(unit) end,
                            order = 6,
                        },
                        drTrackerAdjustSize = {
                            type = "toggle",
                            name = L["Adjust size"],
                            desc = L["Adjust size to the frame size"],
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 7,
                        },
                    },
                },
                font = {
                    type = "group",
                    name = L["Font"],
                    desc = L["Font settings"],
                    inline = true,
                    order = 3,
                    args = {
                        drFontSize = {
                            type = "range",
                            name = L["Text size"],
                            desc = L["Text size of the DR text"],
                            min = 1, max = 20, step = 1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 15,
                        },
                    },
                },
                position = {
                    type = "group",
                    name = L["Position"],
                    desc = L["Position settings"],
                    inline = true,
                    order = 4,
                    args = {
                        drTrackerAttachTo = {
                            type = "select",
                            name = L["Attach to"],
                            desc = L["Attach to the given frame"],
                            values = function() return self:GetOtherAttachPoints(unit) end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 1,
                        },
                        drTrackerPosition = {
                            type = "select",
                            name = L["Position"],
                            desc = L["Position of the frame"],
                            values = GladiusEx:GetGrowSimplePositions(),
                            get = function()
                                return GladiusEx:GrowSimplePositionFromAnchor(
                                    self.db[unit].drTrackerAnchor,
                                    self.db[unit].drTrackerRelativePoint,
                                    self.db[unit].drTrackerGrowDirection)
                            end,
                            set = function(info, value)
                                self.db[unit].drTrackerAnchor, self.db[unit].drTrackerRelativePoint =
                                    GladiusEx:AnchorFromGrowSimplePosition(value, self.db[unit].drTrackerGrowDirection)
                                GladiusEx:UpdateFrames()
                            end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            hidden = function() return GladiusEx.db.base.advancedOptions end,
                            order = 6,
                        },
                        drTrackerGrowDirection = {
                            type = "select",
                            name = L["Grow direction"],
                            values = {
                                ["LEFT"]  = L["Left"],
                                ["RIGHT"] = L["Right"],
                                ["UP"]    = L["Up"],
                                ["DOWN"]  = L["Down"],
                            },
                            set = function(info, value)
                                if not GladiusEx.db.base.advancedOptions then
                                    self.db[unit].drTrackerAnchor, self.db[unit].drTrackerRelativePoint =
                                        GladiusEx:AnchorFromGrowDirection(
                                            self.db[unit].drTrackerAnchor,
                                            self.db[unit].drTrackerRelativePoint,
                                            self.db[unit].drTrackerGrowDirection,
                                            value)
                                end
                                self.db[unit].drTrackerGrowDirection = value
                                GladiusEx:UpdateFrames()
                            end,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 7,
                        },
                        sep = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 8,
                        },
                        drTrackerAnchor = {
                            type = "select",
                            name = L["Anchor"],
                            desc = L["Anchor of the frame"],
                            values = GladiusEx:GetPositions(),
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            hidden = function() return not GladiusEx.db.base.advancedOptions end,
                            order = 10,
                        },
                        drTrackerRelativePoint = {
                            type = "select",
                            name = L["Relative point"],
                            desc = L["Relative point of the frame"],
                            values = GladiusEx:GetPositions(),
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            hidden = function() return not GladiusEx.db.base.advancedOptions end,
                            order = 15,
                        },
                        sep2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 17,
                        },
                        drTrackerOffsetX = {
                            type = "range",
                            name = L["Offset X"],
                            desc = L["X offset of the frame"],
                            softMin = -100, softMax = 100, bigStep = 1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 20,
                        },
                        drTrackerOffsetY = {
                            type = "range",
                            name = L["Offset Y"],
                            desc = L["Y offset of the frame"],
                            softMin = -100, softMax = 100, bigStep = 1,
                            disabled = function() return not self:IsUnitEnabled(unit) end,
                            order = 25,
                        },
                    },
                },
            },
        },
    }

    options.categories = {
        type = "group",
        name = L["Categories"],
        order = 2,
        args = {
            categories = {
                type = "group",
                name = L["Categories"],
                desc = L["Category settings"],
                inline = true,
                order = 1,
                args = {
                },
            },
        },
    }

    options.icon_for_category = {
        type = "group",
        name = "Icon for category",
        order = 3,
        args = {}
    }

    local index = 1
    for key, name in pairs(DRData:GetCategories()) do
        options.categories.args.categories.args[key] = {
            type = "toggle",
            name = name,
            get = function(info)
                if self.db[unit].drCategories[info[#info]] == nil then
                    return true
                else
                    return self.db[unit].drCategories[info[#info]]
                end
            end,
            set = function(info, value)
                self.db[unit].drCategories[info[#info]] = value
            end,
            disabled = function() return not self:IsUnitEnabled(unit) end,
            order = index * 5,
        }

        local values = {"Default"}
        local seen_icons = {}
        local id = 1
        local icon_spell_ids = {}
        for spellid, _ in DRData:IterateProviders(key) do
            local spellname, _, spellicon = GetSpellInfo(spellid)
            if spellname == nil then
                print("This Diminishing Returns related spell ID does not exist: "..spellid)
            end
            if spellname ~= nil and (not seen_icons[spellname] or not seen_icons[spellname][spellicon]) then
                if seen_icons[spellname] then
                    seen_icons[spellname][spellicon] = true
                else
                    seen_icons[spellname] = { [spellicon] = true }
                end
                icon_spell_ids[id] = spellid
                table.insert(
                    values,
                    string.format(" |T%s:20|t %s", spellicon, spellname)
                )
                id = id + 1
            end
        end
        
        if #icon_spell_ids > 1 then
            options.icon_for_category.args[key] = {
                type = "select",
                name = name,
                values = values,
                order = index * 5,
                style = "dropdown",
                get = function(info)
                    if not self.db[unit].drIcons[key] then
                        return 1
                    end
                    for id, spellid in pairs(icon_spell_ids) do
                        if spellid == self.db[unit].drIcons[key] then
                            -- +1 because 1 is "default"
                            return id + 1
                        end
                    end
                    return 1
                end,
                set = function(info, value)
                    -- 1 = default
                    if value > 1 then
                        self.db[unit].drIcons[key] = icon_spell_ids[value - 1]
                    else
                        self.db[unit].drIcons[key] = nil
                    end
                end,
            }
        end
        index = index + 1
    end

    return options
end
