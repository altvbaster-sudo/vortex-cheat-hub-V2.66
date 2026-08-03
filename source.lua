local VERSION = "3.0"

-- ============================================================
--  KEY SYSTEM (Supabase Integration)
-- ============================================================
local SUPABASE_URL = "https://vcefcicgwasmgicrzdql.supabase.co"
local SUPABASE_ANON_KEY = "sb_publishable__Ufbp24bKyIRLiwlvPwUUQ_a0irzAGF"

local HttpService = game:GetService("HttpService")

local function supabaseRequest(method, endpoint, data)
    local url = SUPABASE_URL .. endpoint
    local headers = {
        ["Content-Type"] = "application/json",
        ["apikey"] = SUPABASE_ANON_KEY,
        ["Authorization"] = "Bearer " .. SUPABASE_ANON_KEY,
        ["Prefer"] = "return=representation"
    }
    local body = data and HttpService:JSONEncode(data) or nil

    local function doRequest()
        if syn and syn.request then
            local response = syn.request({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
            return response
        end
        if http and http.request then
            local response = http.request({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
            return response
        end
        if request then
            local response = request({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
            return response
        end
        local options = {
            Url = url,
            Method = method,
            Headers = headers,
        }
        if body then options.Body = body end
        return HttpService:RequestAsync(options)
    end

    local success, response = pcall(doRequest)
    if not success then
        return nil, "Network error: " .. tostring(response)
    end

    if response.Success then
        if response.Body and response.Body ~= "" then
            local decoded = HttpService:JSONDecode(response.Body)
            return decoded, nil
        end
        return {}, nil
    else
        return nil, "HTTP " .. response.StatusCode .. ": " .. response.Body
    end
end

local function isKeyExpired(keyData)
    if not keyData.expires then return false end
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec = keyData.expires:match(pattern)
    if not year then return false end
    local expiryTime = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
    return os.time() > expiryTime
end

local function validateKey(keyData, userId)
    if isKeyExpired(keyData) then
        return false, "This key has expired!"
    end

    if keyData.user_id == nil or keyData.user_id == "" then
        if keyData.status == "active" then
            return true, "Valid unclaimed key"
        elseif keyData.status == "revoked" then
            return false, "This key has been revoked!"
        elseif keyData.status == "inactive" then
            return false, "This key is inactive!"
        elseif keyData.status == "used" then
            return false, "This key has already been used!"
        else
            return false, "Invalid key status!"
        end
    else
        if keyData.user_id == userId then
            if keyData.status == "revoked" then
                return false, "This key has been revoked!"
            elseif keyData.status == "inactive" then
                return false, "This key is inactive!"
            else
                return true, "Valid owned key"
            end
        else
            return false, "This key belongs to another user!"
        end
    end
end

local function getPlayerKey(userId)
    local endpoint = "/rest/v1/keys?user_id=eq." .. userId .. "&select=*"
    local result, err = supabaseRequest("GET", endpoint)
    if not result then
        return nil, err
    end
    if #result == 0 then
        return nil, "No key found"
    end
    return result[1], nil
end

local function redeemKey(key, userId, username)
    local endpoint = "/rest/v1/keys?key=eq." .. key .. "&select=*"
    local result, err = supabaseRequest("GET", endpoint)
    if not result or #result == 0 then
        return nil, "Invalid key!"
    end
    local keyData = result[1]

    local valid, msg = validateKey(keyData, userId)
    if not valid then
        return nil, msg
    end

    if keyData.user_id == userId then
        return keyData, nil, "already_owned"
    end

    local updateData = {
        user_id = userId,
        username = username,
        status = "used"
    }
    local updateEndpoint = "/rest/v1/keys?key=eq." .. key
    local updateResult, err = supabaseRequest("PATCH", updateEndpoint, updateData)
    if not updateResult then
        return nil, "Failed to redeem key: " .. tostring(err)
    end

    local newResult, err = supabaseRequest("GET", "/rest/v1/keys?key=eq." .. key)
    if newResult and #newResult > 0 then
        return newResult[1], nil, nil
    else
        return nil, "Key redeemed but data not found"
    end
end

local currentKeyData = nil

-- ============================================================
--  END KEY SYSTEM
-- ============================================================

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local sessionStart = tick()

player.CharacterAdded:Connect(function(c)
    character = c
    humanoid = c:WaitForChild("Humanoid")
    rootPart = c:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
--  CONFIGURATION - FIXED
-- ============================================================
local cfg = {
    -- ESP
    esp = true,
    espBoxes = true,
    espNames = true,
    espHealth = true,
    espTracers = false,
    espBones = false,
    espDistance = true,
    rainbowEsp = false,
    espMaxDistance = 2000,
    espMaxPlayers = 30,
    espGlow = true,
    espBoxStyle = "corner",
    
    -- Aimbot
    aimbot = false,
    aimbotFOV = 120,
    aimbotSmooth = 5,
    aimbotPart = "HumanoidRootPart",
    aimbotTeamCheck = true,
    aimbotPrediction = true,
    softAim = false,
    softAimStr = 5,
    silentAim = false,
    
    -- Movement
    noclip = false,
    fly = false,
    flySpeed = 60,
    speed = false,
    speedVal = 32,
    jumpPower = false,
    jumpVal = 100,
    infiniteJump = false,
    gravity = false,
    gravityVal = 100,
    noFallDamage = false,
    autoSprint = false,
    thirdPerson = false,
    antiAfk = false,
    
    -- Combat
    hitboxExpander = false,
    hitboxSize = 10,
    spinBot = false,
    spinSpeed = 10,
    killAura = false,
    killAuraRange = 20,
    
    -- Visuals
    fovChanger = false,
    fovVal = 70,
    fullbright = false,
    spamClick = false,
    invViewer = false,
    crosshair = false,
    crosshairSize = 10,
}

local DEFAULT_GRAVITY = workspace.Gravity
local panicOn = false
local savedState = {}

local TOGGLEABLE_KEYS = {
    "esp","espBoxes","espNames","espHealth","espTracers","espBones","espDistance","rainbowEsp",
    "aimbot","softAim","silentAim","noclip","fly","speed","jumpPower","infiniteJump","gravity",
    "noFallDamage","autoSprint","thirdPerson","antiAfk","hitboxExpander","spinBot","killAura",
    "fovChanger","fullbright","spamClick","aimbotTeamCheck","invViewer","crosshair",
}

local function setPanic(on)
    panicOn = on
    if on then
        for _, k in ipairs(TOGGLEABLE_KEYS) do savedState[k] = cfg[k]; cfg[k] = false end
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        workspace.Gravity = DEFAULT_GRAVITY
        Lighting.Brightness = 1
        Camera.FieldOfView = 70
    else
        for _, k in ipairs(TOGGLEABLE_KEYS) do
            if savedState[k] ~= nil then cfg[k] = savedState[k] end
        end
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum then
            if cfg.speed then hum.WalkSpeed = cfg.speedVal end
            if cfg.jumpPower then hum.JumpPower = cfg.jumpVal end
        end
        if cfg.gravity then workspace.Gravity = DEFAULT_GRAVITY * (cfg.gravityVal / 100) end
        if cfg.fovChanger then Camera.FieldOfView = cfg.fovVal end
        if cfg.fullbright then
            Lighting.Brightness = 10
            Lighting.ClockTime = 14
        end
    end
end

-- ============================================================
--  FOV CIRCLE
-- ============================================================
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "FOV"
fovGui.ResetOnSpawn = false
fovGui.DisplayOrder = 5
fovGui.IgnoreGuiInset = true
fovGui.Parent = player.PlayerGui

local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.ZIndex = 5
fovCircle.Visible = false
fovCircle.Parent = fovGui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovCircle)
fovStroke.Color = Color3.fromRGB(99, 102, 241)
fovStroke.Thickness = 1
fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function updateFOVCircle()
    local vis = cfg.aimbot or cfg.softAim or cfg.silentAim
    fovCircle.Visible = vis
    if vis then
        local r = cfg.aimbotFOV
        local vp = Camera.ViewportSize
        fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)
        fovCircle.Position = UDim2.new(0, vp.X / 2 - r, 0, vp.Y / 2 - r)
    end
end

-- ============================================================
--  CROSSHAIR
-- ============================================================
local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "Crosshair"
crosshairGui.ResetOnSpawn = false
crosshairGui.DisplayOrder = 10
crosshairGui.IgnoreGuiInset = true
crosshairGui.Parent = player.PlayerGui

local chH = Instance.new("Frame", crosshairGui)
chH.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
chH.BorderSizePixel = 0
chH.Visible = false

local chV = Instance.new("Frame", crosshairGui)
chV.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
chV.BorderSizePixel = 0
chV.Visible = false

RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local s = cfg.crosshairSize
    
    chH.Visible = cfg.crosshair
    chV.Visible = cfg.crosshair
    
    if cfg.crosshair then
        chH.Size = UDim2.new(0, s * 2, 0, 2)
        chH.Position = UDim2.new(0, cx - s, 0, cy - 1)
        chV.Size = UDim2.new(0, 2, 0, s * 2)
        chV.Position = UDim2.new(0, cx - 1, 0, cy - s)
    end
end)

-- ============================================================
--  FLY SYSTEM
-- ============================================================
local flyPart, flyWeld, flyVelocity, flyConn = nil, nil, nil, nil

local function stopFly()
    cfg.fly = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyPart then flyPart:Destroy(); flyPart = nil end
    flyWeld = nil; flyVelocity = nil
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
end

local function startFly()
    local root = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    cfg.fly = true
    
    flyPart = Instance.new("Part")
    flyPart.Name = "Fly"
    flyPart.Size = Vector3.new(1, 0.2, 1)
    flyPart.Transparency = 1
    flyPart.CanCollide = false
    flyPart.Anchored = false
    flyPart.CFrame = root.CFrame
    flyPart.Parent = workspace
    
    flyVelocity = Instance.new("BodyVelocity", flyPart)
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyVelocity.P = 1e4
    
    flyWeld = Instance.new("WeldConstraint", flyPart)
    flyWeld.Part0 = flyPart
    flyWeld.Part1 = root
    
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    
    flyConn = RunService.RenderStepped:Connect(function()
        if not cfg.fly then stopFly(); return end
        local cam = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        flyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * cfg.flySpeed or Vector3.zero
    end)
end

-- ============================================================
--  ESP SYSTEM - CLEAN VERSION
-- ============================================================
local espGui = Instance.new("ScreenGui")
espGui.Name = "ESP"
espGui.ResetOnSpawn = false
espGui.Parent = player.PlayerGui

local espObjects = {}

local function createESPObject()
    local obj = {
        BoxTL = Instance.new("Frame", espGui),
        BoxTR = Instance.new("Frame", espGui),
        BoxBL = Instance.new("Frame", espGui),
        BoxBR = Instance.new("Frame", espGui),
        HealthBG = Instance.new("Frame", espGui),
        HealthBar = Instance.new("Frame", espGui),
        NameLabel = Instance.new("TextLabel", espGui),
        Tracer = Instance.new("Frame", espGui),
        Glow = Instance.new("Frame", espGui),
        Bones = {}
    }
    
    for _, f in pairs({obj.BoxTL, obj.BoxTR, obj.BoxBL, obj.BoxBR}) do
        f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        f.BackgroundTransparency = 0
        f.BorderSizePixel = 0
        f.Size = UDim2.new(0, 0, 0, 0)
        f.Visible = false
    end
    
    obj.HealthBG.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    obj.HealthBG.BorderSizePixel = 0
    obj.HealthBG.Visible = false
    
    obj.HealthBar.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    obj.HealthBar.BorderSizePixel = 0
    obj.HealthBar.Visible = false
    
    obj.NameLabel.BackgroundTransparency = 1
    obj.NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    obj.NameLabel.TextStrokeTransparency = 0
    obj.NameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    obj.NameLabel.TextSize = 12
    obj.NameLabel.Font = Enum.Font.GothamBold
    obj.NameLabel.Size = UDim2.new(0, 300, 0, 16)
    obj.NameLabel.TextXAlignment = Enum.TextXAlignment.Center
    obj.NameLabel.Visible = false
    
    obj.Tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    obj.Tracer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    obj.Tracer.BackgroundTransparency = 0
    obj.Tracer.BorderSizePixel = 0
    obj.Tracer.Size = UDim2.new(0, 0, 0, 1)
    obj.Tracer.Visible = false
    
    obj.Glow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    obj.Glow.BackgroundTransparency = 0.7
    obj.Glow.BorderSizePixel = 0
    obj.Glow.Size = UDim2.new(0, 0, 0, 0)
    obj.Glow.Visible = false
    
    for i = 1, 15 do
        local bone = Instance.new("Frame", espGui)
        bone.AnchorPoint = Vector2.new(0.5, 0.5)
        bone.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
        bone.BackgroundTransparency = 0
        bone.BorderSizePixel = 0
        bone.Size = UDim2.new(0, 0, 0, 1)
        bone.Visible = false
        obj.Bones[i] = bone
    end
    
    return obj
end

local bonePairs = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"}
}

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then espObjects[p] = createESPObject() end
end

Players.PlayerAdded:Connect(function(p) espObjects[p] = createESPObject() end)
Players.PlayerRemoving:Connect(function(p) espObjects[p] = nil end)

local function w2s(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), vis
end

local function getBox(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local valid = false
    
    for _, part in pairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local pos, vis = Camera:WorldToViewportPoint(part.Position)
            if vis then
                valid = true
                minX = math.min(minX, pos.X)
                minY = math.min(minY, pos.Y)
                maxX = math.max(maxX, pos.X)
                maxY = math.max(maxY, pos.Y)
            end
        end
    end
    
    if valid then
        return {x = minX, y = minY, w = maxX - minX, h = maxY - minY}
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    if not cfg.esp then
        for _, obj in pairs(espObjects) do
            if obj then
                obj.BoxTL.Visible = false; obj.BoxTR.Visible = false
                obj.BoxBL.Visible = false; obj.BoxBR.Visible = false
                obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
                obj.NameLabel.Visible = false; obj.Tracer.Visible = false
                obj.Glow.Visible = false
                for _, b in ipairs(obj.Bones) do b.Visible = false end
            end
        end
        return
    end
    
    local center = Camera.ViewportSize / 2
    local count = 0
    
    for plr, obj in pairs(espObjects) do
        if count >= cfg.espMaxPlayers then break end
        
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if not (char and hum and root) or hum.Health <= 0 then
            obj.BoxTL.Visible = false; obj.BoxTR.Visible = false
            obj.BoxBL.Visible = false; obj.BoxBR.Visible = false
            obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
            obj.NameLabel.Visible = false; obj.Tracer.Visible = false
            obj.Glow.Visible = false
            for _, b in ipairs(obj.Bones) do b.Visible = false end
            continue
        end
        
        local dist = (root.Position - rootPart.Position).Magnitude
        if dist > cfg.espMaxDistance then
            obj.BoxTL.Visible = false; obj.BoxTR.Visible = false
            obj.BoxBL.Visible = false; obj.BoxBR.Visible = false
            obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
            obj.NameLabel.Visible = false; obj.Tracer.Visible = false
            obj.Glow.Visible = false
            for _, b in ipairs(obj.Bones) do b.Visible = false end
            continue
        end
        
        local rootPos, onScreen = w2s(root.Position)
        if not onScreen then
            obj.BoxTL.Visible = false; obj.BoxTR.Visible = false
            obj.BoxBL.Visible = false; obj.BoxBR.Visible = false
            obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
            obj.NameLabel.Visible = false; obj.Tracer.Visible = false
            obj.Glow.Visible = false
            for _, b in ipairs(obj.Bones) do b.Visible = false end
            continue
        end
        
        count = count + 1
        
        -- Color
        local color
        if cfg.rainbowEsp then
            color = Color3.fromHSV((tick() * 0.05) % 1, 1, 1)
        elseif plr.Team then
            color = plr.Team.TeamColor.Color
        else
            color = Color3.fromRGB(255, 255, 255)
        end
        
        local box = getBox(char)
        if not box then continue end
        
        local x, y, w, h = box.x, box.y, box.w, box.h
        local t = 2
        local cs = math.min(10, w / 4)
        
        -- GLOW
        if cfg.espGlow then
            obj.Glow.Position = UDim2.new(0, x - 8, 0, y - 8)
            obj.Glow.Size = UDim2.new(0, w + 16, 0, h + 16)
            obj.Glow.BackgroundColor3 = color
            obj.Glow.Visible = true
        else
            obj.Glow.Visible = false
        end
        
        -- BOXES
        if cfg.espBoxes then
            if cfg.espBoxStyle == "full" then
                obj.BoxTL.Position = UDim2.new(0, x, 0, y)
                obj.BoxTL.Size = UDim2.new(0, w, 0, t)
                obj.BoxTL.BackgroundColor3 = color
                obj.BoxTL.Visible = true
                
                obj.BoxTR.Position = UDim2.new(0, x, 0, y + h - t)
                obj.BoxTR.Size = UDim2.new(0, w, 0, t)
                obj.BoxTR.BackgroundColor3 = color
                obj.BoxTR.Visible = true
                
                obj.BoxBL.Position = UDim2.new(0, x, 0, y)
                obj.BoxBL.Size = UDim2.new(0, t, 0, h)
                obj.BoxBL.BackgroundColor3 = color
                obj.BoxBL.Visible = true
                
                obj.BoxBR.Position = UDim2.new(0, x + w - t, 0, y)
                obj.BoxBR.Size = UDim2.new(0, t, 0, h)
                obj.BoxBR.BackgroundColor3 = color
                obj.BoxBR.Visible = true
            else
                obj.BoxTL.Position = UDim2.new(0, x, 0, y)
                obj.BoxTL.Size = UDim2.new(0, cs, 0, t)
                obj.BoxTL.BackgroundColor3 = color
                obj.BoxTL.Visible = true
                
                obj.BoxTR.Position = UDim2.new(0, x + w - cs, 0, y)
                obj.BoxTR.Size = UDim2.new(0, cs, 0, t)
                obj.BoxTR.BackgroundColor3 = color
                obj.BoxTR.Visible = true
                
                obj.BoxBL.Position = UDim2.new(0, x, 0, y + h - t)
                obj.BoxBL.Size = UDim2.new(0, cs, 0, t)
                obj.BoxBL.BackgroundColor3 = color
                obj.BoxBL.Visible = true
                
                obj.BoxBR.Position = UDim2.new(0, x + w - cs, 0, y + h - t)
                obj.BoxBR.Size = UDim2.new(0, cs, 0, t)
                obj.BoxBR.BackgroundColor3 = color
                obj.BoxBR.Visible = true
            end
        else
            obj.BoxTL.Visible = false; obj.BoxTR.Visible = false
            obj.BoxBL.Visible = false; obj.BoxBR.Visible = false
        end
        
        -- HEALTH
        if cfg.espHealth then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local healthColor = Color3.fromHSV(0.3 * pct, 1, 0.6)
            local bw, bh = 40, 3
            local hx = x + (w / 2) - (bw / 2)
            local hy = y - 10
            
            obj.HealthBG.Position = UDim2.new(0, hx, 0, hy)
            obj.HealthBG.Size = UDim2.new(0, bw, 0, bh)
            obj.HealthBG.Visible = true
            
            obj.HealthBar.Position = UDim2.new(0, hx, 0, hy)
            obj.HealthBar.Size = UDim2.new(0, bw * pct, 0, bh)
            obj.HealthBar.BackgroundColor3 = healthColor
            obj.HealthBar.Visible = true
        else
            obj.HealthBG.Visible = false
            obj.HealthBar.Visible = false
        end
        
        -- NAME
        if cfg.espNames then
            local text = plr.Name
            if cfg.espDistance then
                text = text .. " | " .. math.floor(dist) .. "m"
            end
            obj.NameLabel.Text = text
            obj.NameLabel.TextColor3 = color
            obj.NameLabel.Position = UDim2.new(0, x + (w/2) - 150, 0, y - 30)
            obj.NameLabel.Visible = true
        else
            obj.NameLabel.Visible = false
        end
        
        -- TRACER
        if cfg.espTracers then
            local x1, y1 = center.X, center.Y
            local x2, y2 = x + (w/2), y + h
            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            
            obj.Tracer.Position = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
            obj.Tracer.Size = UDim2.new(0, len, 0, 1)
            obj.Tracer.Rotation = math.deg(math.atan2(dy, dx))
            obj.Tracer.BackgroundColor3 = color
            obj.Tracer.Visible = true
        else
            obj.Tracer.Visible = false
        end
        
        -- BONES
        if cfg.espBones then
            for i, pair in ipairs(bonePairs) do
                local pA = char:FindFirstChild(pair[1])
                local pB = char:FindFirstChild(pair[2])
                if pA and pB then
                    local p1, v1 = w2s(pA.Position)
                    local p2, v2 = w2s(pB.Position)
                    if v1 and v2 then
                        local dx, dy = p2.X - p1.X, p2.Y - p1.Y
                        local len = math.sqrt(dx * dx + dy * dy)
                        local bone = obj.Bones[i]
                        bone.Position = UDim2.new(0, (p1.X + p2.X) / 2, 0, (p1.Y + p2.Y) / 2)
                        bone.Size = UDim2.new(0, len, 0, 1)
                        bone.Rotation = math.deg(math.atan2(dy, dx))
                        bone.BackgroundColor3 = color
                        bone.Visible = true
                    else
                        obj.Bones[i].Visible = false
                    end
                else
                    obj.Bones[i].Visible = false
                end
            end
        else
            for _, b in ipairs(obj.Bones) do b.Visible = false end
        end
    end
end)

-- ============================================================
--  AIMBOT
-- ============================================================
local function getTarget()
    local best, bestDist = nil, math.huge
    local center = Camera.ViewportSize / 2
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        if cfg.aimbotTeamCheck and player.Team and plr.Team == player.Team then continue end
        
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local aimPart = char and char:FindFirstChild(cfg.aimbotPart)
        if not aimPart then aimPart = char and char:FindFirstChild("HumanoidRootPart") end
        if not (char and hum and aimPart) or hum.Health <= 0 then continue end
        
        local targetPos = aimPart.Position
        if cfg.aimbotPrediction then
            local vel = aimPart.Velocity or Vector3.new(0, 0, 0)
            targetPos = targetPos + vel * 0.12
        end
        
        local pos, vis = Camera:WorldToViewportPoint(targetPos)
        if not vis then continue end
        
        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
        if dist < cfg.aimbotFOV and dist < bestDist then
            best = {pos = targetPos}
            bestDist = dist
        end
    end
    
    return best
end

RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    local target = getTarget()
    if not target then return end
    
    if cfg.aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local smooth = cfg.aimbotSmooth / 10
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.pos), smooth)
    end
    
    if cfg.softAim and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local smooth = math.clamp(cfg.softAimStr / 50, 0.02, 0.3)
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.pos), smooth)
    end
    
    if cfg.silentAim then
        local savedCF = Camera.CFrame
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.pos)
        task.defer(function()
            if cfg.silentAim then Camera.CFrame = savedCF end
        end)
    end
end)

-- ============================================================
--  MOVEMENT SYSTEMS
-- ============================================================
RunService.RenderStepped:Connect(function()
    if cfg.thirdPerson and character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            Camera.CameraSubject = root
            Camera.CameraType = Enum.CameraType.Custom
        end
    end
    
    if cfg.autoSprint and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = hum.MoveDirection.Magnitude > 0 and cfg.speedVal or 16
        end
    end
    
    if cfg.speed and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = cfg.speedVal end
    end
    
    if cfg.jumpPower and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = cfg.jumpVal end
    end
    
    if cfg.gravity then
        workspace.Gravity = DEFAULT_GRAVITY * (cfg.gravityVal / 100)
    end
    
    if cfg.fovChanger then
        Camera.FieldOfView = cfg.fovVal
    end
    
    if cfg.fullbright then
        Lighting.Brightness = 10
        Lighting.ClockTime = 14
    else
        Lighting.Brightness = 1
    end
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.infiniteJump and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function()
    if cfg.noclip and character then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
    
    if cfg.noFallDamage and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end
    end
end)

player.Idled:Connect(function()
    if cfg.antiAfk then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Jump = true end
    end
end)

-- ============================================================
--  HITBOX EXPANDER
-- ============================================================
local hitboxParts = {}

local function removeHitbox(plr)
    if hitboxParts[plr] then
        hitboxParts[plr]:Destroy()
        hitboxParts[plr] = nil
    end
end

local function buildHitbox(plr)
    if plr == player then return end
    removeHitbox(plr)
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local hb = Instance.new("Part")
    hb.Name = "VortexHitbox"
    hb.Size = Vector3.new(cfg.hitboxSize, cfg.hitboxSize, cfg.hitboxSize)
    hb.Transparency = 1
    hb.CanCollide = false
    hb.CastShadow = false
    hb.Anchored = false
    hb.CFrame = root.CFrame
    hb.Parent = workspace
    
    local weld = Instance.new("WeldConstraint", hb)
    weld.Part0 = hb
    weld.Part1 = root
    
    hitboxParts[plr] = hb
end

RunService.Heartbeat:Connect(function()
    if cfg.hitboxExpander then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and not hitboxParts[p] then buildHitbox(p) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do removeHitbox(p) end
    end
end)

-- ============================================================
--  KILL AURA
-- ============================================================
RunService.Heartbeat:Connect(function()
    if cfg.killAura then
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == player then continue end
                local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                local pHum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if pRoot and pHum and pHum.Health > 0 then
                    local d = (pRoot.Position - myRoot.Position).Magnitude
                    if d < cfg.killAuraRange then
                        local tool = character:FindFirstChildOfClass("Tool")
                        if tool then
                            for _, obj in ipairs(tool:GetDescendants()) do
                                if obj:IsA("RemoteEvent") then
                                    pcall(function() obj:FireServer() end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
--  SPIN BOT
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if cfg.spinBot then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(cfg.spinSpeed * dt * 60), 0)
        end
    end
end)

-- ============================================================
--  RAYFIELD UI - ALL TABS WORKING
-- ============================================================
local function createMainMenu()
    local Window = Rayfield:CreateWindow({
        Name = "Vortex Hub v" .. VERSION,
        LoadingTitle = "Vortex Hub",
        LoadingSubtitle = "v" .. VERSION .. "  •  Join the Discord!",
        Theme = "Default",
        DisableRayfieldPrompts = false,
        DisableBuildWarnings = true,
    })

    local menuOpen = true
    UserInputService.InputBegan:Connect(function(input, gp)
        if input.KeyCode == Enum.KeyCode.Semicolon then
            menuOpen = not menuOpen
            local gui = player.PlayerGui:FindFirstChild("Rayfield")
            if gui then gui.Enabled = menuOpen end
        end
    end)

    -- ====== ESP TAB ======
    local TabESP = Window:CreateTab("ESP", 4483362458)
    
    TabESP:CreateSection("ESP Settings")
    TabESP:CreateToggle({Name="Enable ESP", CurrentValue=cfg.esp, Callback=function(v) cfg.esp = v end})
    TabESP:CreateToggle({Name="Boxes", CurrentValue=cfg.espBoxes, Callback=function(v) cfg.espBoxes = v end})
    TabESP:CreateToggle({Name="Names", CurrentValue=cfg.espNames, Callback=function(v) cfg.espNames = v end})
    TabESP:CreateToggle({Name="Health Bars", CurrentValue=cfg.espHealth, Callback=function(v) cfg.espHealth = v end})
    TabESP:CreateToggle({Name="Tracers", CurrentValue=cfg.espTracers, Callback=function(v) cfg.espTracers = v end})
    TabESP:CreateToggle({Name="Bones", CurrentValue=cfg.espBones, Callback=function(v) cfg.espBones = v end})
    TabESP:CreateToggle({Name="Distance", CurrentValue=cfg.espDistance, Callback=function(v) cfg.espDistance = v end})
    TabESP:CreateToggle({Name="Rainbow ESP", CurrentValue=cfg.rainbowEsp, Callback=function(v) cfg.rainbowEsp = v end})
    TabESP:CreateToggle({Name="Glow Effect", CurrentValue=cfg.espGlow, Callback=function(v) cfg.espGlow = v end})
    
    TabESP:CreateDropdown({
        Name="Box Style",
        Options={"corner", "full"},
        CurrentOption={cfg.espBoxStyle},
        Callback=function(v)
            if type(v) == "table" then v = v[1] end
            cfg.espBoxStyle = v
        end
    })
    
    TabESP:CreateSection("Performance")
    TabESP:CreateSlider({
        Name="Max Distance",
        Range={100, 5000},
        Increment=50,
        CurrentValue=cfg.espMaxDistance,
        Callback=function(v) cfg.espMaxDistance = v end
    })
    TabESP:CreateSlider({
        Name="Max Players",
        Range={5, 50},
        Increment=1,
        CurrentValue=cfg.espMaxPlayers,
        Callback=function(v) cfg.espMaxPlayers = v end
    })

    -- ====== AIMBOT TAB ======
    local TabAimbot = Window:CreateTab("Aimbot", 4483362458)
    
    TabAimbot:CreateSection("Aimbot")
    TabAimbot:CreateToggle({Name="Aimbot [Hold RMB]", CurrentValue=cfg.aimbot, Callback=function(v) cfg.aimbot = v end})
    TabAimbot:CreateToggle({Name="Soft Aim [Hold LMB]", CurrentValue=cfg.softAim, Callback=function(v) cfg.softAim = v end})
    TabAimbot:CreateToggle({Name="Silent Aim", CurrentValue=cfg.silentAim, Callback=function(v) cfg.silentAim = v end})
    TabAimbot:CreateToggle({Name="AI Prediction", CurrentValue=cfg.aimbotPrediction, Callback=function(v) cfg.aimbotPrediction = v end})
    TabAimbot:CreateToggle({Name="Team Check", CurrentValue=cfg.aimbotTeamCheck, Callback=function(v) cfg.aimbotTeamCheck = v end})
    
    TabAimbot:CreateDropdown({
        Name="Aim Part",
        Options={"Head", "HumanoidRootPart", "UpperTorso"},
        CurrentOption={cfg.aimbotPart},
        Callback=function(v)
            if type(v) == "table" then v = v[1] end
            cfg.aimbotPart = v
        end
    })
    
    TabAimbot:CreateSlider({Name="FOV", Range={10, 500}, Increment=5, CurrentValue=cfg.aimbotFOV, Callback=function(v) cfg.aimbotFOV = v end})
    TabAimbot:CreateSlider({Name="Smoothness", Range={1, 10}, Increment=1, CurrentValue=cfg.aimbotSmooth, Callback=function(v) cfg.aimbotSmooth = v end})
    TabAimbot:CreateSlider({Name="Soft Aim Strength", Range={1, 10}, Increment=1, CurrentValue=cfg.softAimStr, Callback=function(v) cfg.softAimStr = v end})

    -- ====== MOVEMENT TAB ======
    local TabMovement = Window:CreateTab("Movement", 4483362458)
    
    TabMovement:CreateSection("Movement")
    TabMovement:CreateToggle({Name="Fly [V]", CurrentValue=cfg.fly, Callback=function(v) cfg.fly = v; if v then startFly() else stopFly() end end})
    TabMovement:CreateToggle({Name="Speed Hack", CurrentValue=cfg.speed, Callback=function(v) cfg.speed = v end})
    TabMovement:CreateToggle({Name="Jump Power", CurrentValue=cfg.jumpPower, Callback=function(v) cfg.jumpPower = v end})
    TabMovement:CreateToggle({Name="Infinite Jump", CurrentValue=cfg.infiniteJump, Callback=function(v) cfg.infiniteJump = v end})
    TabMovement:CreateToggle({Name="Noclip", CurrentValue=cfg.noclip, Callback=function(v) cfg.noclip = v end})
    TabMovement:CreateToggle({Name="No Fall Damage", CurrentValue=cfg.noFallDamage, Callback=function(v) cfg.noFallDamage = v end})
    TabMovement:CreateToggle({Name="Auto Sprint", CurrentValue=cfg.autoSprint, Callback=function(v) cfg.autoSprint = v end})
    TabMovement:CreateToggle({Name="Third Person", CurrentValue=cfg.thirdPerson, Callback=function(v) cfg.thirdPerson = v end})
    TabMovement:CreateToggle({Name="Anti-AFK", CurrentValue=cfg.antiAfk, Callback=function(v) cfg.antiAfk = v end})
    TabMovement:CreateToggle({Name="Gravity Hack", CurrentValue=cfg.gravity, Callback=function(v) cfg.gravity = v end})
    
    TabMovement:CreateSection("Sliders")
    TabMovement:CreateSlider({Name="Fly Speed", Range={10, 300}, Increment=5, CurrentValue=cfg.flySpeed, Callback=function(v) cfg.flySpeed = v end})
    TabMovement:CreateSlider({Name="Walk Speed", Range={16, 200}, Increment=1, CurrentValue=cfg.speedVal, Callback=function(v) cfg.speedVal = v end})
    TabMovement:CreateSlider({Name="Jump Height", Range={50, 500}, Increment=5, CurrentValue=cfg.jumpVal, Callback=function(v) cfg.jumpVal = v end})
    TabMovement:CreateSlider({Name="Gravity %", Range={0, 200}, Increment=5, CurrentValue=cfg.gravityVal, Callback=function(v) cfg.gravityVal = v end})

    -- ====== COMBAT TAB ======
    local TabCombat = Window:CreateTab("Combat", 4483362458)
    
    TabCombat:CreateSection("Combat")
    TabCombat:CreateToggle({Name="Spin Bot", CurrentValue=cfg.spinBot, Callback=function(v) cfg.spinBot = v end})
    TabCombat:CreateToggle({Name="Kill Aura", CurrentValue=cfg.killAura, Callback=function(v) cfg.killAura = v end})
    TabCombat:CreateToggle({Name="Hitbox Expander", CurrentValue=cfg.hitboxExpander, Callback=function(v) cfg.hitboxExpander = v end})
    
    TabCombat:CreateSection("Sliders")
    TabCombat:CreateSlider({Name="Spin Speed", Range={1, 30}, Increment=1, CurrentValue=cfg.spinSpeed, Callback=function(v) cfg.spinSpeed = v end})
    TabCombat:CreateSlider({Name="Kill Aura Range", Range={5, 100}, Increment=1, CurrentValue=cfg.killAuraRange, Callback=function(v) cfg.killAuraRange = v end})
    TabCombat:CreateSlider({Name="Hitbox Size", Range={4, 50}, Increment=1, CurrentValue=cfg.hitboxSize, Callback=function(v) cfg.hitboxSize = v end})

    -- ====== VISUALS TAB ======
    local TabVisuals = Window:CreateTab("Visuals", 4483362458)
    
    TabVisuals:CreateSection("Visuals")
    TabVisuals:CreateToggle({Name="FOV Changer", CurrentValue=cfg.fovChanger, Callback=function(v) cfg.fovChanger = v end})
    TabVisuals:CreateToggle({Name="Fullbright", CurrentValue=cfg.fullbright, Callback=function(v) cfg.fullbright = v end})
    TabVisuals:CreateToggle({Name="Crosshair", CurrentValue=cfg.crosshair, Callback=function(v) cfg.crosshair = v end})
    TabVisuals:CreateToggle({Name="Spam Click", CurrentValue=cfg.spamClick, Callback=function(v) cfg.spamClick = v end})
    TabVisuals:CreateToggle({Name="Inventory Viewer", CurrentValue=cfg.invViewer, Callback=function(v) cfg.invViewer = v end})
    
    TabVisuals:CreateSection("Sliders")
    TabVisuals:CreateSlider({Name="FOV Value", Range={40, 120}, Increment=1, CurrentValue=cfg.fovVal, Callback=function(v) cfg.fovVal = v end})
    TabVisuals:CreateSlider({Name="Crosshair Size", Range={5, 30}, Increment=1, CurrentValue=cfg.crosshairSize, Callback=function(v) cfg.crosshairSize = v end})

    -- ====== INFO TAB ======
    local TabInfo = Window:CreateTab("Info", 4483362458)
    
    TabInfo:CreateSection("Vortex Hub v" .. VERSION)
    TabInfo:CreateLabel("Press ; to toggle menu")
    TabInfo:CreateLabel("Hold RMB for Aimbot")
    TabInfo:CreateLabel("Press V for Fly")
    TabInfo:CreateLabel("Press F for Random Teleport")
    TabInfo:CreateLabel("Press G for Closest Teleport")
    TabInfo:CreateLabel("Press RCtrl for Panic Mode")
    
    if currentKeyData then
        TabInfo:CreateSection("Key Info")
        TabInfo:CreateLabel("Username: " .. (currentKeyData.username or "N/A"))
        TabInfo:CreateLabel("User ID: " .. (currentKeyData.user_id or "N/A"))
        TabInfo:CreateLabel("Status: " .. (currentKeyData.status or "N/A"))
        TabInfo:CreateLabel("Expires: " .. (currentKeyData.expires or "Never"))
    end
    
    TabInfo:CreateSection("Discord")
    TabInfo:CreateButton({
        Name="💬 Join Discord",
        Callback=function()
            local url = "https://discord.gg/ZWsBVFhAnS"
            if setclipboard then
                setclipboard(url)
                Rayfield:Notify({Title="Discord", Content="Link copied!", Duration=2})
            else
                game:GetService("GuiService"):OpenBrowserWindow(url)
            end
        end
    })

    -- ============================================================
    --  INPUT BINDINGS
    -- ============================================================
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        
        if input.KeyCode == Enum.KeyCode.RightControl then
            setPanic(not panicOn)
            if panicOn then stopFly() end
            Rayfield:Notify({
                Title="Panic",
                Content=panicOn and "Panic ON" or "Panic OFF",
                Duration=2
            })
        end
        
        if input.KeyCode == Enum.KeyCode.V then
            cfg.fly = not cfg.fly
            if cfg.fly then startFly() else stopFly() end
        end
        
        if input.KeyCode == Enum.KeyCode.F then
            local others = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(others, p)
                end
            end
            if #others > 0 then
                local t = others[math.random(1, #others)]
                local myRoot = character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    myRoot.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
                end
            end
        end
        
        if input.KeyCode == Enum.KeyCode.G then
            local myRoot = character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local closest, best = nil, math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local d = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                        if d < best then closest = p; best = d end
                    end
                end
                if closest then
                    myRoot.CFrame = closest.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
                end
            end
        end
    end)
end

-- ============================================================
--  KEY ENTRY SCREEN
-- ============================================================
local KeyWindow = nil

function showKeyEntryScreen()
    KeyWindow = Rayfield:CreateWindow({
        Name = "Key Required",
        LoadingTitle = "Enter your key",
        LoadingSubtitle = "Valid key required to use Vortex Hub",
        Theme = "Default",
        DisableRayfieldPrompts = true,
        DisableBuildWarnings = true,
    })

    local tab = KeyWindow:CreateTab("Key Entry", 4483362458)
    tab:CreateSection("Enter Key")

    local currentKeyText = ""
    local input = tab:CreateInput({
        Name = "Key",
        PlaceholderText = "XXXX-XXXX-XXXX-XXXX",
        RemoveTextAfterFocusLost = false,
        Callback = function(text) currentKeyText = text end
    })

    local statusLabel = tab:CreateLabel("")
    statusLabel:Set("")

    tab:CreateButton({
        Name = "Redeem Key",
        Callback = function()
            local key = currentKeyText
            if not key or #key < 16 then
                statusLabel:Set("Please enter a valid key (16 characters)")
                return
            end
            key = string.upper(string.gsub(key, "%s+", ""))
            if #key < 16 then
                statusLabel:Set("Key must be at least 16 characters")
                return
            end

            statusLabel:Set("Checking key...")
            local result, msg, flag = redeemKey(key, tostring(player.UserId), player.Name)

            if result then
                currentKeyData = result
                statusLabel:Set("Key redeemed successfully!")
                task.wait(1)
                if KeyWindow then
                    pcall(function()
                        if KeyWindow.Destroy then KeyWindow:Destroy()
                        elseif KeyWindow.Close then KeyWindow:Close()
                        end
                    end)
                    KeyWindow = nil
                end
                createMainMenu()
            else
                statusLabel:Set("Error: " .. (msg or "Unknown error"))
            end
        end
    })

    tab:CreateButton({
        Name = "Get a key on Discord",
        Callback = function()
            local url = "https://discord.gg/ZWsBVFhAnS"
            if setclipboard then
                setclipboard(url)
                statusLabel:Set("Discord link copied!")
            else
                game:GetService("GuiService"):OpenBrowserWindow(url)
            end
        end
    })
end

-- ============================================================
--  STARTUP
-- ============================================================
task.spawn(function()
    local keyData, err = getPlayerKey(tostring(player.UserId))
    if keyData then
        local valid, msg = validateKey(keyData, tostring(player.UserId))
        if valid then
            currentKeyData = keyData
            createMainMenu()
        else
            print("Key invalid: " .. msg)
            currentKeyData = nil
            showKeyEntryScreen()
        end
    else
        showKeyEntryScreen()
    end
end)
