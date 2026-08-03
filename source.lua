-- Vortex Hub v2.66 - FULL MENU EDITION
local VERSION = "2.66"

-- ============================================================
--  SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local DEFAULT_GRAVITY = workspace.Gravity

-- ============================================================
--  CONFIGURATION - ALL FEATURES
-- ============================================================
local cfg = {
    aimbot = {enabled = false, teamCheck = true, fov = 75, smoothness = 5, part = "HumanoidRootPart"},
    softAim = {enabled = false, strength = 3},
    silentAim = {enabled = false},
    esp = {
        enabled = true, boxes = true, names = true, health = true, tracers = false,
        bones = false, distance = true, rainbow = false, maxDistance = 3000,
        maxPlayers = 30, useTeamColor = true
    },
    movement = {
        fly = false, flySpeed = 50, speed = false, speedVal = 24, jumpPower = false,
        jumpVal = 70, infiniteJump = false, noClip = false, noFallDamage = false,
        autoSprint = false, thirdPerson = false, gravity = false, gravityVal = 100,
        antiAfk = false
    },
    combat = {
        spinBot = false, spinSpeed = 5, killAura = false, killAuraRange = 15,
        hitboxExpander = false, hitboxSize = 6
    },
    visuals = {
        fovChanger = false, fovVal = 70, fullbright = false, crosshair = false,
        crosshairSize = 10
    }
}

-- ============================================================
--  NEURAL NETWORK
-- ============================================================
local nn = {
    weights = {}, biases = {},
    init = function(self)
        for i = 1, 16 do self.weights[i] = {} for j = 1, 32 do self.weights[i][j] = (math.random() - 0.5) * 2 end end
        for i = 1, 32 do self.biases[i] = 0.1 end return self
    end,
    forward = function(self, inputs)
        local h = {}
        for j = 1, 32 do
            local sum = self.biases[j]
            for i = 1, 16 do sum = sum + inputs[i] * (self.weights[i][j] or 0) end
            h[j] = sum / (1 + math.exp(-sum))
        end
        local out = {}
        for j = 1, 8 do
            local sum = 0
            for i = 1, 32 do sum = sum + h[i] * (math.random() - 0.5) * 2 end
            out[j] = math.tanh(sum)
        end
        return out
    end
}
nn:init()

-- ============================================================
--  AIMBOT ENGINE
-- ============================================================
local perf = {shots = 0, hits = 0}
local function getTarget()
    local best, bestScore = nil, -math.huge
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        if cfg.aimbot.teamCheck and player.Team and plr.Team == player.Team then continue end
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(cfg.aimbot.part) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local pos, vis = Camera:WorldToViewportPoint(part.Position)
        if not vis then continue end
        local dist = (part.Position - rootPart.Position).Magnitude
        local angle = (Vector2.new(pos.X, pos.Y) - center).Magnitude
        local inputs = {dist/2000, angle/180, 0,0,0, hum.Health/hum.MaxHealth, math.sin(os.time()*0.1), math.cos(os.time()*0.1), 0,0,0,0,0,0,0,0}
        local out = nn:forward(inputs)
        local score = out[1] * 0.4 + out[2] * 0.3 + out[3] * 0.2 + out[4] * 0.1
        if score > bestScore then bestScore = score; best = {part = part, pos = part.Position, angle = angle} end
    end
    return best
end

local function updateAimbot()
    if cfg.aimbot.enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = getTarget()
        if target then
            local smooth = cfg.aimbot.smoothness / 10
            local newCF = CFrame.new(Camera.CFrame.Position, target.pos)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, smooth)
            perf.shots = perf.shots + 1
            if target.angle < 5 then perf.hits = perf.hits + 1 end
        end
    end
    -- Soft Aim
    if cfg.softAim.enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local target = getTarget()
        if target then
            local smooth = cfg.softAim.strength / 20
            local newCF = CFrame.new(Camera.CFrame.Position, target.pos)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, smooth)
        end
    end
    -- Silent Aim
    if cfg.silentAim.enabled then
        local target = getTarget()
        if target then
            local savedCF = Camera.CFrame
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.pos)
            task.defer(function() if cfg.silentAim.enabled then Camera.CFrame = savedCF end end)
        end
    end
end

-- ============================================================
--  FLY SYSTEM
-- ============================================================
local flyPart, flyVel, flyWeld, flyConn = nil, nil, nil, nil
local function stopFly()
    cfg.movement.fly = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyPart then flyPart:Destroy(); flyPart = nil end
    flyWeld = nil; flyVel = nil
end
local function startFly()
    local root = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    cfg.movement.fly = true
    flyPart = Instance.new("Part")
    flyPart.Name = "Fly"
    flyPart.Size = Vector3.new(1,0.2,1)
    flyPart.Transparency = 1
    flyPart.CanCollide = false
    flyPart.Anchored = false
    flyPart.CFrame = root.CFrame
    flyPart.Parent = workspace
    flyVel = Instance.new("BodyVelocity", flyPart)
    flyVel.Velocity = Vector3.zero
    flyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
    flyVel.P = 1e4
    flyWeld = Instance.new("WeldConstraint", flyPart)
    flyWeld.Part0 = flyPart
    flyWeld.Part1 = root
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    flyConn = RunService.RenderStepped:Connect(function()
        if not cfg.movement.fly then stopFly(); return end
        local cam = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        flyVel.Velocity = dir.Magnitude > 0 and dir.Unit * cfg.movement.flySpeed or Vector3.zero
    end)
end

-- ============================================================
--  ESP SYSTEM
-- ============================================================
local espGui = Instance.new("ScreenGui")
espGui.Name = "ESP"
espGui.ResetOnSpawn = false
espGui.Parent = player.PlayerGui

local espObjs = {}
local function createESP()
    local o = {box = {}, bones = {}}
    for _, n in ipairs({"t","b","l","r"}) do
        local f = Instance.new("Frame", espGui)
        f.BackgroundColor3 = Color3.new(1,1,1)
        f.BackgroundTransparency = 0
        f.BorderSizePixel = 0
        f.Size = UDim2.new(0,0,0,0)
        f.Visible = false
        o.box[n] = f
    end
    local hb = Instance.new("Frame", espGui)
    hb.BackgroundColor3 = Color3.fromRGB(20,20,20)
    hb.BorderSizePixel = 0
    hb.Visible = false
    o.healthBG = hb
    local hf = Instance.new("Frame", espGui)
    hf.BackgroundColor3 = Color3.fromRGB(34,197,94)
    hf.BorderSizePixel = 0
    hf.Visible = false
    o.healthBar = hf
    local nl = Instance.new("TextLabel", espGui)
    nl.BackgroundTransparency = 1
    nl.TextColor3 = Color3.new(1,1,1)
    nl.TextStrokeTransparency = 0
    nl.TextStrokeColor3 = Color3.new(0,0,0)
    nl.TextSize = 12
    nl.Font = Enum.Font.GothamBold
    nl.Size = UDim2.new(0,300,0,16)
    nl.TextXAlignment = Enum.TextXAlignment.Center
    nl.Visible = false
    o.nameLabel = nl
    local tr = Instance.new("Frame", espGui)
    tr.AnchorPoint = Vector2.new(0.5,0.5)
    tr.BackgroundColor3 = Color3.new(1,1,1)
    tr.BackgroundTransparency = 0
    tr.BorderSizePixel = 0
    tr.Size = UDim2.new(0,0,0,1)
    tr.Visible = false
    o.tracer = tr
    for i = 1, 15 do
        local b = Instance.new("Frame", espGui)
        b.AnchorPoint = Vector2.new(0.5,0.5)
        b.BackgroundColor3 = Color3.new(1,1,1)
        b.BackgroundTransparency = 0
        b.BorderSizePixel = 0
        b.Size = UDim2.new(0,0,0,1)
        b.Visible = false
        o.bones[i] = b
    end
    return o
end

local bonePairs = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"}
}

for _, p in ipairs(Players:GetPlayers()) do if p ~= player then espObjs[p] = createESP() end end
Players.PlayerAdded:Connect(function(p) espObjs[p] = createESP() end)

RunService.RenderStepped:Connect(function()
    if not cfg.esp.enabled then
        for _, o in pairs(espObjs) do
            for _, f in pairs(o.box) do f.Visible = false end
            o.healthBG.Visible = false; o.healthBar.Visible = false
            o.nameLabel.Visible = false; o.tracer.Visible = false
            for _, b in ipairs(o.bones) do b.Visible = false end
        end
        return
    end
    local count, center = 0, Camera.ViewportSize / 2
    for plr, o in pairs(espObjs) do
        if count >= cfg.esp.maxPlayers then break end
        local char, hum, root = plr.Character, plr.Character and plr.Character:FindFirstChildOfClass("Humanoid"), plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not (char and hum and root) or hum.Health <= 0 then
            for _, f in pairs(o.box) do f.Visible = false end
            o.healthBG.Visible = false; o.healthBar.Visible = false
            o.nameLabel.Visible = false; o.tracer.Visible = false
            for _, b in ipairs(o.bones) do b.Visible = false end
            continue
        end
        local dist = (root.Position - rootPart.Position).Magnitude
        if dist > cfg.esp.maxDistance then
            for _, f in pairs(o.box) do f.Visible = false end
            o.healthBG.Visible = false; o.healthBar.Visible = false
            o.nameLabel.Visible = false; o.tracer.Visible = false
            for _, b in ipairs(o.bones) do b.Visible = false end
            continue
        end
        local pos, vis = Camera:WorldToViewportPoint(root.Position)
        if not vis then
            for _, f in pairs(o.box) do f.Visible = false end
            o.healthBG.Visible = false; o.healthBar.Visible = false
            o.nameLabel.Visible = false; o.tracer.Visible = false
            for _, b in ipairs(o.bones) do b.Visible = false end
            continue
        end
        count = count + 1
        local color = cfg.esp.rainbow and Color3.fromHSV((tick()*0.05)%1,1,1) or (cfg.esp.useTeamColor and plr.Team and plr.Team.TeamColor.Color) or Color3.fromRGB(255,255,255)
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local valid = false
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local p, v = Camera:WorldToViewportPoint(part.Position)
                if v then valid = true; minX = math.min(minX, p.X); minY = math.min(minY, p.Y); maxX = math.max(maxX, p.X); maxY = math.max(maxY, p.Y) end
            end
        end
        if valid and cfg.esp.boxes then
            local w, h, t, cs = maxX - minX, maxY - minY, 2, math.min(8, (maxX-minX)/5)
            o.box.t.Position = UDim2.new(0, minX, 0, minY); o.box.t.Size = UDim2.new(0, cs, 0, t); o.box.t.BackgroundColor3 = color; o.box.t.Visible = true
            o.box.b.Position = UDim2.new(0, maxX - cs, 0, minY); o.box.b.Size = UDim2.new(0, cs, 0, t); o.box.b.BackgroundColor3 = color; o.box.b.Visible = true
            o.box.l.Position = UDim2.new(0, minX, 0, maxY - t); o.box.l.Size = UDim2.new(0, cs, 0, t); o.box.l.BackgroundColor3 = color; o.box.l.Visible = true
            o.box.r.Position = UDim2.new(0, maxX - cs, 0, maxY - t); o.box.r.Size = UDim2.new(0, cs, 0, t); o.box.r.BackgroundColor3 = color; o.box.r.Visible = true
        else for _, f in pairs(o.box) do f.Visible = false end end
        if valid and cfg.esp.health then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local hc = Color3.fromHSV(0.3 * pct, 1, 0.6)
            local bw, bh, x, y = 40, 3, (minX+maxX)/2 - 20, minY - 10
            o.healthBG.Position = UDim2.new(0, x, 0, y); o.healthBG.Size = UDim2.new(0, bw, 0, bh); o.healthBG.Visible = true
            o.healthBar.Position = UDim2.new(0, x, 0, y); o.healthBar.Size = UDim2.new(0, bw * pct, 0, bh); o.healthBar.BackgroundColor3 = hc; o.healthBar.Visible = true
        else o.healthBG.Visible = false; o.healthBar.Visible = false end
        if cfg.esp.names then
            local text = plr.Name; if cfg.esp.distance then text = text .. " | " .. math.floor(dist) .. "m" end
            o.nameLabel.Text = text; o.nameLabel.TextColor3 = color; o.nameLabel.Position = UDim2.new(0, (minX+maxX)/2 - 150, 0, minY - 30); o.nameLabel.Visible = true
        else o.nameLabel.Visible = false end
        if cfg.esp.tracers then
            local x1, y1, x2, y2 = center.X, center.Y, (minX+maxX)/2, maxY
            local dx, dy, len = x2 - x1, y2 - y1, math.sqrt((x2-x1)^2 + (y2-y1)^2)
            o.tracer.Position = UDim2.new(0, (x1+x2)/2, 0, (y1+y2)/2); o.tracer.Size = UDim2.new(0, len, 0, 1); o.tracer.Rotation = math.deg(math.atan2(dy, dx)); o.tracer.BackgroundColor3 = color; o.tracer.Visible = true
        else o.tracer.Visible = false end
        if cfg.esp.bones then
            for i, pair in ipairs(bonePairs) do
                local pA, pB = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                if pA and pB then
                    local p1, v1 = Camera:WorldToViewportPoint(pA.Position)
                    local p2, v2 = Camera:WorldToViewportPoint(pB.Position)
                    if v1 and v2 then
                        local dx, dy, len = p2.X - p1.X, p2.Y - p1.Y, math.sqrt((p2.X-p1.X)^2 + (p2.Y-p1.Y)^2)
                        local b = o.bones[i]
                        b.Position = UDim2.new(0, (p1.X+p2.X)/2, 0, (p1.Y+p2.Y)/2); b.Size = UDim2.new(0, len, 0, 1); b.Rotation = math.deg(math.atan2(dy, dx)); b.BackgroundColor3 = color; b.Visible = true
                    else o.bones[i].Visible = false end
                else o.bones[i].Visible = false end
            end
        else for _, b in ipairs(o.bones) do b.Visible = false end end
    end
end)

-- ============================================================
--  MOVEMENT SYSTEMS
-- ============================================================
RunService.RenderStepped:Connect(function()
    if cfg.combat.spinBot then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(cfg.combat.spinSpeed * 0.5), 0) end
    end
    if cfg.movement.autoSprint and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = hum.MoveDirection.Magnitude > 0 and cfg.movement.speedVal or 16 end
    end
    if cfg.movement.speed and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = cfg.movement.speedVal end
    end
    if cfg.movement.jumpPower and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = cfg.movement.jumpVal end
    end
    if cfg.movement.gravity then workspace.Gravity = DEFAULT_GRAVITY * (cfg.movement.gravityVal / 100) end
    if cfg.visuals.fovChanger then Camera.FieldOfView = cfg.visuals.fovVal end
    if cfg.visuals.fullbright then Lighting.Brightness = 10; Lighting.ClockTime = 14 else Lighting.Brightness = 1 end
    if cfg.movement.noClip and character then
        for _, p in ipairs(character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end
    if cfg.movement.noFallDamage and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end
    end
    if cfg.movement.thirdPerson and character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then Camera.CameraSubject = root; Camera.CameraType = Enum.CameraType.Custom end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if cfg.movement.infiniteJump and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

player.Idled:Connect(function()
    if cfg.movement.antiAfk then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Jump = true end
    end
end)

-- ============================================================
--  HITBOX EXPANDER
-- ============================================================
local hbParts = {}
local function removeHB(p) if hbParts[p] then hbParts[p]:Destroy(); hbParts[p] = nil end end
local function buildHB(p)
    if p == player then return end
    removeHB(p)
    local char, root = p.Character, p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hb = Instance.new("Part")
    hb.Name = "VortexHitbox"
    hb.Size = Vector3.new(cfg.combat.hitboxSize, cfg.combat.hitboxSize, cfg.combat.hitboxSize)
    hb.Transparency = 1
    hb.CanCollide = false
    hb.CastShadow = false
    hb.Anchored = false
    hb.CFrame = root.CFrame
    hb.Parent = workspace
    local w = Instance.new("WeldConstraint", hb)
    w.Part0 = hb
    w.Part1 = root
    hbParts[p] = hb
end
RunService.Heartbeat:Connect(function()
    if cfg.combat.hitboxExpander then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and not hbParts[p] then buildHB(p) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do removeHB(p) end
    end
end)

-- ============================================================
--  KILL AURA
-- ============================================================
RunService.Heartbeat:Connect(function()
    if cfg.combat.killAura then
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == player then continue end
                local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                local pHum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if pRoot and pHum and pHum.Health > 0 then
                    local d = (pRoot.Position - myRoot.Position).Magnitude
                    if d < cfg.combat.killAuraRange then
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
--  COMPLETE MENU WITH ALL FEATURES
-- ============================================================
local menuVisible = false
local menuGui = nil
local currentTab = "Aimbot"

local function createMenu()
    if menuGui then
        menuGui:Destroy()
        menuGui = nil
        menuVisible = false
        return
    end
    
    menuGui = Instance.new("ScreenGui")
    menuGui.Name = "VortexHub"
    menuGui.Parent = player.PlayerGui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 450, 0, 550)
    main.Position = UDim2.new(0.5, -225, 0.5, -275)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    main.BorderSizePixel = 0
    main.Parent = menuGui
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = main
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 45)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "VORTEX HUB v" .. VERSION
    title.TextColor3 = Color3.fromRGB(150, 120, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() createMenu() end)
    
    -- Tab Buttons
    local tabNames = {"Aimbot", "ESP", "Movement", "Combat", "Visuals"}
    local tabButtons = {}
    
    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 86, 0, 32)
        btn.Position = UDim2.new(0, 8 + (i-1) * 88, 0, 50)
        btn.Text = name
        btn.TextColor3 = name == currentTab and Color3.fromRGB(150, 120, 255) or Color3.fromRGB(180, 180, 200)
        btn.BackgroundColor3 = name == currentTab and Color3.fromRGB(30, 25, 50) or Color3.fromRGB(25, 25, 40)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = main
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            currentTab = name
            for _, b in ipairs(tabButtons) do
                b.TextColor3 = b.Text == currentTab and Color3.fromRGB(150, 120, 255) or Color3.fromRGB(180, 180, 200)
                b.BackgroundColor3 = b.Text == currentTab and Color3.fromRGB(30, 25, 50) or Color3.fromRGB(25, 25, 40)
            end
            createMenu()
        end)
        tabButtons[i] = btn
    end
    
    -- Content Frame
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 0, 420)
    content.Position = UDim2.new(0, 10, 0, 88)
    content.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    content.BorderSizePixel = 0
    content.Parent = main
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = content
    
    -- Helper function to create toggle
    local function createToggle(parent, text, y, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 30)
        frame.Position = UDim2.new(0, 10, 0, y)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 4)
        fCorner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 140, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 40, 0, 22)
        btn.Position = UDim2.new(1, -45, 0.5, -11)
        btn.Text = getter() and "ON" or "OFF"
        btn.TextColor3 = getter() and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
        btn.BackgroundColor3 = getter() and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(70, 30, 30)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.Parent = frame
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            setter(not getter())
            btn.Text = getter() and "ON" or "OFF"
            btn.TextColor3 = getter() and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
            btn.BackgroundColor3 = getter() and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(70, 30, 30)
        end)
        return frame
    end
    
    -- Helper function to create slider
    local function createSlider(parent, text, y, min, max, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 40)
        frame.Position = UDim2.new(0, 10, 0, y)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.Text = text .. ": " .. getter()
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.P
