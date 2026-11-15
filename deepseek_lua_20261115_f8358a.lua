--[[
    Drag Drive Simulator - Auto Farm v3 (FINAL)
    Siklus: RIDING -> DESCEND -> STOP -> DISMOUNT -> CLAIM -> REMOUNT -> loop
    Ride duration default 20 menit, turun pelan, klaim otomatis.
    Cara pakai: duduk di motor, execute, klik FARM ON.
    Akun alt only. Resiko ban tanggung sendiri.
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser      = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

--==================== CONFIG ====================
local Config = {
    Enabled      = false,
    RideDuration = 1200,    -- 20 menit
    ClaimWait    = 3,
    Altitude     = 100,
    Speed        = 80,
    DescendSpeed = 2.5,
    StopWait     = 3,
}

local State = {
    Seat       = nil,
    Chassis    = nil,
    Phase      = "IDLE",
    Timer      = 0,
    CurrentAlt = 0,
    LastPos    = nil,
    StuckTime  = 0,
}

--==================== HELPERS ====================
local function getHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getSeat()
    local hum = getHumanoid()
    if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
        return hum.SeatPart
    end
    return nil
end

local function findNearbySeat(radius)
    radius = radius or 150
    local char = LP.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local bestSeat, bestDist = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("VehicleSeat") then
            local d = (obj.Position - hrp.Position).Magnitude
            if d < bestDist and d < radius then
                bestSeat, bestDist = obj, d
            end
        end
    end
    return bestSeat
end

local function getChassis(seat)
    if not seat then return nil end
    local model = seat
    while model and not model:IsA("Model") do model = model.Parent end
    if not model then return nil end
    if model.PrimaryPart then return model.PrimaryPart end
    local best, bestSize = nil, 0
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= seat then
            local s = d.Size.X * d.Size.Y * d.Size.Z
            if s > bestSize then best, bestSize = d, s end
        end
    end
    return best
end

local function flatten(v)
    local f = Vector3.new(v.X, 0, v.Z)
    if f.Magnitude < 0.001 then return Vector3.new(1,0,0) end
    return f.Unit
end

--==================== MOVERS ====================
local bp, bv, bg

local function cleanupMovers()
    if bp then bp:Destroy() bp = nil end
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end
end

local function ensureMovers(chassis)
    if not bp or bp.Parent ~= chassis then
        if bp then bp:Destroy() end
        bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bp.P = 10000; bp.D = 800
        bp.Parent = chassis
    end
    if not bv or bv.Parent ~= chassis then
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e6, 0, 1e6)
        bv.P = 10000
        bv.Parent = chassis
    end
    if not bg or bg.Parent ~= chassis then
        if bg then bg:Destroy() end
        bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.P = 8000; bg.D = 500
        bg.Parent = chassis
    end
end

--==================== STATE MACHINE ====================
local Direction = Vector3.new(1, 0, 0)

local function startRide()
    local seat = getSeat()
    if not seat then
        local nearby = findNearbySeat()
        if nearby then
            local hum = getHumanoid()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                hrp.CFrame = nearby.CFrame * CFrame.new(0, 3, 0)
                task.wait(0.2)
                pcall(function() nearby:Sit(hum) end)
                task.wait(0.3)
                seat = getSeat()
            end
        end
    end
    if not seat then
        State.Phase = "IDLE"
        return
    end
    State.Seat = seat
    State.Chassis = getChassis(seat)
    if State.Chassis then
        State.CurrentAlt = State.Chassis.Position.Y
        Direction = flatten(State.Chassis.CFrame.LookVector)
    end
    State.Timer = 0
    State.LastPos = nil
    State.StuckTime = 0
    State.Phase = "RIDING"
    print("[Farm] RIDING - ngumpulin " .. math.floor(Config.RideDuration) .. " detik")
end

local function doRiding(dt)
    local seat = getSeat()
    if not seat then State.Phase = "IDLE" return end
    local chassis = State.Chassis or getChassis(seat)
    if not chassis then cleanupMovers() return end
    State.Chassis = chassis
    ensureMovers(chassis)

    if State.CurrentAlt < Config.Altitude then
        State.CurrentAlt = math.min(Config.Altitude, State.CurrentAlt + 8)
    end

    local pos = chassis.Position
    bp.Position = Vector3.new(pos.X, State.CurrentAlt, pos.Z)

    local angle = math.rad(15 * dt)
    Direction = flatten(Vector3.new(
        Direction.X * math.cos(angle) - Direction.Z * math.sin(angle),
        0,
        Direction.X * math.sin(angle) + Direction.Z * math.cos(angle)
    ))

    bv.Velocity = Direction * Config.Speed
    bg.CFrame = CFrame.lookAt(Vector3.new(), Direction)

    -- anti-stuck v2
    if State.LastPos then
        if (pos - State.LastPos).Magnitude < 5 then
            State.StuckTime = State.StuckTime + dt
            if State.StuckTime > 3 then
                Direction = flatten(-Direction + Vector3.new(math.random(-3,3), 0, math.random(-3,3)))
                State.CurrentAlt = math.min(300, State.CurrentAlt + 25)
                State.StuckTime = 0
                print("[Farm] Anti-stuck: ubah arah, alt=" .. math.floor(State.CurrentAlt))
            end
        else
            State.StuckTime = 0
        end
    end
    State.LastPos = pos

    State.Timer = State.Timer + dt
    if State.Timer >= Config.RideDuration then
        State.Phase = "DESCEND"
        State.Timer = 0
        print("[Farm] DESCEND - turun pelan")
    end
end

local function doDescend(dt)
    local seat = getSeat()
    if not seat or not State.Chassis then State.Phase = "IDLE" return end
    local chassis = State.Chassis

    State.CurrentAlt = math.max(15, State.CurrentAlt - Config.DescendSpeed)
    local pos = chassis.Position
    bp.Position = Vector3.new(pos.X, State.CurrentAlt, pos.Z)
    bv.Velocity = Vector3.new(0, 0, 0)

    if State.CurrentAlt <= 15 then
        State.Phase = "STOP"
        State.Timer = 0
        print("[Farm] STOP - motor berhenti")
    end
end

local function doStop(dt)
    if State.Chassis then
        local pos = State.Chassis.Position
        if bp then bp.Position = Vector3.new(pos.X, 15, pos.Z) end
        if bv then bv.Velocity = Vector3.new(0, 0, 0) end
    end
    State.Timer = State.Timer + dt
    if State.Timer >= Config.StopWait then
        State.Phase = "DISMOUNT"
        State.Timer = 0
    end
end

local function doDismount()
    cleanupMovers()
    local hum = getHumanoid()
    if not hum then State.Phase = "IDLE" return end

    -- strategi 1: Jump = true
    pcall(function() hum.Jump = true end)
    task.wait(0.05)

    -- strategi 2: VirtualUser click
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(0, 0))
        VirtualUser:Button1Up(Vector2.new(0, 0))
    end)

    -- strategi 3: keypress Space
    pcall(function()
        if keypress and keyrelease then
            keypress(Enum.KeyCode.Space)
            task.wait(0.08)
            keyrelease(Enum.KeyCode.Space)
        end
    end)

    -- strategi 4: Sit = false (fallback)
    task.wait(0.05)
    pcall(function() hum.Sit = false end)

    State.Phase = "CLAIM"
    State.Timer = 0
    print("[Farm] DISMOUNT via Jump. CLAIM nunggu " .. Config.ClaimWait .. " detik")
end

local function doClaim(dt)
    State.Timer = State.Timer + dt

    -- safety: jatuh ke void, tarik balik
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Position.Y < 0 and State.Seat and State.Seat:IsDescendantOf(workspace) then
        hrp.CFrame = State.Seat.CFrame * CFrame.new(0, 5, 0)
        print("[Farm] Karakter jatuh, ditarik balik ke motor")
    end

    if State.Timer >= Config.ClaimWait then
        State.Phase = "REMOUNT"
        State.Timer = 0
    end
end

local function doRemount(dt)
    State.Timer = State.Timer + dt
    local hum = getHumanoid()
    if not hum then State.Phase = "IDLE" return end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hum.SeatPart and hrp then
        local seat = State.Seat
        if not seat or not seat:IsDescendantOf(workspace) then
            seat = findNearbySeat(150)
        end
        if seat then
            hrp.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.1)
            pcall(function() seat:Sit(hum) end)
            task.wait(0.15)
            if not hum.SeatPart then
                pcall(function() hum.Sit = true end)
            end
        end
    end

    if getSeat() then
        State.Phase = "RIDING"
        State.Timer = 0
        State.CurrentAlt = Config.Altitude
        State.LastPos = nil
        State.StuckTime = 0
        print("[Farm] REMOUNT berhasil - balik RIDING")
    elseif State.Timer > 8 then
        print("[Farm] Remount gagal, ulang dari IDLE")
        State.Phase = "IDLE"
        State.Timer = 0
    end
end

--==================== MAIN LOOP ====================
task.spawn(function()
    local lastTick = tick()
    while task.wait(0.1) do
        local now = tick()
        local dt = now - lastTick
        lastTick = now

        if not Config.Enabled then
            cleanupMovers()
            State.Phase = "IDLE"
            continue
        end

        if State.Phase == "IDLE" then
            startRide()
        elseif State.Phase == "RIDING" then
            pcall(doRiding, dt)
        elseif State.Phase == "DESCEND" then
            pcall(doDescend, dt)
        elseif State.Phase == "STOP" then
            pcall(doStop, dt)
        elseif State.Phase == "DISMOUNT" then
            pcall(doDismount)
        elseif State.Phase == "CLAIM" then
            doClaim(dt)
        elseif State.Phase == "REMOUNT" then
            pcall(doRemount, dt)
        end
    end
end)

--==================== CASH LOG ====================
task.spawn(function()
    while task.wait(2) do
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            local parts = {}
            for _, v in ipairs(ls:GetChildren()) do
                if v:IsA("ValueBase") then
                    table.insert(parts, v.Name .. "=" .. tostring(v.Value))
                end
            end
            if #parts > 0 then
                print("[Farm] " .. table.concat(parts, " | ") .. " | Phase: " .. State.Phase)
            end
        end
    end
end)

--==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DDSAutoFarmFinal"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 430)
frame.Position = UDim2.new(0, 20, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "DDS Auto Farm v3 FINAL"
title.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 260, 0, 44)
btn.Position = UDim2.new(0, 10, 0, 40)
btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.Text = "FARM: OFF"
btn.Parent = frame

btn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    btn.Text = "FARM: " .. (Config.Enabled and "ON" or "OFF")
    btn.BackgroundColor3 = Config.Enabled
        and Color3.fromRGB(40, 200, 80)
        or Color3.fromRGB(200, 40, 40)
    if not Config.Enabled then
        cleanupMovers()
        State.Phase = "IDLE"
    end
end)

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(0, 260, 0, 20)
phaseLabel.Position = UDim2.new(0, 10, 0, 90)
phaseLabel.BackgroundTransparency = 1
phaseLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.TextSize = 13
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Text = "Phase: IDLE"
phaseLabel.Parent = frame

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0, 260, 0, 20)
timerLabel.Position = UDim2.new(0, 10, 0, 112)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 13
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = "Sisa ride: -"
timerLabel.Parent = frame

task.spawn(function()
    while task.wait(0.3) do
        phaseLabel.Text = "Phase: " .. State.Phase
        if State.Phase == "RIDING" then
            local sisa = math.max(0, Config.RideDuration - State.Timer)
            local m = math.floor(sisa / 60)
            local s = math.floor(sisa % 60)
            timerLabel.Text = string.format("Sisa ride: %d:%02d", m, s)
        elseif State.Phase == "DESCEND" then
            timerLabel.Text = string.format("Turun: sisa %.0f studs", State.CurrentAlt - 15)
        elseif State.Phase == "STOP" then
            timerLabel.Text = string.format("Stop: %.1f / %.1f s", State.Timer, Config.StopWait)
        elseif State.Phase == "CLAIM" then
            timerLabel.Text = string.format("Claim: %.1f / %.1f s", State.Timer, Config.ClaimWait)
        else
            timerLabel.Text = ""
        end
    end
end)

local function makeSlider(label, yPos, minV, maxV, defaultV, onChange)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 260, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200,200,200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label .. ": " .. string.format("%.1f", defaultV)
    lbl.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(0, 260, 0, 22)
    bar.Position = UDim2.new(0, 10, 0, yPos + 18)
    bar.BackgroundColor3 = Color3.fromRGB(55,55,75)
    bar.Text = ""
    bar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultV-minV)/(maxV-minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80,160,255)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local dragging = false
    local function updatePos(mx)
        local absX = bar.AbsolutePosition.X
        local absW = bar.AbsoluteSize.X
        local t = math.clamp((mx - absX) / absW, 0, 1)
        local v = minV + (maxV - minV) * t
        fill.Size = UDim2.new(t, 0, 1, 0)
        lbl.Text = label .. ": " .. string.format("%.1f", v)
        onChange(v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; updatePos(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            updatePos(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

makeSlider("Ride duration (menit)", 145, 1, 60, Config.RideDuration / 60,
    function(v) Config.RideDuration = v * 60 end)
makeSlider("Descend speed", 205, 1, 10, Config.DescendSpeed,
    function(v) Config.DescendSpeed = v end)
makeSlider("Stop wait (s)", 265, 1, 10, Config.StopWait,
    function(v) Config.StopWait = v end)
makeSlider("Speed", 325, 30, 200, Config.Speed,
    function(v) Config.Speed = v end)

print("[Farm v3] Loaded. Duduk di motor, klik FARM ON.")
print("[Farm v3] Ride default: " .. math.floor(Config.RideDuration/60) .. " menit")