-- ModernMapMarkers_UI.lua
-- Dropdown controls (Filter Markers, Find Marker), marker label, slash command.
-- Depends on MMM namespace defined in ModernMapMarkers.lua.

local isPfUI  = IsAddOnLoaded and IsAddOnLoaded("pfUI")
local strfind = string.find
local strsub  = string.sub
local tsort   = table.sort
local ipairs  = ipairs

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

    if WorldMapFrameAreaLabel then
        markerLabel:SetPoint("TOP", WorldMapFrameAreaLabel, "TOP", 0, 0)
    else
        markerLabel:SetPoint("TOP", WorldMapDetailFrame, "TOP", 0, -10)
    end

    markerLabel.name = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.name:SetPoint("TOP", markerLabel, "TOP", 0, 0)
    markerLabel.name:SetJustifyH("CENTER")

    if WorldMapFrameAreaLabel then
        local fontName, fontSize, fontFlags = WorldMapFrameAreaLabel:GetFont()
        markerLabel.name:SetFont(fontName, fontSize, fontFlags)
        local r, g, b, a = WorldMapFrameAreaLabel:GetShadowColor()
        local sx, sy = WorldMapFrameAreaLabel:GetShadowOffset()
        markerLabel.name:SetShadowColor(r, g, b, a)
        markerLabel.name:SetShadowOffset(sx, sy)
        local tr, tg, tb = WorldMapFrameAreaLabel:GetTextColor()
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
-- Find Marker dropdown
-- ============================================================

-- These are constant and never change at runtime.
-- [1]=id/key, [2]=display label
local FIND_CONTINENTS = {
    {1, "Kalimdor"},
    {2, "Eastern Kingdoms"},
}
local FIND_TYPES = {
    {"dungeon",   "Dungeons"},
    {"raid",      "Raids"},
    {"worldboss", "World Bosses"},
}

function InitFindDropdown()
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1

    if level == 1 then
        for _, cont in ipairs(FIND_CONTINENTS) do
            local info = {}
            info.text         = cont[2]
            info.value        = cont[1]
            info.hasArrow     = 1
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, 1)
        end

    elseif level == 2 then
        local contID = UIDROPDOWNMENU_MENU_VALUE
        if not contID then return end

        local flatData = MMM.GetFlatData()
        for _, t in ipairs(FIND_TYPES) do
            for _, data in ipairs(flatData) do
                if data.continent == contID and data.type == t[1] then
                    local info = {}
                    info.text         = t[2]
                    info.value        = contID .. ":" .. t[1]
                    info.hasArrow     = 1
                    info.notCheckable = 1
                    UIDropDownMenu_AddButton(info, 2)
                    break
                end
            end
        end

    elseif level == 3 then
        local parentVal = UIDROPDOWNMENU_MENU_VALUE
        local _, _, cIDStr, cType = strfind(parentVal or "", "^(%d+):(%w+)")
        local cID = tonumber(cIDStr)
        if not cID or not cType then return end

        local flatData = MMM.GetFlatData()
        local list = {}
        for _, data in ipairs(flatData) do
            if data.continent == cID and data.type == cType then
                tinsert(list, data)
            end
        end

        tsort(list, function(a, b)
            local _, _, alvl = strfind(a.description or "", "^(%d+)")
            local _, _, blvl = strfind(b.description or "", "^(%d+)")
            local an = tonumber(alvl) or 0
            local bn = tonumber(blvl) or 0
            if an == bn then return (a.name or "") < (b.name or "") end
            return an < bn
        end)

        for _, data in ipairs(list) do
            local d = data
            -- Split "Name\nComment" on the newline.
            local baseName, comment = data.name, nil
            local nl = strfind(data.name, "\n")
            if nl then
                baseName = strsub(data.name, 1, nl - 1)
                comment  = strsub(data.name, nl + 1)
                -- Strip leading color code and trailing |r
                local _, ce = strfind(comment, "^|c%x%x%x%x%x%x%x%x")
                if ce then comment = strsub(comment, ce + 1) end
                local rs = strfind(comment, "|r$")
                if rs then comment = strsub(comment, 1, rs - 1) end
            end

            local lvlText = d.description and (" |cffaaaaaa(Lvl " .. d.description .. ")|r") or ""
            local entryInfo = {}
            entryInfo.text         = baseName .. lvlText
            entryInfo.notCheckable = 1
            entryInfo.func = function()
                MMM.FindMarker(d.continent, d.zone, d.name)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(entryInfo, 3)

            if comment then
                local cinfo = {}
                cinfo.text         = "|cffaaaaaa(" .. comment .. ")|r"
                cinfo.notCheckable = 1
                cinfo.disabled     = 1
                UIDropDownMenu_AddButton(cinfo, 3)
            end
        end
    end
end

-- ============================================================
-- Hook ToggleDropDownMenu to open Find Marker submenus to the left.
-- Scoped only to MMMFindDropdown to avoid affecting other dropdowns.
-- ============================================================

local _origToggleDropDownMenu = ToggleDropDownMenu
function ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset)
    _origToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset)

    local currentLevel = level or 1
    local listName     = "DropDownList" .. currentLevel

    if UIDROPDOWNMENU_OPEN_MENU ~= "MMMFindDropdown" then
        -- Restore default arrow positioning for all other dropdowns.
        for i = 1, 32 do
            local arrow = getglobal(listName .. "Button" .. i .. "ExpandArrow")
            if not arrow then break end
            local btn = getglobal(listName .. "Button" .. i)
            if btn then
                arrow:ClearAllPoints()
                arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
                local tex = arrow:GetNormalTexture()
                if tex then tex:SetTexCoord(0, 1, 0, 1) end
            end
        end
        return
    end

    -- Reposition submenus to open to the left.
    if currentLevel > 1 then
        local currentList = getglobal("DropDownList" .. currentLevel)
        local parentList  = getglobal("DropDownList" .. (currentLevel - 1))
        if currentList and parentList then
            currentList:ClearAllPoints()
            currentList:SetPoint("TOPRIGHT", parentList, "TOPLEFT", 0, 0)
        end
    end

    -- Move expand arrows to the left side, flip them to point left,
    -- and shift button text right so it doesn't clip under the arrow.
    -- Level 3 (marker entries) gets extra left padding to avoid border clipping.
    local textLeft = (currentLevel == 3) and 12 or 22
    for i = 1, 32 do
        local btn = getglobal(listName .. "Button" .. i)
        if not btn then break end
        local arrow = getglobal(listName .. "Button" .. i .. "ExpandArrow")
        local btnText = getglobal(listName .. "Button" .. i .. "NormalText")
        if btnText then
            btnText:ClearAllPoints()
            btnText:SetPoint("LEFT",  btn, "LEFT",  textLeft, 0)
            btnText:SetPoint("RIGHT", btn, "RIGHT", -14, 0)
        end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("LEFT", btn, "LEFT", 5, 0)
            local tex = arrow:GetNormalTexture()
            if tex then tex:SetTexCoord(1, 0, 0, 1) end  -- flip horizontally
        end
    end
end

-- ============================================================
-- Find Marker: open the world map to the right continent/zone
-- ============================================================

function MMM.FindMarker(continentID, zoneID, markerName)
    if not WorldMapFrame:IsVisible() then ShowUIPanel(WorldMapFrame) end
    MMM.pendingHighlight = markerName
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    SetMapZoom(continentID, zoneID)
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
    elseif isPfUIMapOn then
        MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -8, -56)
    elseif isShaguMap then
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
        if MMMFindDropdown:IsShown() then MMMFindDropdown:Hide() else MMMFindDropdown:Show() end
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
        if MMMFindDropdown   then UIDropDownMenu_Initialize(MMMFindDropdown,   InitFindDropdown)   end
        this:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResolveCompatState()
        if not MMMFilterDropdown then
            CreateDropdowns()
            if MMMFilterDropdown then UIDropDownMenu_Initialize(MMMFilterDropdown, InitFilterDropdown) end
            if MMMFindDropdown   then UIDropDownMenu_Initialize(MMMFindDropdown,   InitFindDropdown)   end
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
