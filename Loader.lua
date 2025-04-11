local function decrypt(encrypted, key)
    local result = {}
    for i = 1, #encrypted do
        local char_byte = string.byte(encrypted, i)
        local key_byte = string.byte(key, 1 + (i - 1) % #key)
        table.insert(result, string.char(bit32.bxor(char_byte, key_byte) % 256))
    end
    return table.concat(result)
end

local label = Instance.new("TextLabel", workspace)
while true do
    if game:IsLoaded() and workspace.CurrentCamera then
        label:Destroy()
        break
    end
    label.Text = "Fire~Library is loading, please wait..."
    task.wait()
end

local function get_global_env()
    return (typeof(getfenv().getgenv) == "function" and typeof(getfenv().getgenv()) == "table" and getfenv().getgenv()) or _G
end

local function http_get(url)
    return game:HttpGet(url, true)
end

function urlGet(url)
    local attempts = 0
    local success, result
    while true do
        success, result = pcall(http_get, url)
        if success and result:gsub("\n", ""):gsub("\t", ""):gsub("\r", ""):gsub(" ", "") ~= "" then
            return result
        end
        attempts = attempts + 1
    end
end

function urlLoad(url, ...)
    local code = urlGet(url)
    local success, func = pcall(loadstring, code)
    if not success then
        return urlLoad(url, ...)
    end
    return func(...)
end

local env = get_global_env()
local was_loaded = env.FireHubLoaded
env.FireHubLoaded = true

local notifications
local function notify(title, time)
    notifications.Notifications:Notification({
        Title = title,
        Image = "rbxassetid://14885564557",
        Time = time
    })
end

local function report(data)
    if not getfenv().request then
        return warn("Fire~Library does not support this executor!")
    end
    local response
    pcall(function()
        response = getfenv().request({
            Url = "http://nullfire.xyz/api/report",
            Method = "POST",
            Body = game:GetService("HttpService"):JSONEncode(data),
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
    end)
    return tostring(response.StatusCode):sub(1, 1) ~= "4"
end

local player = game:GetService("Players").LocalPlayer
local function report_error(reason, error)
    env.FireHubLoaded = false
    if notifications then
        notify("NullFire failed to load:\n" .. reason .. "\n\nTry restarting the script!", 10)
    end
    report({
        uid = player.UserId,
        gameName = env.GameName or "Universal",
        jobId = game.JobId,
        placeId = game.PlaceId,
        playersOnline = tostring(#game:GetService("ReplicatedStorage"):GetPlayers() .. "/" .. (env.MaxPlayers or game:GetService("GameSettings").MaxPlayers)),
        device = (game:GetService("UserInputService").KeyboardEnabled and not game:GetService("UserInputService").TouchEnabled and "Computer") or "Mobile",
        executor = (getfenv().identifyexecutor and getfenv().identifyexecutor()) or "Unknown",
        error = error,
        reason = reason,
        type = "BugReport"
    })
end

notifications = urlLoad("http://nullfire.xyz/api/loader")
if not notifications then
    local error_label = Instance.new("TextLabel", workspace)
    error_label.Text = "Fire~Library failed to initilize!\n\n[Sending auto bug report]"
    report_error("Failed to initilize Fire~Library", "Fire~Library failed to initilize!")
    task.wait(5)
    return error_label:Destroy()
end

notify("NullFire Initilization begun!\nDoing some base checks & getting data...")
if was_loaded then
    return notify("NullFire is already loaded!")
end

local player_data_raw = urlGet("http://nullfire.xyz/api/players")
local success, error_msg = pcall(function()
    env.PersonalPlayerData = env.PersonalPlayerData or game:GetService("HttpService"):JSONDecode(player_data_raw)
end)
if not success then
    return report_error("Failed to load player data", error_msg .. "\n\nData: " .. player_data_raw)
end

local player_data = env.PersonalPlayerData
if player_data[tostring(player.UserId)] then
    local user_data = player_data[tostring(player.UserId)]
    if user_data.Admin then
        notify("Ooh, you're an admin, cool!")
    elseif user_data.Ban and user_data.Ban[1] then
        local ban_time = user_data.Ban[1]
        local ban_reason = user_data.Ban[2] or "No reason provided"
        local time_left = ban_time - os.time()
        if time_left > 0 then
            local days = math.floor(time_left / (24 * 60 * 60))
            local hours = math.floor((time_left - (days * 24 * 60 * 60)) / (60 * 60))
            local minutes = math.floor((time_left - (days * 24 * 60 * 60) - (hours * 60 * 60)) / 60)
            local seconds = time_left - (days * 24 * 60 * 60) - (hours * 60 * 60) - (minutes * 60)
            return notify("Whoops! Initilization has stopped because:\nYou are banned from NullFire for " .. days .. "D " .. hours .. "H " .. minutes .. "M " .. seconds .. "S because:\n" .. ban_reason, 30)
        end
    end
end

local scripts_raw = game:HttpGet("http://nullfire.xyz/api/scripts")
local scripts_data
success, error_msg = pcall(function()
    scripts_data = game:GetService("HttpService"):JSONDecode(scripts_raw)
end)
if not success then
    report_error("Failed to decode JSON from scripts API", "```\n" .. error_msg .. "\n\nData: " .. scripts_raw .. "\n```")
    return
end

if not scripts_data.Works or typeof(scripts_data.Works) == "string" then
    return notify("Failed to load:\nThe script is currently down!" .. (typeof(scripts_data.Works) == "string" and "\n" .. scripts_data.Works or ""))
end

notify("NullFire Initilization complete!\nFetching...")
for game_name, game_info in pairs(scripts_data) do
    if typeof(game_info) == "table" and table.find(game_info, game.PlaceId) then
        if not game_info[1] or typeof(game_info[1]) == "string" then
            return notify("Failed to load:\n" .. game_name .. " is not supported by NullFire!" .. (typeof(game_info[1]) ~= "string" and "" or game_info[1]))
        end
        env.GameName = game_name
        local script_url = "http://nullfire.xyz/api/gamescripts/" .. game_name .. ".lua"
        notify("NullFire Initilization done!\nLoading script for: " .. game_name .. "\n\n(" .. script_url .. ")")
        return urlLoad(script_url)
    end
end

notify("Failed to load:\nThe game is not supported!")
