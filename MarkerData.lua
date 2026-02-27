-- ModernMapMarkers - MarkerData.lua
-- Marker data organized by continent ID.
-- Entry format: { zoneID, x, y, name, type, info, atlasID, dest }
--
-- Continent IDs:  1 = Kalimdor  |  2 = Eastern Kingdoms
-- Types: "dungeon", "raid", "worldboss", "zepp", "boat", "tram", "portal"
-- info: level range (e.g. "24-32"), "60", faction ("Alliance"/"Horde"), or nil
-- atlasID: AtlasLoot zone index, or nil if not applicable
-- dest: destination for transport markers. One of:
--   { continent, zone }                    -- single destination (left-click navigates there)
--   { {continent, zone}, {continent, zone} } -- two destinations (left/right-click)
--   nil                                    -- non-transport markers

MMM_MarkerData = {

    -- -------------------------------------------------------------------------
    [1] = { -- Kalimdor
    -- -------------------------------------------------------------------------

        -- Kalimdor Dungeons
        {1, 0.123, 0.128, "Blackfathom Deeps", "dungeon", "24-32", 1},
        {9, 0.648, 0.303, "Dire Maul - East", "dungeon", "55-58", 2},
        {9, 0.771, 0.369, "Dire Maul - East\n|cFF808080(The Hidden Reach)|r", "dungeon", "55-58", 2},
        {9, 0.671, 0.34, "Dire Maul - East\n|cFF808080(Side Entrance)|r", "dungeon", "55-58", 2},
        {9, 0.624, 0.249, "Dire Maul - North", "dungeon", "57-60", 3},
        {9, 0.604, 0.311, "Dire Maul - West", "dungeon", "57-60", 4},
        {5, 0.29, 0.629, "Maraudon", "dungeon", "46-55", 5},
        {12, 0.53, 0.486, "Ragefire Chasm", "dungeon", "13-18", 7},
        {17, 0.508, 0.94, "Razorfen Downs", "dungeon", "37-46", 8},
        {17, 0.423, 0.9, "Razorfen Kraul", "dungeon", "29-38", 9},
        {17, 0.462, 0.357, "Wailing Caverns", "dungeon", "17-24", 12},
        {15, 0.387, 0.2, "Zul'Farrak", "dungeon", "44-54", 13},
        -- Kalimdor Raids
        {7, 0.529, 0.777, "Onyxia's Lair", "raid", "60", 6},
        {13, 0.305, 0.987, "Ruins of Ahn'Qiraj", "raid", "60", 10},
        {13, 0.269, 0.987, "Temple of Ahn'Qiraj", "raid", "60", 11},
        -- Kalimdor World Bosses
        {2, 0.535, 0.816, "Azuregos", "worldboss", "60", nil},
        {1, 0.937, 0.355, "Emerald Dragon - Spawn Point 1 of 4", "worldboss", "60", nil},
        {9, 0.512, 0.108, "Emerald Dragon - Spawn Point 2 of 4", "worldboss", "60", nil},
        -- Kalimdor Transport
        -- Theramore zeppelin tower: Left = Tirisfal Glades, Right = Grom'Gol Base Camp
        {6, 0.512, 0.135, "Zeppelins to Tirisfal Glades & Grom'Gol", "zepp", "Horde", nil, {{2, 21}, {2, 18}}},
        -- Ratchet boat: goes to Booty Bay (EK zone 18 - Stranglethorn Vale)
        {17, 0.636, 0.389, "Boat to Booty Bay", "boat", "Neutral", nil, {2, 18}},
        -- Auberdine boats
        {3, 0.333, 0.399, "Boat to Rut'Theran Village", "boat", "Alliance", nil, {1, 16}},
        {3, 0.325, 0.436, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 25}},
        -- Theramore boats
        {7, 0.718, 0.566, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 25}},
        -- Feathermoon Stronghold boats (Feralas)
        {9, 0.311, 0.395, "Boat to Forgotten Coast", "boat", "Alliance", nil, {1, 9}},
        {9, 0.431, 0.428, "Boat to Sardor Isle", "boat", "Alliance", nil, {1, 9}},
        -- Rut'Theran Village boat to Auberdine
        {16, 0.552, 0.949, "Boat to Auberdine", "boat", "Alliance", nil, {1, 3}},
    },

    -- -------------------------------------------------------------------------
    [2] = { -- Eastern Kingdoms
    -- -------------------------------------------------------------------------

        -- Eastern Kingdoms Dungeons
        {15, 0.387, 0.833, "Blackrock Depths", "dungeon", "52-60", 1},
        {5, 0.328, 0.365, "Blackrock Depths", "dungeon", "52-60", 1},
        {24, 0.423, 0.726, "The Deadmines", "dungeon", "17-24", 3},
        {7, 0.178, 0.392, "Gnomeregan", "dungeon", "29-38", 4},
        {7, 0.216, 0.3, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", 4},
        {5, 0.32, 0.39, "Lower Blackrock Spire", "dungeon", "55-60", 5},
        {15, 0.379, 0.858, "Lower Blackrock Spire", "dungeon", "55-60", 5},
        {21, 0.87, 0.325, "Scarlet Monastery - Armory", "dungeon", "32-42", 8},
        {21, 0.862, 0.295, "Scarlet Monastery - Cathedral", "dungeon", "35-45", 9},
        {21, 0.839, 0.283, "Scarlet Monastery - Graveyard", "dungeon", "26-36", 10},
        {21, 0.85, 0.335, "Scarlet Monastery - Library", "dungeon", "29-39", 11},
        {23, 0.69, 0.729, "Scholomance", "dungeon", "58-60", 12},
        {16, 0.448, 0.678, "Shadowfang Keep", "dungeon", "22-30", 13},
        {17, 0.399, 0.544, "The Stockade", "dungeon", "24-31", 14},
        {9, 0.31, 0.14, "Stratholme", "dungeon", "58-60", 15},
        {9, 0.482, 0.219, "Stratholme\n|cFF808080(Back Gate)|r", "dungeon", "58-60", 15},
        {19, 0.703, 0.55, "The Sunken Temple", "dungeon", "50-60", 16},
        {3, 0.429, 0.13, "Uldaman", "dungeon", "41-51", 17},
        {3, 0.657, 0.438, "Uldaman\n|cFF808080(Back Entrance)|r", "dungeon", "41-51", 17},
        {5, 0.312, 0.365, "Upper Blackrock Spire", "dungeon", "55-60", 18},
        {15, 0.371, 0.833, "Upper Blackrock Spire", "dungeon", "55-60", 18},
        -- Eastern Kingdoms Raids
        {15, 0.332, 0.833, "Blackwing Lair", "raid", "60", 2},
        {5, 0.273, 0.363, "Blackwing Lair", "raid", "60", 2},
        {15, 0.332, 0.86, "Molten Core", "raid", "60", 6},
        {5, 0.273, 0.39, "Molten Core", "raid", "60", 6},
        {9, 0.399, 0.259, "Naxxramas", "raid", "60", 7},
        {18, 0.53, 0.172, "Zul'Gurub", "raid", "60", 19},
        -- Eastern Kingdoms World Bosses
        {8, 0.465, 0.357, "Emerald Dragon - Spawn Point 3 of 4", "worldboss", "60", nil},
        {20, 0.632, 0.217, "Emerald Dragon - Spawn Point 4 of 4", "worldboss", "60", nil},
        {4, 0.36, 0.753, "Lord Kazzak", "worldboss", "60", 7},
        -- Eastern Kingdoms Transport
        -- Deeprun Tram (Stormwind/Gnomeregan districts)
        {17, 0.627, 0.097, "Tram to Ironforge", "tram", "Alliance", nil, {2, 12}},
        {12, 0.762, 0.511, "Tram to Stormwind", "tram", "Alliance", nil, {2, 17}},
        -- Menethil Harbor boats
        {25, 0.051, 0.634, "Boat to Theramore Isle", "boat", "Alliance", nil, {1, 7}},
        {25, 0.046, 0.572, "Boat to Auberdine", "boat", "Alliance", nil, {1, 3}},
        -- Booty Bay boat: goes to Ratchet (Kalimdor zone 17 - The Barrens)
        {18, 0.257, 0.73, "Boat to Ratchet", "boat", "Neutral", nil, {1, 17}},
        -- Undercity zeppelin tower: Left = Durotar, Right = Grom'Gol Base Camp
        {21, 0.616, 0.571, "Zeppelins to Durotar & Grom'Gol", "zepp", "Horde", nil, {{1, 6}, {2, 18}}},
        -- Grom'Gol zeppelin tower: Left = Tirisfal Glades, Right = Durotar
        {18, 0.312, 0.298, "Zeppelins to Tirisfal Glades & Durotar", "zepp", "Horde", nil, {{2, 21}, {1, 6}}},
    },
}
