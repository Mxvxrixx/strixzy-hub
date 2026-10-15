-- ==============================================================================
-- 0. GAME & CLIENT LOAD VERIFICATION (Safety Gate)
-- ==============================================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

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

-- Viewport Stabilization (Prevents DirectX / Canvas Crash)
pcall(function()
    local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 10)
    if camera then
        local t0 = os.clock()
        while (camera.ViewportSize.X < 200 or camera.ViewportSize.Y < 200) and (os.clock() - t0 < 5) do
            task.wait(0.2)
        end
    end
end)

-- Storage Folders
local function EnsureFolders()
    if isfolder and not isfolder("STRIX HUB") then pcall(makefolder, "STRIX HUB") end
    if isfolder and not isfolder("STRIX HUB/Anime Dice") then pcall(makefolder, "STRIX HUB/Anime Dice") end
end
EnsureFolders()

-- Safe Instance Cleanup (Prevents duplicates and memory leaks)
if getgenv().STRIX_HUB_CLEANUP then
    pcall(getgenv().STRIX_HUB_CLEANUP)
    task.wait(0.2)
end

pcall(function()
    local searchLocations = {
        (gethui and gethui()) or game:GetService("CoreGui"),
        game:GetService("CoreGui"):FindFirstChild("RobloxGui"),
        LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
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
local runningThreads = {}

local function SpawnTracked(fn)
    local thread = task.spawn(function()
        local ok, err = pcall(fn)
        if not ok and err then
            warn("[STRIX HUB - Anime Dice] Thread error: " .. tostring(err))
        end
    end)
    table.insert(runningThreads, thread)
    return thread
end

getgenv().STRIX_HUB_CLEANUP = function()
    isScriptRunning = false
    for _, th in ipairs(runningThreads) do
        pcall(task.cancel, th)
    end
    table.clear(runningThreads)

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

-- ==============================================================================
-- 1. SERVICES & NETWORK INITIALIZATION
-- ==============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- Framework Modules (Safe Resolution)
local DataController = nil
local BuffController = nil
local NumberFormatter = nil

pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)
pcall(function()
    BuffController = require(ReplicatedStorage.Framework.Features.Buffs.BuffController)
end)
pcall(function()
    NumberFormatter = require(ReplicatedStorage.Packages.NumberFormatter)
end)
local Dice = nil
pcall(function()
    Dice = require(ReplicatedStorage.Framework.Features.Rolling.Dice)
end)
local EntryRegistry = nil
pcall(function()
    EntryRegistry = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
end)
local BuffBarController = nil
pcall(function()
    BuffBarController = require(ReplicatedStorage.Framework.Features.Buffs.BuffBarController)
end)
local UIReferences = nil
pcall(function()
    UIReferences = require(ReplicatedStorage.Framework.Features.UI.UIReferences)
end)
local UnitUtil = nil
pcall(function()
    UnitUtil = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitUtil)
end)
local Rebirths = nil
pcall(function()
    Rebirths = require(ReplicatedStorage.Framework.Features.Rebirth.Rebirths)
end)
local UpgradesConfig = nil
pcall(function()
    UpgradesConfig = require(ReplicatedStorage.Framework.Features.Upgrades.Upgrades)
end)
local TreeStructure = nil
pcall(function()
    TreeStructure = require(ReplicatedStorage.Framework.Features.Upgrades.TreeStructure)
end)
local DailyRewardConfig = nil
pcall(function()
    DailyRewardConfig = require(ReplicatedStorage.Framework.Features.Rewards.DailyRewardConfig)
end)
local QuestConfig = nil
pcall(function()
    QuestConfig = require(ReplicatedStorage.Framework.Features.Quests.QuestConfig)
end)
local QuirkUtil = nil
pcall(function()
    QuirkUtil = require(ReplicatedStorage.Framework.Features.Quirks.QuirkUtil)
end)

-- Network Remotes (Defensive Fallback)
local Network = ReplicatedStorage:WaitForChild("Network", 15)

local function GetRemote(serviceName, remoteType, remoteName)
    local s = Network and Network:FindFirstChild(serviceName)
    if not s then return nil end
    local folder = s:FindFirstChild(remoteType)
    if not folder then return nil end
    return folder:FindFirstChild(remoteName)
end

local RollDiceRF      = GetRemote("RollService", "RF", "RollDice")
local BuyDiceRE       = GetRemote("DiceShopService", "RE", "BuyDice")
local EquipDiceRE     = GetRemote("DiceShopService", "RE", "EquipDice")
local UpdateAutoSellRE = GetRemote("SellService", "RE", "UpdateAutoSell")
local EquipBestRE     = GetRemote("PlotService", "RE", "EquipBest")
local InteractSlotRE  = GetRemote("PlotService", "RE", "InteractSlot")
local UnequipRF       = GetRemote("UnitService", "RF", "Unequip")
local LevelUpSlotRE   = GetRemote("PlotService", "RE", "LevelUpSlot")
local CollectBalanceRE = GetRemote("PlotService", "RE", "CollectBalance")
local RedeemCodeRE    = GetRemote("CodesService", "RE", "RedeemCode")
local UseBoostRE      = GetRemote("BoostService", "RE", "Use")
local RebirthRE       = GetRemote("RebirthService", "RE", "Rebirth")
local BuyUpgradeRE    = Network and Network:FindFirstChild("RE") and Network.RE:FindFirstChild("BuyUpgrade")
local ClaimDailyRewardRE = GetRemote("DailyRewardService", "RE", "Claim")
local ClaimQuestRE    = GetRemote("QuestService", "RE", "Claim")
local RollQuirkRE     = GetRemote("QuirkService", "RE", "Roll")
local RollGradeRE     = GetRemote("GradeService", "RE", "Roll")
local RollTraitRE     = GetRemote("TraitService", "RE", "Roll")

-- ==============================================================================
-- 2. STATE & CONFIGURATION MANAGEMENT
-- ==============================================================================
local ConfigFolder = "STRIX HUB/Anime Dice"
local ConfigFile = ConfigFolder .. "/" .. tostring(LocalPlayer.Name) .. ".json"

local State = {
    -- Auto Roll
    AutoRoll = false,

    -- Progression
    AutoBuyDice = false,
    AutoEquipBestDice = false,
    AutoRebirth = false,
    AutoUpgrades = false,
    AutoClaimQuests = false,
    AutoClaimDailyReward = false,

    -- Hub & Quirks
    AutoQuirks = false,
    SelectedQuirkUnits = {},
    SelectedQuirks = { "Fortune's Favor", "Midas Touch", "Prodigy", "Tycoon", "Fortune III" },

    -- Hub & Grades
    AutoGrades = false,
    SelectedGradeUnits = {},
    SelectedGrades = { "Ω", "∞", "神", "Z+", "Z" },

    -- Hub & Traits
    AutoTraits = false,
    SelectedTraitUnits = {},
    SelectedTraits = { "Genesis", "Paradox", "Eternal", "Transcendent", "Monarch" },

    -- Potions & Boosts Automation
    AutoUsePotions = false,
    AutoUsePotionTypes = { "Luck", "Damage", "Income", "Speed" },
    AutoUsePotionMode = "Keep Active",

    -- Auto Sell
    AutoSellEnabled = false,
    AutoSellNumber = "10",
    AutoSellUnit = "k",
    AutoSellValue = 0,

    -- Plot & Units
    AutoCollectPlot = false,
    CollectInterval = 5,
    AutoEquipBest = false,
    EquipBestInterval = 15,
    AutoUpgradePlot = false,
    PlotTargetLevel = 100,

    -- Interface Settings
    AcrylicBlur = false,
    ShowUserInfo = true,
    MobileToggle = true,
    Keybind = Enum.KeyCode.RightControl,
    UISize = { Width = 868, Height = 650 }
}

local isLoadingConfig = false
local LoadConfig = nil

local function ResolveBind(bindName)
    if not bindName or bindName == "Unknown" or bindName == "None" then return nil end
    local okKey, k = pcall(function() return Enum.KeyCode[bindName] end)
    if okKey and k and k ~= Enum.KeyCode.Unknown then return k end
    local okInput, u = pcall(function() return Enum.UserInputType[bindName] end)
    if okInput and u and u ~= Enum.UserInputType.None then return u end
    return nil
end

local function NormalizeSelectionList(selection, default)
    if type(selection) == "table" then
        local res = {}
        for k, v in pairs(selection) do
            if type(k) == "number" then
                table.insert(res, v)
            elseif v == true then
                table.insert(res, k)
            end
        end
        if #res > 0 or not default then return res end
    end
    return default or {}
end

local function SaveConfig()
    if not isScriptRunning or isLoadingConfig then return end
    EnsureFolders()

    local keybindStr = "RightControl"
    if typeof(State.Keybind) == "EnumItem" then
        keybindStr = State.Keybind.Name
    elseif type(State.Keybind) == "string" and State.Keybind ~= "" then
        keybindStr = State.Keybind
    end

    local payload = {
        AutoRoll = (State.AutoRoll == true),
        AutoBuyDice = (State.AutoBuyDice == true),
        AutoEquipBestDice = (State.AutoEquipBestDice == true),
        AutoRebirth = (State.AutoRebirth == true),
        AutoUpgrades = (State.AutoUpgrades == true),
        AutoClaimQuests = (State.AutoClaimQuests == true),
        AutoClaimDailyReward = (State.AutoClaimDailyReward == true),
        AutoQuirks = (State.AutoQuirks == true),
        SelectedQuirkUnits = NormalizeSelectionList(State.SelectedQuirkUnits),
        SelectedQuirks = NormalizeSelectionList(State.SelectedQuirks, { "Fortune's Favor", "Midas Touch", "Prodigy", "Tycoon", "Fortune III" }),
        AutoGrades = (State.AutoGrades == true),
        SelectedGradeUnits = NormalizeSelectionList(State.SelectedGradeUnits),
        SelectedGrades = NormalizeSelectionList(State.SelectedGrades, { "Ω", "∞", "神", "Z+", "Z" }),
        AutoTraits = (State.AutoTraits == true),
        SelectedTraitUnits = NormalizeSelectionList(State.SelectedTraitUnits),
        SelectedTraits = NormalizeSelectionList(State.SelectedTraits, { "Genesis", "Paradox", "Eternal", "Transcendent", "Monarch" }),
        AutoSellEnabled = (State.AutoSellEnabled == true),
        AutoSellNumber = tostring(State.AutoSellNumber or "10"),
        AutoSellUnit = tostring(State.AutoSellUnit or "k"),
        AutoSellValue = tonumber(State.AutoSellValue) or 0,
        AutoUsePotions = (State.AutoUsePotions == true),
        AutoUsePotionTypes = NormalizeSelectionList(State.AutoUsePotionTypes, { "Luck", "Damage", "Income", "Speed" }),
        AutoUsePotionMode = tostring(State.AutoUsePotionMode or "Keep Active"),
        AutoCollectPlot = (State.AutoCollectPlot == true),
        CollectInterval = tonumber(State.CollectInterval) or 5,
        AutoEquipBest = (State.AutoEquipBest == true),
        EquipBestInterval = tonumber(State.EquipBestInterval) or 15,
        AutoUpgradePlot = (State.AutoUpgradePlot == true),
        PlotTargetLevel = tonumber(State.PlotTargetLevel) or 100,
        AcrylicBlur = (State.AcrylicBlur == true),
        ShowUserInfo = (State.ShowUserInfo ~= false),
        MobileToggle = (State.MobileToggle ~= false),
        Keybind = keybindStr,
        UISize = State.UISize or { Width = 868, Height = 650 }
    }

    local okEnc, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if okEnc and encoded and writefile then
        pcall(writefile, ConfigFile, encoded)
    end
end

local saveDebounce = false
local function SaveConfigDebounced()
    if not isScriptRunning or isLoadingConfig or saveDebounce then return end
    saveDebounce = true
    task.delay(0.5, function()
        saveDebounce = false
        if isScriptRunning and not isLoadingConfig then
            SaveConfig()
        end
    end)
end

-- Pre-load Config (early settings into State before Window creation)
EnsureFolders()
if isfile and isfile(ConfigFile) then
    local okRead, content = pcall(readfile, ConfigFile)
    if okRead and content and #content > 2 then
        local okParse, data = pcall(function() return HttpService:JSONDecode(content) end)
        if okParse and type(data) == "table" then
            if data.AutoRoll ~= nil then State.AutoRoll = (data.AutoRoll == true) end
            if data.AutoBuyDice ~= nil then State.AutoBuyDice = (data.AutoBuyDice == true) end
            if data.AutoEquipBestDice ~= nil then State.AutoEquipBestDice = (data.AutoEquipBestDice == true) end
            if data.AutoRebirth ~= nil then State.AutoRebirth = (data.AutoRebirth == true) end
            if data.AutoUpgrades ~= nil then State.AutoUpgrades = (data.AutoUpgrades == true) end
            if data.AutoQuirks ~= nil then State.AutoQuirks = (data.AutoQuirks == true) end
            if data.SelectedQuirkUnits ~= nil and type(data.SelectedQuirkUnits) == "table" then
                State.SelectedQuirkUnits = data.SelectedQuirkUnits
            end
            if data.SelectedQuirks ~= nil and type(data.SelectedQuirks) == "table" then
                State.SelectedQuirks = data.SelectedQuirks
            end
            if data.AutoGrades ~= nil then State.AutoGrades = (data.AutoGrades == true) end
            if data.SelectedGradeUnits ~= nil and type(data.SelectedGradeUnits) == "table" then
                State.SelectedGradeUnits = data.SelectedGradeUnits
            end
            if data.SelectedGrades ~= nil and type(data.SelectedGrades) == "table" then
                State.SelectedGrades = data.SelectedGrades
            end
            if data.AutoTraits ~= nil then State.AutoTraits = (data.AutoTraits == true) end
            if data.SelectedTraitUnits ~= nil and type(data.SelectedTraitUnits) == "table" then
                State.SelectedTraitUnits = data.SelectedTraitUnits
            end
            if data.SelectedTraits ~= nil and type(data.SelectedTraits) == "table" then
                State.SelectedTraits = data.SelectedTraits
            end
            if data.AutoUsePotions ~= nil then State.AutoUsePotions = (data.AutoUsePotions == true) end
            if data.AutoUsePotionTypes ~= nil and type(data.AutoUsePotionTypes) == "table" then
                State.AutoUsePotionTypes = data.AutoUsePotionTypes
            end
            if data.AutoUsePotionMode ~= nil then State.AutoUsePotionMode = tostring(data.AutoUsePotionMode) end
            if data.AutoSellEnabled ~= nil then State.AutoSellEnabled = (data.AutoSellEnabled == true) end
            if data.AutoSellNumber ~= nil then State.AutoSellNumber = tostring(data.AutoSellNumber) end
            if data.AutoSellUnit ~= nil then State.AutoSellUnit = tostring(data.AutoSellUnit) end
            if data.AutoSellValue ~= nil then State.AutoSellValue = tonumber(data.AutoSellValue) or 0 end
            if data.AutoCollectPlot ~= nil then State.AutoCollectPlot = (data.AutoCollectPlot == true) end
            if data.CollectInterval then State.CollectInterval = tonumber(data.CollectInterval) or 5 end
            if data.AutoEquipBest ~= nil then State.AutoEquipBest = (data.AutoEquipBest == true) end
            if data.EquipBestInterval then State.EquipBestInterval = tonumber(data.EquipBestInterval) or 15 end
            if data.AutoUpgradePlot ~= nil then State.AutoUpgradePlot = (data.AutoUpgradePlot == true) end
            if data.PlotTargetLevel then State.PlotTargetLevel = tonumber(data.PlotTargetLevel) or 100 end
            if data.AcrylicBlur ~= nil then State.AcrylicBlur = (data.AcrylicBlur == true) end
            if data.ShowUserInfo ~= nil then State.ShowUserInfo = (data.ShowUserInfo ~= false) end
            if data.MobileToggle ~= nil then State.MobileToggle = (data.MobileToggle ~= false) end
            if data.Keybind then
                local k = ResolveBind(data.Keybind)
                if k then State.Keybind = k end
            end
            if data.UISize and data.UISize.Width and data.UISize.Height then
                State.UISize = data.UISize
            end
        end
    end
end

-- Auto-Save Loop
SpawnTracked(function()
    while isScriptRunning do
        task.wait(10)
        if not isScriptRunning then break end
        if not isLoadingConfig then SaveConfig() end
    end
end)

pcall(function()
    game:BindToClose(function()
        isScriptRunning = false
        pcall(SaveConfig)
    end)
end)

-- ==============================================================================
-- 3. MACLIB LOADING & REGEX PATCHES
-- ==============================================================================
local MacLib = nil
local MacLibCacheFile = "STRIX HUB/maclib_cache.lua"
local rawMaclibSource = nil

if isfile and isfile(MacLibCacheFile) then
    local ok, cached = pcall(readfile, MacLibCacheFile)
    if ok and cached and #cached > 1000 then
        rawMaclibSource = cached
    end
end

if not rawMaclibSource then
    local maclibSources = {
        "https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt",
        "https://raw.githubusercontent.com/biggaboy212/Public-Resources/main/MacLib/maclib.lua"
    }
    for _, url in ipairs(maclibSources) do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and res and #res > 1000 then
            rawMaclibSource = res
            if writefile then pcall(writefile, MacLibCacheFile, res) end
            break
        end
    end
end

if not rawMaclibSource then
    error("[STRIX HUB] Failed to download MacLib library!")
end

-- Apply Essential Patches
if rawMaclibSource:find("Selected = {}\r\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\r\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\r\n\t\t\t\t\t\t\tend", 1)
elseif rawMaclibSource:find("Selected = {}\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\n\t\t\t\t\t\t\tend", 1)
end

local patDefault = "isSelected = %(Settings%.Default == i%) and true or false"
local replDefault = "isSelected = (Settings.Default == i or Settings.Default == v or (type(Settings.Default) == 'table' and table.find(Settings.Default, v) ~= nil)) and true or false"
rawMaclibSource = rawMaclibSource:gsub(patDefault, replDefault)

local patUpdateSel = "function DropdownFunctions:UpdateSelection%(newSelection%)"
local replUpdateSel = [[function DropdownFunctions:UpdateSelection(newSelection)
						if type(newSelection) == "string" or type(newSelection) == "number" then
							newSelection = { newSelection }
						elseif type(newSelection) == "table" then
							local flat = {}
							for k, v in pairs(newSelection) do
								if type(k) == "number" then
									table.insert(flat, v)
								elseif v == true then
									table.insert(flat, k)
								end
							end
							newSelection = flat
						end]]
rawMaclibSource = rawMaclibSource:gsub(patUpdateSel, replUpdateSel)

local patSliderMinMax = "function SectionFunctions:Slider%(Settings, Flag%)"
local replSliderMinMax = "function SectionFunctions:Slider(Settings, Flag)\n\t\t\t\t\tSettings.Minimum = Settings.Minimum or Settings.Min or 0\n\t\t\t\t\tSettings.Maximum = Settings.Maximum or Settings.Max or 100"
rawMaclibSource = rawMaclibSource:gsub(patSliderMinMax, replSliderMinMax)

rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, %(base%.AbsoluteSize%.X %- sidebar%.AbsoluteSize%.X%), 1, 0%)",
    "content.Size = UDim2.new(1 - sidebar.Size.X.Scale, -sidebar.Size.X.Offset, 1, 0)"
)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, base%.AbsoluteSize%.X %- newSidebarWidth, 1, 0%)",
    "content.Size = UDim2.new(1, -newSidebarWidth, 1, 0)"
)

local patDivLine = "line%.BackgroundColor3 = Color3%.fromRGB%(255, 255, 255%)\r?\n\t*line%.BackgroundTransparency = 0%.9\r?\n\t*line%.BorderColor3 = Color3%.fromRGB%(0, 0, 0%)\r?\n\t*line%.BorderSizePixel = 0\r?\n\t*line%.Size = UDim2%.new%(1, 0, 0, 1%)"
local replDivLine = "line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)\n\t\t\t\t\tline.BackgroundTransparency = 0.68\n\t\t\t\t\tline.BorderSizePixel = 0\n\t\t\t\t\tline.Size = UDim2.new(1, 0, 0, 1)"
rawMaclibSource = rawMaclibSource:gsub(patDivLine, replDivLine)

local patTween = "local function Tween%(instance, tweeninfo, propertytable%)\r?\n\t*return TweenService:Create%(instance, tweeninfo, propertytable%)\r?\nend"
local replTween = [[local function Tween(instance, tweeninfo, propertytable)
    local ok, tw = pcall(function() return TweenService:Create(instance, tweeninfo, propertytable) end)
    if ok and tw then return tw end
    pcall(function()
        if instance and propertytable then
            for prop, val in pairs(propertytable) do instance[prop] = val end
        end
    end)
    return { Play = function() end, Stop = function() end, Cancel = function() end, Pause = function() end, Completed = { Connect = function() return { Disconnect = function() end } end, Wait = function() end } }
end]]
rawMaclibSource = rawMaclibSource:gsub(patTween, replTween)

local loadedLib = loadstring(rawMaclibSource)
if loadedLib then
    MacLib = loadedLib()
end

if not MacLib then
    error("[STRIX HUB] Failed to initialize MacLib!")
end

-- ==============================================================================
-- 4. WINDOW CREATION & DIRECTX CRASH BYPASS
-- ==============================================================================
local Window = MacLib:Window({
    Title = "STRIX HUB",
    Subtitle = "Anime Dice",
    Size = (State.UISize and State.UISize.Width and State.UISize.Height) and UDim2.fromOffset(State.UISize.Width, State.UISize.Height) or UDim2.fromOffset(868, 650),
    DragStyle = 1,
    AcrylicBlur = (State.AcrylicBlur == true),
    ShowUserInfo = (State.ShowUserInfo ~= false),
    Keybind = (State.Keybind and State.Keybind ~= Enum.KeyCode.Unknown) and State.Keybind or Enum.KeyCode.RightControl
})

-- Prevent CanvasGroup DirectX Lost Device Crash
Window:SetNotificationsState(false)

Window.Dialog = function(self, dialogSettings)
    if dialogSettings and dialogSettings.Buttons then
        for _, btn in ipairs(dialogSettings.Buttons) do
            if btn.Name == "Confirm" and btn.Callback then
                task.spawn(btn.Callback)
                break
            end
        end
    end
    return { UpdateTitle = function() end, UpdateDescription = function() end, Cancel = function() end }
end

if Window.onUnloaded then
    Window.onUnloaded(function()
        if getgenv().STRIX_HUB_CLEANUP then pcall(getgenv().STRIX_HUB_CLEANUP) end
    end)
end

-- ==============================================================================
-- 5. RESPONSIVE SCREEN AUTO-SCALE & DRAG-TO-RESIZE (AnimeMysterious Standard)
-- ==============================================================================
local UpdateResponsiveScaleRef = nil

local function SetupWindowResize()
    local targetScreenGui
    local parent = (gethui and gethui()) or game:GetService("CoreGui")

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
    pcall(function() targetScreenGui.DisplayOrder = 999999 end)
    local base = targetScreenGui.Base

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
        local marginX = (screenW < 750) and 10 or ((screenW < 1000) and 16 or 24)
        local marginY = (screenH < 550) and 10 or ((screenH < 750) and 16 or 24)
        local availW = math.max(screenW - marginX * 2, 200)
        local availH = math.max(screenH - marginY * 2, 180)

        local refW = math.max(DESIGN_BASE_W, (base.Size and base.Size.X.Offset) or DESIGN_BASE_W)
        local refH = math.max(DESIGN_BASE_H, (base.Size and base.Size.Y.Offset) or DESIGN_BASE_H)

        local scaleX = availW / refW
        local scaleY = availH / refH
        local autoFit = math.min(scaleX, scaleY)

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

    local resizeConnections = {}
    local function CleanResizeConnections()
        for _, c in ipairs(resizeConnections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(resizeConnections)
    end
    getgenv().STRIX_UI_RESIZE_CLEANUP = CleanResizeConnections

    local resizingType = nil
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
                task.defer(function()
                    pcall(function()
                        ClampWindowBounds()
                    end)
                end)
            end
        end
    end))

    UpdateResponsiveScale(true)
end
SpawnTracked(SetupWindowResize)

-- ==============================================================================
-- 6. MOBILE FLOATING ACTION BUTTON
-- ==============================================================================
local function CreateMobileToggleButton()
    if getgenv().STRIX_MOBILE_GUI then
        pcall(function() getgenv().STRIX_MOBILE_GUI:Destroy() end)
    end

    local h = (gethui and gethui()) or game:GetService("CoreGui")
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "STRIX_MOBILE_TOGGLE"
    mobileGui.ResetOnSpawn = false
    mobileGui.DisplayOrder = 999999
    pcall(function() mobileGui.Parent = h end)
    if not mobileGui.Parent then mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    getgenv().STRIX_MOBILE_GUI = mobileGui

    local btn = Instance.new("ImageButton", mobileGui)
    btn.Name = "FloatingButton"
    btn.Size = UDim2.fromOffset(46, 46)
    btn.Position = UDim2.new(0, 15, 0, 140)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    btn.BackgroundTransparency = 0.15
    btn.Active = true

    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 1.4

    local icon = Instance.new("ImageLabel", btn)
    icon.Size = UDim2.fromOffset(26, 26)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://10709782230"

    local statusDot = Instance.new("Frame", btn)
    statusDot.Size = UDim2.fromOffset(8, 8)
    statusDot.Position = UDim2.new(1, -5, 0, 5)
    statusDot.AnchorPoint = Vector2.new(1, 0)
    statusDot.BackgroundColor3 = Color3.fromRGB(0, 230, 130)
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local function UpdateVisuals(isOpen)
        stroke.Color = isOpen and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(65, 65, 75)
        statusDot.BackgroundColor3 = isOpen and Color3.fromRGB(0, 230, 130) or Color3.fromRGB(255, 80, 80)
        icon.ImageTransparency = isOpen and 0 or 0.2
    end

    btn.Activated:Connect(function()
        local cur = Window:GetState()
        Window:SetState(not cur)
        UpdateVisuals(not cur)
    end)
    return mobileGui
end
SpawnTracked(CreateMobileToggleButton)

-- ==============================================================================
-- 7. TAB & SECTION ARCHITECTURE
-- ==============================================================================
local TabGroup = Window:TabGroup()

local Tabs = {
    Main = TabGroup:Tab({ Name = "Main", Image = "rbxassetid://10723407389" }), -- lucide-dices
    Progression = TabGroup:Tab({ Name = "Progression", Image = "rbxassetid://10747363465" }), -- lucide-trending-up
    Plots = TabGroup:Tab({ Name = "Plot & Units", Image = "rbxassetid://10723407389" }), -- lucide-home
    Hub = TabGroup:Tab({ Name = "Hub", Image = "rbxassetid://10723405980" }), -- lucide-globe-2
    Stats = TabGroup:Tab({ Name = "Stats & Codes", Image = "rbxassetid://10709770317" }), -- lucide-bar-chart-2
    Settings = TabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" }) -- lucide-settings
}

local MainSections = {
    Roll = Tabs.Main:Section({ Side = "Left" }),
    Boosts = Tabs.Main:Section({ Side = "Left" }),
    Right = Tabs.Main:Section({ Side = "Right" })
}

local ProgressionSections = {
    Left = Tabs.Progression:Section({ Side = "Left" }),
    Rewards = Tabs.Progression:Section({ Side = "Left" }),
    Right = Tabs.Progression:Section({ Side = "Right" })
}

local PlotSections = {
    Collect = Tabs.Plots:Section({ Side = "Left" }),
    Upgrade = Tabs.Plots:Section({ Side = "Left" }),
    Right = Tabs.Plots:Section({ Side = "Right" })
}

local HubSections = {
    Quirks = Tabs.Hub:Section({ Side = "Left" }),
    Grades = Tabs.Hub:Section({ Side = "Right" }),
    Traits = Tabs.Hub:Section({ Side = "Left" })
}

local StatsSections = {
    Left = Tabs.Stats:Section({ Side = "Left" }),
    Right = Tabs.Stats:Section({ Side = "Right" })
}

local SettingsSections = {
    Controls = Tabs.Settings:Section({ Side = "Left" }),
    Config = Tabs.Settings:Section({ Side = "Right" })
}

-- ==============================================================================
-- 8. MAIN / AUTO TAB: AUTO ROLL & AUTO SELL
-- ==============================================================================
MainSections.Roll:Header({ Text = "Auto Roll" })

MainSections.Roll:Toggle({
    Name = "Auto Roll",
    Default = (State.AutoRoll == true),
    Callback = function(v)
        State.AutoRoll = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoRoll")

-- ==============================================================================
-- 8.1 POTIONS & BOOSTS HELPERS & UI
-- ==============================================================================
local function ParseBoostTimeString(str)
    if not str or type(str) ~= "string" then return 0 end
    local days = tonumber(str:match("(%d+)%s*d")) or 0
    local hours = tonumber(str:match("(%d+)%s*h")) or 0
    local mins = tonumber(str:match("(%d+)%s*m")) or 0
    local secs = tonumber(str:match("(%d+)%s*s")) or 0
    local total = (days * 86400) + (hours * 3600) + (mins * 60) + secs
    if total == 0 and tonumber(str) then total = tonumber(str) end
    return total > 0 and total or 9999
end

local function GetActiveBoosts()
    local active = {}

    -- Method 1: u98 table from BuffBarController.SetWeather via getupvalues
    pcall(function()
        if getupvalues and BuffBarController and BuffBarController.SetWeather then
            local upvals = getupvalues(BuffBarController.SetWeather)
            local u98 = upvals and upvals[1]
            if type(u98) == "table" then
                local now = workspace:GetServerTimeNow()
                for k, v in pairs(u98) do
                    if type(v) == "table" and v.name then
                        local rem = v.remaining or 0
                        if v.startedAt and typeof(v.startedAt) == "number" then
                            rem = math.max(0, rem - (now - v.startedAt))
                        end
                        local keyName = v.name or k
                        active[keyName] = {
                            name = keyName,
                            remaining = rem,
                            tier = v.tier or 1
                        }
                    end
                end
            end
        end
    end)

    -- Method 2: ActiveEntries in DataController
    pcall(function()
        if DataController and DataController.ActiveEntries then
            local entries = DataController.ActiveEntries()
            if type(entries) == "table" then
                local now = workspace:GetServerTimeNow()
                for k, v in pairs(entries) do
                    if type(v) == "table" and v.startedAt and typeof(v.startedAt) == "number" then
                        local rem = math.max(0, (v.remaining or 0) - (now - v.startedAt))
                        local itemName = v.name or k
                        if not active[itemName] or rem > (active[itemName].remaining or 0) then
                            local cfg = EntryRegistry and EntryRegistry.getEntryConfig(itemName)
                            active[itemName] = {
                                name = itemName,
                                remaining = rem,
                                tier = cfg and cfg.tier or 1
                            }
                        end
                    end
                end
            end
        end
    end)

    -- Method 3: Fallback to BuffBar & Boosts menu GUI children
    pcall(function()
        local BuffBar = UIReferences and UIReferences.HUD and UIReferences.HUD.BuffBar
        if BuffBar then
            for _, child in ipairs(BuffBar:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible and child.Name:sub(1, 6) == "Boost_" then
                    local boostKey = child.Name:sub(7)
                    if not active[boostKey] then
                        local label = child:FindFirstChildWhichIsA("TextLabel", true)
                        active[boostKey] = {
                            name = boostKey,
                            remaining = label and ParseBoostTimeString(label.Text) or 9999,
                            tier = 1
                        }
                    end
                end
            end
        end
        local BoostsMenu = UIReferences and UIReferences.Menus and UIReferences.Menus.Boosts
        local scrolling = BoostsMenu and BoostsMenu.Content and BoostsMenu.Content.ScrollingFrame
        if scrolling then
            for _, child in ipairs(scrolling:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible and child.Name:sub(1, 6) == "Boost_" then
                    local boostKey = child.Name:sub(7)
                    if not active[boostKey] then
                        local label = child:FindFirstChildWhichIsA("TextLabel", true)
                        active[boostKey] = {
                            name = boostKey,
                            remaining = label and ParseBoostTimeString(label.Text) or 9999,
                            tier = 1
                        }
                    end
                end
            end
        end
    end)

    return active
end

local function IsPotionTypeSelected(baseType)
    local selected = State.AutoUsePotionTypes
    if not selected then return true end
    if type(selected) == "table" then
        local count = 0
        for _, _ in pairs(selected) do
            count = count + 1
            break
        end
        if count == 0 then return true end

        if selected["All"] == true or selected["ALL"] == true or selected["all"] == true then return true end
        if selected[baseType] == true then return true end
        for k, v in pairs(selected) do
            if v == "All" or v == "ALL" or v == "all" then return true end
            if v == baseType or k == baseType then return true end
            if type(v) == "string" and baseType and string.lower(v) == string.lower(baseType) then return true end
        end
    end
    return false
end

local function UseSelectedPotionsOnce()
    if not (UseBoostRE and DataController and EntryRegistry) then return 0 end
    local count = 0
    pcall(function()
        local inv = DataController.Inventory and DataController.Inventory() or {}
        local activeBoosts = GetActiveBoosts()
        local isStackMode = (State.AutoUsePotionMode == "Stack All")

        for k, v in pairs(inv) do
            if type(v) == "table" and (v.amount or 0) > 0 then
                local cfg = EntryRegistry.getEntryConfig(v.name)
                if cfg and cfg.kind == "Boost" then
                    local baseType = cfg.category and cfg.category:match("([A-Za-z]+)$") or cfg.category
                    if IsPotionTypeSelected(baseType) or IsPotionTypeSelected("All") then
                        local exactActive = activeBoosts[v.name]
                        local hasActiveCountdown = exactActive and (exactActive.remaining > 10)
                        if isStackMode or not hasActiveCountdown then
                            local toConsume = isStackMode and (v.amount or 1) or 1
                            for _ = 1, toConsume do
                                UseBoostRE:FireServer(k)
                                count = count + 1
                                task.wait(0.015)
                            end
                        end
                    end
                end
            end
        end
    end)
    return count
end

MainSections.Boosts:Header({ Text = "Potions" })

local PotionStatusLabel = MainSections.Boosts:Label({ Text = "Active Boosts: Checking..." })

MainSections.Boosts:Toggle({
    Name = "Auto Use Potions",
    Default = (State.AutoUsePotions == true),
    Callback = function(v)
        State.AutoUsePotions = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoUsePotions")

MainSections.Boosts:Dropdown({
    Name = "Potion Types",
    Multi = true,
    Required = false,
    Options = { "Luck", "Damage", "Income", "Speed" },
    Default = (function()
        if type(State.AutoUsePotionTypes) == "table" then
            local arr = {}
            for k, val in pairs(State.AutoUsePotionTypes) do
                if type(k) == "number" then
                    table.insert(arr, val)
                elseif val == true then
                    table.insert(arr, k)
                end
            end
            if #arr > 0 then return arr end
        end
        return { "Luck", "Damage", "Income", "Speed" }
    end)(),
    Callback = function(val)
        State.AutoUsePotionTypes = {}
        if type(val) == "table" then
            for target, enabled in pairs(val) do
                if enabled == true or type(target) == "number" then
                    local key = type(target) == "number" and enabled or target
                    State.AutoUsePotionTypes[key] = true
                end
            end
        end
        SaveConfigDebounced()
    end
}, "Dropdown_AutoUsePotionTypes")

MainSections.Boosts:Dropdown({
    Name = "Potion Mode",
    Multi = false,
    Required = true,
    Options = { "Keep Active", "Stack All" },
    Default = State.AutoUsePotionMode or "Keep Active",
    Callback = function(choice)
        local opt = type(choice) == "table" and choice[1] or choice
        State.AutoUsePotionMode = opt
        SaveConfigDebounced()
    end
}, "Dropdown_AutoUsePotionMode")

MainSections.Boosts:Button({
    Name = "Use Selected Potions Once",
    Callback = function()
        local count = UseSelectedPotionsOnce()
        if PotionStatusLabel and PotionStatusLabel.UpdateName then
            PotionStatusLabel:UpdateName(string.format("Triggered %d potions once", count))
        end
    end
})

-- Auto Sell Section
MainSections.Right:Header({ Text = "Auto Sell" })

local AutoSellStatusLabel = MainSections.Right:Label({ Text = "Current Server AutoSell: Loading..." })

local UnitMultipliers = {
    ["k"] = 1e3,
    ["m"] = 1e6,
    ["b"] = 1e9,
    ["t"] = 1e12,
    ["qd"] = 1e15,
    ["qi"] = 1e18,
    ["sx"] = 1e21,
    ["sp"] = 1e24,
    ["none"] = 1
}

local function CalculateAutoSellValue()
    local num = tonumber(State.AutoSellNumber) or 0
    local unitKey = tostring(State.AutoSellUnit or "k"):lower()
    local mult = UnitMultipliers[unitKey] or 1
    local val = math.floor(num * mult)
    return math.clamp(val, 0, 1e26)
end

local function UpdateLabel(labelObj, text)
    if not labelObj then return end
    if labelObj.UpdateName then
        pcall(function() labelObj:UpdateName(text) end)
    elseif labelObj.SetText then
        pcall(function() labelObj:SetText(text) end)
    end
end

local function ApplyAutoSell(val)
    local targetVal = val
    if targetVal == nil then
        targetVal = State.AutoSellEnabled and CalculateAutoSellValue() or (State.AutoSellValue or 0)
    end
    if targetVal > 0 or val == 0 then
        State.AutoSellValue = targetVal
    end

    if UpdateAutoSellRE then
        pcall(function() UpdateAutoSellRE:FireServer(targetVal) end)
    end
    if targetVal == 0 then
        UpdateLabel(AutoSellStatusLabel, "Current Server AutoSell: Off (0)")
    else
        local formatted = (NumberFormatter and NumberFormatter.FormatCompact) and NumberFormatter.FormatCompact(targetVal) or tostring(targetVal)
        UpdateLabel(AutoSellStatusLabel, "Current Server AutoSell: 1 in " .. formatted)
    end
    SaveConfigDebounced()
end

MainSections.Right:Toggle({
    Name = "Enable Auto Sell",
    Default = (State.AutoSellEnabled == true),
    Callback = function(v)
        State.AutoSellEnabled = v
        if v then
            ApplyAutoSell(CalculateAutoSellValue())
        else
            SaveConfigDebounced()
        end
    end
}, "Toggle_AutoSellEnabled")

MainSections.Right:Input({
    Name = "Auto Sell Number",
    Placeholder = "e.g. 10",
    AcceptedCharacters = function(str)
        return str:gsub("[^0-9%.]", "")
    end,
    Default = tostring(State.AutoSellNumber or "10"),
    Callback = function(text)
        if text and text ~= "" then
            State.AutoSellNumber = text
        else
            State.AutoSellNumber = "0"
        end
        if State.AutoSellEnabled then
            ApplyAutoSell(CalculateAutoSellValue())
        else
            SaveConfigDebounced()
        end
    end
}, "Input_AutoSellNumber")

MainSections.Right:Dropdown({
    Name = "Select Place Values",
    Multi = false,
    Required = true,
    Options = { "None", "k", "m", "b", "t", "qd", "qi", "sx", "sp" },
    Default = State.AutoSellUnit or "k",
    Callback = function(choice)
        local opt = type(choice) == "table" and choice[1] or choice
        State.AutoSellUnit = opt
        if State.AutoSellEnabled then
            ApplyAutoSell(CalculateAutoSellValue())
        else
            SaveConfigDebounced()
        end
    end
}, "Dropdown_AutoSellUnit")

-- ==============================================================================
-- 8.5 PROGRESSION TAB: SHOP & EQUIP BEST
-- ==============================================================================
ProgressionSections.Left:Header({ Text = "Shop & Equip Best" })

ProgressionSections.Left:Toggle({
    Name = "Auto Buy Dice Shop",
    Default = (State.AutoBuyDice == true),
    Callback = function(v)
        State.AutoBuyDice = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyDice")

ProgressionSections.Left:Toggle({
    Name = "Auto Equip Best Dice",
    Default = (State.AutoEquipBestDice == true),
    Callback = function(v)
        State.AutoEquipBestDice = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoEquipBestDice")

ProgressionSections.Rewards:Header({ Text = "Rewards & Quests" })

ProgressionSections.Rewards:Toggle({
    Name = "Auto Claim Quests (Daily/Weekly)",
    Default = (State.AutoClaimQuests == true),
    Callback = function(v)
        State.AutoClaimQuests = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoClaimQuests")

ProgressionSections.Rewards:Toggle({
    Name = "Auto Claim Daily Reward",
    Default = (State.AutoClaimDailyReward == true),
    Callback = function(v)
        State.AutoClaimDailyReward = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoClaimDailyReward")

ProgressionSections.Right:Header({ Text = "Rebirth & Upgrades" })

ProgressionSections.Right:Toggle({
    Name = "Auto Rebirth",
    Default = (State.AutoRebirth == true),
    Callback = function(v)
        State.AutoRebirth = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoRebirth")

ProgressionSections.Right:Toggle({
    Name = "Auto Upgrades",
    Default = (State.AutoUpgrades == true),
    Callback = function(v)
        State.AutoUpgrades = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoUpgrades")

-- ==============================================================================
-- 9. PLOTS & UNITS TAB
-- ==============================================================================
PlotSections.Collect:Header({ Text = "Auto Collect" })

PlotSections.Collect:Toggle({
    Name = "Auto Collect",
    Default = (State.AutoCollectPlot == true),
    Callback = function(v)
        State.AutoCollectPlot = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoCollectPlot")

PlotSections.Collect:Input({
    Name = "Collect (Seconds)",
    Placeholder = "e.g. 5",
    AcceptedCharacters = function(str)
        return str:gsub("[^0-9]", "")
    end,
    Default = tostring(State.CollectInterval or 5),
    Callback = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            State.CollectInterval = math.max(1, math.floor(num))
        else
            State.CollectInterval = 5
        end
        SaveConfigDebounced()
    end
}, "Input_CollectInterval")

PlotSections.Collect:Button({
    Name = "Collect All Now",
    Callback = function()
        if CollectBalanceRE and DataController and DataController.Slots then
            pcall(function()
                local slots = DataController.Slots()
                for slotKey, _ in pairs(slots) do
                    local idx = tonumber(slotKey)
                    if idx then
                        CollectBalanceRE:FireServer(idx)
                    end
                end
            end)
        end
    end
})

PlotSections.Upgrade:Header({ Text = "Auto Upgrade Plot" })

PlotSections.Upgrade:Toggle({
    Name = "Auto Upgrade Plot",
    Default = (State.AutoUpgradePlot == true),
    Callback = function(v)
        State.AutoUpgradePlot = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoUpgradePlot")

PlotSections.Upgrade:Input({
    Name = "Plot Target Level",
    Placeholder = "e.g. 100",
    AcceptedCharacters = function(str)
        return str:gsub("[^0-9]", "")
    end,
    Default = tostring(State.PlotTargetLevel or 100),
    Callback = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            State.PlotTargetLevel = math.floor(num)
        else
            State.PlotTargetLevel = 100
        end
        SaveConfigDebounced()
    end
}, "Input_PlotTargetLevel")

local isEquippingBest = false
local function AreSlotsSorted()
    if not (DataController and DataController.Inventory and DataController.Slots and EntryRegistry) then
        return false
    end
    local inventory = DataController.Inventory()
    local slots = DataController.Slots()
    if not inventory or not slots then return true end

    local topUnits = {}
    for key, item in pairs(inventory) do
        local cfg = EntryRegistry.getEntryConfig(item.name)
        if cfg and cfg.kind == "Unit" then
            local inc = 0
            pcall(function() inc = cfg.income(item.attributes) end)
            table.insert(topUnits, { key = key, income = inc })
        end
    end
    table.sort(topUnits, function(a, b)
        if a.income == b.income then return a.key < b.key end
        return a.income > b.income
    end)

    local slotNumbers = {}
    for slotKey, _ in pairs(slots) do
        local num = tonumber(slotKey)
        if num then table.insert(slotNumbers, num) end
    end
    table.sort(slotNumbers)

    for i, slotNum in ipairs(slotNumbers) do
        local targetUnit = topUnits[i]
        local currentSlot = slots[tostring(slotNum)] or slots[slotNum]
        local currentUnitId = currentSlot and currentSlot.unitId
        if not targetUnit or currentUnitId ~= targetUnit.key then
            return false
        end
    end

    return true
end

local function EquipBestSorted(force)
    if isEquippingBest or not EquipBestRE then return end
    isEquippingBest = true

    pcall(function()
        if not force and AreSlotsSorted() then
            return
        end

        -- If not in order, unequip Slot 1 so server EquipBest doesn't skip due to top-set matching
        if InteractSlotRE and UnequipRF then
            pcall(function()
                InteractSlotRE:FireServer(1)
                task.wait(0.55)
                UnequipRF:InvokeServer()
                task.wait(0.2)
            end)
        end

        EquipBestRE:FireServer()
    end)

    isEquippingBest = false
end

PlotSections.Right:Header({ Text = "Auto Equip Plot" })

PlotSections.Right:Toggle({
    Name = "Auto Equip Best Units",
    Default = (State.AutoEquipBest == true),
    Callback = function(v)
        State.AutoEquipBest = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoEquipBest")

PlotSections.Right:Input({
    Name = "Equip Best (Seconds)",
    Placeholder = "e.g. 15",
    AcceptedCharacters = function(str)
        return str:gsub("[^0-9]", "")
    end,
    Default = tostring(State.EquipBestInterval or 15),
    Callback = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            State.EquipBestInterval = math.max(1, math.floor(num))
        else
            State.EquipBestInterval = 15
        end
        SaveConfigDebounced()
    end
}, "Input_EquipBestInterval")

PlotSections.Right:Button({
    Name = "Equip Best Now",
    Callback = function()
        task.spawn(function()
            EquipBestSorted(true)
        end)
    end
})

-- ==============================================================================
-- 9.5. HUB TAB: AUTO QUIRKS
-- ==============================================================================
local unitOptionToId = {}
local unitIdToOption = {}

local function GetAvailableUnitOptions()
    local options = {}
    unitOptionToId = {}
    unitIdToOption = {}

    pcall(function()
        if DataController and DataController.Inventory and EntryRegistry then
            local inv = DataController.Inventory()
            local slots = (DataController.Slots and DataController.Slots()) or {}
            local slotByUnitId = {}
            for sNum, sData in pairs(slots) do
                if sData and sData.unitId then
                    slotByUnitId[sData.unitId] = sNum
                end
            end

            local temp = {}
            for id, item in pairs(inv) do
                local cfg = EntryRegistry.getEntryConfig(item.name)
                if cfg and cfg.kind == "Unit" then
                    local sNum = slotByUnitId[id]
                    local rawChance = 0
                    if cfg.chance then
                        pcall(function() rawChance = cfg.chance(item.attributes) end)
                    end
                    table.insert(temp, {
                        id = id,
                        name = item.name,
                        chance = rawChance,
                        slotNum = tonumber(sNum) or 999,
                        isSlot = sNum ~= nil
                    })
                end
            end

            table.sort(temp, function(a, b)
                if a.isSlot ~= b.isSlot then
                    return a.isSlot
                end
                if a.slotNum ~= b.slotNum then
                    return a.slotNum < b.slotNum
                end
                if a.chance ~= b.chance then
                    return a.chance > b.chance
                end
                return a.name < b.name
            end)

            table.insert(options, "[All Equipped Units]")

            local nameCounts = {}
            for _, u in ipairs(temp) do
                local prefix = u.isSlot and ("[Podium " .. tostring(u.slotNum) .. "] ") or ""
                local formattedChance = (NumberFormatter and NumberFormatter.FormatCompact and NumberFormatter.FormatCompact(u.chance)) or tostring(u.chance)
                local numPart, sfxPart = formattedChance:match("^([%d%.]+)(%a*)$")
                if numPart and sfxPart and sfxPart ~= "" then
                    formattedChance = numPart .. sfxPart:upper()
                end
                local chanceStr = "1 in " .. formattedChance
                local baseLabel = prefix .. u.name .. " (" .. chanceStr .. ")"

                nameCounts[baseLabel] = (nameCounts[baseLabel] or 0) + 1
                local finalLabel = baseLabel
                if nameCounts[baseLabel] > 1 then
                    finalLabel = baseLabel .. " #" .. tostring(nameCounts[baseLabel])
                end

                table.insert(options, finalLabel)
                unitOptionToId[finalLabel] = u.id
                unitIdToOption[u.id] = finalLabel
            end
        end
    end)
    if #options == 0 then
        options = { "[All Equipped Units]" }
    end
    return options
end

local function ResolveSelectedUnitIds(selectedUnits)
    local targetUnitIds = {}
    local hasAllEquipped = false

    local list = {}
    if type(selectedUnits) == "table" then
        for k, v in pairs(selectedUnits) do
            if type(k) == "number" then
                table.insert(list, v)
            elseif v == true then
                table.insert(list, k)
            end
        end
    end

    local inv = (DataController and DataController.Inventory and DataController.Inventory()) or {}
    local slots = (DataController and DataController.Slots and DataController.Slots()) or {}

    for _, opt in ipairs(list) do
        if opt == "[All Equipped Units]" then
            hasAllEquipped = true
        elseif unitOptionToId[opt] and inv[unitOptionToId[opt]] then
            targetUnitIds[unitOptionToId[opt]] = true
        else
            -- Robust fallback: match by podium number
            local podiumNum = opt:match("%[Podium (%d+)%]")
            if podiumNum and slots[podiumNum] and slots[podiumNum].unitId then
                targetUnitIds[slots[podiumNum].unitId] = true
            else
                -- Fallback to shortId in case config had previous format
                local shortId = opt:match("#([a-f0-9]+)")
                if shortId then
                    for id, _ in pairs(inv) do
                        if id:sub(1, #shortId) == shortId then
                            targetUnitIds[id] = true
                            break
                        end
                    end
                end
            end
        end
    end

    if hasAllEquipped then
        for _, s in pairs(slots) do
            if s and s.unitId and inv[s.unitId] then
                targetUnitIds[s.unitId] = true
            end
        end
    end

    return targetUnitIds
end

local function ToLookupMap(selection)
    local map = {}
    if type(selection) == "table" then
        for k, v in pairs(selection) do
            if type(k) == "number" then
                map[v] = true
            elseif v == true then
                map[k] = true
            end
        end
    end
    return map
end
local GetSelectedQuirksMap = ToLookupMap
local GetSelectedGradesMap = ToLookupMap
local GetSelectedTraitsMap = ToLookupMap

HubSections.Quirks:Header({ Text = "Auto Quirks" })

HubSections.Quirks:Toggle({
    Name = "Auto Quirks",
    Default = (State.AutoQuirks == true),
    Callback = function(v)
        State.AutoQuirks = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoQuirks")

local QuirkUnitsDropdown = HubSections.Quirks:Dropdown({
    Name = "Select Unit",
    Multi = true,
    Required = false,
    Options = GetAvailableUnitOptions(),
    Default = State.SelectedQuirkUnits or {},
    Callback = function(selected)
        State.SelectedQuirkUnits = selected
        SaveConfigDebounced()
    end
}, "Dropdown_QuirkUnits")

-- Dynamic Quirk and Grade Options Extractors (Auto-updates with game patches)
local function GetDynamicQuirkOptions()
    local quirksList = {}
    pcall(function()
        local quirksModule = ReplicatedStorage:FindFirstChild("Framework")
            and ReplicatedStorage.Framework:FindFirstChild("Features")
            and ReplicatedStorage.Framework.Features:FindFirstChild("Quirks")
            and ReplicatedStorage.Framework.Features.Quirks:FindFirstChild("Quirks")
        if quirksModule then
            local data = require(quirksModule)
            if type(data) == "table" then
                local items = {}
                for name, info in pairs(data) do
                    local ord = (type(info) == "table" and info.order) or 0
                    table.insert(items, { name = tostring(name), order = ord })
                end
                table.sort(items, function(a, b)
                    if a.order ~= b.order then
                        return a.order > b.order
                    end
                    return a.name < b.name
                end)
                for _, item in ipairs(items) do
                    table.insert(quirksList, item.name)
                end
            end
        end
    end)
    return quirksList
end

local function GetDynamicGradeOptions()
    local gradesList = {}
    pcall(function()
        local gradesModule = ReplicatedStorage:FindFirstChild("Framework")
            and ReplicatedStorage.Framework:FindFirstChild("Features")
            and ReplicatedStorage.Framework.Features:FindFirstChild("Grades")
            and ReplicatedStorage.Framework.Features.Grades:FindFirstChild("Grades")
        if gradesModule then
            local data = require(gradesModule)
            if type(data) == "table" then
                local items = {}
                for name, info in pairs(data) do
                    local ord = (type(info) == "table" and info.order) or 0
                    table.insert(items, { name = tostring(name), order = ord })
                end
                table.sort(items, function(a, b)
                    if a.order ~= b.order then
                        return a.order > b.order
                    end
                    return a.name < b.name
                end)
                for _, item in ipairs(items) do
                    table.insert(gradesList, item.name)
                end
            end
        end
    end)
    return gradesList
end

local function GetDynamicTraitOptions()
    local traitsList = {}
    pcall(function()
        local traitsModule = ReplicatedStorage:FindFirstChild("Framework")
            and ReplicatedStorage.Framework:FindFirstChild("Features")
            and ReplicatedStorage.Framework.Features:FindFirstChild("Traits")
            and ReplicatedStorage.Framework.Features.Traits:FindFirstChild("Traits")
        if traitsModule then
            local data = require(traitsModule)
            if type(data) == "table" then
                local items = {}
                for name, info in pairs(data) do
                    local ord = (type(info) == "table" and info.order) or 0
                    table.insert(items, { name = tostring(name), order = ord })
                end
                table.sort(items, function(a, b)
                    if a.order ~= b.order then
                        return a.order > b.order
                    end
                    return a.name < b.name
                end)
                for _, item in ipairs(items) do
                    table.insert(traitsList, item.name)
                end
            end
        end
    end)
    return traitsList
end

local function RefreshDropdownPreservingSelection(dropdown, getNewOptionsFunc, currentSelectionState, mapUnitPodium)
    if not dropdown or not dropdown.ClearOptions or not dropdown.InsertOptions then return end
    local savedList = NormalizeSelectionList(currentSelectionState)
    local newOptions = getNewOptionsFunc()
    if not newOptions or #newOptions == 0 then return end

    local preserved = {}
    for _, item in ipairs(savedList) do
        if table.find(newOptions, item) then
            table.insert(preserved, item)
        elseif mapUnitPodium then
            local podiumNum = item:match("%[Podium (%d+)%]")
            if podiumNum then
                for _, opt in ipairs(newOptions) do
                    if opt:match("%[Podium " .. podiumNum .. "%]") then
                        table.insert(preserved, opt)
                        break
                    end
                end
            end
        end
    end

    if #preserved == 0 and #savedList > 0 and not mapUnitPodium then
        preserved = savedList
    end

    if dropdown.Settings then
        dropdown.Settings.Default = preserved
    end

    dropdown:ClearOptions()
    dropdown:InsertOptions(newOptions)
    if dropdown.UpdateSelection and #preserved > 0 then
        dropdown:UpdateSelection(preserved)
    end
end

local QuirkTargetsDropdown = HubSections.Quirks:Dropdown({
    Name = "Select Quirk",
    Multi = true,
    Required = false,
    Options = GetDynamicQuirkOptions(),
    Default = State.SelectedQuirks or { "Fortune's Favor", "Midas Touch", "Prodigy", "Tycoon", "Fortune III" },
    Callback = function(selected)
        State.SelectedQuirks = selected
        SaveConfigDebounced()
    end
}, "Dropdown_QuirkTargets")

HubSections.Quirks:Button({
    Name = "Refresh List",
    Callback = function()
        pcall(function()
            RefreshDropdownPreservingSelection(QuirkUnitsDropdown, GetAvailableUnitOptions, State.SelectedQuirkUnits, true)
            RefreshDropdownPreservingSelection(QuirkTargetsDropdown, GetDynamicQuirkOptions, State.SelectedQuirks, false)
        end)
    end
})


-- 9.6. HUB TAB: AUTO GRADES
HubSections.Grades:Header({ Text = "Auto Grades" })

HubSections.Grades:Toggle({
    Name = "Auto Grades",
    Default = (State.AutoGrades == true),
    Callback = function(v)
        State.AutoGrades = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoGrades")

local GradeUnitsDropdown = HubSections.Grades:Dropdown({
    Name = "Select Unit",
    Multi = true,
    Required = false,
    Options = GetAvailableUnitOptions(),
    Default = State.SelectedGradeUnits or {},
    Callback = function(selected)
        State.SelectedGradeUnits = selected
        SaveConfigDebounced()
    end
}, "Dropdown_GradeUnits")

local GradeTargetsDropdown = HubSections.Grades:Dropdown({
    Name = "Select Grades",
    Multi = true,
    Required = false,
    Options = GetDynamicGradeOptions(),
    Default = State.SelectedGrades or { "Ω", "∞", "神", "Z+", "Z" },
    Callback = function(selected)
        State.SelectedGrades = selected
        SaveConfigDebounced()
    end
}, "Dropdown_GradeTargets")

HubSections.Grades:Button({
    Name = "Refresh List",
    Callback = function()
        pcall(function()
            RefreshDropdownPreservingSelection(GradeUnitsDropdown, GetAvailableUnitOptions, State.SelectedGradeUnits, true)
            RefreshDropdownPreservingSelection(GradeTargetsDropdown, GetDynamicGradeOptions, State.SelectedGrades, false)
        end)
    end
})


-- 9.7. HUB TAB: AUTO TRAITS
HubSections.Traits:Header({ Text = "Auto Traits" })

HubSections.Traits:Toggle({
    Name = "Auto Traits",
    Default = (State.AutoTraits == true),
    Callback = function(v)
        State.AutoTraits = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoTraits")

local TraitUnitsDropdown = HubSections.Traits:Dropdown({
    Name = "Select Unit",
    Multi = true,
    Required = false,
    Options = GetAvailableUnitOptions(),
    Default = State.SelectedTraitUnits or {},
    Callback = function(selected)
        State.SelectedTraitUnits = selected
        SaveConfigDebounced()
    end
}, "Dropdown_TraitUnits")

local TraitTargetsDropdown = HubSections.Traits:Dropdown({
    Name = "Select Traits",
    Multi = true,
    Required = false,
    Options = GetDynamicTraitOptions(),
    Default = State.SelectedTraits or { "Genesis", "Paradox", "Eternal", "Transcendent", "Monarch" },
    Callback = function(selected)
        State.SelectedTraits = selected
        SaveConfigDebounced()
    end
}, "Dropdown_TraitTargets")

HubSections.Traits:Button({
    Name = "Refresh List",
    Callback = function()
        pcall(function()
            RefreshDropdownPreservingSelection(TraitUnitsDropdown, GetAvailableUnitOptions, State.SelectedTraitUnits, true)
            RefreshDropdownPreservingSelection(TraitTargetsDropdown, GetDynamicTraitOptions, State.SelectedTraits, false)
        end)
    end
})


-- ==============================================================================
-- 10. STATS & CODES TAB
-- ==============================================================================
StatsSections.Left:Header({ Text = "Live Player Statistics" })

local StatRollsLabel = StatsSections.Left:Label({ Text = "Total Rolls: Loading..." })
local StatMoneyLabel = StatsSections.Left:Label({ Text = "Total Money: Loading..." })
local StatMoneyRateLabel = StatsSections.Left:Label({ Text = "Money / Sec: Loading..." })
local StatLuckLabel = StatsSections.Left:Label({ Text = "Luck Multiplier: Loading..." })
local StatDurationLabel = StatsSections.Left:Label({ Text = "Roll Duration: Loading..." })
local StatDiceLabel = StatsSections.Left:Label({ Text = "Equipped Dice: Loading..." })

StatsSections.Right:Header({ Text = "Active Codes" })

local activeCodes = {
    "RELEASE",
    "MORELUCK",
    "UPDATE8",
    "ANIME",
    "DICE"
}

StatsSections.Right:Button({
    Name = "Redeem Popular Codes",
    Callback = function()
        if RedeemCodeRE then
            for _, code in ipairs(activeCodes) do
                pcall(function() RedeemCodeRE:FireServer(code) end)
                task.wait(0.3)
            end
        end
    end
})

-- ==============================================================================
-- 11. UNIVERSAL SETTINGS TAB
-- ==============================================================================
SettingsSections.Controls:Header({ Text = "Interface Controls" })

SettingsSections.Controls:Toggle({
    Name = "Acrylic Blur Background",
    Default = (State.AcrylicBlur == true),
    Callback = function(v)
        State.AcrylicBlur = v
        if Window and Window.SetAcrylicBlurState then Window:SetAcrylicBlurState(v) end
        SaveConfigDebounced()
    end
}, "Toggle_AcrylicBlur")

SettingsSections.Controls:Toggle({
    Name = "Show User Information",
    Default = (State.ShowUserInfo ~= false),
    Callback = function(v)
        State.ShowUserInfo = v
        if Window and Window.SetUserInfoState then Window:SetUserInfoState(v) end
        SaveConfigDebounced()
    end
}, "Toggle_ShowUserInfo")

SettingsSections.Controls:Toggle({
    Name = "Mobile Floating Button",
    Default = (State.MobileToggle ~= false),
    Callback = function(v)
        State.MobileToggle = v
        if getgenv().STRIX_MOBILE_GUI then getgenv().STRIX_MOBILE_GUI.Enabled = v end
        SaveConfigDebounced()
    end
}, "Toggle_MobileToggle")

SettingsSections.Controls:Keybind({
    Name = "Open/Hide Keybind",
    Blacklist = false,
    Default = (State.Keybind and State.Keybind ~= Enum.KeyCode.Unknown) and State.Keybind or Enum.KeyCode.RightControl,
    Callback = function(binded)
        State.Keybind = binded
        if Window and Window.SetKeybind then Window:SetKeybind(binded) end
        SaveConfigDebounced()
    end
}, "Keybind_ToggleUI")

SettingsSections.Config:Header({ Text = "Config Manager" })
SettingsSections.Config:Label({ Text = "Auto Save: Active (Realtime)" })
SettingsSections.Config:Label({ Text = "File: workspace\\" .. ConfigFile })

SettingsSections.Config:Button({
    Name = "Save Config Now",
    Callback = function()
        SaveConfig()
    end
})

SettingsSections.Config:Button({
    Name = "Reload Config",
    Callback = function()
        if LoadConfig then
            LoadConfig()
        end
    end
})

SettingsSections.Config:Divider()
SettingsSections.Config:Header({ Text = "Hub Management" })

SettingsSections.Config:Button({
    Name = "Unload STRIX HUB",
    Callback = function()
        pcall(function()
            if getgenv().STRIX_HUB_CLEANUP then pcall(getgenv().STRIX_HUB_CLEANUP) end
            if Window and Window.Unload then Window:Unload() end
            if getgenv().STRIX_MOBILE_GUI then pcall(function() getgenv().STRIX_MOBILE_GUI:Destroy() end) end
        end)
    end
})

-- ==============================================================================
-- 11.5 CONFIG LOADER (Applies saved settings to live UI components)
-- ==============================================================================
LoadConfig = function()
    if isLoadingConfig then return end
    isLoadingConfig = true
    EnsureFolders()

    local okMain, mainErr = pcall(function()
        if not (isfile and isfile(ConfigFile)) then return end
        local content = readfile(ConfigFile)
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not (ok and type(data) == "table") then return end

        -- 1. Auto Roll
        if data.AutoRoll ~= nil then
            State.AutoRoll = (data.AutoRoll == true)
            if MacLib.Options["Toggle_AutoRoll"] then
                pcall(function() MacLib.Options["Toggle_AutoRoll"]:UpdateState(State.AutoRoll) end)
            end
        end

        -- 2. Dice Automation
        if data.AutoBuyDice ~= nil then
            State.AutoBuyDice = (data.AutoBuyDice == true)
            if MacLib.Options["Toggle_AutoBuyDice"] then
                pcall(function() MacLib.Options["Toggle_AutoBuyDice"]:UpdateState(State.AutoBuyDice) end)
            end
        end
        if data.AutoEquipBestDice ~= nil then
            State.AutoEquipBestDice = (data.AutoEquipBestDice == true)
            if MacLib.Options["Toggle_AutoEquipBestDice"] then
                pcall(function() MacLib.Options["Toggle_AutoEquipBestDice"]:UpdateState(State.AutoEquipBestDice) end)
            end
        end
        if data.AutoRebirth ~= nil then
            State.AutoRebirth = (data.AutoRebirth == true)
            if MacLib.Options["Toggle_AutoRebirth"] then
                pcall(function() MacLib.Options["Toggle_AutoRebirth"]:UpdateState(State.AutoRebirth) end)
            end
        end
        if data.AutoUpgrades ~= nil then
            State.AutoUpgrades = (data.AutoUpgrades == true)
            if MacLib.Options["Toggle_AutoUpgrades"] then
                pcall(function() MacLib.Options["Toggle_AutoUpgrades"]:UpdateState(State.AutoUpgrades) end)
            end
        end
        if data.AutoClaimQuests ~= nil then
            State.AutoClaimQuests = (data.AutoClaimQuests == true)
            if MacLib.Options["Toggle_AutoClaimQuests"] then
                pcall(function() MacLib.Options["Toggle_AutoClaimQuests"]:UpdateState(State.AutoClaimQuests) end)
            end
        end
        if data.AutoClaimDailyReward ~= nil then
            State.AutoClaimDailyReward = (data.AutoClaimDailyReward == true)
            if MacLib.Options["Toggle_AutoClaimDailyReward"] then
                pcall(function() MacLib.Options["Toggle_AutoClaimDailyReward"]:UpdateState(State.AutoClaimDailyReward) end)
            end
        end
        if data.AutoQuirks ~= nil then
            State.AutoQuirks = (data.AutoQuirks == true)
            if MacLib.Options["Toggle_AutoQuirks"] then
                pcall(function() MacLib.Options["Toggle_AutoQuirks"]:UpdateState(State.AutoQuirks) end)
            end
        end
        if data.SelectedQuirkUnits ~= nil and type(data.SelectedQuirkUnits) == "table" and MacLib.Options["Dropdown_QuirkUnits"] then
            State.SelectedQuirkUnits = data.SelectedQuirkUnits
            pcall(function() MacLib.Options["Dropdown_QuirkUnits"]:UpdateSelection(NormalizeSelectionList(State.SelectedQuirkUnits)) end)
        end
        if data.SelectedQuirks ~= nil and type(data.SelectedQuirks) == "table" and MacLib.Options["Dropdown_QuirkTargets"] then
            State.SelectedQuirks = data.SelectedQuirks
            pcall(function() MacLib.Options["Dropdown_QuirkTargets"]:UpdateSelection(NormalizeSelectionList(State.SelectedQuirks)) end)
        end
        if data.AutoGrades ~= nil then
            State.AutoGrades = (data.AutoGrades == true)
            if MacLib.Options["Toggle_AutoGrades"] then
                pcall(function() MacLib.Options["Toggle_AutoGrades"]:UpdateState(State.AutoGrades) end)
            end
        end
        if data.SelectedGradeUnits ~= nil and type(data.SelectedGradeUnits) == "table" and MacLib.Options["Dropdown_GradeUnits"] then
            State.SelectedGradeUnits = data.SelectedGradeUnits
            pcall(function() MacLib.Options["Dropdown_GradeUnits"]:UpdateSelection(NormalizeSelectionList(State.SelectedGradeUnits)) end)
        end
        if data.SelectedGrades ~= nil and type(data.SelectedGrades) == "table" and MacLib.Options["Dropdown_GradeTargets"] then
            State.SelectedGrades = data.SelectedGrades
            pcall(function() MacLib.Options["Dropdown_GradeTargets"]:UpdateSelection(NormalizeSelectionList(State.SelectedGrades)) end)
        end
        if data.AutoTraits ~= nil then
            State.AutoTraits = (data.AutoTraits == true)
            if MacLib.Options["Toggle_AutoTraits"] then
                pcall(function() MacLib.Options["Toggle_AutoTraits"]:UpdateState(State.AutoTraits) end)
            end
        end
        if data.SelectedTraitUnits ~= nil and type(data.SelectedTraitUnits) == "table" and MacLib.Options["Dropdown_TraitUnits"] then
            State.SelectedTraitUnits = data.SelectedTraitUnits
            pcall(function() MacLib.Options["Dropdown_TraitUnits"]:UpdateSelection(NormalizeSelectionList(State.SelectedTraitUnits)) end)
        end
        if data.SelectedTraits ~= nil and type(data.SelectedTraits) == "table" and MacLib.Options["Dropdown_TraitTargets"] then
            State.SelectedTraits = data.SelectedTraits
            pcall(function() MacLib.Options["Dropdown_TraitTargets"]:UpdateSelection(NormalizeSelectionList(State.SelectedTraits)) end)
        end

        -- 2.5 Potions & Boosts
        if data.AutoUsePotions ~= nil and MacLib.Options["Toggle_AutoUsePotions"] then
            State.AutoUsePotions = (data.AutoUsePotions == true)
            pcall(function() MacLib.Options["Toggle_AutoUsePotions"]:UpdateState(State.AutoUsePotions) end)
        end
        if data.AutoUsePotionTypes ~= nil and type(data.AutoUsePotionTypes) == "table" and MacLib.Options["Dropdown_AutoUsePotionTypes"] then
            State.AutoUsePotionTypes = data.AutoUsePotionTypes
            pcall(function() MacLib.Options["Dropdown_AutoUsePotionTypes"]:UpdateSelection(State.AutoUsePotionTypes) end)
        end
        if data.AutoUsePotionMode ~= nil and MacLib.Options["Dropdown_AutoUsePotionMode"] then
            State.AutoUsePotionMode = tostring(data.AutoUsePotionMode)
            pcall(function() MacLib.Options["Dropdown_AutoUsePotionMode"]:UpdateSelection(State.AutoUsePotionMode) end)
        end

        -- 3. Auto Sell
        if data.AutoSellEnabled ~= nil and MacLib.Options["Toggle_AutoSellEnabled"] then
            State.AutoSellEnabled = (data.AutoSellEnabled == true)
            pcall(function() MacLib.Options["Toggle_AutoSellEnabled"]:UpdateState(State.AutoSellEnabled) end)
        end
        if data.AutoSellNumber ~= nil and MacLib.Options["Input_AutoSellNumber"] then
            State.AutoSellNumber = tostring(data.AutoSellNumber)
            pcall(function() MacLib.Options["Input_AutoSellNumber"]:UpdateText(State.AutoSellNumber) end)
        end
        if data.AutoSellUnit ~= nil and MacLib.Options["Dropdown_AutoSellUnit"] then
            State.AutoSellUnit = tostring(data.AutoSellUnit)
            pcall(function() MacLib.Options["Dropdown_AutoSellUnit"]:UpdateSelection(State.AutoSellUnit) end)
        end
        if data.AutoSellValue ~= nil then
            State.AutoSellValue = tonumber(data.AutoSellValue) or 0
        end
        if ApplyAutoSell then
            pcall(function()
                if State.AutoSellEnabled then
                    ApplyAutoSell(CalculateAutoSellValue())
                else
                    ApplyAutoSell(0)
                end
            end)
        end

        -- 4. Plots & Units
        if data.AutoCollectPlot ~= nil then
            State.AutoCollectPlot = (data.AutoCollectPlot == true)
            if MacLib.Options["Toggle_AutoCollectPlot"] then
                pcall(function() MacLib.Options["Toggle_AutoCollectPlot"]:UpdateState(State.AutoCollectPlot) end)
            end
        end
        if data.CollectInterval then
            State.CollectInterval = tonumber(data.CollectInterval) or 5
            if MacLib.Options["Input_CollectInterval"] then
                pcall(function() MacLib.Options["Input_CollectInterval"]:UpdateText(tostring(State.CollectInterval)) end)
            elseif MacLib.Options["Slider_CollectInterval"] then
                pcall(function() MacLib.Options["Slider_CollectInterval"]:UpdateValue(State.CollectInterval) end)
            end
        end
        if data.AutoEquipBest ~= nil then
            State.AutoEquipBest = (data.AutoEquipBest == true)
            if MacLib.Options["Toggle_AutoEquipBest"] then
                pcall(function() MacLib.Options["Toggle_AutoEquipBest"]:UpdateState(State.AutoEquipBest) end)
            end
        end
        if data.EquipBestInterval then
            State.EquipBestInterval = tonumber(data.EquipBestInterval) or 15
            if MacLib.Options["Input_EquipBestInterval"] then
                pcall(function() MacLib.Options["Input_EquipBestInterval"]:UpdateText(tostring(State.EquipBestInterval)) end)
            elseif MacLib.Options["Slider_EquipBestInterval"] then
                pcall(function() MacLib.Options["Slider_EquipBestInterval"]:UpdateValue(State.EquipBestInterval) end)
            end
        end

        -- 5. Interface Settings & Keybind
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

        if data.AcrylicBlur ~= nil and MacLib.Options["Toggle_AcrylicBlur"] then
            State.AcrylicBlur = (data.AcrylicBlur == true)
            pcall(function()
                MacLib.Options["Toggle_AcrylicBlur"]:UpdateState(State.AcrylicBlur)
                if Window and Window.SetAcrylicBlurState then
                    Window:SetAcrylicBlurState(State.AcrylicBlur)
                end
            end)
        end

        if data.ShowUserInfo ~= nil and MacLib.Options["Toggle_ShowUserInfo"] then
            State.ShowUserInfo = (data.ShowUserInfo ~= false)
            pcall(function()
                MacLib.Options["Toggle_ShowUserInfo"]:UpdateState(State.ShowUserInfo)
                if Window and Window.SetUserInfoState then
                    Window:SetUserInfoState(State.ShowUserInfo)
                end
            end)
        end

        if data.MobileToggle ~= nil and MacLib.Options["Toggle_MobileToggle"] then
            State.MobileToggle = (data.MobileToggle ~= false)
            pcall(function()
                MacLib.Options["Toggle_MobileToggle"]:UpdateState(State.MobileToggle)
                if getgenv().STRIX_MOBILE_GUI then
                    getgenv().STRIX_MOBILE_GUI.Enabled = State.MobileToggle
                end
            end)
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
    end)

    if not okMain and mainErr then
        warn("[STRIX HUB] LoadConfig error: " .. tostring(mainErr))
    end
    isLoadingConfig = false
end

-- Initialize saved config values onto UI
LoadConfig()

-- ==============================================================================
-- 12. BACKGROUND WORKERS & AUTOMATION LOOPS
-- ==============================================================================

-- Worker 1: Auto Roll Loop (Fastest)
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoRoll and RollDiceRF then
            pcall(function()
                return RollDiceRF:InvokeServer()
            end)
        end
        task.wait(0.05)
    end
end)

-- Worker: Dice Automation Loop (Auto Buy & Auto Equip Best)
SpawnTracked(function()
    while isScriptRunning do
        -- 1. Auto Buy Dice Shop
        if State.AutoBuyDice and BuyDiceRE and DataController and Dice then
            pcall(function()
                local money = DataController.Money and DataController.Money() or 0
                local owned = DataController.OwnedDice and DataController.OwnedDice() or {}
                local allDice = Dice.GetAll and Dice.GetAll() or {}

                local affordableList = {}
                for diceName, info in pairs(allDice) do
                    if not owned[diceName] and info.price and money >= info.price then
                        table.insert(affordableList, {name = diceName, price = info.price, luck = info.luck or 0})
                    end
                end

                if #affordableList > 0 then
                    table.sort(affordableList, function(a, b) return a.price < b.price end)
                    BuyDiceRE:FireServer(affordableList[1].name)
                end
            end)
        end

        -- 2. Auto Equip Best Dice
        if State.AutoEquipBestDice and EquipDiceRE and DataController and Dice then
            pcall(function()
                local owned = DataController.OwnedDice and DataController.OwnedDice() or {}
                local currentDice = DataController.Dice and DataController.Dice() or ""
                local allDice = Dice.GetAll and Dice.GetAll() or {}

                local bestDice = nil
                local bestLuck = -1

                for diceName, isOwned in pairs(owned) do
                    if isOwned == true then
                        local info = allDice[diceName] or (Dice.Get and Dice.Get(diceName))
                        local luck = info and info.luck or 0
                        if luck > bestLuck then
                            bestLuck = luck
                            bestDice = diceName
                        end
                    end
                end

                if bestDice and bestDice ~= currentDice then
                    EquipDiceRE:FireServer(bestDice)
                end
            end)
        end

        task.wait(1)
    end
end)

-- Worker: Potions & Boosts Automation Loop
local lastPotionStatusText = nil
SpawnTracked(function()
    while isScriptRunning do
        pcall(function()
            local activeBoosts = GetActiveBoosts()
            local activeCount = 0
            for _ in pairs(activeBoosts) do
                activeCount = activeCount + 1
            end

            if PotionStatusLabel then
                local newStatus = (activeCount > 0) and string.format("Active Boosts: %d active", activeCount) or "Active Boosts: None"
                if newStatus ~= lastPotionStatusText then
                    lastPotionStatusText = newStatus
                    UpdateLabel(PotionStatusLabel, newStatus)
                end
            end

            if State.AutoUsePotions and UseBoostRE and DataController and EntryRegistry then
                local inv = DataController.Inventory and DataController.Inventory() or {}
                local availableBoosts = {}
                for k, v in pairs(inv) do
                    if type(v) == "table" and (v.amount or 0) > 0 then
                        local cfg = EntryRegistry.getEntryConfig(v.name)
                        if cfg and cfg.kind == "Boost" then
                            table.insert(availableBoosts, {
                                key = k,
                                name = v.name,
                                amount = v.amount,
                                category = cfg.category or "Unknown",
                                tier = cfg.tier or 1,
                                duration = cfg.duration or 300
                            })
                        end
                    end
                end

                if #availableBoosts > 0 then
                    local categoryGroups = {}
                    for _, b in ipairs(availableBoosts) do
                        if not categoryGroups[b.category] then
                            categoryGroups[b.category] = {}
                        end
                        table.insert(categoryGroups[b.category], b)
                    end

                    local mode = State.AutoUsePotionMode or "Keep Active"

                    for cat, boostsInCat in pairs(categoryGroups) do
                        -- Sort highest tier first
                        table.sort(boostsInCat, function(a, b)
                            return (a.tier or 0) > (b.tier or 0)
                        end)

                        if mode == "Stack All" then
                            for _, item in ipairs(boostsInCat) do
                                local amt = item.amount or 1
                                for _ = 1, amt do
                                    UseBoostRE:FireServer(item.key)
                                    task.wait(0.015)
                                end
                            end
                        elseif mode == "Keep Active" then
                            -- Find currently active buff for this category on screen
                            local activeCatItem = nil
                            for _, act in pairs(activeBoosts) do
                                local actCfg = EntryRegistry.getEntryConfig(act.name)
                                if actCfg and actCfg.category == cat then
                                    if not activeCatItem or (act.remaining or 0) > (activeCatItem.remaining or 0) then
                                        activeCatItem = act
                                    end
                                end
                            end

                            local activeTier = activeCatItem and activeCatItem.tier or 0
                            local activeRemaining = activeCatItem and (activeCatItem.remaining or 0) or 0
                            local isCategoryActive = (activeRemaining > 10)

                            if not isCategoryActive then
                                -- Category has no active timer (or <= 10s left):
                                -- Use ONLY 1 bottle of highest tier available to start/refresh countdown
                                local best = boostsInCat[1]
                                if best then
                                    UseBoostRE:FireServer(best.key)
                                    task.wait(0.05)
                                end
                            elseif boostsInCat[1] and (boostsInCat[1].tier or 0) > activeTier then
                                -- Inventory has a HIGHER tier than what is currently active!
                                -- Use ONLY 1 bottle to upgrade the buff to higher tier
                                UseBoostRE:FireServer(boostsInCat[1].key)
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end
        end)
        local sleepTime = (State.AutoUsePotions and State.AutoUsePotionMode == "Stack All") and 0.35 or 1.2
        task.wait(sleepTime)
    end
end)

-- Worker 2: Auto Collect Plot Income Loop
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoCollectPlot and CollectBalanceRE and DataController and DataController.Slots then
            pcall(function()
                local slots = DataController.Slots()
                for slotKey, _ in pairs(slots) do
                    local idx = tonumber(slotKey)
                    if idx then
                        CollectBalanceRE:FireServer(idx)
                    end
                end
            end)
        end
        local waitSec = math.max(State.CollectInterval or 5, 1)
        task.wait(waitSec)
    end
end)

-- Worker 3: Auto Equip Best Units Loop
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoEquipBest then
            pcall(function()
                EquipBestSorted(false)
            end)
        end
        local waitSec = math.max(State.EquipBestInterval or 15, 3)
        task.wait(waitSec)
    end
end)

-- Worker 3.5: Auto Upgrade Plot Loop (Strict ascending order from Slot 1 to last slot up to PlotTargetLevel)
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoUpgradePlot and LevelUpSlotRE and DataController and DataController.Slots and DataController.Inventory then
            pcall(function()
                local slots = DataController.Slots()
                local inventory = DataController.Inventory()
                local targetLevel = tonumber(State.PlotTargetLevel) or 100

                local slotNumbers = {}
                for slotKey, _ in pairs(slots) do
                    local num = tonumber(slotKey)
                    if num then
                        table.insert(slotNumbers, num)
                    end
                end
                table.sort(slotNumbers)

                local didUpgrade = false
                for _, slotIdx in ipairs(slotNumbers) do
                    local slotData = slots[tostring(slotIdx)] or slots[slotIdx]
                    local uId = slotData and slotData.unitId
                    local uItem = uId and inventory[uId]
                    if uItem and uItem.attributes then
                        local currentLevel = uItem.attributes.level or 1
                        if currentLevel < targetLevel then
                            local price = 0
                            if UnitUtil and UnitUtil.GetLevelPrice then
                                pcall(function()
                                    price = UnitUtil.GetLevelPrice(uItem.name, uItem.attributes)
                                end)
                            elseif EntryRegistry then
                                pcall(function()
                                    local cfg = EntryRegistry.getEntryConfig(uItem.name)
                                    if cfg and cfg.income then
                                        price = math.floor(cfg.income({ mutation = uItem.attributes.mutation }) * 1.6 ^ ((uItem.attributes.level or 1) - 1))
                                    end
                                end)
                            end

                            local currentMoney = DataController.Money and DataController.Money() or 0
                            if currentMoney >= price and price > 0 then
                                LevelUpSlotRE:FireServer(slotIdx)
                                didUpgrade = true
                                task.wait(0.12)
                            else
                                task.wait(0.5)
                            end
                            -- Enforce strict ascending order: Slot 1 must reach targetLevel before Slot 2
                            break
                        end
                    end
                end

                if not didUpgrade then
                    task.wait(0.5)
                end
            end)
        else
            task.wait(1)
        end
        task.wait(0.05)
    end
end)

-- Worker 3.6: Auto Rebirth Loop
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoRebirth and RebirthRE and DataController and Rebirths then
            pcall(function()
                local rebirth = DataController.Rebirth and DataController.Rebirth() or 0
                local nextRebirth = Rebirths.GetNext(rebirth)
                if nextRebirth and nextRebirth.cost then
                    local money = DataController.Money and DataController.Money() or 0
                    if money >= nextRebirth.cost then
                        RebirthRE:FireServer()
                        task.wait(0.6)
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

-- Worker 3.7: Auto Upgrades Loop
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoUpgrades and BuyUpgradeRE and DataController and UpgradesConfig and TreeStructure then
            pcall(function()
                local ownedUpgrades = DataController.Upgrades and DataController.Upgrades() or {}
                local money = DataController.Money and DataController.Money() or 0

                local buyable = {}
                for name, data in pairs(UpgradesConfig) do
                    if not ownedUpgrades[name] and name ~= "Start" then
                        local parent = TreeStructure.GetParent(name)
                        if not parent or parent == "Start" or ownedUpgrades[parent] then
                            if money >= data.price then
                                table.insert(buyable, { name = name, price = data.price })
                            end
                        end
                    end
                end

                table.sort(buyable, function(a, b) return a.price < b.price end)

                for _, upg in ipairs(buyable) do
                    local currentMoney = DataController.Money and DataController.Money() or 0
                    if currentMoney >= upg.price then
                        BuyUpgradeRE:FireServer(upg.name)
                        task.wait(0.12)
                    end
                end
            end)
        end
        task.wait(1.5)
    end
end)

-- Worker 3.8: Auto Claim Quests Loop (Daily/Weekly)
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoClaimQuests and ClaimQuestRE and DataController and QuestConfig and QuestConfig.Periods then
            pcall(function()
                for _, period in ipairs({ "Daily", "Weekly" }) do
                    local pConfig = QuestConfig.Periods[period]
                    local pData = DataController.Quests and DataController.Quests[period] and DataController.Quests[period]()
                    if pConfig and pData and pData.expiresAt and pData.expiresAt > 0 and pData.expiresAt > os.time() then
                        local progress = pData.progress or {}
                        local claimed = pData.claimed or {}
                        for _, q in ipairs(pConfig.quests) do
                            local curProg = progress[q.id] or 0
                            local isClaimed = claimed[q.id] == true
                            if not isClaimed and curProg >= q.target then
                                ClaimQuestRE:FireServer(period, q.id, pData.expiresAt)
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(2)
    end
end)

-- Worker 3.9: Auto Claim Daily Reward Loop
SpawnTracked(function()
    while isScriptRunning do
        if State.AutoClaimDailyReward and ClaimDailyRewardRE and DataController then
            pcall(function()
                local last = DataController.LastDailyRewardClaim and DataController.LastDailyRewardClaim() or 0
                local cooldown = (DailyRewardConfig and DailyRewardConfig.Cooldown) or 82800
                local remaining = (last ~= 0) and math.max(0, cooldown - (os.time() - last)) or 0
                if remaining <= 0 then
                    ClaimDailyRewardRE:FireServer()
                    task.wait(1)
                end
            end)
        end
        task.wait(3)
    end
end)

-- Worker 3.10: Auto Quirks Loop (Maximum possible speed without server rejection)
SpawnTracked(function()
    local QUIRK_ROLL_DELAY = 0.202 -- Server debounce is strictly 0.20s (DebounceUtil.Try)

    while isScriptRunning do
        if State.AutoQuirks and RollQuirkRE and DataController and QuirkUtil then
            pcall(function()
                local targetQuirksMap = GetSelectedQuirksMap(State.SelectedQuirks)
                if not next(targetQuirksMap) then
                    State.AutoQuirks = false
                    if MacLib.Options["Toggle_AutoQuirks"] then
                        pcall(function() MacLib.Options["Toggle_AutoQuirks"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Quirks",
                                Description = "No target quirks selected!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local targetUnitIds = ResolveSelectedUnitIds(State.SelectedQuirkUnits)
                if not next(targetUnitIds) then
                    State.AutoQuirks = false
                    if MacLib.Options["Toggle_AutoQuirks"] then
                        pcall(function() MacLib.Options["Toggle_AutoQuirks"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Quirks",
                                Description = "No units selected to roll quirks for!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local inv = DataController.Inventory and DataController.Inventory() or {}
                local currentMoney = DataController.Money and DataController.Money() or 0

                -- Find all units that still need a target quirk
                local pendingUnits = {}
                for unitId, _ in pairs(targetUnitIds) do
                    local unitItem = inv[unitId]
                    if unitItem and unitItem.attributes then
                        local curQuirk = unitItem.attributes.quirk or "None"
                        if not targetQuirksMap[curQuirk] then
                            table.insert(pendingUnits, unitId)
                        end
                    end
                end

                if #pendingUnits == 0 then
                    -- All selected units already acquired a target quirk!
                    if isScriptRunning and State.AutoQuirks then
                        State.AutoQuirks = false
                        if MacLib.Options["Toggle_AutoQuirks"] then
                            pcall(function() MacLib.Options["Toggle_AutoQuirks"]:UpdateState(false) end)
                        end
                        SaveConfigDebounced()
                        if Window and Window.Notify then
                            pcall(function()
                                Window:Notify({
                                    Title = "Auto Quirks",
                                    Description = "All selected units have acquired target quirks!",
                                    Lifetime = 4
                                })
                            end)
                        end
                    end
                    task.wait(0.5)
                    return
                end

                -- Purely Sequential: Focus continuous rolls on the first pending unit until it succeeds, then advance
                local activeUnitId = pendingUnits[1]
                local unitItem = inv[activeUnitId]
                if unitItem and unitItem.attributes then
                    local cost = QuirkUtil.GetRollCost(unitItem.name, unitItem.attributes) or 0
                    if currentMoney >= cost then
                        RollQuirkRE:FireServer(activeUnitId, true)
                        task.wait(QUIRK_ROLL_DELAY)
                    else
                        task.wait(0.5)
                    end
                else
                    task.wait(0.1)
                end
            end)
        else
            task.wait(0.5)
        end
    end
end)

-- Worker 3.11: Auto Grades Loop (Maximum possible speed without server rejection)
SpawnTracked(function()
    local GRADE_ROLL_DELAY = 0.252 -- Server debounce is strictly 0.25s (DebounceUtil.Try)

    while isScriptRunning do
        if State.AutoGrades and RollGradeRE and DataController then
            pcall(function()
                local targetGradesMap = GetSelectedGradesMap(State.SelectedGrades)
                if not next(targetGradesMap) then
                    State.AutoGrades = false
                    if MacLib.Options["Toggle_AutoGrades"] then
                        pcall(function() MacLib.Options["Toggle_AutoGrades"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Grades",
                                Description = "No target grades selected!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local targetUnitIds = ResolveSelectedUnitIds(State.SelectedGradeUnits)
                if not next(targetUnitIds) then
                    State.AutoGrades = false
                    if MacLib.Options["Toggle_AutoGrades"] then
                        pcall(function() MacLib.Options["Toggle_AutoGrades"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Grades",
                                Description = "No units selected to roll grades for!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local inv = DataController.Inventory and DataController.Inventory() or {}

                -- Verify currency: Grade rolls cost Gems (inv item where name == "Gems" or name == "Gem")
                local gemsAmount = 0
                for _, item in pairs(inv) do
                    if item and (item.name == "Gems" or item.name == "Gem") then
                        gemsAmount = item.amount or 0
                        break
                    end
                end

                if gemsAmount < 1 then
                    State.AutoGrades = false
                    if MacLib.Options["Toggle_AutoGrades"] then
                        pcall(function() MacLib.Options["Toggle_AutoGrades"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Grades",
                                Description = "You don't have any gems left to roll grades!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                -- Identify units that haven't reached target grade yet
                local pendingUnits = {}
                for unitId, _ in pairs(targetUnitIds) do
                    local unitItem = inv[unitId]
                    if unitItem and unitItem.attributes then
                        local curGrade = unitItem.attributes.grade or "None"
                        if not targetGradesMap[curGrade] then
                            table.insert(pendingUnits, unitId)
                        end
                    end
                end

                -- If all selected units have reached their target grades, shut off
                if #pendingUnits == 0 then
                    if isScriptRunning and State.AutoGrades then
                        State.AutoGrades = false
                        if MacLib.Options["Toggle_AutoGrades"] then
                            pcall(function() MacLib.Options["Toggle_AutoGrades"]:UpdateState(false) end)
                        end
                        SaveConfigDebounced()
                        if Window and Window.Notify then
                            pcall(function()
                                Window:Notify({
                                    Title = "Auto Grades",
                                    Description = "All selected units have acquired target grades!",
                                    Lifetime = 4
                                })
                            end)
                        end
                    end
                    task.wait(0.5)
                    return
                end

                -- Purely Sequential: Focus rolls on the first pending unit until it reaches a target grade
                local activeUnitId = pendingUnits[1]
                local unitItem = inv[activeUnitId]
                if unitItem and unitItem.attributes then
                    RollGradeRE:FireServer(activeUnitId, true)
                    task.wait(GRADE_ROLL_DELAY)
                else
                    task.wait(0.1)
                end
            end)
        else
            task.wait(0.5)
        end
    end
end)

-- Worker 3.12: Auto Traits Loop (Maximum possible speed without server rejection)
SpawnTracked(function()
    local TRAIT_ROLL_DELAY = 0.252 -- Server debounce is strictly 0.25s (DebounceUtil.Try)

    while isScriptRunning do
        if State.AutoTraits and RollTraitRE and DataController then
            pcall(function()
                local targetTraitsMap = GetSelectedTraitsMap(State.SelectedTraits)
                if not next(targetTraitsMap) then
                    State.AutoTraits = false
                    if MacLib.Options["Toggle_AutoTraits"] then
                        pcall(function() MacLib.Options["Toggle_AutoTraits"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Traits",
                                Description = "No target traits selected!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local targetUnitIds = ResolveSelectedUnitIds(State.SelectedTraitUnits)
                if not next(targetUnitIds) then
                    State.AutoTraits = false
                    if MacLib.Options["Toggle_AutoTraits"] then
                        pcall(function() MacLib.Options["Toggle_AutoTraits"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Traits",
                                Description = "No units selected to roll traits for!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                local inv = DataController.Inventory and DataController.Inventory() or {}

                -- Verify currency: Trait rolls cost "Trait Reroll" item
                local traitRerolls = 0
                if inv["Trait Reroll"] and inv["Trait Reroll"].amount then
                    traitRerolls = tonumber(inv["Trait Reroll"].amount) or 0
                else
                    for _, item in pairs(inv) do
                        if item and item.name == "Trait Reroll" then
                            traitRerolls = traitRerolls + (tonumber(item.amount) or 1)
                        end
                    end
                end

                if traitRerolls < 1 then
                    State.AutoTraits = false
                    if MacLib.Options["Toggle_AutoTraits"] then
                        pcall(function() MacLib.Options["Toggle_AutoTraits"]:UpdateState(false) end)
                    end
                    SaveConfigDebounced()
                    if Window and Window.Notify then
                        pcall(function()
                            Window:Notify({
                                Title = "Auto Traits",
                                Description = "You don't have any Trait Rerolls left!",
                                Lifetime = 3
                            })
                        end)
                    end
                    task.wait(0.5)
                    return
                end

                -- Identify units that haven't reached target trait yet
                local pendingUnits = {}
                for unitId, _ in pairs(targetUnitIds) do
                    local unitItem = inv[unitId]
                    if unitItem and unitItem.attributes then
                        local curTrait = unitItem.attributes.trait or "None"
                        if not targetTraitsMap[curTrait] then
                            table.insert(pendingUnits, unitId)
                        end
                    end
                end

                -- If all selected units have reached target traits, shut off
                if #pendingUnits == 0 then
                    if isScriptRunning and State.AutoTraits then
                        State.AutoTraits = false
                        if MacLib.Options["Toggle_AutoTraits"] then
                            pcall(function() MacLib.Options["Toggle_AutoTraits"]:UpdateState(false) end)
                        end
                        SaveConfigDebounced()
                        if Window and Window.Notify then
                            pcall(function()
                                Window:Notify({
                                    Title = "Auto Traits",
                                    Description = "All selected units have acquired target traits!",
                                    Lifetime = 4
                                })
                            end)
                        end
                    end
                    task.wait(0.5)
                    return
                end

                -- Purely Sequential: Focus continuous rolls on the first pending unit until it succeeds, then advance
                local activeUnitId = pendingUnits[1]
                local unitItem = inv[activeUnitId]
                if unitItem and unitItem.attributes then
                    RollTraitRE:FireServer(activeUnitId, true)
                    task.wait(TRAIT_ROLL_DELAY)
                else
                    task.wait(0.1)
                end
            end)
        else
            task.wait(0.5)
        end
    end
end)

-- Worker 3.13: Live Quirk, Grade & Trait Options Auto-Updater (Detects new game updates dynamically)
SpawnTracked(function()
    local lastQuirkCount = #GetDynamicQuirkOptions()
    local lastGradeCount = #GetDynamicGradeOptions()
    local lastTraitCount = #GetDynamicTraitOptions()

    while isScriptRunning do
        task.wait(10)
        pcall(function()
            if QuirkTargetsDropdown and QuirkTargetsDropdown.ClearOptions and QuirkTargetsDropdown.InsertOptions then
                local currentQuirks = GetDynamicQuirkOptions()
                if #currentQuirks ~= lastQuirkCount then
                    lastQuirkCount = #currentQuirks
                    RefreshDropdownPreservingSelection(QuirkTargetsDropdown, GetDynamicQuirkOptions, State.SelectedQuirks, false)
                end
            end

            if GradeTargetsDropdown and GradeTargetsDropdown.ClearOptions and GradeTargetsDropdown.InsertOptions then
                local currentGrades = GetDynamicGradeOptions()
                if #currentGrades ~= lastGradeCount then
                    lastGradeCount = #currentGrades
                    RefreshDropdownPreservingSelection(GradeTargetsDropdown, GetDynamicGradeOptions, State.SelectedGrades, false)
                end
            end

            if TraitTargetsDropdown and TraitTargetsDropdown.ClearOptions and TraitTargetsDropdown.InsertOptions then
                local currentTraits = GetDynamicTraitOptions()
                if #currentTraits ~= lastTraitCount then
                    lastTraitCount = #currentTraits
                    RefreshDropdownPreservingSelection(TraitTargetsDropdown, GetDynamicTraitOptions, State.SelectedTraits, false)
                end
            end
        end)
    end
end)

-- Helper: Real-time Money / Sec Calculation (Plot Units Income * Money Multiplier)
local function CalculateMoneyPerSec()
    local totalRate = 0
    pcall(function()
        if DataController and DataController.Slots and DataController.Inventory and EntryRegistry then
            local slots = DataController.Slots()
            local inv = DataController.Inventory()
            local mult = 1
            if BuffController and BuffController.GetBuff then
                mult = BuffController.GetBuff("Money Multiplier") or 1
            end

            if slots and inv then
                for _, s in pairs(slots) do
                    local unitId = s and s.unitId
                    local item = unitId and inv[unitId]
                    if item then
                        local cfg = EntryRegistry.getEntryConfig(item.name)
                        if cfg and cfg.income then
                            local inc = 0
                            pcall(function() inc = cfg.income(item.attributes) end)
                            totalRate = totalRate + inc
                        end
                    end
                end
            end
            totalRate = totalRate * mult
        end
    end)
    return totalRate
end

-- Worker 4: Live Statistics Refresher
SpawnTracked(function()
    while isScriptRunning do
        pcall(function()
            if DataController then
                local rolls = DataController.Rolls and DataController.Rolls() or 0
                local money = DataController.Money and DataController.Money() or 0
                local dice = DataController.Dice and DataController.Dice() or "None"
                local autoSell = DataController.AutoSell and DataController.AutoSell() or 0

                local formattedMoney = (NumberFormatter and NumberFormatter.FormatCompact) and NumberFormatter.FormatCompact(money) or tostring(money)
                local formattedRolls = (NumberFormatter and NumberFormatter.FormatCompact) and NumberFormatter.FormatCompact(rolls) or tostring(rolls)

                if StatRollsLabel then
                    UpdateLabel(StatRollsLabel, "Total Rolls: " .. formattedRolls .. " (" .. tostring(rolls) .. ")")
                end
                if StatMoneyLabel then
                    UpdateLabel(StatMoneyLabel, "Total Money: $" .. formattedMoney)
                end
                if StatMoneyRateLabel then
                    local rate = CalculateMoneyPerSec()
                    local formattedRate = (NumberFormatter and NumberFormatter.FormatCompact) and NumberFormatter.FormatCompact(rate) or tostring(math.floor(rate))
                    UpdateLabel(StatMoneyRateLabel, "Money / Sec: +$" .. formattedRate .. "/s")
                end
                if StatDiceLabel then
                    UpdateLabel(StatDiceLabel, "Equipped Dice: " .. tostring(dice))
                end

                if AutoSellStatusLabel then
                    if autoSell == 0 then
                        UpdateLabel(AutoSellStatusLabel, "Current Server AutoSell: Off (0)")
                    else
                        local formattedAS = (NumberFormatter and NumberFormatter.FormatCompact) and NumberFormatter.FormatCompact(autoSell) or tostring(autoSell)
                        UpdateLabel(AutoSellStatusLabel, "Current Server AutoSell: 1 in " .. formattedAS)
                    end
                end
            end

            if BuffController and BuffController.GetBuff then
                local luck = BuffController.GetBuff("Luck") or 1
                local dur = BuffController.GetBuff("Roll Duration") or 2.5
                if StatLuckLabel then
                    UpdateLabel(StatLuckLabel, string.format("Luck Multiplier: %.2fx", luck))
                end
                if StatDurationLabel then
                    UpdateLabel(StatDurationLabel, string.format("Roll Duration: %.2fs", dur))
                end
            end
        end)
        task.wait(2)
    end
end)

-- ==============================================================================
-- 13. ANTI-AFK SYSTEM
-- ==============================================================================
if getconnections then
    for _, c in getconnections(LocalPlayer.Idled) do
        pcall(function() c:Disable(); c:Disconnect() end)
    end
end

local function SendAntiAfkInput()
    pcall(function()
        local vim = Instance.new("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        vim:Destroy()
    end)
end

local antiAfkCon = LocalPlayer.Idled:Connect(SendAntiAfkInput)
getgenv().STRIX_ANTI_AFK_CON = antiAfkCon

SpawnTracked(function()
    while isScriptRunning do
        task.wait(300)
        if not isScriptRunning then break end
        SendAntiAfkInput()
    end
end)

-- Select first tab
pcall(function()
    if Tabs.Main and Tabs.Main.Select then
        Tabs.Main:Select()
    end
end)

-- Global Registry
getgenv().STRIX_HUB = {
    Window = Window,
    Tabs = Tabs,
    State = State,
    MacLib = MacLib,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig
}
getgenv().STRIX_HUB_JOB_ID = game.JobId

print("[STRIX HUB] Anime Dice script initialized successfully!")
