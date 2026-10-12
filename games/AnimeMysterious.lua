-- ==============================================================================
-- 0. GAME & CLIENT LOAD VERIFICATION (Auto-Execute Safety Gate)
-- ==============================================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Engine & Render Pipeline Stabilization Delay for Auto-Execute
task.wait(1.5)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer or not LocalPlayer.Name or LocalPlayer.Name == "" or (LocalPlayer.UserId or 0) <= 0 then
    repeat
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    until LocalPlayer and LocalPlayer.UserId and LocalPlayer.UserId > 0 and LocalPlayer.Name ~= ""
end

-- Wait for PlayerGui
if not LocalPlayer:FindFirstChild("PlayerGui") then
    LocalPlayer:WaitForChild("PlayerGui", 25)
end

-- Wait for Character & HumanoidRootPart
if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    pcall(function()
        if not LocalPlayer.Character then
            LocalPlayer.CharacterAdded:Wait()
        end
        if LocalPlayer.Character then
            LocalPlayer.Character:WaitForChild("HumanoidRootPart", 15)
        end
    end)
end

-- Viewport / Camera stabilization (Prevents rendering pipeline crash on early UI creation)
pcall(function()
    local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 10)
    if camera then
        local t0 = os.clock()
        while (camera.ViewportSize.X < 200 or camera.ViewportSize.Y < 200) and (os.clock() - t0 < 5) do
            task.wait(0.2)
        end
    end
end)

--// Storage & Folder Initialization
local function EnsureFolders()
    if isfolder and not isfolder("STRIX HUB") then pcall(makefolder, "STRIX HUB") end
    if isfolder and not isfolder("STRIX HUB/Anime Mysterious") then pcall(makefolder, "STRIX HUB/Anime Mysterious") end
end
EnsureFolders()

--// Safe Instance Cleanup (Neutralizes Unload recursion & dead C++ instance crashes)
if getgenv().STRIX_HUB_CLEANUP then
    pcall(getgenv().STRIX_HUB_CLEANUP)
    task.wait(0.2)
end

pcall(function()
    local searchLocations = {
        (gethui and gethui()) or game:GetService("CoreGui"),
        game:GetService("CoreGui"):FindFirstChild("RobloxGui"),
        game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    }
    for _, loc in ipairs(searchLocations) do
        if loc then
            for _, child in ipairs(loc:GetChildren()) do
                if child:IsA("ScreenGui") and (child:FindFirstChild("Base") or child.Name == "STRIX_MOBILE_TOGGLE") then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end)

local isScriptRunning = true
getgenv().STRIX_HUB_CLEANUP = function()
    isScriptRunning = false
    if getgenv().STRIX_MOBILE_GUI then
        pcall(function()
            if getgenv().STRIX_MOBILE_GUI.Parent then
                getgenv().STRIX_MOBILE_GUI:Destroy()
            end
        end)
        getgenv().STRIX_MOBILE_GUI = nil
    end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Place Identification
local LOBBY_PLACE_ID = 117949143041402
local LOBBY_ALT_PLACE_ID = 110388679506690
local GAMEPLAY_PLACE_ID = 107610426295102
local isLobby = (game.PlaceId == LOBBY_PLACE_ID or game.PlaceId == LOBBY_ALT_PLACE_ID)
local isBattlePlace = not isLobby

-- Wait for Remotes and Network
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 25) or ReplicatedStorage:FindFirstChild("Remotes")
local RequestJoinLobby = Remotes and Remotes:FindFirstChild("RequestJoinLobby")
local UpdateLobbySettings = Remotes and Remotes:FindFirstChild("UpdateLobbySettings")
local TeleportRequest = Remotes and Remotes:FindFirstChild("TeleportRequest")
local LeaveLobbyEvent = Remotes and Remotes:FindFirstChild("LeaveLobbyEvent")
local GetChallengeData = Remotes and Remotes:FindFirstChild("GetChallengeData")
local BuyItem = Remotes and Remotes:FindFirstChild("BuyItem")
local SummonRequest = Remotes and Remotes:FindFirstChild("SummonRequest")
local GetBannerInfo = Remotes and Remotes:FindFirstChild("GetBannerInfo")

--// Gameplay Remotes & Events
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 25) or ReplicatedStorage:FindFirstChild("GameEvents")
local LeaveGameRequest = GameEvents and GameEvents:FindFirstChild("LeaveGameRequest")
local EndGameEvent = GameEvents and GameEvents:FindFirstChild("EndGameEvent")

--// Game Modules (Wait for replication so MapConfig is guaranteed loaded in BOTH Lobby & Battle)
local Modules = ReplicatedStorage:WaitForChild("Modules", 25) or ReplicatedStorage:FindFirstChild("Modules")
local PlayingModule = Modules and (Modules:FindFirstChild("PlayingModule") or Modules:WaitForChild("PlayingModule", 2))
local PlayModule = nil
local StageUnlockHelper = nil
local MapConfig = {}

local function FindAndLoadMapConfig()
    local mc = (PlayingModule and PlayingModule:FindFirstChild("MapConfig"))
        or (Modules and Modules:FindFirstChild("Gameplay") and Modules.Gameplay:FindFirstChild("MapConfig"))
        or (Modules and Modules:FindFirstChild("MapConfig", true))
    if mc then
        local okM, m = pcall(require, mc)
        if okM and type(m) == "table" and next(m) ~= nil then
            return m
        end
    end
    return nil
end

MapConfig = FindAndLoadMapConfig() or {}

if PlayingModule then
    local okP, p = pcall(require, PlayingModule:WaitForChild("PlayModule", 5))
    if okP then PlayModule = p end
    local okS, s = pcall(require, PlayingModule:WaitForChild("StageUnlockHelper", 5))
    if okS then StageUnlockHelper = s end
end
if not StageUnlockHelper and PlayingModule and PlayingModule:FindFirstChild("StageUnlockHelper") then
    local okS, s = pcall(require, PlayingModule.StageUnlockHelper)
    if okS then StageUnlockHelper = s end
end

-- MapConfig verification loop for slow network / Auto-Execute
local mapWaitDeadline = os.clock() + 8
while (not MapConfig or next(MapConfig) == nil) and (os.clock() < mapWaitDeadline) do
    task.wait(0.5)
    local m = FindAndLoadMapConfig()
    if m then
        MapConfig = m
        break
    end
end

local SummonConfig = Modules and Modules:FindFirstChild("SummonConfig") and select(2, pcall(require, Modules.SummonConfig)) or {}
local ShopModule = Modules and (isLobby and (Modules:WaitForChild("ShopModule", 5) or Modules:FindFirstChild("ShopModule")) or Modules:FindFirstChild("ShopModule"))
local ShopConfig = (ShopModule and (ShopModule:FindFirstChild("ShopConfig") or ShopModule:WaitForChild("ShopConfig", 2)) and select(2, pcall(require, ShopModule.ShopConfig))) or {}
local ItemDatabase = Modules and (Modules:FindFirstChild("ItemDatabase") or Modules:WaitForChild("ItemDatabase", 5)) and select(2, pcall(require, Modules.ItemDatabase)) or nil
local GemsShopModule = Modules and (isLobby and (Modules:WaitForChild("GemsShopModule", 5) or Modules:FindFirstChild("GemsShopModule")) or Modules:FindFirstChild("GemsShopModule")) and select(2, pcall(require, Modules.GemsShopModule)) or nil
local SettingModule = Modules and (Modules:FindFirstChild("SettingModule") or Modules:WaitForChild("SettingModule", 5)) and select(2, pcall(require, Modules.SettingModule)) or nil


--// Load & Patch Maclib Library (Cached locally to prevent HTTP network freezes & GitHub rate limits on Auto-Execute)
local MacLib = nil
local MacLibCacheFile = "STRIX HUB/maclib_cache.lua"
local rawMaclibSource = nil

-- Fast load from disk cache (Bypasses HTTP overhead and rate limits during Auto-Execute)
if isfile and isfile(MacLibCacheFile) then
    local ok, cached = pcall(readfile, MacLibCacheFile)
    if ok and cached and #cached > 1000 then
        rawMaclibSource = cached
    end
end

-- Fallback to remote download if cache is missing or corrupt
if not rawMaclibSource then
    local maclibSources = {
        "https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt",
        "https://raw.githubusercontent.com/biggaboy212/Public-Resources/main/MacLib/maclib.lua"
    }
    for _, url in ipairs(maclibSources) do
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and res and #res > 1000 then
            rawMaclibSource = res
            if writefile then
                pcall(writefile, MacLibCacheFile, res)
            end
            break
        end
    end
end

if not rawMaclibSource then
    warn("[STRIX HUB] Failed to download or load Maclib UI Library source!")
    return
end

-- Patch 1: Prevent Toggle(option, false) from clearing the active single-select value
if rawMaclibSource:find("Selected = {}\r\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\r\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\r\n\t\t\t\t\t\t\tend", 1)
elseif rawMaclibSource:find("Selected = {}\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\n\t\t\t\t\t\t\tend", 1)
end

-- Patch 2: Allow Dropdown Settings.Default to match string option values, numbers, or tables
local patDefault = "isSelected = %(Settings%.Default == i%) and true or false"
local replDefault = "isSelected = (Settings.Default == i or Settings.Default == v or (type(Settings.Default) == 'table' and table.find(Settings.Default, v) ~= nil)) and true or false"
rawMaclibSource = rawMaclibSource:gsub(patDefault, replDefault)

-- Patch 2.5: Allow Dropdown UpdateSelection to accept string values directly (not just tables or numbers)
local patUpdateSel = "function DropdownFunctions:UpdateSelection%(newSelection%)"
local replUpdateSel = "function DropdownFunctions:UpdateSelection(newSelection)\n\t\t\t\t\t\tif type(newSelection) == 'string' then newSelection = { newSelection } end"
rawMaclibSource = rawMaclibSource:gsub(patUpdateSel, replUpdateSel)

-- Patch 3: Responsive Content sizing (prevent double-scale gap between sidebar and content)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, %(base%.AbsoluteSize%.X %- sidebar%.AbsoluteSize%.X%), 1, 0%)",
    "content.Size = UDim2.new(1 - sidebar.Size.X.Scale, -sidebar.Size.X.Offset, 1, 0)"
)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, base%.AbsoluteSize%.X %- newSidebarWidth, 1, 0%)",
    "content.Size = UDim2.new(1, -newSidebarWidth, 1, 0)"
)

-- Patch 4: Clear & Distinct Section Dividers (Harmonious Muted Frost White Line)
local patDivLine = "line%.BackgroundColor3 = Color3%.fromRGB%(255, 255, 255%)\r?\n\t*line%.BackgroundTransparency = 0%.9\r?\n\t*line%.BorderColor3 = Color3%.fromRGB%(0, 0, 0%)\r?\n\t*line%.BorderSizePixel = 0\r?\n\t*line%.Size = UDim2%.new%(1, 0, 0, 1%)"
local replDivLine = "line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)\n\t\t\t\t\tline.BackgroundTransparency = 0.68\n\t\t\t\t\tline.BorderSizePixel = 0\n\t\t\t\t\tline.Size = UDim2.new(1, 0, 0, 1)"
rawMaclibSource = rawMaclibSource:gsub(patDivLine, replDivLine)
rawMaclibSource = rawMaclibSource:gsub("uIPadding%.PaddingBottom = UDim%.new%(0, 8%)\r?\n\t*uIPadding%.PaddingTop = UDim%.new%(0, 8%)", "uIPadding.PaddingBottom = UDim.new(0, 10)\n\t\t\t\t\tuIPadding.PaddingTop = UDim.new(0, 10)")

MacLib = loadstring(rawMaclibSource)()
_G.MacLib = MacLib

--// Auto-Update Game Data Tables
local GameData = {
    Story = { Maps = {}, DisplayToId = {}, Stages = {} },
    Mysterious = { Maps = {}, DisplayToId = {}, Stages = {} },
    Raids = { Maps = {}, DisplayToId = {}, Stages = {} },
    Boss = { Maps = {}, DisplayToId = {}, Stages = {} },
    Difficulties = { "Normal", "Hard", "Nightmare" },
    Banners = { "Standard", "Fate" },
    GemsItems = {},
    GemsItemMap = {},
    GemsIdToLabel = {},
    GoldItems = {},
    GoldItemMap = {},
    GoldIdToLabel = {}
}

-- Populate Maps dynamically from MapConfig
for _, mapInfo in pairs(MapConfig) do
    if type(mapInfo) == "table" and mapInfo.MapToCreate and mapInfo.Name then
        local id = mapInfo.MapToCreate
        local mode = mapInfo.Mode or ""
        local isTestMap = (id == "TestingMap") or (mapInfo.Name == "Studio Map") or (string.sub(string.lower(id), 1, 4) == "test")

        if not isTestMap then
            local displayName = mapInfo.Name
            local legacyName = mapInfo.Name .. " [" .. id .. "]"
            local totalStages = tonumber(mapInfo.TotalStages) or 1
            
            local stagesList = {}
            for s = 1, totalStages do
                table.insert(stagesList, tostring(s))
            end

        if mode == "Story" then
            table.insert(GameData.Story.Maps, displayName)
            GameData.Story.DisplayToId[displayName] = id
            GameData.Story.DisplayToId[legacyName] = id
            GameData.Story.DisplayToId[id] = id
            GameData.Story.Stages[id] = stagesList
        elseif mode == "Mysterios" or mode == "Mysterious" then
            table.insert(GameData.Mysterious.Maps, displayName)
            GameData.Mysterious.DisplayToId[displayName] = id
            GameData.Mysterious.DisplayToId[legacyName] = id
            GameData.Mysterious.DisplayToId[id] = id
            GameData.Mysterious.Stages[id] = stagesList
        elseif mode == "Raids" then
            table.insert(GameData.Raids.Maps, displayName)
            GameData.Raids.DisplayToId[displayName] = id
            GameData.Raids.DisplayToId[legacyName] = id
            GameData.Raids.DisplayToId[id] = id
            GameData.Raids.Stages[id] = stagesList
        elseif mode == "Event" or mode == "Boss" or string.find(id, "Event") then
            table.insert(GameData.Boss.Maps, displayName)
            GameData.Boss.DisplayToId[displayName] = id
            GameData.Boss.DisplayToId[legacyName] = id
            GameData.Boss.DisplayToId[id] = id
            GameData.Boss.Stages[id] = stagesList
        end
    end
end
end

-- Populate Shop items dynamically from ShopConfig & ItemDatabase (with built-in fallback for Battle place)
local defaultGemsShop = {
    { ID = "Fruit_1", Price = 10, MaxStock = 10 },
    { ID = "Fruit_2", Price = 25, MaxStock = 5 },
    { ID = "RareShard", Price = 35, MaxStock = 10 },
    { ID = "EpicShard", Price = 75, MaxStock = 7 },
    { ID = "LegendShard", Price = 180, MaxStock = 5 },
    { ID = "MythicShard", Price = 350, MaxStock = 3 },
    { ID = "MysteriousShard", Price = 10000, MaxStock = 1 },
    { ID = "Trait", Price = 200, MaxStock = 3 },
    { ID = "StatRerollAll", Price = 35, MaxStock = 10 },
    { ID = "StatReroll", Price = 80, MaxStock = 10 },
    { ID = "MysteryCapsule", Price = 750, MaxStock = 50 },
}

local defaultGoldShop = {
    { ID = "Fruit_1", Price = 1000, MaxStock = 10 },
    { ID = "Fruit_2", Price = 2500, MaxStock = 5 },
    { ID = "RareShard", Price = 3500, MaxStock = 10 },
    { ID = "EpicShard", Price = 7500, MaxStock = 7 },
    { ID = "LegendShard", Price = 18000, MaxStock = 5 },
    { ID = "MythicShard", Price = 35000, MaxStock = 3 },
    { ID = "MysteriousShard", Price = 1000000, MaxStock = 1 },
    { ID = "Trait", Price = 20000, MaxStock = 3 },
    { ID = "StatRerollAll", Price = 3500, MaxStock = 10 },
    { ID = "StatReroll", Price = 8000, MaxStock = 10 },
    { ID = "MysteryCapsule", Price = 75000, MaxStock = 50 },
}

local gemsItemsToProcess = (ShopConfig and ShopConfig.GemsShopItems and #ShopConfig.GemsShopItems > 0) and ShopConfig.GemsShopItems or defaultGemsShop
local goldItemsToProcess = (ShopConfig and ShopConfig.GoldShopItems and #ShopConfig.GoldShopItems > 0) and ShopConfig.GoldShopItems or defaultGoldShop

local function ResolveItemName(id)
    if ItemDatabase and ItemDatabase.GetItem then
        local ok, db = pcall(function() return ItemDatabase.GetItem(id) end)
        if ok and db and db.Name then return db.Name end
    end
    local fallbackNames = {
        Fruit_1 = "Namekian Fruit",
        Fruit_2 = "Mist Fish",
        RareShard = "Rare Shard",
        EpicShard = "Epic Shard",
        LegendShard = "Legend Shard",
        MythicShard = "Mythic Shard",
        MysteriousShard = "Mysterious Shard",
        Trait = "Trait",
        StatRerollAll = "StatsRerollAll",
        StatReroll = "StatsReroll",
        MysteryCapsule = "Release Capsule"
    }
    return fallbackNames[id] or id
end

for _, item in ipairs(gemsItemsToProcess) do
    local name = ResolveItemName(item.ID)
    local label = name .. " (" .. item.Price .. " Gems)"
    table.insert(GameData.GemsItems, label)
    GameData.GemsItemMap[label] = {
        ID = item.ID,
        Name = name,
        Price = item.Price,
        MaxStock = item.MaxStock or 10
    }
    GameData.GemsIdToLabel[item.ID] = label
end

for _, item in ipairs(goldItemsToProcess) do
    local name = ResolveItemName(item.ID)
    local label = name .. " (" .. item.Price .. " Coins)"
    table.insert(GameData.GoldItems, label)
    GameData.GoldItemMap[label] = {
        ID = item.ID,
        Name = name,
        Price = item.Price,
        MaxStock = item.MaxStock or 10
    }
    GameData.GoldIdToLabel[item.ID] = label
end

--// In-Game Gameplay Settings Map (PlayerGui.Settings Sync)
local GameSettingsMap = {
    { StateKey = "AutoPlay", OptFlag = "Toggle_AutoPlay", GuiName = "Auto Autoplay", SettingKey = "Autoplay", Label = "Auto Play" },
    { StateKey = "AutoNext", OptFlag = "Toggle_AutoNext", GuiName = "Auto Next", SettingKey = "AutoNext", Label = "Auto Next" },
    { StateKey = "AutoReplay", OptFlag = "Toggle_AutoReplay", GuiName = "Auto Retry", SettingKey = "AutoRetry", Label = "Auto Replay" },
    { StateKey = "AutoVoteStart", OptFlag = "Toggle_AutoVoteStart", GuiName = "Auto Vote Start", SettingKey = "AutoVoteStart", Label = "Auto Vote Start" },
    { StateKey = "AutoWaveSkipping", OptFlag = "Toggle_AutoWaveSkipping", GuiName = "Auto Skip Wave", SettingKey = "AutoSkipWave", Label = "Auto Wave Skipping" },
    { StateKey = "AutoMaxGameSpeed", OptFlag = "Toggle_AutoMaxGameSpeed", GuiName = "Auto Max Speed", SettingKey = "AutoMaxGameSpeed", Label = "Auto Max Game Speed" },
    { StateKey = "AutoUltimate", OptFlag = "Toggle_AutoUltimate", GuiName = "Auto Ultimate", SettingKey = "AutoUltimate", Label = "Auto Ultimate" }
}

--// State Table
local State = {
    ActiveAutoCreate = "None", -- "None", "Story", "Mysterious", "Raids", "Boss"
    
    StoryMap = GameData.Story.Maps[1] or "",
    StoryStage = "1",
    StoryDiff = "Normal",
    
    MysteriousMap = GameData.Mysterious.Maps[1] or "",
    MysteriousStage = "1",
    MysteriousDiff = "Normal",
    
    RaidsMap = GameData.Raids.Maps[1] or "",
    RaidsStage = "1",
    RaidsDiff = "Normal",
    
    BossMap = GameData.Boss.Maps[1] or "",
    BossStage = "1",
    BossDiff = "Normal",
    
    AutoStart = false,
    
    AutoChallenges = false,
    AutoLeaveChallenge = false,
    AutoLeaveOnChallengeReset = false,
    TargetChallenges = {
        Weekly = true,
        Daily = true,
        Regular = true
    },
    
    AutoSummon = false,
    SummonBanner = "Standard",
    SummonAmount = "10x",
    
    AutoBuyGems = false,
    SelectedGemsItems = {},
    
    AutoBuyGold = false,
    SelectedGoldItems = {},
    
    Keybind = Enum.KeyCode.RightControl,
    UISize = { Width = 868, Height = 650 },
    AcrylicBlur = true,
    ShowUserInfo = true,
    MobileToggle = true,

    -- Gameplay Settings (In-Game Synced)
    AutoPlay = true,
    AutoNext = true,
    AutoReplay = true,
    AutoVoteStart = true,
    AutoWaveSkipping = true,
    AutoMaxGameSpeed = true,
    AutoUltimate = true,
    AutoDefendMoneyUnits = true,

    -- Event Automation
    AutoSolveFateSword = true
}

--// Config Paths (Save at workspace\STRIX HUB\<MapName>\<Username>.json)
local ConfigFolder = "STRIX HUB/Anime Mysterious"
local ConfigFile = ConfigFolder .. "/" .. tostring(LocalPlayer.Name) .. ".json"

local function EnsureFolders()
    if not isfolder("STRIX HUB") then pcall(makefolder, "STRIX HUB") end
    if not isfolder("STRIX HUB/Anime Mysterious") then pcall(makefolder, "STRIX HUB/Anime Mysterious") end
end

local function ResolveBind(bindName)
    if not bindName or bindName == "Unknown" or bindName == "None" then return nil end
    local okKey, k = pcall(function() return Enum.KeyCode[bindName] end)
    if okKey and k and k ~= Enum.KeyCode.Unknown then return k end
    local okInput, u = pcall(function() return Enum.UserInputType[bindName] end)
    if okInput and u and u ~= Enum.UserInputType.None then return u end
    return nil
end

-- Pre-load early settings into State (Keybind, UISize, UIScale, Blur, UserInfo, MobileToggle, Maps, etc.) before Window creation
EnsureFolders()
local earlyTarget = ConfigFile
if not isfile(earlyTarget) then
    local oldTarget = ConfigFolder .. "/" .. tostring(LocalPlayer.UserId) .. ".json"
    if isfile(oldTarget) then earlyTarget = oldTarget end
end
if isfile(earlyTarget) then
    local ok, earlyData = pcall(function() return HttpService:JSONDecode(readfile(earlyTarget)) end)
    if ok and type(earlyData) == "table" then
        if earlyData.Keybind then
            local k = ResolveBind(earlyData.Keybind)
            if k then
                State.Keybind = k
            end
        end
        if earlyData.UISize and earlyData.UISize.Width and earlyData.UISize.Height then
            State.UISize = earlyData.UISize
        end
        if earlyData.AcrylicBlur ~= nil then
            State.AcrylicBlur = (earlyData.AcrylicBlur == true)
        end
        if earlyData.ShowUserInfo ~= nil then
            State.ShowUserInfo = (earlyData.ShowUserInfo ~= false)
        end
        if earlyData.MobileToggle ~= nil then
            State.MobileToggle = (earlyData.MobileToggle ~= false)
        end
        for _, sInfo in ipairs(GameSettingsMap) do
            if earlyData[sInfo.StateKey] ~= nil then
                State[sInfo.StateKey] = earlyData[sInfo.StateKey]
            end
        end

        -- Pre-load Auto Create & Maps
        if earlyData.ActiveAutoCreate ~= nil then State.ActiveAutoCreate = earlyData.ActiveAutoCreate end
        if earlyData.StoryMap and earlyData.StoryMap ~= "" then State.StoryMap = earlyData.StoryMap end
        if earlyData.StoryStage and earlyData.StoryStage ~= "" then State.StoryStage = earlyData.StoryStage end
        if earlyData.StoryDiff and earlyData.StoryDiff ~= "" then State.StoryDiff = earlyData.StoryDiff end
        if earlyData.MysteriousMap and earlyData.MysteriousMap ~= "" then State.MysteriousMap = earlyData.MysteriousMap end
        if earlyData.MysteriousStage and earlyData.MysteriousStage ~= "" then State.MysteriousStage = earlyData.MysteriousStage end
        if earlyData.MysteriousDiff and earlyData.MysteriousDiff ~= "" then State.MysteriousDiff = earlyData.MysteriousDiff end
        if earlyData.RaidsMap and earlyData.RaidsMap ~= "" then State.RaidsMap = earlyData.RaidsMap end
        if earlyData.RaidsStage and earlyData.RaidsStage ~= "" then State.RaidsStage = earlyData.RaidsStage end
        if earlyData.RaidsDiff and earlyData.RaidsDiff ~= "" then State.RaidsDiff = earlyData.RaidsDiff end
        if earlyData.BossMap and earlyData.BossMap ~= "" then State.BossMap = earlyData.BossMap end
        if earlyData.BossStage and earlyData.BossStage ~= "" then State.BossStage = earlyData.BossStage end
        if earlyData.BossDiff and earlyData.BossDiff ~= "" then State.BossDiff = earlyData.BossDiff end
        if earlyData.AutoStart ~= nil then State.AutoStart = (earlyData.AutoStart == true) end

        -- Pre-load Challenges
        if earlyData.AutoChallenges ~= nil then State.AutoChallenges = (earlyData.AutoChallenges == true) end
        if earlyData.AutoLeaveChallenge ~= nil then State.AutoLeaveChallenge = (earlyData.AutoLeaveChallenge == true) end
        if earlyData.AutoLeaveOnChallengeReset ~= nil then State.AutoLeaveOnChallengeReset = (earlyData.AutoLeaveOnChallengeReset == true) end
        if type(earlyData.TargetChallenges) == "table" then State.TargetChallenges = earlyData.TargetChallenges end

        -- Pre-load Summon
        if earlyData.AutoSummon ~= nil then State.AutoSummon = (earlyData.AutoSummon == true) end
        if earlyData.SummonBanner then State.SummonBanner = earlyData.SummonBanner end
        if earlyData.SummonAmount then State.SummonAmount = earlyData.SummonAmount end

        -- Pre-load Shop
        if earlyData.AutoBuyGems ~= nil then State.AutoBuyGems = (earlyData.AutoBuyGems == true) end
        if type(earlyData.SelectedGemsItems) == "table" then State.SelectedGemsItems = earlyData.SelectedGemsItems end
        if earlyData.AutoBuyGold ~= nil then State.AutoBuyGold = (earlyData.AutoBuyGold == true) end
        if type(earlyData.SelectedGoldItems) == "table" then State.SelectedGoldItems = earlyData.SelectedGoldItems end
    end
end

local function SaveConfig()
    if not isScriptRunning or isLoadingConfig then return end
    EnsureFolders()

    local diskData = {}
    if isfile(ConfigFile) then
        local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(ConfigFile)) end)
        if ok and type(dec) == "table" then
            diskData = dec
        end
    end

    local function SafePick(stateVal, diskVal, isTable)
        if isTable then
            if type(stateVal) == "table" and #stateVal > 0 then
                return stateVal
            elseif isBattlePlace and type(diskVal) == "table" and #diskVal > 0 then
                return diskVal
            end
            return stateVal or {}
        else
            if stateVal ~= nil and stateVal ~= "" and stateVal ~= "None" then
                return stateVal
            elseif isBattlePlace and diskVal ~= nil and diskVal ~= "" and diskVal ~= "None" then
                return diskVal
            elseif diskVal ~= nil and diskVal ~= "" and diskVal ~= "None" and (stateVal == nil or stateVal == "") then
                return diskVal
            end
            return stateVal
        end
    end

    local payload = {
        ActiveAutoCreate = SafePick(State.ActiveAutoCreate, diskData.ActiveAutoCreate, false),
        StoryMap = SafePick(State.StoryMap, diskData.StoryMap, false),
        StoryStage = SafePick(State.StoryStage, diskData.StoryStage, false),
        StoryDiff = SafePick(State.StoryDiff, diskData.StoryDiff, false),
        MysteriousMap = SafePick(State.MysteriousMap, diskData.MysteriousMap, false),
        MysteriousStage = SafePick(State.MysteriousStage, diskData.MysteriousStage, false),
        MysteriousDiff = SafePick(State.MysteriousDiff, diskData.MysteriousDiff, false),
        RaidsMap = SafePick(State.RaidsMap, diskData.RaidsMap, false),
        RaidsStage = SafePick(State.RaidsStage, diskData.RaidsStage, false),
        RaidsDiff = SafePick(State.RaidsDiff, diskData.RaidsDiff, false),
        BossMap = SafePick(State.BossMap, diskData.BossMap, false),
        BossStage = SafePick(State.BossStage, diskData.BossStage, false),
        BossDiff = SafePick(State.BossDiff, diskData.BossDiff, false),
        AutoStart = (State.AutoStart ~= nil) and State.AutoStart or (diskData.AutoStart == true),
        AutoChallenges = (State.AutoChallenges ~= nil) and State.AutoChallenges or (diskData.AutoChallenges == true),
        AutoLeaveChallenge = (State.AutoLeaveChallenge ~= nil) and State.AutoLeaveChallenge or (diskData.AutoLeaveChallenge == true),
        AutoLeaveOnChallengeReset = (State.AutoLeaveOnChallengeReset ~= nil) and State.AutoLeaveOnChallengeReset or (diskData.AutoLeaveOnChallengeReset == true),
        TargetChallenges = (State.TargetChallenges and next(State.TargetChallenges)) and State.TargetChallenges or diskData.TargetChallenges or { Weekly = true, Daily = true, Regular = true },
        AutoSummon = (State.AutoSummon ~= nil) and State.AutoSummon or (diskData.AutoSummon == true),
        SummonBanner = SafePick(State.SummonBanner, diskData.SummonBanner, false),
        SummonAmount = SafePick(State.SummonAmount, diskData.SummonAmount, false),
        AutoBuyGems = (State.AutoBuyGems ~= nil) and State.AutoBuyGems or (diskData.AutoBuyGems == true),
        SelectedGemsItems = SafePick(State.SelectedGemsItems, diskData.SelectedGemsItems, true),
        AutoBuyGold = (State.AutoBuyGold ~= nil) and State.AutoBuyGold or (diskData.AutoBuyGold == true),
        SelectedGoldItems = SafePick(State.SelectedGoldItems, diskData.SelectedGoldItems, true),
        Keybind = typeof(State.Keybind) == "EnumItem" and State.Keybind.Name or (type(State.Keybind) == "string" and State.Keybind or (diskData.Keybind or "RightControl")),
        UISize = State.UISize or diskData.UISize or { Width = 868, Height = 650 },
        AcrylicBlur = (State.AcrylicBlur ~= nil) and State.AcrylicBlur or (diskData.AcrylicBlur ~= false),
        ShowUserInfo = (State.ShowUserInfo ~= nil) and State.ShowUserInfo or (diskData.ShowUserInfo ~= false),
        MobileToggle = (State.MobileToggle ~= nil) and State.MobileToggle or (diskData.MobileToggle ~= false),
        AutoPlay = (State.AutoPlay ~= nil) and State.AutoPlay or (diskData.AutoPlay ~= false),
        AutoNext = (State.AutoNext ~= nil) and State.AutoNext or (diskData.AutoNext ~= false),
        AutoReplay = (State.AutoReplay ~= nil) and State.AutoReplay or (diskData.AutoReplay ~= false),
        AutoVoteStart = (State.AutoVoteStart ~= nil) and State.AutoVoteStart or (diskData.AutoVoteStart ~= false),
        AutoWaveSkipping = (State.AutoWaveSkipping ~= nil) and State.AutoWaveSkipping or (diskData.AutoWaveSkipping ~= false),
        AutoMaxGameSpeed = (State.AutoMaxGameSpeed ~= nil) and State.AutoMaxGameSpeed or (diskData.AutoMaxGameSpeed ~= false),
        AutoUltimate = (State.AutoUltimate ~= nil) and State.AutoUltimate or (diskData.AutoUltimate ~= false),
        AutoSolveFateSword = (State.AutoSolveFateSword ~= nil) and State.AutoSolveFateSword or (diskData.AutoSolveFateSword ~= false),
        AutoDefendMoneyUnits = (State.AutoDefendMoneyUnits ~= nil) and State.AutoDefendMoneyUnits or (diskData.AutoDefendMoneyUnits ~= false)
    }
    local encoded = HttpService:JSONEncode(payload)
    pcall(writefile, ConfigFile, encoded)
end

local isLoadingConfig = false
local saveDebounce = false
local function SaveConfigDebounced()
    if not isScriptRunning or isLoadingConfig then return end
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.5, function()
        saveDebounce = false
        if isScriptRunning and not isLoadingConfig then
            SaveConfig()
        end
    end)
end

-- Periodic Auto-Save (Every 10 seconds & on game shutdown)
task.spawn(function()
    while isScriptRunning do
        task.wait(10)
        if not isScriptRunning then break end
        SaveConfig()
    end
end)

pcall(function()
    game:BindToClose(function()
        if isScriptRunning then
            isScriptRunning = false
            pcall(SaveConfig)
        end
    end)
end)

--// Helper Functions
local function SafeClick(button)
    if not button then return end
    if firesignal then
        pcall(firesignal, button.MouseButton1Click)
        pcall(firesignal, button.Activated)
        return
    end
    if getconnections then
        pcall(function()
            for _, conn in ipairs(getconnections(button.MouseButton1Click) or {}) do
                conn:Fire()
            end
            for _, conn in ipairs(getconnections(button.Activated) or {}) do
                conn:Fire()
            end
        end)
    end
end

--// In-Game Gameplay Settings Controller (Two-way Sync with PlayerGui.Settings & SettingModule)
local isSyncingFromGame = false

local function GetGameSettingItem(guiName)
    local s = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Settings")
    return s and s:FindFirstChild(guiName, true)
end

local function GetGameSetting(guiName, settingKey)
    local item = GetGameSettingItem(guiName)
    local slider = item and item:FindFirstChild("Slider")
    local ball = slider and slider:FindFirstChild("Ball")
    if ball then
        return (ball.Position.X.Scale > 0.3)
    end
    if SettingModule and settingKey and SettingModule.GetSetting then
        local ok, val = pcall(function() return SettingModule:GetSetting(settingKey) end)
        if ok and val ~= nil then return val end
    end
    return nil
end

local function SetGameSetting(guiName, targetState, settingKey)
    local item = GetGameSettingItem(guiName)
    local slider = item and item:FindFirstChild("Slider")
    local ball = slider and slider:FindFirstChild("Ball")
    local btn = slider and slider:FindFirstChild("Button")
    
    if ball and btn then
        local currentState = (ball.Position.X.Scale > 0.3)
        if currentState ~= targetState then
            SafeClick(btn)
            return true
        end
        return false
    end
    
    if SettingModule and settingKey then
        pcall(function()
            if SettingModule.SettingsState and SettingModule.SettingsState[settingKey] ~= targetState then
                SettingModule:SaveSetting(settingKey, targetState)
                if SettingModule.ApplySettingEffect then
                    SettingModule:ApplySettingEffect(settingKey, targetState)
                end
            end
        end)
    end
    return false
end

-- Sync from In-Game Settings to STRIX HUB (Unified Thread)
local function SetupGameSettingsSync()
    task.spawn(function()
        while isScriptRunning do
            task.wait(1.0)
            if not isScriptRunning then break end
            for _, sInfo in ipairs(GameSettingsMap) do
                if not isScriptRunning then break end
                local currentInGame = GetGameSetting(sInfo.GuiName, sInfo.SettingKey)
                if currentInGame ~= nil and State[sInfo.StateKey] ~= currentInGame and not isSyncingFromGame then
                    isSyncingFromGame = true
                    State[sInfo.StateKey] = currentInGame
                    if MacLib and MacLib.Options and MacLib.Options[sInfo.OptFlag] then
                        pcall(function() MacLib.Options[sInfo.OptFlag]:UpdateState(currentInGame) end)
                    end
                    isSyncingFromGame = false
                    SaveConfigDebounced()
                end
            end
        end
    end)
end
SetupGameSettingsSync()

local function IsRoomCreated()
    local PlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
    if PlayGUI and PlayGUI:FindFirstChild("PlayFrame") and PlayGUI.PlayFrame.Visible then
        return true
    end
    return false
end

local ProcessAutoChallenges

--// Challenge & Gameplay Helpers
local function GetCurrentGameMode()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayingGui")
    local gm = pg and pg:FindFirstChild("Frame") and pg.Frame:FindFirstChild("MainContainer")
        and pg.Frame.MainContainer:FindFirstChild("StageText")
        and pg.Frame.MainContainer.StageText:FindFirstChild("GameMode")
    if gm and gm.Text and gm.Text ~= "" then
        return gm.Text
    end

    local si = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("StageInfo")
    local siGm = si and si:FindFirstChild("GameMode", true)
    if siGm and siGm.Text and siGm.Text ~= "" then
        return siGm.Text
    end

    local modeAttr = workspace:GetAttribute("GameMode") or workspace:GetAttribute("Mode")
    if modeAttr and tostring(modeAttr) ~= "" then
        return tostring(modeAttr)
    end

    return ""
end

local function IsChallengeMatch()
    if isLobby or game.PlaceId == 117949143041402 or game.PlaceId == 110388679506690 then
        return false
    end

    local modeText = string.lower(GetCurrentGameMode())
    if modeText ~= "" then
        -- Hard rejection for non-challenge game modes (Event, Story, Raid, Boss)
        if string.find(modeText, "event") or string.find(modeText, "story") or string.find(modeText, "raid") or string.find(modeText, "boss") then
            return false
        end
        -- Positive match for Challenge modes
        if string.find(modeText, "challenge") or string.find(modeText, "weekly") or string.find(modeText, "daily") or string.find(modeText, "regular") then
            return true
        end
    end

    -- Secondary check on StageMap label
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayingGui")
    local sm = pg and pg:FindFirstChild("Frame") and pg.Frame:FindFirstChild("MainContainer")
        and pg.Frame.MainContainer:FindFirstChild("StageText")
        and pg.Frame.MainContainer.StageText:FindFirstChild("StageMap")
    if sm and sm.Text then
        local smText = string.lower(sm.Text)
        if string.find(smText, "event") or string.find(smText, "story") or string.find(smText, "raid") or string.find(smText, "boss") then
            return false
        end
        if string.find(smText, "challenge") then
            return true
        end
    end

    return false
end

local hasHandledLeave = false
local isMatchFinished = false
local matchStartCycle = math.floor(os.time() / 1800)
local pendingResetLeave = false

local function IsMatchFinished()
    if isMatchFinished then
        return true
    end

    local eg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
    local frame = eg and eg:FindFirstChild("EndGameFrame")
    -- In Gameplay, EndGameFrame.Visible is strictly false during the match. It only becomes true when the match is over!
    if eg and eg.Enabled and frame and frame.Visible then
        local resLabel = frame:FindFirstChild("Info") and frame.Info:FindFirstChild("ResultLabel")
        local leaveBtn = frame:FindFirstChild("Buttons") and frame.Buttons:FindFirstChild("LeaveBtn")
        if (resLabel and resLabel.Visible) or (leaveBtn and leaveBtn.Visible) then
            return true
        end
    end

    return false
end

local function ExecuteLeaveToLobby(reasonTitle, reasonDesc)
    if hasHandledLeave then return end
    hasHandledLeave = true

    -- Notifications right before teleport are omitted to prevent render engine Tween crashes during DataModel teardown

    task.spawn(function()
        task.wait(2)

        local eg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
        local frame = eg and eg:FindFirstChild("EndGameFrame")
        local leaveBtn = frame and (frame:FindFirstChild("Buttons") and frame.Buttons:FindFirstChild("LeaveBtn") or frame:FindFirstChild("LeaveBtn", true))
        if leaveBtn then
            SafeClick(leaveBtn)
        end

        local ge = ReplicatedStorage:FindFirstChild("GameEvents")
        local leaveReq = ge and ge:FindFirstChild("LeaveGameRequest")
        if leaveReq then
            pcall(function() leaveReq:FireServer() end)
        end

        task.wait(4)
        if game.PlaceId ~= 117949143041402 and not isLobby then
            pcall(function()
                game:GetService("TeleportService"):Teleport(117949143041402)
            end)
        end
    end)
end

local function CheckAndExecuteAutoLeave()
    if isLobby or game.PlaceId == 117949143041402 or game.PlaceId == 110388679506690 then
        hasHandledLeave = false
        isMatchFinished = false
        pendingResetLeave = false
        getgenv().STRIX_IS_CHALLENGE_MATCH = false
        return
    end

    if hasHandledLeave then return end

    -- Check if Challenge rotation reset happened during this match (:00 or :30)
    if State.AutoLeaveOnChallengeReset then
        local now = os.time()
        local currentCycle = math.floor(now / 1800)
        local d = os.date("*t", now)
        if currentCycle ~= matchStartCycle or (d.min == 0 or d.min == 30) then
            pendingResetLeave = true
        end
    end

    -- Rule 1: Auto Leave On Reset -> Regardless of what mode is playing (Story, Event, Raid, Boss, Challenge),
    -- wait for match to finish, then leave to lobby to do the newly reset Challenges!
    if State.AutoLeaveOnChallengeReset and pendingResetLeave then
        if IsMatchFinished() then
            ExecuteLeaveToLobby("Challenge Reset", "Challenge rotation reset! Match finished, leaving to Lobby for Challenges...")
            return
        end
    end

    -- Rule 2: Normal Auto Leave -> Strictly for Challenge match completion
    if State.AutoLeaveChallenge and IsChallengeMatch() then
        if IsMatchFinished() then
            ExecuteLeaveToLobby("Auto Leave", "Challenge finished! Leaving to Lobby in 2s...")
            return
        end
    end
end

-- Feature 5: Auto Leave on Challenge Reset (Check periodically in background loop)
local function CheckChallengeResetLeave()
    CheckAndExecuteAutoLeave()
end

-- Listen for EndGameEvent from server
pcall(function()
    local ge = ReplicatedStorage:WaitForChild("GameEvents", 10)
    local egEvent = ge and ge:WaitForChild("EndGameEvent", 10)
    if egEvent then
        egEvent.OnClientEvent:Connect(function()
            isMatchFinished = true
            if (State.AutoLeaveChallenge or State.AutoLeaveOnChallengeReset) and not hasHandledLeave then
                task.delay(1.5, function()
                    CheckAndExecuteAutoLeave()
                end)
            end
        end)
    end
end)

--// Fate (Event) Mystery Sword Automation
local isSolvingSwordEvent = false
local lastSwordSolveTime = 0
local lastSafeGroundCFrame = nil

-- Background tracker for player's safe resting position on solid ground
task.spawn(function()
    while isScriptRunning do
        if not isSolvingSwordEvent then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air then
                if hrp.AssemblyLinearVelocity.Magnitude < 2.5 then
                    lastSafeGroundCFrame = hrp.CFrame
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Calculate safe standing position near sword/fence (Prevents clipping inside fence mesh or sinking underground)
local function GetSafeSwordStandCFrame(fencePart, defaultPos, promptObj)
    local targetPos = nil
    if fencePart and fencePart:IsA("BasePart") then
        local fenceCFrame = fencePart.CFrame
        local fenceHeight = fencePart.Size.Y
        
        -- Try 3.8 studs in front of fence
        local frontPos = fenceCFrame * Vector3.new(0, 0, 3.8)
        local rayOrigin = frontPos + Vector3.new(0, 12, 0)
        local rayDir = Vector3.new(0, -40, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { LocalPlayer.Character, fencePart }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local hit = workspace:Raycast(rayOrigin, rayDir, rayParams)
        if hit and hit.Position then
            targetPos = hit.Position + Vector3.new(0, 3.2, 0)
        else
            -- Try 3.8 studs behind fence
            local backPos = fenceCFrame * Vector3.new(0, 0, -3.8)
            local hitBack = workspace:Raycast(backPos + Vector3.new(0, 12, 0), rayDir, rayParams)
            if hitBack and hitBack.Position then
                targetPos = hitBack.Position + Vector3.new(0, 3.2, 0)
            else
                -- Fallback: Safely elevated atop the fence mesh
                targetPos = fencePart.Position + Vector3.new(0, (fenceHeight / 2) + 3.2, 0)
            end
        end
    else
        targetPos = defaultPos + Vector3.new(0, 4.5, 0)
    end

    local promptPart = promptObj and promptObj.Parent
    local lookPos = (promptPart and promptPart:IsA("BasePart") and promptPart.Position) or defaultPos
    return CFrame.lookAt(targetPos, Vector3.new(lookPos.X, targetPos.Y, lookPos.Z))
end

local function SolveFateSwordEvent()
    if isSolvingSwordEvent then return end
    if not (workspace:GetAttribute("SwordEventActive") == true) then return end
    if os.clock() - lastSwordSolveTime < 3.0 then return end

    isSolvingSwordEvent = true
    lastSwordSolveTime = os.clock()

    task.spawn(function()
        pcall(function()
            local char = LocalPlayer and LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then
                isSolvingSwordEvent = false
                return
            end

            local startCFrame = lastSafeGroundCFrame or hrp.CFrame

            -- 1. Gather all candidate fences and swords with ProximityPrompt
            local candidates = {}
            local fe = workspace:FindFirstChild("FateEvent")
            local fencesFolder = fe and fe:FindFirstChild("Map") and fe.Map:FindFirstChild("Fences")
            local fences = fencesFolder and fencesFolder:GetChildren() or {}

            for _, f in ipairs(fences) do
                local prompt = f:FindFirstChildWhichIsA("ProximityPrompt") or f:FindFirstChild("SwordPrompt")
                if prompt and prompt.Enabled then
                    local fPos = f:IsA("BasePart") and f.Position or (f:IsA("Model") and f:GetPivot().Position) or Vector3.zero
                    table.insert(candidates, { fence = f, prompt = prompt, pos = fPos })
                end
            end

            if #candidates == 0 then
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local actText = string.lower(d.ActionText or "")
                        local objText = string.lower(d.ObjectText or "")
                        local pName = string.lower(d.Name or "")
                        if pName == "swordprompt" or string.find(actText, "ดาบ") or string.find(objText, "ดาบ") or string.find(actText, "sword") or string.find(objText, "sword") then
                            local pPart = d.Parent and (d.Parent:IsA("BasePart") and d.Parent or (d.Parent:IsA("Model") and d.Parent.PrimaryPart) or d:FindFirstAncestorWhichIsA("BasePart"))
                            if pPart then
                                table.insert(candidates, { fence = pPart, prompt = d, pos = pPart.Position })
                            end
                        end
                    end
                end
            end

            -- Failsafe: Any active prompt under FateEvent
            if #candidates == 0 and fe then
                for _, d in ipairs(fe:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local pPart = d.Parent and (d.Parent:IsA("BasePart") and d.Parent or (d.Parent:IsA("Model") and d.Parent.PrimaryPart) or d:FindFirstAncestorWhichIsA("BasePart"))
                        if pPart then
                            table.insert(candidates, { fence = pPart, prompt = d, pos = pPart.Position })
                        end
                    end
                end
            end

            if #candidates == 0 then
                isSolvingSwordEvent = false
                return
            end

            -- Sort candidates by distance from player to solve closest first
            local playerPos = hrp.Position
            table.sort(candidates, function(a, b)
                return (a.pos - playerPos).Magnitude < (b.pos - playerPos).Magnitude
            end)

            -- 2. Interact with candidates with stable server-sync timing
            local lastPresses = workspace:GetAttribute("SwordEventPresses") or 0
            local requiredPresses = workspace:GetAttribute("SwordEventRequired") or 2

            for _, item in ipairs(candidates) do
                if not (workspace:GetAttribute("SwordEventActive") == true) then
                    break
                end
                local currentPresses = workspace:GetAttribute("SwordEventPresses") or 0
                if currentPresses >= requiredPresses then
                    break
                end

                local prompt = item.prompt
                if not prompt or not prompt.Enabled or not prompt.Parent then
                    continue
                end

                -- Calculate safe standing CFrame (prevent clipping into fence or ground)
                local safeStandCFrame = GetSafeSwordStandCFrame(item.fence, item.pos, prompt)

                -- Teleport to sword with zero velocity
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = safeStandCFrame
                end)

                -- Physics Replication Delay: Allow server to register character's new position
                task.wait(0.35)

                -- Keep character stable at location
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    prompt.HoldDuration = 0
                    prompt.RequiresLineOfSight = false
                    prompt.MaxActivationDistance = 60
                end)

                -- Trigger interaction
                pcall(function()
                    if fireproximityprompt then
                        fireproximityprompt(prompt, 0)
                    elseif getconnections then
                        for _, c in ipairs(getconnections(prompt.Triggered) or {}) do
                            pcall(function() c:Fire() end)
                        end
                    end
                end)

                -- Server Processing Delay: Allow server script to record pickup
                task.wait(0.45)

                local updatedPresses = workspace:GetAttribute("SwordEventPresses") or 0
                if updatedPresses > lastPresses or not (workspace:GetAttribute("SwordEventActive") == true) then
                    lastPresses = updatedPresses
                    task.wait(0.2)
                    if updatedPresses >= requiredPresses or not (workspace:GetAttribute("SwordEventActive") == true) then
                        break
                    end
                else
                    -- Retry once if server ping delayed the trigger
                    if prompt.Enabled and (workspace:GetAttribute("SwordEventActive") == true) then
                        pcall(function()
                            if fireproximityprompt then
                                fireproximityprompt(prompt, 0)
                            end
                        end)
                        task.wait(0.35)
                        lastPresses = workspace:GetAttribute("SwordEventPresses") or 0
                        if lastPresses >= requiredPresses or not (workspace:GetAttribute("SwordEventActive") == true) then
                            break
                        end
                    end
                end
            end

            -- 3. Teleport back safely to original ground position (+2.5 studs lift to prevent sinking)
            pcall(function()
                local returnCFrame = lastSafeGroundCFrame or startCFrame
                if hrp and returnCFrame then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = returnCFrame + Vector3.new(0, 2.5, 0)

                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                    task.wait(0.25)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        end)
        task.wait(0.5)
        isSolvingSwordEvent = false
    end)
end

-- Immediate Listener for Fate Sword Event
pcall(function()
    workspace:GetAttributeChangedSignal("SwordEventActive"):Connect(function()
        if State.AutoSolveFateSword and workspace:GetAttribute("SwordEventActive") == true then
            task.spawn(SolveFateSwordEvent)
        end
    end)
end)

--// Auto Defend (Money Units: Spood (Yen), etc.)
local UnitConfigModule = Modules and (Modules:FindFirstChild("UnitConfig") or Modules:WaitForChild("UnitConfig", 3)) and select(2, pcall(require, Modules.UnitConfig)) or nil

local function GetPlayerFolder()
    local pf = workspace:FindFirstChild("PlayerFolder", true)
        or workspace:FindFirstChild("PlayerUnits", true)
        or workspace:FindFirstChild("Units", true)
    if pf then return pf end
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch:IsA("Folder") or ch:IsA("Model") then
            local f = ch:FindFirstChild("PlayerFolder") or ch:FindFirstChild("PlayerUnits") or ch:FindFirstChild("Units")
            if f then return f end
        end
    end
    return nil
end

local function IsMyUnit(unit)
    if not (unit and unit:IsA("Model")) then return false end
    local ownerId = unit:GetAttribute("OwnerID") or unit:GetAttribute("OwnerId") or unit:GetAttribute("UserId")
    if ownerId then return tonumber(ownerId) == LocalPlayer.UserId end
    local owner = unit:GetAttribute("Owner") or unit:GetAttribute("Player")
    if owner then return owner == LocalPlayer.Name end
    return true
end

local function IsMoneyUnit(unit)
    local dn = unit:GetAttribute("DisplayName")
    if type(dn) == "string" and (string.find(dn, "Yen") or string.find(dn, "Money") or string.find(dn, "Farm") or string.find(dn, "Cash")) then
        return true
    end
    local unit_id = unit:GetAttribute("UnitId")
    if unit_id and UnitConfigModule and UnitConfigModule.GetUnitData then
        local data = UnitConfigModule.GetUnitData(unit_id)
        if data and data.DisplayName and type(data.DisplayName) == "string" then
            local name = data.DisplayName
            if string.find(name, "Yen") or string.find(name, "Money") or string.find(name, "Farm") or string.find(name, "Cash") then
                return true
            end
        end
    end
    return false
end

local lastDefendToggle = {}
local function HandleAutoDefendMoneyUnits()
    if not State.AutoDefendMoneyUnits then return end
    local pf = GetPlayerFolder()
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    local toggleRemote = ge and ge:FindFirstChild("ToggleBehaviorModeRequest")
    if not (pf and toggleRemote) then return end

    local now = os.clock()
    for _, unit in ipairs(pf:GetChildren()) do
        if IsMyUnit(unit) and IsMoneyUnit(unit) then
            local mode = unit:GetAttribute("BehaviorMode")
            if mode ~= "Defend" then
                if now - (lastDefendToggle[unit] or 0) >= 2.0 then
                    lastDefendToggle[unit] = now
                    pcall(function()
                        toggleRemote:FireServer(unit)
                    end)
                end
            end
        end
    end
end

-- Fast reaction listener on newly placed units across all game modes (Story, Mysterious, Raids, Boss, Fate Event)
task.spawn(function()
    local lastConnectedFolder = nil
    while isScriptRunning do
        local pf = GetPlayerFolder()
        if pf and pf ~= lastConnectedFolder then
            lastConnectedFolder = pf
            pf.ChildAdded:Connect(function(child)
                if State.AutoDefendMoneyUnits and isBattlePlace then
                    task.wait(0.3)
                    HandleAutoDefendMoneyUnits()
                end
            end)
        end
        task.wait(2)
    end
end)

--// Helper: Player Data Replica Retrieval
local function GetReplicaData()
    if PlayModule and PlayModule.Replica and PlayModule.Replica.Data then
        return PlayModule.Replica.Data
    end
    if _G.PlayerDataReplica and _G.PlayerDataReplica.Data then
        return _G.PlayerDataReplica.Data
    end
    local ok, rc = pcall(function()
        return require(ReplicatedStorage.ReplicaLib.ReplicatedStorage.ReplicaController)
    end)
    if ok and rc and rc._replicas then
        for _, rep in pairs(rc._replicas) do
            if rep.Class == "PlayerData" and rep.Data then
                return rep.Data
            end
        end
    end
    return nil
end

--// Feature 2: Stage Unlock Validation
local function ValidateMapAndStage(mapId, stageNum, mode)
    if not StageUnlockHelper then
        return true, "Unlocked"
    end
    local repData = GetReplicaData()
    local cleared = (repData and repData.ClearedStages) or {}
    local clearedC = (repData and repData.ClearedChallenges) or {}

    local isMapUnlocked, mapErr = StageUnlockHelper.IsMapUnlocked(mapId, cleared, mode)
    if not isMapUnlocked then
        return false, tostring(mapErr or "Map Locked")
    end

    local isStageUnlocked, stageErr = StageUnlockHelper.IsStageUnlocked(mapId, tonumber(stageNum) or 1, cleared, clearedC, mode)
    if not isStageUnlocked then
        return false, tostring(stageErr or "Stage Locked")
    end

    return true, "Unlocked"
end

local function GetHighestUnlockedStage(mapId, totalStages, mode)
    local highest = 1
    local total = totalStages or 1
    for s = 1, total do
        local ok = ValidateMapAndStage(mapId, s, mode)
        if ok then
            highest = s
        else
            break
        end
    end
    return highest
end

--// Feature 3: Robust Room Creation & Direct Server Sync
local function CreateRoom(mode, mapDisplayName, stage, difficulty, forceRecreate)
    local cleanName = string.gsub(mapDisplayName or "", "%s*%[.-%]", "")
    local mapId = nil
    if mode == "Story" then
        mapId = GameData.Story.DisplayToId[mapDisplayName] or GameData.Story.DisplayToId[cleanName] or mapDisplayName
    elseif mode == "Mysterios" or mode == "Mysterious" then
        mapId = GameData.Mysterious.DisplayToId[mapDisplayName] or GameData.Mysterious.DisplayToId[cleanName] or mapDisplayName
    elseif mode == "Raids" then
        mapId = GameData.Raids.DisplayToId[mapDisplayName] or GameData.Raids.DisplayToId[cleanName] or mapDisplayName
    elseif mode == "Event" or mode == "Boss" then
        mapId = GameData.Boss.DisplayToId[mapDisplayName] or GameData.Boss.DisplayToId[cleanName] or mapDisplayName
    end
    
    if not mapId then return false, "Map not found" end
    
    local stageNum = tonumber(stage) or 1
    local diff = difficulty or "Normal"
    
    -- Feature 3: In-place update if room already exists
    if IsRoomCreated() then
        if not forceRecreate then
            pcall(function()
                if UpdateLobbySettings then
                    UpdateLobbySettings:FireServer(cleanName, tostring(stageNum), {}, diff, mapId, mode)
                end
            end)
            return true, "Room updated in-place"
        else
            pcall(function()
                if LeaveLobbyEvent then LeaveLobbyEvent:FireServer() end
                if PlayModule and PlayModule.CloseModule then PlayModule.CloseModule() end
            end)
            task.wait(0.25)
        end
    end
    
    -- Feature 2: Stage Unlock Validation
    local isUnlocked, reason = ValidateMapAndStage(mapId, stageNum, mode)
    if not isUnlocked then
        warn(string.format("[STRIX HUB] Stage %s of %s is locked: %s", tostring(stageNum), tostring(cleanName), tostring(reason)))
        pcall(function()
            if Window and Window.Notify then
                Window:Notify({
                    Title = "Stage Locked",
                    Description = string.format("%s [Stage %s] ยังไม่ปลดล็อค: %s", tostring(cleanName), tostring(stageNum), tostring(reason)),
                    Lifetime = 4
                })
            end
        end)
        return false, reason
    end
    
    -- Feature 3: Request Lobby Creation & Open Target Map
    pcall(function()
        if not (PlayModule and PlayModule.isHost == true) and RequestJoinLobby then
            RequestJoinLobby:InvokeServer("Create")
        end
    end)
    
    if PlayModule then
        PlayModule.isHost = true
        if PlayModule.OpenTargetMap then
            pcall(function()
                PlayModule.OpenTargetMap(mode, mapId, stageNum, diff)
            end)
        end
    end
    
    task.wait(0.25)
    
    -- Feature 3: Select Difficulty button on SelectPlayer UI (Normal / Hard / Nightmare)
    pcall(function()
        local PlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
        local sp = PlayGUI and PlayGUI:FindFirstChild("SelectPlayer")
        local sdf = sp and sp:FindFirstChild("ShowDetailsFrame")
        local modeFrame = sdf and sdf:FindFirstChild("Mode")
        local diffBtn = modeFrame and modeFrame:FindFirstChild(diff .. "Btn")
        if diffBtn and diffBtn.Visible then
            SafeClick(diffBtn)
        end
    end)
    
    task.wait(0.2)
    
    -- Feature 3: Click SelectPlayer.CreateBtn to finalize creation
    local enteredPlayFrame = false
    pcall(function()
        local PlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
        local sp = PlayGUI and PlayGUI:FindFirstChild("SelectPlayer")
        local createBtn = sp and sp:FindFirstChild("CreateBtn")
        if createBtn and createBtn.Visible then
            SafeClick(createBtn)
            enteredPlayFrame = true
        end
    end)
    
    -- Feature 3: Direct sync to guarantee PlayFrame is opened and server state matches
    pcall(function()
        if not enteredPlayFrame and PlayModule and PlayModule.OpenPlayFrame then
            pcall(function() PlayModule.OpenPlayFrame() end)
        end
        if UpdateLobbySettings then
            UpdateLobbySettings:FireServer(cleanName, tostring(stageNum), {}, diff, mapId, mode)
        end
    end)
    
    return true
end

--// Feature 4: Dual-Trigger Match Start & Teleport Reliability
local function TriggerMatchStart(overrideMode, overrideMap, overrideStage, overrideDiff)
    local PlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
    local pf = PlayGUI and PlayGUI:FindFirstChild("PlayFrame")
    if not (pf and pf.Visible) then return false, "No active room" end
    
    if not PlayGUI.Enabled then
        PlayGUI.Enabled = true
    end
    
    -- Extract mode, map, stage, difficulty
    local mode = overrideMode
    local mapName = overrideMap
    local stage = overrideStage
    local diff = overrideDiff
    
    local sdf = pf:FindFirstChild("Details") and pf.Details:FindFirstChild("ShowDetailsFrame")
    if sdf then
        mapName = mapName or (sdf:FindFirstChild("MAPNAME") and sdf.MAPNAME.Text)
        local stageText = sdf:FindFirstChild("STAGE") and sdf.STAGE.Text
        if stageText then
            stage = stage or string.match(stageText, "%d+") or "1"
        end
        diff = diff or (sdf:FindFirstChild("Diff") and sdf.Diff.Text)
    end
    mode = mode or (PlayModule and PlayModule.SessionMode)
    
    -- Fallback to State if still missing
    if not mode or mode == "" then
        if State.ActiveAutoCreate == "Story" then
            mode = "Story"; mapName = mapName or State.StoryMap; stage = stage or State.StoryStage; diff = diff or State.StoryDiff
        elseif State.ActiveAutoCreate == "Mysterious" then
            mode = "Mysterios"; mapName = mapName or State.MysteriousMap; stage = stage or State.MysteriousStage; diff = diff or State.MysteriousDiff
        elseif State.ActiveAutoCreate == "Raids" then
            mode = "Raids"; mapName = mapName or State.RaidsMap; stage = stage or State.RaidsStage; diff = diff or State.RaidsDiff
        elseif State.ActiveAutoCreate == "Boss" then
            mode = "Event"; mapName = mapName or State.BossMap; stage = stage or State.BossStage; diff = diff or State.BossDiff
        end
    end
    
    local mapId = nil
    if mode and mapName then
        local cleanName = string.gsub(mapName or "", "%s*%[.-%]", "")
        if mode == "Story" then
            mapId = GameData.Story.DisplayToId[mapName] or GameData.Story.DisplayToId[cleanName] or mapName
        elseif mode == "Mysterios" or mode == "Mysterious" then
            mapId = GameData.Mysterious.DisplayToId[mapName] or GameData.Mysterious.DisplayToId[cleanName] or mapName
        elseif mode == "Raids" then
            mapId = GameData.Raids.DisplayToId[mapName] or GameData.Raids.DisplayToId[cleanName] or mapName
        elseif mode == "Event" or mode == "Boss" then
            mapId = GameData.Boss.DisplayToId[mapName] or GameData.Boss.DisplayToId[cleanName] or mapName
        else
            mapId = mapName
        end
    end
    
    local stageNum = tonumber(stage) or 1
    local diffStr = diff or "Normal"
    
    -- Feature 2: Validate unlock before starting
    if mapId and mode then
        local isUnlocked, reason = ValidateMapAndStage(mapId, stageNum, mode)
        if not isUnlocked then
            warn(string.format("[STRIX HUB] Cannot start locked match: %s", tostring(reason)))
            return false, reason
        end
    end
    
    -- 1. Click in-game PlayBtn in PlayFrame if present
    local playBtn = pf:FindFirstChild("ContainerBtn") and pf.ContainerBtn:FindFirstChild("PlayBtn")
    if playBtn and playBtn.Visible and playBtn.Text ~= "Teleporting..." then
        SafeClick(playBtn)
    end
    
    -- 2. Direct TeleportRequest firing (Dual-Trigger failsafe)
    if TeleportRequest and mapId and mode then
        pcall(function()
            TeleportRequest:FireServer(107610426295102, mode, mapId, tostring(stageNum), diffStr)
        end)
        pcall(function()
            TeleportRequest:FireServer(97246719761307, mode, mapId, tostring(stageNum), diffStr)
        end)
    end
    
    return true
end

--// Clean up any existing STRIX HUB GUI
pcall(function()
    local hui = (gethui and gethui()) or game:GetService("CoreGui")
    if hui then
        for _, v in ipairs(hui:GetChildren()) do
            if v and v:IsA("ScreenGui") and v:FindFirstChild("Base") then
                pcall(function() v:Destroy() end)
            end
        end
    end
end)

--// Create MacLib Window
local Window = MacLib:Window({
    Title = "STRIX HUB",
    Subtitle = "Anime Mysterious",
    Size = (State.UISize and State.UISize.Width and State.UISize.Height) and UDim2.fromOffset(State.UISize.Width, State.UISize.Height) or UDim2.fromOffset(868, 650),
    DragStyle = 1,
    AcrylicBlur = (State.AcrylicBlur == true),
    ShowUserInfo = (State.ShowUserInfo ~= false),
    Keybind = (State.Keybind and State.Keybind ~= Enum.KeyCode.Unknown) and State.Keybind or Enum.KeyCode.RightControl
})

-- Completely disable MacLib notifications to prevent CanvasGroup DirectX device lost crashes
Window:SetNotificationsState(false)

-- Safe Window Unload hook (no circular recursion)
if Window.onUnloaded then
    Window.onUnloaded(function()
        if getgenv().STRIX_HUB_CLEANUP then pcall(getgenv().STRIX_HUB_CLEANUP) end
    end)
end

-- Neutralize Maclib's Dialog to prevent CanvasGroup creation
Window.Dialog = function(self, dialogSettings)
    if dialogSettings and dialogSettings.Buttons then
        for _, btn in ipairs(dialogSettings.Buttons) do
            if btn.Name == "Confirm" and btn.Callback then
                task.spawn(btn.Callback)
                break
            end
        end
    end
    return {
        UpdateTitle = function() end,
        UpdateDescription = function() end,
        Cancel = function() end,
    }
end

--// Resizable Window Setup (Drag to Resize + Proportion Fix)
local function SetupWindowResize()
    local targetScreenGui
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    for _, v in ipairs(parent:GetChildren()) do
        if v:IsA("ScreenGui") and v:FindFirstChild("Base") then
            targetScreenGui = v
            break
        end
    end
    if not targetScreenGui or not targetScreenGui:FindFirstChild("Base") then return end
    local base = targetScreenGui.Base

    local function EnforceFrameLayout()
        local sidebar = base:FindFirstChild("Sidebar")
        local content = base:FindFirstChild("Content")
        if sidebar and content then
            sidebar.Size = UDim2.new(0, 240, 1, 0)
            content.AnchorPoint = Vector2.new(1, 0)
            content.Position = UDim2.new(1, 0, 0, 0)
            content.Size = UDim2.new(1, -240, 1, 0)
        end
    end
    EnforceFrameLayout()
    if base:FindFirstChild("BaseUIScale") then
        base.BaseUIScale:Destroy()
    end

    -- Replace Maclib's exit button with a clean clone to detach the broken CanvasGroup Dialog listener
    local exitBtn = base:FindFirstChild("Exit", true)
    if exitBtn and exitBtn:IsA("TextButton") then
        local p = exitBtn.Parent
        local cleanExit = exitBtn:Clone()
        cleanExit.Name = "ExitClean"
        cleanExit.LayoutOrder = exitBtn.LayoutOrder
        cleanExit.Parent = p
        pcall(function() exitBtn:Destroy() end)

        local exited = false
        local function doExit()
            if exited then return end
            exited = true
            if getgenv().STRIX_HUB_CLEANUP then pcall(getgenv().STRIX_HUB_CLEANUP) end
            pcall(function()
                if Window and Window.Unload then Window:Unload() end
            end)
            pcall(function()
                if targetScreenGui and targetScreenGui.Parent then
                    targetScreenGui:Destroy()
                end
            end)
        end
        cleanExit.MouseButton1Click:Connect(doExit)
        cleanExit.Activated:Connect(doExit)
    end

    local MIN_W, MAX_W = 760, 1150
    local MIN_H, MAX_H = 480, 850

    local resizingType = nil
    local startMousePos
    local startOffsetSize
    local startPos

    -- 1. Corner Handle (Bottom-Right)
    local corner = Instance.new("Frame")
    corner.Name = "ResizeHandle_Corner"
    corner.AnchorPoint = Vector2.new(1, 1)
    corner.Position = UDim2.new(1, 0, 1, 0)
    corner.Size = UDim2.fromOffset(24, 24)
    corner.BackgroundTransparency = 1
    corner.ZIndex = 100
    corner.Parent = base

    local grip = Instance.new("ImageLabel")
    grip.Name = "Grip"
    grip.AnchorPoint = Vector2.new(1, 1)
    grip.Position = UDim2.new(1, -4, 1, -4)
    grip.Size = UDim2.fromOffset(14, 14)
    grip.Image = "rbxassetid://10734900011"
    grip.ImageTransparency = 0.5
    grip.BackgroundTransparency = 1
    grip.ZIndex = 101
    grip.Parent = corner

    local cornerBtn = Instance.new("TextButton")
    cornerBtn.Name = "Hit"
    cornerBtn.Size = UDim2.fromScale(1, 1)
    cornerBtn.BackgroundTransparency = 1
    cornerBtn.Text = ""
    cornerBtn.ZIndex = 102
    cornerBtn.Parent = corner

    -- 2. Right Edge Handle
    local rightEdge = Instance.new("TextButton")
    rightEdge.Name = "ResizeHandle_Right"
    rightEdge.AnchorPoint = Vector2.new(1, 0)
    rightEdge.Position = UDim2.new(1, 0, 0, 30)
    rightEdge.Size = UDim2.new(0, 8, 1, -54)
    rightEdge.BackgroundTransparency = 1
    rightEdge.Text = ""
    rightEdge.ZIndex = 99
    rightEdge.Parent = base

    -- 3. Bottom Edge Handle
    local bottomEdge = Instance.new("TextButton")
    bottomEdge.Name = "ResizeHandle_Bottom"
    bottomEdge.AnchorPoint = Vector2.new(0, 1)
    bottomEdge.Position = UDim2.new(0, 0, 1, 0)
    bottomEdge.Size = UDim2.new(1, -24, 0, 8)
    bottomEdge.BackgroundTransparency = 1
    bottomEdge.Text = ""
    bottomEdge.ZIndex = 99
    bottomEdge.Parent = base

    local function StartResize(rType, input)
        resizingType = rType
        startMousePos = input.Position
        startOffsetSize = Vector2.new(base.Size.X.Offset, base.Size.Y.Offset)
        startPos = base.Position
        grip.ImageTransparency = 0.1
    end

    cornerBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            StartResize("Corner", input)
        end
    end)

    rightEdge.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            StartResize("Right", input)
        end
    end)

    bottomEdge.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            StartResize("Bottom", input)
        end
    end)

    cornerBtn.MouseEnter:Connect(function() grip.ImageTransparency = 0.25 end)
    cornerBtn.MouseLeave:Connect(function() if not resizingType then grip.ImageTransparency = 0.5 end end)

    UserInputService.InputChanged:Connect(function(input)
        if resizingType and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startMousePos
            local newW = startOffsetSize.X
            local newH = startOffsetSize.Y

            if resizingType == "Corner" then
                newW = math.clamp(startOffsetSize.X + delta.X, MIN_W, MAX_W)
                newH = math.clamp(startOffsetSize.Y + delta.Y, MIN_H, MAX_H)
            elseif resizingType == "Right" then
                newW = math.clamp(startOffsetSize.X + delta.X, MIN_W, MAX_W)
            elseif resizingType == "Bottom" then
                newH = math.clamp(startOffsetSize.Y + delta.Y, MIN_H, MAX_H)
            end

            local diffX = newW - startOffsetSize.X
            local diffY = newH - startOffsetSize.Y

            base.Size = UDim2.fromOffset(newW, newH)
            base.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + (diffX * 0.5),
                startPos.Y.Scale, startPos.Y.Offset + (diffY * 0.5)
            )
            EnforceFrameLayout()
            State.UISize = { Width = newW, Height = newH }
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if resizingType then
                resizingType = nil
                grip.ImageTransparency = 0.5
                EnforceFrameLayout()
                SaveConfigDebounced()
            end
        end
    end)
end

task.spawn(SetupWindowResize)

--// Mobile Floating Toggle Button
local function CreateMobileToggleButton()
    if getgenv().STRIX_MOBILE_GUI then
        pcall(function()
            getgenv().STRIX_MOBILE_GUI:Destroy()
        end)
        getgenv().STRIX_MOBILE_GUI = nil
    end

    local h = (gethui and gethui()) or game:GetService("CoreGui")
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "STRIX_MOBILE_TOGGLE"
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        mobileGui.DisplayOrder = 999999
    end)

    pcall(function()
        mobileGui.Parent = h
    end)
    if not mobileGui.Parent then
        mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    getgenv().STRIX_MOBILE_GUI = mobileGui

    -- Floating Button Frame
    local buttonFrame = Instance.new("ImageButton")
    buttonFrame.Name = "FloatingButton"
    buttonFrame.Size = UDim2.fromOffset(46, 46)
    buttonFrame.Position = UDim2.new(0, 15, 0, 140)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    buttonFrame.BackgroundTransparency = 0.15
    buttonFrame.BorderSizePixel = 0
    buttonFrame.AutoButtonColor = false
    buttonFrame.ZIndex = 1000
    buttonFrame.Active = true
    buttonFrame.Parent = mobileGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = buttonFrame

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BorderStroke"
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 1.4
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = buttonFrame

    -- Inner Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromOffset(26, 26)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://10709782230"
    icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    icon.ZIndex = 1001
    icon.Parent = buttonFrame

    -- Status Glow Dot
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.fromOffset(8, 8)
    statusDot.Position = UDim2.new(1, -5, 0, 5)
    statusDot.AnchorPoint = Vector2.new(1, 0)
    statusDot.BackgroundColor3 = Color3.fromRGB(0, 230, 130)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 1002
    statusDot.Parent = buttonFrame

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot

    local dotStroke = Instance.new("UIStroke")
    dotStroke.Color = Color3.fromRGB(20, 20, 24)
    dotStroke.Thickness = 1.2
    dotStroke.Parent = statusDot

    local function UpdateVisuals(isOpen)
        if isOpen then
            stroke.Color = Color3.fromRGB(0, 170, 255)
            statusDot.BackgroundColor3 = Color3.fromRGB(0, 230, 130)
            icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            icon.ImageTransparency = 0
        else
            stroke.Color = Color3.fromRGB(65, 65, 75)
            statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
            icon.ImageColor3 = Color3.fromRGB(180, 180, 190)
            icon.ImageTransparency = 0.2
        end
    end

    if Window and Window.GetState then
        UpdateVisuals(Window:GetState())
    end

    task.spawn(function()
        while isScriptRunning and mobileGui and mobileGui.Parent do
            local curState = false
            if Window and Window.GetState then
                curState = Window:GetState()
            end
            UpdateVisuals(curState)
            task.wait(0.3)
        end
    end)

    local function ToggleUI()
        local currentState = false
        if Window and Window.GetState then
            currentState = Window:GetState()
        end
        local newState = not currentState
        if Window and Window.SetState then
            Window:SetState(newState)
        end
        UpdateVisuals(newState)
    end

    local lastToggleTime = 0
    local function SafeToggle()
        local now = tick()
        if now - lastToggleTime < 0.35 then return end
        lastToggleTime = now
        ToggleUI()
    end

    -- Touch and Mouse Dragging
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local hasMoved = false

    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = buttonFrame.Position
            hasMoved = false
        end
    end)

    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if dragStart and startPos then
                local delta = input.Position - dragStart
                if delta.Magnitude > 8 then
                    hasMoved = true
                end

                if hasMoved then
                    local cam = workspace.CurrentCamera
                    local viewSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
                    local targetX = math.clamp(startPos.X.Offset + delta.X, 5, math.max(5, viewSize.X - 52))
                    local targetY = math.clamp(startPos.Y.Offset + delta.Y, 5, math.max(5, viewSize.Y - 52))

                    buttonFrame.Position = UDim2.new(0, targetX, 0, targetY)
                end
            end
        end
    end)

    buttonFrame.Activated:Connect(function()
        if not hasMoved then
            SafeToggle()
        end
    end)

    if State.MobileToggle == false then
        mobileGui.Enabled = false
    end

    return mobileGui
end

task.spawn(CreateMobileToggleButton)

local TabGroup = Window:TabGroup()

local Tabs = {
    AutoCreate = TabGroup:Tab({ Name = "Auto Create", Image = "rbxassetid://10709782230" }), -- lucide-bot
    Challenges = TabGroup:Tab({ Name = "Challenges", Image = "rbxassetid://10734975692" }), -- lucide-swords
    Gameplay = TabGroup:Tab({ Name = "Gameplay", Image = "rbxassetid://10723395215" }), -- lucide-gamepad-2
    SummonShop = TabGroup:Tab({ Name = "Summon & Shop", Image = "rbxassetid://10734952479" }), -- lucide-shopping-cart
    Settings = TabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" }) -- lucide-settings
}

-- Mutual exclusion handler for Auto Create toggles
local isUpdatingAutoCreate = false
local function SetAutoCreateMode(mode)
    if isUpdatingAutoCreate then return end
    isUpdatingAutoCreate = true
    
    State.ActiveAutoCreate = mode or "None"
    
    local modeToggleMap = {
        Story = "Toggle_AutoStory",
        Mysterious = "Toggle_AutoMysterious",
        Raids = "Toggle_AutoRaids",
        Boss = "Toggle_AutoBoss"
    }
    
    for m, optFlag in pairs(modeToggleMap) do
        local opt = MacLib.Options[optFlag]
        if opt then
            local shouldBeOn = (mode == m)
            if opt:GetState() ~= shouldBeOn then
                opt:UpdateState(shouldBeOn)
            end
        end
    end
    
    isUpdatingAutoCreate = false
    SaveConfigDebounced()
end

-- ====================================================================
-- TAB 1: AUTO CREATE
-- ====================================================================
local Sections = {
    Story = Tabs.AutoCreate:Section({ Side = "Left" }),
    Mysterious = Tabs.AutoCreate:Section({ Side = "Left" }),
    Raids = Tabs.AutoCreate:Section({ Side = "Right" }),
    Boss = Tabs.AutoCreate:Section({ Side = "Right" }),
    MatchStart = Tabs.AutoCreate:Section({ Side = "Right" })
}

-- [Menu] Story Mode
Sections.Story:Header({ Text = "Story Mode" })

Sections.Story:Toggle({
    Name = "Auto Create Story",
    Default = false,
    Callback = function(val)
        if isUpdatingAutoCreate then return end
        if val then
            SetAutoCreateMode("Story")
        elseif State.ActiveAutoCreate == "Story" then
            SetAutoCreateMode("None")
        end
    end
}, "Toggle_AutoStory")

local StoryStageDropdown
Sections.Story:Dropdown({
    Name = "Select Story Map",
    Multi = false,
    Required = true,
    Options = GameData.Story.Maps,
    Default = GameData.Story.Maps[1] or "",
    Callback = function(val)
        State.StoryMap = val
        SaveConfigDebounced()
        local id = GameData.Story.DisplayToId[val]
        if id and StoryStageDropdown then
            local stages = GameData.Story.Stages[id] or { "1" }
            StoryStageDropdown:ClearOptions()
            StoryStageDropdown:InsertOptions(stages)
            StoryStageDropdown:UpdateSelection(stages[1] or "1")
        end
    end
}, "Dropdown_StoryMap")

StoryStageDropdown = Sections.Story:Dropdown({
    Name = "Select Story Stage",
    Multi = false,
    Required = true,
    Options = (GameData.Story.Maps[1] and GameData.Story.Stages[GameData.Story.DisplayToId[GameData.Story.Maps[1]]]) or { "1", "2", "3", "4", "5" },
    Default = "1",
    Callback = function(val)
        State.StoryStage = tostring(val)
        SaveConfigDebounced()
    end
}, "Dropdown_StoryStage")

Sections.Story:Dropdown({
    Name = "Select Story Difficulty",
    Multi = false,
    Required = true,
    Options = GameData.Difficulties,
    Default = "Normal",
    Callback = function(val)
        State.StoryDiff = val
        SaveConfigDebounced()
    end
}, "Dropdown_StoryDiff")

Sections.Story:Button({
    Name = "Create Story Now",
    Callback = function()
        local ok, err = CreateRoom("Story", State.StoryMap, State.StoryStage, State.StoryDiff, true)
        if not ok then
            Window:Notify({ Title = "Auto Create", Description = tostring(err), Lifetime = 3 })
        else
            Window:Notify({ Title = "Auto Create", Description = "Story lobby created!", Lifetime = 3 })
        end
    end
})

-- [Menu] Mysterious Mode
Sections.Mysterious:Header({ Text = "Mysterious Mode" })

Sections.Mysterious:Toggle({
    Name = "Auto Create Mysterious",
    Default = false,
    Callback = function(val)
        if isUpdatingAutoCreate then return end
        if val then
            SetAutoCreateMode("Mysterious")
        elseif State.ActiveAutoCreate == "Mysterious" then
            SetAutoCreateMode("None")
        end
    end
}, "Toggle_AutoMysterious")

local MysteriousStageDropdown
Sections.Mysterious:Dropdown({
    Name = "Select Mysterious Map",
    Multi = false,
    Required = true,
    Options = GameData.Mysterious.Maps,
    Default = GameData.Mysterious.Maps[1] or "",
    Callback = function(val)
        State.MysteriousMap = val
        SaveConfigDebounced()
        local id = GameData.Mysterious.DisplayToId[val]
        if id and MysteriousStageDropdown then
            local stages = GameData.Mysterious.Stages[id] or { "1" }
            MysteriousStageDropdown:ClearOptions()
            MysteriousStageDropdown:InsertOptions(stages)
            MysteriousStageDropdown:UpdateSelection(stages[1] or "1")
        end
    end
}, "Dropdown_MysteriousMap")

MysteriousStageDropdown = Sections.Mysterious:Dropdown({
    Name = "Select Mysterious Stage",
    Multi = false,
    Required = true,
    Options = (GameData.Mysterious.Maps[1] and GameData.Mysterious.Stages[GameData.Mysterious.DisplayToId[GameData.Mysterious.Maps[1]]]) or { "1", "2", "3" },
    Default = "1",
    Callback = function(val)
        State.MysteriousStage = tostring(val)
        SaveConfigDebounced()
    end
}, "Dropdown_MysteriousStage")

Sections.Mysterious:Dropdown({
    Name = "Select Mysterious Difficulty",
    Multi = false,
    Required = true,
    Options = GameData.Difficulties,
    Default = "Normal",
    Callback = function(val)
        State.MysteriousDiff = val
        SaveConfigDebounced()
    end
}, "Dropdown_MysteriousDiff")

Sections.Mysterious:Button({
    Name = "Create Mysterious Now",
    Callback = function()
        local ok, err = CreateRoom("Mysterios", State.MysteriousMap, State.MysteriousStage, State.MysteriousDiff, true)
        if not ok then
            Window:Notify({ Title = "Auto Create", Description = tostring(err), Lifetime = 3 })
        else
            Window:Notify({ Title = "Auto Create", Description = "Mysterious lobby created!", Lifetime = 3 })
        end
    end
})

-- [Menu] Raids Mode
Sections.Raids:Header({ Text = "Raids Mode" })

Sections.Raids:Toggle({
    Name = "Auto Create Raids",
    Default = false,
    Callback = function(val)
        if isUpdatingAutoCreate then return end
        if val then
            SetAutoCreateMode("Raids")
        elseif State.ActiveAutoCreate == "Raids" then
            SetAutoCreateMode("None")
        end
    end
}, "Toggle_AutoRaids")

local RaidsStageDropdown
Sections.Raids:Dropdown({
    Name = "Select Raids Map",
    Multi = false,
    Required = true,
    Options = GameData.Raids.Maps,
    Default = GameData.Raids.Maps[1] or "",
    Callback = function(val)
        State.RaidsMap = val
        SaveConfigDebounced()
        local id = GameData.Raids.DisplayToId[val]
        if id and RaidsStageDropdown then
            local stages = GameData.Raids.Stages[id] or { "1" }
            RaidsStageDropdown:ClearOptions()
            RaidsStageDropdown:InsertOptions(stages)
            RaidsStageDropdown:UpdateSelection(stages[1] or "1")
        end
    end
}, "Dropdown_RaidsMap")

RaidsStageDropdown = Sections.Raids:Dropdown({
    Name = "Select Raids Stage",
    Multi = false,
    Required = true,
    Options = (GameData.Raids.Maps[1] and GameData.Raids.Stages[GameData.Raids.DisplayToId[GameData.Raids.Maps[1]]]) or { "1", "2", "3" },
    Default = "1",
    Callback = function(val)
        State.RaidsStage = tostring(val)
        SaveConfigDebounced()
    end
}, "Dropdown_RaidsStage")

Sections.Raids:Dropdown({
    Name = "Select Raids Difficulty",
    Multi = false,
    Required = true,
    Options = GameData.Difficulties,
    Default = "Normal",
    Callback = function(val)
        State.RaidsDiff = val
        SaveConfigDebounced()
    end
}, "Dropdown_RaidsDiff")

Sections.Raids:Button({
    Name = "Create Raids Now",
    Callback = function()
        local ok, err = CreateRoom("Raids", State.RaidsMap, State.RaidsStage, State.RaidsDiff, true)
        if not ok then
            Window:Notify({ Title = "Auto Create", Description = tostring(err), Lifetime = 3 })
        else
            Window:Notify({ Title = "Auto Create", Description = "Raids lobby created!", Lifetime = 3 })
        end
    end
})

-- [Menu] Boss Event
Sections.Boss:Header({ Text = "Boss Event" })

Sections.Boss:Toggle({
    Name = "Auto Create Boss Event",
    Default = false,
    Callback = function(val)
        if isUpdatingAutoCreate then return end
        if val then
            SetAutoCreateMode("Boss")
        elseif State.ActiveAutoCreate == "Boss" then
            SetAutoCreateMode("None")
        end
    end
}, "Toggle_AutoBoss")

local BossStageDropdown
Sections.Boss:Dropdown({
    Name = "Select Boss Map",
    Multi = false,
    Required = true,
    Options = GameData.Boss.Maps,
    Default = GameData.Boss.Maps[1] or "",
    Callback = function(val)
        State.BossMap = val
        SaveConfigDebounced()
        local id = GameData.Boss.DisplayToId[val]
        if id and BossStageDropdown then
            local stages = GameData.Boss.Stages[id] or { "1" }
            BossStageDropdown:ClearOptions()
            BossStageDropdown:InsertOptions(stages)
            BossStageDropdown:UpdateSelection(stages[1] or "1")
        end
    end
}, "Dropdown_BossMap")

BossStageDropdown = Sections.Boss:Dropdown({
    Name = "Select Boss Stage",
    Multi = false,
    Required = true,
    Options = (GameData.Boss.Maps[1] and GameData.Boss.Stages[GameData.Boss.DisplayToId[GameData.Boss.Maps[1]]]) or { "1" },
    Default = "1",
    Callback = function(val)
        State.BossStage = tostring(val)
        SaveConfigDebounced()
    end
}, "Dropdown_BossStage")

Sections.Boss:Dropdown({
    Name = "Select Boss Difficulty",
    Multi = false,
    Required = true,
    Options = GameData.Difficulties,
    Default = "Normal",
    Callback = function(val)
        State.BossDiff = val
        SaveConfigDebounced()
    end
}, "Dropdown_BossDiff")

Sections.Boss:Button({
    Name = "Create Boss Now",
    Callback = function()
        local ok, err = CreateRoom("Event", State.BossMap, State.BossStage, State.BossDiff, true)
        if not ok then
            Window:Notify({ Title = "Auto Create", Description = tostring(err), Lifetime = 3 })
        else
            Window:Notify({ Title = "Auto Create", Description = "Boss Event lobby created!", Lifetime = 3 })
        end
    end
})

-- [Menu] Match Start
Sections.MatchStart:Header({ Text = "Match Start" })

Sections.MatchStart:Toggle({
    Name = "Auto Start",
    Default = false,
    Callback = function(val)
        State.AutoStart = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoStart")

-- ====================================================================
-- TAB 2: CHALLENGES
-- ====================================================================
local ChallengeSections = {
    Main = Tabs.Challenges:Section({ Side = "Left" }),
    Info = Tabs.Challenges:Section({ Side = "Right" })
}

ChallengeSections.Main:Header({ Text = "Challenge" })

ChallengeSections.Main:Toggle({
    Name = "Auto Challenges",
    Default = false,
    Callback = function(val)
        State.AutoChallenges = val
        SaveConfigDebounced()
        if val and ProcessAutoChallenges then
            task.spawn(ProcessAutoChallenges)
        end
    end
}, "Toggle_AutoChallenges")

ChallengeSections.Main:Toggle({
    Name = "Auto Leave",
    Default = false,
    Callback = function(val)
        State.AutoLeaveChallenge = val
        SaveConfigDebounced()
        if val then
            task.spawn(CheckAndExecuteAutoLeave)
        end
    end
}, "Toggle_AutoLeaveChallenge")

ChallengeSections.Main:Toggle({
    Name = "Auto Leave On Reset",
    Default = false,
    Callback = function(val)
        State.AutoLeaveOnChallengeReset = val
        SaveConfigDebounced()
        if val then
            task.spawn(CheckChallengeResetLeave)
        end
    end
}, "Toggle_AutoLeaveOnChallengeReset")

ChallengeSections.Main:Dropdown({
    Name = "Target Challenges",
    Multi = true,
    Required = false,
    Options = { "Weekly", "Daily", "Regular" },
    Default = { "Weekly", "Daily", "Regular" },
    Callback = function(val)
        State.TargetChallenges = {}
        for target, enabled in pairs(val) do
            if enabled then
                State.TargetChallenges[target] = true
            end
        end
        SaveConfigDebounced()
    end
}, "Dropdown_TargetChallenges")

ChallengeSections.Info:Header({ Text = "Active Rotation Info" })
local ChallengeInfoLabel = ChallengeSections.Info:Label({ Text = "Checking challenge status..." })

local function UpdateChallengeInfoDisplay()
    local ok, data = pcall(function() return GetChallengeData:InvokeServer() end)
    if ok and data then
        local replica = PlayModule.Replica or _G.PlayerDataReplica
        local cleared = replica and replica.Data and replica.Data.ClearedChallenges or {}
        
        local text = ""
        for _, modeName in ipairs({ "Weekly", "Daily", "Regular" }) do
            local ch = data[modeName]
            if ch then
                local isCleared = (ch.PeriodIndex or 0) <= (cleared[modeName] or 0)
                text = text .. string.format("[%s] %s (Stage %s) - %s\n", modeName, ch.MapName or ch.MapToCreate, tostring(ch.StageName), isCleared and "CLEARED" or "AVAILABLE")
            end
        end
        ChallengeInfoLabel:UpdateName(text)
    end
end

ChallengeSections.Info:Button({
    Name = "Refresh Challenge Info",
    Callback = UpdateChallengeInfoDisplay
})

-- ====================================================================
-- TAB 3: GAMEPLAY
-- ====================================================================
local GameplaySections = {
    Settings = Tabs.Gameplay:Section({ Side = "Left" }),
    Controls = Tabs.Gameplay:Section({ Side = "Right" })
}

-- [Menu] Gameplay Setting
GameplaySections.Settings:Header({ Text = "Gameplay Setting" })

for _, sInfo in ipairs(GameSettingsMap) do
    GameplaySections.Settings:Toggle({
        Name = sInfo.Label,
        Default = State[sInfo.StateKey],
        Callback = function(val)
            State[sInfo.StateKey] = val
            SaveConfigDebounced()
            if not isSyncingFromGame then
                SetGameSetting(sInfo.GuiName, val, sInfo.SettingKey)
            end
        end
    }, sInfo.OptFlag)
end

GameplaySections.Settings:Toggle({
    Name = "Auto Defend (Money Units)",
    Default = (State.AutoDefendMoneyUnits ~= false),
    Callback = function(val)
        State.AutoDefendMoneyUnits = val
        SaveConfigDebounced()
        if val then
            HandleAutoDefendMoneyUnits()
        end
    end
}, "Toggle_AutoDefendMoneyUnits")

GameplaySections.Settings:Divider()
GameplaySections.Settings:Header({ Text = "Fate Event Automation" })

GameplaySections.Settings:Toggle({
    Name = "Auto Fate Swords",
    Default = (State.AutoSolveFateSword ~= false),
    Callback = function(val)
        State.AutoSolveFateSword = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoSolveFateSword")

GameplaySections.Controls:Header({ Text = "Game Controls" })

GameplaySections.Controls:Button({
    Name = "Sync All In-Game Settings",
    Callback = function()
        for _, sInfo in ipairs(GameSettingsMap) do
            SetGameSetting(sInfo.GuiName, State[sInfo.StateKey], sInfo.SettingKey)
        end
        Window:Notify({
            Title = "Gameplay Settings",
            Description = "Synchronized all settings with game!",
            Lifetime = 3
        })
    end
})

GameplaySections.Controls:Button({
    Name = "Back To Spawn",
    Callback = function()
        pcall(function()
            local Aleart = select(2, pcall(require, ReplicatedStorage.Modules.Aleart))
            if Aleart and Aleart.Show then Aleart.Show("Back to spawn.") end
            local Character = LocalPlayer.Character
            local spawnLoc = workspace:FindFirstChild("BaseMap") and workspace.BaseMap:FindFirstChild("SpawnLocation")
            if Character and Character:FindFirstChild("HumanoidRootPart") and spawnLoc then
                Character.HumanoidRootPart.CFrame = spawnLoc.CFrame + Vector3.new(0, 5, 0)
                if Remotes and Remotes:FindFirstChild("TeleportRequest") then
                    Remotes.TeleportRequest:FireServer("Spawn")
                end
            end
        end)
    end
})

GameplaySections.Controls:Button({
    Name = "Restart Match",
    Callback = function()
        pcall(function()
            local ForceEndGame = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("ForceEndGameRequest")
            if ForceEndGame then
                ForceEndGame:FireServer("Lose")
            end
        end)
    end
})

GameplaySections.Controls:Button({
    Name = "Return To Lobby",
    Callback = function()
        pcall(function()
            local TeleportService = game:GetService("TeleportService")
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)
    end
})

-- ====================================================================
-- TAB 4: SUMMON & SHOP
-- ====================================================================
local SummonShopSections = {
    Summon = Tabs.SummonShop:Section({ Side = "Left" }),
    GemsShop = Tabs.SummonShop:Section({ Side = "Right" }),
    GoldShop = Tabs.SummonShop:Section({ Side = "Right" })
}

-- [Menu] Summon
SummonShopSections.Summon:Header({ Text = "Summon" })

SummonShopSections.Summon:Toggle({
    Name = "Auto Summon",
    Default = false,
    Callback = function(val)
        State.AutoSummon = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoSummon")

SummonShopSections.Summon:Dropdown({
    Name = "Select Banner",
    Multi = false,
    Required = true,
    Options = GameData.Banners,
    Default = "Standard",
    Callback = function(val)
        State.SummonBanner = val
        SaveConfigDebounced()
    end
}, "Dropdown_SummonBanner")

SummonShopSections.Summon:Dropdown({
    Name = "Summon Amount",
    Multi = false,
    Required = true,
    Options = { "10x", "1x" },
    Default = "10x",
    Callback = function(val)
        State.SummonAmount = val
        SaveConfigDebounced()
    end
}, "Dropdown_SummonAmount")

-- [Menu] Gems Shop
SummonShopSections.GemsShop:Header({ Text = "Gems Shop" })

SummonShopSections.GemsShop:Toggle({
    Name = "Auto Buy Gems Shop",
    Default = false,
    Callback = function(val)
        State.AutoBuyGems = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyGems")

SummonShopSections.GemsShop:Dropdown({
    Name = "Select Items",
    Multi = true,
    Required = false,
    Options = GameData.GemsItems,
    Default = {},
    Callback = function(val)
        State.SelectedGemsItems = {}
        if type(val) == "table" then
            for k, v in pairs(val) do
                local itemLabel = (v == true and type(k) == "string") and k or (type(v) == "string" and v)
                if itemLabel then
                    local itemData = GameData.GemsItemMap[itemLabel]
                    local id = itemData and itemData.ID or (GameData.GemsIdToLabel[itemLabel] and itemLabel)
                    if id and not table.find(State.SelectedGemsItems, id) then
                        table.insert(State.SelectedGemsItems, id)
                    end
                end
            end
        end
        SaveConfigDebounced()
    end
}, "Dropdown_GemsItems")

-- [Menu] Gold Shop
SummonShopSections.GoldShop:Header({ Text = "Gold Shop" })

SummonShopSections.GoldShop:Toggle({
    Name = "Auto Buy Gold Shop",
    Default = false,
    Callback = function(val)
        State.AutoBuyGold = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyGold")

SummonShopSections.GoldShop:Dropdown({
    Name = "Select Items",
    Multi = true,
    Required = false,
    Options = GameData.GoldItems,
    Default = {},
    Callback = function(val)
        State.SelectedGoldItems = {}
        if type(val) == "table" then
            for k, v in pairs(val) do
                local itemLabel = (v == true and type(k) == "string") and k or (type(v) == "string" and v)
                if itemLabel then
                    local itemData = GameData.GoldItemMap[itemLabel]
                    local id = itemData and itemData.ID or (GameData.GoldIdToLabel[itemLabel] and itemLabel)
                    if id and not table.find(State.SelectedGoldItems, id) then
                        table.insert(State.SelectedGoldItems, id)
                    end
                end
            end
        end
        SaveConfigDebounced()
    end
}, "Dropdown_GoldItems")

-- ====================================================================
-- TAB 5: SETTINGS
-- ====================================================================
local SettingsSections = {
    Controls = Tabs.Settings:Section({ Side = "Left" }),
    Config = Tabs.Settings:Section({ Side = "Right" })
}

SettingsSections.Controls:Header({ Text = "Interface Controls" })

SettingsSections.Controls:Toggle({
    Name = "Acrylic Blur Background",
    Default = (State.AcrylicBlur == true),
    Callback = function(v)
        State.AcrylicBlur = v
        if Window and Window.SetAcrylicBlurState then
            Window:SetAcrylicBlurState(v)
        end
        SaveConfigDebounced()
    end
}, "Toggle_AcrylicBlur")

SettingsSections.Controls:Toggle({
    Name = "Show User Information",
    Default = (State.ShowUserInfo ~= false),
    Callback = function(v)
        State.ShowUserInfo = v
        if Window and Window.SetUserInfoState then
            Window:SetUserInfoState(v)
        end
        SaveConfigDebounced()
    end
}, "Toggle_ShowUserInfo")

SettingsSections.Controls:Toggle({
    Name = "Mobile Floating Button",
    Default = (State.MobileToggle ~= false),
    Callback = function(v)
        State.MobileToggle = v
        if getgenv().STRIX_MOBILE_GUI then
            getgenv().STRIX_MOBILE_GUI.Enabled = v
        end
        SaveConfigDebounced()
    end
}, "Toggle_MobileToggle")

SettingsSections.Controls:Keybind({
    Name = "Open/Hide Keybind",
    Blacklist = false,
    Default = (State.Keybind and State.Keybind ~= Enum.KeyCode.Unknown) and State.Keybind or Enum.KeyCode.RightControl,
    Callback = function(binded)
        State.Keybind = binded
        if Window and Window.SetKeybind then
            Window:SetKeybind(binded)
        end
        SaveConfigDebounced()
    end,
    onBinded = function(bind)
        if bind and bind ~= Enum.KeyCode.Unknown then
            State.Keybind = bind
            if Window and Window.SetKeybind then
                Window:SetKeybind(bind)
            end
            SaveConfigDebounced()
        end
    end
}, "Keybind_ToggleUI")

SettingsSections.Config:Header({ Text = "Config Manager" })
SettingsSections.Config:Label({ Text = "Auto Save: Active (Realtime)" })
SettingsSections.Config:Label({ Text = "File: workspace\\" .. ConfigFile })

SettingsSections.Config:Button({
    Name = "Save Config Now",
    Callback = function()
        SaveConfig()
        Window:Notify({ Title = "Config", Description = "Saved to " .. LocalPlayer.Name .. ".json", Lifetime = 3 })
    end
})

local LoadConfig

SettingsSections.Config:Button({
    Name = "Reload Config",
    Callback = function()
        if LoadConfig then LoadConfig() end
        Window:Notify({ Title = "Config", Description = "Reloaded from " .. LocalPlayer.Name .. ".json", Lifetime = 3 })
    end
})

SettingsSections.Config:Divider()

SettingsSections.Config:Header({ Text = "Hub Management" })

SettingsSections.Config:Button({
    Name = "Unload STRIX HUB",
    Callback = function()
        pcall(function()
            if _G.STRIX_HUB_CLEANUP then
                pcall(_G.STRIX_HUB_CLEANUP)
            end
            if Window and Window.Unload then
                Window:Unload()
            end
            if getgenv().STRIX_MOBILE_GUI then
                pcall(function() getgenv().STRIX_MOBILE_GUI:Destroy() end)
                getgenv().STRIX_MOBILE_GUI = nil
            end
        end)
    end
})

-- ====================================================================
-- PRIORITY LOGIC RUNNER
-- [Priority] Auto Buy > Auto Challenges > Auto Create
-- ====================================================================

local function ProcessAutoBuy()
    local didBuy = false
    
    -- Gems Shop
    if State.AutoBuyGems and #State.SelectedGemsItems > 0 then
        local currentGems = LocalPlayer:GetAttribute("Gems") or 0
        for _, itemId in ipairs(State.SelectedGemsItems) do
            for _, itemConfig in pairs(GameData.GemsItemMap) do
                if itemConfig.ID == itemId and currentGems >= itemConfig.Price then
                    local stock = GemsShopModule:GetStockLeft(itemId, itemConfig.MaxStock)
                    local affordable = math.floor(currentGems / itemConfig.Price)
                    local buyCount = math.min(stock, affordable)
                    if buyCount > 0 then
                        local ok, success, msg = pcall(function()
                            return BuyItem:InvokeServer(itemId, buyCount, "Gems")
                        end)
                        if ok and success then
                            currentGems = currentGems - (buyCount * itemConfig.Price)
                            didBuy = true
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
    
    -- Gold Shop
    if State.AutoBuyGold and #State.SelectedGoldItems > 0 then
        local currentCoins = LocalPlayer:GetAttribute("Coins") or 0
        for _, itemId in ipairs(State.SelectedGoldItems) do
            for _, itemConfig in pairs(GameData.GoldItemMap) do
                if itemConfig.ID == itemId and currentCoins >= itemConfig.Price then
                    local stock = ShopModule:GetStockLeft(itemId, itemConfig.MaxStock)
                    local affordable = math.floor(currentCoins / itemConfig.Price)
                    local buyCount = math.min(stock, affordable)
                    if buyCount > 0 then
                        local ok, success, msg = pcall(function()
                            return BuyItem:InvokeServer(itemId, buyCount, "Coins")
                        end)
                        if ok and success then
                            currentCoins = currentCoins - (buyCount * itemConfig.Price)
                            didBuy = true
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
    
    return didBuy
end

local challengeDebounce = false

ProcessAutoChallenges = function()
    if challengeDebounce then return true end
    if game.PlaceId ~= 117949143041402 then return false end -- Only execute in Lobby
    
    local PlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
    local pf = PlayGUI and PlayGUI:FindFirstChild("PlayFrame")
    
    -- Case 1: PlayFrame is already open -> Press "Play" only if it is confirmed to be a Challenge room
    if pf and pf.Visible then
        local isPfChallenge = false
        if PlayModule and (PlayModule.SessionMode == "Challange" or PlayModule.SessionMode == "Challenge") then
            isPfChallenge = true
        end
        for _, lbl in ipairs(pf:GetDescendants()) do
            if lbl:IsA("TextLabel") and string.find(string.lower(lbl.Text), "challenge") then
                isPfChallenge = true
                break
            end
        end

        if not isPfChallenge then
            return false
        end

        if not PlayGUI.Enabled then
            PlayGUI.Enabled = true
        end
        local playBtn = pf:FindFirstChild("ContainerBtn") and pf.ContainerBtn:FindFirstChild("PlayBtn")
        if playBtn and playBtn.Visible then
            if playBtn.Text == "Teleporting..." then
                return true
            end
            if playBtn.Text == "Play" or playBtn.Interactable then
                challengeDebounce = true
                SafeClick(playBtn)
                -- Feature 4: Cross-server tracking
                getgenv().STRIX_IS_CHALLENGE_MATCH = true
                pcall(function()
                    if queue_on_teleport then
                        queue_on_teleport("getgenv().STRIX_IS_CHALLENGE_MATCH = true")
                    end
                end)
                task.delay(2.5, function() challengeDebounce = false end)
                return true
            end
        end
        return true
    end
    
    -- Case 2: Fetch challenge data and find uncleared target challenge
    local ok, challengeData = pcall(function() return GetChallengeData:InvokeServer() end)
    if not (ok and challengeData) then return false end
    
    local replica = PlayModule and PlayModule.Replica or _G.PlayerDataReplica or GetReplicaData()
    local cleared = (replica and replica.Data and replica.Data.ClearedChallenges) or (replica and replica.ClearedChallenges) or {}
    
    -- Priority sequence: Weekly > Daily > Regular
    local priorityList = { "Weekly", "Daily", "Regular" }
    local targetType = nil
    for _, chType in ipairs(priorityList) do
        if State.TargetChallenges[chType] then
            local data = challengeData[chType]
            if data then
                local period = data.PeriodIndex or 0
                local clearedPeriod = cleared[chType] or 0
                if period > clearedPeriod then
                    targetType = chType
                    break
                end
            end
        end
    end
    
    if not targetType then
        return false -- All target challenges cleared!
    end
    
    local cInfo = challengeData[targetType]
    if not cInfo then return false end
    
    challengeDebounce = true
    task.spawn(function()
        pcall(function()
            local mapTitle = targetType .. " Challenge"
            local modeTitle = targetType .. "Challenge"
            local stageName = tostring(cInfo.StageName or "1")
            local rewards = { Items = {} }
            
            if cInfo.Rewards then
                for _, r in ipairs(cInfo.Rewards) do
                    if r.Id == "Coins" then
                        rewards.Coins = r.Amount
                    elseif r.Id == "Gems" then
                        rewards.Gems = r.Amount
                    else
                        table.insert(rewards.Items, { Chance = 100, Id = r.Id, Count = r.Amount })
                    end
                end
            end
            
            -- Feature 2: Direct Remote Lobby Creation (Zero UI Navigation)
            if not IsRoomCreated() then
                pcall(function()
                    if RequestJoinLobby then
                        RequestJoinLobby:InvokeServer("Create")
                    end
                end)
            end
            
            if PlayModule then
                PlayModule.SessionMode = "Challange"
                PlayModule.isHost = true
            end
            
            pcall(function()
                if UpdateLobbySettings then
                    UpdateLobbySettings:FireServer(mapTitle, stageName, rewards, "Nightmare", cInfo.MapToCreate, modeTitle)
                end
            end)
            
            task.wait(0.35)
            
            -- Feature 4: Cross-Server State Tracking via queue_on_teleport
            getgenv().STRIX_IS_CHALLENGE_MATCH = true
            pcall(function()
                if queue_on_teleport then
                    queue_on_teleport("getgenv().STRIX_IS_CHALLENGE_MATCH = true")
                end
            end)
            
            -- Feature 3: Dual-Trigger Match Start & Teleport Reliability
            -- 1. Click PlayBtn in PlayFrame if present
            local currentPlayGUI = LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
            local currentPf = currentPlayGUI and currentPlayGUI:FindFirstChild("PlayFrame")
            if currentPf and currentPf.Visible then
                local playBtn = currentPf:FindFirstChild("ContainerBtn") and currentPf.ContainerBtn:FindFirstChild("PlayBtn")
                if playBtn and playBtn.Visible and playBtn.Text ~= "Teleporting..." then
                    SafeClick(playBtn)
                end
            end
            
            -- 2. Direct TeleportRequest firing (Dual-Trigger failsafe)
            if TeleportRequest then
                pcall(function()
                    TeleportRequest:FireServer(107610426295102, modeTitle, cInfo.MapToCreate, stageName, "Nightmare")
                end)
                pcall(function()
                    TeleportRequest:FireServer(97246719761307, modeTitle, cInfo.MapToCreate, stageName, "Nightmare")
                end)
            end
        end)
        
        task.wait(2.5)
        challengeDebounce = false
    end)
    
    return true
end

local function ProcessAutoCreate()
    if IsRoomCreated() then return end
    
    if State.ActiveAutoCreate == "Story" then
        CreateRoom("Story", State.StoryMap, State.StoryStage, State.StoryDiff)
    elseif State.ActiveAutoCreate == "Mysterious" then
        CreateRoom("Mysterios", State.MysteriousMap, State.MysteriousStage, State.MysteriousDiff)
    elseif State.ActiveAutoCreate == "Raids" then
        CreateRoom("Raids", State.RaidsMap, State.RaidsStage, State.RaidsDiff)
    elseif State.ActiveAutoCreate == "Boss" then
        CreateRoom("Event", State.BossMap, State.BossStage, State.BossDiff)
    end
end

local function GetAutoSellSettings()
    -- 1. Try from SummonController.ActiveInstance.AutoSellSettings
    local okSC, sc = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("SummonController", 3))
    end)
    if okSC and sc and sc.ActiveInstance and sc.ActiveInstance.AutoSellSettings then
        return sc.ActiveInstance.AutoSellSettings
    end
    
    -- 2. Try from PlayerDataReplica.Data.Config
    local replica = _G.PlayerDataReplica or (PlayModule and PlayModule.Replica)
    if replica and replica.Data and replica.Data.Config then
        local config = replica.Data.Config
        local sellSettings = {
            Common = false,
            Rare = false,
            Epic = false,
            Legendary = false,
            Rare_Shiny = false,
            Epic_Shiny = false,
            Legendary_Shiny = false
        }
        if config.AutosellRarity then
            for k, v in pairs(config.AutosellRarity) do
                if sellSettings[k] ~= nil then
                    sellSettings[k] = v
                end
            end
        end
        if config.AutosellRarityShiny then
            for k, v in pairs(config.AutosellRarityShiny) do
                local shinyKey = k .. "_Shiny"
                if sellSettings[shinyKey] ~= nil then
                    sellSettings[shinyKey] = v
                end
            end
        end
        return sellSettings
    end
    
    -- 3. Fallback: check UI buttons in SummonFrame.AutoSellContainer
    local sf = LocalPlayer.PlayerGui:FindFirstChild("Main") and LocalPlayer.PlayerGui.Main:FindFirstChild("MainFrame") and LocalPlayer.PlayerGui.Main.MainFrame:FindFirstChild("SummonFrame")
    local container = sf and sf:FindFirstChild("AutoSellContainer")
    if container then
        local sellSettings = {
            Common = false,
            Rare = false,
            Epic = false,
            Legendary = false,
            Rare_Shiny = false,
            Epic_Shiny = false,
            Legendary_Shiny = false
        }
        local normalFrame = container:FindFirstChild("AutoSellFrame")
        if normalFrame then
            for _, r in ipairs({ "Rare", "Epic", "Legendary" }) do
                local btn = normalFrame:FindFirstChild(r)
                if btn and btn:FindFirstChild("Inner") and btn.Inner:FindFirstChild("Active") then
                    sellSettings[r] = btn.Inner.Active.Visible
                end
            end
        end
        local shinyFrame = container:FindFirstChild("AutoSellFrameShiny") or container:FindFirstChild("AutoSellShinyFrame")
        if shinyFrame then
            for _, r in ipairs({ "Rare", "Epic", "Legendary" }) do
                local btn = shinyFrame:FindFirstChild(r)
                if btn and btn:FindFirstChild("Inner") and btn.Inner:FindFirstChild("Active") then
                    sellSettings[r .. "_Shiny"] = btn.Inner.Active.Visible
                end
            end
        end
        return sellSettings
    end
    
    return {}
end

local function GetSummonPrice(banner)
    local isVIP = false
    local okSC, sc = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("SummonController", 3))
    end)
    if okSC and sc and sc.ActiveInstance and sc.ActiveInstance.LocalReplica then
        local rep = sc.ActiveInstance.LocalReplica
        if rep.Data and rep.Data.OwnedGamePasses and rep.Data.OwnedGamePasses.VIP == true then
            isVIP = true
        end
    end

    local basePrice = 50
    if banner == "Standard" then
        local okC, cfg = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("SummonConfig", 3))
        end)
        if okC and cfg and cfg.Price then
            basePrice = cfg.Price
        end
    elseif banner == "Fate" then
        local okF, fateCfg = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("Data", 3):WaitForChild("FateSummonData", 3))
        end)
        if okF and fateCfg and fateCfg.Price then
            basePrice = fateCfg.Price
        end
    end

    local singlePrice = isVIP and math.floor(basePrice * 0.7) or basePrice
    local tenPrice = isVIP and math.floor(basePrice * 10 * 0.7) or (basePrice * 10)
    return singlePrice, tenPrice
end

local function GetSummonCurrency(banner)
    if banner == "Standard" then
        return LocalPlayer:GetAttribute("Gems") or 0
    elseif banner == "Fate" then
        local attr = LocalPlayer:GetAttribute("FateCoins")
        if attr and attr > 0 then return attr end
        local okSC, sc = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("SummonController", 3))
        end)
        if okSC and sc and sc.ActiveInstance and sc.ActiveInstance.LocalReplica then
            local rep = sc.ActiveInstance.LocalReplica
            if rep.Data and rep.Data.ItemInventory and rep.Data.ItemInventory.FateCoins then
                return rep.Data.ItemInventory.FateCoins
            end
        end
        return attr or 0
    end
    return 0
end

local function ProcessAutoSummon()
    if not State.AutoSummon then return end
    local banner = State.SummonBanner or "Standard"
    local wantTen = (State.SummonAmount == "10x")
    local singlePrice, tenPrice = GetSummonPrice(banner)
    local currency = GetSummonCurrency(banner)
    local currencyName = (banner == "Fate") and "Fate Coins" or "Gems"

    -- Currency is completely exhausted (not enough even for 1 roll)
    if currency < singlePrice then
        State.AutoSummon = false
        SaveConfigDebounced()
        if MacLib.Options["Toggle_AutoSummon"] then
            MacLib.Options["Toggle_AutoSummon"]:UpdateState(false)
        end
        pcall(function()
            Window:Notify({
                Title = "Auto Summon",
                Description = "Out of " .. currencyName .. "! Auto Summon turned OFF.",
                Lifetime = 5
            })
        end)
        return
    end

    -- Determine roll count: prefer 10x if wanted and affordable, otherwise fall back to 1x
    local rollCount = 1
    if wantTen and currency >= tenPrice then
        rollCount = 10
    end

    local autoSell = GetAutoSellSettings()
    pcall(function()
        SummonRequest:InvokeServer(rollCount, autoSell, banner)
    end)
    
    task.wait(1)

    -- Check currency again after roll to see if now exhausted
    local newCurrency = GetSummonCurrency(banner)
    if newCurrency < singlePrice then
        State.AutoSummon = false
        SaveConfigDebounced()
        if MacLib.Options["Toggle_AutoSummon"] then
            MacLib.Options["Toggle_AutoSummon"]:UpdateState(false)
        end
        pcall(function()
            Window:Notify({
                Title = "Auto Summon",
                Description = "Out of " .. currencyName .. "! Auto Summon turned OFF.",
                Lifetime = 5
            })
        end)
    end
end

-- Main Loop
task.spawn(function()
    while isScriptRunning do
        task.wait(1)
        if not isScriptRunning then break end
        -- Priority 1: Auto Buy
        local didBuy = false
        if State.AutoBuyGems or State.AutoBuyGold then
            didBuy = ProcessAutoBuy()
        end
        
        if not didBuy then
            -- Auto Solve Fate Swords (In Gameplay)
            if isBattlePlace and State.AutoSolveFateSword and workspace:GetAttribute("SwordEventActive") == true then
                SolveFateSwordEvent()
            end

            -- Auto Defend Money Units (In Gameplay)
            if isBattlePlace and State.AutoDefendMoneyUnits then
                HandleAutoDefendMoneyUnits()
            end

            -- Auto Leave Challenge (In Gameplay)
            if State.AutoLeaveChallenge then
                CheckAndExecuteAutoLeave()
            end
            if State.AutoLeaveOnChallengeReset then
                CheckChallengeResetLeave()
            end
            
            -- Priority 2: Auto Challenges
            local challengeActive = false
            if State.AutoChallenges then
                challengeActive = ProcessAutoChallenges()
            end
            
            -- Priority 3: Auto Create (Only if challenges not active/completed)
            if not challengeActive and State.ActiveAutoCreate ~= "None" then
                ProcessAutoCreate()
            end
        end
        
        -- Auto Start (Checks if room is created and starts match)
        if State.AutoStart and IsRoomCreated() then
            task.wait(0.5)
            TriggerMatchStart()
        end
        
        -- Auto Summon
        if State.AutoSummon then
            ProcessAutoSummon()
        end
    end
end)

-- ====================================================================
-- AUTO RUN: LOAD CONFIG ON START
-- ====================================================================
LoadConfig = function()
    isLoadingConfig = true
    EnsureFolders()
    local targetFile = ConfigFile
    if not isfile(targetFile) then
        local oldFile = ConfigFolder .. "/" .. tostring(LocalPlayer.UserId) .. ".json"
        if isfile(oldFile) then
            targetFile = oldFile
        end
    end
    if isfile(targetFile) then
        local content = readfile(targetFile)
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if ok and type(data) == "table" then
            if data.ActiveAutoCreate then
                SetAutoCreateMode(data.ActiveAutoCreate)
            end
            local function CleanMapName(name)
                if not name then return nil end
                return string.gsub(name, "%s*%[.-%]", "")
            end

            if data.StoryMap then
                local sm = CleanMapName(data.StoryMap)
                State.StoryMap = sm
                if MacLib.Options["Dropdown_StoryMap"] then
                    MacLib.Options["Dropdown_StoryMap"]:UpdateSelection(sm)
                end
            end
            if data.StoryStage then
                State.StoryStage = tostring(data.StoryStage)
                if MacLib.Options["Dropdown_StoryStage"] then
                    MacLib.Options["Dropdown_StoryStage"]:UpdateSelection(tostring(data.StoryStage))
                end
            end
            if data.StoryDiff then
                State.StoryDiff = data.StoryDiff
                if MacLib.Options["Dropdown_StoryDiff"] then
                    MacLib.Options["Dropdown_StoryDiff"]:UpdateSelection(data.StoryDiff)
                end
            end
            if data.MysteriousMap then
                local mm = CleanMapName(data.MysteriousMap)
                State.MysteriousMap = mm
                if MacLib.Options["Dropdown_MysteriousMap"] then
                    MacLib.Options["Dropdown_MysteriousMap"]:UpdateSelection(mm)
                end
            end
            if data.MysteriousStage then
                State.MysteriousStage = tostring(data.MysteriousStage)
                if MacLib.Options["Dropdown_MysteriousStage"] then
                    MacLib.Options["Dropdown_MysteriousStage"]:UpdateSelection(tostring(data.MysteriousStage))
                end
            end
            if data.MysteriousDiff then
                State.MysteriousDiff = data.MysteriousDiff
                if MacLib.Options["Dropdown_MysteriousDiff"] then
                    MacLib.Options["Dropdown_MysteriousDiff"]:UpdateSelection(data.MysteriousDiff)
                end
            end
            if data.RaidsMap then
                local rm = CleanMapName(data.RaidsMap)
                State.RaidsMap = rm
                if MacLib.Options["Dropdown_RaidsMap"] then
                    MacLib.Options["Dropdown_RaidsMap"]:UpdateSelection(rm)
                end
            end
            if data.RaidsStage then
                State.RaidsStage = tostring(data.RaidsStage)
                if MacLib.Options["Dropdown_RaidsStage"] then
                    MacLib.Options["Dropdown_RaidsStage"]:UpdateSelection(tostring(data.RaidsStage))
                end
            end
            if data.RaidsDiff then
                State.RaidsDiff = data.RaidsDiff
                if MacLib.Options["Dropdown_RaidsDiff"] then
                    MacLib.Options["Dropdown_RaidsDiff"]:UpdateSelection(data.RaidsDiff)
                end
            end
            if data.BossMap then
                local bm = CleanMapName(data.BossMap)
                State.BossMap = bm
                if MacLib.Options["Dropdown_BossMap"] then
                    MacLib.Options["Dropdown_BossMap"]:UpdateSelection(bm)
                end
            end
            if data.BossStage then
                State.BossStage = tostring(data.BossStage)
                if MacLib.Options["Dropdown_BossStage"] then
                    MacLib.Options["Dropdown_BossStage"]:UpdateSelection(tostring(data.BossStage))
                end
            end
            if data.BossDiff then
                State.BossDiff = data.BossDiff
                if MacLib.Options["Dropdown_BossDiff"] then
                    MacLib.Options["Dropdown_BossDiff"]:UpdateSelection(data.BossDiff)
                end
            end
            if data.AutoStart ~= nil and MacLib.Options["Toggle_AutoStart"] then
                MacLib.Options["Toggle_AutoStart"]:UpdateState(data.AutoStart)
            end
            if data.AutoChallenges ~= nil and MacLib.Options["Toggle_AutoChallenges"] then
                MacLib.Options["Toggle_AutoChallenges"]:UpdateState(data.AutoChallenges)
            end
            if data.AutoLeaveChallenge ~= nil and MacLib.Options["Toggle_AutoLeaveChallenge"] then
                MacLib.Options["Toggle_AutoLeaveChallenge"]:UpdateState(data.AutoLeaveChallenge)
            end
            if data.AutoLeaveOnChallengeReset ~= nil and MacLib.Options["Toggle_AutoLeaveOnChallengeReset"] then
                MacLib.Options["Toggle_AutoLeaveOnChallengeReset"]:UpdateState(data.AutoLeaveOnChallengeReset)
            end
            if data.TargetChallenges and MacLib.Options["Dropdown_TargetChallenges"] then
                local selected = {}
                if type(data.TargetChallenges) == "table" then
                    for k, v in pairs(data.TargetChallenges) do
                        if v == true and type(k) == "string" then
                            table.insert(selected, k)
                        elseif type(v) == "string" then
                            table.insert(selected, v)
                        end
                    end
                end
                MacLib.Options["Dropdown_TargetChallenges"]:UpdateSelection(selected)
            end
            if data.AutoBuyGems ~= nil and MacLib.Options["Toggle_AutoBuyGems"] then
                MacLib.Options["Toggle_AutoBuyGems"]:UpdateState(data.AutoBuyGems)
            end
            if data.SelectedGemsItems and MacLib.Options["Dropdown_GemsItems"] then
                local labelsToSelect = {}
                State.SelectedGemsItems = data.SelectedGemsItems or {}
                if type(data.SelectedGemsItems) == "table" then
                    for _, idOrLabel in ipairs(data.SelectedGemsItems) do
                        local lbl = GameData.GemsIdToLabel[idOrLabel]
                        if lbl then
                            table.insert(labelsToSelect, lbl)
                        elseif GameData.GemsItemMap[idOrLabel] then
                            table.insert(labelsToSelect, idOrLabel)
                        end
                    end
                end
                MacLib.Options["Dropdown_GemsItems"]:UpdateSelection(labelsToSelect)
            end
            if data.AutoBuyGold ~= nil and MacLib.Options["Toggle_AutoBuyGold"] then
                MacLib.Options["Toggle_AutoBuyGold"]:UpdateState(data.AutoBuyGold)
            end
            if data.SelectedGoldItems and MacLib.Options["Dropdown_GoldItems"] then
                local labelsToSelect = {}
                State.SelectedGoldItems = data.SelectedGoldItems or {}
                if type(data.SelectedGoldItems) == "table" then
                    for _, idOrLabel in ipairs(data.SelectedGoldItems) do
                        local lbl = GameData.GoldIdToLabel[idOrLabel]
                        if lbl then
                            table.insert(labelsToSelect, lbl)
                        elseif GameData.GoldItemMap[idOrLabel] then
                            table.insert(labelsToSelect, idOrLabel)
                        end
                    end
                end
                MacLib.Options["Dropdown_GoldItems"]:UpdateSelection(labelsToSelect)
            end
            if data.AutoSummon ~= nil and MacLib.Options["Toggle_AutoSummon"] then
                MacLib.Options["Toggle_AutoSummon"]:UpdateState(data.AutoSummon)
            end
            if data.SummonBanner and MacLib.Options["Dropdown_SummonBanner"] then
                MacLib.Options["Dropdown_SummonBanner"]:UpdateSelection(data.SummonBanner)
            end
            if data.SummonAmount and MacLib.Options["Dropdown_SummonAmount"] then
                MacLib.Options["Dropdown_SummonAmount"]:UpdateSelection(data.SummonAmount)
            end
            if data.Keybind then
                local k = ResolveBind(data.Keybind)
                if k and k ~= Enum.KeyCode.Unknown then
                    State.Keybind = k
                    if Window and Window.SetKeybind then
                        Window:SetKeybind(k)
                    end
                    if MacLib.Options["Keybind_ToggleUI"] then
                        MacLib.Options["Keybind_ToggleUI"]:Bind(k)
                    end
                end
            end
            if data.UISize and data.UISize.Width and data.UISize.Height then
                State.UISize = data.UISize
                local parent = (gethui and gethui()) or game:GetService("CoreGui")
                for _, v in ipairs(parent:GetChildren()) do
                    if v:IsA("ScreenGui") and v:FindFirstChild("Base") then
                        v.Base.Size = UDim2.fromOffset(data.UISize.Width, data.UISize.Height)
                        local s = v.Base:FindFirstChild("Sidebar")
                        local c = v.Base:FindFirstChild("Content")
                        if s and c then
                            s.Size = UDim2.new(0, 240, 1, 0)
                            c.AnchorPoint = Vector2.new(1, 0)
                            c.Position = UDim2.new(1, 0, 0, 0)
                            c.Size = UDim2.new(1, -240, 1, 0)
                        end
                        break
                    end
                end
            end
            if data.AcrylicBlur ~= nil and MacLib.Options["Toggle_AcrylicBlur"] then
                MacLib.Options["Toggle_AcrylicBlur"]:UpdateState(data.AcrylicBlur)
                if Window and Window.SetAcrylicBlurState then
                    Window:SetAcrylicBlurState(data.AcrylicBlur)
                end
            end
            if data.ShowUserInfo ~= nil and MacLib.Options["Toggle_ShowUserInfo"] then
                MacLib.Options["Toggle_ShowUserInfo"]:UpdateState(data.ShowUserInfo)
                if Window and Window.SetUserInfoState then
                    Window:SetUserInfoState(data.ShowUserInfo)
                end
            end
            if data.MobileToggle ~= nil and MacLib.Options["Toggle_MobileToggle"] then
                MacLib.Options["Toggle_MobileToggle"]:UpdateState(data.MobileToggle)
                if getgenv().STRIX_MOBILE_GUI then
                    getgenv().STRIX_MOBILE_GUI.Enabled = data.MobileToggle
                end
            end
            for _, sInfo in ipairs(GameSettingsMap) do
                if data[sInfo.StateKey] ~= nil and MacLib.Options[sInfo.OptFlag] then
                    MacLib.Options[sInfo.OptFlag]:UpdateState(data[sInfo.StateKey])
                    if not isSyncingFromGame then
                        SetGameSetting(sInfo.GuiName, data[sInfo.StateKey], sInfo.SettingKey)
                    end
                end
            end
            if data.AutoSolveFateSword ~= nil then
                State.AutoSolveFateSword = (data.AutoSolveFateSword ~= false)
                if MacLib.Options["Toggle_AutoSolveFateSword"] then
                    MacLib.Options["Toggle_AutoSolveFateSword"]:UpdateState(State.AutoSolveFateSword)
                end
            end
            if data.AutoDefendMoneyUnits ~= nil then
                State.AutoDefendMoneyUnits = (data.AutoDefendMoneyUnits ~= false)
                if MacLib.Options["Toggle_AutoDefendMoneyUnits"] then
                    MacLib.Options["Toggle_AutoDefendMoneyUnits"]:UpdateState(State.AutoDefendMoneyUnits)
                end
            end
            isLoadingConfig = false
        end
    end
    isLoadingConfig = false
end

-- Auto Run on script execution
LoadConfig()
if isBattlePlace and Tabs.Gameplay then
    Tabs.Gameplay:Select()
else
    Tabs.AutoCreate:Select()
end
UpdateChallengeInfoDisplay()

getgenv().STRIX_HUB = {
    Window = Window,
    Tabs = Tabs,
    State = State,
    GameData = GameData,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig
}
getgenv().STRIX_HUB_JOB_ID = game.JobId
