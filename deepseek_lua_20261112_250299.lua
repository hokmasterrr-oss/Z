-- MOVEMENT PANEL v35 SLIM | Dropkick Focus
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "MP35"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
local okP = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okP then
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then gui.Parent = pg end
end
if not gui.Parent then return end

local S = { fly=false, speed=false, noclip=false, armed=false }
local selectedPlayer = nil
local flyObjects = {}
local upH = false

local function getHum() local c = lp.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = lp.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function isAlive(p)
    if not p or p.Parent ~= Players then return false end
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and r ~= nil
end
local function findNearest(maxD)
    local r = getRoot(); if not r then return nil end
    local pos = r.Position
    local nearest, best = nil, maxD
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp and pl.Character then
            local tr = pl.Character:FindFirstChild("HumanoidRootPart")
            local th = pl.Character:FindFirstChildOfClass("Humanoid")
            if tr and th and th.Health > 0 then
                local d = (tr.Position - pos).Magnitude
                if d < best then nearest, best = pl, d end
            end
        end
    end
    return nearest
end

local function stopFly()
    for _, o in pairs(flyObjects) do pcall(function() o:Destroy() end) end
    flyObjects = {}
    local h = getHum()
    if h then pcall(function() h.PlatformStand = false end) end
end
local function startFly()
    stopFly()
    local r, h = getRoot(), getHum()
    if not r or not h then return false end
    local att = Instance.new("Attachment"); att.Parent = r
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.Parent = r
    local ao = Instance.new("AlignOrientation")
    ao.Attachment0 = att
    ao.MaxTorque = math.huge
    ao.Responsiveness = 60
    ao.Parent = r
    h.PlatformStand = true
    flyObjects = { att = att, lv = lv, ao = ao }
    return true
end
RunService.RenderStepped:Connect(function(dt)
    if not S.fly then return end
    local lv = flyObjects.lv
    if not (lv and lv.Parent) then return end
    local h = getHum()
    local mv = h and h.MoveDirection or Vector3.zero
    local lm = cam.CFrame:VectorToObjectSpace(mv)
    local dir = cam.CFrame.LookVector * -lm.Z + cam.CFrame.RightVector * lm.X
    dir = dir + Vector3.new(0, upH and 1 or 0, 0)
    if dir.Magnitude > 0.05 then
        pcall(function() lv.VectorVelocity = dir.Unit * 60 end)
    else
        pcall(function() lv.VectorVelocity = Vector3.zero end)
    end
end)

local tracked = {}
local function setNoclip(on)
    local c = lp.Character; if not c then return end
    if on then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide = false end); tracked[p] = true end
        end
    else
        for p in pairs(tracked) do
            if p and p.Parent then pcall(function() p.CanCollide = true end) end
        end
        tracked = {}
    end
end
task.spawn(function()
    while true do
        task.wait(0.5)
        if S.noclip then
            local c = lp.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide = false end); tracked[p] = true end
                end
            end
        end
    end
end)

local function doDropkick()
    if not S.armed then return end
    local c = lp.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not r or not h then return end

    local target = selectedPlayer
    if not isAlive(target) then target = findNearest(500) end
    if not isAlive(target) then return end

    local tC = target.Character
    local tR = tC:FindFirstChild("HumanoidRootPart")
    if not tR then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://133566007754001"
    local track
    local animator = h:FindFirstChildOfClass("Animator")
    if animator then
        local ok, t = pcall(function() return animator:LoadAnimation(anim) end)
        if ok then track = t end
    end
    if track then
        pcall(function() track.Priority = Enum.AnimationPriority.Action end)
        pcall(function() track:Play() end)
        task.delay(2, function() pcall(function() track:Stop() end) end)
    end

    pcall(function() tR:SetNetworkOwner(lp) end)

    local dir = tR.Position - r.Position
    if dir.Magnitude < 0.1 then dir = Vector3.new(1,0,0) else dir = dir.Unit end

    local injected = {}
    for _, part in ipairs(tC:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new(1e7, 1e7, 1e7)
                bv.Parent = part
                table.insert(injected, bv)
            end)
        end
    end

    task.spawn(function()
        local flip = 1
        for i = 1, 30 do
            if not tC or not tC.Parent then break end
            flip = flip * -1
            local vel = Vector3.new(dir.X * 1e6 * flip, 1e6, dir.Z * 1e6 * flip)
            local spin = Vector3.new(1e6 * flip, 1e6 * flip, 1e6 * flip)
            for _, part in ipairs(tC:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.AssemblyLinearVelocity = vel
                        part.AssemblyAngularVelocity = spin
                    end)
                end
            end
            RunService.Heartbeat:Wait()
        end
        task.wait(0.5)
        for _, bv in ipairs(injected) do
            if bv and bv.Parent then pcall(function() bv:Destroy() end) end
        end
    end)
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(260, 320)
main.Position = UDim2.new(0, 20, 0.1, 0)
main.BackgroundColor3 = Color3.fromRGB(29, 43, 83)
main.BorderSizePixel = 0
main.Parent = gui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(126, 37, 83)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "MOVEMENT PANEL v35"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.Font = Enum.Font.Arcade
titleText.TextSize = 14
titleText.Parent = titleBar

local dragStart, dragFrom, isDragging
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = input.Position
        dragFrom = main.Position
        isDragging = true
    end
end)
UIS.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(dragFrom.X.Scale, dragFrom.X.Offset + d.X, dragFrom.Y.Scale, dragFrom.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

local FBtn
local function makeToggle(y, text, stateKey, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 32)
    btn.Position = UDim2.fromOffset(10, y)
    btn.BackgroundColor3 = Color3.fromRGB(41, 58, 108)
    btn.Text = text .. " [OFF]"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Arcade
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = main
    btn.MouseButton1Click:Connect(function()
        S[stateKey] = not S[stateKey]
        btn.Text = text .. (S[stateKey] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = S[stateKey] and Color3.fromRGB(0, 180, 50) or Color3.fromRGB(41, 58, 108)
        if onToggle then onToggle(S[stateKey]) end
    end)
    return btn
end

makeToggle(38, "Fly", "fly", function(on)
    if on then startFly() else stopFly() end
end)
makeToggle(74, "Speed", "speed", function(on)
    local h = getHum()
    if h then
        if on then h.WalkSpeed = 50 else h.WalkSpeed = 16 end
    end
end)
makeToggle(110, "Noclip", "noclip", function(on)
    setNoclip(on)
end)
makeToggle(146, "Dropkick Armed (F)", "armed", function(on)
    if FBtn then FBtn.Visible = on end
end)

FBtn = Instance.new("TextButton")
FBtn.Size = UDim2.fromOffset(56, 56)
FBtn.Position = UDim2.new(0, 20, 0.5, -28)
FBtn.BackgroundColor3 = Color3.fromRGB(255, 163, 0)
FBtn.Text = "F"
FBtn.TextColor3 = Color3.new(0, 0, 0)
FBtn.Font = Enum.Font.Arcade
FBtn.TextSize = 32
FBtn.Visible = false
FBtn.BorderSizePixel = 0
FBtn.Parent = gui
local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(1, 0)
fCorner.Parent = FBtn

FBtn.MouseButton1Click:Connect(function()
    doDropkick()
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        doDropkick()
    elseif input.KeyCode == Enum.KeyCode.E then
        upH = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then upH = false end
end)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 0, 130)
listFrame.Position = UDim2.fromOffset(10, 182)
listFrame.BackgroundColor3 = Color3.fromRGB(18, 25, 56)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.CanvasSize = UDim2.new()
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
listFrame.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.Parent = listFrame

local function refreshList()
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    if selectedPlayer and not isAlive(selectedPlayer) then selectedPlayer = nil end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp and isAlive(pl) then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 22)
            btn.BackgroundColor3 = (pl == selectedPlayer) and Color3.fromRGB(126, 37, 83) or Color3.fromRGB(41, 58, 108)
            btn.Text = pl.Name
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Font = Enum.Font.Arcade
            btn.TextSize = 12
            btn.BorderSizePixel = 0
            btn.Parent = listFrame
            btn.MouseButton1Click:Connect(function()
                selectedPlayer = pl
                refreshList()
            end)
        end
    end
end
pcall(refreshList)

task.spawn(function()
    while true do
        task.wait(3)
        pcall(refreshList)
    end
end)