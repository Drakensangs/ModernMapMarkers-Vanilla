-- ModernMapMarkers_UI.lua
-- Dropdown controls (Filter Markers, Find Marker), marker label, slash command.
-- Depends on MMM namespace defined in ModernMapMarkers.lua.

local isPfUI  = IsAddOnLoaded and IsAddOnLoaded("pfUI")
local strfind = string.find
local strsub  = string.sub
local tsort   = table.sort
local tinsert = tinsert
local ipairs  = ipairs
local getn    = getn
local min     = math.min

-- ============================================================
-- Marker label
-- ============================================================

local markerLabel

local function CreateMarkerLabel()
    markerLabel = CreateFrame("Frame", "MMMMarkerLabelFrame", WorldMapDetailFrame)
    markerLabel:SetFrameStrata("TOOLTIP")
    markerLabel:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 10)
    markerLabel:SetWidth(400)
    markerLabel:SetHeight(60)

    local areaLabel = WorldMapFrameAreaLabel
    if areaLabel then
        markerLabel:SetPoint("TOP", areaLabel, "TOP", 0, 0)
    else
        markerLabel:SetPoint("TOP", WorldMapDetailFrame, "TOP", 0, -10)
    end

    markerLabel.name = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.name:SetPoint("TOP", markerLabel, "TOP", 0, 0)
    markerLabel.name:SetJustifyH("CENTER")

    if areaLabel then
        local fontName, fontSize, fontFlags = areaLabel:GetFont()
        markerLabel.name:SetFont(fontName, fontSize, fontFlags)
        local r, g, b, a = areaLabel:GetShadowColor()
        local sx, sy = areaLabel:GetShadowOffset()
        markerLabel.name:SetShadowColor(r, g, b, a)
        markerLabel.name:SetShadowOffset(sx, sy)
        local tr, tg, tb = areaLabel:GetTextColor()
        markerLabel.name:SetTextColor(tr, tg, tb)
    else
        markerLabel.name:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE, THICKOUTLINE")
        markerLabel.name:SetShadowColor(0, 0, 0, 1)
        markerLabel.name:SetShadowOffset(1, -1)
        markerLabel.name:SetTextColor(1, 0.82, 0)
    end

    markerLabel.info = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.info:SetPoint("TOP", markerLabel.name, "BOTTOM", 0, -2)
    markerLabel.info:SetJustifyH("CENTER")
    markerLabel.info:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    markerLabel.info:SetShadowColor(0, 0, 0, 1)
    markerLabel.info:SetShadowOffset(1, -1)

    markerLabel.hint = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.hint:SetPoint("TOP", markerLabel.info, "BOTTOM", 0, -2)
    markerLabel.hint:SetJustifyH("CENTER")
    markerLabel.hint:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    markerLabel.hint:SetShadowColor(0, 0, 0, 1)
    markerLabel.hint:SetShadowOffset(1, -1)
    markerLabel.hint:SetTextColor(0.8, 0.8, 0.8)

    markerLabel:Hide()
end

local FACTION_COLORS = {
    Alliance = {0.15, 0.59, 0.75},
    Horde    = {0.89, 0.16, 0.10},
    Neutral  = {1,    0.82, 0   },
}

-- Returns r, g, b for a level number relative to the player's level,
-- mirroring the game's own mob difficulty coloring.
local function GetLevelColor(level)
    local delta = level - UnitLevel("player")
    if     delta >= 5  then return 1,    0.1,  0.1   -- red:    much higher
    elseif delta >= 1  then return 1,    0.5,  0.25  -- orange: slightly higher
    elseif delta >= -4 then return 1,    1,    0     -- yellow: even / slightly lower
    elseif delta >= -9 then return 0.25, 0.75, 0.25  -- green:  comfortably lower
    else                    return 0.6,  0.6,  0.6   -- grey:   trivial
    end
end

function MMM.ShowMarkerInfo(name, info, hint)
    if not markerLabel then CreateMarkerLabel() end
    if WorldMapFrameAreaLabel then WorldMapFrameAreaLabel:Hide() end

    markerLabel.name:SetText(name)

    if info and info ~= "" then
        local color = FACTION_COLORS[info]
        if color then
            markerLabel.info:SetTextColor(color[1], color[2], color[3])
            markerLabel.info:SetText("(" .. info .. ")")
        else
            -- Level info: "24-32" or "60". Color the numbers by difficulty.
            local _, _, _, maxStr = strfind(info, "^(%d+)-(%d+)$")
            local maxLevel = tonumber(maxStr or info)
            if maxLevel then
                local r, g, b = GetLevelColor(maxLevel)
                local colored = format("|cFF%02X%02X%02X%s|r", r*255, g*255, b*255, info)
                markerLabel.info:SetTextColor(1, 0.82, 0)
                markerLabel.info:SetText("(Level " .. colored .. ")")
            else
                markerLabel.info:SetTextColor(1, 0.82, 0)
                markerLabel.info:SetText("(" .. info .. ")")
            end
        end
        markerLabel.info:Show()
    else
        markerLabel.info:Hide()
    end

    if hint and hint ~= "" then
        markerLabel.hint:SetText(hint)
        markerLabel.hint:Show()
    else
        markerLabel.hint:Hide()
    end

    markerLabel:Show()
end

function MMM.HideMarkerInfo()
    if markerLabel then markerLabel:Hide() end
    if WorldMapFrameAreaLabel then WorldMapFrameAreaLabel:Show() end
end

-- ============================================================
-- Filter dropdown
-- ============================================================

local function ApplyChange()
    MMM.ForceRedraw()
    MMM.UpdateMarkers()
end

function InitFilterDropdown()
    local db = ModernMapMarkersDB

    local function addToggle(text, key)
        local info = {}
        info.text             = text
        info.checked          = db[key]
        info.keepShownOnClick = 1
        info.func = function()
            db[key] = not db[key]
            ApplyChange()
        end
        UIDropDownMenu_AddButton(info, 1)
    end

    local function addHeader(text)
        local info = {}
        info.text         = text
        info.isTitle      = 1
        info.notCheckable = 1
        UIDropDownMenu_AddButton(info, 1)
    end

    local function addFactionRadio(text, dbKey, value)
        local info = {}
        info.text             = text
        info.checked          = (db[dbKey] == value)
        info.keepShownOnClick = 1
        info.func = function()
            db[dbKey] = value
            ApplyChange()
            local ticker = CreateFrame("Frame")
            ticker:SetScript("OnUpdate", function()
                this:SetScript("OnUpdate", nil)
                UIDropDownMenu_Initialize(MMMFilterDropdown, InitFilterDropdown)
            end)
        end
        UIDropDownMenu_AddButton(info, 1)
    end

    -- Master toggle
    local info = {}
    info.text             = "All Markers"
    info.checked          = db.showMarkers
    info.keepShownOnClick = 1
    info.func = function()
        db.showMarkers = not db.showMarkers
        if not db.showMarkers then
            MMM.ClearMarkers()
            MMM.SetUpdateEnabled(false)
        else
            MMM.SetUpdateEnabled(true)
        end
        ApplyChange()
    end
    UIDropDownMenu_AddButton(info, 1)

    addToggle("Dungeons",     "showDungeons")
    addToggle("Raids",        "showRaids")
    addToggle("World Bosses", "showWorldBosses")

    addHeader("Transports")
    addToggle("Boats",     "showBoats")
    addToggle("Zeppelins", "showZeppelins")
    addToggle("Trams",     "showTrams")
    addToggle("Portals",   "showPortals")

    addHeader("Transport Faction")
    addFactionRadio("Show All",             "transportFaction", "all")
    addFactionRadio("|cFF2592C5Alliance|r", "transportFaction", "Alliance")
    addFactionRadio("|cFFE32A19Horde|r",    "transportFaction", "Horde")

    addHeader("Portal Faction")
    addFactionRadio("Show All",             "portalFaction", "all")
    addFactionRadio("|cFF2592C5Alliance|r", "portalFaction", "Alliance")
    addFactionRadio("|cFFE32A19Horde|r",    "portalFaction", "Horde")
end

-- ============================================================
-- Find Marker panel
-- ============================================================

local FIND_PANEL_WIDTH      = 280
local FIND_ROW_HEIGHT       = 16
local FIND_MAX_VISIBLE_ROWS = 14
local FIND_BUTTON_HEIGHT    = 20
local FIND_BUTTON_SPACING   = 2
local FIND_PANEL_PADDING    = 8
local FIND_LIST_AREA_TOP    = FIND_PANEL_PADDING + FIND_BUTTON_HEIGHT * 2 + FIND_BUTTON_SPACING * 2 + 4

local FIND_TYPES = {
    {id="dungeon",   label="Dungeons"},
    {id="raid",      label="Raids"},
    {id="worldboss", label="World Bosses"},
}

local function CreateFindSelectorButton(name, parent, width, text)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(width)
    btn:SetHeight(FIND_BUTTON_HEIGHT)
    btn:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    btn.label = label
    btn:SetScript("OnEnter", function()
        if not this.isActive then this:SetBackdropColor(0.3, 0.3, 0.3, 1) end
    end)
    btn:SetScript("OnLeave", function()
        if not this.isActive then this:SetBackdropColor(0.15, 0.15, 0.15, 1) end
    end)
    btn.isActive = false
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    return btn
end

local function SetFindButtonActive(btn, active)
    btn.isActive = active
    if active then
        btn:SetBackdropColor(0.2, 0.4, 0.7, 1)
        btn:SetBackdropBorderColor(0.4, 0.6, 1.0, 1)
        btn.label:SetTextColor(1, 1, 1)
    else
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        btn.label:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function MakeLvlString(description)
    if not description then return "" end
    local _, _, _, maxStr = strfind(description, "^(%d+)-(%d+)$")
    local maxLevel = tonumber(maxStr or description)
    if maxLevel then
        local r, g, b = GetLevelColor(maxLevel)
        return format("Level |cff%02X%02X%02X%s|r", r*255, g*255, b*255, description)
    end
    return "Level " .. description
end

local function CreateFindPanel(anchorFrame)
    local activeContinent = 1
    local activeType      = "dungeon"
    local displayList     = {}

    local findPanel = CreateFrame("Frame", "MMMFindPanel", WorldMapFrame)
    findPanel:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    findPanel:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 30)
    findPanel:SetWidth(FIND_PANEL_WIDTH)
    findPanel:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", -16, 0)
    findPanel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    findPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    findPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    findPanel:Hide()

    -- Forward declarations — must be above any SetScript that references them.
    local UpdateFindButtonStates
    local RefreshFindList

    -- Continent buttons (one row of two for vanilla).
    local halfWidth = (FIND_PANEL_WIDTH - FIND_PANEL_PADDING * 2 - FIND_BUTTON_SPACING) / 2

    local btnKalimdor = CreateFindSelectorButton("MMMFind_Kalimdor", findPanel, halfWidth, "Kalimdor")
    btnKalimdor:SetPoint("TOPLEFT", findPanel, "TOPLEFT", FIND_PANEL_PADDING, -FIND_PANEL_PADDING)

    local btnEK = CreateFindSelectorButton("MMMFind_EK", findPanel, halfWidth, "Eastern Kingdoms")
    btnEK:SetPoint("TOPLEFT", btnKalimdor, "TOPRIGHT", FIND_BUTTON_SPACING, 0)

    -- Type buttons: created up front, reflowed by UpdateFindButtonStates.
    local findTypeButtons = {}
    local numTypes = getn(FIND_TYPES)
    local typeWidth = (FIND_PANEL_WIDTH - FIND_PANEL_PADDING * 2 - FIND_BUTTON_SPACING * (numTypes - 1)) / numTypes
    for i = 1, numTypes do
        local tp  = FIND_TYPES[i]
        local btn = CreateFindSelectorButton("MMMFind_Type" .. i, findPanel, typeWidth, tp.label)
        if i == 1 then
            btn:SetPoint("TOPLEFT", btnKalimdor, "BOTTOMLEFT", 0, -FIND_BUTTON_SPACING)
        else
            btn:SetPoint("TOPLEFT", findTypeButtons[i - 1], "TOPRIGHT", FIND_BUTTON_SPACING, 0)
        end
        local t = tp.id
        btn:SetScript("OnClick", function()
            activeType = t
            UpdateFindButtonStates()
            RefreshFindList()
        end)
        findTypeButtons[i] = btn
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MMMFindScroll", findPanel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     findPanel, "TOPLEFT",     FIND_PANEL_PADDING,       -FIND_LIST_AREA_TOP)
    scrollFrame:SetPoint("BOTTOMRIGHT", findPanel, "BOTTOMRIGHT", -FIND_PANEL_PADDING - 22,  FIND_PANEL_PADDING)

    local rowButtons = {}
    for i = 1, FIND_MAX_VISIBLE_ROWS do
        local row = CreateFrame("Button", "MMMFind_Row" .. i, findPanel)
        row:SetHeight(FIND_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * FIND_ROW_HEIGHT))
        row:SetPoint("RIGHT",   scrollFrame, "RIGHT",   0, 0)

        -- Single OVERLAY hlTex per row. Extended downward on name rows with comments
        -- so one texture covers both rows. Comment rows defer to nameRow's hlTex.
        local hlTex = row:CreateTexture(nil, "OVERLAY")
        hlTex:SetAllPoints(row)
        hlTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hlTex:SetBlendMode("ADD")
        hlTex:SetAlpha(0.7)
        hlTex:Hide()
        row.hlTex = hlTex

        -- nameText: RIGHT anchor stops it before the level column — no SetWidth,
        -- so text clips (truncates) at the boundary rather than wrapping.
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT",  row, "LEFT",  4,   0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -82, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetJustifyV("MIDDLE")
        row.nameText = nameText

        -- lvlText: TOPRIGHT+BOTTOMRIGHT for proper vertical centering, no SetWidth.
        local lvlText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lvlText:SetPoint("TOPRIGHT",    row, "TOPRIGHT",    -4, 0)
        lvlText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
        lvlText:SetJustifyH("RIGHT")
        lvlText:SetJustifyV("MIDDLE")
        row.lvlText = lvlText

        row:SetScript("OnEnter", function()
            if this.nameRow then this.nameRow.hlTex:Show()
            else this.hlTex:Show() end
        end)
        row:SetScript("OnLeave", function()
            if this.nameRow then this.nameRow.hlTex:Hide()
            else this.hlTex:Hide() end
        end)
        row:SetScript("OnClick", function()
            if this.dataContinent then
                MMM.FindMarker(this.dataContinent, this.dataZone, this.dataName)
            end
        end)
        row:Hide()
        rowButtons[i] = row
    end

    local function sortLvl(a, b)
        local _, _, av = strfind(a.description or "", "^(%d+)")
        local _, _, bv = strfind(b.description or "", "^(%d+)")
        local an, bn = tonumber(av) or 0, tonumber(bv) or 0
        if an == bn then return (a.name or "") < (b.name or "") end
        return an < bn
    end

    local function BuildDisplayList()
        local flatData = MMM.GetFlatData()
        local sorted = {}
        for _, data in ipairs(flatData) do
            if data.continent == activeContinent and data.type == activeType then
                tinsert(sorted, data)
            end
        end
        tsort(sorted, sortLvl)

        displayList = {}
        for _, data in ipairs(sorted) do
            local baseName = data.name
            local comment
            local nl = strfind(baseName, "\n")
            if nl then
                comment  = strsub(baseName, nl + 1)
                baseName = strsub(baseName, 1, nl - 1)
                local _, ce = strfind(comment, "^|c%x%x%x%x%x%x%x%x")
                if ce then comment = strsub(comment, ce + 1) end
                local rs = strfind(comment, "|r$")
                if rs then comment = strsub(comment, 1, rs - 1) end
            end
            tinsert(displayList, {
                kind      = "name",
                text      = baseName,
                lvlText   = MakeLvlString(data.description),
                continent = data.continent,
                zone      = data.zone,
                dataName  = data.name,
                hasComment = (comment ~= nil),
            })
            if comment then
                tinsert(displayList, {kind = "comment", text = comment})
            end
        end
    end

    local function DrawRows()
        -- Always reset all highlight textures first. If the mouse leaves a row
        -- while the list redraws (e.g. during fast scrolling), OnLeave may never
        -- fire, leaving hlTex visible. This guarantees a clean slate every draw.
        for i = 1, FIND_MAX_VISIBLE_ROWS do
            rowButtons[i].hlTex:Hide()
        end

        local offset = FauxScrollFrame_GetOffset(scrollFrame)
        local total  = getn(displayList)
        for i = 1, FIND_MAX_VISIBLE_ROWS do
            local row = rowButtons[i]
            local idx = offset + i
            if idx <= total then
                local slot = displayList[idx]
                if slot.kind == "name" then
                    row.nameRow = nil
                    row.nameText:ClearAllPoints()
                    row.nameText:SetPoint("LEFT",  row, "LEFT",  4,   0)
                    row.nameText:SetPoint("RIGHT", row, "RIGHT", -82, 0)
                    row.nameText:SetTextColor(1, 1, 1)
                    row.nameText:SetText(slot.text)
                    row.lvlText:SetText(slot.lvlText or "")
                    row.dataContinent = slot.continent
                    row.dataZone      = slot.zone
                    row.dataName      = slot.dataName
                    if slot.hasComment then
                        row.hlTex:ClearAllPoints()
                        row.hlTex:SetPoint("TOPLEFT",     row, "TOPLEFT",     0,  0)
                        row.hlTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -FIND_ROW_HEIGHT)
                    else
                        row.hlTex:ClearAllPoints()
                        row.hlTex:SetAllPoints(row)
                    end
                    row.hlTex:Hide()
                else
                    -- Comment row: full-width text, no level column.
                    local parent = displayList[idx - 1]
                    row.nameRow = rowButtons[i - 1]
                    row.nameText:ClearAllPoints()
                    row.nameText:SetPoint("LEFT",  row, "LEFT",  4, 0)
                    row.nameText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                    row.nameText:SetTextColor(0.55, 0.55, 0.55)
                    row.nameText:SetText(slot.text)
                    row.lvlText:SetText("")
                    row.dataContinent = parent.continent
                    row.dataZone      = parent.zone
                    row.dataName      = parent.dataName
                end
                row:Show()
            else
                row.nameRow       = nil
                row.dataContinent = nil
                row.dataZone      = nil
                row.dataName      = nil
                row.nameText:SetText("")
                row.nameText:SetTextColor(1, 1, 1)
                row.lvlText:SetText("")
                row.hlTex:ClearAllPoints()
                row.hlTex:SetAllPoints(row)
                row.hlTex:Hide()
                row:Hide()
            end
        end
    end

    -- UpdateFindButtonStates: shows only type buttons that have data for the active
    -- continent, hides the rest, and reflowing widths to fill the available space.
    -- Falls back to the first available type if the current one has no data.
    UpdateFindButtonStates = function(continent)
        if continent then activeContinent = continent end
        SetFindButtonActive(btnKalimdor, activeContinent == 1)
        SetFindButtonActive(btnEK,       activeContinent == 2)

        local flatData    = MMM.GetFlatData()
        local typeVisible = {}
        for i = 1, numTypes do typeVisible[i] = false end
        for _, d in ipairs(flatData) do
            if d.continent == activeContinent then
                for i = 1, numTypes do
                    if FIND_TYPES[i].id == d.type then typeVisible[i] = true end
                end
            end
        end

        -- Fall back to first visible type if the active one has no data here.
        local valid = false
        for i = 1, numTypes do
            if FIND_TYPES[i].id == activeType and typeVisible[i] then
                valid = true; break
            end
        end
        if not valid then
            for i = 1, numTypes do
                if typeVisible[i] then activeType = FIND_TYPES[i].id; break end
            end
        end

        -- Collect visible buttons and reflow their widths evenly.
        local visible = {}
        for i = 1, numTypes do
            if typeVisible[i] then
                tinsert(visible, findTypeButtons[i])
                findTypeButtons[i]:Show()
            else
                findTypeButtons[i]:Hide()
            end
        end
        local n    = getn(visible)
        local btnW = (FIND_PANEL_WIDTH - FIND_PANEL_PADDING * 2 - FIND_BUTTON_SPACING * (n - 1)) / n
        for j = 1, n do
            visible[j]:SetWidth(btnW)
            visible[j]:ClearAllPoints()
            if j == 1 then
                visible[j]:SetPoint("TOPLEFT", btnKalimdor, "BOTTOMLEFT", 0, -FIND_BUTTON_SPACING)
            else
                visible[j]:SetPoint("TOPLEFT", visible[j - 1], "TOPRIGHT", FIND_BUTTON_SPACING, 0)
            end
        end

        for i = 1, numTypes do
            SetFindButtonActive(findTypeButtons[i], FIND_TYPES[i].id == activeType)
        end
    end

    RefreshFindList = function()
        BuildDisplayList()
        local total = getn(displayList)
        findPanel:SetHeight(FIND_LIST_AREA_TOP + min(total, FIND_MAX_VISIBLE_ROWS) * FIND_ROW_HEIGHT + FIND_PANEL_PADDING + 4)
        FauxScrollFrame_SetOffset(scrollFrame, 0)
        FauxScrollFrame_Update(scrollFrame, total, FIND_MAX_VISIBLE_ROWS, FIND_ROW_HEIGHT)
        DrawRows()
    end

    scrollFrame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(FIND_ROW_HEIGHT, DrawRows)
    end)

    btnKalimdor:SetScript("OnClick", function()
        activeContinent = 1; UpdateFindButtonStates(); RefreshFindList()
    end)
    btnEK:SetScript("OnClick", function()
        activeContinent = 2; UpdateFindButtonStates(); RefreshFindList()
    end)

    UpdateFindButtonStates()

    local origOnHide = WorldMapFrame:GetScript("OnHide")
    WorldMapFrame:SetScript("OnHide", function()
        if origOnHide then origOnHide() end
        findPanel:Hide()
    end)

    return findPanel, UpdateFindButtonStates, RefreshFindList
end

-- ============================================================
-- Find Marker: open the world map to the right continent/zone
-- ============================================================

function MMM.FindMarker(continentID, zoneID, markerName)
    if not WorldMapFrame:IsVisible() then ShowUIPanel(WorldMapFrame) end
    MMM.pendingHighlight = markerName
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    if GetCurrentMapContinent() == continentID and GetCurrentMapZone() == zoneID then
        -- Already on the correct map: force a redraw so pendingHighlight is consumed.
        MMM.ForceRedraw()
        MMM.UpdateMarkers()
    else
        SetMapZoom(continentID, zoneID)
    end
end

-- ============================================================
-- Create and position dropdowns
-- ============================================================

-- pfDrop is safe at module level: pfQuest frames exist by parse time.
-- isShaguMap and isPfUIMapOn read saved variables so are set at VARIABLES_LOADED.
local pfDrop
local isShaguMap
local isPfUIMapOn

local function ResolveCompatState()
    pfDrop      = getglobal("pfQuestMapDropdown")
    local stKey = ShaguTweaks and ShaguTweaks.T and ShaguTweaks.T["WorldMap Window"]
    isShaguMap  = stKey and ShaguTweaks_config and ShaguTweaks_config[stKey] == 1
    isPfUIMapOn = isPfUI and not (pfUI_config and pfUI_config["disabled"] and pfUI_config["disabled"]["map"] == "1")
end

local function PositionDropdowns()
    if not MMMFilterDropdown then return end
    MMMFilterDropdown:ClearAllPoints()
    if pfDrop then
        MMMFilterDropdown:SetPoint("TOPRIGHT", pfDrop, "BOTTOMRIGHT", 0, 0)
    elseif isPfUIMapOn or isShaguMap then
        MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -8, -56)
    else
        MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -183, -79)
    end
    MMMFindDropdown:ClearAllPoints()
    MMMFindDropdown:SetPoint("TOPRIGHT", MMMFilterDropdown, "BOTTOMRIGHT", 0, 0)
end

local function CreateDropdowns()
    local parent         = WorldMapFrame
    local filterDropdown = CreateFrame("Frame", "MMMFilterDropdown", parent, "UIDropDownMenuTemplate")
    local findDropdown   = CreateFrame("Frame", "MMMFindDropdown",   parent, "UIDropDownMenuTemplate")

    local baseLevel = parent:GetFrameLevel() + 10
    filterDropdown:SetFrameStrata(parent:GetFrameStrata())
    filterDropdown:SetFrameLevel(baseLevel)
    findDropdown:SetFrameStrata(parent:GetFrameStrata())
    findDropdown:SetFrameLevel(baseLevel)

    local filterBtn = getglobal("MMMFilterDropdownButton")
    if filterBtn then filterBtn:SetFrameLevel(baseLevel + 2) end
    local findBtn = getglobal("MMMFindDropdownButton")
    if findBtn then findBtn:SetFrameLevel(baseLevel + 2) end

    PositionDropdowns()

    UIDropDownMenu_SetWidth(120, filterDropdown)
    UIDropDownMenu_SetButtonWidth(125, filterDropdown)
    UIDropDownMenu_SetWidth(120, findDropdown)
    UIDropDownMenu_SetButtonWidth(125, findDropdown)

    UIDropDownMenu_SetText("Filter Markers", filterDropdown)
    UIDropDownMenu_SetText("Find Marker",    findDropdown)

    -- Build the find panel and wire the toggle button.
    -- Do NOT call UIDropDownMenu_Initialize on findDropdown — it resets OnClick.
    -- The find button just toggles the panel; no dropdown menu opens.
    local findPanel, updateFindButtonStates, refreshFindList = CreateFindPanel(findDropdown)
    if findBtn then
        findBtn:SetScript("OnClick", function()
            local panel = getglobal("MMMFindPanel")
            if panel then
                if panel:IsVisible() then
                    panel:Hide()
                else
                    local c = GetCurrentMapContinent()
                    updateFindButtonStates((c == 1 or c == 2) and c or nil)
                    panel:Show()
                    refreshFindList()
                end
            end
        end)
    end

    if isPfUI and pfUI and pfUI.api and pfUI.api.SkinDropDown then
        pfUI.api.SkinDropDown(filterDropdown)
        pfUI.api.SkinDropDown(findDropdown)
    end
end

-- ============================================================
-- Slash command
-- ============================================================

SLASH_MMM1 = "/mmm"
SlashCmdList["MMM"] = function(msg)
    if msg and strlower(msg) == "hints" then
        ModernMapMarkersDB.showTransportHints = not ModernMapMarkersDB.showTransportHints
        MMM.RefreshVisibleTooltip()
        return
    end
    if msg and msg ~= "" then return end
    if MMMFilterDropdown then
        if MMMFilterDropdown:IsShown() then MMMFilterDropdown:Hide() else MMMFilterDropdown:Show() end
    end
    if MMMFindDropdown then
        if MMMFindDropdown:IsShown() then
            MMMFindDropdown:Hide()
            local p = getglobal("MMMFindPanel")
            if p then p:Hide() end
        else
            MMMFindDropdown:Show()
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================

local uiFrame = CreateFrame("Frame")
uiFrame:RegisterEvent("VARIABLES_LOADED")
uiFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

uiFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        ResolveCompatState()
        CreateDropdowns()
        if MMMFilterDropdown then UIDropDownMenu_Initialize(MMMFilterDropdown, InitFilterDropdown) end
        this:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResolveCompatState()
        if not MMMFilterDropdown then
            CreateDropdowns()
            if MMMFilterDropdown then UIDropDownMenu_Initialize(MMMFilterDropdown, InitFilterDropdown) end
        end
        -- pfUI map module and ShaguTweaks WorldMap Window both reposition WorldMapFrame
        -- in PLAYER_ENTERING_WORLD. Defer our anchor by one frame so it runs after them.
        if (isShaguMap or isPfUIMapOn) and not pfDrop then
            local deferFrame = CreateFrame("Frame")
            deferFrame:SetScript("OnUpdate", function()
                this:SetScript("OnUpdate", nil)
                PositionDropdowns()
            end)
        end
        this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
