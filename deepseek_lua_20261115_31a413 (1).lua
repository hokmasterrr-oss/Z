--[[
    DDS Auto Farm v4 - Throttle Flight (Anti-Kick)
    Cara pakai: Duduk di motor, execute, klik FLY ON.
    Motor akan terbang dan maju menggunakan mesinnya sendiri.
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local Config = {
    Enabled    = false,
    Altitude   = 100, -- Ketinggian terbang
    Speed      = 80,  -- Kecepatan dorong horizontal (tidak dipakai di mode throttle)
    Throttle   = 1,   -- 1 = Gas penuh
    Steer      = 0,   -- 0 = Lurus
}

local State = {
    Seat    = nil,
    Chassis = nil,
    CurrentAlt = 0,
}

--========== HELPERS ==========
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

--========== MOVERS ==========
local bp -- Hanya BodyPosition yang kita butuhkan

local function cleanup()
    if bp then bp:Destroy() bp = nil end
end

local function ensureMovers(chassis)
    if not bp or bp.Parent ~= chassis then
        if bp then bp:Destroy() end
        bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bp.P = 10000; bp.D = 800
        bp.Parent = chassis
    end
end

--========== INTI FLY ==========
local function doFly()
    local seat = getSeat()
    if not seat then cleanup() return end
    local chassis = getChassis(seat)
    if not chassis then cleanup() return end
    ensureMovers(chassis)

    -- Naik pelan-pelan ke ketinggian target
    local pos = chassis.Position
    if State.CurrentAlt < Config.Altitude then
        State.CurrentAlt = math.min(Config.Altitude, State.CurrentAlt + 5)
    elseif State.CurrentAlt > Config.Altitude then
        State.CurrentAlt = math.max(Config.Altitude, State.CurrentAlt - 5)
    end
    bp.Position = Vector3.new(pos.X, State.CurrentAlt, pos.Z)

    -- INI KUNCINYA: Paksa motor untuk "ngegas" menggunakan sistemnya sendiri
    pcall(function()
        seat.ThrottleFloat = Config.Throttle
        seat.SteerFloat = Config.Steer
    end)
end

--========== LOOP ==========
task.spawn(function()
    while task.wait(0.1) do
        if Config.Enabled then
            local ok = pcall(doFly)
            if not ok then cleanup() end
        else
            cleanup()
        end
    end
end)

--========== GUI SEDERHANA ==========
local gui = Instance.new("ScreenGui")
gui.Name = "DDS_AutoDrive_v4"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 200, 0, 50)
btn.Position = UDim2.new(0, 20, 0, 100)
btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.Text = "FLY: OFF"
btn.Parent = gui

btn.MouseButton1Click:Connect(function()
    if not Config.Enabled then
        local seat = getSeat()
        if not seat then
            btn.Text = "NAIK MOTOR DULU!"
            task.delay(2, function() btn.Text = "FLY: OFF" end)
            return
        end
        local chassis = getChassis(seat)
        if chassis then
            State.CurrentAlt = chassis.Position.Y
        end
    end
    Config.Enabled = not Config.Enabled
    btn.Text = "FLY: " .. (Config.Enabled and "ON" or "OFF")
    btn.BackgroundColor3 = Config.Enabled
        and Color3.fromRGB(40, 200, 80)
        or Color3.fromRGB(200, 40, 40)
    if not Config.Enabled then
        cleanup()
    end
end)

-- Indikator kecepatan
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 200, 0, 20)
speedLabel.Position = UDim2.new(0, 20, 0, 160)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 14
speedLabel.Text = "KM/H: -"
speedLabel.Parent = gui

-- Update indikator kecepatan
task.spawn(function()
    while task.wait(0.5) do
        local seat = getSeat()
        if seat then
            local chassis = getChassis(seat)
            if chassis then
                local speed = chassis.AssemblyLinearVelocity.Magnitude * 3.6
                speedLabel.Text = string.format("KM/H: %.0f", speed)
            end
        else
            speedLabel.Text = "KM/H: -"
        end
    end
end)

print("[v4] Loaded. Duduk di motor, klik FLY ON. Mode: Throttle Flight.")