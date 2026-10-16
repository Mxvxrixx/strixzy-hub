-- ==============================================================================
-- STRIX HUB | Mini City Wars
-- Standard Master UI Architecture & Archetype Blueprint
-- Supported Place IDs: 133756580238784 (Main), 113956197828246 (Novice), 112820989813035 (Pro)
-- ==============================================================================

-- ==============================================================================
-- 1. VERIFICATION & SAFETY GATE (Auto-Execute Lifecycle Gate)
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

if not LocalPlayer:FindFirstChild("PlayerGui") then
    LocalPlayer:WaitForChild("PlayerGui", 25)
end

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

-- Viewport stabilization (Prevents CanvasGroup / rendering crashes)
pcall(function()
    local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 10)
    if camera then
        local t0 = os.clock()
        while (camera.ViewportSize.X < 200 or camera.ViewportSize.Y < 200) and (os.clock() - t0 < 5) do
            task.wait(0.2)
        end
    end
end)

-- Safe Instance Cleanup (Neutralizes duplicate threads & memory leaks)
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
local scriptConnections = {}
local scriptTasks = {}

getgenv().STRIX_HUB_CLEANUP = function()
    isScriptRunning = false
    
    for _, conn in ipairs(scriptConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(scriptConnections)
    
    for _, t in ipairs(scriptTasks) do
        pcall(function() task.cancel(t) end)
    end
    table.clear(scriptTasks)

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

-- Anti-AFK Protection
pcall(function()
    local virtualUser = game:GetService("VirtualUser")
    getgenv().STRIX_ANTI_AFK_CON = LocalPlayer.Idled:Connect(function()
        if not isScriptRunning then return end
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.zero)
    end)
end)

-- ==============================================================================
-- 2. SERVICES & REMOTES RESOLUTION
-- ==============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 25) or ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
    warn("[STRIX HUB] Remotes folder not found in ReplicatedStorage!")
    return
end

local EconomyRemotes   = RemotesFolder:WaitForChild("Economy", 15)
local BuildingRemotes  = RemotesFolder:WaitForChild("Building", 15)
local QuestsRemotes    = RemotesFolder:WaitForChild("Quests", 15)
local EventGiftRemotes = RemotesFolder:WaitForChild("EventGift", 15)

local Remotes = {
    CollectRequest        = EconomyRemotes and EconomyRemotes:WaitForChild("CollectRequest", 10),
    RequestRestock        = BuildingRemotes and BuildingRemotes:WaitForChild("RequestRestock", 10),
    RequestUnlockCell     = BuildingRemotes and BuildingRemotes:WaitForChild("RequestUnlockCell", 10),
    UnlockCellResult      = BuildingRemotes and BuildingRemotes:WaitForChild("UnlockCellResult", 10),
    RequestRepairBuilding = BuildingRemotes and BuildingRemotes:WaitForChild("RequestRepairBuilding", 10),
    RepairResult          = BuildingRemotes and BuildingRemotes:WaitForChild("RepairResult", 10),
    RequestQuestState     = QuestsRemotes and QuestsRemotes:WaitForChild("RequestQuestState", 10),
    QuestState            = QuestsRemotes and QuestsRemotes:WaitForChild("QuestState", 10),
    ClaimQuest            = QuestsRemotes and QuestsRemotes:WaitForChild("ClaimQuest", 10),
    SkipQuest             = QuestsRemotes and QuestsRemotes:WaitForChild("SkipQuest", 10),
    ClaimLegacy           = QuestsRemotes and QuestsRemotes:WaitForChild("ClaimLegacy", 10),
    ClaimEventGift        = EventGiftRemotes and EventGiftRemotes:WaitForChild("Claim", 10),
    EventGiftResult       = EventGiftRemotes and EventGiftRemotes:WaitForChild("ClaimResult", 10),
}

-- Catalogs & Helpers
local Catalogs = ReplicatedStorage:FindFirstChild("Catalogs")
local EventGiftCatalog = Catalogs and Catalogs:FindFirstChild("EventGiftCatalog") and select(2, pcall(require, Catalogs.EventGiftCatalog)) or nil
local QuestCatalog = Catalogs and Catalogs:FindFirstChild("QuestCatalog") and select(2, pcall(require, Catalogs.QuestCatalog)) or nil

-- ==============================================================================
-- 3. STATE & CONFIGURATION MANAGEMENT
-- ==============================================================================
local ConfigFolder = "STRIX HUB/Mini City Wars"
local ConfigFile = ConfigFolder .. "/" .. tostring(LocalPlayer.Name) .. ".json"

local function EnsureFolders()
    if isfolder and not isfolder("STRIX HUB") then pcall(makefolder, "STRIX HUB") end
    if isfolder and not isfolder(ConfigFolder) then pcall(makefolder, ConfigFolder) end
end
EnsureFolders()

local State = {
    -- Automations
    AutoCollectCash = true,
    CollectInterval = 1.0,

    
    AutoUnlockLand = false,
    UnlockInterval = 2.0,
    
    AutoRepair = true,
    RepairInterval = 2.0,
    
    AutoClaimDailyQuests = true,
    AutoClaimLegacyMilestones = true,
    AutoClaimEventGifts = true,
    QuestsPollInterval = 5.0,

    -- UI & System Settings
    AcrylicBlur = false,
    ShowUserInfo = true,
    MobileToggle = true,
    Keybind = Enum.KeyCode.RightControl,
    UISize = { Width = 868, Height = 650 }
}

local function ResolveBind(bindName)
    if not bindName or bindName == "Unknown" or bindName == "None" then return nil end
    local okKey, k = pcall(function() return Enum.KeyCode[bindName] end)
    if okKey and k and k ~= Enum.KeyCode.Unknown then return k end
    local okInput, u = pcall(function() return Enum.UserInputType[bindName] end)
    if okInput and u and u ~= Enum.UserInputType.None then return u end
    return nil
end

-- Pre-load Config from disk
if isfile and isfile(ConfigFile) then
    local okRead, content = pcall(readfile, ConfigFile)
    if okRead and content and #content > 2 then
        local okParse, data = pcall(function() return HttpService:JSONDecode(content) end)
        if okParse and type(data) == "table" then
            for k, v in pairs(data) do
                if k == "Keybind" then
                    local bind = ResolveBind(v)
                    if bind then State.Keybind = bind end
                elseif State[k] ~= nil then
                    State[k] = v
                end
            end
        end
    end
end

local isLoadingConfig = false
local function SaveConfig()
    if not isScriptRunning or isLoadingConfig then return end
    EnsureFolders()
    
    local payload = {}
    for k, v in pairs(State) do
        if typeof(v) == "EnumItem" then
            payload[k] = v.Name
        else
            payload[k] = v
        end
    end
    
    pcall(function()
        if writefile then
            writefile(ConfigFile, HttpService:JSONEncode(payload))
        end
    end)
end

local saveDebounce = false
local function SaveConfigDebounced()
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.5, function()
        saveDebounce = false
        SaveConfig()
    end)
end

-- ==============================================================================
-- 4. MACLIB UI LOADING & 7 ESSENTIAL REGEX PATCHES
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
    warn("[STRIX HUB] Failed to download or load Maclib UI Library!")
    return
end

-- Patch 1: Single-Select Dropdown Reset Bug
if rawMaclibSource:find("Selected = {}\r\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\r\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\r\n\t\t\t\t\t\t\tend", 1)
elseif rawMaclibSource:find("Selected = {}\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\n\t\t\t\t\t\t\tend", 1)
end

-- Patch 2: Allow Dropdown Settings.Default to match strings, numbers, or tables
local patDefault = "isSelected = %(Settings%.Default == i%) and true or false"
local replDefault = "isSelected = (Settings.Default == i or Settings.Default == v or (type(Settings.Default) == 'table' and table.find(Settings.Default, v) ~= nil)) and true or false"
rawMaclibSource = rawMaclibSource:gsub(patDefault, replDefault)

-- Patch 3: Allow Dropdown UpdateSelection to accept string values directly
local patUpdateSel = "function DropdownFunctions:UpdateSelection%(newSelection%)"
local replUpdateSel = "function DropdownFunctions:UpdateSelection(newSelection)\n\t\t\t\t\t\tif type(newSelection) == 'string' then newSelection = { newSelection } end"
rawMaclibSource = rawMaclibSource:gsub(patUpdateSel, replUpdateSel)

-- Patch 4: Slider Minimum/Maximum arithmetic nil bug
local patSliderMinMax = "function SectionFunctions:Slider%(Settings, Flag%)"
local replSliderMinMax = "function SectionFunctions:Slider(Settings, Flag)\n\t\t\t\t\tSettings.Minimum = Settings.Minimum or Settings.Min or 0\n\t\t\t\t\tSettings.Maximum = Settings.Maximum or Settings.Max or 100"
rawMaclibSource = rawMaclibSource:gsub(patSliderMinMax, replSliderMinMax)

-- Patch 5: Responsive Content sizing (prevent double-scale gap)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, %(base%.AbsoluteSize%.X %- sidebar%.AbsoluteSize%.X%), 1, 0%)",
    "content.Size = UDim2.new(1 - sidebar.Size.X.Scale, -sidebar.Size.X.Offset, 1, 0)"
)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, base%.AbsoluteSize%.X %- newSidebarWidth, 1, 0%)",
    "content.Size = UDim2.new(1, -newSidebarWidth, 1, 0)"
)

-- Patch 6: Clear & Distinct Section Dividers
local patDivLine = "line%.BackgroundColor3 = Color3%.fromRGB%(255, 255, 255%)\r?\n\t*line%.BackgroundTransparency = 0%.9\r?\n\t*line%.BorderColor3 = Color3%.fromRGB%(0, 0, 0%)\r?\n\t*line%.BorderSizePixel = 0\r?\n\t*line%.Size = UDim2%.new%(1, 0, 0, 1%)"
local replDivLine = "line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)\n\t\t\t\t\tline.BackgroundTransparency = 0.68\n\t\t\t\t\tline.BorderSizePixel = 0\n\t\t\t\t\tline.Size = UDim2.new(1, 0, 0, 1)"
rawMaclibSource = rawMaclibSource:gsub(patDivLine, replDivLine)

-- Patch 7: TweenService Thread Capability & Protected Hierarchy Crash
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

local loadedLib, loadErr = loadstring(rawMaclibSource)
if not loadedLib then
    warn("[STRIX HUB] Failed to compile patched Maclib: " .. tostring(loadErr))
    return
end

MacLib = loadedLib()

-- ==============================================================================
-- 5. WINDOW CREATION & DIRECTX CRASH BYPASS
-- ==============================================================================
local Window = MacLib:Window({
    Title = "STRIX HUB",
    Subtitle = "Mini City Wars",
    Size = (State.UISize and State.UISize.Width and State.UISize.Height) and UDim2.fromOffset(State.UISize.Width, State.UISize.Height) or UDim2.fromOffset(868, 650),
    DragStyle = 1,
    AcrylicBlur = (State.AcrylicBlur == true),
    ShowUserInfo = (State.ShowUserInfo ~= false),
    Keybind = (State.Keybind and State.Keybind ~= Enum.KeyCode.Unknown) and State.Keybind or Enum.KeyCode.RightControl
})

-- Completely disable MacLib notifications to prevent CanvasGroup DirectX crashes
Window:SetNotificationsState(false)

-- Neutralize Dialog to prevent CanvasGroup modal crashes
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
-- 6. RESPONSIVE SCREEN AUTO-SCALE & DRAG-TO-RESIZE
-- ==============================================================================
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

    local startMousePos
    local startOffsetSize
    local startPos

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

    local rightEdge = Instance.new("TextButton")
    rightEdge.Name = "ResizeHandle_Right"
    rightEdge.AnchorPoint = Vector2.new(1, 0)
    rightEdge.Position = UDim2.new(1, 0, 0, 30)
    rightEdge.Size = UDim2.new(0, 8, 1, -54)
    rightEdge.BackgroundTransparency = 1
    rightEdge.Text = ""
    rightEdge.ZIndex = 99
    rightEdge.Parent = base

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
task.spawn(SetupWindowResize)

-- ==============================================================================
-- 7. MOBILE FLOATING ACTION BUTTON
-- ==============================================================================
local function CreateMobileToggleButton()
    if getgenv().STRIX_MOBILE_GUI then
        pcall(function() getgenv().STRIX_MOBILE_GUI:Destroy() end)
        getgenv().STRIX_MOBILE_GUI = nil
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
task.spawn(CreateMobileToggleButton)

-- ==============================================================================
-- 8. GAME HELPERS & LOGIC ENGINES
-- ==============================================================================
local function GetPlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local myUserId = LocalPlayer.UserId
    
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerId") == myUserId then
            return plot
        end
        local buildings = plot:FindFirstChild("Buildings")
        if buildings then
            for _, b in ipairs(buildings:GetChildren()) do
                if b:GetAttribute("OwnerId") == myUserId then
                    return plot
                end
            end
        end
    end
    return nil
end

-- 1. Collect Cash from all player's buildings
local function CollectCashOnce()
    local plot = GetPlayerPlot()
    if not plot then return 0, 0 end
    local buildings = plot:FindFirstChild("Buildings")
    if not buildings then return 0, 0 end

    local collectedCount = 0
    local totalPending = 0

    for _, b in ipairs(buildings:GetChildren()) do
        local pending = tonumber(b:GetAttribute("PendingCash")) or 0
        if pending >= 1 then
            pcall(function()
                Remotes.CollectRequest:FireServer(b)
            end)
            collectedCount = collectedCount + 1
            totalPending = totalPending + pending
        end
    end
    return collectedCount, totalPending
end


-- 3. Unlock Land (Locked tiles in player's plot)
local function UnlockLandOnce()
    local plot = GetPlayerPlot()
    if not plot then return false end
    local cells = plot:FindFirstChild("Cells")
    if not cells then return false end

    local currentCash = tonumber(LocalPlayer:GetAttribute("WalletCash")) or 0

    for _, c in ipairs(cells:GetChildren()) do
        if c.Name:sub(1, 11) == "LockedTile_" then
            local ux = c:GetAttribute("TileUX")
            local uz = c:GetAttribute("TileUZ")
            if ux and uz then
                local prompt = c:FindFirstChildOfClass("ProximityPrompt")
                local cost = 3200
                if prompt and prompt.ActionText then
                    local num = prompt.ActionText:match("%$(%d+)")
                    if num then cost = tonumber(num) or 3200 end
                end

                if currentCash >= cost then
                    pcall(function()
                        Remotes.RequestUnlockCell:FireServer(ux, uz)
                    end)
                    return true -- unlock 1 per tick to ensure smooth sync
                end
            end
        end
    end
    return false
end

-- 4. Repair Ruined Buildings & Walls
local function RepairRuinsOnce()
    -- Skip if base is under attack (game server locks repairs during raids)
    if LocalPlayer:GetAttribute("UnderRaid") == true then
        return 0
    end

    local plot = GetPlayerPlot()
    if not plot then return 0 end
    local repairedCount = 0

    local foldersToCheck = {
        plot:FindFirstChild("Buildings"),
        plot:FindFirstChild("Walls")
    }

    for _, folder in ipairs(foldersToCheck) do
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if item:GetAttribute("IsRubble") == true or item:FindFirstChild("RepairPrompt") then
                    pcall(function()
                        Remotes.RequestRepairBuilding:FireServer(item)
                    end)
                    repairedCount = repairedCount + 1
                end
            end
        end
    end
    return repairedCount
end

-- 5 & 6. Quests Cache & Handler
local cachedQuestState = nil

local function HandleQuestState(state)
    if type(state) ~= "table" then return end
    cachedQuestState = state

    -- Auto Claim Daily Quests
    if State.AutoClaimDailyQuests and state.daily and type(state.daily) == "table" then
        for _, q in ipairs(state.daily) do
            if type(q) == "table" and q.done == true and q.slot then
                pcall(function()
                    Remotes.ClaimQuest:FireServer(q.slot)
                end)
            end
        end
    end

    -- Auto Claim Legacy Milestones
    if State.AutoClaimLegacyMilestones and state.legacy and type(state.legacy) == "table" then
        for _, l in ipairs(state.legacy) do
            if type(l) == "table" and l.done == true and l.id then
                pcall(function()
                    Remotes.ClaimLegacy:FireServer(l.id)
                end)
            end
        end
    end
end

if Remotes.QuestState then
    table.insert(scriptConnections, Remotes.QuestState.OnClientEvent:Connect(function(state)
        if not isScriptRunning then return end
        HandleQuestState(state)
    end))
end

-- 7. Event Gifts
local function ClaimEventGiftOnce()
    local giftId = LocalPlayer:GetAttribute("EventGift")
    if not giftId and EventGiftCatalog and EventGiftCatalog.current then
        local cur = EventGiftCatalog.current(os.time())
        if cur and cur.id then giftId = cur.id end
    end

    if giftId and Remotes.ClaimEventGift then
        pcall(function()
            Remotes.ClaimEventGift:FireServer(giftId)
        end)
    end
end

table.insert(scriptConnections, LocalPlayer:GetAttributeChangedSignal("EventGift"):Connect(function()
    if not isScriptRunning or not State.AutoClaimEventGifts then return end
    ClaimEventGiftOnce()
end))

-- Trigger repairs immediately when a raid/attack finishes
table.insert(scriptConnections, LocalPlayer:GetAttributeChangedSignal("UnderRaid"):Connect(function()
    if not isScriptRunning or not State.AutoRepair then return end
    if LocalPlayer:GetAttribute("UnderRaid") ~= true then
        task.delay(0.5, function()
            if isScriptRunning and State.AutoRepair then
                pcall(RepairRuinsOnce)
            end
        end)
    end
end))

-- ==============================================================================
-- 9. TAB HIERARCHY & 2-COLUMN SECTION LAYOUT
-- ==============================================================================
local TabGroup = Window:TabGroup()

local Tabs = {
    Main = TabGroup:Tab({ Name = "Main / Auto", Image = "rbxassetid://10709782230" }),
    Settings = TabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" })
}

local MainSections = {
    LeftSection = Tabs.Main:Section({ Side = "Left" }),
    RightSection = Tabs.Main:Section({ Side = "Right" })
}

-- Left Column: Economy & Building Automations
MainSections.LeftSection:Header({ Text = "Economy & City Automations" })

MainSections.LeftSection:Toggle({
    Name = "Auto Collect Cash",
    Default = (State.AutoCollectCash == true),
    Callback = function(v)
        State.AutoCollectCash = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoCollectCash")

MainSections.LeftSection:Slider({
    Name = "Collect Interval (s)",
    Min = 0.5,
    Max = 5.0,
    Precision = 1,
    Default = State.CollectInterval or 1.0,
    Callback = function(v)
        State.CollectInterval = v
        SaveConfigDebounced()
    end
}, "Slider_CollectInterval")

MainSections.LeftSection:Divider()



MainSections.LeftSection:Toggle({
    Name = "Auto Unlock Land (Tiles)",
    Default = (State.AutoUnlockLand == true),
    Callback = function(v)
        State.AutoUnlockLand = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoUnlockLand")

MainSections.LeftSection:Slider({
    Name = "Unlock Land Interval (s)",
    Min = 1,
    Max = 10,
    Precision = 0,
    Default = State.UnlockInterval or 2,
    Callback = function(v)
        State.UnlockInterval = v
        SaveConfigDebounced()
    end
}, "Slider_UnlockInterval")

MainSections.LeftSection:Divider()

MainSections.LeftSection:Toggle({
    Name = "Auto Repair Ruins & Walls",
    Default = (State.AutoRepair == true),
    Callback = function(v)
        State.AutoRepair = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoRepair")

MainSections.LeftSection:Slider({
    Name = "Repair Check Interval (s)",
    Min = 1,
    Max = 10,
    Precision = 0,
    Default = State.RepairInterval or 2,
    Callback = function(v)
        State.RepairInterval = v
        SaveConfigDebounced()
    end
}, "Slider_RepairInterval")

-- Right Column: Quests, Rewards & Manual Actions
MainSections.RightSection:Header({ Text = "Quests & Reward Automations" })

MainSections.RightSection:Toggle({
    Name = "Auto Claim Daily Quests",
    Default = (State.AutoClaimDailyQuests == true),
    Callback = function(v)
        State.AutoClaimDailyQuests = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoClaimDailyQuests")

MainSections.RightSection:Toggle({
    Name = "Auto Claim Legacy Milestones",
    Default = (State.AutoClaimLegacyMilestones == true),
    Callback = function(v)
        State.AutoClaimLegacyMilestones = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoClaimLegacyMilestones")

MainSections.RightSection:Toggle({
    Name = "Auto Claim Event Gifts",
    Default = (State.AutoClaimEventGifts == true),
    Callback = function(v)
        State.AutoClaimEventGifts = v
        SaveConfigDebounced()
    end
}, "Toggle_AutoClaimEventGifts")



-- Select First Tab by default
pcall(function()
    if Tabs.Main and Tabs.Main.Select then
        Tabs.Main:Select()
    end
end)

-- ==============================================================================
-- 10. UNIVERSAL SETTINGS TAB
-- ==============================================================================
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
        Window:Notify({ Title = "Config", Description = "Saved successfully!", Lifetime = 3 })
    end
})

local function LoadConfig()
    if not isfile or not isfile(ConfigFile) then return end
    local okRead, content = pcall(readfile, ConfigFile)
    if not okRead or not content or #content < 2 then return end
    local okParse, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okParse or type(data) ~= "table" then return end

    isLoadingConfig = true
    for k, v in pairs(data) do
        if k == "Keybind" then
            local bind = ResolveBind(v)
            if bind then State.Keybind = bind end
        elseif State[k] ~= nil then
            State[k] = v
        end
    end

    -- Update MacLib UI components
    pcall(function()
        if MacLib and MacLib.Options then
            for flag, option in pairs(MacLib.Options) do
                local stateKey = flag:gsub("^Toggle_", ""):gsub("^Slider_", ""):gsub("^Keybind_", "")
                if State[stateKey] ~= nil and option.SetValue then
                    pcall(function() option:SetValue(State[stateKey]) end)
                end
            end
        end
    end)

    isLoadingConfig = false
end

SettingsSections.Config:Button({
    Name = "Reload Config",
    Callback = function()
        LoadConfig()
        Window:Notify({ Title = "Config", Description = "Reloaded config!", Lifetime = 3 })
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
-- 11. BACKGROUND TASK WORKERS
-- ==============================================================================

-- Worker 1: Auto Collect Cash
table.insert(scriptTasks, task.spawn(function()
    while isScriptRunning do
        if State.AutoCollectCash then
            pcall(CollectCashOnce)
        end
        task.wait(State.CollectInterval or 1.0)
    end
end))


-- Worker 3: Auto Unlock Land
table.insert(scriptTasks, task.spawn(function()
    while isScriptRunning do
        if State.AutoUnlockLand then
            pcall(UnlockLandOnce)
        end
        task.wait(State.UnlockInterval or 2.0)
    end
end))

-- Worker 4: Auto Repair Ruined Buildings & Walls
table.insert(scriptTasks, task.spawn(function()
    while isScriptRunning do
        if State.AutoRepair then
            pcall(RepairRuinsOnce)
        end
        task.wait(State.RepairInterval or 2.0)
    end
end))

-- Worker 5: Quests & Event Gift Polling
table.insert(scriptTasks, task.spawn(function()
    while isScriptRunning do
        if State.AutoClaimDailyQuests or State.AutoClaimLegacyMilestones then
            pcall(function()
                if Remotes.RequestQuestState then
                    Remotes.RequestQuestState:FireServer()
                end
            end)
        end
        if State.AutoClaimEventGifts then
            pcall(ClaimEventGiftOnce)
        end
        task.wait(State.QuestsPollInterval or 5.0)
    end
end))

-- Worker 6: Periodic Auto Save Config (Every 10 seconds)
table.insert(scriptTasks, task.spawn(function()
    while isScriptRunning do
        task.wait(10)
        pcall(SaveConfig)
    end
end))


print("[STRIX HUB] Mini City Wars script loaded successfully!")
