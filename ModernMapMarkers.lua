-- ModernMapMarkers.lua
-- Core logic: point index, marker pool, rendering, event handling.
-- UI (dropdowns, labels) is in ModernMapMarkers_UI.lua.
-- Marker data is defined in MarkerData.lua as MMM_MarkerData.

-- ============================================================
-- Constants
-- ============================================================

local HOVER_SIZE_MULTIPLIER   = 1.15
local HOVER_ALPHA             = 0.5
local FIND_SIZE_MULTIPLIER    = 1.4
local FIND_HIGHLIGHT_ALPHA    = 0.9
local FIND_HIGHLIGHT_DURATION = 3.5
local SOUND_CLICK             = "Sound\\Interface\\uCharacterSheetOpen.wav"
local MARKER_SIZE_LARGE       = 32
local MARKER_SIZE_SMALL       = 24
local UPDATE_THROTTLE         = 0.1
local MAX_POOL_SIZE           = 50
local CONTINENT_MULTIPLIER    = 100

local TEXTURES = {
    dungeon   = "Interface\\Addons\\ModernMapMarkers\\Textures\\dungeon.tga",
    raid      = "Interface\\Addons\\ModernMapMarkers\\Textures\\raid.tga",
    worldboss = "Interface\\Addons\\ModernMapMarkers\\Textures\\worldboss.tga",
    zepp      = "Interface\\Addons\\ModernMapMarkers\\Textures\\zepp.tga",
    boat      = "Interface\\Addons\\ModernMapMarkers\\Textures\\boat.tga",
    tram      = "Interface\\Addons\\ModernMapMarkers\\Textures\\tram.tga",
    portal    = "Interface\\Addons\\ModernMapMarkers\\Textures\\portal.tga",
}

local WORLD_BOSS_MAP = {
    ["Azuregos"]    = "AAzuregos",
    ["Lord Kazzak"] = "KKazzak",
}

local ATLAS_OUTDOOR_INDEX = {
    ["Azuregos"]                            = 1,
    ["Emerald Dragon - Spawn Point 1 of 4"] = 2,
    ["Emerald Dragon - Spawn Point 2 of 4"] = 2,
    ["Emerald Dragon - Spawn Point 3 of 4"] = 2,
    ["Emerald Dragon - Spawn Point 4 of 4"] = 2,
    ["Lord Kazzak"]                         = 3,
}

-- [1]=atlasID, [2]=displayName
local NIGHTMARE_DRAGONS = {
    {"DLethon",  "Lethon"},
    {"DEmeriss", "Emeriss"},
    {"DTaerar",  "Taerar"},
    {"DYsondre", "Ysondre"},
}

-- Maps continent index to Atlas type index (Kalimdor=1->Atlas 2, EK=2->Atlas 1)
local ATLAS_CONTINENT_MAP = {2, 1}

-- ============================================================
-- Cached globals
-- ============================================================

local pairs       = pairs
local GetTime     = GetTime
local tinsert     = tinsert
local getn        = getn
local math_random = math.random
local math_sin    = math.sin
local strfind     = string.find
local pcall       = pcall

-- ============================================================
-- State
-- ============================================================

local pointsByMap        = {}
local markerPool         = {}
local markerPoolCount    = 0
local activeMarkers      = {}
local activeMarkersCount = 0
local initialized        = false
local lastContinent      = 0
local lastZone           = 0
local lastUpdateTime     = 0
local worldMapFrameLevel
local frame              = CreateFrame("Frame")
local updateEnabled      = false
local flatDataCache
local pendingOriginC     -- transport click: origin continent for dest highlight
local pendingOriginZ     -- transport click: origin zone for dest highlight

-- ============================================================
-- Global namespace (shared with ModernMapMarkers_UI.lua)
-- ============================================================

MMM = MMM or {}

function MMM.ForceRedraw()
    lastContinent = 0
    lastZone      = 0
end

function MMM.SetUpdateEnabled(state)
    if state and not updateEnabled then
        frame:RegisterEvent("WORLD_MAP_UPDATE")
        updateEnabled = true
    elseif not state and updateEnabled then
        frame:UnregisterEvent("WORLD_MAP_UPDATE")
        updateEnabled = false
    end
end

-- ============================================================
-- Point index
-- ============================================================

local function BuildPointIndex()
    for continentID, points in pairs(MMM_MarkerData) do
        local pointCount = getn(points)
        for i = 1, pointCount do
            local p      = points[i]
            local zoneID = p[1]
            local key    = continentID * CONTINENT_MULTIPLIER + zoneID
            local bucket = pointsByMap[key]
            if not bucket then
                bucket = {}
                pointsByMap[key] = bucket
            end
            -- Internal format: { x, y, name, type, info, atlasID, dest }
            tinsert(bucket, {p[2], p[3], p[4], p[5], p[6], p[7], p[8]})
        end
    end
end

-- Returns a flat list of { continent, zone, name, type, description, atlasID }
-- for the Find Marker dropdown. Transport types are excluded.
-- Built once on first call and cached for the lifetime of the session.
function MMM.GetFlatData()
    if flatDataCache then return flatDataCache end
    local result = {}
    local skip = {boat=true, zepp=true, tram=true, portal=true}
    for continentID, points in pairs(MMM_MarkerData) do
        local pointCount = getn(points)
        for i = 1, pointCount do
            local p = points[i]
            if not skip[p[5]] then
                tinsert(result, {
                    continent   = continentID,
                    zone        = p[1],
                    name        = p[4],
                    type        = p[5],
                    description = p[6],
                    atlasID     = p[7],
                })
            end
        end
    end
    flatDataCache = result
    return result
end

-- ============================================================
-- Marker pool
-- ============================================================

local function GetMarkerFromPool()
    if markerPoolCount > 0 then
        local marker = markerPool[markerPoolCount]
        markerPool[markerPoolCount] = nil
        markerPoolCount = markerPoolCount - 1
        return marker
    end
    local marker = CreateFrame("Button", nil, WorldMapDetailFrame)
    marker.texture   = marker:CreateTexture(nil, "OVERLAY")
    marker.highlight = marker:CreateTexture(nil, "HIGHLIGHT")
    marker.highlight:SetBlendMode("ADD")
    return marker
end

local function ReturnMarkerToPool(marker)
    marker:Hide()
    marker:ClearAllPoints()
    marker:SetScript("OnEnter", nil)
    marker:SetScript("OnLeave", nil)
    marker:SetScript("OnClick", nil)
    marker:SetScript("OnUpdate", nil)
    marker.findTimer       = nil
    marker.markerName      = nil
    marker.markerInfo      = nil
    marker.markerHint      = nil
    marker.markerKind      = nil
    marker.atlasID         = nil
    marker.transportDest   = nil
    marker.isDualDest      = nil
    marker.isEmeraldDragon = nil
    marker.originalSize    = nil
    if markerPoolCount < MAX_POOL_SIZE then
        markerPoolCount = markerPoolCount + 1
        markerPool[markerPoolCount] = marker
    else
        marker:SetParent(nil)
    end
end

-- ============================================================
-- Click handlers
-- ============================================================

local function GetRandomNightmareDragon()
    local d = NIGHTMARE_DRAGONS[math_random(1, 4)]
    return d[1], d[2]
end

local function IsWorldMapFullscreen()
    if BlackoutWorld and BlackoutWorld:IsVisible() then return true end
    return (WorldMapFrame:GetWidth()  / GetScreenWidth()  > 0.9 and
            WorldMapFrame:GetHeight() / GetScreenHeight() > 0.9)
end

local function OnWorldBossClick()
    if not AtlasLoot_ShowBossLoot or not AtlasFrame or not Atlas_Refresh then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000AtlasLoot not loaded.|r")
        return
    end
    local bossName    = this.markerName
    local dataID      = WORLD_BOSS_MAP[bossName]
    local atlasIndex  = ATLAS_OUTDOOR_INDEX[bossName]
    local displayName = bossName
    if this.isEmeraldDragon then
        dataID, displayName = GetRandomNightmareDragon()
        atlasIndex = 2
    end
    if dataID and atlasIndex then
        PlaySoundFile(SOUND_CLICK)
        if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
            HideUIPanel(WorldMapFrame)
        end
        if AtlasFrame and AtlasOptions then
            AtlasOptions.AtlasType = 3
            AtlasOptions.AtlasZone = atlasIndex
            Atlas_Refresh()
            AtlasFrame:SetFrameStrata("FULLSCREEN")
            AtlasFrame:Show()
        end
        local delayFrame = CreateFrame("Frame")
        delayFrame.timer = 0
        delayFrame:SetScript("OnUpdate", function()
            this.timer = this.timer + arg1
            if this.timer >= 0.1 then
                this:SetScript("OnUpdate", nil)
                local ok = pcall(AtlasLoot_ShowBossLoot, dataID, displayName, AtlasFrame)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error loading AtlasLoot data.|r")
                end
            end
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000No Atlas data found for \"" .. bossName .. "\".|r")
    end
end

local function OnAtlasClick()
    if this.atlasID and AtlasFrame and AtlasOptions then
        PlaySoundFile(SOUND_CLICK)
        if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
            HideUIPanel(WorldMapFrame)
        end
        AtlasOptions.AtlasType = ATLAS_CONTINENT_MAP[GetCurrentMapContinent()]
        AtlasOptions.AtlasZone = this.atlasID
        Atlas_Refresh()
        AtlasFrame:SetFrameStrata("FULLSCREEN")
        AtlasFrame:Show()
        if AtlasQuestFrame then AtlasQuestFrame:Show() end
    end
end

local function StartPinHighlight(pin)
    pin.highlight:SetAlpha(0)
    pin.findTimer = 0
    pin:SetScript("OnUpdate", function()
        this.findTimer = this.findTimer + arg1
        local progress = this.findTimer / FIND_HIGHLIGHT_DURATION
        if progress >= 1 then
            this:SetWidth(this.originalSize)
            this:SetHeight(this.originalSize)
            this.highlight:SetAlpha(0)
            this.findTimer = nil
            this:SetScript("OnUpdate", nil)
        else
            local envelope = 1 - progress
            local pulse    = (math_sin(progress * 3.14159 * 8) + 1) * 0.5
            local sz = this.originalSize
                + (this.originalSize * (FIND_SIZE_MULTIPLIER - 1)) * pulse * envelope
            this:SetWidth(sz)
            this:SetHeight(sz)
            this.highlight:SetAlpha(FIND_HIGHLIGHT_ALPHA * pulse * envelope)
        end
    end)
end

local function OnTransportClick()
    local dest = this.transportDest
    if not dest then return end
    local chosen
    if this.isDualDest then
        chosen = (arg1 == "RightButton") and dest[2] or dest[1]
    else
        chosen = dest
    end
    local cc = GetCurrentMapContinent()
    local cz = GetCurrentMapZone()
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    -- Same-zone transport (e.g. Feralas intra-zone boats): no map change needed.
    -- Directly highlight the other transport pin on the current map.
    if chosen[1] == cc and chosen[2] == cz then
        local clicked = this
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin ~= clicked and pin.transportDest then
                local d = pin.transportDest
                local match
                if pin.isDualDest then
                    match = (d[1][1] == cc and d[1][2] == cz)
                         or (d[2][1] == cc and d[2][2] == cz)
                else
                    match = (d[1] == cc and d[2] == cz)
                end
                if match then
                    StartPinHighlight(pin)
                    break
                end
            end
        end
        return
    end
    -- Different-zone transport: zoom to destination and highlight the return marker.
    pendingOriginC = cc
    pendingOriginZ = cz
    SetMapZoom(chosen[1], chosen[2])
    MMM.ForceRedraw()
end

-- ============================================================
-- Pin creation
-- ============================================================

local function CreateMapPin(x, y, size, texture, tooltipText, tooltipInfo, atlasID, kind, dest)
    local pin = GetMarkerFromPool()
    pin:SetWidth(size)
    pin:SetHeight(size)
    pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", x, -y)
    pin.texture:SetAllPoints()
    pin.texture:SetTexture(texture)
    pin:SetFrameLevel(worldMapFrameLevel)
    pin.highlight:SetAllPoints()
    pin.highlight:SetTexture(texture)
    pin.highlight:SetAlpha(0)
    pin.originalSize    = size
    pin.markerName      = tooltipText
    pin.markerInfo      = tooltipInfo
    pin.markerKind      = kind
    pin.atlasID         = atlasID
    pin.transportDest   = dest
    pin.isDualDest      = dest and type(dest[1]) == "table" or false
    pin.isEmeraldDragon = (kind == "worldboss" and tooltipInfo == "60"
                            and not WORLD_BOSS_MAP[tooltipText]) or nil

    -- Build a left/right-click hint for dual-destination transports.
    -- Name format is always "Zeppelins to A & B", so split on " & ".
    if pin.isDualDest then
        local _, _, left, right = strfind(tooltipText, "^.+ to (.+) %& (.+)$")
        pin.markerHint = "|cFFFFD700Left-click:|r " .. (left  or "Destination 1")
                      .. "   |cFFFFD700Right-click:|r " .. (right or "Destination 2")
    end

    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    pin:SetScript("OnEnter", function()
        local hint = ModernMapMarkersDB.showTransportHints and this.markerHint or nil
        MMM.ShowMarkerInfo(this.markerName, this.markerInfo, hint)
        local newSize = this.originalSize * HOVER_SIZE_MULTIPLIER
        this:SetWidth(newSize)
        this:SetHeight(newSize)
        this.highlight:SetAlpha(HOVER_ALPHA)
    end)
    pin:SetScript("OnLeave", function()
        MMM.HideMarkerInfo()
        this:SetWidth(this.originalSize)
        this:SetHeight(this.originalSize)
        this.highlight:SetAlpha(0)
    end)
    pin:SetScript("OnClick", function()
        if this.markerKind == "worldboss" then
            OnWorldBossClick()
        elseif this.markerKind == "boat" or this.markerKind == "zepp"
            or this.markerKind == "tram" or this.markerKind == "portal" then
            OnTransportClick()
        elseif this.atlasID then
            OnAtlasClick()
        end
    end)
    pin:Show()
    return pin
end

-- ============================================================
-- Marker display
-- ============================================================

local function ClearMarkers()
    for i = 1, activeMarkersCount do
        ReturnMarkerToPool(activeMarkers[i])
        activeMarkers[i] = nil
    end
    activeMarkersCount = 0
    MMM.HideMarkerInfo()
end

function MMM.ClearMarkers()
    ClearMarkers()
end

local function UpdateMarkers()
    if not initialized then return end
    if not ModernMapMarkersDB.showMarkers or not WorldMapFrame:IsVisible() then return end

    local currentContinent = GetCurrentMapContinent()
    local currentZone      = GetCurrentMapZone()

    if currentContinent == 0 or currentZone == 0 then
        if activeMarkersCount > 0 then
            ClearMarkers()
            lastContinent = 0
            lastZone      = 0
        end
        return
    end

    if currentContinent == lastContinent and currentZone == lastZone then return end

    local now = GetTime()
    if now - lastUpdateTime < UPDATE_THROTTLE then return end
    lastUpdateTime = now

    lastContinent = currentContinent
    lastZone      = currentZone

    ClearMarkers()

    local mapWidth  = WorldMapDetailFrame:GetWidth()
    local mapHeight = WorldMapDetailFrame:GetHeight()
    if mapWidth == 0 or mapHeight == 0 then return end

    local key = currentContinent * CONTINENT_MULTIPLIER + currentZone
    local relevantPoints = pointsByMap[key]
    if not relevantPoints then return end

    local db               = ModernMapMarkersDB
    local showDungeons     = db.showDungeons
    local showRaids        = db.showRaids
    local showWorldBosses  = db.showWorldBosses
    local showBoats        = db.showBoats
    local showZeppelins    = db.showZeppelins
    local showTrams        = db.showTrams
    local showPortals      = db.showPortals
    local transportFaction = db.transportFaction
    local portalFaction    = db.portalFaction

    local texDungeon   = TEXTURES.dungeon
    local texRaid      = TEXTURES.raid
    local texWorldBoss = TEXTURES.worldboss
    local texZepp      = TEXTURES.zepp
    local texBoat      = TEXTURES.boat
    local texTram      = TEXTURES.tram
    local texPortal    = TEXTURES.portal

    local pointCount = getn(relevantPoints)
    for i = 1, pointCount do
        local data    = relevantPoints[i]
        local kind    = data[4]
        local info    = data[5]
        local shouldDisplay = false
        local texture

        if kind == "dungeon" then
            shouldDisplay = showDungeons
            texture = texDungeon
        elseif kind == "raid" then
            shouldDisplay = showRaids
            texture = texRaid
        elseif kind == "worldboss" then
            shouldDisplay = showWorldBosses
            texture = texWorldBoss
        elseif kind == "boat" then
            shouldDisplay = showBoats
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texBoat
        elseif kind == "zepp" then
            shouldDisplay = showZeppelins
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texZepp
        elseif kind == "tram" then
            shouldDisplay = showTrams
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texTram
        elseif kind == "portal" then
            shouldDisplay = showPortals
            if shouldDisplay and portalFaction ~= "all" then
                shouldDisplay = (info == portalFaction) or (info == "Neutral")
            end
            texture = texPortal
        end

        if shouldDisplay then
            local size = (kind == "boat" or kind == "zepp" or kind == "tram" or kind == "portal")
                and MARKER_SIZE_SMALL or MARKER_SIZE_LARGE
            local pin = CreateMapPin(
                data[1] * mapWidth, data[2] * mapHeight,
                size, texture,
                data[3], info, data[6], kind, data[7])
            activeMarkersCount = activeMarkersCount + 1
            activeMarkers[activeMarkersCount] = pin
        end
    end

    -- If a Find Marker selection is pending, highlight the matching pin now.
    if MMM.pendingHighlight then
        local target = MMM.pendingHighlight
        MMM.pendingHighlight = nil
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin.markerName == target then
                StartPinHighlight(pin)
                break
            end
        end
    end

    -- If a transport was just clicked, highlight the return transport at the destination.
    if pendingOriginC then
        local oc = pendingOriginC
        local oz = pendingOriginZ
        pendingOriginC = nil
        pendingOriginZ = nil
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin.transportDest then
                local d = pin.transportDest
                local match
                if pin.isDualDest then
                    match = (d[1][1] == oc and d[1][2] == oz)
                         or (d[2][1] == oc and d[2][2] == oz)
                else
                    match = (d[1] == oc and d[2] == oz)
                end
                if match then
                    StartPinHighlight(pin)
                    break
                end
            end
        end
    end
end

function MMM.UpdateMarkers()
    UpdateMarkers()
end

function MMM.RefreshVisibleTooltip()
    for i = 1, activeMarkersCount do
        local pin = activeMarkers[i]
        if pin and pin:IsVisible() and MouseIsOver(pin) then
            local hint = ModernMapMarkersDB.showTransportHints and pin.markerHint or nil
            MMM.ShowMarkerInfo(pin.markerName, pin.markerInfo, hint)
            return
        end
    end
end

-- ============================================================
-- Saved variables
-- ============================================================

local DEFAULTS = {
    showMarkers        = true,
    showDungeons       = true,
    showRaids          = true,
    showWorldBosses    = true,
    showBoats          = true,
    showZeppelins      = true,
    showTrams          = true,
    showPortals        = false,
    transportFaction   = "all",
    portalFaction      = "all",
    showTransportHints = true,
}

local function InitializeSavedVariables()
    if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
    local db = ModernMapMarkersDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
end

-- ============================================================
-- Silent Atlas priming
-- ============================================================

-- Silently runs Atlas_Refresh() with Naxxramas selected, then restores the
-- previous AtlasOptions state. No frame is ever shown; this exists solely to
-- force Atlas to complete any deferred internal initialization that it skips
-- until the first real Refresh call. Called once on PLAYER_ENTERING_WORLD via
-- a short OnUpdate delay to guarantee Atlas has finished loading first.
local function PrimeAtlasSilently()
    if not Atlas_Refresh or not AtlasOptions then return end
    local savedType = AtlasOptions.AtlasType
    local savedZone = AtlasOptions.AtlasZone
    AtlasOptions.AtlasType = 1  -- Eastern Kingdoms
    AtlasOptions.AtlasZone = 7  -- Naxxramas
    Atlas_Refresh()
    AtlasOptions.AtlasType = savedType
    AtlasOptions.AtlasZone = savedZone
end

local function ScheduleAtlasPriming()
    local primerFrame = CreateFrame("Frame")
    primerFrame.timer = 0
    primerFrame:SetScript("OnUpdate", function()
        this.timer = this.timer + arg1
        if this.timer >= 0.5 then
            this:SetScript("OnUpdate", nil)
            PrimeAtlasSilently()
        end
    end)
end

-- ============================================================
-- Event handling
-- ============================================================

frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "ModernMapMarkers" then
        BuildPointIndex()
        worldMapFrameLevel = WorldMapDetailFrame:GetFrameLevel() + 3
        this:UnregisterEvent("ADDON_LOADED")

    elseif event == "VARIABLES_LOADED" then
        if not initialized then
            InitializeSavedVariables()
            initialized = true
            if ModernMapMarkersDB.showMarkers then
                frame:RegisterEvent("WORLD_MAP_UPDATE")
                updateEnabled = true
            end
        end
        this:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not initialized then
            InitializeSavedVariables()
            BuildPointIndex()
            worldMapFrameLevel = WorldMapDetailFrame:GetFrameLevel() + 3
            initialized = true
            if ModernMapMarkersDB.showMarkers then
                frame:RegisterEvent("WORLD_MAP_UPDATE")
                updateEnabled = true
            end
        end
        lastContinent = 0
        lastZone      = 0
        ScheduleAtlasPriming()

    elseif event == "WORLD_MAP_UPDATE" then
        if initialized then UpdateMarkers() end
    end
end)
