-- ==============================================================================
-- STRIX HUB | Mini City Wars
-- Standard UI Archetype Blueprint: AnimeMysterious Standard
-- ==============================================================================

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
local ConfigFolder = "STRIX HUB/Mini City Wars"
local ConfigFile = ConfigFolder .. "/" .. tostring(LocalPlayer.Name) .. ".json"

local function EnsureFolders()
    if isfolder and not isfolder("STRIX HUB") then pcall(makefolder, "STRIX HUB") end
    if isfolder and not isfolder(ConfigFolder) then pcall(makefolder, ConfigFolder) end
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
    if getgenv().STRIX_KEYBIND_CON then
        pcall(function() getgenv().STRIX_KEYBIND_CON:Disconnect() end)
        getgenv().STRIX_KEYBIND_CON = nil
    end
end

-- ==============================================================================
-- 1. SERVICES & REMOTES RESOLUTION
-- ==============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 25)

-- Economy Remotes
local EconomyRemotes = Remotes and Remotes:WaitForChild("Economy", 15)
local CollectRequest = EconomyRemotes and EconomyRemotes:WaitForChild("CollectRequest", 15)
local CiviliansUpdated = EconomyRemotes and EconomyRemotes:WaitForChild("CiviliansUpdated", 15)

-- Building Remotes (Repair & Shop System)
local BuildingRemotes = Remotes and Remotes:WaitForChild("Building", 15)
local RequestRepairBuilding = BuildingRemotes and BuildingRemotes:WaitForChild("RequestRepairBuilding", 15)
local RepairResult = BuildingRemotes and BuildingRemotes:WaitForChild("RepairResult", 15)
local BuyToInventory = BuildingRemotes and BuildingRemotes:WaitForChild("BuyToInventory", 15)
local BuyResult = BuildingRemotes and BuildingRemotes:WaitForChild("BuyResult", 15)
local StockUpdated = BuildingRemotes and BuildingRemotes:WaitForChild("StockUpdated", 15)
local RequestStock = BuildingRemotes and BuildingRemotes:WaitForChild("RequestStock", 15)

-- Building Catalog
local BuildingCatalog = nil
pcall(function()
    BuildingCatalog = require(ReplicatedStorage:WaitForChild("Catalogs"):WaitForChild("BuildingCatalog"))
end)

-- Research Remotes
local ResearchRemotes = Remotes and Remotes:WaitForChild("Research", 15)
local RequestResearch = ResearchRemotes and ResearchRemotes:WaitForChild("RequestResearch", 15)
local RequestResearchState = ResearchRemotes and ResearchRemotes:WaitForChild("RequestResearchState", 15)
local ResearchResult = ResearchRemotes and ResearchRemotes:WaitForChild("ResearchResult", 15)
local ResearchState = ResearchRemotes and ResearchRemotes:WaitForChild("ResearchState", 15)

-- Research Catalog & HexGrid
local ResearchConfig = nil
local HexGrid = nil
pcall(function()
    ResearchConfig = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("ResearchConfig"))
    HexGrid = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("HexGrid"))
end)

-- Quests Remotes
local QuestsRemotes = Remotes and Remotes:WaitForChild("Quests", 15)
local QuestState = QuestsRemotes and QuestsRemotes:WaitForChild("QuestState", 15)
local ClaimQuest = QuestsRemotes and QuestsRemotes:WaitForChild("ClaimQuest", 15)
local ClaimLegacy = QuestsRemotes and QuestsRemotes:WaitForChild("ClaimLegacy", 15)
local RequestQuestState = QuestsRemotes and QuestsRemotes:WaitForChild("RequestQuestState", 15)

-- Plot Owners Attribute Storage
local PlotOwners = ReplicatedStorage:WaitForChild("PlotOwners", 15)

-- Quests Data Cache
local cachedQuestData = nil

if QuestState then
    QuestState.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            cachedQuestData = data
        end
    end)
    task.defer(function()
        if RequestQuestState then
            pcall(function() RequestQuestState:FireServer() end)
        end
    end)
end

-- Helper: Format Number with commas (e.g. 1,000,000)
local function FormatNumber(val)
    local n = tonumber(val) or 0
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Helper: Find player's assigned plot in workspace.Plots
local function GetPlayerPlot()
    if PlotOwners then
        for i = 1, 6 do
            if PlotOwners:GetAttribute("Plot" .. i .. "_Id") == LocalPlayer.UserId then
                local plots = workspace:FindFirstChild("Plots")
                local p = plots and plots:FindFirstChild("Plot" .. i)
                if p then return p end
            end
        end
    end

    -- Fallback: detect by building OwnerId
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local bFolder = p:FindFirstChild("Buildings")
            if bFolder then
                for _, b in ipairs(bFolder:GetChildren()) do
                    if b:GetAttribute("OwnerId") == LocalPlayer.UserId then
                        return p
                    end
                end
            end
        end
    end
    return nil
end

-- Helper: Collect Cash from all owned buildings that have PendingCash
local function CollectCashFromBuildings()
    if not CollectRequest then return 0 end
    local plot = GetPlayerPlot()
    if not plot then return 0 end
    local buildingsFolder = plot:FindFirstChild("Buildings")
    if not buildingsFolder then return 0 end

    local count = 0
    for _, building in ipairs(buildingsFolder:GetChildren()) do
        if not isScriptRunning then break end
        local pending = tonumber(building:GetAttribute("PendingCash")) or 0
        if pending > 0 then
            pcall(function()
                CollectRequest:FireServer(building)
                building:SetAttribute("PendingCash", 0)
            end)
            count = count + 1
        end
    end
    return count
end

-- Helper: Get list of rubble/ruins owned by LocalPlayer (in Buildings and Walls)
local function GetRubbleList()
    local rubbles = {}
    local plot = GetPlayerPlot()
    if plot then
        for _, folderName in ipairs({"Buildings", "Walls"}) do
            local folder = plot:FindFirstChild(folderName)
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    if obj:GetAttribute("IsRubble") == true and obj:GetAttribute("OwnerId") == LocalPlayer.UserId then
                        table.insert(rubbles, obj)
                    end
                end
            end
        end
    end
    return rubbles
end

-- Helper: Repair all destroyed buildings & broken walls
local function RepairAllRuins()
    if not RequestRepairBuilding then return 0 end
    if LocalPlayer:GetAttribute("UnderRaid") == true then
        return 0
    end

    local rubbles = GetRubbleList()
    local count = 0
    for _, ruin in ipairs(rubbles) do
        if not isScriptRunning then break end
        if ruin.Parent and ruin:GetAttribute("IsRubble") == true then
            pcall(function()
                RequestRepairBuilding:FireServer(ruin)
            end)
            count = count + 1
            task.wait(0.15)
        end
    end
    return count
end

-- Helper: Claim Completed Daily and Legacy Quests
local function ClaimCompletedQuests()
    if not cachedQuestData then
        if RequestQuestState then
            pcall(function() RequestQuestState:FireServer() end)
        end
        return 0
    end

    local claimedCount = 0

    -- 1. Daily Quests Claim
    if type(cachedQuestData.daily) == "table" then
        for _, q in ipairs(cachedQuestData.daily) do
            if not isScriptRunning then break end
            if q.done and q.slot then
                pcall(function()
                    ClaimQuest:FireServer(q.slot)
                end)
                q.done = false
                claimedCount = claimedCount + 1
                task.wait(0.15)
            end
        end
    end

    -- 2. Legacy Quests Claim
    if type(cachedQuestData.legacy) == "table" then
        for _, q in ipairs(cachedQuestData.legacy) do
            if not isScriptRunning then break end
            if q.done and q.id then
                pcall(function()
                    ClaimLegacy:FireServer(q.id)
                end)
                q.done = false
                claimedCount = claimedCount + 1
                task.wait(0.15)
            end
        end
    end

    if RequestQuestState then
        pcall(function() RequestQuestState:FireServer() end)
    end

    return claimedCount
end

-- ==============================================================================
-- RESEARCH SYSTEM CACHE & HELPERS
-- ==============================================================================
local cachedResearchOwned = {}
local cachedResearchJobs = {}
local cachedResearchersMax = 1
local lastResearchAttemptTime = 0
local lastResearchAttemptId = nil
local lastResearchResult = { success = nil, msg = "", timestamp = 0 }

local function UpdateResearchState(data)
    if type(data) ~= "table" then return end
    table.clear(cachedResearchOwned)
    for _, id in ipairs(data.owned or {}) do
        cachedResearchOwned[id] = true
    end

    table.clear(cachedResearchJobs)
    if type(data.jobs) == "table" then
        for k, v in pairs(data.jobs) do
            if type(v) == "table" and v.id then
                cachedResearchJobs[v.id] = v
            elseif type(k) == "string" then
                cachedResearchJobs[k] = v
            end
        end
    end

    if type(data.researchers) == "number" then
        cachedResearchersMax = data.researchers
    end
end

if ResearchState then
    ResearchState.OnClientEvent:Connect(function(data)
        UpdateResearchState(data)
    end)
    task.defer(function()
        if RequestResearchState then
            pcall(function() RequestResearchState:FireServer() end)
        end
    end)
end

if ResearchResult then
    ResearchResult.OnClientEvent:Connect(function(success, nodeId, msg)
        lastResearchResult.success = (success == true)
        lastResearchResult.msg = tostring(msg or "")
        lastResearchResult.timestamp = os.clock()
        if RequestResearchState then
            task.delay(0.5, function()
                pcall(function() RequestResearchState:FireServer() end)
            end)
        end
    end)
end

local function GetActiveResearchJobCount()
    local count = 0
    for _ in pairs(cachedResearchJobs) do
        count = count + 1
    end
    return count
end

local function GetOwnedResearchCount()
    local count = 0
    for _ in pairs(cachedResearchOwned) do
        count = count + 1
    end
    return count
end

local function GetAvailableResearchNodes()
    if not ResearchConfig or not ResearchConfig.NODES or not HexGrid then return {} end

    local available = {}
    for _, node in ipairs(ResearchConfig.NODES) do
        if not cachedResearchOwned[node.id] and not cachedResearchJobs[node.id] and node.live == true then
            -- 1. Check prerequisites
            local reqsMet = true
            for _, reqId in ipairs(node.requires or {}) do
                if not cachedResearchOwned[reqId] then
                    reqsMet = false
                    break
                end
            end

            if reqsMet then
                -- 2. Check hex distance <= 1 to any owned node, or is ORIGIN
                local isConnected = (node.id == ResearchConfig.ORIGIN)
                if not isConnected then
                    for ownedId in pairs(cachedResearchOwned) do
                        local ownedNode = ResearchConfig.BY_ID and ResearchConfig.BY_ID[ownedId]
                        if ownedNode and HexGrid.distance(node.q, node.r, ownedNode.q, ownedNode.r) <= 1 then
                            isConnected = true
                            break
                        end
                    end
                end

                if isConnected then
                    table.insert(available, {
                        id = node.id,
                        name = node.name or node.id,
                        cost = tonumber(node.cost) or 0,
                        time = tonumber(node.time) or 0
                    })
                end
            end
        end
    end

    -- Sort by cost ascending, then by time ascending
    table.sort(available, function(a, b)
        if a.cost ~= b.cost then
            return a.cost < b.cost
        end
        return a.time < b.time
    end)

    return available
end

local function UpgradeNextResearch()
    if not RequestResearch then return false, "RequestResearch remote unavailable" end

    local activeJobs = GetActiveResearchJobCount()
    if activeJobs >= cachedResearchersMax then
        return false, ("All research slots full (%d/%d)"):format(activeJobs, cachedResearchersMax)
    end

    if (os.clock() - lastResearchAttemptTime) < 1.0 then
        return false, "Cooldown"
    end

    local currentCash = LocalPlayer:GetAttribute("WalletCash")
    if type(currentCash) ~= "number" then
        currentCash = 0
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        local cashVal = ls and ls:FindFirstChild("Cash")
        if cashVal and tonumber(cashVal.Value) then
            currentCash = tonumber(cashVal.Value)
        end
    end

    local availableList = GetAvailableResearchNodes()
    if #availableList == 0 then
        return false, "No research nodes currently available"
    end

    for _, item in ipairs(availableList) do
        if currentCash >= item.cost then
            lastResearchAttemptTime = os.clock()
            lastResearchAttemptId = item.id
            pcall(function()
                RequestResearch:FireServer(item.id)
            end)
            cachedResearchJobs[item.id] = { id = item.id, optimistic = true }
            return true, item.name
        end
    end

    local cheapest = availableList[1]
    return false, ("Need $%s for %s"):format(FormatNumber(cheapest.cost), cheapest.name)
end

-- ==============================================================================
-- SHOP & BUILDING CATALOG CLASSIFICATION & HELPERS
-- ==============================================================================
local ShopCategories = {
    residential = {},
    offices = {},
    military = {},
    misc = {}
}

local ShopCategoryOptions = {
    residential = {},
    offices = {},
    military = {},
    misc = {}
}

local categoryMap = {
    house = "residential",
    office = "offices",
    farm = "offices",
    mine = "offices",
    premium = "offices",
    military = "military",
    civic = "misc",
    recreational = "misc",
    decoration = "misc"
}

local function InitShopCatalog()
    if not BuildingCatalog or not BuildingCatalog.DEFS then return end
    for catKey, _ in pairs(ShopCategories) do
        table.clear(ShopCategories[catKey])
        table.clear(ShopCategoryOptions[catKey])
    end

    for _, def in pairs(BuildingCatalog.DEFS) do
        local group = categoryMap[def.category]
        if group and not def.robuxOnly and not def.exclusive then
            local cost = tonumber(def.cost) or 0
            if cost > 0 then
                local name = def.displayName or def.name or tostring(def.id)
                local label = ("%s ($%s)"):format(name, FormatNumber(cost))
                table.insert(ShopCategories[group], {
                    id = tostring(def.id),
                    name = name,
                    label = label,
                    cost = cost,
                    category = def.category,
                    unlockPop = tonumber(def.unlockPop) or 0
                })
            end
        end
    end

    for group, list in pairs(ShopCategories) do
        table.sort(list, function(a, b)
            return a.cost < b.cost
        end)
        for _, item in ipairs(list) do
            table.insert(ShopCategoryOptions[group], item.label)
        end
    end
end
InitShopCatalog()

-- Stock & Shop Live Cache
local cachedStocks = {}
local cachedRestockTimer = 0
local cachedCivilians = 9999
local lastPurchaseResult = { success = nil, msg = "None", itemName = "", timestamp = 0 }
local failedItemCooldowns = {}
local lastAttemptedItemId = nil

if StockUpdated then
    StockUpdated.OnClientEvent:Connect(function(stocks, restockTime)
        if type(stocks) == "table" then
            cachedStocks = stocks
        end
        if type(restockTime) == "number" then
            cachedRestockTimer = restockTime
        end
    end)
    task.defer(function()
        if RequestStock then
            pcall(function() RequestStock:FireServer() end)
        end
    end)
end

if CiviliansUpdated then
    CiviliansUpdated.OnClientEvent:Connect(function(curCiv, maxCiv)
        if type(curCiv) == "number" then
            cachedCivilians = curCiv
        end
    end)
end

if BuyResult then
    BuyResult.OnClientEvent:Connect(function(success, msg)
        lastPurchaseResult.success = (success == true)
        lastPurchaseResult.msg = tostring(msg or "")
        lastPurchaseResult.timestamp = os.clock()
        if lastAttemptedItemId then
            if success == true then
                failedItemCooldowns[lastAttemptedItemId] = nil
            else
                failedItemCooldowns[lastAttemptedItemId] = os.clock() + 20
            end
        end
    end)
end

-- Helper: Count selected items (supports both array and dictionary format)
local function GetSelectedCount(tbl)
    if type(tbl) ~= "table" then return 0 end
    local count = 0
    for k, v in pairs(tbl) do
        if v == true or type(k) == "number" then
            count = count + 1
        end
    end
    return count
end

-- Helper: Check if item is selected in the category selection table
local function IsItemSelected(selectedTbl, item)
    if type(selectedTbl) ~= "table" then return false end
    for k, v in pairs(selectedTbl) do
        local optName = (type(k) == "number") and v or (v == true and k or nil)
        if optName and (optName == item.label or optName == item.name or optName == item.id) then
            return true
        end
    end
    return false
end

-- Helper: Buy Next Available Item for Category
local function BuyNextBuilding(catKey)
    if not BuyToInventory then return false end
    local list = ShopCategories[catKey]
    if not list or #list == 0 then return false end

    local selectedList = nil
    if catKey == "residential" then
        selectedList = State.SelectedResidential
    elseif catKey == "offices" then
        selectedList = State.SelectedOffices
    elseif catKey == "military" then
        selectedList = State.SelectedMilitary
    elseif catKey == "misc" then
        selectedList = State.SelectedMisc
    end

    local selCount = GetSelectedCount(selectedList)
    if selCount == 0 and not State.BuyAllIfNoneSelected then
        -- User has not selected any items in this category and fallback buy-all is off
        return false
    end

    local currentCash = LocalPlayer:GetAttribute("WalletCash") or 0
    local minReserve = tonumber(State.KeepCashReserve) or 0

    for _, item in ipairs(list) do
        if not isScriptRunning then break end

        -- If specific items are selected, only buy those items
        if selCount > 0 and not IsItemSelected(selectedList, item) then
            continue
        end

        -- 1. Check if temporary blacklist cooldown
        if failedItemCooldowns[item.id] and os.clock() < failedItemCooldowns[item.id] then
            continue
        end

        -- 2. Check stock limit
        if cachedStocks[item.id] ~= nil and cachedStocks[item.id] <= 0 then
            continue
        end

        -- 3. Check civilian requirement
        if item.unlockPop and item.unlockPop > 0 and cachedCivilians < item.unlockPop then
            continue
        end

        -- 4. Check if player has enough cash considering reserve
        if (currentCash - item.cost) < minReserve then
            -- Can't afford this item
            break
        end

        -- 5. Fire purchase
        lastAttemptedItemId = item.id
        lastPurchaseResult.itemName = item.name
        if cachedStocks[item.id] and cachedStocks[item.id] > 0 then
            cachedStocks[item.id] = cachedStocks[item.id] - 1
        end

        pcall(function()
            BuyToInventory:FireServer(item.id, false, 1)
        end)
        return true, item
    end

    return false
end

-- Helper: Count items in stock for category
local function GetInStockCount(catKey)
    local list = ShopCategories[catKey]
    if not list then return 0 end
    local count = 0
    for _, item in ipairs(list) do
        local stock = cachedStocks[item.id]
        if stock == nil or stock > 0 then
            count = count + 1
        end
    end
    return count
end

-- ==============================================================================
-- 2. MACLIB SOURCE LOADING & REGEX PATCHES
-- ==============================================================================
local MacLib = nil
local MacLibCacheFile = "STRIX HUB/maclib_cache.lua"
local rawMaclibSource = nil

-- Fast load from disk cache
if isfile and isfile(MacLibCacheFile) then
    local ok, cached = pcall(readfile, MacLibCacheFile)
    if ok and cached and #cached > 1000 then
        rawMaclibSource = cached
    end
end

-- Fallback to remote download
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

-- Patch 1: Single-Select Dropdown Reset Bug
if rawMaclibSource:find("Selected = {}\r\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\r\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\r\n\t\t\t\t\t\t\tend", 1)
elseif rawMaclibSource:find("Selected = {}\n\t\t\t\t\t\t\tend") then
    rawMaclibSource = rawMaclibSource:gsub("Selected = {}\n\t\t\t\t\t\t\tend", "if Selected[1] == optionName then Selected = {} end\n\t\t\t\t\t\t\tend", 1)
end

-- Patch 2: Dropdown Default Match Bug
local patDefault = "isSelected = %(Settings%.Default == i%) and true or false"
local replDefault = "isSelected = (Settings.Default == i or Settings.Default == v or (type(Settings.Default) == 'table' and table.find(Settings.Default, v) ~= nil)) and true or false"
rawMaclibSource = rawMaclibSource:gsub(patDefault, replDefault)

-- Patch 3: Dropdown UpdateSelection String Acceptance Bug
local patUpdateSel = "function DropdownFunctions:UpdateSelection%(newSelection%)"
local replUpdateSel = "function DropdownFunctions:UpdateSelection(newSelection)\n\t\t\t\t\t\tif type(newSelection) == 'string' then newSelection = { newSelection } end"
rawMaclibSource = rawMaclibSource:gsub(patUpdateSel, replUpdateSel)

-- Patch 4: Enable Smooth Scrolling on Dropdowns
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

-- Patch 5: Slider Min/Max Arithmetic Nil Bug
local patSliderMinMax = "function SectionFunctions:Slider%(Settings, Flag%)"
local replSliderMinMax = "function SectionFunctions:Slider(Settings, Flag)\n\t\t\t\t\tSettings.Minimum = Settings.Minimum or Settings.Min or 0\n\t\t\t\t\tSettings.Maximum = Settings.Maximum or Settings.Max or 100"
rawMaclibSource = rawMaclibSource:gsub(patSliderMinMax, replSliderMinMax)

-- Patch 6: Responsive Content Gap Bug
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, %(base%.AbsoluteSize%.X %- sidebar%.AbsoluteSize%.X%), 1, 0%)",
    "content.Size = UDim2.new(1 - sidebar.Size.X.Scale, -sidebar.Size.X.Offset, 1, 0)"
)
rawMaclibSource = rawMaclibSource:gsub(
    "content%.Size = UDim2%.new%(0, base%.AbsoluteSize%.X %- newSidebarWidth, 1, 0%)",
    "content.Size = UDim2.new(1, -newSidebarWidth, 1, 0)"
)

-- Patch 7: Distinct Dividers
local patDivLine = "line%.BackgroundColor3 = Color3%.fromRGB%(255, 255, 255%)\r?\n\t*line%.BackgroundTransparency = 0%.9\r?\n\t*line%.BorderColor3 = Color3%.fromRGB%(0, 0, 0%)\r?\n\t*line%.BorderSizePixel = 0\r?\n\t*line%.Size = UDim2%.new%(1, 0, 0, 1%)"
local replDivLine = "line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)\n\t\t\t\t\tline.BackgroundTransparency = 0.68\n\t\t\t\t\tline.BorderSizePixel = 0\n\t\t\t\t\tline.Size = UDim2.new(1, 0, 0, 1)"
rawMaclibSource = rawMaclibSource:gsub(patDivLine, replDivLine)

-- Patch 8: Safe Tween Engine Wrapper
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

-- Patch 9: Keybind Blacklist Typo Crash Bug
rawMaclibSource = rawMaclibSource:gsub(
    "KeybindFunctions%.KeybindFunctions%.Settings%.Blacklist",
    "KeybindFunctions.Settings.Blacklist"
)

-- Patch 10: Clean Keybind Management & Leak Prevention
local patKeybindBlock = 'local MenuKeybind = Settings%.Keybind or Enum%.KeyCode%.RightControl.-UserInputService%.InputEnded:Connect%(function%(inp, gpe%)\r?\n\t*if gpe then return end\r?\n\t*if inp%.KeyCode == MenuKeybind then\r?\n\t*ToggleMenu%(%)\r?\n\t*end\r?\n\t*end%)'
local replKeybindBlock = [[local MenuKeybind = Settings.Keybind or Enum.KeyCode.RightControl

	local function ToggleMenu()
		if unloaded then return end
		local state = not WindowFunctions:GetState()
		WindowFunctions:SetState(state)
	end

	if getgenv().STRIX_KEYBIND_CON then
		pcall(function() getgenv().STRIX_KEYBIND_CON:Disconnect() end)
		getgenv().STRIX_KEYBIND_CON = nil
	end

	local keybindCon = UserInputService.InputEnded:Connect(function(inp, gpe)
		if gpe then return end
		if UserInputService:GetFocusedTextBox() then return end
		if unloaded then return end
		local isMatched = false
		if typeof(MenuKeybind) == "EnumItem" then
			if inp.KeyCode == MenuKeybind and MenuKeybind ~= Enum.KeyCode.Unknown then
				isMatched = true
			elseif inp.UserInputType == MenuKeybind then
				isMatched = true
			end
		end
		if isMatched then
			ToggleMenu()
		end
	end)
	getgenv().STRIX_KEYBIND_CON = keybindCon]]
rawMaclibSource = rawMaclibSource:gsub(patKeybindBlock, replKeybindBlock, 1)

MacLib = loadstring(rawMaclibSource)()
_G.MacLib = MacLib

-- ==============================================================================
-- 3. STATE & CONFIGURATION MANAGEMENT
-- ==============================================================================
local State = {
    -- Cash Automation
    AutoCollectCash = false,

    -- Repair Automation
    AutoRepair = false,

    -- Research Automation
    AutoUpgradeResearch = false,

    -- Quests Automation
    AutoClaimQuests = false,

    -- Shop Automation
    AutoBuyResidential = false,
    AutoBuyOffices = false,
    AutoBuyMilitary = false,
    AutoBuyMisc = false,
    SelectedResidential = {},
    SelectedOffices = {},
    SelectedMilitary = {},
    SelectedMisc = {},
    BuyAllIfNoneSelected = false,
    BuyInterval = 1.5,
    KeepCashReserve = 10000,

    -- Interface Settings
    Keybind = Enum.KeyCode.RightControl,
    UISize = { Width = 868, Height = 650 },
    AcrylicBlur = true,
    ShowUserInfo = true,
    MobileToggle = true
}

-- Keybind String Resolver
local function ResolveBind(bindName)
    if not bindName or bindName == "Unknown" or bindName == "None" then return nil end
    local okKey, k = pcall(function() return Enum.KeyCode[bindName] end)
    if okKey and k and k ~= Enum.KeyCode.Unknown then return k end
    local okInput, u = pcall(function() return Enum.UserInputType[bindName] end)
    if okInput and u and u ~= Enum.UserInputType.None then return u end
    return nil
end

-- Pre-load Config from Disk before Window Creation (Prevents UI Glitch)
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
local saveDebounce = false

local function SaveConfig()
    if not isScriptRunning or isLoadingConfig then return end
    EnsureFolders()

    local keybindStr = "RightControl"
    if typeof(State.Keybind) == "EnumItem" then
        keybindStr = State.Keybind.Name
    elseif type(State.Keybind) == "string" and State.Keybind ~= "" then
        keybindStr = State.Keybind
    end

    local payload = {}
    for k, v in pairs(State) do
        payload[k] = v
    end
    payload.Keybind = keybindStr

    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if okEnc and encoded and writefile then
        pcall(writefile, ConfigFile, encoded)
    end
end

local function SaveConfigDebounced()
    if not isScriptRunning or isLoadingConfig or saveDebounce then return end
    saveDebounce = true
    task.delay(0.5, function()
        saveDebounce = false
        if isScriptRunning and not isLoadingConfig then SaveConfig() end
    end)
end

-- Periodic Auto-Save
task.spawn(function()
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
-- 4. ANTI-AFK SYSTEM
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

task.spawn(function()
    while isScriptRunning do
        task.wait(300)
        if not isScriptRunning then break end
        SendAntiAfkInput()
    end
end)

-- ==============================================================================
-- 5. WINDOW INITIALIZATION & DIRECTX CRASH PREVENTION
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

-- Completely disable MacLib notifications to prevent CanvasGroup DirectX device lost crashes
Window:SetNotificationsState(false)

-- Safe Window Unload hook
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

-- ==============================================================================
-- 6. RESPONSIVE SCREEN AUTO-SCALE & DRAG-TO-RESIZE ENGINE
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

    -- Clean Exit Button replacement
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

    -- Corner Handle (Bottom-Right)
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

    -- Right Edge Handle
    local rightEdge = Instance.new("TextButton")
    rightEdge.Name = "ResizeHandle_Right"
    rightEdge.AnchorPoint = Vector2.new(1, 0)
    rightEdge.Position = UDim2.new(1, 0, 0, 30)
    rightEdge.Size = UDim2.new(0, 8, 1, -54)
    rightEdge.BackgroundTransparency = 1
    rightEdge.Text = ""
    rightEdge.ZIndex = 99
    rightEdge.Parent = base

    -- Bottom Edge Handle
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
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() mobileGui.DisplayOrder = 999999 end)

    pcall(function() mobileGui.Parent = h end)
    if not mobileGui.Parent then
        mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    getgenv().STRIX_MOBILE_GUI = mobileGui

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
            task.wait(0.25)
        end
    end)

    local function SafeToggle()
        if Window and Window.GetState and Window.SetState then
            local nextState = not Window:GetState()
            Window:SetState(nextState)
            UpdateVisuals(nextState)
        end
    end

    local dragging = false
    local dragStart = nil
    local startPos = nil
    local hasMoved = false

    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
            dragStart = input.Position
            startPos = buttonFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                hasMoved = true
            end
            local cam = workspace.CurrentCamera
            local viewSize = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
            local targetX = math.clamp(startPos.X.Offset + delta.X, 5, math.max(5, viewSize.X - 52))
            local targetY = math.clamp(startPos.Y.Offset + delta.Y, 5, math.max(5, viewSize.Y - 52))
            buttonFrame.Position = UDim2.new(0, targetX, 0, targetY)
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

-- ==============================================================================
-- 8. UI TAB STRUCTURE & FEATURES
-- ==============================================================================
local TabGroup = Window:TabGroup()

local Tabs = {
    Main = TabGroup:Tab({ Name = "Main", Image = "rbxassetid://10709782230" }), -- lucide-home
    Shop = TabGroup:Tab({ Name = "Shop", Image = "rbxassetid://10734952479" }), -- lucide-shopping-cart
    Quests = TabGroup:Tab({ Name = "Quests", Image = "rbxassetid://10734966248" }), -- lucide-star
    Settings = TabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" }) -- lucide-settings
}

-- ------------------------------------------------------------------------------
-- TAB 1: MAIN
-- ------------------------------------------------------------------------------
local MainSections = {
    Cash = Tabs.Main:Section({ Side = "Left" }),
    Repair = Tabs.Main:Section({ Side = "Left" }),
    Research = Tabs.Main:Section({ Side = "Left" }),
    Stats = Tabs.Main:Section({ Side = "Right" })
}

-- [Menu] Cash
MainSections.Cash:Header({ Text = "Cash" })

MainSections.Cash:Toggle({
    Name = "Auto Collect",
    Default = (State.AutoCollectCash == true),
    Callback = function(val)
        State.AutoCollectCash = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoCollectCash")

MainSections.Cash:Button({
    Name = "Collect Cash Now",
    Callback = function()
        local collected = CollectCashFromBuildings()
        if Window and Window.Notify then
            Window:Notify({
                Title = "Cash Collected",
                Description = ("Collected pending cash from %d building(s)"):format(collected),
                Lifetime = 3
            })
        end
    end
})

-- [Menu] Repair
MainSections.Repair:Header({ Text = "Repair" })

MainSections.Repair:Toggle({
    Name = "Auto Repair",
    Default = (State.AutoRepair == true),
    Callback = function(val)
        State.AutoRepair = val
        SaveConfigDebounced()
        if val then
            task.spawn(RepairAllRuins)
        end
    end
}, "Toggle_AutoRepair")

MainSections.Repair:Button({
    Name = "Repair All Ruins Now",
    Callback = function()
        local count = RepairAllRuins()
        if Window and Window.Notify then
            Window:Notify({
                Title = "Repair",
                Description = ("Repaired %d destroyed building(s) / wall(s)"):format(count),
                Lifetime = 3
            })
        end
    end
})

-- [Menu] Research
MainSections.Research:Header({ Text = "Research" })

MainSections.Research:Toggle({
    Name = "Auto Upgrade Research",
    Default = (State.AutoUpgradeResearch == true),
    Callback = function(val)
        State.AutoUpgradeResearch = val
        SaveConfigDebounced()
        if val then
            task.spawn(UpgradeNextResearch)
        end
    end
}, "Toggle_AutoUpgradeResearch")

local ResearchSlotsLabel = MainSections.Research:Label({ Text = "Researchers: 0/1 Active" })
local NextTechLabel = MainSections.Research:Label({ Text = "Next Tech: Detecting..." })

MainSections.Research:Button({
    Name = "Upgrade Next Research Now",
    Callback = function()
        local success, result = UpgradeNextResearch()
        if Window and Window.Notify then
            if success then
                Window:Notify({
                    Title = "Research Started",
                    Description = ("Started research: %s"):format(tostring(result)),
                    Lifetime = 3
                })
            else
                Window:Notify({
                    Title = "Research",
                    Description = tostring(result or "Unable to upgrade research"),
                    Lifetime = 3
                })
            end
        end
    end
})

-- [Menu] Overview & Plot Statistics
MainSections.Stats:Header({ Text = "Plot & Economy Overview" })

local StatLabels = {
    Player = MainSections.Stats:Label({ Text = "Player: " .. tostring(LocalPlayer.Name) }),
    Plot = MainSections.Stats:Label({ Text = "Plot: Detecting..." }),
    BaseHp = MainSections.Stats:Label({ Text = "Base Health: 100%" }),
    Rubble = MainSections.Stats:Label({ Text = "Destroyed Ruins: 0" }),
    Buildings = MainSections.Stats:Label({ Text = "Buildings: 0" }),
    Wallet = MainSections.Stats:Label({ Text = "Wallet Cash: $0" }),
    ResearchCount = MainSections.Stats:Label({ Text = "Techs Researched: 0" })
}

-- Real-time Overview Stats Updater
task.spawn(function()
    while isScriptRunning do
        task.wait(1.0)
        if not isScriptRunning then break end
        pcall(function()
            local plot = GetPlayerPlot()
            local plotName = plot and plot.Name or "Not Claimed"
            local bFolder = plot and plot:FindFirstChild("Buildings")
            local bCount = bFolder and #bFolder:GetChildren() or 0
            local wallet = LocalPlayer:GetAttribute("WalletCash") or 0
            local hp = LocalPlayer:GetAttribute("BaseHealthPercent") or 100
            local rubbles = GetRubbleList()

            if StatLabels.Plot and StatLabels.Plot.UpdateName then
                StatLabels.Plot:UpdateName("Active Plot: " .. plotName)
            end
            if StatLabels.BaseHp and StatLabels.BaseHp.UpdateName then
                StatLabels.BaseHp:UpdateName(("Base Health: %d%%"):format(hp))
            end
            if StatLabels.Rubble and StatLabels.Rubble.UpdateName then
                StatLabels.Rubble:UpdateName(("Destroyed Ruins: %d"):format(#rubbles))
            end
            if StatLabels.Buildings and StatLabels.Buildings.UpdateName then
                StatLabels.Buildings:UpdateName(("Buildings: %d"):format(bCount))
            end
            if StatLabels.Wallet and StatLabels.Wallet.UpdateName then
                StatLabels.Wallet:UpdateName(("Wallet Cash: $%s"):format(FormatNumber(wallet)))
            end
            if StatLabels.ResearchCount and StatLabels.ResearchCount.UpdateName then
                StatLabels.ResearchCount:UpdateName(("Techs Researched: %d"):format(GetOwnedResearchCount()))
            end

            if ResearchSlotsLabel and ResearchSlotsLabel.UpdateName then
                ResearchSlotsLabel:UpdateName(("Researchers: %d/%d Active"):format(GetActiveResearchJobCount(), cachedResearchersMax))
            end

            if NextTechLabel and NextTechLabel.UpdateName then
                local available = GetAvailableResearchNodes()
                local nextTechText = "All Unlocked"
                if #available > 0 then
                    local nextTech = available[1]
                    nextTechText = ("%s ($%s)"):format(nextTech.name, FormatNumber(nextTech.cost))
                end
                NextTechLabel:UpdateName("Next Tech: " .. nextTechText)
            end
        end)
    end
end)

-- ------------------------------------------------------------------------------
-- TAB 2: SHOP
-- ------------------------------------------------------------------------------
local ShopSections = {
    AutoBuy = Tabs.Shop:Section({ Side = "Left" })
}

-- [Menu] Auto Buy
ShopSections.AutoBuy:Header({ Text = "Auto Buy" })

ShopSections.AutoBuy:Toggle({
    Name = "Auto Buy Residential",
    Default = (State.AutoBuyResidential == true),
    Callback = function(val)
        State.AutoBuyResidential = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyResidential")

ShopSections.AutoBuy:Dropdown({
    Name = "Select Residential Items",
    Search = true,
    Multi = true,
    Options = ShopCategoryOptions.residential,
    Default = State.SelectedResidential or {},
    Callback = function(selected)
        State.SelectedResidential = (type(selected) == "table") and selected or {}
        SaveConfigDebounced()
    end
}, "Dropdown_SelectedResidential")

ShopSections.AutoBuy:Toggle({
    Name = "Auto Buy Offices",
    Default = (State.AutoBuyOffices == true),
    Callback = function(val)
        State.AutoBuyOffices = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyOffices")

ShopSections.AutoBuy:Dropdown({
    Name = "Select Offices Items",
    Search = true,
    Multi = true,
    Options = ShopCategoryOptions.offices,
    Default = State.SelectedOffices or {},
    Callback = function(selected)
        State.SelectedOffices = (type(selected) == "table") and selected or {}
        SaveConfigDebounced()
    end
}, "Dropdown_SelectedOffices")

ShopSections.AutoBuy:Toggle({
    Name = "Auto Buy Military",
    Default = (State.AutoBuyMilitary == true),
    Callback = function(val)
        State.AutoBuyMilitary = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyMilitary")

ShopSections.AutoBuy:Dropdown({
    Name = "Select Military Items",
    Search = true,
    Multi = true,
    Options = ShopCategoryOptions.military,
    Default = State.SelectedMilitary or {},
    Callback = function(selected)
        State.SelectedMilitary = (type(selected) == "table") and selected or {}
        SaveConfigDebounced()
    end
}, "Dropdown_SelectedMilitary")

ShopSections.AutoBuy:Toggle({
    Name = "Auto Buy Miscellaneous",
    Default = (State.AutoBuyMisc == true),
    Callback = function(val)
        State.AutoBuyMisc = val
        SaveConfigDebounced()
    end
}, "Toggle_AutoBuyMisc")

ShopSections.AutoBuy:Dropdown({
    Name = "Select Miscellaneous Items",
    Search = true,
    Multi = true,
    Options = ShopCategoryOptions.misc,
    Default = State.SelectedMisc or {},
    Callback = function(selected)
        State.SelectedMisc = (type(selected) == "table") and selected or {}
        SaveConfigDebounced()
    end
}, "Dropdown_SelectedMisc")

-- ------------------------------------------------------------------------------
-- TAB 3: QUESTS
-- ------------------------------------------------------------------------------
local QuestSections = {
    Quests = Tabs.Quests:Section({ Side = "Left" }),
    Status = Tabs.Quests:Section({ Side = "Right" })
}

-- [Menu] Quests
QuestSections.Quests:Header({ Text = "Quests" })

QuestSections.Quests:Toggle({
    Name = "Auto Claim",
    Default = (State.AutoClaimQuests == true),
    Callback = function(val)
        State.AutoClaimQuests = val
        SaveConfigDebounced()
        if val then
            task.spawn(ClaimCompletedQuests)
        end
    end
}, "Toggle_AutoClaimQuests")

QuestSections.Quests:Button({
    Name = "Claim Completed Quests",
    Callback = function()
        local count = ClaimCompletedQuests()
        if Window and Window.Notify then
            Window:Notify({
                Title = "Quests",
                Description = ("Claimed %d completed quest(s)"):format(count),
                Lifetime = 3
            })
        end
    end
})

-- [Menu] Quests Status & Progress
QuestSections.Status:Header({ Text = "Quests Status & Overview" })

local QuestLabels = {
    DailyReady = QuestSections.Status:Label({ Text = "Daily Quests Ready: 0" }),
    LegacyReady = QuestSections.Status:Label({ Text = "Legacy Quests Ready: 0" }),
    TotalDaily = QuestSections.Status:Label({ Text = "Daily Total: 4" }),
    TotalLegacy = QuestSections.Status:Label({ Text = "Legacy Total: 8" })
}

-- Real-time Quest Status Updater
task.spawn(function()
    while isScriptRunning do
        task.wait(1.5)
        if not isScriptRunning then break end
        pcall(function()
            if cachedQuestData then
                local dReady = 0
                local dTotal = 0
                if type(cachedQuestData.daily) == "table" then
                    dTotal = #cachedQuestData.daily
                    for _, q in ipairs(cachedQuestData.daily) do
                        if q.done then dReady = dReady + 1 end
                    end
                end

                local lReady = 0
                local lTotal = 0
                if type(cachedQuestData.legacy) == "table" then
                    lTotal = #cachedQuestData.legacy
                    for _, q in ipairs(cachedQuestData.legacy) do
                        if q.done then lReady = lReady + 1 end
                    end
                end

                if QuestLabels.DailyReady and QuestLabels.DailyReady.UpdateName then
                    QuestLabels.DailyReady:UpdateName(("Daily Quests Ready: %d"):format(dReady))
                end
                if QuestLabels.LegacyReady and QuestLabels.LegacyReady.UpdateName then
                    QuestLabels.LegacyReady:UpdateName(("Legacy Quests Ready: %d"):format(lReady))
                end
                if QuestLabels.TotalDaily and QuestLabels.TotalDaily.UpdateName then
                    QuestLabels.TotalDaily:UpdateName(("Daily Total: %d"):format(dTotal))
                end
                if QuestLabels.TotalLegacy and QuestLabels.TotalLegacy.UpdateName then
                    QuestLabels.TotalLegacy:UpdateName(("Legacy Total: %d"):format(lTotal))
                end
            end
        end)
    end
end)

-- ==============================================================================
-- 9. UNIVERSAL SETTINGS TAB
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
        if Window and Window.Notify then
            Window:Notify({ Title = "Config", Description = "Saved successfully!", Lifetime = 3 })
        end
    end
})

local function LoadConfig()
    if isLoadingConfig then return end
    isLoadingConfig = true
    EnsureFolders()

    local okMain, mainErr = pcall(function()
        if not (isfile and isfile(ConfigFile)) then return end
        local content = readfile(ConfigFile)
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not (ok and type(data) == "table") then return end

        for k, v in pairs(data) do
            if k == "Keybind" then
                local bind = ResolveBind(v)
                if bind and bind ~= Enum.KeyCode.Unknown then
                    State.Keybind = bind
                    if Window and Window.SetKeybind then pcall(function() Window:SetKeybind(bind) end) end
                    if MacLib.Options["Keybind_ToggleUI"] then pcall(function() MacLib.Options["Keybind_ToggleUI"]:Bind(bind) end) end
                end
            elseif State[k] ~= nil then
                State[k] = v
                if MacLib.Options["Toggle_" .. k] then
                    pcall(function() MacLib.Options["Toggle_" .. k]:UpdateState(v == true) end)
                elseif MacLib.Options["Dropdown_" .. k] then
                    pcall(function() MacLib.Options["Dropdown_" .. k]:UpdateSelection(v) end)
                elseif MacLib.Options["Slider_" .. k] then
                    pcall(function() MacLib.Options["Slider_" .. k]:UpdateValue(v) end)
                elseif MacLib.Options["Input_" .. k] then
                    pcall(function() MacLib.Options["Input_" .. k]:UpdateText(tostring(v)) end)
                end
            end
        end

        if data.AcrylicBlur ~= nil and MacLib.Options["Toggle_AcrylicBlur"] then
            pcall(function()
                MacLib.Options["Toggle_AcrylicBlur"]:UpdateState(data.AcrylicBlur == true)
                if Window and Window.SetAcrylicBlurState then Window:SetAcrylicBlurState(data.AcrylicBlur == true) end
            end)
        end
        if data.ShowUserInfo ~= nil and MacLib.Options["Toggle_ShowUserInfo"] then
            pcall(function()
                MacLib.Options["Toggle_ShowUserInfo"]:UpdateState(data.ShowUserInfo ~= false)
                if Window and Window.SetUserInfoState then Window:SetUserInfoState(data.ShowUserInfo ~= false) end
            end)
        end
        if data.MobileToggle ~= nil and MacLib.Options["Toggle_MobileToggle"] then
            pcall(function()
                MacLib.Options["Toggle_MobileToggle"]:UpdateState(data.MobileToggle ~= false)
                if getgenv().STRIX_MOBILE_GUI then getgenv().STRIX_MOBILE_GUI.Enabled = (data.MobileToggle ~= false) end
            end)
        end
    end)

    if not okMain and mainErr then
        warn("[STRIX HUB] LoadConfig error: " .. tostring(mainErr))
    end
    isLoadingConfig = false
end

SettingsSections.Config:Button({
    Name = "Reload Config",
    Callback = function()
        LoadConfig()
        if Window and Window.Notify then
            Window:Notify({ Title = "Config", Description = "Reloaded config!", Lifetime = 3 })
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
-- 10. BACKGROUND WORKERS & LOOPS
-- ==============================================================================
-- 1. Cash Auto Collect Loop
task.spawn(function()
    while isScriptRunning do
        task.wait(1.0)
        if not isScriptRunning then break end
        if State.AutoCollectCash then
            pcall(CollectCashFromBuildings)
        end
    end
end)

-- 2. Repair Auto Repair Loop
task.spawn(function()
    while isScriptRunning do
        task.wait(2.0)
        if not isScriptRunning then break end
        if State.AutoRepair then
            pcall(RepairAllRuins)
        end
    end
end)

-- 3. Research Auto Upgrade Loop
task.spawn(function()
    local lastRefresh = 0
    while isScriptRunning do
        task.wait(2.5)
        if not isScriptRunning then break end
        if State.AutoUpgradeResearch then
            pcall(UpgradeNextResearch)
        end
        if (os.clock() - lastRefresh) > 15 then
            lastRefresh = os.clock()
            if RequestResearchState then
                pcall(function() RequestResearchState:FireServer() end)
            end
        end
    end
end)

-- 4. Quests Auto Claim Loop
task.spawn(function()
    while isScriptRunning do
        task.wait(2.5)
        if not isScriptRunning then break end
        if State.AutoClaimQuests then
            pcall(ClaimCompletedQuests)
        else
            if RequestQuestState then
                pcall(function() RequestQuestState:FireServer() end)
            end
        end
    end
end)

-- 4. Shop Auto Buy Loop
task.spawn(function()
    while isScriptRunning do
        local interval = tonumber(State.BuyInterval) or 1.5
        if interval < 0.3 then interval = 0.3 end
        task.wait(interval)
        if not isScriptRunning then break end

        local anyBuyActive = State.AutoBuyResidential or State.AutoBuyOffices or State.AutoBuyMilitary or State.AutoBuyMisc
        if anyBuyActive then
            if State.AutoBuyResidential then
                pcall(function() BuyNextBuilding("residential") end)
            end
            if State.AutoBuyOffices then
                pcall(function() BuyNextBuilding("offices") end)
            end
            if State.AutoBuyMilitary then
                pcall(function() BuyNextBuilding("military") end)
            end
            if State.AutoBuyMisc then
                pcall(function() BuyNextBuilding("misc") end)
            end
        end

        -- Countdown restock timer
        if cachedRestockTimer > 0 then
            cachedRestockTimer = math.max(0, cachedRestockTimer - interval)
            if cachedRestockTimer <= 0 and RequestStock then
                pcall(function() RequestStock:FireServer() end)
            end
        end
    end
end)

-- 5. Periodic Shop Stock Refresh Loop
task.spawn(function()
    while isScriptRunning do
        task.wait(25)
        if not isScriptRunning then break end
        if RequestStock then
            pcall(function() RequestStock:FireServer() end)
        end
    end
end)

-- Initial Load Config & Select First Tab
LoadConfig()
pcall(function()
    if Tabs.Main and Tabs.Main.Select then
        Tabs.Main:Select()
    end
end)

-- Global Hub Registry
getgenv().STRIX_HUB = {
    Window = Window,
    Tabs = Tabs,
    State = State,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig
}
getgenv().STRIX_HUB_JOB_ID = game.JobId

print("[STRIX HUB] Mini City Wars script loaded successfully!")
