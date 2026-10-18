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

if getgenv().STRIX_HUB_CLEANUP then
    pcall(getgenv().STRIX_HUB_CLEANUP)
end

local isScriptRunning = true
getgenv().STRIX_HUB_CLEANUP = function()
    isScriptRunning = false
    if getgenv().STRIX_ANTI_AFK_CON then
        pcall(function() getgenv().STRIX_ANTI_AFK_CON:Disconnect() end)
        getgenv().STRIX_ANTI_AFK_CON = nil
    end
    if getgenv().STRIX_MOBILE_GUI then
        pcall(function()
            if getgenv().STRIX_MOBILE_GUI.Parent then
                getgenv().STRIX_MOBILE_GUI:Destroy()
            end
        end)
        getgenv().STRIX_MOBILE_GUI = nil
    end
    if getgenv().STRIX_UI_RESIZE_CLEANUP then
        pcall(getgenv().STRIX_UI_RESIZE_CLEANUP)
        getgenv().STRIX_UI_RESIZE_CLEANUP = nil
    end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Place Identification
local LOBBY_PLACE_ID = 117949143041402
local LOBBY_ALT_PLACE_ID = 110388679506690
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
local rawShopModule = Modules and (isLobby and (Modules:WaitForChild("ShopModule", 5) or Modules:FindFirstChild("ShopModule")) or Modules:FindFirstChild("ShopModule"))
local ShopModule = rawShopModule and select(2, pcall(require, rawShopModule)) or nil
local ShopConfig = (rawShopModule and (rawShopModule:FindFirstChild("ShopConfig") or rawShopModule:WaitForChild("ShopConfig", 2)) and select(2, pcall(require, rawShopModule.ShopConfig))) or {}
local ItemDatabase = Modules and (Modules:FindFirstChild("ItemDatabase") or Modules:WaitForChild("ItemDatabase", 5)) and select(2, pcall(require, Modules.ItemDatabase)) or nil
local rawGemsShopModule = Modules and (isLobby and (Modules:WaitForChild("GemsShopModule", 5) or Modules:FindFirstChild("GemsShopModule")) or Modules:FindFirstChild("GemsShopModule"))
local GemsShopModule = rawGemsShopModule and select(2, pcall(require, rawGemsShopModule)) or nil
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

-- Patch 2.6: Enable Smooth Scrolling on Dropdowns (Fix: Dropdown unable to scroll up/down when options exceed height)
local patDropdownFrame = 'local dropdownFrame = Instance%.new%("Frame"%)\r?\n\t*dropdownFrame%.Name = "DropdownFrame"\r?\n\t*dropdownFrame%.BackgroundColor3 = Color3%.fromRGB%(255, 255, 255%)\r?\n\t*dropdownFrame%.BackgroundTransparency = 1\r?\n\t*dropdownFrame%.BorderColor3 = Color3%.fromRGB%(0, 0, 0%)\r?\n\t*dropdownFrame%.BorderSizePixel = 0\r?\n\t*dropdownFrame%.ClipsDescendants = true\r?\n\t*dropdownFrame%.Size = UDim2%.fromScale%(1, 1%)\r?\n\t*dropdownFrame%.Visible = false\r?\n\t*dropdownFrame%.AutomaticSize = Enum%.AutomaticSize%.Y'
local replDropdownFrame = [[local dropdownFrame = Instance.new("ScrollingFrame")
					dropdownFrame.Name = "DropdownFrame"
					dropdownFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					dropdownFrame.BackgroundTransparency = 1
					dropdownFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
					dropdownFrame.BorderSizePixel = 0
					dropdownFrame.ClipsDescendants = true
					dropdownFrame.Position = UDim2.new(0, 0, 0, 38)
					dropdownFrame.Size = UDim2.new(1, 0, 1, -38)
					dropdownFrame.ScrollBarThickness = 3
					dropdownFrame.ScrollBarImageColor3 = Color3.fromRGB(160, 160, 175)
					dropdownFrame.ScrollBarImageTransparency = 0.4
					dropdownFrame.ScrollingDirection = Enum.ScrollingDirection.Y
					dropdownFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
					dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
					dropdownFrame.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
					dropdownFrame.Visible = false]]
rawMaclibSource = rawMaclibSource:gsub(patDropdownFrame, replDropdownFrame)

local patDropdownPad = 'dropdownFrameUIPadding%.PaddingTop = UDim%.new%(0, 38%)\r?\n\t*dropdownFrameUIPadding%.PaddingBottom = UDim%.new%(0, 10%)'
local replDropdownPad = 'dropdownFrameUIPadding.PaddingTop = UDim.new(0, 4)\n\t\t\t\t\tdropdownFrameUIPadding.PaddingBottom = UDim.new(0, 8)\n\t\t\t\t\tdropdownFrameUIPadding.PaddingRight = UDim.new(0, 5)'
rawMaclibSource = rawMaclibSource:gsub(patDropdownPad, replDropdownPad)

local patCalcSize = 'local function CalculateDropdownSize%(%)\r?\n\t*local totalHeight = 0\r?\n\t*local visibleChildrenCount = 0\r?\n\t*local padding = dropdownFrameUIPadding%.PaddingTop%.Offset %+ dropdownFrameUIPadding%.PaddingBottom%.Offset\r?\n\r?\n\t*for _, v in pairs%(dropdownFrame:GetChildren%(%)%) do\r?\n\t*if not v:IsA%("UIComponent"%) and v%.Visible then\r?\n\t*totalHeight %+= v%.AbsoluteSize%.Y\r?\n\t*visibleChildrenCount %+= 1\r?\n\t*end\r?\n\t*end\r?\n\r?\n\t*local spacing = dropdownFrameUIListLayout%.Padding%.Offset %* %(visibleChildrenCount %- 1%)\r?\n\r?\n\t*return totalHeight %+ spacing %+ padding\r?\n\t*end'
local replCalcSize = [[local function CalculateDropdownSize()
						local totalHeight = 0
						local visibleChildrenCount = 0
						local padding = dropdownFrameUIPadding.PaddingTop.Offset + dropdownFrameUIPadding.PaddingBottom.Offset

						for _, v in pairs(dropdownFrame:GetChildren()) do
							if not v:IsA("UIComponent") and v.Visible then
								totalHeight += v.AbsoluteSize.Y
								visibleChildrenCount += 1
							end
						end

						local spacing = dropdownFrameUIListLayout.Padding.Offset * math.max(0, visibleChildrenCount - 1)
						local contentHeight = totalHeight + spacing + padding
						local fullDropdownHeight = 38 + contentHeight
						local maxDropdownHeight = 210

						if dropdownFrame:IsA("ScrollingFrame") then
							dropdownFrame.ScrollBarThickness = (fullDropdownHeight > maxDropdownHeight) and 3 or 0
						end

						return math.min(fullDropdownHeight, maxDropdownHeight)
					end]]
rawMaclibSource = rawMaclibSource:gsub(patCalcSize, replCalcSize)

-- Patch 2.8: Slider Min/Max Arithmetic Nil Bug
local patSliderMinMax = "function SectionFunctions:Slider%(Settings, Flag%)"
local replSliderMinMax = "function SectionFunctions:Slider(Settings, Flag)\n\t\t\t\t\tSettings.Minimum = Settings.Minimum or Settings.Min or 0\n\t\t\t\t\tSettings.Maximum = Settings.Maximum or Settings.Max or 100"
rawMaclibSource = rawMaclibSource:gsub(patSliderMinMax, replSliderMinMax)

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

-- Patch 5: Safe Tween engine wrapper (Bypasses Roblox thread capability Plugin crashes on protected GUI hierarchies)
local patTween = "local function Tween%(instance, tweeninfo, propertytable%)\r?\n\t*return TweenService:Create%(instance, tweeninfo, propertytable%)\r?\nend"
local replTween = [[local function Tween(instance, tweeninfo, propertytable)
	local ok, tw = pcall(function()
		return TweenService:Create(instance, tweeninfo, propertytable)
	end)
	if ok and tw then
		return tw
	end
	pcall(function()
		if instance and propertytable then
			for prop, val in pairs(propertytable) do
				instance[prop] = val
			end
		end
	end)
	return {
		Play = function() end,
		Stop = function() end,
		Cancel = function() end,
		Pause = function() end,
		Completed = {
			Connect = function() return { Disconnect = function() end } end,
			Wait = function() end
		}
	}
end]]
rawMaclibSource = rawMaclibSource:gsub(patTween, replTween)

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

-- Populate Shop items dynamically from ShopConfig & ItemDatabase (with disk cache & accurate fallback for Battle place)
local ShopConfigCacheFile = "STRIX HUB/Anime Mysterious/shop_config_cache.json"
local cachedItemNames = {}

-- Cache ShopConfig and ItemNames to disk when in Lobby (for instant access across Battle places)
if isLobby and ShopConfig and ShopConfig.GoldShopItems and #ShopConfig.GoldShopItems > 0 then
    task.spawn(function()
        pcall(function()
            local itemNames = {}
            for _, item in ipairs(ShopConfig.GoldShopItems) do
                if item and item.ID and ItemDatabase and ItemDatabase.GetItem then
                    local ok, db = pcall(function() return ItemDatabase.GetItem(item.ID) end)
                    if ok and db and db.Name then
                        itemNames[item.ID] = db.Name
                    end
                end
            end
            for _, item in ipairs(ShopConfig.GemsShopItems or {}) do
                if item and item.ID and ItemDatabase and ItemDatabase.GetItem and not itemNames[item.ID] then
                    local ok, db = pcall(function() return ItemDatabase.GetItem(item.ID) end)
                    if ok and db and db.Name then
                        itemNames[item.ID] = db.Name
                    end
                end
            end
            local payload = {
                GoldShopItems = ShopConfig.GoldShopItems,
                GemsShopItems = ShopConfig.GemsShopItems,
                ItemNames = itemNames
            }
            if writefile then
                EnsureFolders()
                writefile(ShopConfigCacheFile, HttpService:JSONEncode(payload))
            end
        end)
    end)
elseif not isLobby then
    -- When in Battle place: attempt to load verified ShopConfig from disk cache
    pcall(function()
        if isfile and isfile(ShopConfigCacheFile) then
            local raw = readfile(ShopConfigCacheFile)
            if raw and #raw > 10 then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    if data.GoldShopItems and #data.GoldShopItems > 0 and data.GemsShopItems and #data.GemsShopItems > 0 then
                        ShopConfig = {
                            GoldShopItems = data.GoldShopItems,
                            GemsShopItems = data.GemsShopItems
                        }
                    end
                    if type(data.ItemNames) == "table" then
                        cachedItemNames = data.ItemNames
                    end
                end
            end
        end
    end)
end

-- Fallback tables with exact 12 items, actual stock, and real prices verified from current game version
local defaultGemsShop = {
    { ID = "Fruit_1", Price = 10, MaxStock = 10 },
    { ID = "Fruit_2", Price = 25, MaxStock = 5 },
    { ID = "RareShard", Price = 35, MaxStock = 25 },
    { ID = "EpicShard", Price = 75, MaxStock = 20 },
    { ID = "LegendShard", Price = 180, MaxStock = 20 },
    { ID = "MythicShard", Price = 350, MaxStock = 20 },
    { ID = "MysteriousShard", Price = 10000, MaxStock = 10 },
    { ID = "Trait", Price = 200, MaxStock = 10 },
    { ID = "StatRerollAll", Price = 35, MaxStock = 10 },
    { ID = "StatReroll", Price = 80, MaxStock = 10 },
    { ID = "MysteryCapsule", Price = 750, MaxStock = 50 },
    { ID = "BingoCoin", Price = 1000, MaxStock = 10 },
}

local defaultGoldShop = {
    { ID = "Fruit_1", Price = 150, MaxStock = 10 },
    { ID = "Fruit_2", Price = 350, MaxStock = 5 },
    { ID = "RareShard", Price = 500, MaxStock = 25 },
    { ID = "EpicShard", Price = 1000, MaxStock = 20 },
    { ID = "LegendShard", Price = 2500, MaxStock = 20 },
    { ID = "MythicShard", Price = 5000, MaxStock = 20 },
    { ID = "MysteriousShard", Price = 65000, MaxStock = 10 },
    { ID = "Trait", Price = 3000, MaxStock = 10 },
    { ID = "StatRerollAll", Price = 500, MaxStock = 10 },
    { ID = "StatReroll", Price = 1200, MaxStock = 10 },
    { ID = "MysteryCapsule", Price = 3000, MaxStock = 50 },
    { ID = "BingoCoin", Price = 2000, MaxStock = 10 },
}

local gemsItemsToProcess = (ShopConfig and ShopConfig.GemsShopItems and #ShopConfig.GemsShopItems > 0) and ShopConfig.GemsShopItems or defaultGemsShop
local goldItemsToProcess = (ShopConfig and ShopConfig.GoldShopItems and #ShopConfig.GoldShopItems > 0) and ShopConfig.GoldShopItems or defaultGoldShop

local function ResolveItemName(id)
    if ItemDatabase and ItemDatabase.GetItem then
        local ok, db = pcall(function() return ItemDatabase.GetItem(id) end)
        if ok and db and db.Name then return db.Name end
    end
    if cachedItemNames and cachedItemNames[id] then
        return cachedItemNames[id]
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
        MysteryCapsule = "Release Capsule",
        BingoCoin = "Bingo Coin"
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
    AutoSolveFateSword = true,

    -- Discord Webhook
    WebhookEnabled = false,
    WebhookUrl = "",
    WebhookUserId = "",
    WebhookOnVictory = true,
    WebhookOnDefeat = true,

    -- Auto Open Capsules
    AutoOpenCapsules = false,
    CapsuleMinFreeSlots = 2,

    -- Auto Feed & Evolve
    AutoFeed = false,
    AutoFeedTarget = "Equipped", -- "Equipped", "All", or UUID
    AutoEvolve = false,

    -- Auto Trait Reroll
    AutoTraitReroll = false,
    TraitRerollTargetUnit = "",
    TargetTraits = { "Absolute Ego", "Twin Stars", "Aura Burst" },
    RespectInGameStopList = true,
    TraitRerollDelay = 0.02,

    -- Party System
    PartyEnabled = false,
    PartyRole = "Host", -- "Host" or "Alt"
    PartyHost = "",
    PartyAlts = {},
    PartyAltsWhitelist = "",
    PartyAutoInvite = true,
    PartyAutoFollow = true,
    PartyAutoJoin = true,
    PartyAutoLeaveOnHostLeave = true
}

--// Config Paths (Save at workspace\STRIX HUB\<MapName>\<Username>.json)
local ConfigFolder = "STRIX HUB/Anime Mysterious"
local ConfigFile = ConfigFolder .. "/" .. tostring(LocalPlayer.Name) .. ".json"

local function ResolveBind(bindName)
    if not bindName or bindName == "Unknown" or bindName == "None" then return nil end
    local okKey, k = pcall(function() return Enum.KeyCode[bindName] end)
    if okKey and k and k ~= Enum.KeyCode.Unknown then return k end
    local okInput, u = pcall(function() return Enum.UserInputType[bindName] end)
    if okInput and u and u ~= Enum.UserInputType.None then return u end
    return nil
end

-- Pre-load early settings into State (Keybind, UISize, Blur, UserInfo, MobileToggle, Maps, etc.) before Window creation
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

        -- Pre-load Gameplay / Event Automations
        if earlyData.AutoSolveFateSword ~= nil then State.AutoSolveFateSword = (earlyData.AutoSolveFateSword ~= false) end
        if earlyData.AutoDefendMoneyUnits ~= nil then State.AutoDefendMoneyUnits = (earlyData.AutoDefendMoneyUnits ~= false) end

        -- Pre-load Webhook
        if earlyData.WebhookEnabled ~= nil then State.WebhookEnabled = (earlyData.WebhookEnabled == true) end
        if earlyData.WebhookUrl ~= nil then State.WebhookUrl = earlyData.WebhookUrl end
        if earlyData.WebhookUserId ~= nil then State.WebhookUserId = earlyData.WebhookUserId end
        if earlyData.WebhookOnVictory ~= nil then State.WebhookOnVictory = (earlyData.WebhookOnVictory ~= false) end
        if earlyData.WebhookOnDefeat ~= nil then State.WebhookOnDefeat = (earlyData.WebhookOnDefeat ~= false) end

        -- Pre-load Auto Open Capsules
        if earlyData.AutoOpenCapsules ~= nil then State.AutoOpenCapsules = (earlyData.AutoOpenCapsules == true) end
        if earlyData.CapsuleMinFreeSlots ~= nil then State.CapsuleMinFreeSlots = tonumber(earlyData.CapsuleMinFreeSlots) or 2 end

        -- Pre-load Auto Feed & Evolve
        if earlyData.AutoFeed ~= nil then State.AutoFeed = (earlyData.AutoFeed == true) end
        if earlyData.AutoFeedTarget ~= nil then State.AutoFeedTarget = earlyData.AutoFeedTarget end
        if earlyData.AutoEvolve ~= nil then State.AutoEvolve = (earlyData.AutoEvolve == true) end

        -- Pre-load Auto Trait Reroll
        if earlyData.AutoTraitReroll ~= nil then State.AutoTraitReroll = (earlyData.AutoTraitReroll == true) end
        if earlyData.TraitRerollTargetUnit ~= nil then State.TraitRerollTargetUnit = earlyData.TraitRerollTargetUnit end
        if type(earlyData.TargetTraits) == "table" then State.TargetTraits = earlyData.TargetTraits end
        if earlyData.RespectInGameStopList ~= nil then State.RespectInGameStopList = (earlyData.RespectInGameStopList ~= false) end
        if earlyData.TraitRerollDelay ~= nil then State.TraitRerollDelay = tonumber(earlyData.TraitRerollDelay) or 0.02 end

        -- Pre-load Party System
        if earlyData.PartyEnabled ~= nil then State.PartyEnabled = (earlyData.PartyEnabled == true) end
        if earlyData.PartyRole ~= nil then
            if earlyData.PartyRole == "Disabled" then
                State.PartyEnabled = false
                State.PartyRole = "Host"
            else
                State.PartyRole = (earlyData.PartyRole == "Alt") and "Alt" or "Host"
            end
        end
        if earlyData.PartyHost ~= nil then State.PartyHost = earlyData.PartyHost end
        if type(earlyData.PartyAlts) == "table" then
            State.PartyAlts = earlyData.PartyAlts
            State.PartyAltsWhitelist = table.concat(earlyData.PartyAlts, ", ")
        elseif earlyData.PartyAltsWhitelist ~= nil and type(earlyData.PartyAltsWhitelist) == "string" then
            State.PartyAltsWhitelist = earlyData.PartyAltsWhitelist
            State.PartyAlts = {}
            for name in string.gmatch(earlyData.PartyAltsWhitelist, "[^,;%s]+") do
                table.insert(State.PartyAlts, name)
            end
        end
        if earlyData.PartyAutoInvite ~= nil then State.PartyAutoInvite = (earlyData.PartyAutoInvite ~= false) end
        if earlyData.PartyAutoFollow ~= nil then State.PartyAutoFollow = (earlyData.PartyAutoFollow ~= false) end
        if earlyData.PartyAutoJoin ~= nil then State.PartyAutoJoin = (earlyData.PartyAutoJoin ~= false) end
        if earlyData.PartyAutoLeaveOnHostLeave ~= nil then State.PartyAutoLeaveOnHostLeave = (earlyData.PartyAutoLeaveOnHostLeave ~= false) end
    end
end

local isLoadingConfig = true
local saveDebounce = false
local lastUserGameSettingChangeTime = 0

local function ResolveBool(stateVal, diskVal, defaultVal)
    if stateVal ~= nil then
        return (stateVal == true)
    elseif diskVal ~= nil then
        return (diskVal == true)
    else
        return (defaultVal == true)
    end
end

local function ResolveString(stateVal, diskVal, defaultVal)
    if stateVal ~= nil and stateVal ~= "" then
        return tostring(stateVal)
    elseif diskVal ~= nil and diskVal ~= "" then
        return tostring(diskVal)
    else
        return defaultVal or ""
    end
end

local function ResolveMap(stateVal, diskVal, defaultVal)
    if stateVal ~= nil and stateVal ~= "" and stateVal ~= "None" then
        return tostring(stateVal)
    elseif diskVal ~= nil and diskVal ~= "" and diskVal ~= "None" then
        return tostring(diskVal)
    else
        return defaultVal or ""
    end
end

local function ResolveItemList(stateVal, diskVal)
    if type(stateVal) == "table" and (not isBattlePlace or #stateVal > 0) then
        return stateVal
    elseif type(diskVal) == "table" and #diskVal > 0 then
        return diskVal
    elseif type(stateVal) == "table" then
        return stateVal
    else
        return {}
    end
end

local function SaveConfig()
    if not isScriptRunning or isLoadingConfig then return end
    EnsureFolders()

    local diskData = {}
    local readTarget = ConfigFile
    if not isfile(readTarget) then
        local oldTarget = ConfigFolder .. "/" .. tostring(LocalPlayer.UserId) .. ".json"
        if isfile(oldTarget) then
            readTarget = oldTarget
        end
    end
    if isfile(readTarget) then
        local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(readTarget)) end)
        if ok and type(dec) == "table" then
            diskData = dec
        end
    end

    local payload = {
        ActiveAutoCreate = ResolveString(State.ActiveAutoCreate, diskData.ActiveAutoCreate, "None"),
        StoryMap = ResolveMap(State.StoryMap, diskData.StoryMap, GameData.Story.Maps[1] or ""),
        StoryStage = ResolveString(State.StoryStage, diskData.StoryStage, "1"),
        StoryDiff = ResolveString(State.StoryDiff, diskData.StoryDiff, "Normal"),
        MysteriousMap = ResolveMap(State.MysteriousMap, diskData.MysteriousMap, GameData.Mysterious.Maps[1] or ""),
        MysteriousStage = ResolveString(State.MysteriousStage, diskData.MysteriousStage, "1"),
        MysteriousDiff = ResolveString(State.MysteriousDiff, diskData.MysteriousDiff, "Normal"),
        RaidsMap = ResolveMap(State.RaidsMap, diskData.RaidsMap, GameData.Raids.Maps[1] or ""),
        RaidsStage = ResolveString(State.RaidsStage, diskData.RaidsStage, "1"),
        RaidsDiff = ResolveString(State.RaidsDiff, diskData.RaidsDiff, "Normal"),
        BossMap = ResolveMap(State.BossMap, diskData.BossMap, GameData.Boss.Maps[1] or ""),
        BossStage = ResolveString(State.BossStage, diskData.BossStage, "1"),
        BossDiff = ResolveString(State.BossDiff, diskData.BossDiff, "Normal"),
        AutoStart = ResolveBool(State.AutoStart, diskData.AutoStart, false),
        AutoChallenges = ResolveBool(State.AutoChallenges, diskData.AutoChallenges, false),
        AutoLeaveChallenge = ResolveBool(State.AutoLeaveChallenge, diskData.AutoLeaveChallenge, false),
        AutoLeaveOnChallengeReset = ResolveBool(State.AutoLeaveOnChallengeReset, diskData.AutoLeaveOnChallengeReset, false),
        TargetChallenges = (type(State.TargetChallenges) == "table") and State.TargetChallenges or (type(diskData.TargetChallenges) == "table" and diskData.TargetChallenges or { Weekly = true, Daily = true, Regular = true }),
        AutoSummon = ResolveBool(State.AutoSummon, diskData.AutoSummon, false),
        SummonBanner = ResolveString(State.SummonBanner, diskData.SummonBanner, "Standard"),
        SummonAmount = ResolveString(State.SummonAmount, diskData.SummonAmount, "10x"),
        AutoBuyGems = ResolveBool(State.AutoBuyGems, diskData.AutoBuyGems, false),
        SelectedGemsItems = ResolveItemList(State.SelectedGemsItems, diskData.SelectedGemsItems),
        AutoBuyGold = ResolveBool(State.AutoBuyGold, diskData.AutoBuyGold, false),
        SelectedGoldItems = ResolveItemList(State.SelectedGoldItems, diskData.SelectedGoldItems),
        Keybind = typeof(State.Keybind) == "EnumItem" and State.Keybind.Name or (type(State.Keybind) == "string" and State.Keybind or (diskData.Keybind or "RightControl")),
        UISize = State.UISize or diskData.UISize or { Width = 868, Height = 650 },
        AcrylicBlur = ResolveBool(State.AcrylicBlur, diskData.AcrylicBlur, true),
        ShowUserInfo = ResolveBool(State.ShowUserInfo, diskData.ShowUserInfo, true),
        MobileToggle = ResolveBool(State.MobileToggle, diskData.MobileToggle, true),
        AutoPlay = ResolveBool(State.AutoPlay, diskData.AutoPlay, true),
        AutoNext = ResolveBool(State.AutoNext, diskData.AutoNext, true),
        AutoReplay = ResolveBool(State.AutoReplay, diskData.AutoReplay, true),
        AutoVoteStart = ResolveBool(State.AutoVoteStart, diskData.AutoVoteStart, true),
        AutoWaveSkipping = ResolveBool(State.AutoWaveSkipping, diskData.AutoWaveSkipping, true),
        AutoMaxGameSpeed = ResolveBool(State.AutoMaxGameSpeed, diskData.AutoMaxGameSpeed, true),
        AutoUltimate = ResolveBool(State.AutoUltimate, diskData.AutoUltimate, true),
        AutoSolveFateSword = ResolveBool(State.AutoSolveFateSword, diskData.AutoSolveFateSword, true),
        AutoDefendMoneyUnits = ResolveBool(State.AutoDefendMoneyUnits, diskData.AutoDefendMoneyUnits, true),

        -- Webhook
        WebhookEnabled = ResolveBool(State.WebhookEnabled, diskData.WebhookEnabled, false),
        WebhookUrl = ResolveString(State.WebhookUrl, diskData.WebhookUrl, ""),
        WebhookUserId = ResolveString(State.WebhookUserId, diskData.WebhookUserId, ""),
        WebhookOnVictory = ResolveBool(State.WebhookOnVictory, diskData.WebhookOnVictory, true),
        WebhookOnDefeat = ResolveBool(State.WebhookOnDefeat, diskData.WebhookOnDefeat, true),

        -- Auto Open Capsules
        AutoOpenCapsules = ResolveBool(State.AutoOpenCapsules, diskData.AutoOpenCapsules, false),
        CapsuleMinFreeSlots = tonumber(State.CapsuleMinFreeSlots) or tonumber(diskData.CapsuleMinFreeSlots) or 2,

        -- Auto Feed & Evolve
        AutoFeed = ResolveBool(State.AutoFeed, diskData.AutoFeed, false),
        AutoFeedTarget = ResolveString(State.AutoFeedTarget, diskData.AutoFeedTarget, "Equipped"),
        AutoEvolve = ResolveBool(State.AutoEvolve, diskData.AutoEvolve, false),

        -- Auto Trait Reroll
        AutoTraitReroll = ResolveBool(State.AutoTraitReroll, diskData.AutoTraitReroll, false),
        TraitRerollTargetUnit = ResolveString(State.TraitRerollTargetUnit, diskData.TraitRerollTargetUnit, ""),
        TargetTraits = (type(State.TargetTraits) == "table") and State.TargetTraits or (type(diskData.TargetTraits) == "table" and diskData.TargetTraits or { "Absolute Ego", "Twin Stars", "Aura Burst" }),
        RespectInGameStopList = ResolveBool(State.RespectInGameStopList, diskData.RespectInGameStopList, true),
        TraitRerollDelay = tonumber(State.TraitRerollDelay) or 0.02,

        -- Party System
        PartyEnabled = ResolveBool(State.PartyEnabled, diskData.PartyEnabled, false),
        PartyRole = (State.PartyRole == "Alt") and "Alt" or "Host",
        PartyHost = ResolveString(State.PartyHost, diskData.PartyHost, ""),
        PartyAlts = (type(State.PartyAlts) == "table") and State.PartyAlts or {},
        PartyAltsWhitelist = ResolveString(State.PartyAltsWhitelist, diskData.PartyAltsWhitelist, ""),
        PartyAutoInvite = ResolveBool(State.PartyAutoInvite, diskData.PartyAutoInvite, true),
        PartyAutoFollow = ResolveBool(State.PartyAutoFollow, diskData.PartyAutoFollow, true),
        PartyAutoJoin = ResolveBool(State.PartyAutoJoin, diskData.PartyAutoJoin, true),
        PartyAutoLeaveOnHostLeave = ResolveBool(State.PartyAutoLeaveOnHostLeave, diskData.PartyAutoLeaveOnHostLeave, true)
    }

    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if okEnc and encoded then
        pcall(writefile, ConfigFile, encoded)
    end
end

local function SaveConfigDebounced()
    if not isScriptRunning or isLoadingConfig then return end
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.3, function()
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
        if not isLoadingConfig then
            SaveConfig()
        end
    end
end)

pcall(function()
    game:BindToClose(function()
        if isScriptRunning and not isLoadingConfig then
            isScriptRunning = false
            pcall(SaveConfig)
        end
    end)
end)

--// Helper Functions
local function SafeClick(button)
    if not button then return end
    local clicked = false
    if firesignal and button:IsA("GuiButton") then
        local ok = pcall(firesignal, button.MouseButton1Click)
        if ok then
            clicked = true
        else
            local okAct = pcall(firesignal, button.Activated)
            if okAct then clicked = true end
        end
    end
    if not clicked and getconnections then
        local sigNames = { "MouseButton1Click", "Activated" }
        for _, sigName in ipairs(sigNames) do
            local sig = button[sigName]
            if sig then
                local conns = getconnections(sig) or {}
                if #conns > 0 then
                    for _, conn in ipairs(conns) do
                        if conn.Fire then
                            pcall(function() conn:Fire() end)
                        elseif conn.Function then
                            pcall(conn.Function, button)
                        end
                    end
                    clicked = true
                    break
                end
            end
        end
    end
    if not clicked and firesignal then
        pcall(firesignal, button.MouseButton1Down)
        pcall(firesignal, button.MouseButton1Up)
    end
end

--// Anti-AFK & Game 18-Minute Idle Bypass System
local antiAfkCon = getgenv().STRIX_ANTI_AFK_CON
local localPlayer = game:GetService("Players").LocalPlayer

if getconnections then
    for _, c in getconnections(localPlayer.Idled) do
        pcall(function() c:Disable() end)
        pcall(function() c:Disconnect() end)
    end
end

if antiAfkCon then
    pcall(function() antiAfkCon:Disconnect() end)
    getgenv().STRIX_ANTI_AFK_CON = nil
end

local function SendAntiAfkInput()
    pcall(function()
        local VirtualInputManager = Instance.new("VirtualInputManager")
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        VirtualInputManager:Destroy()
    end)
end

antiAfkCon = localPlayer.Idled:Connect(function()
    SendAntiAfkInput()
end)
getgenv().STRIX_ANTI_AFK_CON = antiAfkCon
print("Anti-AFK System Enabled!")

-- Bypass in-game 18-minute auto-rejoin (AntiAFKController & AFKRejoinRequest)
pcall(function()
    local ps = localPlayer:FindFirstChild("PlayerScripts")
    local ctrl = ps and ps:FindFirstChild("AntiAFKController")
    if ctrl then
        ctrl.Disabled = true
    end
end)

pcall(function()
    local ps = localPlayer:WaitForChild("PlayerScripts", 5)
    if ps then
        ps.ChildAdded:Connect(function(child)
            if child.Name == "AntiAFKController" then
                task.wait(0.1)
                pcall(function() child.Disabled = true end)
            end
        end)
    end
end)

if hookmetamethod and getnamecallmethod and not getgenv().STRIX_AFK_REJOIN_HOOKED then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "fireServer") and tostring(self) == "AFKRejoinRequest" then
            return nil
        end
        return oldNamecall(self, ...)
    end))
    getgenv().STRIX_AFK_REJOIN_HOOKED = true
end

-- Periodic activity heartbeat (Every 5 minutes to keep internal activity timers reset)
task.spawn(function()
    while isScriptRunning do
        task.wait(300)
        if not isScriptRunning then break end
        SendAntiAfkInput()
    end
end)

--// In-Game Gameplay Settings Controller (Two-way Sync with PlayerGui.Settings & SettingModule)
local isSyncingFromGame = false

local function GetGameSettingItem(guiName)
    local s = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Settings")
    return s and s:FindFirstChild(guiName, true)
end

local function GetSwitchState(item)
    if not item then return nil end
    local slider = item:FindFirstChild("Slider")
    local btn = slider and slider:FindFirstChild("Button")
    local ball = slider and slider:FindFirstChild("Ball")
    if btn and getconnections and debug and debug.getupvalues then
        local conns = getconnections(btn.MouseButton1Click)
        if conns and conns[1] and conns[1].Function then
            local ok, uvs = pcall(debug.getupvalues, conns[1].Function)
            if ok and uvs and type(uvs[1]) == "boolean" then
                return uvs[1]
            end
        end
    end
    if ball then
        return (ball.Position.X.Scale > 0.3)
    end
    return nil
end

local function GetGameSetting(guiName, settingKey)
    local item = GetGameSettingItem(guiName)
    local switchState = GetSwitchState(item)
    if switchState ~= nil then
        return switchState
    end
    if SettingModule and settingKey and SettingModule.GetSetting then
        local ok, val = pcall(function() return SettingModule:GetSetting(settingKey) end)
        if ok and val ~= nil then return val end
    end
    return nil
end

local function SetGameSetting(guiName, targetState, settingKey)
    local item = GetGameSettingItem(guiName)
    local btn = item and item:FindFirstChild("Slider") and item.Slider:FindFirstChild("Button")
    local curState = GetSwitchState(item)
    
    -- 1. Sync In-Game Switch GUI & Slider Visual (Single Click)
    if btn and curState ~= nil and curState ~= targetState then
        SafeClick(btn)
    end
    
    -- 2. Direct Sync into SettingModule & Server Remote (Guaranteed persistence & replica update)
    if SettingModule and settingKey then
        pcall(function()
            if SettingModule.SaveSetting then
                SettingModule:SaveSetting(settingKey, targetState)
            elseif SettingModule.SettingsState then
                SettingModule.SettingsState[settingKey] = targetState
                local UpdateSetting = Remotes and Remotes:FindFirstChild("UpdateSetting")
                if UpdateSetting then
                    UpdateSetting:FireServer(settingKey, targetState)
                end
            end
            if SettingModule.ApplySettingEffect then
                SettingModule:ApplySettingEffect(settingKey, targetState)
            end
        end)
    end
    
    -- 3. In-Game Battle Active State Handlers (Instant live match action)
    if isBattlePlace then
        -- Autoplay active match attribute sync
        if settingKey == "Autoplay" then
            local currentAttr = LocalPlayer and LocalPlayer:GetAttribute("AutoPlay")
            if currentAttr ~= targetState then
                local ToggleAutoplay = Remotes and Remotes:FindFirstChild("ToggleAutoplay")
                if ToggleAutoplay then
                    pcall(function() ToggleAutoplay:FireServer(targetState) end)
                end
            end
        -- Auto Max Game Speed match request
        elseif settingKey == "AutoMaxGameSpeed" and targetState == true then
            local ChangeGameSpeedRequest = GameEvents and GameEvents:FindFirstChild("ChangeGameSpeedRequest")
            if ChangeGameSpeedRequest then
                local speed = 1.5
                pcall(function()
                    if SettingModule and SettingModule.LocalReplica and SettingModule.LocalReplica.Data and SettingModule.LocalReplica.Data.OwnedGamePasses and SettingModule.LocalReplica.Data.OwnedGamePasses.GameSpeedx3 then
                        speed = 3
                    end
                end)
                pcall(function() ChangeGameSpeedRequest:FireServer(speed) end)
            end
        -- Auto Skip Wave vote request
        elseif settingKey == "AutoSkipWave" and targetState == true then
            if workspace:GetAttribute("SkipWaveActive") then
                local VoteSkipWave = Remotes and Remotes:FindFirstChild("VoteSkipWave")
                if VoteSkipWave then
                    pcall(function() VoteSkipWave:FireServer() end)
                end
            end
        -- Auto Vote Start match request
        elseif settingKey == "AutoVoteStart" and targetState == true then
            if LocalPlayer and LocalPlayer:GetAttribute("GameStarted") ~= true and LocalPlayer:GetAttribute("HasVotedStart") ~= true then
                local VoteStartRequest = Remotes and Remotes:FindFirstChild("VoteStartRequest")
                if VoteStartRequest then
                    pcall(function() VoteStartRequest:FireServer(LocalPlayer) end)
                end
            end
        end
    end
    return true
end

-- Sync from In-Game Settings to STRIX HUB (Unified Thread)
local function SetupGameSettingsSync()
    task.spawn(function()
        while isScriptRunning do
            task.wait(1.0)
            if not isScriptRunning then break end
            if isLoadingConfig then continue end
            if os.clock() - lastUserGameSettingChangeTime < 2.5 then continue end

            for _, sInfo in ipairs(GameSettingsMap) do
                if not isScriptRunning or isLoadingConfig then break end
                local currentInGame = GetGameSetting(sInfo.GuiName, sInfo.SettingKey)
                if currentInGame ~= nil and State[sInfo.StateKey] ~= currentInGame and not isSyncingFromGame then
                    isSyncingFromGame = true
                    State[sInfo.StateKey] = currentInGame
                    if MacLib and MacLib.Options and MacLib.Options[sInfo.OptFlag] then
                        pcall(function() MacLib.Options[sInfo.OptFlag]:UpdateState(currentInGame) end)
                    end
                    isSyncingFromGame = false
                    if not isLoadingConfig then
                        SaveConfigDebounced()
                    end
                end
            end
        end
    end)
end
SetupGameSettingsSync()

-- In-Battle Gameplay Settings Continuous Enforcer
if isBattlePlace then
    task.spawn(function()
        while isScriptRunning do
            task.wait(1.5)
            if not isScriptRunning then break end
            
            -- Keep AutoPlay active during live battle
            if State.AutoPlay and LocalPlayer and LocalPlayer:GetAttribute("GameStarted") == true then
                if LocalPlayer:GetAttribute("AutoPlay") ~= true then
                    local ToggleAutoplay = Remotes and Remotes:FindFirstChild("ToggleAutoplay")
                    if ToggleAutoplay then
                        pcall(function() ToggleAutoplay:FireServer(true) end)
                    end
                end
            end
            
            -- Keep Auto Max Speed active
            if State.AutoMaxGameSpeed and workspace:GetAttribute("GameStarted") == true then
                local currentSpeed = workspace:GetAttribute("GameSpeed") or 1
                local desiredSpeed = 1.5
                pcall(function()
                    if SettingModule and SettingModule.LocalReplica and SettingModule.LocalReplica.Data and SettingModule.LocalReplica.Data.OwnedGamePasses and SettingModule.LocalReplica.Data.OwnedGamePasses.GameSpeedx3 then
                        desiredSpeed = 3
                    end
                end)
                if currentSpeed < desiredSpeed then
                    local ChangeGameSpeedRequest = GameEvents and GameEvents:FindFirstChild("ChangeGameSpeedRequest")
                    if ChangeGameSpeedRequest then
                        pcall(function() ChangeGameSpeedRequest:FireServer(desiredSpeed) end)
                    end
                end
            end
            
            -- Automatically vote to skip wave when ready
            if State.AutoWaveSkipping and workspace:GetAttribute("SkipWaveActive") == true then
                local VoteSkipWave = Remotes and Remotes:FindFirstChild("VoteSkipWave")
                if VoteSkipWave then
                    pcall(function() VoteSkipWave:FireServer() end)
                end
            end
            
            -- Automatically vote to start game when waiting
            if State.AutoVoteStart and LocalPlayer and LocalPlayer:GetAttribute("GameStarted") ~= true and LocalPlayer:GetAttribute("HasVotedStart") ~= true then
                local VoteStartRequest = Remotes and Remotes:FindFirstChild("VoteStartRequest")
                if VoteStartRequest then
                    pcall(function() VoteStartRequest:FireServer(LocalPlayer) end)
                end
            end
        end
    end)
end

local function GetRoomModeFromMap(mapName)
    if not mapName or mapName == "" then return "Story" end
    local cleanName = string.gsub(mapName, "%s*%[.-%]", "")
    local cClean = string.lower(cleanName)
    for _, mc in ipairs(MapConfig) do
        if mc.Name and string.lower(mc.Name) == cClean then
            return mc.Mode or "Story"
        end
        if mc.MapToCreate and string.lower(mc.MapToCreate) == cClean then
            return mc.Mode or "Story"
        end
    end
    return (PlayModule and PlayModule.SessionMode) or "Story"
end

local function GetCurrentRoomInfo()
    local PlayGUI = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
    if not (PlayGUI and PlayGUI.Enabled) then
        return nil
    end
    local pf = PlayGUI:FindFirstChild("PlayFrame")
    if not (pf and pf.Visible) then
        return nil
    end
    local sdf = pf:FindFirstChild("Details") and pf.Details:FindFirstChild("ShowDetailsFrame")
    local mapName = sdf and sdf:FindFirstChild("MAPNAME") and sdf.MAPNAME.Text or ""
    local stageText = sdf and sdf:FindFirstChild("STAGE") and sdf.STAGE.Text or ""
    local diffText = sdf and sdf:FindFirstChild("Diff") and sdf.Diff.Text or ""
    local playBtn = pf:FindFirstChild("ContainerBtn") and pf.ContainerBtn:FindFirstChild("PlayBtn")
    
    if mapName == "" or mapName == "Waiting for Host..." or stageText == "" or stageText == "..." then
        return nil
    end
    
    local stageNum = tonumber(string.match(stageText, "%d+")) or 1
    local mode = GetRoomModeFromMap(mapName)
    
    return {
        Gui = PlayGUI,
        Frame = pf,
        MapName = mapName,
        StageText = stageText,
        StageNum = stageNum,
        Diff = diffText,
        Mode = mode,
        IsHost = (PlayModule and PlayModule.isHost == true),
        PlayBtn = playBtn,
        IsTeleporting = (playBtn and playBtn.Text == "Teleporting...")
    }
end

local function IsRoomCreated()
    local info = GetCurrentRoomInfo()
    return info ~= nil
end

local function DoesRoomMatch(targetMode, targetMapName, targetStage, targetDiff)
    local room = GetCurrentRoomInfo()
    if not room then return false end
    
    local cleanTargetMap = string.gsub(targetMapName or "", "%s*%[.-%]", "")
    local cleanRoomMap = string.gsub(room.MapName or "", "%s*%[.-%]", "")
    
    local targetStageNum = tonumber(targetStage) or 1
    local targetDiffStr = string.lower(tostring(targetDiff or "Normal"))
    
    -- Check map match (case-insensitive and trimmed)
    local cR = string.lower(cleanRoomMap)
    local cT = string.lower(cleanTargetMap)
    local mapMatches = (cR == cT) or (string.find(cR, cT, 1, true) ~= nil) or (string.find(cT, cR, 1, true) ~= nil)
    if not mapMatches then return false end
    
    -- Check stage match
    local stageMatches = (room.StageNum == targetStageNum)
    if not stageMatches then return false end
    
    -- Check difficulty match
    local roomDiffStr = string.lower(tostring(room.Diff or "Normal"))
    local diffMatches = (roomDiffStr == targetDiffStr)
    if not diffMatches then return false end
    
    -- Check mode match
    local rMode = string.lower(tostring(room.Mode or ""))
    local tMode = string.lower(tostring(targetMode or ""))
    if rMode == tMode then return true end
    if (rMode == "mysterios" or rMode == "mysterious") and (tMode == "mysterios" or tMode == "mysterious") then return true end
    if (rMode == "boss" or rMode == "event") and (tMode == "boss" or tMode == "event") then return true end
    if (rMode == "challange" or rMode == "challenge") and (tMode == "challange" or tMode == "challenge") then return true end
    
    -- Verify against MapConfig mode definitions
    for _, mc in ipairs(MapConfig) do
        if mc.Name and string.lower(mc.Name) == cT then
            local mcMode = string.lower(tostring(mc.Mode or ""))
            if mcMode == tMode or ((mcMode == "boss" or mcMode == "event") and (tMode == "boss" or tMode == "event"))
                or ((mcMode == "mysterios" or mcMode == "mysterious") and (tMode == "mysterios" or tMode == "mysterious")) then
                return true
            end
        end
    end
    
    return true
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
local hasSentMatchWebhook = false
local lastWebhookDispatchTime = 0
local battleStartTime = os.clock()
local lastMatchIsWon = nil
local lastMatchRewards = nil
local lastMatchStats = nil
local lastMatchMapId = nil
local lastMatchStageId = nil
local lastMatchDifficulty = nil
local lastMatchTotalTime = nil
local lastMatchHudTimer = nil
local matchStartCycle = math.floor(os.time() / 1800)
local pendingResetLeave = false
local CheckHostLeftAndAutoLeave = nil
local CheckAndSendMatchWebhook = nil
local ResetMatchState = nil

ResetMatchState = function(reason)
    hasSentMatchWebhook = false
    isMatchFinished = false
    hasHandledLeave = false
    pendingResetLeave = false
    battleStartTime = os.clock()
    lastMatchIsWon = nil
    lastMatchRewards = nil
    lastMatchStats = nil
    lastMatchMapId = nil
    lastMatchStageId = nil
    lastMatchDifficulty = nil
    lastMatchTotalTime = nil
    lastMatchHudTimer = nil
end

local function IsMatchFinished()
    if isMatchFinished then
        if CheckAndSendMatchWebhook then
            pcall(CheckAndSendMatchWebhook)
        end
        return true
    end

    local eg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
    local frame = eg and eg:FindFirstChild("EndGameFrame")
    -- In Gameplay, EndGameFrame.Visible is strictly false during the match. It only becomes true when the match is over!
    if eg and eg.Enabled and frame and frame.Visible then
        local resLabel = frame:FindFirstChild("Info") and frame.Info:FindFirstChild("ResultLabel")
        local leaveBtn = frame:FindFirstChild("Buttons") and frame.Buttons:FindFirstChild("LeaveBtn")
        if (resLabel and resLabel.Visible) or (leaveBtn and leaveBtn.Visible) then
            isMatchFinished = true
            if CheckAndSendMatchWebhook then
                pcall(CheckAndSendMatchWebhook)
            end
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
        if ResetMatchState then
            ResetMatchState("Lobby Reset")
        end
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

-- Listen for EndGameEvent and Match Lifecycle (Fully Asynchronous to guarantee instant script execution)
task.spawn(function()
    if isLobby then return end

    local ge = ReplicatedStorage:FindFirstChild("GameEvents") or ReplicatedStorage:WaitForChild("GameEvents", 2)
    if ge then
        local egEvent = ge:FindFirstChild("EndGameEvent") or ge:WaitForChild("EndGameEvent", 2)
        if egEvent then
            egEvent.OnClientEvent:Connect(function(isWon, mapId, stageId, totalTime, a5, a6, rewards, difficulty, stats)
                isMatchFinished = true
                lastMatchIsWon = isWon
                lastMatchMapId = mapId
                lastMatchStageId = stageId
                lastMatchTotalTime = totalTime
                lastMatchRewards = rewards
                lastMatchDifficulty = difficulty
                lastMatchStats = stats

                -- Capture battle timer from PlayingGui HUD as secondary backup
                local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayingGui")
                local tt = pg and pg:FindFirstChild("Frame") and pg.Frame:FindFirstChild("HealthBar") and pg.Frame.HealthBar:FindFirstChild("TimerText")
                if tt and tt.Text and tt.Text ~= "" then
                    lastMatchHudTimer = string.match(tt.Text, "(%d+:%d+)")
                end

                if CheckAndSendMatchWebhook then
                    pcall(CheckAndSendMatchWebhook)
                end
                if (State.AutoLeaveChallenge or State.AutoLeaveOnChallengeReset) and not hasHandledLeave then
                    task.delay(1.5, function()
                        CheckAndExecuteAutoLeave()
                    end)
                end
                if State.PartyAutoLeaveOnHostLeave and not hasHandledLeave then
                    task.delay(1.5, function()
                        if CheckHostLeftAndAutoLeave then
                            pcall(CheckHostLeftAndAutoLeave)
                        end
                    end)
                end
            end)
        end

        local mlEvent = ge:FindFirstChild("MapLoadedComplete") or ge:WaitForChild("MapLoadedComplete", 2)
        if mlEvent then
            mlEvent.OnClientEvent:Connect(function()
                if ResetMatchState then
                    ResetMatchState("MapLoadedComplete")
                end
            end)
        end
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 2)
    if remotes then
        local closeEg = remotes:FindFirstChild("CloseEndGameUIEvent") or remotes:WaitForChild("CloseEndGameUIEvent", 2)
        if closeEg then
            closeEg.OnClientEvent:Connect(function()
                if ResetMatchState then
                    ResetMatchState("CloseEndGameUIEvent")
                end
            end)
        end
    end

    local plGui = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 2))
    local eg = plGui and (plGui:FindFirstChild("EndGame") or plGui:WaitForChild("EndGame", 2))
    local frame = eg and (eg:FindFirstChild("EndGameFrame") or eg:WaitForChild("EndGameFrame", 2))
    if frame then
        frame:GetPropertyChangedSignal("Visible"):Connect(function()
            if not frame.Visible and (isMatchFinished or hasSentMatchWebhook) then
                task.delay(1, function()
                    if not frame.Visible and ResetMatchState then
                        ResetMatchState("EndGameFrame Hidden")
                    end
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

-- Helper to trigger ProximityPrompt cleanly
local function TriggerSwordPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9999
    end)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt, 0)
    end
    if getconnections then
        pcall(function()
            for _, c in ipairs(getconnections(prompt.Triggered) or {}) do
                if c.Fire then
                    pcall(function() c:Fire() end)
                elseif c.Function then
                    pcall(c.Function)
                end
            end
        end)
    end
end

-- Fast finder for all active sword prompts in the map
local function FindSwordCandidates()
    local candidates = {}
    local fe = workspace:FindFirstChild("FateEvent")
    local fencesFolder = fe and fe:FindFirstChild("Map") and fe.Map:FindFirstChild("Fences")
    local fences = (fencesFolder and fencesFolder:GetChildren()) or {}

    for _, f in ipairs(fences) do
        local prompt = f:FindFirstChildWhichIsA("ProximityPrompt", true) or f:FindFirstChild("SwordPrompt", true)
        if prompt and prompt.Enabled and prompt.Parent then
            local fPos = (f:IsA("BasePart") and f.Position) or (f:IsA("Model") and f:GetPivot().Position) or Vector3.zero
            table.insert(candidates, { fence = f, prompt = prompt, pos = fPos })
        end
    end

    if #candidates == 0 and fe then
        for _, d in ipairs(fe:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled and d.Parent then
                local pPart = (d.Parent:IsA("BasePart") and d.Parent) or (d.Parent:IsA("Model") and d.Parent.PrimaryPart) or d:FindFirstAncestorWhichIsA("BasePart")
                if pPart then
                    table.insert(candidates, { fence = pPart, prompt = d, pos = pPart.Position })
                end
            end
        end
    end

    if #candidates == 0 then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled and d.Parent then
                local actText = string.lower(d.ActionText or "")
                local objText = string.lower(d.ObjectText or "")
                local pName = string.lower(d.Name or "")
                if pName == "swordprompt" or string.find(actText, "ดาบ") or string.find(objText, "ดาบ") or string.find(actText, "sword") or string.find(objText, "sword") then
                    local pPart = (d.Parent:IsA("BasePart") and d.Parent) or (d.Parent:IsA("Model") and d.Parent.PrimaryPart) or d:FindFirstAncestorWhichIsA("BasePart")
                    if pPart then
                        table.insert(candidates, { fence = pPart, prompt = d, pos = pPart.Position })
                    end
                end
            end
        end
    end
    return candidates
end

local function SolveFateSwordEvent()
    if isSolvingSwordEvent then return end
    if not (workspace:GetAttribute("SwordEventActive") == true) then return end
    if os.clock() - lastSwordSolveTime < 0.8 then return end

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

            -- 1. Fast discovery with adaptive wait (up to 0.8s) for server replication
            local candidates = FindSwordCandidates()
            local searchStart = os.clock()
            while #candidates == 0 and (os.clock() - searchStart < 0.8) and (workspace:GetAttribute("SwordEventActive") == true) do
                task.wait(0.04)
                candidates = FindSwordCandidates()
            end

            if #candidates == 0 then
                isSolvingSwordEvent = false
                return
            end

            -- 2. Fast Reactive Interaction Loop
            local lastPresses = workspace:GetAttribute("SwordEventPresses") or 0
            local requiredPresses = workspace:GetAttribute("SwordEventRequired") or 2

            while (workspace:GetAttribute("SwordEventActive") == true) do
                local currentPresses = workspace:GetAttribute("SwordEventPresses") or 0
                if currentPresses >= requiredPresses then break end

                -- Filter valid and enabled candidates
                local validCandidates = {}
                for _, c in ipairs(candidates) do
                    if c.prompt and c.prompt.Enabled and c.prompt.Parent then
                        table.insert(validCandidates, c)
                    end
                end

                -- Re-scan if empty
                if #validCandidates == 0 then
                    candidates = FindSwordCandidates()
                    for _, c in ipairs(candidates) do
                        if c.prompt and c.prompt.Enabled and c.prompt.Parent then
                            table.insert(validCandidates, c)
                        end
                    end
                end

                if #validCandidates == 0 then break end

                -- Dynamic sorting: pick the nearest sword from current position for fastest travel
                local currentPos = hrp.Position
                table.sort(validCandidates, function(a, b)
                    return (a.pos - currentPos).Magnitude < (b.pos - currentPos).Magnitude
                end)

                local item = validCandidates[1]
                local prompt = item.prompt
                local safeStandCFrame = GetSafeSwordStandCFrame(item.fence, item.pos, prompt)

                -- Instant zero-velocity snap
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = safeStandCFrame
                end)

                -- Pre-unlock prompt properties
                pcall(function()
                    prompt.HoldDuration = 0
                    prompt.RequiresLineOfSight = false
                    prompt.MaxActivationDistance = 9999
                end)

                -- Rapid physics replication delay: 0.08s (allows server to register character position)
                task.wait(0.08)

                -- Keep character stable and fire prompt
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
                TriggerSwordPrompt(prompt)

                -- Reactive confirmation loop: exit instantly as soon as server registers the pickup
                local waitStart = os.clock()
                local retried = false
                while (os.clock() - waitStart < 0.32) do
                    local updatedPresses = workspace:GetAttribute("SwordEventPresses") or 0
                    local isEventActive = (workspace:GetAttribute("SwordEventActive") == true)
                    if not isEventActive or updatedPresses > lastPresses or not prompt.Enabled or not prompt.Parent then
                        lastPresses = updatedPresses
                        break
                    end
                    -- Quick retry if delayed after 0.14s
                    if not retried and (os.clock() - waitStart > 0.14) then
                        retried = true
                        TriggerSwordPrompt(prompt)
                    end
                    task.wait(0.025)
                end

                lastPresses = workspace:GetAttribute("SwordEventPresses") or lastPresses
                if lastPresses >= requiredPresses or not (workspace:GetAttribute("SwordEventActive") == true) then
                    break
                end
            end

            -- 3. Fast Safe Return to Original Ground Position
            pcall(function()
                local returnCFrame = lastSafeGroundCFrame or startCFrame
                if hrp and returnCFrame then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = returnCFrame + Vector3.new(0, 2.0, 0)
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                    task.wait(0.08)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        end)
        task.wait(0.2)
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
    if PlayModule and type(PlayModule) == "table" and type(PlayModule.Replica) == "table" and type(PlayModule.Replica.Data) == "table" then
        return PlayModule.Replica.Data
    end
    if _G.PlayerDataReplica and type(_G.PlayerDataReplica) == "table" and type(_G.PlayerDataReplica.Data) == "table" then
        return _G.PlayerDataReplica.Data
    end
    local ok, rc = pcall(function()
        return require(ReplicatedStorage.ReplicaLib.ReplicatedStorage.ReplicaController)
    end)
    if ok and type(rc) == "table" and rc._replicas then
        for _, rep in pairs(rc._replicas) do
            if type(rep) == "table" and rep.Class == "PlayerData" and type(rep.Data) == "table" then
                return rep.Data
            end
        end
    end
    return nil
end

-- ====================================================================
-- DISCORD WEBHOOK SYSTEM (Victory / Defeat Match Reporter)
-- ====================================================================
local function SendDiscordWebhook(embedData)
    if not State.WebhookEnabled or not State.WebhookUrl or State.WebhookUrl == "" then return end
    
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not httpRequest then
        warn("[STRIX HUB] Webhook Error: Executor HTTP request function not supported!")
        return
    end

    local payload = {
        username = "STRIX HUB • Anime Mysterious",
        avatar_url = "https://raw.githubusercontent.com/STRIX-HUB/assets/main/logo.png",
        embeds = { embedData }
    }
    if State.WebhookUserId and State.WebhookUserId ~= "" then
        payload.content = "<@" .. tostring(State.WebhookUserId) .. ">"
    end

    task.spawn(function()
        local ok, res = pcall(function()
            return httpRequest({
                Url = State.WebhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        if not ok then
            warn("[STRIX HUB] Webhook dispatch failed: " .. tostring(res))
        end
    end)
end

CheckAndSendMatchWebhook = function()
    if hasSentMatchWebhook or not State.WebhookEnabled or not State.WebhookUrl or State.WebhookUrl == "" then
        return
    end

    local eg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
    local frame = eg and eg:FindFirstChild("EndGameFrame")
    if not (eg and eg.Enabled and frame and frame.Visible) and not isMatchFinished then
        return
    end

    hasSentMatchWebhook = true
    lastWebhookDispatchTime = os.clock()

    task.spawn(function()
        -- Dynamic wait: If server already delivered full stats & rewards, dispatch quickly (0.5s)
        if lastMatchStats and lastMatchRewards then
            task.wait(0.5)
        else
            local waitStart = os.clock()
            while (os.clock() - waitStart) < 2.0 do
                local currentEg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
                local currentFrame = currentEg and currentEg:FindFirstChild("EndGameFrame")
                if currentFrame and currentFrame.Visible then
                    local statsFrame = currentFrame:FindFirstChild("Stats")
                    local dmgVal = statsFrame and statsFrame:FindFirstChild("TotalDmg") and statsFrame.TotalDmg:FindFirstChild("Value")
                    if dmgVal and dmgVal.Text ~= "" and dmgVal.Text ~= "0" then
                        task.wait(0.2)
                        break
                    end
                end
                task.wait(0.1)
            end
        end

        local currentEg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
        local frame = currentEg and currentEg:FindFirstChild("EndGameFrame")

        -- 1. Determine Victory / Defeat with multi-layered ground truth
        local isVictory = false
        if lastMatchIsWon ~= nil then
            isVictory = (lastMatchIsWon == true)
        else
            local resLabel = frame and frame:FindFirstChild("Info") and frame.Info:FindFirstChild("ResultLabel")
            local headerName = frame and frame:FindFirstChild("Header") and (frame.Header:FindFirstChild("Name") or frame.Header:FindFirstChild("FrameName"))
            local resText = resLabel and resLabel.Text or ""
            local headerText = headerName and headerName.Text or ""
            local upperRes = string.upper(resText)
            local upperHeader = string.upper(headerText)

            local resLabelWon = resLabel and resLabel:FindFirstChild("Won")
            local resLabelLose = resLabel and resLabel:FindFirstChild("Lose")

            if string.find(upperRes, "WON") or string.find(upperRes, "WIN") or string.find(upperRes, "VICTORY")
                or string.find(upperHeader, "WON") or string.find(upperHeader, "WIN") or string.find(upperHeader, "VICTORY")
                or (resLabelWon and resLabelWon.Enabled == true) then
                isVictory = true
            elseif string.find(upperRes, "DEFEAT") or string.find(upperRes, "LOSE")
                or string.find(upperHeader, "DEFEAT") or string.find(upperHeader, "LOSE")
                or (resLabelLose and resLabelLose.Enabled == true) then
                isVictory = false
            else
                isVictory = not (string.find(upperRes, "DEFEAT") or string.find(upperRes, "LOSE"))
            end
        end

        if isVictory and not State.WebhookOnVictory then return end
        if not isVictory and not State.WebhookOnDefeat then return end

        -- 2. Map & Stage Resolution
        local mapInfo = "Battle Match"
        local mapNameLabel = frame and frame:FindFirstChild("Info") and frame.Info:FindFirstChild("MapName")
        local stageNameLabel = frame and frame:FindFirstChild("Info") and frame.Info:FindFirstChild("StageName")
        if mapNameLabel and mapNameLabel.Text ~= "" then
            mapInfo = mapNameLabel.Text
            if stageNameLabel and stageNameLabel.Text ~= "" then
                mapInfo = mapInfo .. " " .. stageNameLabel.Text
            end
        else
            local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayingGui")
            local sm = pg and pg:FindFirstChild("Frame") and pg.Frame:FindFirstChild("MainContainer")
                and pg.Frame.MainContainer:FindFirstChild("StageText")
                and pg.Frame.MainContainer.StageText:FindFirstChild("StageMap")
            if sm and sm.Text and sm.Text ~= "" then
                mapInfo = sm.Text
            elseif lastMatchMapId then
                mapInfo = tostring(lastMatchMapId) .. (lastMatchStageId and (" Stage: " .. tostring(lastMatchStageId)) or "")
            else
                mapInfo = GetCurrentGameMode() or "Battle Match"
            end
        end

        local diffStr = lastMatchDifficulty or State.StoryDiff or ""
        if diffStr ~= "" and not string.find(mapInfo, diffStr) then
            mapInfo = mapInfo .. " (" .. diffStr .. ")"
        end

        -- 3. Time Elapsed Resolution
        local timeFormatted = "00:00"
        if lastMatchTotalTime then
            local secs = tonumber(lastMatchTotalTime)
            if secs and secs > 0 then
                timeFormatted = string.format("%02d:%02d", math.floor(secs / 60), math.floor(secs % 60))
            elseif type(lastMatchTotalTime) == "string" and string.find(lastMatchTotalTime, "%d+:%d+") then
                timeFormatted = string.match(lastMatchTotalTime, "%d+:%d+")
            end
        end

        if timeFormatted == "00:00" and lastMatchHudTimer and lastMatchHudTimer ~= "" and lastMatchHudTimer ~= "00:00" then
            timeFormatted = lastMatchHudTimer
        end

        if timeFormatted == "00:00" then
            local totalTimeLabel = frame and frame:FindFirstChild("Stats") and frame.Stats:FindFirstChild("TotalTime")
            local totalTimeVal = totalTimeLabel and totalTimeLabel:FindFirstChild("Value")
            if totalTimeVal and totalTimeVal.Text ~= "" and totalTimeVal.Text ~= "00:00" then
                timeFormatted = totalTimeVal.Text
            else
                local elapsedSecs = math.max(1, math.floor(os.clock() - (battleStartTime or os.clock())))
                timeFormatted = string.format("%02d:%02d", math.floor(elapsedSecs / 60), math.floor(elapsedSecs % 60))
            end
        end

        -- 4. Stats Resolution (Damage, Mobs, EXP)
        local damageStr = "N/A"
        local mobsStr = "N/A"
        local expStr = "N/A"

        -- Primary: Authoritative server stats (Instant & immune to GUI count-up animations)
        if lastMatchStats and type(lastMatchStats) == "table" then
            if lastMatchStats.TotalDmg and tostring(lastMatchStats.TotalDmg) ~= "0" then
                damageStr = tostring(lastMatchStats.TotalDmg)
            end
            if lastMatchStats.Takedowns and tostring(lastMatchStats.Takedowns) ~= "0" then
                mobsStr = tostring(lastMatchStats.Takedowns)
            end
            if lastMatchStats.BattlepassExp and tostring(lastMatchStats.BattlepassExp) ~= "0" then
                expStr = "+" .. tostring(lastMatchStats.BattlepassExp) .. " BP EXP"
            end
        end

        -- Secondary: EndGame UI fallback
        local statsFrame = frame and frame:FindFirstChild("Stats")
        if statsFrame then
            if damageStr == "N/A" or damageStr == "0" then
                local dmgVal = statsFrame:FindFirstChild("TotalDmg") and statsFrame.TotalDmg:FindFirstChild("Value")
                if dmgVal and dmgVal.Text ~= "" and dmgVal.Text ~= "0" then
                    damageStr = dmgVal.Text
                end
            end
            if mobsStr == "N/A" or mobsStr == "0" then
                local killsVal = statsFrame:FindFirstChild("Takedowns") and statsFrame.Takedowns:FindFirstChild("Value")
                if killsVal and killsVal.Text ~= "" and killsVal.Text ~= "0" then
                    mobsStr = killsVal.Text
                end
            end
            if expStr == "N/A" then
                local bpVal = statsFrame:FindFirstChild("Battlepass XP") and statsFrame["Battlepass XP"]:FindFirstChild("Value")
                if bpVal and bpVal.Text ~= "" then
                    expStr = bpVal.Text .. " BP EXP"
                end
            end
        end

        -- 5. Rewards Resolution
        local rewardsList = {}
        local rf = frame and frame:FindFirstChild("RewardFrame")
        if rf then
            for _, item in ipairs(rf:GetChildren()) do
                if item:IsA("GuiObject") and item.Name ~= "Frame" and item.Name ~= "RewardItemTemplate" then
                    local nameLabel = item:FindFirstChild("ItemName", true)
                    local countLabel = item:FindFirstChild("ItemCount", true)
                    local itemName = (nameLabel and nameLabel.Text ~= "") and nameLabel.Text or item.Name
                    local itemCount = (countLabel and countLabel.Text ~= "") and countLabel.Text or "x1"
                    
                    local icon = "🎁"
                    local lName = string.lower(itemName)
                    if string.find(lName, "coin") then
                        icon = "🪙"
                    elseif string.find(lName, "gem") then
                        icon = "💎"
                    elseif string.find(lName, "shard") then
                        icon = "🔮"
                    elseif string.find(lName, "capsule") then
                        icon = "💊"
                    elseif string.find(lName, "trait") then
                        icon = "📜"
                    elseif string.find(lName, "fruit") or string.find(lName, "fish") or string.find(lName, "pan") then
                        icon = "🍖"
                    end

                    table.insert(rewardsList, icon .. " " .. itemName .. " " .. itemCount)
                end
            end
        end

        if #rewardsList == 0 and lastMatchRewards and type(lastMatchRewards) == "table" then
            if (lastMatchRewards.Coins or 0) > 0 then
                table.insert(rewardsList, "🪙 Coins x" .. tostring(lastMatchRewards.Coins))
            end
            if (lastMatchRewards.Gems or 0) > 0 then
                table.insert(rewardsList, "💎 Gems x" .. tostring(lastMatchRewards.Gems))
            end
            if lastMatchRewards.Items and type(lastMatchRewards.Items) == "table" then
                for _, itm in ipairs(lastMatchRewards.Items) do
                    local itmName = itm.Id or "Item"
                    local itmAmount = itm.Count or itm.Amount or 1
                    table.insert(rewardsList, "🎁 " .. tostring(itmName) .. " x" .. tostring(itmAmount))
                end
            end
            if lastMatchRewards.Units and type(lastMatchRewards.Units) == "table" then
                for _, u in ipairs(lastMatchRewards.Units) do
                    local uName = u.Id or "Unit"
                    local uCount = u.Count or 1
                    local shiny = u.IsShiny and " ✨(Shiny)" or ""
                    table.insert(rewardsList, "⭐ " .. tostring(uName) .. shiny .. " x" .. tostring(uCount))
                end
            end
        end

        local rewardsStr = #rewardsList > 0 and table.concat(rewardsList, "\n") or "None / Standard Drop"

        -- 6. Discord Embed Construction
        local embed = {
            title = isVictory and "🏆 Match Completed - VICTORY!" or "💀 Match Over - DEFEAT",
            color = isVictory and 3066993 or 15158332,
            fields = {
                { name = "🗺️ Map & Stage", value = tostring(mapInfo), inline = true },
                { name = "⏱️ Time Elapsed", value = tostring(timeFormatted), inline = true },
                { name = "⚔️ Damage Dealt", value = tostring(damageStr), inline = true },
                { name = "👾 Mobs Killed", value = tostring(mobsStr), inline = true },
                { name = "✨ EXP Gained", value = tostring(expStr), inline = true },
                { name = "🎁 Rewards", value = tostring(rewardsStr), inline = false }
            },
            footer = { text = "STRIX HUB • Anime Mysterious | Account: " .. LocalPlayer.Name },
            timestamp = DateTime.now():ToIsoDate()
        }

        SendDiscordWebhook(embed)
    end)
end

-- ====================================================================
-- AUTO OPEN CAPSULES (Storage-Safe Capsule Engine)
-- ====================================================================
local function ProcessAutoOpenCapsules()
    if not State.AutoOpenCapsules or not isLobby then return end
    local OpenCapsuleRemote = Remotes and Remotes:FindFirstChild("OpenCapsule")
    if not OpenCapsuleRemote then return end

    local pData = GetReplicaData()
    if not pData then return end

    local maxStorage = pData.MaxStorage or 50
    local currentUnits = 0
    if pData.Inventory then
        for _ in pairs(pData.Inventory) do currentUnits = currentUnits + 1 end
    end

    local safetyBuffer = State.CapsuleMinFreeSlots or 2
    local freeSlots = maxStorage - currentUnits
    if freeSlots <= safetyBuffer then
        return -- Storage protected, never overflow!
    end

    -- Auto-detect ALL capsules from CapsuleData module & ItemInventory (Dynamic Auto-Update)
    local targets = {}
    local seen = {}

    pcall(function()
        local CapsuleDataMod = Modules and Modules:FindFirstChild("Data") and Modules.Data:FindFirstChild("CapsuleData")
        local CapsuleData = CapsuleDataMod and select(2, pcall(require, CapsuleDataMod))
        if CapsuleData and type(CapsuleData.Capsules) == "table" then
            for capId in pairs(CapsuleData.Capsules) do
                if not seen[capId] then
                    seen[capId] = true
                    table.insert(targets, capId)
                end
            end
        end
    end)

    if pData.ItemInventory then
        for itemId, count in pairs(pData.ItemInventory) do
            if count > 0 and not seen[itemId] and string.find(string.lower(itemId), "capsule") then
                seen[itemId] = true
                table.insert(targets, itemId)
            end
        end
    end

    if #targets == 0 then
        targets = { "MysteryCapsule", "HalloweenCapsule" }
    end

    for _, capId in ipairs(targets) do
        local count = (pData.ItemInventory and pData.ItemInventory[capId]) or 0
        if count > 0 then
            local toOpen = math.clamp(math.min(count, freeSlots - safetyBuffer), 1, 100)
            if toOpen > 0 then
                pcall(function()
                    OpenCapsuleRemote:InvokeServer(capId, toOpen)
                end)
                task.wait(0.5)
                return
            end
        end
    end
end

-- ====================================================================
-- AUTO FEED SYSTEM (Food Items Only - Zero Unit Consumption Safety Guarantee)
-- ====================================================================
local function GetExpNeededToMax(unit, maxLvl)
    maxLvl = maxLvl or 100
    local curLvl = unit.Level or 1
    if curLvl >= maxLvl then return 0 end
    local UnitLevelData = Modules and Modules:FindFirstChild("Data") and Modules.Data:FindFirstChild("UnitLevelData")
    if not UnitLevelData then return 0 end
    local uld = select(2, pcall(require, UnitLevelData))
    if not uld or not uld.BaseExp or not uld.Multiplier then return 0 end
    local expNeeded = 0
    for i = curLvl, maxLvl - 1 do
        expNeeded = expNeeded + math.floor(uld.BaseExp * (math.pow(uld.Multiplier, i - 1)))
    end
    return math.max(0, expNeeded - (unit.Exp or 0))
end

-- Exclusively food items from ItemInventory (Namekian Fruit, Mist Fish, Daifuku, Curry, Chocolate, etc.)
-- Character units / duplicate units are NEVER consumed or touched.
local FOOD_ORDER = {
    { Id = "Fruit_1", Exp = 50 },  -- Namekian Fruit
    { Id = "Fruit_2", Exp = 100 }, -- Mist Fish
    { Id = "Fruit_3", Exp = 200 }, -- Daifuku Food
    { Id = "Fruit_4", Exp = 300 }, -- Desert Curry
    { Id = "Fruit_5", Exp = 400 }, -- Feast Chocolate
    { Id = "Fruit_8", Exp = 450 }, -- Acanthus Melon Pan
    { Id = "Fruit_6", Exp = 1000 } -- Exclusive Food
}

local function ProcessAutoFeed()
    if not State.AutoFeed or not isLobby then return end
    local pData = GetReplicaData()
    if not pData or not pData.Inventory then return end

    local FeedUnitRemote = Remotes and Remotes:FindFirstChild("FeedUnit")
    if not FeedUnitRemote then return end

    for uuid, unit in pairs(pData.Inventory) do
        local isTarget = false
        if State.AutoFeedTarget == "All" then
            isTarget = true
        elseif State.AutoFeedTarget == "Equipped" then
            if pData.EquippedSlots then
                for _, eqUUID in pairs(pData.EquippedSlots) do
                    if eqUUID == uuid then isTarget = true break end
                end
            end
        elseif State.AutoFeedTarget == uuid or State.AutoFeedTarget == unit.UnitId then
            isTarget = true
        end

        -- Auto Feed to max level with cheapest food
        if isTarget and FeedUnitRemote then
            local expNeeded = GetExpNeededToMax(unit, 100)
            if expNeeded > 0 and pData.ItemInventory then
                local queue = {}
                local accumulatedExp = 0
                for _, food in ipairs(FOOD_ORDER) do
                    local available = pData.ItemInventory[food.Id] or 0
                    if available > 0 and accumulatedExp < expNeeded then
                        local neededUnits = math.ceil((expNeeded - accumulatedExp) / food.Exp)
                        local countToAdd = math.min(available, neededUnits)
                        if countToAdd > 0 then
                            queue[food.Id] = countToAdd
                            accumulatedExp = accumulatedExp + (countToAdd * food.Exp)
                        end
                    end
                end
                if next(queue) ~= nil then
                    pcall(function() FeedUnitRemote:FireServer(uuid, queue) end)
                    task.wait(0.3)
                end
            end
        end
    end
end

-- ====================================================================
-- AUTO TRAIT REROLL SYSTEM (Target Traits & In-Game Stop List - Fast Engine & Protection)
-- ====================================================================
local isAutoRollingTraits = false
local cachedTraitsModule = nil
local cachedTraitsData = nil

local function GetTraitsModules()
    if not cachedTraitsModule then
        local tmObj = Modules and Modules:FindFirstChild("TraitsModule")
        if tmObj then
            local ok, m = pcall(require, tmObj)
            if ok then cachedTraitsModule = m end
        end
    end
    if not cachedTraitsData then
        local tdObj = Modules and Modules:FindFirstChild("Data") and Modules.Data:FindFirstChild("TraitsData")
        if tdObj then
            local ok, d = pcall(require, tdObj)
            if ok then cachedTraitsData = d end
        end
    end
    return cachedTraitsModule, cachedTraitsData
end

local function FindUnitByUUID(inventory, targetUUID)
    if not inventory or type(inventory) ~= "table" then return nil end
    if not targetUUID or targetUUID == "" then return nil end

    if inventory[targetUUID] and type(inventory[targetUUID]) == "table" then
        return inventory[targetUUID]
    end

    for _, u in pairs(inventory) do
        if type(u) == "table" and u.UUID == targetUUID then
            return u
        end
    end

    return nil
end

local function CheckIfTraitMatches(pTrait, sTrait, tm, TraitsData)
    if not pTrait and not sTrait then return false, nil, nil, nil end

    local primaryName = (TraitsData and TraitsData.TraitsData and TraitsData.TraitsData[pTrait] and TraitsData.TraitsData[pTrait].TraitDisplayName) or pTrait
    local subName = sTrait and ((TraitsData and TraitsData.TraitsData and TraitsData.TraitsData[sTrait] and TraitsData.TraitsData[sTrait].TraitDisplayName) or sTrait) or ""

    -- 1. Check TargetTraits
    for k, v in pairs(State.TargetTraits or {}) do
        local target = (type(k) == "string" and v == true) and k or v
        if type(target) == "string" and target ~= "" then
            if target == pTrait or target == primaryName or (sTrait and (target == sTrait or target == subName)) then
                return true, primaryName, subName, "TargetTrait"
            end
        end
    end

    -- 2. Check In-Game Stop List
    if State.RespectInGameStopList and tm and tm.StopConfig then
        if (pTrait and tm.StopConfig[pTrait] == true) or (sTrait and tm.StopConfig[sTrait] == true) then
            return true, primaryName, subName, "InGameStopList"
        end
    end

    return false, primaryName, subName, nil
end

local function ProcessAutoTraitReroll()
    if not State.AutoTraitReroll or not isLobby or isAutoRollingTraits then return end
    local RerollTraitRemote = Remotes and Remotes:FindFirstChild("RerollTrait")
    if not RerollTraitRemote then return end

    local pData = GetReplicaData()
    if not pData or not pData.Inventory then return end

    local targetUUID = State.TraitRerollTargetUnit
    local unitObj = nil
    if targetUUID and targetUUID ~= "" then
        unitObj = FindUnitByUUID(pData.Inventory, targetUUID)
    end

    if not unitObj and pData.EquippedSlots and pData.EquippedSlots[1] then
        targetUUID = pData.EquippedSlots[1]
        unitObj = FindUnitByUUID(pData.Inventory, targetUUID)
    end

    if not unitObj or not targetUUID then
        State.AutoTraitReroll = false
        if MacLib.Options["Toggle_AutoTraitReroll"] then
            pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
        end
        return
    end

    local tm, TraitsData = GetTraitsModules()

    -- SAFETY PRE-CHECK BEFORE ROLLING: Check if unit already has target / stop trait!
    local alreadyMatches, curPName, curSName = CheckIfTraitMatches(unitObj.Trait, unitObj.SubTrait, tm, TraitsData)
    if alreadyMatches then
        State.AutoTraitReroll = false
        if MacLib.Options["Toggle_AutoTraitReroll"] then
            pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
        end
        pcall(function()
            MacLib:Notify({
                Title = "Trait Protected!",
                Description = "Unit already has target trait: " .. tostring(curPName) .. (curSName ~= "" and (" / " .. curSName) or "") .. "!\nAuto Reroll stopped to prevent losing it.",
                Lifetime = 6
            })
        end)
        return
    end

    local traitItemCount = (pData.ItemInventory and pData.ItemInventory.Trait) or 0
    if traitItemCount <= 0 then
        State.AutoTraitReroll = false
        if MacLib.Options["Toggle_AutoTraitReroll"] then
            pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
        end
        pcall(function()
            MacLib:Notify({
                Title = "Auto Trait Reroll",
                Description = "Out of Trait items!",
                Lifetime = 4
            })
        end)
        return
    end

    isAutoRollingTraits = true
    task.spawn(function()
        while isScriptRunning and State.AutoTraitReroll and isLobby do
            local currentPData = GetReplicaData()
            if not currentPData or not currentPData.Inventory then
                task.wait(0.1)
                continue
            end

            -- Re-verify unit in inventory
            local curUnit = FindUnitByUUID(currentPData.Inventory, targetUUID)
            if not curUnit then
                State.AutoTraitReroll = false
                if MacLib.Options["Toggle_AutoTraitReroll"] then
                    pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
                end
                break
            end

            -- Pre-check before each roll in loop
            local isPreMatch, pNamePre, sNamePre = CheckIfTraitMatches(curUnit.Trait, curUnit.SubTrait, tm, TraitsData)
            if isPreMatch then
                State.AutoTraitReroll = false
                if MacLib.Options["Toggle_AutoTraitReroll"] then
                    pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
                end
                pcall(function()
                    MacLib:Notify({
                        Title = "Trait Protected!",
                        Description = "Unit already has: " .. tostring(pNamePre) .. (sNamePre ~= "" and (" / " .. sNamePre) or "") .. "!",
                        Lifetime = 5
                    })
                end)
                break
            end

            local itemsLeft = (currentPData.ItemInventory and currentPData.ItemInventory.Trait) or 0
            if itemsLeft <= 0 then
                State.AutoTraitReroll = false
                if MacLib.Options["Toggle_AutoTraitReroll"] then
                    pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
                end
                pcall(function()
                    MacLib:Notify({
                        Title = "Auto Trait Reroll",
                        Description = "Out of Trait items!",
                        Lifetime = 4
                    })
                end)
                break
            end

            -- Execute Remote
            local ok, success, pTrait, sTrait = pcall(function()
                return RerollTraitRemote:InvokeServer(targetUUID)
            end)

            if not ok or not success then
                State.AutoTraitReroll = false
                if MacLib.Options["Toggle_AutoTraitReroll"] then
                    pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
                end
                break
            end

            -- Post-roll check
            local isPostMatch, pNamePost, sNamePost = CheckIfTraitMatches(pTrait, sTrait, tm, TraitsData)
            if isPostMatch then
                State.AutoTraitReroll = false
                if MacLib.Options["Toggle_AutoTraitReroll"] then
                    pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(false) end)
                end
                pcall(function()
                    MacLib:Notify({
                        Title = "Auto Trait Reroll",
                        Description = "🎯 Target Trait Reached: " .. tostring(pNamePost) .. (sNamePost ~= "" and (" / " .. sNamePost) or "") .. "!",
                        Lifetime = 5
                    })
                end)
                break
            end

            local delayTime = tonumber(State.TraitRerollDelay) or 0.02
            if delayTime > 0 then
                task.wait(delayTime)
            else
                task.wait()
            end
        end

        isAutoRollingTraits = false
    end)
end

-- ====================================================================
-- PARTY SYSTEM (Host / Alt Room Coordination, Invites, Follow)
-- ====================================================================
local PARTY_HOST_FILE = "STRIX HUB/party_host.json"
local RefreshAltsUIRef = nil
local UpdateAltsParagraphRef = nil
local lastPartyWaitNotification = 0
local lastAltUiRefresh = 0

local function NormalizeUsername(name)
    if not name then return "" end
    return string.gsub(tostring(name), "%s+", "")
end

local function GetPartyAltsList()
    local list = {}
    if type(State.PartyAlts) == "table" then
        for _, name in ipairs(State.PartyAlts) do
            local clean = NormalizeUsername(name)
            if clean ~= "" then
                table.insert(list, clean)
            end
        end
    end
    if #list == 0 and type(State.PartyAltsWhitelist) == "string" and State.PartyAltsWhitelist ~= "" then
        for name in string.gmatch(State.PartyAltsWhitelist, "[^,;%s]+") do
            table.insert(list, name)
        end
    end
    return list
end

local function GetPlayersInRoom()
    local playersInRoom = {}
    local PlayGUI = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PlayGUI")
    local pf = PlayGUI and PlayGUI:FindFirstChild("PlayFrame")
    local container = pf and pf:FindFirstChild("Details") and pf.Details:FindFirstChild("Player") and pf.Details.Player:FindFirstChild("Container")
    if container then
        for _, child in ipairs(container:GetChildren()) do
            if string.sub(child.Name, 1, 7) == "Player_" then
                local pName = string.sub(child.Name, 8)
                if pName ~= "" then
                    table.insert(playersInRoom, pName)
                end
            end
        end
    end
    return playersInRoom
end

local function AreAllAltsInRoom()
    local alts = GetPartyAltsList()
    if #alts == 0 then
        return true, {}
    end
    local inRoom = GetPlayersInRoom()
    local missingAlts = {}
    for _, altName in ipairs(alts) do
        local found = false
        local lowerAlt = string.lower(altName)
        for _, roomUser in ipairs(inRoom) do
            if string.lower(roomUser) == lowerAlt then
                found = true
                break
            end
        end
        if not found then
            table.insert(missingAlts, altName)
        end
    end
    return (#missingAlts == 0), missingAlts
end

local function ProcessPartySystem()
    if not State.PartyEnabled or not isLobby then return end

    local altsList = GetPartyAltsList()

    -- HOST ROLE
    if State.PartyRole == "Host" then
        pcall(function()
            local hostInfo = {
                Host = LocalPlayer.Name,
                HostUserId = LocalPlayer.UserId,
                JobId = game.JobId,
                PlaceId = game.PlaceId,
                Timestamp = os.time(),
                InRoom = IsRoomCreated()
            }
            writefile(PARTY_HOST_FILE, HttpService:JSONEncode(hostInfo))
        end)

        if IsRoomCreated() then
            -- Auto Invite Alts
            if State.PartyAutoInvite then
                local LobbyInvite = Remotes and Remotes:FindFirstChild("LobbyInvite")
                if LobbyInvite then
                    local inRoom = GetPlayersInRoom()
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local pLower = string.lower(player.Name)
                            local isAlt = false
                            for _, a in ipairs(altsList) do
                                if string.lower(a) == pLower then
                                    isAlt = true
                                    break
                                end
                            end
                            local alreadyIn = false
                            for _, rName in ipairs(inRoom) do
                                if string.lower(rName) == pLower then
                                    alreadyIn = true
                                    break
                                end
                            end
                            if isAlt and not alreadyIn then
                                pcall(function() LobbyInvite:FireServer(player) end)
                            end
                        end
                    end
                end
            end
        end

    -- ALT ROLE
    elseif State.PartyRole == "Alt" then
        local targetHost = string.lower(NormalizeUsername(State.PartyHost or ""))
        if targetHost == "" then return end

        -- 1. Auto Follow Host Server
        if State.PartyAutoFollow and isfile and isfile(PARTY_HOST_FILE) then
            local ok, info = pcall(function() return HttpService:JSONDecode(readfile(PARTY_HOST_FILE)) end)
            if ok and type(info) == "table" and string.lower(NormalizeUsername(info.Host or "")) == targetHost then
                if info.JobId and info.JobId ~= game.JobId and os.time() - (info.Timestamp or 0) < 60 then
                    pcall(function()
                        game:GetService("TeleportService"):TeleportToPlaceInstance(info.PlaceId or game.PlaceId, info.JobId, LocalPlayer)
                    end)
                    task.wait(5)
                    return
                end
            end
        end

        -- 2. Join Host's Room in same server
        if (State.PartyAutoJoin ~= false) and not IsRoomCreated() then
            local GetLobbyList = Remotes and Remotes:FindFirstChild("GetLobbyList")
            local RequestJoinLobby = Remotes and Remotes:FindFirstChild("RequestJoinLobby")
            if GetLobbyList and RequestJoinLobby then
                local ok, lobbies = pcall(function() return GetLobbyList:InvokeServer() end)
                if ok and type(lobbies) == "table" then
                    for _, room in ipairs(lobbies) do
                        if string.lower(NormalizeUsername(room.HostName or "")) == targetHost then
                            pcall(function()
                                RequestJoinLobby:InvokeServer("Join", room.RoomId)
                            end)
                            break
                        end
                    end
                end
            end
        end
    end

    if os.clock() - lastAltUiRefresh > 2.5 then
        lastAltUiRefresh = os.clock()
        if UpdateAltsParagraphRef then
            pcall(UpdateAltsParagraphRef)
        end
    end
end

-- Alt Invite Auto-Accept Listener
pcall(function()
    local LobbyInvite = Remotes and Remotes:FindFirstChild("LobbyInvite")
    local RequestJoinLobby = Remotes and Remotes:FindFirstChild("RequestJoinLobby")
    if LobbyInvite and RequestJoinLobby then
        LobbyInvite.OnClientEvent:Connect(function(hostPlayer, roomId)
            if State.PartyEnabled and State.PartyRole == "Alt" and (State.PartyAutoJoin ~= false) and hostPlayer then
                local targetHost = string.lower(NormalizeUsername(State.PartyHost or ""))
                local hName = string.lower(hostPlayer.Name or "")
                local hDisplay = string.lower(hostPlayer.DisplayName or "")
                if targetHost ~= "" and (hName == targetHost or hDisplay == targetHost) then
                    pcall(function()
                        RequestJoinLobby:InvokeServer("Join", roomId)
                    end)
                end
            end
        end)
    end
end)

--// Feature: Auto Leave Stage When Host Leaves
local hostSeenInBattle = false
local hostCheckStartTime = os.clock()

local function GetResolvedPartyHost()
    local hostName = NormalizeUsername(State.PartyHost or "")
    if hostName ~= "" then
        return hostName
    end
    if isfile and isfile(PARTY_HOST_FILE) then
        local ok, info = pcall(function() return HttpService:JSONDecode(readfile(PARTY_HOST_FILE)) end)
        if ok and type(info) == "table" and info.Host and info.Host ~= "" then
            return NormalizeUsername(info.Host)
        end
    end
    return nil
end

CheckHostLeftAndAutoLeave = function()
    if not isBattlePlace or hasHandledLeave then return end
    if not State.PartyAutoLeaveOnHostLeave then return end
    if State.PartyRole == "Host" then return end

    local targetHost = GetResolvedPartyHost()
    if not targetHost or targetHost == "" then return end

    local myName = string.lower(NormalizeUsername(LocalPlayer.Name))
    local tLower = string.lower(targetHost)
    if tLower == myName then return end

    local isHostPresent = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pName = string.lower(NormalizeUsername(p.Name))
            local pDisplay = string.lower(NormalizeUsername(p.DisplayName))
            if pName == tLower or pDisplay == tLower then
                isHostPresent = true
                hostSeenInBattle = true
                break
            end
        end
    end

    if hostSeenInBattle then
        if not isHostPresent then
            print("[STRIX HUB] Host (" .. targetHost .. ") has left the match. Auto leaving to lobby...")
            ExecuteLeaveToLobby("Host Left", "Host has left the match! Returning to Lobby...")
            return
        end
    else
        -- Host has not been seen yet in this match
        -- 1. Check if host's file already shows host has left or returned to Lobby
        if isfile and isfile(PARTY_HOST_FILE) then
            local ok, info = pcall(function() return HttpService:JSONDecode(readfile(PARTY_HOST_FILE)) end)
            if ok and type(info) == "table" and info.Host and string.lower(NormalizeUsername(info.Host)) == tLower then
                local isHostInLobby = (info.PlaceId == LOBBY_PLACE_ID or info.PlaceId == LOBBY_ALT_PLACE_ID)
                if isHostInLobby and os.time() - (info.Timestamp or 0) < 60 then
                    print("[STRIX HUB] Host file indicates host is in Lobby. Leaving to lobby...")
                    ExecuteLeaveToLobby("Host Left", "Host is in Lobby! Returning to Lobby...")
                    return
                end
            end
        end

        -- 2. Grace period: Wait up to 45 seconds for host to join before considering abandoned
        if os.clock() - hostCheckStartTime > 45 then
            print("[STRIX HUB] Host (" .. targetHost .. ") did not join match after 45s. Returning to Lobby...")
            ExecuteLeaveToLobby("Host Missing", "Host not found after 45s! Returning to Lobby...")
            return
        end
    end
end

-- Fast reactive detection for Host leaving match
pcall(function()
    Players.PlayerRemoving:Connect(function(player)
        if not isBattlePlace or hasHandledLeave then return end
        if not State.PartyAutoLeaveOnHostLeave then return end
        if State.PartyRole == "Host" then return end

        local targetHost = GetResolvedPartyHost()
        if not targetHost or targetHost == "" then return end

        local myName = string.lower(NormalizeUsername(LocalPlayer.Name))
        local tLower = string.lower(targetHost)
        if tLower == myName then return end

        local pName = string.lower(NormalizeUsername(player.Name))
        local pDisplay = string.lower(NormalizeUsername(player.DisplayName))

        if pName == tLower or pDisplay == tLower then
            print("[STRIX HUB] Host (" .. player.Name .. ") left the match! Triggering auto-leave to lobby...")
            task.delay(1, function()
                if not hasHandledLeave and isBattlePlace then
                    ExecuteLeaveToLobby("Host Left", "Host has left the match! Returning to Lobby...")
                end
            end)
        end
    end)
end)

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
    
    -- If room already exists and matches what we want, no need to recreate
    if IsRoomCreated() then
        if DoesRoomMatch(mode, cleanName, stageNum, diff) and not forceRecreate then
            return true, "Room already matches"
        end
        -- Otherwise room is wrong or force requested: leave and reset cleanly
        pcall(function()
            if LeaveLobbyEvent then LeaveLobbyEvent:FireServer() end
            if PlayModule and PlayModule.CloseModule then PlayModule.CloseModule() end
        end)
        task.wait(0.35)
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
        if RequestJoinLobby then
            RequestJoinLobby:InvokeServer("Create")
        end
    end)
    task.wait(0.2)
    
    if PlayModule then
        PlayModule.SessionMode = mode
        PlayModule.isHost = true
        if PlayModule.OpenTargetMap then
            pcall(function()
                PlayModule.OpenTargetMap(mode, mapId, stageNum, diff)
            end)
        end
    end
    
    task.wait(0.35)
    
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
    
    task.wait(0.25)
    
    -- Feature 3: Direct sync to guarantee PlayFrame is opened and server state matches
    pcall(function()
        if not enteredPlayFrame and PlayModule and PlayModule.OpenPlayFrame then
            PlayModule.OpenPlayFrame()
        end
        if UpdateLobbySettings then
            UpdateLobbySettings:FireServer(cleanName, tostring(stageNum), {}, diff, mapId, mode)
        end
    end)
    
    local t0 = os.clock()
    while (os.clock() - t0 < 1.0) do
        if IsRoomCreated() then break end
        task.wait(0.1)
    end
    
    return IsRoomCreated()
end

--// Feature 4: Dual-Trigger Match Start & Teleport Reliability
local lastMatchStartTrigger = 0
local function TriggerMatchStart(overrideMode, overrideMap, overrideStage, overrideDiff, force)
    if not force and os.clock() - lastMatchStartTrigger < 2.0 then
        return false, "Debounce"
    end
    
    local room = GetCurrentRoomInfo()
    if not room then return false, "No active room" end
    
    if room.IsTeleporting then
        return true, "Already teleporting"
    end

    -- Party System Gate: If Party is enabled and role is Host, wait for all ALTs before match start
    if not force and State.PartyEnabled and State.PartyRole == "Host" then
        local allIn, missing = AreAllAltsInRoom()
        if not allIn and #missing > 0 then
            if os.clock() - lastPartyWaitNotification > 4.0 then
                lastPartyWaitNotification = os.clock()
                pcall(function()
                    MacLib:Notify({
                        Title = "Party System",
                        Description = "⏳ Waiting for ALTs (" .. #missing .. " missing): " .. table.concat(missing, ", "),
                        Lifetime = 3.5
                    })
                end)
            end
            return false, "Waiting for ALTs"
        end
    end
    
    if room.Gui and not room.Gui.Enabled then
        room.Gui.Enabled = true
    end
    
    if PlayModule then
        PlayModule.isHost = true
    end
    
    -- 1. Click in-game PlayBtn in PlayFrame if present
    local playBtn = room.PlayBtn
    if playBtn and playBtn.Visible and playBtn.Text ~= "Teleporting..." then
        playBtn.Interactable = true
        SafeClick(playBtn)
    end
    
    -- 2. Extract and resolve mode, map, stage, difficulty for dual-trigger remote
    local mode = overrideMode or room.Mode
    local mapName = overrideMap or room.MapName
    local stage = overrideStage or room.StageNum
    local diff = overrideDiff or room.Diff
    
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
    
    -- 3. Direct TeleportRequest firing (Dual-Trigger failsafe to battle place 97246719761307)
    if TeleportRequest and mapId and mode then
        pcall(function()
            TeleportRequest:FireServer(97246719761307, mode, mapId, tostring(stageNum), diffStr)
        end)
    end
    
    lastMatchStartTrigger = os.clock()
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

--// Resizable Window Setup (Responsive Screen Auto-Scale + Drag to Resize + Proportion Fix)
local UpdateResponsiveScaleRef = nil

local function SetupWindowResize()
    local targetScreenGui
    local parent = (gethui and gethui()) or game:GetService("CoreGui")

    -- Retry briefly to ensure ScreenGui is ready
    local deadline = os.clock() + 3
    repeat
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("ScreenGui") and v:FindFirstChild("Base") then
                targetScreenGui = v
                break
            end
        end
        if not targetScreenGui and os.clock() < deadline then
            task.wait(0.05)
        end
    until targetScreenGui or os.clock() >= deadline

    if not targetScreenGui or not targetScreenGui:FindFirstChild("Base") then return end
    local base = targetScreenGui.Base

    -- Ensure BaseUIScale is active (never destroy it, used for proportional screen scaling)
    local baseUIScale = base:FindFirstChild("BaseUIScale")
    if not baseUIScale or not baseUIScale:IsA("UIScale") then
        baseUIScale = Instance.new("UIScale")
        baseUIScale.Name = "BaseUIScale"
        baseUIScale.Parent = base
    end

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

    local DESIGN_BASE_W = 868
    local DESIGN_BASE_H = 650
    local MIN_W, MAX_W = 720, 1150
    local MIN_H, MAX_H = 460, 850

    local function GetScreenDimensions()
        local w = (targetScreenGui and targetScreenGui.AbsoluteSize.X > 0 and targetScreenGui.AbsoluteSize.X)
        local h = (targetScreenGui and targetScreenGui.AbsoluteSize.Y > 0 and targetScreenGui.AbsoluteSize.Y)
        if not w or not h or w < 100 or h < 100 then
            local cam = workspace.CurrentCamera
            if cam and cam.ViewportSize.X > 100 and cam.ViewportSize.Y > 100 then
                w = cam.ViewportSize.X
                h = cam.ViewportSize.Y
            else
                w = 1280
                h = 720
            end
        end
        return w, h
    end

    local function CalculateFitScale()
        local screenW, screenH = GetScreenDimensions()
        -- Dynamic margin based on screen width/height to maximize usable space on tight screens
        local marginX = (screenW < 750) and 10 or ((screenW < 1000) and 16 or 24)
        local marginY = (screenH < 550) and 10 or ((screenH < 750) and 16 or 24)
        local availW = math.max(screenW - marginX * 2, 200)
        local availH = math.max(screenH - marginY * 2, 180)

        -- Peg scaling to DESIGN dimensions (or custom larger dimensions), never inflate scale when window is shrunk
        local refW = math.max(DESIGN_BASE_W, (base.Size and base.Size.X.Offset) or DESIGN_BASE_W)
        local refH = math.max(DESIGN_BASE_H, (base.Size and base.Size.Y.Offset) or DESIGN_BASE_H)

        local scaleX = availW / refW
        local scaleY = availH / refH
        local autoFit = math.min(scaleX, scaleY)

        -- Intelligent scale ceiling based on display resolution (crisp on 4K, native on 1080p, auto-fit on small)
        local maxScale = 1.0
        if screenW >= 3400 and screenH >= 1900 then
            maxScale = 1.30
        elseif screenW >= 2400 and screenH >= 1300 then
            maxScale = 1.15
        end

        local minScale = 0.35
        return math.clamp(autoFit, minScale, maxScale)
    end

    local function ClampWindowBounds(targetScale)
        if not base or not base.Parent then return end
        local s = targetScale or (baseUIScale and baseUIScale.Scale) or 1
        if s <= 0 then s = 1 end
        local screenW, screenH = GetScreenDimensions()

        local curBaseW = (base.Size.X.Offset > 0 and base.Size.X.Offset) or DESIGN_BASE_W
        local curBaseH = (base.Size.Y.Offset > 0 and base.Size.Y.Offset) or DESIGN_BASE_H

        local visualW = curBaseW * s
        local visualH = curBaseH * s

        local halfW = visualW * 0.5
        local halfH = visualH * 0.5

        -- Center point in screen pixels
        local currentCenterX = base.Position.X.Scale * screenW + base.Position.X.Offset
        local currentCenterY = base.Position.Y.Scale * screenH + base.Position.Y.Offset

        local margin = 8
        local minX = halfW + margin
        local maxX = screenW - halfW - margin
        local minY = halfH + margin
        local maxY = screenH - halfH - margin

        local targetCenterX, targetCenterY
        if maxX <= minX then
            targetCenterX = screenW * 0.5
        else
            targetCenterX = math.clamp(currentCenterX, minX, maxX)
        end

        if maxY <= minY then
            targetCenterY = screenH * 0.5
        else
            targetCenterY = math.clamp(currentCenterY, minY, maxY)
        end

        base.AnchorPoint = Vector2.new(0.5, 0.5)
        base.Position = UDim2.new(0.5, math.round(targetCenterX - screenW * 0.5), 0.5, math.round(targetCenterY - screenH * 0.5))
    end

    local function UpdateResponsiveScale(forceCenter)
        if not base or not base.Parent then return end
        EnforceFrameLayout()
        local scale = CalculateFitScale()
        baseUIScale.Scale = scale
        if forceCenter then
            base.AnchorPoint = Vector2.new(0.5, 0.5)
            base.Position = UDim2.fromScale(0.5, 0.5)
        else
            ClampWindowBounds(scale)
        end
    end

    UpdateResponsiveScaleRef = UpdateResponsiveScale

    -- Viewport & Resolution Change Listeners
    local resizeConnections = {}
    local function CleanResizeConnections()
        for _, c in ipairs(resizeConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(resizeConnections)
    end
    getgenv().STRIX_UI_RESIZE_CLEANUP = CleanResizeConnections

    local resizeDebounce = false
    local function SafeTriggerResize()
        if resizeDebounce or resizingType then return end
        resizeDebounce = true
        task.delay(0.05, function()
            resizeDebounce = false
            pcall(function()
                if not resizingType then
                    UpdateResponsiveScale(false)
                end
            end)
        end)
    end

    table.insert(resizeConnections, targetScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(SafeTriggerResize))
    local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 5)
    if camera then
        table.insert(resizeConnections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(SafeTriggerResize))
    end
    table.insert(resizeConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local newCam = workspace.CurrentCamera
        if newCam then
            table.insert(resizeConnections, newCam:GetPropertyChangedSignal("ViewportSize"):Connect(SafeTriggerResize))
        end
        SafeTriggerResize()
    end))

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

    table.insert(resizeConnections, UserInputService.InputChanged:Connect(function(input)
        if resizingType and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local currentScale = (baseUIScale and baseUIScale.Scale) or 1
            if currentScale <= 0 then currentScale = 1 end

            local delta = (input.Position - startMousePos) / currentScale
            local newW = startOffsetSize.X
            local newH = startOffsetSize.Y

            local screenW, screenH = GetScreenDimensions()
            local marginX = (screenW < 750) and 10 or ((screenW < 1000) and 16 or 24)
            local marginY = (screenH < 550) and 10 or ((screenH < 750) and 16 or 24)
            local availW = math.max(screenW - marginX * 2, 200)
            local availH = math.max(screenH - marginY * 2, 180)

            local effMaxW = math.clamp(math.floor(availW / currentScale), MIN_W, MAX_W)
            local effMaxH = math.clamp(math.floor(availH / currentScale), MIN_H, MAX_H)

            if resizingType == "Corner" then
                newW = math.clamp(startOffsetSize.X + delta.X, MIN_W, effMaxW)
                newH = math.clamp(startOffsetSize.Y + delta.Y, MIN_H, effMaxH)
            elseif resizingType == "Right" then
                newW = math.clamp(startOffsetSize.X + delta.X, MIN_W, effMaxW)
            elseif resizingType == "Bottom" then
                newH = math.clamp(startOffsetSize.Y + delta.Y, MIN_H, effMaxH)
            end

            local diffX = (newW - startOffsetSize.X) * currentScale
            local diffY = (newH - startOffsetSize.Y) * currentScale

            base.Size = UDim2.fromOffset(newW, newH)
            base.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + (diffX * 0.5),
                startPos.Y.Scale, startPos.Y.Offset + (diffY * 0.5)
            )
            EnforceFrameLayout()
            State.UISize = { Width = newW, Height = newH }
            ClampWindowBounds(currentScale)
        end
    end))

    table.insert(resizeConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if resizingType then
                resizingType = nil
                grip.ImageTransparency = 0.5
                local currentScale = (baseUIScale and baseUIScale.Scale) or 1
                EnforceFrameLayout()
                ClampWindowBounds(currentScale)
                SaveConfigDebounced()
            else
                -- If dragging ended, clamp cleanly so window never gets pushed outside screen
                task.defer(function()
                    pcall(function()
                        ClampWindowBounds()
                    end)
                end)
            end
        end
    end))

    -- Initial startup auto-adaptation: calculate fit scale & center immediately
    UpdateResponsiveScale(true)
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
    Party = TabGroup:Tab({ Name = "Party", Image = "rbxassetid://10747373426" }), -- lucide-users
    Gameplay = TabGroup:Tab({ Name = "Gameplay", Image = "rbxassetid://10723395215" }), -- lucide-gamepad-2
    Units = TabGroup:Tab({ Name = "Units & Items", Image = "rbxassetid://10734966248" }), -- lucide-star
    SummonShop = TabGroup:Tab({ Name = "Summon & Shop", Image = "rbxassetid://10734952479" }), -- lucide-shopping-cart
    Webhook = TabGroup:Tab({ Name = "Webhook", Image = "rbxassetid://10709775704" }), -- lucide-bell
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
        if val and IsRoomCreated() then
            task.spawn(TriggerMatchStart)
        end
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
    if ok and type(data) == "table" then
        local repData = GetReplicaData()
        local cleared = (type(repData) == "table" and repData.ClearedChallenges) or {}
        
        local text = ""
        for _, modeName in ipairs({ "Weekly", "Daily", "Regular" }) do
            local ch = data[modeName]
            if ch then
                local isCleared = (ch.PeriodIndex or 0) <= (cleared[modeName] or 0)
                text = text .. string.format("[%s] %s (Stage %s) - %s\n", modeName, ch.MapName or ch.MapToCreate, tostring(ch.StageName), isCleared and "CLEARED" or "AVAILABLE")
            end
        end
        if ChallengeInfoLabel and ChallengeInfoLabel.UpdateName then
            pcall(function() ChallengeInfoLabel:UpdateName(text) end)
        end
    end
end

ChallengeSections.Info:Button({
    Name = "Refresh Challenge Info",
    Callback = UpdateChallengeInfoDisplay
})

-- ====================================================================
-- TAB: UNITS & ITEMS (Capsules, Feed, Evolve, Traits)
-- ====================================================================
local UnitsSections = {
    Capsules = Tabs.Units:Section({ Side = "Left" }),
    FeedEvolve = Tabs.Units:Section({ Side = "Left" }),
    Traits = Tabs.Units:Section({ Side = "Right" })
}

-- 1. Capsules Section
UnitsSections.Capsules:Header({ Text = "Capsule Automation" })

UnitsSections.Capsules:Toggle({
    Name = "Auto Open All Capsules",
    Default = (State.AutoOpenCapsules == true),
    Callback = function(val)
        State.AutoOpenCapsules = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoOpenCapsules")

UnitsSections.Capsules:Slider({
    Name = "Safety Buffer Slots",
    Minimum = 1,
    Maximum = 10,
    Min = 1,
    Max = 10,
    Default = State.CapsuleMinFreeSlots or 2,
    Callback = function(val)
        State.CapsuleMinFreeSlots = val
        SaveConfigDebounced()
    end
}, "Slider_CapsuleMinFreeSlots")

UnitsSections.Capsules:Button({
    Name = "Open Safe Batch Now",
    Callback = function()
        ProcessAutoOpenCapsules()
    end
})

-- 2. Feed Section
UnitsSections.FeedEvolve:Header({ Text = "Auto Feed" })

UnitsSections.FeedEvolve:Toggle({
    Name = "Auto Feed to Max Level",
    Default = (State.AutoFeed == true),
    Callback = function(val)
        State.AutoFeed = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoFeed")

UnitsSections.FeedEvolve:Dropdown({
    Name = "Feed Target",
    Multi = false,
    Required = true,
    Options = { "Equipped Units", "All Units" },
    Default = State.AutoFeedTarget == "All" and "All Units" or "Equipped Units",
    Callback = function(val)
        State.AutoFeedTarget = (val == "All Units") and "All" or "Equipped"
        SaveConfigDebounced()
    end
}, "Dropdown_AutoFeedTarget")

-- 3. Traits Section
UnitsSections.Traits:Header({ Text = "Trait Reroll Automation" })

UnitsSections.Traits:Toggle({
    Name = "Auto Trait Reroll",
    Default = (State.AutoTraitReroll == true),
    Callback = function(val)
        State.AutoTraitReroll = val
        SaveConfigDebounced()
        if val then
            task.spawn(ProcessAutoTraitReroll)
        end
    end
}, "Toggle_AutoTraitReroll")

UnitsSections.Traits:Slider({
    Name = "Reroll Delay (Seconds)",
    Minimum = 0,
    Maximum = 0.5,
    Default = State.TraitRerollDelay or 0.02,
    Precision = 2,
    Callback = function(val)
        State.TraitRerollDelay = val
        SaveConfigDebounced()
    end
}, "Slider_TraitRerollDelay")

local traitOptions = {
    -- Mythic (God Tier)
    "Absolute Ego",
    "Twin Stars",
    "Efficient King",
    "Aura Burst",
    "Phantom Blade",
    "Eternal Guardian",
    -- Legendary (High Tier)
    "Cross X",
    "Puch Burst",
    "Health Devil",
    "Enegy Arrow",
    -- Epic (Mid Tier)
    "Executioner",
    "Sharpshooter",
    "Skillful",
    "Haste",
    -- Rare (Low Tier)
    "Human Damage",
    "Human AS",
    "Human Range",
    "Human Health"
}

UnitsSections.Traits:Dropdown({
    Name = "Target Traits",
    Multi = true,
    Required = false,
    Options = traitOptions,
    Default = State.TargetTraits or { "Absolute Ego", "Twin Stars", "Aura Burst" },
    Callback = function(val)
        local selectedList = {}
        if type(val) == "table" then
            for k, v in pairs(val) do
                if type(k) == "string" and v == true then
                    table.insert(selectedList, k)
                elseif type(v) == "string" then
                    table.insert(selectedList, v)
                end
            end
        end
        State.TargetTraits = selectedList
        SaveConfigDebounced()
    end
}, "Dropdown_TargetTraits")

UnitsSections.Traits:Toggle({
    Name = "Respect In-Game Stop List",
    Default = (State.RespectInGameStopList ~= false),
    Callback = function(val)
        State.RespectInGameStopList = val
        SaveConfigDebounced()
    end
}, "Toggle_RespectInGameStopList")

UnitsSections.Traits:Button({
    Name = "Reroll Trait Once",
    Callback = function()
        local RerollTraitRemote = Remotes and Remotes:FindFirstChild("RerollTrait")
        local pData = GetReplicaData()
        local targetUUID = State.TraitRerollTargetUnit
        local unitObj = FindUnitByUUID(pData and pData.Inventory, targetUUID)
        if not unitObj and pData and pData.EquippedSlots and pData.EquippedSlots[1] then
            targetUUID = pData.EquippedSlots[1]
            unitObj = FindUnitByUUID(pData.Inventory, targetUUID)
        end

        if unitObj and targetUUID then
            local tm, TraitsData = GetTraitsModules()
            local isMatch, primaryName, subName = CheckIfTraitMatches(unitObj.Trait, unitObj.SubTrait, tm, TraitsData)
            if isMatch then
                pcall(function()
                    MacLib:Notify({
                        Title = "Reroll Protected",
                        Description = "Unit already has target trait: " .. tostring(primaryName) .. (subName ~= "" and (" / " .. subName) or "") .. "!\nDeselect trait from Target Traits to reroll.",
                        Lifetime = 5
                    })
                end)
                return
            end
        end

        if RerollTraitRemote and targetUUID then
            pcall(function() RerollTraitRemote:InvokeServer(targetUUID) end)
        end
    end
})

-- ====================================================================
-- TAB: PARTY (Party System & Host Invite)
-- ====================================================================
local PartySections = {
    System = Tabs.Party:Section({ Side = "Left" }),
    HostInvite = Tabs.Party:Section({ Side = "Right" })
}

-- [Menu] Left Side: Party System
PartySections.System:Header({ Text = "Party System" })

PartySections.System:Toggle({
    Name = "Enable Party",
    Default = (State.PartyEnabled == true),
    Callback = function(val)
        State.PartyEnabled = val
        SaveConfigDebounced()
    end
}, "Toggle_PartyEnabled")

PartySections.System:Dropdown({
    Name = "Party Role",
    Multi = false,
    Required = true,
    Options = { "Host", "Alt" },
    Default = (State.PartyRole == "Alt") and "Alt" or "Host",
    Callback = function(val)
        State.PartyRole = val
        SaveConfigDebounced()
    end
}, "Dropdown_PartyRole")

PartySections.System:Input({
    Name = "Host Username",
    Placeholder = "Enter Host Username...",
    Default = State.PartyHost or "",
    Callback = function(val)
        State.PartyHost = val
        SaveConfigDebounced()
    end
}, "Input_PartyHost")

PartySections.System:Toggle({
    Name = "Auto join host room",
    Default = (State.PartyAutoJoin ~= false),
    Callback = function(val)
        State.PartyAutoJoin = val
        SaveConfigDebounced()
    end
}, "Toggle_PartyAutoJoin")

PartySections.System:Toggle({
    Name = "Auto Follow Host Server",
    Default = (State.PartyAutoFollow ~= false),
    Callback = function(val)
        State.PartyAutoFollow = val
        SaveConfigDebounced()
    end
}, "Toggle_PartyAutoFollow")

PartySections.System:Toggle({
    Name = "Auto Leave When Host Leaves",
    Default = (State.PartyAutoLeaveOnHostLeave ~= false),
    Callback = function(val)
        State.PartyAutoLeaveOnHostLeave = val
        SaveConfigDebounced()
        if val and isBattlePlace and CheckHostLeftAndAutoLeave then
            task.spawn(function()
                pcall(CheckHostLeftAndAutoLeave)
            end)
        end
    end
}, "Toggle_PartyAutoLeaveOnHostLeave")

-- [Menu] Right Side: Host Invite
PartySections.HostInvite:Header({ Text = "Host Invite" })

PartySections.HostInvite:Toggle({
    Name = "Auto Invite Alts",
    Default = (State.PartyAutoInvite ~= false),
    Callback = function(val)
        State.PartyAutoInvite = val
        SaveConfigDebounced()
    end
}, "Toggle_PartyAutoInvite")

local currentAltInputText = ""
local altsListParagraph
local removeAltDropdown
local selectedAltToRemove = ""

local function FormatAltsParagraphBody()
    local list = GetPartyAltsList()
    if #list == 0 then
        return "(No Alts in whitelist. Enter a username above to add)"
    end
    local inRoom = GetPlayersInRoom()
    local lines = {}
    for i, name in ipairs(list) do
        local inRoomStr = ""
        for _, rName in ipairs(inRoom) do
            if string.lower(rName) == string.lower(name) then
                inRoomStr = " [In Room]"
                break
            end
        end
        table.insert(lines, string.format("%d. %s%s", i, name, inRoomStr))
    end
    return table.concat(lines, "\n")
end

local function GetRemoveDropdownOptions()
    local list = GetPartyAltsList()
    if #list == 0 then
        return { "(None)" }
    end
    return list
end

local function UpdateAltsParagraph()
    local alts = GetPartyAltsList()
    if altsListParagraph and altsListParagraph.UpdateHeader and altsListParagraph.UpdateBody then
        pcall(function()
            altsListParagraph:UpdateHeader("Alts List (" .. #alts .. ")")
            altsListParagraph:UpdateBody(FormatAltsParagraphBody())
        end)
    end
end
UpdateAltsParagraphRef = UpdateAltsParagraph

local function RefreshAltsUI()
    UpdateAltsParagraph()
    if removeAltDropdown and removeAltDropdown.ClearOptions and removeAltDropdown.InsertOptions then
        local alts = GetPartyAltsList()
        pcall(function()
            removeAltDropdown:ClearOptions()
            local opts = GetRemoveDropdownOptions()
            removeAltDropdown:InsertOptions(opts)
            if #alts > 0 then
                selectedAltToRemove = alts[1]
                removeAltDropdown:UpdateSelection(alts[1])
            else
                selectedAltToRemove = ""
                removeAltDropdown:UpdateSelection("(None)")
            end
        end)
    end
end
RefreshAltsUIRef = RefreshAltsUI

local altInputObj = PartySections.HostInvite:Input({
    Name = "Alts Whitelist Username",
    Placeholder = "Enter Alt Username...",
    Default = "",
    Callback = function(val)
        currentAltInputText = val
    end
}, "Input_PartyAltUsername")

PartySections.HostInvite:Button({
    Name = "Add Alt to Whitelist",
    Callback = function()
        local nameToAdd = currentAltInputText
        if (not nameToAdd or nameToAdd == "") and altInputObj and altInputObj.GetInput then
            pcall(function() nameToAdd = altInputObj:GetInput() end)
        end
        nameToAdd = NormalizeUsername(nameToAdd or "")
        if nameToAdd == "" then
            pcall(function()
                MacLib:Notify({
                    Title = "Whitelist",
                    Description = "Please enter an Alt username first!",
                    Lifetime = 3
                })
            end)
            return
        end

        local lower = string.lower(nameToAdd)
        local exists = false
        for _, n in ipairs(State.PartyAlts or {}) do
            if string.lower(n) == lower then
                exists = true
                break
            end
        end

        if exists then
            pcall(function()
                MacLib:Notify({
                    Title = "Whitelist",
                    Description = nameToAdd .. " is already in the whitelist!",
                    Lifetime = 3
                })
            end)
            return
        end

        if type(State.PartyAlts) ~= "table" then
            State.PartyAlts = {}
        end
        table.insert(State.PartyAlts, nameToAdd)
        State.PartyAltsWhitelist = table.concat(State.PartyAlts, ", ")
        SaveConfigDebounced()

        currentAltInputText = ""
        if altInputObj and altInputObj.UpdateText then
            pcall(function() altInputObj:UpdateText("") end)
        end

        RefreshAltsUI()

        pcall(function()
            MacLib:Notify({
                Title = "Whitelist",
                Description = "Added " .. nameToAdd .. " to Whitelist!",
                Lifetime = 3
            })
        end)
    end
})

PartySections.HostInvite:Divider()

altsListParagraph = PartySections.HostInvite:Paragraph({
    Header = "Alts List (" .. #GetPartyAltsList() .. ")",
    Body = FormatAltsParagraphBody()
}, "Paragraph_AltsList")

removeAltDropdown = PartySections.HostInvite:Dropdown({
    Name = "Select Alt to Remove",
    Multi = false,
    Required = false,
    Options = GetRemoveDropdownOptions(),
    Default = (function()
        local l = GetPartyAltsList()
        return (#l > 0) and l[1] or "(None)"
    end)(),
    Callback = function(val)
        selectedAltToRemove = val
    end
}, "Dropdown_RemoveAlt")

PartySections.HostInvite:Button({
    Name = "Remove Selected Alt",
    Callback = function()
        local target = selectedAltToRemove
        if not target or target == "" or target == "(None)" then
            pcall(function()
                MacLib:Notify({
                    Title = "Whitelist",
                    Description = "No Alt selected to remove!",
                    Lifetime = 3
                })
            end)
            return
        end

        local lowerTarget = string.lower(target)
        local newList = {}
        local removed = false
        for _, n in ipairs(State.PartyAlts or {}) do
            if string.lower(n) == lowerTarget then
                removed = true
            else
                table.insert(newList, n)
            end
        end

        if removed then
            State.PartyAlts = newList
            State.PartyAltsWhitelist = table.concat(newList, ", ")
            SaveConfigDebounced()
            RefreshAltsUI()
            pcall(function()
                MacLib:Notify({
                    Title = "Whitelist",
                    Description = "Removed " .. target .. " from Whitelist!",
                    Lifetime = 3
                })
            end)
        end
    end
})

PartySections.HostInvite:Button({
    Name = "Clear All Alts",
    Callback = function()
        if not State.PartyAlts or #State.PartyAlts == 0 then return end
        State.PartyAlts = {}
        State.PartyAltsWhitelist = ""
        SaveConfigDebounced()
        RefreshAltsUI()
        pcall(function()
            MacLib:Notify({
                Title = "Whitelist",
                Description = "Cleared all Alts from Whitelist!",
                Lifetime = 3
            })
        end)
    end
})

-- ====================================================================
-- TAB 4: GAMEPLAY
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
            lastUserGameSettingChangeTime = os.clock()
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
-- TAB: WEBHOOK (Discord Victory / Defeat Match Reporter)
-- ====================================================================
local WebhookSections = {
    Setup = Tabs.Webhook:Section({ Side = "Left" }),
    Outcomes = Tabs.Webhook:Section({ Side = "Right" })
}

WebhookSections.Setup:Header({ Text = "Discord Webhook Setup" })

WebhookSections.Setup:Toggle({
    Name = "Enable Webhook",
    Default = (State.WebhookEnabled == true),
    Callback = function(val)
        State.WebhookEnabled = val
        SaveConfigDebounced()
    end
}, "Toggle_WebhookEnabled")

WebhookSections.Setup:Input({
    Name = "Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Default = State.WebhookUrl or "",
    Callback = function(val)
        State.WebhookUrl = val
        SaveConfigDebounced()
    end
}, "Input_WebhookUrl")

WebhookSections.Setup:Input({
    Name = "Discord User ID (Optional Ping)",
    Placeholder = "e.g. 123456789012345678",
    Default = State.WebhookUserId or "",
    Callback = function(val)
        State.WebhookUserId = val
        SaveConfigDebounced()
    end
}, "Input_WebhookUserId")

WebhookSections.Setup:Button({
    Name = "Send Test Webhook",
    Callback = function()
        SendDiscordWebhook({
            title = "🧪 Webhook Test - STRIX HUB",
            description = "Discord Webhook connection verified successfully!",
            color = 3066993,
            fields = {
                { name = "🗺️ Map", value = "Namek World (Stage 1)", inline = true },
                { name = "⏱️ Time", value = "03:45", inline = true },
                { name = "⚔️ Damage", value = "1,250,000", inline = true },
                { name = "👾 Mobs Killed", value = "95", inline = true },
                { name = "✨ EXP", value = "+2,400 EXP", inline = true },
                { name = "🎁 Rewards", value = "💎 500 Gems\n🪙 2,000 Coins", inline = false }
            },
            footer = { text = "STRIX HUB • Anime Mysterious | Account: " .. LocalPlayer.Name },
            timestamp = DateTime.now():ToIsoDate()
        })
        Window:Notify({
            Title = "Discord Webhook",
            Description = "Test webhook request dispatched!",
            Lifetime = 3
        })
    end
})

WebhookSections.Outcomes:Header({ Text = "Match Outcome Triggers" })

WebhookSections.Outcomes:Toggle({
    Name = "Send on Victory",
    Default = (State.WebhookOnVictory ~= false),
    Callback = function(val)
        State.WebhookOnVictory = val
        SaveConfigDebounced()
    end
}, "Toggle_WebhookOnVictory")

WebhookSections.Outcomes:Toggle({
    Name = "Send on Defeat",
    Default = (State.WebhookOnDefeat ~= false),
    Callback = function(val)
        State.WebhookOnDefeat = val
        SaveConfigDebounced()
    end
}, "Toggle_WebhookOnDefeat")

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
    -- Auto-Buy is strictly a Lobby action (Shop modules do not exist in Battle Place)
    if not isLobby or not BuyItem then return false end
    local didBuy = false
    
    -- Dynamically resolve Shop modules if not yet loaded
    if not GemsShopModule and Modules then
        local gsm = Modules:FindFirstChild("GemsShopModule")
        if gsm then
            local ok, m = pcall(require, gsm)
            if ok and type(m) == "table" then GemsShopModule = m end
        end
    end
    if not ShopModule and Modules then
        local sm = Modules:FindFirstChild("ShopModule")
        if sm then
            local ok, m = pcall(require, sm)
            if ok and type(m) == "table" then ShopModule = m end
        end
    end
    
    -- Gems Shop
    if State.AutoBuyGems and #State.SelectedGemsItems > 0 and GemsShopModule and type(GemsShopModule.GetStockLeft) == "function" then
        local currentGems = LocalPlayer:GetAttribute("Gems") or 0
        for _, itemId in ipairs(State.SelectedGemsItems) do
            for _, itemConfig in pairs(GameData.GemsItemMap) do
                if itemConfig.ID == itemId and currentGems >= itemConfig.Price then
                    local okStock, stock = pcall(function()
                        return GemsShopModule:GetStockLeft(itemId, itemConfig.MaxStock)
                    end)
                    stock = (okStock and tonumber(stock)) or 0
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
    if State.AutoBuyGold and #State.SelectedGoldItems > 0 and ShopModule and type(ShopModule.GetStockLeft) == "function" then
        local currentCoins = LocalPlayer:GetAttribute("Coins") or 0
        for _, itemId in ipairs(State.SelectedGoldItems) do
            for _, itemConfig in pairs(GameData.GoldItemMap) do
                if itemConfig.ID == itemId and currentCoins >= itemConfig.Price then
                    local okStock, stock = pcall(function()
                        return ShopModule:GetStockLeft(itemId, itemConfig.MaxStock)
                    end)
                    stock = (okStock and tonumber(stock)) or 0
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
    if not (ok and type(challengeData) == "table") then return false end
    
    local repData = GetReplicaData()
    local cleared = (type(repData) == "table" and repData.ClearedChallenges) or {}
    
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
                    TeleportRequest:FireServer(97246719761307, modeTitle, cInfo.MapToCreate, stageName, "Nightmare")
                end)
            end
        end)
        
        task.wait(2.5)
        challengeDebounce = false
    end)
    
    return true
end

local lastAutoCreateAttempt = 0
local lastSuccessfulRoomCreation = 0
local function ProcessAutoCreate()
    if os.clock() - lastAutoCreateAttempt < 4.0 then
        return
    end
    
    local mode, mapName, stage, diff
    if State.ActiveAutoCreate == "Story" then
        mode, mapName, stage, diff = "Story", State.StoryMap, State.StoryStage, State.StoryDiff
    elseif State.ActiveAutoCreate == "Mysterious" then
        mode, mapName, stage, diff = "Mysterios", State.MysteriousMap, State.MysteriousStage, State.MysteriousDiff
    elseif State.ActiveAutoCreate == "Raids" then
        mode, mapName, stage, diff = "Raids", State.RaidsMap, State.RaidsStage, State.RaidsDiff
    elseif State.ActiveAutoCreate == "Boss" then
        mode, mapName, stage, diff = "Event", State.BossMap, State.BossStage, State.BossDiff
    else
        return
    end
    
    if not mapName or mapName == "" then return end
    
    -- If room already created and matches target configuration, no need to recreate
    if DoesRoomMatch(mode, mapName, stage, diff) then
        return
    end
    
    -- Cooldown: if a room was created within the last 6 seconds and is active, do not recreate
    if os.clock() - lastSuccessfulRoomCreation < 6.0 and IsRoomCreated() then
        return
    end
    
    lastAutoCreateAttempt = os.clock()
    
    -- Call CreateRoom without forcing blind recreation (CreateRoom checks DoesRoomMatch)
    local ok = CreateRoom(mode, mapName, stage, diff, false)
    if ok then
        lastSuccessfulRoomCreation = os.clock()
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
    local repData = GetReplicaData()
    if type(repData) == "table" and repData.Config then
        local config = repData.Config
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
        if isLobby then
            -- Party System
            if State.PartyEnabled then
                pcall(ProcessPartySystem)
            end

            -- Auto Open Capsules (Storage Safe)
            if State.AutoOpenCapsules then
                pcall(ProcessAutoOpenCapsules)
            end

            -- Auto Feed
            if State.AutoFeed then
                pcall(ProcessAutoFeed)
            end

            -- Auto Trait Reroll (Ensures fast worker stays active)
            if State.AutoTraitReroll and not isAutoRollingTraits then
                pcall(ProcessAutoTraitReroll)
            end

            -- Priority 1: Auto Buy
            local didBuy = false
            if State.AutoBuyGems or State.AutoBuyGold then
                didBuy = ProcessAutoBuy()
            end
            
            if not didBuy then
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
                TriggerMatchStart()
            end
            
            -- Auto Summon
            if State.AutoSummon then
                ProcessAutoSummon()
            end
        else
            -- Battle-only operations (In Gameplay)
            if State.WebhookEnabled and CheckAndSendMatchWebhook then
                pcall(CheckAndSendMatchWebhook)
            end

            -- Match State Auto-Reset for repetitive rounds (Auto Retry / Next Stage / Next Match)
            if (hasSentMatchWebhook or isMatchFinished) and (os.clock() - lastWebhookDispatchTime > 12) then
                local eg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EndGame")
                local frame = eg and eg:FindFirstChild("EndGameFrame")
                if not (frame and frame.Visible) then
                    if ResetMatchState then
                        ResetMatchState("Round Transition Active")
                    end
                end
            end

            if State.AutoSolveFateSword and workspace:GetAttribute("SwordEventActive") == true then
                SolveFateSwordEvent()
            end

            if State.AutoDefendMoneyUnits then
                HandleAutoDefendMoneyUnits()
            end

            if State.AutoLeaveChallenge then
                CheckAndExecuteAutoLeave()
            end
            if State.AutoLeaveOnChallengeReset then
                CheckChallengeResetLeave()
            end

            if State.PartyAutoLeaveOnHostLeave and CheckHostLeftAndAutoLeave then
                pcall(CheckHostLeftAndAutoLeave)
            end
        end
    end
end)

-- ====================================================================
-- AUTO RUN: LOAD CONFIG ON START
-- ====================================================================
LoadConfig = function()
    isLoadingConfig = true
    local okMain, mainErr = pcall(function()
        EnsureFolders()
        local targetFile = ConfigFile
        if not isfile(targetFile) then
            local oldFile = ConfigFolder .. "/" .. tostring(LocalPlayer.UserId) .. ".json"
            if isfile(oldFile) then
                targetFile = oldFile
            end
        end
        if not isfile(targetFile) then return end

        local content = readfile(targetFile)
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not (ok and type(data) == "table") then return end

        if data.ActiveAutoCreate then
            pcall(function() SetAutoCreateMode(data.ActiveAutoCreate) end)
        end
        local function CleanMapName(name)
            if not name then return nil end
            return string.gsub(name, "%s*%[.-%]", "")
        end

        if data.StoryMap then
            local sm = CleanMapName(data.StoryMap)
            State.StoryMap = sm
            if MacLib.Options["Dropdown_StoryMap"] then
                pcall(function() MacLib.Options["Dropdown_StoryMap"]:UpdateSelection(sm) end)
            end
        end
        if data.StoryStage then
            State.StoryStage = tostring(data.StoryStage)
            if MacLib.Options["Dropdown_StoryStage"] then
                pcall(function() MacLib.Options["Dropdown_StoryStage"]:UpdateSelection(tostring(data.StoryStage)) end)
            end
        end
        if data.StoryDiff then
            State.StoryDiff = data.StoryDiff
            if MacLib.Options["Dropdown_StoryDiff"] then
                pcall(function() MacLib.Options["Dropdown_StoryDiff"]:UpdateSelection(data.StoryDiff) end)
            end
        end
        if data.MysteriousMap then
            local mm = CleanMapName(data.MysteriousMap)
            State.MysteriousMap = mm
            if MacLib.Options["Dropdown_MysteriousMap"] then
                pcall(function() MacLib.Options["Dropdown_MysteriousMap"]:UpdateSelection(mm) end)
            end
        end
        if data.MysteriousStage then
            State.MysteriousStage = tostring(data.MysteriousStage)
            if MacLib.Options["Dropdown_MysteriousStage"] then
                pcall(function() MacLib.Options["Dropdown_MysteriousStage"]:UpdateSelection(tostring(data.MysteriousStage)) end)
            end
        end
        if data.MysteriousDiff then
            State.MysteriousDiff = data.MysteriousDiff
            if MacLib.Options["Dropdown_MysteriousDiff"] then
                pcall(function() MacLib.Options["Dropdown_MysteriousDiff"]:UpdateSelection(data.MysteriousDiff) end)
            end
        end
        if data.RaidsMap then
            local rm = CleanMapName(data.RaidsMap)
            State.RaidsMap = rm
            if MacLib.Options["Dropdown_RaidsMap"] then
                pcall(function() MacLib.Options["Dropdown_RaidsMap"]:UpdateSelection(rm) end)
            end
        end
        if data.RaidsStage then
            State.RaidsStage = tostring(data.RaidsStage)
            if MacLib.Options["Dropdown_RaidsStage"] then
                pcall(function() MacLib.Options["Dropdown_RaidsStage"]:UpdateSelection(tostring(data.RaidsStage)) end)
            end
        end
        if data.RaidsDiff then
            State.RaidsDiff = data.RaidsDiff
            if MacLib.Options["Dropdown_RaidsDiff"] then
                pcall(function() MacLib.Options["Dropdown_RaidsDiff"]:UpdateSelection(data.RaidsDiff) end)
            end
        end
        if data.BossMap then
            local bm = CleanMapName(data.BossMap)
            State.BossMap = bm
            if MacLib.Options["Dropdown_BossMap"] then
                pcall(function() MacLib.Options["Dropdown_BossMap"]:UpdateSelection(bm) end)
            end
        end
        if data.BossStage then
            State.BossStage = tostring(data.BossStage)
            if MacLib.Options["Dropdown_BossStage"] then
                pcall(function() MacLib.Options["Dropdown_BossStage"]:UpdateSelection(tostring(data.BossStage)) end)
            end
        end
        if data.BossDiff then
            State.BossDiff = data.BossDiff
            if MacLib.Options["Dropdown_BossDiff"] then
                pcall(function() MacLib.Options["Dropdown_BossDiff"]:UpdateSelection(data.BossDiff) end)
            end
        end
        if data.AutoStart ~= nil and MacLib.Options["Toggle_AutoStart"] then
            pcall(function() MacLib.Options["Toggle_AutoStart"]:UpdateState(data.AutoStart) end)
        end
        if data.AutoChallenges ~= nil and MacLib.Options["Toggle_AutoChallenges"] then
            pcall(function() MacLib.Options["Toggle_AutoChallenges"]:UpdateState(data.AutoChallenges) end)
        end
        if data.AutoLeaveChallenge ~= nil and MacLib.Options["Toggle_AutoLeaveChallenge"] then
            pcall(function() MacLib.Options["Toggle_AutoLeaveChallenge"]:UpdateState(data.AutoLeaveChallenge) end)
        end
        if data.AutoLeaveOnChallengeReset ~= nil and MacLib.Options["Toggle_AutoLeaveOnChallengeReset"] then
            pcall(function() MacLib.Options["Toggle_AutoLeaveOnChallengeReset"]:UpdateState(data.AutoLeaveOnChallengeReset) end)
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
            pcall(function() MacLib.Options["Dropdown_TargetChallenges"]:UpdateSelection(selected) end)
        end
        local function MatchDropdownLabel(idOrLabel, idToLabelMap, itemMap)
            if not idOrLabel then return nil end
            if idToLabelMap[idOrLabel] then return idToLabelMap[idOrLabel] end
            if itemMap[idOrLabel] then return idOrLabel end
            local baseName = string.match(tostring(idOrLabel), "^(.-)%s*%(") or tostring(idOrLabel)
            baseName = string.gsub(baseName, "^%s*(.-)%s*$", "%1")
            for label, itemData in pairs(itemMap) do
                if itemData.ID == idOrLabel or itemData.Name == baseName or itemData.ID == baseName then
                    return label
                end
            end
            return nil
        end

        if data.AutoBuyGems ~= nil and MacLib.Options["Toggle_AutoBuyGems"] then
            pcall(function() MacLib.Options["Toggle_AutoBuyGems"]:UpdateState(data.AutoBuyGems) end)
        end
        if data.SelectedGemsItems and MacLib.Options["Dropdown_GemsItems"] then
            local labelsToSelect = {}
            State.SelectedGemsItems = {}
            if type(data.SelectedGemsItems) == "table" then
                for _, idOrLabel in ipairs(data.SelectedGemsItems) do
                    local lbl = MatchDropdownLabel(idOrLabel, GameData.GemsIdToLabel, GameData.GemsItemMap)
                    if lbl then
                        local itemData = GameData.GemsItemMap[lbl]
                        local id = itemData and itemData.ID or idOrLabel
                        if not table.find(State.SelectedGemsItems, id) then
                            table.insert(State.SelectedGemsItems, id)
                        end
                        if not table.find(labelsToSelect, lbl) then
                            table.insert(labelsToSelect, lbl)
                        end
                    end
                end
            end
            pcall(function() MacLib.Options["Dropdown_GemsItems"]:UpdateSelection(labelsToSelect) end)
        end
        if data.AutoBuyGold ~= nil and MacLib.Options["Toggle_AutoBuyGold"] then
            pcall(function() MacLib.Options["Toggle_AutoBuyGold"]:UpdateState(data.AutoBuyGold) end)
        end
        if data.SelectedGoldItems and MacLib.Options["Dropdown_GoldItems"] then
            local labelsToSelect = {}
            State.SelectedGoldItems = {}
            if type(data.SelectedGoldItems) == "table" then
                for _, idOrLabel in ipairs(data.SelectedGoldItems) do
                    local lbl = MatchDropdownLabel(idOrLabel, GameData.GoldIdToLabel, GameData.GoldItemMap)
                    if lbl then
                        local itemData = GameData.GoldItemMap[lbl]
                        local id = itemData and itemData.ID or idOrLabel
                        if not table.find(State.SelectedGoldItems, id) then
                            table.insert(State.SelectedGoldItems, id)
                        end
                        if not table.find(labelsToSelect, lbl) then
                            table.insert(labelsToSelect, lbl)
                        end
                    end
                end
            end
            pcall(function() MacLib.Options["Dropdown_GoldItems"]:UpdateSelection(labelsToSelect) end)
        end
        if data.AutoSummon ~= nil and MacLib.Options["Toggle_AutoSummon"] then
            pcall(function() MacLib.Options["Toggle_AutoSummon"]:UpdateState(data.AutoSummon) end)
        end
        if data.SummonBanner and MacLib.Options["Dropdown_SummonBanner"] then
            pcall(function() MacLib.Options["Dropdown_SummonBanner"]:UpdateSelection(data.SummonBanner) end)
        end
        if data.SummonAmount and MacLib.Options["Dropdown_SummonAmount"] then
            pcall(function() MacLib.Options["Dropdown_SummonAmount"]:UpdateSelection(data.SummonAmount) end)
        end
        if data.Keybind then
            local k = ResolveBind(data.Keybind)
            if k and k ~= Enum.KeyCode.Unknown then
                State.Keybind = k
                if Window and Window.SetKeybind then
                    pcall(function() Window:SetKeybind(k) end)
                end
                if MacLib.Options["Keybind_ToggleUI"] then
                    pcall(function() MacLib.Options["Keybind_ToggleUI"]:Bind(k) end)
                end
            end
        end
        if data.UISize and data.UISize.Width and data.UISize.Height then
            State.UISize = data.UISize
            pcall(function()
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
            end)
        end
        if UpdateResponsiveScaleRef then
            pcall(function() UpdateResponsiveScaleRef(false) end)
        end
        if data.AcrylicBlur ~= nil and MacLib.Options["Toggle_AcrylicBlur"] then
            pcall(function()
                MacLib.Options["Toggle_AcrylicBlur"]:UpdateState(data.AcrylicBlur)
                if Window and Window.SetAcrylicBlurState then
                    Window:SetAcrylicBlurState(data.AcrylicBlur)
                end
            end)
        end
        if data.ShowUserInfo ~= nil and MacLib.Options["Toggle_ShowUserInfo"] then
            pcall(function()
                MacLib.Options["Toggle_ShowUserInfo"]:UpdateState(data.ShowUserInfo)
                if Window and Window.SetUserInfoState then
                    Window:SetUserInfoState(data.ShowUserInfo)
                end
            end)
        end
        if data.MobileToggle ~= nil and MacLib.Options["Toggle_MobileToggle"] then
            pcall(function()
                MacLib.Options["Toggle_MobileToggle"]:UpdateState(data.MobileToggle)
                if getgenv().STRIX_MOBILE_GUI then
                    getgenv().STRIX_MOBILE_GUI.Enabled = data.MobileToggle
                end
            end)
        end
        for _, sInfo in ipairs(GameSettingsMap) do
            if data[sInfo.StateKey] ~= nil and MacLib.Options[sInfo.OptFlag] then
                pcall(function()
                    MacLib.Options[sInfo.OptFlag]:UpdateState(data[sInfo.StateKey])
                    if not isSyncingFromGame then
                        SetGameSetting(sInfo.GuiName, data[sInfo.StateKey], sInfo.SettingKey)
                    end
                end)
            end
        end
        if data.AutoSolveFateSword ~= nil then
            State.AutoSolveFateSword = (data.AutoSolveFateSword ~= false)
            if MacLib.Options["Toggle_AutoSolveFateSword"] then
                pcall(function() MacLib.Options["Toggle_AutoSolveFateSword"]:UpdateState(State.AutoSolveFateSword) end)
            end
        end
        if data.AutoDefendMoneyUnits ~= nil then
            State.AutoDefendMoneyUnits = (data.AutoDefendMoneyUnits ~= false)
            if MacLib.Options["Toggle_AutoDefendMoneyUnits"] then
                pcall(function() MacLib.Options["Toggle_AutoDefendMoneyUnits"]:UpdateState(State.AutoDefendMoneyUnits) end)
            end
        end

        -- Webhook
        if data.WebhookEnabled ~= nil and MacLib.Options["Toggle_WebhookEnabled"] then
            pcall(function() MacLib.Options["Toggle_WebhookEnabled"]:UpdateState(data.WebhookEnabled) end)
        end
        if data.WebhookUrl and MacLib.Options["Input_WebhookUrl"] then
            pcall(function() MacLib.Options["Input_WebhookUrl"]:UpdateText(data.WebhookUrl) end)
        end
        if data.WebhookUserId and MacLib.Options["Input_WebhookUserId"] then
            pcall(function() MacLib.Options["Input_WebhookUserId"]:UpdateText(data.WebhookUserId) end)
        end
        if data.WebhookOnVictory ~= nil and MacLib.Options["Toggle_WebhookOnVictory"] then
            pcall(function() MacLib.Options["Toggle_WebhookOnVictory"]:UpdateState(data.WebhookOnVictory) end)
        end
        if data.WebhookOnDefeat ~= nil and MacLib.Options["Toggle_WebhookOnDefeat"] then
            pcall(function() MacLib.Options["Toggle_WebhookOnDefeat"]:UpdateState(data.WebhookOnDefeat) end)
        end

        -- Auto Open Capsules
        if data.AutoOpenCapsules ~= nil and MacLib.Options["Toggle_AutoOpenCapsules"] then
            pcall(function() MacLib.Options["Toggle_AutoOpenCapsules"]:UpdateState(data.AutoOpenCapsules) end)
        end
        if data.CapsuleMinFreeSlots and MacLib.Options["Slider_CapsuleMinFreeSlots"] then
            pcall(function() MacLib.Options["Slider_CapsuleMinFreeSlots"]:UpdateValue(data.CapsuleMinFreeSlots) end)
        end

        -- Auto Feed & Evolve
        if data.AutoFeed ~= nil and MacLib.Options["Toggle_AutoFeed"] then
            pcall(function() MacLib.Options["Toggle_AutoFeed"]:UpdateState(data.AutoFeed) end)
        end
        if data.AutoFeedTarget and MacLib.Options["Dropdown_AutoFeedTarget"] then
            pcall(function() MacLib.Options["Dropdown_AutoFeedTarget"]:UpdateSelection(data.AutoFeedTarget == "All" and "All Units" or "Equipped Units") end)
        end
        if data.AutoEvolve ~= nil and MacLib.Options["Toggle_AutoEvolve"] then
            pcall(function() MacLib.Options["Toggle_AutoEvolve"]:UpdateState(data.AutoEvolve) end)
        end

        -- Auto Trait Reroll
        if data.AutoTraitReroll ~= nil and MacLib.Options["Toggle_AutoTraitReroll"] then
            pcall(function() MacLib.Options["Toggle_AutoTraitReroll"]:UpdateState(data.AutoTraitReroll) end)
        end
        if data.TargetTraits and MacLib.Options["Dropdown_TargetTraits"] then
            pcall(function() MacLib.Options["Dropdown_TargetTraits"]:UpdateSelection(data.TargetTraits) end)
        end
        if data.RespectInGameStopList ~= nil and MacLib.Options["Toggle_RespectInGameStopList"] then
            pcall(function() MacLib.Options["Toggle_RespectInGameStopList"]:UpdateState(data.RespectInGameStopList) end)
        end
        if data.TraitRerollDelay ~= nil and MacLib.Options["Slider_TraitRerollDelay"] then
            pcall(function() MacLib.Options["Slider_TraitRerollDelay"]:UpdateValue(data.TraitRerollDelay) end)
        end

        -- Party System
        if data.PartyEnabled ~= nil and MacLib.Options["Toggle_PartyEnabled"] then
            pcall(function() MacLib.Options["Toggle_PartyEnabled"]:UpdateState(data.PartyEnabled) end)
        elseif data.PartyRole == "Disabled" and MacLib.Options["Toggle_PartyEnabled"] then
            pcall(function() MacLib.Options["Toggle_PartyEnabled"]:UpdateState(false) end)
        end
        local roleVal = (data.PartyRole == "Alt") and "Alt" or "Host"
        if MacLib.Options["Dropdown_PartyRole"] then
            pcall(function() MacLib.Options["Dropdown_PartyRole"]:UpdateSelection(roleVal) end)
        end
        if data.PartyHost and MacLib.Options["Input_PartyHost"] then
            pcall(function() MacLib.Options["Input_PartyHost"]:UpdateText(data.PartyHost) end)
        end
        if type(data.PartyAlts) == "table" then
            State.PartyAlts = data.PartyAlts
            State.PartyAltsWhitelist = table.concat(data.PartyAlts, ", ")
        elseif data.PartyAltsWhitelist and type(data.PartyAltsWhitelist) == "string" then
            State.PartyAltsWhitelist = data.PartyAltsWhitelist
            State.PartyAlts = {}
            for name in string.gmatch(data.PartyAltsWhitelist, "[^,;%s]+") do
                table.insert(State.PartyAlts, name)
            end
        end
        if RefreshAltsUIRef then
            pcall(RefreshAltsUIRef)
        end
        if data.PartyAutoInvite ~= nil and MacLib.Options["Toggle_PartyAutoInvite"] then
            pcall(function() MacLib.Options["Toggle_PartyAutoInvite"]:UpdateState(data.PartyAutoInvite) end)
        end
        if data.PartyAutoFollow ~= nil and MacLib.Options["Toggle_PartyAutoFollow"] then
            pcall(function() MacLib.Options["Toggle_PartyAutoFollow"]:UpdateState(data.PartyAutoFollow) end)
        end
        if data.PartyAutoJoin ~= nil and MacLib.Options["Toggle_PartyAutoJoin"] then
            pcall(function() MacLib.Options["Toggle_PartyAutoJoin"]:UpdateState(data.PartyAutoJoin) end)
        end
        if data.PartyAutoLeaveOnHostLeave ~= nil and MacLib.Options["Toggle_PartyAutoLeaveOnHostLeave"] then
            pcall(function() MacLib.Options["Toggle_PartyAutoLeaveOnHostLeave"]:UpdateState(data.PartyAutoLeaveOnHostLeave) end)
        end
    end)
    if not okMain then
        warn("[STRIX HUB] LoadConfig error: " .. tostring(mainErr))
    end
    isLoadingConfig = false
end

-- Auto Run on script execution
LoadConfig()
pcall(function()
    if isBattlePlace and Tabs.Gameplay then
        Tabs.Gameplay:Select()
    elseif Tabs.AutoCreate then
        Tabs.AutoCreate:Select()
    end
end)
if isLobby then
    pcall(UpdateChallengeInfoDisplay)
end

getgenv().STRIX_HUB = {
    Window = Window,
    Tabs = Tabs,
    State = State,
    GameData = GameData,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig
}
getgenv().STRIX_HUB_JOB_ID = game.JobId