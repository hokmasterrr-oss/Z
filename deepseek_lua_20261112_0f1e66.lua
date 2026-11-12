-- v36 DROPKICK MULTI-METHOD FLING
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "MP36"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then gui.Parent = pg else return end
end

local S = { fly = false, noclip = false, armed = false, extreme = false }
local selectedPlayer = nil
local flyObjects = {}
local upH = false

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isAlive(p)
    if not p or p.Parent ~= Players then return false end
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and r ~= nil
end
local function findNearest(maxD)
    local r = getRoot()
    if not r then return nil end
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
    for _, o in pairs(flyObjects) do
        pcall(function() o:Destroy() end)
    end
    flyObjects = {}
    local h = getHum()
    if h then pcall(function() h.PlatformStand = false end) end
end
local function startFly()
    stopFly()
    local r, h = getRoot(), getHum()
    if not r or not h then return false end
    local att = Instance.new("Attachment")
    att.Parent = r
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.Parent = r
    h.PlatformStand = true
    flyObjects = { att = att, lv = lv }
    return true
end
RunService.RenderStepped:Connect(function()
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
    local c = lp.Character
    if not c then return end
    if on then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                pcall(function() p.CanCollide = false end)
                tracked[p] = true
            end
        end
    else
        for p in pairs(tracked) do
            if p and p.Parent then
                pcall(function() p.CanCollide = true end)
            end
        end
        tracked = {}
    end
end
task.spawn(function()
    while true do
        task.wait(0.3)
        if S.noclip then
            local c = lp.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        pcall(function() p.CanCollide = false end)
                        tracked[p] = true
                    end
                end
            end
        end
    end
end)

-- ============ MULTI-METHOD FLING ============
local function doFling(target)
    if not target or not target.Character then return false end
    local tChar = target.Character
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 then return false end

    local myRoot = getRoot()
    local dir = tRoot.Position - (myRoot and myRoot.Position or tRoot.Position + Vector3.new(0, 0, -10))
    if dir.Magnitude < 1 then dir = Vector3.new(0, 0, -1) else dir = dir.Unit end

    -- ========== METHOD 1: WELD FLING (primary) ==========
    -- Bikin part invisible, weld ke target root. Weld = physics constraint,
    -- velocity di weld part = tarik target. Bypass velocity clamp server.
    local weldParts = {}
    for i = 1, 3 do
        local wp = Instance.new("Part")
        wp.Size = Vector3.new(2, 2, 2)
        wp.CanCollide = false
        wp.Anchored = false
        wp.Transparency = 1
        wp.Massless = true
        wp.CFrame = tRoot.CFrame
        wp.Parent = workspace
        local wc = Instance.new("WeldConstraint")
        wc.Part0 = tRoot
        wc.Part1 = wp
        wc.Parent = wp
        table.insert(weldParts, wp)
    end

    -- ========== METHOD 2: PART TOUCH SPAM (secondary) ==========
    -- Spawn part di sekitar target, kasih velocity ke arah target.
    -- Collision = server-side force, gak bisa di-clamp.
    task.spawn(function()
        for i = 1, 20 do
            if not tChar or not tChar.Parent then break end
            local curRoot = tChar:FindFirstChild("HumanoidRootPart")
            if not curRoot then break end
            local part = Instance.new("Part")
            part.Size = Vector3.new(15, 15, 15)
            part.CanCollide = true
            part.Anchored = false
            part.Transparency = 1
            part.Massless = false
            part.CFrame = CFrame.new(curRoot.Position - dir * 15 + Vector3.new(
                math.random(-8, 8), math.random(0, 10), math.random(-8, 8)
            ))
            part.Parent = workspace
            part.AssemblyLinearVelocity = dir * 8000 + Vector3.new(0, 3000, 0)
            task.delay(1.5, function()
                if part and part.Parent then pcall(function() part:Destroy() end) end
            end)
            task.wait(0.06)
        end
    end)

    -- ========== METHOD 3: VELOCITY SPAM (tertiary) ==========
    task.spawn(function()
        for i = 1, 60 do
            if not tChar or not tChar.Parent then break end
            local flip = (i % 2 == 0) and 1 or -1
            local vel = Vector3.new(dir.X * 8000 * flip, 5000, dir.Z * 8000 * flip)
            local spin = Vector3.new(5000 * flip, 5000 * flip, 5000 * flip)
            for _, part in ipairs(tChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.AssemblyLinearVelocity = vel
                        part.AssemblyAngularVelocity = spin
                    end)
                end
            end
            for _, wp in ipairs(weldParts) do
                if wp and wp.Parent then
                    pcall(function()
                        wp.AssemblyLinearVelocity = vel * 5
                        wp.AssemblyAngularVelocity = spin * 5
                    end)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)

    -- ========== METHOD 4: EXTREME (opsional) ==========
    -- Anchored fling = freeze target + teleport jauh. Cuma visual di client,
    -- tapi server kadang replicate juga.
    if S.extreme then
        local toFreeze = {}
        for _, part in ipairs(tChar:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                pcall(function()
                    part.Anchored = true
                    toFreeze[part] = true
                end)
            end
        end
        task.defer(function()
            for _, part in ipairs(tChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.CFrame = part.CFrame + Vector3.new(
                            math.random(-300, 300),
                            math.random(800, 1500),
                            math.random(-300, 300)
                        ) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
                    end)
                end
            end
        end)
        task.delay(3, function()
            for part in pairs(toFreeze) do
                if part and part.Parent then
                    pcall(function() part.Anchored = false end)
                end
            end
        end)
    end

    -- ========== METHOD 5: VISUAL CFrame FLING (pasti keliatan di layar lu) ==========
    -- Set CFrame visual terus-terusan biar target keliatan mental di layar client
    task.spawn(function()
        local endTime = tick() + 3
        while tick() < endTime do
            if not tChar or not tChar.Parent then break end
            for _, part in ipairs(tChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.CFrame = part.CFrame * CFrame.new(0, 30, 0) * CFrame.Angles(0.3, 0.5, 0.2)
                    end)
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)

    -- ========== CLEANUP ==========
    task.delay(2, function()
        for _, wp in ipairs(weldParts) do
            if wp and wp.Parent then pcall(function() wp:Destroy() end) end
        end
    end)

    -- ========== SELF PROTECTION ==========
    -- Kalau ternyata self kena recoil, reset velocity biar gak mental sendiri
    task.spawn(function()
        task.wait(0.15)
        local r = getRoot()
        if r and r.Parent then
            local v = r.AssemblyLinearVelocity
            if v.Magnitude > 200 then
                pcall(function()
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end)

    return true
end

-- ============ DROPKICK (animation + fling) ============
local function doDropkick()
    if not S.armed then return end
    local c = lp.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not r or not h then return end

    local target = selectedPlayer
    if not isAlive(target) then target = findNearest(500) end
    if not isAlive(target) then
        return
    end

    -- Animasi dropkick di SELF (visual only)
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://133566007754001"
    local track
    local animator = h:FindFirstChildOfClass("Animator")
    if animator then
        local okA, t = pcall(function() return animator:LoadAnimation(anim) end)
        if okA then track = t end
    end
    if not track then
        local okB, t = pcall(function() return h:LoadAnimation(anim) end)
        if okB then track = t end
    end
    if track then
        pcall(function()
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = false
            track:Play()
        end)
        task.delay(2, function()
            pcall(function() track:Stop() end)
        end)
    end

    -- Fling target (delay dikit biar animasi keliatan dulu)
    task.delay(0.15, function()
        doFling(target)
    end)
end

-- ============ UI ============
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(280, 380)
main.Position = UDim2.new(0, 20, 0.1, 0)
main.BackgroundColor3 = Color3.fromRGB(29, 43, 83)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = main

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(126, 37, 83)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 6)
tc.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "MOVEMENT PANEL v36"
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

local function makeToggle(y, text, stateKey, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.fromOffset(10, y)
    btn.BackgroundColor3 = Color3.fromRGB(41, 58, 108)
    btn.Text = text .. " [OFF]"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Arcade
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        S[stateKey] = not S[stateKey]
        btn.Text = text .. (S[stateKey] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = S[stateKey] and Color3.fromRGB(0, 180, 50) or Color3.fromRGB(41, 58, 108)
        if onToggle then onToggle(S[stateKey]) end
    end)
    return btn
end

makeToggle(36, "Fly", "fly", function(on)
    if on then startFly() else stopFly() end
end)
makeToggle(70, "Noclip", "noclip", function(on) setNoclip(on) end)
makeToggle(104, "Dropkick Armed (F)", "armed", function(on)
    if FBtn then FBtn.Visible = on end
end)
makeToggle(138, "Extreme Mode (Anchored)", "extreme", nil)

local infoLbl = Instance.new("TextLabel")
infoLbl.Size = UDim2.new(1, -20, 0, 24)
infoLbl.Position = UDim2.fromOffset(10, 172)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "Target: none | Select below"
infoLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
infoLbl.Font = Enum.Font.Arcade
infoLbl.TextSize = 11
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.Parent = main

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 0, 160)
listFrame.Position = UDim2.fromOffset(10, 200)
listFrame.BackgroundColor3 = Color3.fromRGB(18, 25, 56)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.CanvasSize = UDim2.new()
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
listFrame.Parent = main
local lc = Instance.new("UICorner")
lc.CornerRadius = UDim.new(0, 4)
lc.Parent = listFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.Parent = listFrame

local FBtn = Instance.new("TextButton")
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
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(1, 0)
fc.Parent = FBtn

local fDrag, fFrom
FBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fDrag = input.Position
        fFrom = FBtn.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if fDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - fDrag
        if d.Magnitude > 5 then
            FBtn.Position = UDim2.new(fFrom.X.Scale, fFrom.X.Offset + d.X, fFrom.Y.Scale, fFrom.Y.Offset + d.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fDrag = nil
    end
end)

FBtn.MouseButton1Click:Connect(function()
    doDropkick()
end)

local function refreshList()
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    if selectedPlayer and not isAlive(selectedPlayer) then
        selectedPlayer = nil
    end
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
                infoLbl.Text = "Target: " .. pl.Name
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