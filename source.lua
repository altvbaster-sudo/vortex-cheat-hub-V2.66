local VERSION = "3.0"

-- ============================================================
--  KEY SYSTEM (Supabase Integration) – FINAL FIX
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

-- ---- Check if a key is expired (returns true if expired) ----
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

-- ---- Validate key for a specific user: returns (valid, message) ----
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

-- ---- Lookup by User ID ----
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

-- ---- Redeem or re‑validate a key ----
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
--  CONFIGURATION - UPGRADED WITH NEW FEATURES
-- ============================================================
local cfg = {
    -- ESP (UPGRADED)
    esp = true,
    espBoxes = true,
    espNames = true,
    espHealth = true,
    espTracers = true,
    espBones = true,
    espDistance = true,
    rainbowEsp = false,
    espMaxDistance = 2000,
    espMaxPlayers = 30,
    espGlow = false,        -- NEW: Glow effect
    espBoxStyle = "corner", -- NEW: "corner" or "full"
    espChams = false,       -- NEW: Chams (wallhack)
    
    -- Aimbot (UPGRADED)
    aimbot = false,
    aimbotFOV = 120,
    aimbotSmooth = 5,
    aimbotPart = "HumanoidRootPart",
    aimbotTeamCheck = true,
    aimbotPrediction = true, -- NEW: AI prediction
    softAim = false,
    softAimStr = 5,
    silentAim = false,
    
    -- Movement (UPGRADED)
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
    
    -- Combat (UPGRADED)
    hitboxExpander = false,
    hitboxSize = 10,
    spinBot = false,
    spinSpeed = 10,
    killAura = false,
    killAuraRange = 20,
    
    -- Visuals (UPGRADED)
    fovChanger = false,
    fovVal = 70,
    fullbright = false,
    spamClick = false,
    invViewer = false,
    crosshair = false,
    crosshairSize = 10,
    crosshairColor = Color3.fromRGB(255,255,255), -- NEW: Custom color
    crosshairDot = true, -- NEW: Dot toggle
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
        game:GetService("Lighting").Brightness = 1
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
            game:GetService("Lighting").Brightness = 10
            game:GetService("Lighting").ClockTime = 14
        end
    end
end

local ECFG = {
    TeamCheck = false,
    MaxDistance = 2000,
    UseTeamColor = true,
    DefaultColor = Color3.fromRGB(99, 102, 241),
    BoxThickness = 2,
    BoneThickness = 1,
    BoneColor = Color3.fromRGB(200, 200, 220),
    TracerThickness = 1,
    TracerOrigin = "Bottom",
    HealthBarW = 5,
    HealthBarGap = 5,
    HealthHigh = Color3.fromRGB(34, 197, 94),
    HealthMid = Color3.fromRGB(255, 200, 0),
    HealthLow = Color3.fromRGB(255, 45, 45),
    HealthBGColor = Color3.fromRGB(15, 15, 15),
    TextSize = 12,
    NameGap = 3,
}

local BONES_R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
}
local BONES_R6 = {
    {"Head","Torso"},
    {"Torso","Right Arm"},{"Torso","Left Arm"},
    {"Torso","Right Leg"},{"Torso","Left Leg"},
}
local MAX_BONES = #BONES_R15

local espGui = Instance.new("ScreenGui")
espGui.Name = "ScreenGui"; espGui.ResetOnSpawn = false
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.DisplayOrder = 1; espGui.IgnoreGuiInset = true
espGui.Parent = player.PlayerGui

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "ScreenGui"; fovGui.ResetOnSpawn = false
fovGui.DisplayOrder = 5; fovGui.IgnoreGuiInset = true
fovGui.Parent = player.PlayerGui

local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1; fovCircle.BorderSizePixel = 0
fovCircle.ZIndex = 5; fovCircle.Visible = false; fovCircle.Parent = fovGui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovCircle)
fovStroke.Color = Color3.fromRGB(99, 102, 241); fovStroke.Thickness = 1
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
--  CROSSHAIR (UPGRADED)
-- ============================================================
local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "ScreenGui"; crosshairGui.ResetOnSpawn = false
crosshairGui.DisplayOrder = 10; crosshairGui.IgnoreGuiInset = true
crosshairGui.Parent = player.PlayerGui

local chH = Instance.new("Frame", crosshairGui)
chH.BackgroundColor3 = Color3.new(1,1,1); chH.BorderSizePixel = 0; chH.Visible = false
local chV = Instance.new("Frame", crosshairGui)
chV.BackgroundColor3 = Color3.new(1,1,1); chV.BorderSizePixel = 0; chV.Visible = false
local chDot = Instance.new("Frame", crosshairGui)
chDot.BackgroundColor3 = Color3.fromRGB(255,255,255); chDot.BorderSizePixel = 0; chDot.Visible = false
Instance.new("UICorner", chDot).CornerRadius = UDim.new(1, 0)

RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local s = cfg.crosshairSize
    chH.Visible = cfg.crosshair; chV.Visible = cfg.crosshair; chDot.Visible = cfg.crosshair and cfg.crosshairDot
    if cfg.crosshair then
        chH.Size = UDim2.new(0, s*2, 0, 2); chH.Position = UDim2.new(0, cx-s, 0, cy-1)
        chV.Size = UDim2.new(0, 2, 0, s*2); chV.Position = UDim2.new(0, cx-1, 0, cy-s)
        chH.BackgroundColor3 = cfg.crosshairColor
        chV.BackgroundColor3 = cfg.crosshairColor
        if cfg.crosshairDot then
            chDot.Size = UDim2.new(0, 4, 0, 4); chDot.Position = UDim2.new(0, cx-2, 0, cy-2)
            chDot.BackgroundColor3 = cfg.crosshairColor
        end
    end
end)

-- ============================================================
--  INVENTORY VIEWER (UNCHANGED)
-- ============================================================
local invObjects = {}

local function getPlayerTools(plr)
    local tools = {}
    if plr.Character then
        for _, t in ipairs(plr.Character:GetChildren()) do
            if t:IsA("Tool") then table.insert(tools, {name=t.Name, equipped=true}) end
        end
    end
    pcall(function()
        local bp = plr:FindFirstChildOfClass("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, {name=t.Name, equipped=false}) end
            end
        end
    end)
    return tools
end

local INV_SLOT = 28
local INV_GAP = 2
local INV_SLOTS = 6

local function buildInvBillboard(plr)
    if plr == player then return end
    if invObjects[plr] then invObjects[plr]:Destroy(); invObjects[plr] = nil end
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local totalW = INV_SLOTS * (INV_SLOT + INV_GAP) - INV_GAP

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, totalW, 0, INV_SLOT + 14)
    bb.StudsOffset = Vector3.new(0, -3, 0)
    bb.AlwaysOnTop = true; bb.Adornee = root
    bb.Parent = player.PlayerGui

    local nameLbl = Instance.new("TextLabel", bb)
    nameLbl.Size = UDim2.new(1, 0, 0, 12); nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1; nameLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLbl.TextStrokeTransparency = 0; nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 9
    nameLbl.Text = plr.Name; nameLbl.TextXAlignment = Enum.TextXAlignment.Center

    local row = Instance.new("Frame", bb)
    row.Size = UDim2.new(0, totalW, 0, INV_SLOT); row.Position = UDim2.new(0, 0, 0, 12)
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0

    for i = 1, INV_SLOTS do
        local slot = Instance.new("Frame", row)
        slot.Name = "Slot"..i
        slot.Size = UDim2.new(0, INV_SLOT, 0, INV_SLOT)
        slot.Position = UDim2.new(0, (i-1)*(INV_SLOT+INV_GAP), 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        slot.BorderSizePixel = 0
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 3)

        local label = Instance.new("TextLabel", slot)
        label.Name = "Name"
        label.Size = UDim2.new(1, -2, 1, -2); label.Position = UDim2.new(0, 1, 0, 1)
        label.BackgroundTransparency = 1; label.TextColor3 = Color3.fromRGB(180, 180, 180)
        label.Font = Enum.Font.Gotham; label.TextSize = 7; label.Text = ""
        label.TextTruncate = Enum.TextTruncate.AtEnd; label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
    end

    invObjects[plr] = bb
end

local function refreshInvCard(plr)
    if plr == player then return end
    local bb = invObjects[plr]
    if not bb or not bb.Parent then
        buildInvBillboard(plr); bb = invObjects[plr]
        if not bb then return end
    end
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root or not cfg.invViewer then bb.Enabled = false; return end
    bb.Adornee = root; bb.Enabled = true

    local tools = getPlayerTools(plr)
    local row = bb:FindFirstChildOfClass("Frame")
    if not row then return end

    for i = 1, INV_SLOTS do
        local slot = row:FindFirstChild("Slot"..i)
        local label = slot and slot:FindFirstChild("Name")
        local tool = tools[i]
        if slot then
            if tool then
                slot.BackgroundColor3 = tool.equipped and Color3.fromRGB(40,55,40) or Color3.fromRGB(30,30,30)
                if label then
                    label.Text = tool.name
                    label.TextColor3 = tool.equipped and Color3.fromRGB(100,220,100) or Color3.fromRGB(180,180,180)
                end
            else
                slot.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
                if label then label.Text = "" end
            end
        end
    end
end

local invTimer = 0
RunService.RenderStepped:Connect(function(dt)
    invTimer += dt
    if invTimer < 0.5 then return end
    invTimer = 0
    if cfg.invViewer then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                if not invObjects[p] then buildInvBillboard(p) end
                refreshInvCard(p)
            end
        end
    else
        for _, bb in pairs(invObjects) do if bb then bb.Enabled = false end end
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        if cfg.invViewer then buildInvBillboard(p); refreshInvCard(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if invObjects[p] then invObjects[p]:Destroy(); invObjects[p] = nil end
end)

-- ============================================================
--  FLY SYSTEM (UNCHANGED)
-- ============================================================
local flyPart, flyWeld, flyVelocity, flyGyro, flyConn = nil, nil, nil, nil, nil

local function stopFly()
    cfg.fly = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyPart then flyPart:Destroy(); flyPart = nil end
    flyWeld = nil; flyVelocity = nil; flyGyro = nil
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
end

local function startFly()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    cfg.fly = true

    flyPart = Instance.new("Part")
    flyPart.Name = "FlyCarrier"
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

    flyGyro = Instance.new("BodyGyro", flyPart)
    flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyGyro.P = 1e4
    flyGyro.D = 100
    flyGyro.CFrame = flyPart.CFrame

    flyWeld = Instance.new("WeldConstraint", flyPart)
    flyWeld.Part0 = flyPart
    flyWeld.Part1 = root

    hum:ChangeState(Enum.HumanoidStateType.Physics)

    flyConn = RunService.RenderStepped:Connect(function()
        if not cfg.fly then stopFly(); return end
        local r2 = character and character:FindFirstChild("HumanoidRootPart")
        if not r2 then stopFly(); return end

        local cam = Camera.CFrame
        local fwd = cam.LookVector
        local rgt = cam.RightVector
        local up = Vector3.new(0, 1, 0)
        local dir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= rgt end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += rgt end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= up end

        flyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * cfg.flySpeed or Vector3.zero

        if cfg.spinBot and r2 then
            flyGyro.CFrame = r2.CFrame
        else
            flyGyro.CFrame = CFrame.new(Vector3.zero, Vector3.new(fwd.X, 0, fwd.Z))
        end
    end)
end

local function sendChat(msg)
    pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(msg) end
        end
    end)
    pcall(function()
        local cse = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if cse then
            local smr = cse:FindFirstChild("SayMessageRequest")
            if smr then smr:FireServer(msg, "All") end
        end
    end)
end

task.delay(3, function()
    sendChat("Menu by Vortex Hub v" .. VERSION)
end)

-- ============================================================
--  ESP SYSTEM (UPGRADED - Added Glow + Box Style)
-- ============================================================
local Pool = {}

local function newRect(parent, color)
    local f = Instance.new("Frame", parent or espGui)
    f.BackgroundColor3 = color or Color3.new(1,1,1)
    f.BackgroundTransparency = 0; f.BorderSizePixel = 0
    f.Size = UDim2.new(0,0,0,0); f.Visible = false
    return f
end

local function newLine(thickness, color)
    local f = Instance.new("Frame", espGui)
    f.AnchorPoint = Vector2.new(0.5,0.5)
    f.BackgroundColor3 = color or Color3.new(1,1,1)
    f.BackgroundTransparency = 0; f.BorderSizePixel = 0
    f.Size = UDim2.new(0,0,0,thickness or 1); f.Visible = false
    return f
end

local function newLabel()
    local l = Instance.new("TextLabel", espGui)
    l.BackgroundTransparency = 1; l.TextColor3 = Color3.new(1,1,1)
    l.TextStrokeTransparency = 0; l.TextStrokeColor3 = Color3.new(0,0,0)
    l.TextSize = ECFG.TextSize; l.Font = Enum.Font.GothamBold
    l.Text = ""; l.Size = UDim2.new(0,300,0,16)
    l.TextXAlignment = Enum.TextXAlignment.Center; l.Visible = false
    return l
end

local function applyLine(frame, x1, y1, x2, y2, color)
    local dx, dy = x2-x1, y2-y1
    local len = math.sqrt(dx*dx+dy*dy)
    frame.Size = UDim2.new(0, len, 0, frame.Size.Y.Offset)
    frame.Position = UDim2.new(0, (x1+x2)*0.5, 0, (y1+y2)*0.5)
    frame.Rotation = math.deg(math.atan2(dy, dx))
    if color then frame.BackgroundColor3 = color end
    frame.Visible = true
end

local function applyBox(box, x, y, w, h, color)
    local t = ECFG.BoxThickness
    if cfg.espBoxStyle == "full" then
        box.T.BackgroundColor3 = color; box.T.Position = UDim2.new(0,x,0,y); box.T.Size = UDim2.new(0,w,0,t); box.T.Visible = true
        box.Bo.BackgroundColor3 = color; box.Bo.Position = UDim2.new(0,x,0,y+h-t); box.Bo.Size = UDim2.new(0,w,0,t); box.Bo.Visible = true
        box.L.BackgroundColor3 = color; box.L.Position = UDim2.new(0,x,0,y); box.L.Size = UDim2.new(0,t,0,h); box.L.Visible = true
        box.R.BackgroundColor3 = color; box.R.Position = UDim2.new(0,x+w-t,0,y); box.R.Size = UDim2.new(0,t,0,h); box.R.Visible = true
    else
        local cs = math.min(10, w / 4)
        box.T.BackgroundColor3 = color; box.T.Position = UDim2.new(0,x,0,y); box.T.Size = UDim2.new(0,cs,0,t); box.T.Visible = true
        box.Bo.BackgroundColor3 = color; box.Bo.Position = UDim2.new(0,x+w-cs,0,y); box.Bo.Size = UDim2.new(0,cs,0,t); box.Bo.Visible = true
        box.L.BackgroundColor3 = color; box.L.Position = UDim2.new(0,x,0,y+h-t); box.L.Size = UDim2.new(0,cs,0,t); box.L.Visible = true
        box.R.BackgroundColor3 = color; box.R.Position = UDim2.new(0,x+w-cs,0,y+h-t); box.R.Size = UDim2.new(0,cs,0,t); box.R.Visible = true
    end
end

local function hideBox(box)
    box.T.Visible = false; box.Bo.Visible = false; box.L.Visible = false; box.R.Visible = false
end

local function hideAll(obj)
    hideBox(obj.Box)
    obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
    obj.NameTag.Visible = false; obj.Tracer.Visible = false
    if obj.Glow then obj.Glow.Visible = false end
    for _, b in next, obj.Bones do b.Visible = false end
end

local function lerpCol(a, b, t)
    return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
end

local function hpColor(pct)
    if pct >= 0.5 then return lerpCol(ECFG.HealthMid, ECFG.HealthHigh, (pct-0.5)*2)
    else return lerpCol(ECFG.HealthLow, ECFG.HealthMid, pct*2) end
end

local function w2s(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), vis
end

local OFFSETS = {
    Vector3.new( 1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new( 1,-1, 1), Vector3.new(-1,-1, 1),
    Vector3.new( 1, 1,-1), Vector3.new(-1, 1,-1), Vector3.new( 1,-1,-1), Vector3.new(-1,-1,-1),
}

local function getBounds(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local ok = false
    for _, part in next, char:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local cf = part.CFrame; local sz = part.Size * 0.5
            for _, off in next, OFFSETS do
                local sp, vis = Camera:WorldToViewportPoint(cf * (sz * off))
                if vis then
                    ok = true
                    if sp.X < minX then minX = sp.X end; if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end; if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    if not ok then return nil end
    return {x=minX, y=minY, w=maxX-minX, h=maxY-minY, cx=(minX+maxX)*0.5}
end

local function allocate(plr)
    if plr == player or Pool[plr] then return end
    local bones = table.create(MAX_BONES)
    for i = 1, MAX_BONES do bones[i] = newLine(ECFG.BoneThickness, ECFG.BoneColor) end
    local glow = cfg.espGlow and newRect(nil, Color3.fromRGB(255,255,255)) or nil
    if glow then glow.BackgroundTransparency = 0.7 end
    Pool[plr] = {
        Box = {T=newRect(), Bo=newRect(), L=newRect(), R=newRect()},
        HealthBG = newRect(nil, ECFG.HealthBGColor),
        HealthBar = newRect(nil, ECFG.HealthHigh),
        NameTag = newLabel(),
        Tracer = newLine(ECFG.TracerThickness),
        Bones = bones,
        Glow = glow,
    }
end

local function free(plr)
    local obj = Pool[plr]; if not obj then return end
    for _, f in next, obj.Box do f:Destroy() end
    obj.HealthBG:Destroy(); obj.HealthBar:Destroy()
    obj.NameTag:Destroy(); obj.Tracer:Destroy()
    if obj.Glow then obj.Glow:Destroy() end
    for _, b in next, obj.Bones do b:Destroy() end
    Pool[plr] = nil
end

for _, p in next, Players:GetPlayers() do allocate(p) end
Players.PlayerAdded:Connect(allocate)
Players.PlayerRemoving:Connect(free)

local rainbowHue = 0

-- ESP RENDER LOOP
RunService.RenderStepped:Connect(function()
    if cfg.rainbowEsp then
        rainbowHue = (rainbowHue + 1) % 360
        ECFG.DefaultColor = Color3.fromHSV(rainbowHue / 360, 1, 1)
    end

    if not cfg.esp then
        for _, obj in next, Pool do hideAll(obj) end
        return
    end

    local vp = Camera.ViewportSize
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local players = Players:GetPlayers()
    
    local renderCount = 0
    local maxPlayers = cfg.espMaxPlayers or 30

    local tracerFrom
    if ECFG.TracerOrigin == "Center" then tracerFrom = Vector2.new(vp.X*0.5, vp.Y*0.5)
    elseif ECFG.TracerOrigin == "Top" then tracerFrom = Vector2.new(vp.X*0.5, 0)
    else tracerFrom = Vector2.new(vp.X*0.5, vp.Y) end

    for plr, obj in next, Pool do
        if renderCount >= maxPlayers then
            hideAll(obj)
            continue
        end

        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if not (char and hum and root) or hum.Health <= 0 then hideAll(obj); continue end
        if ECFG.TeamCheck and player.Team and plr.Team == player.Team then hideAll(obj); continue end

        local dist = localRoot and (root.Position - localRoot.Position).Magnitude or 0
        if dist > cfg.espMaxDistance then hideAll(obj); continue end

        local rootSP, rootVis = w2s(root.Position)
        if not rootVis then hideAll(obj); continue end

        renderCount = renderCount + 1

        local col = ECFG.DefaultColor
        if not cfg.rainbowEsp and ECFG.UseTeamColor and plr.Team then col = plr.Team.TeamColor.Color end

        local b = getBounds(char)

        if cfg.espBoxes and b then applyBox(obj.Box, b.x, b.y, b.w, b.h, col) else hideBox(obj.Box) end

        -- GLOW EFFECT (NEW)
        if cfg.espGlow and b then
            if not obj.Glow then
                obj.Glow = newRect(nil, col)
                obj.Glow.BackgroundTransparency = 0.7
            end
            obj.Glow.Position = UDim2.new(0, b.x - 5, 0, b.y - 5)
            obj.Glow.Size = UDim2.new(0, b.w + 10, 0, b.h + 10)
            obj.Glow.BackgroundColor3 = col
            obj.Glow.Visible = true
        elseif obj.Glow then
            obj.Glow.Visible = false
        end

        if cfg.espHealth and b then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local bx = b.x - ECFG.HealthBarW - ECFG.HealthBarGap
            local fillH = math.max(1, b.h * pct)
            obj.HealthBG.BackgroundColor3 = ECFG.HealthBGColor
            obj.HealthBG.Position = UDim2.new(0,bx,0,b.y); obj.HealthBG.Size = UDim2.new(0,ECFG.HealthBarW,0,b.h); obj.HealthBG.Visible = true
            obj.HealthBar.BackgroundColor3 = hpColor(pct)
            obj.HealthBar.Position = UDim2.new(0,bx,0,b.y+b.h-fillH); obj.HealthBar.Size = UDim2.new(0,ECFG.HealthBarW,0,fillH); obj.HealthBar.Visible = true
        else
            obj.HealthBG.Visible = false; obj.HealthBar.Visible = false
        end

        if cfg.espNames then
            local parts = {plr.Name}
            if cfg.espDistance then parts[#parts+1] = math.floor(dist).."m" end
            local tx = b and b.cx or rootSP.X
            local ty = b and (b.y - ECFG.TextSize - ECFG.NameGap) or (rootSP.Y - 36)
            obj.NameTag.Text = table.concat(parts, "  |  ")
            obj.NameTag.TextColor3 = col
            obj.NameTag.Position = UDim2.new(0, tx-150, 0, ty)
            obj.NameTag.Visible = true
        else
            obj.NameTag.Visible = false
        end

        if cfg.espTracers then
            applyLine(obj.Tracer, tracerFrom.X, tracerFrom.Y, rootSP.X, rootSP.Y, col)
        else
            obj.Tracer.Visible = false
        end

        if cfg.espBones then
            local isR15 = char:FindFirstChild("UpperTorso") ~= nil
            local boneSet = isR15 and BONES_R15 or BONES_R6
            for i, bf in next, obj.Bones do
                local conn = boneSet[i]
                if conn then
                    local pA = char:FindFirstChild(conn[1])
                    local pB = char:FindFirstChild(conn[2])
                    if pA and pB then
                        local spA, visA = w2s(pA.Position)
                        local spB, visB = w2s(pB.Position)
                        if visA or visB then applyLine(bf, spA.X, spA.Y, spB.X, spB.Y, col)
                        else bf.Visible = false end
                    else bf.Visible = false end
                else bf.Visible = false end
            end
        else
            for _, bf in next, obj.Bones do bf.Visible = false end
        end
    end
end)

-- ============================================================
--  AIMBOT (UPGRADED - Added AI Prediction)
-- ============================================================
local function getNearestTarget()
    local best, bestDist = nil, math.huge
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        if cfg.aimbotTeamCheck and player.Team and plr.Team and plr.Team == player.Team then continue end
        local char = plr.Character
        local aimPart = char and (char:FindFirstChild(cfg.aimbotPart) or char:FindFirstChild("HumanoidRootPart"))
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not aimPart or not hum or hum.Health <= 0 then continue end
        
        local targetPos = aimPart.Position
        if cfg.aimbotPrediction then
            local vel = aimPart.Velocity or Vector3.new(0,0,0)
            targetPos = targetPos + vel * 0.12
        end
        
        local sc, vis = Camera:WorldToViewportPoint(targetPos)
        if not vis then continue end
        local dist = (Vector2.new(sc.X, sc.Y) - center).Magnitude
        if dist < cfg.aimbotFOV and dist < bestDist then
            best = {part = aimPart, pos = targetPos}; bestDist = dist
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if cfg.aimbot or cfg.softAim or cfg.silentAim then
        local r = cfg.aimbotFOV; local vp = Camera.ViewportSize
        fovCircle.Size = UDim2.new(0, r*2, 0, r*2)
        fovCircle.Position = UDim2.new(0, vp.X/2-r, 0, vp.Y/2-r)
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    local target = getNearestTarget()
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
--  LOOPING SYSTEMS (UNCHANGED)
-- ============================================================
RunService.RenderStepped:Connect(function(dt)
    if cfg.thirdPerson and character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            Camera.CameraSubject = root
            Camera.CameraType = Enum.CameraType.Custom
        end
    elseif not cfg.thirdPerson then
        if Camera.CameraType == Enum.CameraType.Custom then
            Camera.CameraSubject = nil
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

-- ============================================================
--  HITBOX EXPANDER & KILL AURA & SPIN BOT
-- ============================================================
local hitboxParts = {}

local function removeHitbox(plr)
    if hitboxParts[plr] then hitboxParts[plr]:Destroy(); hitboxParts[plr] = nil end
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
    hb.Transparency = 1; hb.CanCollide = false; hb.CastShadow = false
    hb.Anchored = false; hb.CFrame = root.CFrame; hb.Parent = workspace

    local weld = Instance.new("WeldConstraint", hb)
    weld.Part0 = hb; weld.Part1 = root

    hitboxParts[plr] = hb
end

local lastHitboxSize = cfg.hitboxSize

RunService.Heartbeat:Connect(function(dt)
    if cfg.spinBot then
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(cfg.spinSpeed * dt * 60), 0)
        end
        if flyGyro and root then
            flyGyro.CFrame = root.CFrame
        end
    else
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum and not hum.AutoRotate then
            hum.AutoRotate = true
        end
    end

    if cfg.hitboxExpander then
        if lastHitboxSize ~= cfg.hitboxSize then
            lastHitboxSize = cfg.hitboxSize
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then buildHitbox(p) end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and not hitboxParts[p] then buildHitbox(p) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            removeHitbox(p)
        end
    end

    if cfg.killAura then
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local closest, best = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p == player then continue end
                local pChar = p.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
                if not pRoot or not pHum or pHum.Health <= 0 then continue end
                local d = (pRoot.Position - myRoot.Position).Magnitude
                if d < cfg.killAuraRange and d < best then
                    closest = p
                    best = d
                end
            end

            if closest then
                local tool = character:FindFirstChildOfClass("Tool")
                local pRoot = closest.Character and closest.Character:FindFirstChild("HumanoidRootPart")
                if tool then
                    local savedCF = myRoot.CFrame
                    if pRoot then myRoot.CFrame = pRoot.CFrame * CFrame.new(0, 0, 2) end
                    for _, obj in ipairs(tool:GetDescendants()) do
                        if obj:IsA("RemoteEvent") then
                            pcall(function() obj:FireServer() end)
                            if pRoot then pcall(function() obj:FireServer(pRoot) end) end
                        end
                        if obj:IsA("RemoteFunction") then
                            pcall(function() obj:InvokeServer() end)
                        end
                    end
                    myRoot.CFrame = savedCF
                end
            end
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        removeHitbox(p)
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        removeHitbox(p)
    end)
end
Players.PlayerRemoving:Connect(removeHitbox)

-- ============================================================
--  ANTI-AFK
-- ============================================================
player.Idled:Connect(function()
    if cfg.antiAfk then
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Jump = true end
    end
end)

-- ============================================================
--  SPAM CLICK
-- ============================================================
local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
    if cfg.spamClick then
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool then
            for _, obj in ipairs(tool:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    for _ = 1, 5 do pcall(function() obj:FireServer() end) end
                end
            end
        end
    end
end)

-- ============================================================
--  RAYFIELD UI - UPGRADED MENU
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
        if input.KeyCode ~= Enum.KeyCode.Semicolon then return end
        menuOpen = not menuOpen
        local gui = player.PlayerGui:FindFirstChild("Rayfield")
        if gui then gui.Enabled = menuOpen end
    end)

    local TabESP = Window:CreateTab("Visual / ESP", 4483362458)
    local TabAimbot = Window:CreateTab("Aimbot", 4483362458)
    local TabMovement = Window:CreateTab("Movement", 4483362458)
    local TabPlayer = Window:CreateTab("Player", 4483362458)
    local TabMisc = Window:CreateTab("Misc", 4483362458)
    local TabKeyInfo = Window:CreateTab("Key Info", 4483362458)

    -- ============================================================
    --  VISUAL / ESP TAB (UPGRADED)
    -- ============================================================
    TabESP:CreateSection("ESP")
    TabESP:CreateToggle({ Name="ESP", CurrentValue=cfg.esp, Flag="esp", Callback=function(v) cfg.esp = v end })
    TabESP:CreateToggle({ Name="Boxes", CurrentValue=cfg.espBoxes, Flag="espBoxes", Callback=function(v) cfg.espBoxes = v end })
    TabESP:CreateToggle({ Name="Names", CurrentValue=cfg.espNames, Flag="espNames", Callback=function(v) cfg.espNames = v end })
    TabESP:CreateToggle({ Name="Health Bars", CurrentValue=cfg.espHealth, Flag="espHealth", Callback=function(v) cfg.espHealth = v end })
    TabESP:CreateToggle({ Name="Tracers", CurrentValue=cfg.espTracers, Flag="espTracers", Callback=function(v) cfg.espTracers = v end })
    TabESP:CreateToggle({ Name="Bones", CurrentValue=cfg.espBones, Flag="espBones", Callback=function(v) cfg.espBones = v end })
    TabESP:CreateToggle({ Name="Distance", CurrentValue=cfg.espDistance, Flag="espDistance", Callback=function(v) cfg.espDistance = v end })
    TabESP:CreateToggle({ Name="Rainbow ESP", CurrentValue=cfg.rainbowEsp, Flag="rainbowEsp", Callback=function(v) cfg.rainbowEsp = v end })
    
    -- NEW ESP FEATURES
    TabESP:CreateToggle({ Name="Glow Effect", CurrentValue=cfg.espGlow, Flag="espGlow", Callback=function(v) cfg.espGlow = v end })
    
    TabESP:CreateDropdown({
        Name="Box Style",
        Options={"corner","full"},
        CurrentOption={cfg.espBoxStyle},
        Callback=function(v)
            if type(v) == "table" then v = v[1] end
            cfg.espBoxStyle = v
        end
    })

    TabESP:CreateSection("Performance")
    TabESP:CreateSlider({
        Name="Max Render Distance",
        Range={100, 5000},
        Increment=50,
        Suffix=" studs",
        CurrentValue=cfg.espMaxDistance,
        Flag="espMaxDistance",
        Callback=function(v)
            cfg.espMaxDistance = v
            ECFG.MaxDistance = v
        end
    })
    TabESP:CreateSlider({
        Name="Max Players Rendered",
        Range={5, 50},
        Increment=1,
        Suffix=" players",
        CurrentValue=cfg.espMaxPlayers,
        Flag="espMaxPlayers",
        Callback=function(v) cfg.espMaxPlayers = v end
    })

    TabESP:CreateSection("Inventory ESP")
    TabESP:CreateToggle({
        Name="Inventory Viewer", CurrentValue=cfg.invViewer, Flag="invViewer",
        Callback=function(v)
            cfg.invViewer = v
            if v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player then buildInvBillboard(p); refreshInvCard(p) end
                end
            else
                for _, bb in pairs(invObjects) do if bb then bb.Enabled = false end end
            end
        end,
    })

    -- ============================================================
    --  CROSSHAIR (UPGRADED WITH COLOR PICKER)
    -- ============================================================
    TabESP:CreateSection("Crosshair")
    TabESP:CreateToggle({ Name="Custom Crosshair", CurrentValue=cfg.crosshair, Flag="crosshair", Callback=function(v) cfg.crosshair = v end })
    TabESP:CreateSlider({ Name="Crosshair Size", Range={5,30}, Increment=1, Suffix="px", CurrentValue=cfg.crosshairSize, Flag="crosshairSize", Callback=function(v) cfg.crosshairSize = v end })
    TabESP:CreateToggle({ Name="Crosshair Dot", CurrentValue=cfg.crosshairDot, Flag="crosshairDot", Callback=function(v) cfg.crosshairDot = v end })
    TabESP:CreateColorPicker({
        Name="Crosshair Color",
        CurrentValue=cfg.crosshairColor,
        Flag="crosshairColor",
        Callback=function(v) cfg.crosshairColor = v end
    })

    TabESP:CreateSection("Camera")
    TabESP:CreateToggle({
        Name="FOV Changer", CurrentValue=cfg.fovChanger, Flag="fovChanger",
        Callback=function(v)
            cfg.fovChanger = v
            if not v then Camera.FieldOfView = 70 end
        end,
    })
    TabESP:CreateSlider({
        Name="Field of View", Range={40,120}, Increment=1, Suffix="°", CurrentValue=cfg.fovVal, Flag="fovVal",
        Callback=function(v)
            cfg.fovVal = v
            if cfg.fovChanger then Camera.FieldOfView = v end
        end,
    })

    -- ============================================================
    --  AIMBOT TAB (UPGRADED)
    -- ============================================================
    TabAimbot:CreateSection("Aimbot")
    TabAimbot:CreateToggle({ Name="Aimbot [Hold RMB]", CurrentValue=cfg.aimbot, Flag="aimbot", Callback=function(v) cfg.aimbot = v; updateFOVCircle() end })
    TabAimbot:CreateToggle({ Name="Soft Aim [Hold LMB]", CurrentValue=cfg.softAim, Flag="softAim", Callback=function(v) cfg.softAim = v; updateFOVCircle() end })
    TabAimbot:CreateToggle({ Name="Silent Aim", CurrentValue=cfg.silentAim, Flag="silentAim", Callback=function(v) cfg.silentAim = v; updateFOVCircle() end })
    
    -- NEW: AI Prediction Toggle
    TabAimbot:CreateToggle({ Name="AI Prediction", CurrentValue=cfg.aimbotPrediction, Flag="aimbotPrediction", Callback=function(v) cfg.aimbotPrediction = v end })

    TabAimbot:CreateDropdown({
        Name="Aim At",
        Options={"HumanoidRootPart","Head","UpperTorso"},
        CurrentOption={cfg.aimbotPart},
        Callback=function(option)
            if type(option) == "table" then option = option[1] end
            cfg.aimbotPart = option
        end,
    })

    TabAimbot:CreateSlider({ Name="FOV", Range={10,500}, Increment=1, Suffix="px", CurrentValue=cfg.aimbotFOV, Flag="aimbotFOV", Callback=function(v) cfg.aimbotFOV = v; updateFOVCircle() end })
    TabAimbot:CreateSlider({ Name="Smoothness", Range={1,10}, Increment=1, Suffix="", CurrentValue=cfg.aimbotSmooth, Flag="aimbotSmooth", Callback=function(v) cfg.aimbotSmooth = v end })
    TabAimbot:CreateSlider({ Name="Soft Aim Strength", Range={1,10}, Increment=1, Suffix="", CurrentValue=cfg.softAimStr, Flag="softAimStr", Callback=function(v) cfg.softAimStr = v end })
    TabAimbot:CreateToggle({ Name="Don't Lock On Teammates", CurrentValue=cfg.aimbotTeamCheck, Flag="aimbotTeamCheck", Callback=function(v) cfg.aimbotTeamCheck = v end })

    -- ============================================================
    --  MOVEMENT TAB (UNCHANGED)
    -- ============================================================
    TabMovement:CreateSection("Movement")
    TabMovement:CreateToggle({ Name="Fly [V]", CurrentValue=cfg.fly, Flag="fly", Callback=function(v) cfg.fly = v; if v then startFly() else stopFly() end end })
    TabMovement:CreateSlider({ Name="Fly Speed", Range={10,300}, Increment=5, Suffix="", CurrentValue=cfg.flySpeed, Flag="flySpeed", Callback=function(v) cfg.flySpeed = v end })
    
    TabMovement:CreateToggle({
        Name="Speed Hack", CurrentValue=cfg.speed, Flag="speed",
        Callback=function(v)
            cfg.speed = v
            if v then
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = cfg.speedVal end
            else
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end,
    })
    TabMovement:CreateSlider({
        Name="Walk Speed", Range={16,200}, Increment=1, Suffix="", CurrentValue=cfg.speedVal, Flag="speedVal",
        Callback=function(v)
            cfg.speedVal = v
            if cfg.speed then
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = v end
            end
        end,
    })
    TabMovement:CreateToggle({ Name="Auto Sprint", CurrentValue=cfg.autoSprint, Flag="autoSprint", Callback=function(v) cfg.autoSprint = v end })
    
    TabMovement:CreateToggle({
        Name="Jump Power", CurrentValue=cfg.jumpPower, Flag="jumpPower",
        Callback=function(v)
            cfg.jumpPower = v
            if v then
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = cfg.jumpVal end
            else
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = 50 end
            end
        end,
    })
    TabMovement:CreateSlider({
        Name="Jump Height", Range={50,500}, Increment=1, Suffix="", CurrentValue=cfg.jumpVal, Flag="jumpVal",
        Callback=function(v)
            cfg.jumpVal = v
            if cfg.jumpPower then
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = v end
            end
        end,
    })
    TabMovement:CreateToggle({ Name="Infinite Jump", CurrentValue=cfg.infiniteJump, Flag="infiniteJump", Callback=function(v) cfg.infiniteJump = v end })
    TabMovement:CreateToggle({ Name="Noclip", CurrentValue=cfg.noclip, Flag="noclip", Callback=function(v) cfg.noclip = v end })
    TabMovement:CreateToggle({ Name="No Fall Damage", CurrentValue=cfg.noFallDamage, Flag="noFallDamage", Callback=function(v) cfg.noFallDamage = v end })
    TabMovement:CreateToggle({ Name="Third Person", CurrentValue=cfg.thirdPerson, Flag="thirdPerson", Callback=function(v) cfg.thirdPerson = v end })

    TabMovement:CreateSection("Gravity")
    TabMovement:CreateToggle({
        Name="Gravity Hack", CurrentValue=cfg.gravity, Flag="gravity",
        Callback=function(v)
            cfg.gravity = v
            workspace.Gravity = v and (DEFAULT_GRAVITY * cfg.gravityVal / 100) or DEFAULT_GRAVITY
        end,
    })
    TabMovement:CreateSlider({
        Name="Gravity %", Range={0,200}, Increment=1, Suffix="%", CurrentValue=cfg.gravityVal, Flag="gravityVal",
        Callback=function(v)
            cfg.gravityVal = v
            if cfg.gravity then workspace.Gravity = DEFAULT_GRAVITY * v / 100 end
        end,
    })

    TabMovement:CreateSection("Teleport")
    TabMovement:CreateButton({
        Name="Random Player [F]",
        Callback=function()
            local others = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(others, p)
                end
            end
            if #others == 0 then Rayfield:Notify({Title="Teleport", Content="No players found!", Duration=3}); return end
            local t = others[math.random(1, #others)]
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                myRoot.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
                if flyPart then flyPart.CFrame = myRoot.CFrame end
                Rayfield:Notify({Title="Teleport", Content="→ "..t.Name, Duration=3})
            end
        end,
    })
    TabMovement:CreateButton({
        Name="Closest Player [G]",
        Callback=function()
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local closest, best = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                    if d < best then closest = p; best = d end
                end
            end
            if not closest then Rayfield:Notify({Title="Teleport", Content="No players found!", Duration=3}); return end
            myRoot.CFrame = closest.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
            if flyPart then flyPart.CFrame = myRoot.CFrame end
            Rayfield:Notify({Title="Teleport", Content="→ "..closest.Name, Duration=3})
        end,
    })

    -- ============================================================
    --  PLAYER TAB (UNCHANGED)
    -- ============================================================
    TabPlayer:CreateSection("Anti-AFK")
    TabPlayer:CreateToggle({ Name="Anti-AFK", CurrentValue=cfg.antiAfk, Flag="antiAfk", Callback=function(v) cfg.antiAfk = v end })

    TabPlayer:CreateSection("Hitbox Expander")
    TabPlayer:CreateToggle({ Name="Hitbox Expander", CurrentValue=cfg.hitboxExpander, Flag="hitboxExpander", Callback=function(v) cfg.hitboxExpander = v end })
    TabPlayer:CreateSlider({ Name="Hitbox Size", Range={4,50}, Increment=1, Suffix="", CurrentValue=cfg.hitboxSize, Flag="hitboxSize", Callback=function(v) cfg.hitboxSize = v end })

    TabPlayer:CreateSection("Spin Bot")
    TabPlayer:CreateToggle({
        Name="Spin Bot",
        CurrentValue=cfg.spinBot,
        Flag="spinBot",
        Callback=function(v)
            cfg.spinBot = v
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.AutoRotate = not v
            end
        end
    })
    TabPlayer:CreateSlider({ Name="Spin Speed", Range={1,30}, Increment=1, Suffix="", CurrentValue=cfg.spinSpeed, Flag="spinSpeed", Callback=function(v) cfg.spinSpeed = v end })

    TabPlayer:CreateSection("Kill Aura")
    TabPlayer:CreateToggle({ Name="Kill Aura (needs tool)", CurrentValue=cfg.killAura, Flag="killAura", Callback=function(v) cfg.killAura = v end })
    TabPlayer:CreateSlider({ Name="Aura Range", Range={5,100}, Increment=1, Suffix=" studs", CurrentValue=cfg.killAuraRange, Flag="killAuraRange", Callback=function(v) cfg.killAuraRange = v end })

    -- ============================================================
    --  MISC TAB (UNCHANGED)
    -- ============================================================
    TabMisc:CreateSection("Misc")
    TabMisc:CreateToggle({
        Name="Fullbright", CurrentValue=cfg.fullbright, Flag="fullbright",
        Callback=function(v)
            cfg.fullbright = v
            local l = game:GetService("Lighting")
            l.Brightness = v and 10 or 1
            if v then l.ClockTime = 14 end
        end,
    })
    TabMisc:CreateToggle({ Name="Spam Click", CurrentValue=cfg.spamClick, Flag="spamClick", Callback=function(v) cfg.spamClick = v end })

    TabMisc:CreateSection("Extras")
    TabMisc:CreateButton({
        Name="Launch Flinger",
        Callback=function()
            Rayfield:Notify({Title="Extras", Content="Loading Flinger...", Duration=3})
            task.spawn(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/sypcerr/scripts/refs/heads/main/UFGUI", true))()
            end)
        end,
    })
    TabMisc:CreateButton({
        Name="Launch Infinite Yield",
        Callback=function()
            Rayfield:Notify({Title="Extras", Content="Loading Infinite Yield...", Duration=3})
            task.spawn(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source", true))()
            end)
        end,
    })

    TabMisc:CreateSection("Panic")
    TabMisc:CreateButton({
        Name="Toggle Panic [RCtrl]",
        Callback=function()
            setPanic(not panicOn)
            if panicOn then stopFly() end
            Rayfield:Notify({
                Title="Panic",
                Content=panicOn and "Panic ON — all cheats hidden" or "Panic OFF — cheats restored",
                Duration=3,
            })
        end,
    })

    TabMisc:CreateSection("Discord")
    TabMisc:CreateButton({
        Name="💬 Join our Discord",
        Callback=function()
            local discordUrl = "https://discord.gg/ZWsBVFhAnS"
            local success, err = pcall(function()
                if setclipboard then
                    setclipboard(discordUrl)
                    Rayfield:Notify({
                        Title="Discord",
                        Content="Link copied to clipboard!",
                        Duration=2
                    })
                else
                    game:GetService("GuiService"):OpenBrowserWindow(discordUrl)
                    Rayfield:Notify({
                        Title="Discord",
                        Content="Opening Discord...",
                        Duration=2
                    })
                end
            end)
            if not success then
                warn("Discord button error:", err)
                Rayfield:Notify({
                    Title="Error",
                    Content="Could not open Discord. Please visit: discord.gg/ZWsBVFhAnS",
                    Duration=4
                })
            end
        end
    })

    -- ============================================================
    --  KEY INFO TAB (UNCHANGED)
    -- ============================================================
    if currentKeyData then
        local kd = currentKeyData
        local showKey = false

        TabKeyInfo:CreateSection("Your Key")
        local keyLabel = TabKeyInfo:CreateLabel("Key: ••••••••••••••••")
        TabKeyInfo:CreateButton({
            Name="👁️ Toggle Key Visibility",
            Callback=function()
                showKey = not showKey
                local displayKey = showKey and kd.key or string.rep("•", #kd.key)
                keyLabel:Set("Key: " .. displayKey)
            end
        })

        TabKeyInfo:CreateSection("Details")
        TabKeyInfo:CreateLabel("Username: " .. (kd.username or "N/A"))
        TabKeyInfo:CreateLabel("User ID: " .. (kd.user_id or "N/A"))
        TabKeyInfo:CreateLabel("Type: " .. kd.type)
        TabKeyInfo:CreateLabel("Status: " .. kd.status)
        local expiresStr = kd.expires or "Never"
        TabKeyInfo:CreateLabel("Expires: " .. expiresStr)
    else
        TabKeyInfo:CreateLabel("No key data available.")
    end

    -- ============================================================
    --  PROFILE GUI (UNCHANGED)
    -- ============================================================
    local profileGui = Instance.new("ScreenGui")
    profileGui.Name = "ScreenGui"
    profileGui.ResetOnSpawn = false
    profileGui.DisplayOrder = 999
    profileGui.IgnoreGuiInset = true
    profileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    profileGui.Enabled = false
    profileGui.Parent = player.PlayerGui

    local overlay = Instance.new("TextButton", profileGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Text = ""
    overlay.ZIndex = 1

    local card = Instance.new("Frame", profileGui)
    card.Size = UDim2.new(0, 300, 0, 370)
    card.AnchorPoint = Vector2.new(1, 0)
    card.Position = UDim2.new(1, -16, 0, 16)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    card.BorderSizePixel = 0
    card.ZIndex = 2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = Color3.fromRGB(40, 40, 60); cardStroke.Thickness = 1

    local header = Instance.new("Frame", card)
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    header.BorderSizePixel = 0; header.ZIndex = 3
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
    local headerFix = Instance.new("Frame", header)
    headerFix.Size = UDim2.new(1, 0, 0.5, 0)
    headerFix.Position = UDim2.new(0, 0, 0.5, 0)
    headerFix.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    headerFix.BorderSizePixel = 0; headerFix.ZIndex = 3

    local headerTitle = Instance.new("TextLabel", header)
    headerTitle.Size = UDim2.new(1, -50, 1, 0)
    headerTitle.Position = UDim2.new(0, 14, 0, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Profile"
    headerTitle.TextColor3 = Color3.fromRGB(99, 102, 241)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 14
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.ZIndex = 4

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 25, 25)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(200, 70, 70)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.ZIndex = 4
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local avatarRing = Instance.new("Frame", card)
    avatarRing.Size = UDim2.new(0, 80, 0, 80)
    avatarRing.AnchorPoint = Vector2.new(0.5, 0)
    avatarRing.Position = UDim2.new(0.5, 0, 0, 60)
    avatarRing.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    avatarRing.BorderSizePixel = 0; avatarRing.ZIndex = 3
    Instance.new("UICorner", avatarRing).CornerRadius = UDim.new(1, 0)

    local avatarImg = Instance.new("ImageLabel", avatarRing)
    avatarImg.Size = UDim2.new(1, -4, 1, -4)
    avatarImg.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarImg.Position = UDim2.new(0.5, 0, 0.5, 0)
    avatarImg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    avatarImg.BackgroundTransparency = 0
    avatarImg.BorderSizePixel = 0
    avatarImg.Image = ""
    avatarImg.ZIndex = 4
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok then avatarImg.Image = img end
    end)

    local function makeLabel(parent, text, y, size, color, bold)
        local l = Instance.new("TextLabel", parent)
        l.Size = UDim2.new(1, -24, 0, size + 4)
        l.Position = UDim2.new(0, 12, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(220, 220, 235)
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextSize = size
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.ZIndex = 3
        return l
    end

    local displayLbl = makeLabel(card, player.DisplayName, 152, 16, Color3.fromRGB(230,230,245), true)
    local userLbl = makeLabel(card, "@"..player.Name, 175, 12, Color3.fromRGB(120,120,155), false)
    local idLbl = makeLabel(card, "ID: "..player.UserId, 192, 10, Color3.fromRGB(70,70,100), false)

    local divider = Instance.new("Frame", card)
    divider.Size = UDim2.new(1, -28, 0, 1)
    divider.Position = UDim2.new(0, 14, 0, 212)
    divider.BackgroundColor3 = Color3.fromRGB(35, 35, 52)
    divider.BorderSizePixel = 0; divider.ZIndex = 3

    local sessionLbl = makeLabel(card, "Session  00:00:00", 222, 11, Color3.fromRGB(180,180,210), false)
    local pingLbl = makeLabel(card, "Ping  —", 242, 11, Color3.fromRGB(180,180,210), false)
    local fpsLbl = makeLabel(card, "FPS  —", 262, 11, Color3.fromRGB(180,180,210), false)
    local ageLbl = makeLabel(card, "Account Age  "..player.AccountAge.." days", 282, 11, Color3.fromRGB(180,180,210), false)
    local versionLbl = makeLabel(card, "Vortex Hub v"..VERSION, 316, 9, Color3.fromRGB(55,55,80), false)

    RunService.Heartbeat:Connect(function()
        if not profileGui.Enabled then return end
        local elapsed = tick() - sessionStart
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = math.floor(elapsed % 60)
        sessionLbl.Text = string.format("Session  %02d:%02d:%02d", h, m, s)
        pingLbl.Text = string.format("Ping  %dms", math.floor(player:GetNetworkPing() * 1000))
        fpsLbl.Text = string.format("FPS  %d", math.floor(1 / RunService.RenderStepped:Wait()))
    end)

    local function closeProfile()
        profileGui.Enabled = false
    end

    local function openProfile()
        profileGui.Enabled = true
    end

    overlay.MouseButton1Click:Connect(closeProfile)
    closeBtn.MouseButton1Click:Connect(closeProfile)

    task.delay(1.5, function()
        local rayfieldGui = player.PlayerGui:FindFirstChild("Rayfield")
        if not rayfieldGui then return end

        local mainFrame = rayfieldGui:FindFirstChildOfClass("Frame")
        if not mainFrame then return end

        local titleBar
        for _, child in ipairs(mainFrame:GetDescendants()) do
            if child:IsA("Frame") and child.Size.Y.Offset > 0 and child.Size.Y.Offset < 60
            and child.Size.X.Scale >= 0.9 and child.AbsolutePosition.Y < 80 then
                titleBar = child
                break
            end
        end

        if not titleBar then return end

        local profileBtn = Instance.new("TextButton", titleBar)
        profileBtn.Size = UDim2.new(0, 26, 0, 26)
        profileBtn.AnchorPoint = Vector2.new(1, 0.5)
        profileBtn.Position = UDim2.new(1, -42, 0.5, 0)
        profileBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
        profileBtn.BorderSizePixel = 0
        profileBtn.Text = "👤"
        profileBtn.TextSize = 13
        profileBtn.Font = Enum.Font.GothamBold
        profileBtn.TextColor3 = Color3.fromRGB(160, 160, 200)
        profileBtn.ZIndex = 200
        Instance.new("UICorner", profileBtn).CornerRadius = UDim.new(0, 6)

        profileBtn.MouseButton1Click:Connect(function()
            if profileGui.Enabled then
                closeProfile()
            else
                openProfile()
            end
        end)
    end)

    -- ============================================================
    --  INPUT BINDINGS
    -- ============================================================
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        if input.KeyCode == Enum.KeyCode.RightControl then
            setPanic(not panicOn)
            if panicOn then stopFly() end
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
            if #others == 0 then return end
            local t = others[math.random(1, #others)]
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                myRoot.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
                if flyPart then flyPart.CFrame = myRoot.CFrame end
            end
        end

        if input.KeyCode == Enum.KeyCode.G then
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local closest, best = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                    if d < best then closest = p; best = d end
                end
            end
            if not closest then return end
            myRoot.CFrame = closest.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
            if flyPart then flyPart.CFrame = myRoot.CFrame end
        end
    end)

    player.CharacterAdded:Connect(stopFly)

end -- end of createMainMenu()

-- ============================================================
--  KEY ENTRY SCREEN
-- ============================================================
local KeyWindow = nil
local keyRedeemed = false

function showKeyEntryScreen()
    KeyWindow = Rayfield:CreateWindow({
        Name = "🔑 Key Required",
        LoadingTitle = "Please enter your key",
        LoadingSubtitle = "You need a valid key to use Vortex Hub",
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
        Callback = function(text)
            currentKeyText = text
        end
    })

    local statusLabel = tab:CreateLabel("")
    statusLabel:Set("")

    tab:CreateButton({
        Name = "Redeem Key",
        Callback = function()
            local ok, err = pcall(function()
                local key = currentKeyText
                if not key or #key < 16 then
                    statusLabel:Set("❌ Please enter a valid key (16 characters)")
                    return
                end
                key = string.upper(string.gsub(key, "%s+", ""))
                if #key < 16 then
                    statusLabel:Set("❌ Key must be at least 16 characters")
                    return
                end

                print("Sending key to Supabase:", key)
                statusLabel:Set("⏳ Checking key...")

                local result, msg, flag = redeemKey(key, tostring(player.UserId), player.Name)

                if result then
                    currentKeyData = result
                    keyRedeemed = true
                    if flag == "already_owned" then
                        statusLabel:Set("✅ Key already active! Loading menu...")
                    else
                        statusLabel:Set("✅ Key redeemed successfully!")
                    end
                    task.wait(1)

                    if KeyWindow then
                        pcall(function()
                            if KeyWindow.Destroy then KeyWindow:Destroy()
                            elseif KeyWindow.Close then KeyWindow:Close()
                            elseif KeyWindow.Gui and KeyWindow.Gui.Destroy then KeyWindow.Gui:Destroy()
                            end
                        end)
                        KeyWindow = nil
                    end

                    createMainMenu()
                else
                    local displayMsg = msg or "Unknown error"
                    if type(displayMsg) == "string" and string.find(displayMsg, "belongs to another user") then
                        displayMsg = "This key is registered to a different user!\nIf you changed your username recently or believe this is a bug, join our Discord for support."
                    end
                    statusLabel:Set("❌ " .. displayMsg)
                    print("Redeem failed:", displayMsg)
                end
            end)

            if not ok then
                warn("Key redeem callback error:", err)
                statusLabel:Set("❌ Script error: " .. tostring(err))
            end
        end
    })

    tab:CreateButton({
        Name = "💬 Don't have a key? Purchase one at our Discord!",
        Callback = function()
            local discordUrl = "https://discord.gg/ZWsBVFhAnS"
            local ok, err = pcall(function()
                if setclipboard then
                    setclipboard(discordUrl)
                    statusLabel:Set("🔗 Discord link copied to clipboard!")
                else
                    game:GetService("GuiService"):OpenBrowserWindow(discordUrl)
                    statusLabel:Set("🔗 Opening Discord...")
                end
            end)
            if not ok then
                warn("Discord open error:", err)
                statusLabel:Set("❌ Could not open. Please manually visit: discord.gg/ZWsBVFhAnS")
            end
        end
    })
end

-- ============================================================
--  STARTUP - Validate key on load
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
