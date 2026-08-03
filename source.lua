-- Vortex Hub v2.66 - COMPLETE MENU EDITION
local VERSION = "2.66"

-- SERVICES
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

-- CONFIG
local cfg = {
    aimbot = {enabled = false, teamCheck = true, fov = 75, smoothness = 5, part = "HumanoidRootPart"},
    softAim = {enabled = false, strength = 3},
    silentAim = {enabled = false},
    esp = {enabled = true, boxes = true, names = true, health = true, tracers = false, bones = false, distance = true, rainbow = false, maxDistance = 3000, maxPlayers = 30, useTeamColor = true},
    movement = {fly = false, flySpeed = 50, speed = false, speedVal = 24, jumpPower = false, jumpVal = 70, infiniteJump = false, noClip = false, noFallDamage = false, autoSprint = false, thirdPerson = false, gravity = false, gravityVal = 100, antiAfk = false},
    combat = {spinBot = false, spinSpeed = 5, killAura = false, killAuraRange = 15, hitboxExpander = false, hitboxSize = 6},
    visuals = {fovChanger = false, fovVal = 70, fullbright = false}
}

-- NEURAL NETWORK
local nn = {
    weights = {}, biases = {},
    init = function(self)
        for i = 1, 16 do self.weights[i] = {} for j = 1, 32 do self.weights[i][j] = (math.random() - 0.5) * 2 end end
        for i = 1, 32 do self.biases[i] = 0.1 end
        return self
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

-- AIMBOT
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
    if cfg.softAim.enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local target = getTarget()
        if target then
            local smooth = cfg.softAim.strength / 20
            local newCF = CFrame.new(Camera.CFrame.Position, target.pos)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, smooth)
        end
    end
    if cfg.silentAim.enabled then
        local target = getTarget()
        if target then
            local savedCF = Camera.CFrame
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.pos)
            task.defer(function() if cfg.silentAim.enabled then Camera.CFrame = savedCF end end)
        end
    end
end

-- FLY SYSTEM
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

-- ESP
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

-- MOVEMENT SYSTEMS
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

-- HITBOX EXPANDER
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

-- KILL AURA
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
                                if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
--  COMPLETE MENU
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
    main.Size = UDim2.new(0, 450, 0, 520)
    main.Position = UDim2.new(0.5, -225, 0.5, -260)
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
    
    -- Tabs
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
    
    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 0, 400)
    content.Position = UDim2.new(0, 10, 0, 88)
    content.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    content.BorderSizePixel = 0
    content.Parent = main
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = content
    
    -- Helper: Toggle
    local function makeToggle(parent, text, y, getter, setter)
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
    
    -- Helper: Slider
    local function makeSlider(parent, text, y, min, max, getter, setter)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 35)
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
        label.Parent = frame
        
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 4)
        track.Position = UDim2.new(0, 0, 0, 20)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        track.BorderSizePixel = 0
        track.Parent = frame
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 2)
        trackCorner.Parent = track
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((getter() - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(150, 120, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 2)
        fillCorner.Parent = fill
        
        local dragging = false
        local dragBtn = Instance.new("TextButton")
        dragBtn.Size = UDim2.new(0, 12, 0, 12)
        dragBtn.Position = UDim2.new((getter() - min) / (max - min), -6, 0.5, -6)
        dragBtn.Text = ""
        dragBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 255)
        dragBtn.BorderSizePixel = 0
        dragBtn.Parent = track
        local dragCorner = Instance.new("UICorner")
        dragCorner.CornerRadius = UDim.new(1, 0)
        dragCorner.Parent = dragBtn
        
        dragBtn.MouseButton1Down:Connect(function() dragging = true end)
        dragBtn.MouseButton1Up:Connect(function() dragging = false end)
        dragBtn.MouseLeave:Connect(function() dragging = false end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                local mouse = player:GetMouse()
                local pos = mouse.X - track.AbsolutePosition.X
                local newVal = math.clamp((pos / track.AbsoluteSize.X) * (max - min) + min, min, max)
                newVal = math.round(newVal)
                setter(newVal)
                label.Text = text .. ": " .. getter()
                fill.Size = UDim2.new((getter() - min) / (max - min), 0, 1, 0)
                dragBtn.Position = UDim2.new((getter() - min) / (max - min), -6, 0.5, -6)
            end
        end)
        
        return frame
    end
    
    -- ====== AIMBOT TAB ======
    if currentTab == "Aimbot" then
        local y = 10
        makeToggle(content, "Aimbot", y, function() return cfg.aimbot.enabled end, function(v) cfg.aimbot.enabled = v end)
        y = y + 35
        makeToggle(content, "Team Check", y, function() return cfg.aimbot.teamCheck end, function(v) cfg.aimbot.teamCheck = v end)
        y = y + 35
        makeToggle(content, "Soft Aim", y, function() return cfg.softAim.enabled end, function(v) cfg.softAim.enabled = v end)
        y = y + 35
        makeToggle(content, "Silent Aim", y, function() return cfg.silentAim.enabled end, function(v) cfg.silentAim.enabled = v end)
        y = y + 35
        makeSlider(content, "Smoothness", y, 1, 10, function() return cfg.aimbot.smoothness end, function(v) cfg.aimbot.smoothness = v end)
        y = y + 40
        makeSlider(content, "Soft Aim Strength", y, 1, 10, function() return cfg.softAim.strength end, function(v) cfg.softAim.strength = v end)
        y = y + 40
        makeSlider(content, "FOV", y, 10, 500, function() return cfg.aimbot.fov end, function(v) cfg.aimbot.fov = v end)
    end
    
    -- ====== ESP TAB ======
    if currentTab == "ESP" then
        local y = 10
        makeToggle(content, "ESP", y, function() return cfg.esp.enabled end, function(v) cfg.esp.enabled = v end)
        y = y + 35
        makeToggle(content, "Boxes", y, function() return cfg.esp.boxes end, function(v) cfg.esp.boxes = v end)
        y = y + 35
        makeToggle(content, "Names", y, function() return cfg.esp.names end, function(v) cfg.esp.names = v end)
        y = y + 35
        makeToggle(content, "Health Bars", y, function() return cfg.esp.health end, function(v) cfg.esp.health = v end)
        y = y + 35
        makeToggle(content, "Tracers", y, function() return cfg.esp.tracers end, function(v) cfg.esp.tracers = v end)
        y = y + 35
        makeToggle(content, "Bones", y, function() return cfg.esp.bones end, function(v) cfg.esp.bones = v end)
        y = y + 35
        makeToggle(content, "Distance", y, function() return cfg.esp.distance end, function(v) cfg.esp.distance = v end)
        y = y + 35
        makeToggle(content, "Rainbow", y, function() return cfg.esp.rainbow end, function(v) cfg.esp.rainbow = v end)
        y = y + 35
        makeSlider(content, "Max Distance", y, 500, 5000, function() return cfg.esp.maxDistance end, function(v) cfg.esp.maxDistance = v end)
        y = y + 40
        makeSlider(content, "Max Players", y, 5, 50, function() return cfg.esp.maxPlayers end, function(v) cfg.esp.maxPlayers = v end)
    end
    
    -- ====== MOVEMENT TAB ======
    if currentTab == "Movement" then
        local y = 10
        makeToggle(content, "Fly", y, function() return cfg.movement.fly end, function(v) cfg.movement.fly = v; if v then startFly() else stopFly() end end)
        y = y + 35
        makeToggle(content, "Speed Hack", y, function() return cfg.movement.speed end, function(v) cfg.movement.speed = v end)
        y = y + 35
        makeToggle(content, "Jump Power", y, function() return cfg.movement.jumpPower end, function(v) cfg.movement.jumpPower = v end)
        y = y + 35
        makeToggle(content, "Infinite Jump", y, function() return cfg.movement.infiniteJump end, function(v) cfg.movement.infiniteJump = v end)
        y = y + 35
        makeToggle(content, "No Clip", y, function() return cfg.movement.noClip end, function(v) cfg.movement.noClip = v end)
        y = y + 35
        makeToggle(content, "No Fall Damage", y, function() return cfg.movement.noFallDamage end, function(v) cfg.movement.noFallDamage = v end)
        y = y + 35
        makeToggle(content, "Auto Sprint", y, function() return cfg.movement.autoSprint end, function(v) cfg.movement.autoSprint = v end)
        y = y + 35
        makeToggle(content, "Third Person", y, function() return cfg.movement.thirdPerson end, function(v) cfg.movement.thirdPerson = v end)
        y = y + 35
        makeToggle(content, "Anti-AFK", y, function() return cfg.movement.antiAfk end, function(v) cfg.movement.antiAfk = v end)
        y = y + 35
        makeToggle(content, "Gravity Hack", y, function() return cfg.movement.gravity end, function(v) cfg.movement.gravity = v end)
        y = y + 35
        makeSlider(content, "Fly Speed", y, 10, 300, function() return cfg.movement.flySpeed end, function(v) cfg.movement.flySpeed = v end)
        y = y + 40
        makeSlider(content, "Walk Speed", y, 16, 200, function() return cfg.movement.speedVal end, function(v) cfg.movement.speedVal = v end)
        y = y + 40
        makeSlider(content, "Jump Height", y, 50, 500, function() return cfg.movement.jumpVal end, function(v) cfg.movement.jumpVal = v end)
        y = y + 40
        makeSlider(content, "Gravity %", y, 0, 200, function() return cfg.movement.gravityVal end, function(v) cfg.movement.gravityVal = v end)
    end
    
    -- ====== COMBAT TAB ======
    if currentTab == "Combat" then
        local y = 10
        makeToggle(content, "Spin Bot", y, function() return cfg.combat.spinBot end, function(v) cfg.combat.spinBot = v end)
        y = y + 35
        makeToggle(content, "Kill Aura", y, function() return cfg.combat.killAura end, function(v) cfg.combat.killAura = v end)
        y = y + 35
        makeToggle(content, "Hitbox Expander", y, function() return cfg.combat.hitboxExpander end, function(v) cfg.combat.hitboxExpander = v end)
        y = y + 35
        makeSlider(content, "Spin Speed", y, 1, 30, function() return cfg.combat.spinSpeed end, function(v) cfg.combat.spinSpeed = v end)
        y = y + 40
        makeSlider(content, "Kill Aura Range", y, 5, 100, function() return cfg.combat.killAuraRange end, function(v) cfg.combat.killAuraRange = v end)
        y = y + 40
        makeSlider(content, "Hitbox Size", y, 4, 50, function() return cfg.combat.hitboxSize end, function(v) cfg.combat.hitboxSize = v end)
    end
    
    -- ====== VISUALS TAB ======
    if currentTab == "Visuals" then
        local y = 10
        makeToggle(content, "FOV Changer", y, function() return cfg.visuals.fovChanger end, function(v) cfg.visuals.fovChanger = v end)
        y = y + 35
        makeToggle(content, "Fullbright", y, function() return cfg.visuals.fullbright end, function(v) cfg.visuals.fullbright = v end)
        y = y + 35
        makeSlider(content, "FOV Value", y, 40, 120, function() return cfg.visuals.fovVal end, function(v) cfg.visuals.fovVal = v end)
    end
    
    menuVisible = true
end

-- ====== KEYBIND ======
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Semicolon then
        createMenu()
    end
end)

-- ====== MAIN ======
print("Vortex Hub v" .. VERSION .. " loaded!")
print("Press ; to open menu")

RunService.RenderStepped:Connect(function()
    updateAimbot()
end)
