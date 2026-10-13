repeat task.wait() until game:IsLoaded() 

local GITHUB_USER = "Mxvxrixx"
local REPO_NAME   = "strixzy-hub"
local BRANCH      = "main"

local BaseURL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GITHUB_USER, REPO_NAME, BRANCH)

local GameRegistry = {
    -- [Anime Mysterious]
    [117949143041402] = "games/AnimeMysterious.lua", -- Lobby
    [110388679506690] = "games/AnimeMysterious.lua", -- Alt Lobby
    [107610426295102] = "games/AnimeMysterious.lua", -- Gameplay
    [97246719761307]  = "games/AnimeMysterious.lua", -- Secondary Battle

}

local scriptPath = GameRegistry[game.PlaceId]

if scriptPath then
    -- โหลดสคริปต์ประจำแมพนั้นๆ มาทำงาน
    loadstring(game:HttpGet(BaseURL .. scriptPath))()
else
    -- ถ้าเข้าแมพที่ยังไม่รองรับ
    warn("[STRIX HUB] This game is not supported! PlaceId: " .. tostring(game.PlaceId))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "STRIX HUB",
            Text = "Game not supported yet! (ID: " .. tostring(game.PlaceId) .. ")",
            Duration = 5
        })
    end)
end
