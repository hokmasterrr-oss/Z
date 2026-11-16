--[[ MOVEMENT PANEL v34 FANCY | Slim + All Features ]]
local CFG = { intro = true }
local CREDIT = "kemalgans12"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "MP34"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okp or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local S = {
	fly=false, flySpeed=60, speed=false, walkSpeed=50, inf=false,
	anti=false, gravFactor=0.15, walkAir=false, walkWater=false,
	noFling=false, noFall=false, fallCap=30, noclip=false,
	godMode=false, antiRagdoll=false, esp=false, brightShader=false,
	fullbright=false, noFog=false, fov=70, crosshair=false,
	hideNames=false, lowGraphics=false,
	camRoll=0, camHeight=0, camDist=0, camShake=false, camDrift=false, camZoomPulse=false, camFP=false,
	autoCam=nil,
	cinemaHD=false, cinemaDoF=false, cinemaBars=false, cinemaClean=false, cinemaBloom=false,
	stick=false, tpLoop=false, autorespawn=false, antiAFK=false
}

local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local stickTarget, stickManual, stickOrigWS, stickOrigJP
local selectedPlayer, targetLabel, playerListFrame, currentTab
local hookedHum, tpLoopRow, espObjs = nil, nil, {}
local fullbrightSaved, fogSaved = nil, nil
local noclipTracked = {}
local hideNameSaved = {}
local lowGFXSaved = {}
local waypoints = {nil, nil, nil}
local ANTI_MAX_VEL, ANTI_VIOLENT = 40, 80
local STICK_RANGE, STICK_OFFSET, STICK_LERP = 60, CFrame.new(0, 0.4, 1.2), 20
local WALK_AIR_LV, WALK_AIR_ATT = "MP_WALK_AIR_LV", "MP_WALK_AIR_ATT"
local FLY_LV, FLY_AO, FLY_ATT = "MP_FLY_LV", "MP_FLY_AO", "MP_FLY_ATT"
local antiAFKThread = nil
local autoCamStart = tick()
local autoCamRows = {}
local CAM_BIND = "MP34_CAM"
local camOrigMinZoom, camOrigMaxZoom, camOrigMode = nil, nil, nil

local function getHum() local c=lp.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c=lp.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function isAlive(p)
	if not p or p.Parent ~= Players then return false end
	local c=p.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
	local r=c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Health>0 and r~=nil
end
local function findNearest(md)
	local r=getRoot(); if not r then return nil end
	local pos,near,best=r.Position,nil,md
	for _,p in pairs(Players:GetPlayers()) do
		if p~=lp and p.Character then
			local tr=p.Character:FindFirstChild("HumanoidRootPart")
			local th=p.Character:FindFirstChildOfClass("Humanoid")
			if tr and th and th.Health>0 then
				local d=(tr.Position-pos).Magnitude
				if d<best then near,best=p,d end
			end
		end
	end
	return near
end
local function fmtDist(d) if d>=1000 then return string.format("%.1fk",d/1000) end return math.floor(d).."m" end

-- MOVEMENT
local function stopFly()
	for _,o in pairs(flyObjs) do if o and o.Parent then o:Destroy() end end
	flyObjs={}
	local h=getHum(); if h then h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end
end
local function startFly()
	stopFly()
	local r,h=getRoot(),getHum(); if not r or not h then return false end
	local att=Instance.new("Attachment"); att.Name=FLY_ATT; att.Parent=r
	local lv=Instance.new("LinearVelocity"); lv.Name=FLY_LV; lv.Attachment0=att
	lv.MaxForce=math.huge; lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.VectorVelocity=Vector3.zero; lv.Parent=r
	local ao=Instance.new("AlignOrientation"); ao.Name=FLY_AO
	ao.Mode=Enum.OrientationAlignmentMode.OneAttachment; ao.Attachment0=att
	ao.MaxTorque=math.huge; ao.Responsiveness=60; ao.CFrame=r.CFrame; ao.Parent=r
	h.PlatformStand=true; flyObjs={att=att,lv=lv,ao=ao}; return true
end
RunService.RenderStepped:Connect(function(dt)
	if not S.fly then return end
	local lv,ao=flyObjs.lv,flyObjs.ao
	if not (lv and lv.Parent and ao and ao.Parent) then return end
	local h=getHum(); local mv=h and h.MoveDirection or Vector3.zero
	local lm=cam.CFrame:VectorToObjectSpace(mv)
	local dir=cam.CFrame.LookVector*-lm.Z+cam.CFrame.RightVector*lm.X
	dir=dir+Vector3.new(0,(upHeld and 1 or 0)-(downHeld and 1 or 0),0)
	if dir.Magnitude>0.05 then lv.VectorVelocity=dir.Unit*S.flySpeed else lv.VectorVelocity=Vector3.zero end
	local look=cam.CFrame.LookVector; local flat=Vector3.new(look.X,0,look.Z)
	if flat.Magnitude>0.05 then
		local tgt,cur=flat.Unit,ao.CFrame.LookVector
		if cur:Dot(tgt)>-0.5 then ao.CFrame=CFrame.lookAt(Vector3.zero,cur:Lerp(tgt,math.clamp(dt*8,0,1)).Unit)
		else ao.CFrame=CFrame.lookAt(Vector3.zero,tgt) end
	end
end)

local function stopWalkAir()
	local r=getRoot(); if not r then return end
	local lv=r:FindFirstChild(WALK_AIR_LV); if lv then lv:Destroy() end
	local att=r:FindFirstChild(WALK_AIR_ATT); if att then att:Destroy() end
end
local function walkAirTick()
	if not S.walkAir then stopWalkAir(); return end
	local r,h=getRoot(),getHum(); if not r or not h then return end
	if S.fly or S.stick or S.tpLoop then stopWalkAir(); return end
	local st=h:GetState()
	local air=(st==Enum.HumanoidStateType.Freefall or st==Enum.HumanoidStateType.FallingDown)
	if not air and (st==Enum.HumanoidStateType.Running or st==Enum.HumanoidStateType.Landed) then
		air=(h.FloorMaterial==Enum.Material.Air)
	end
	if not air then stopWalkAir(); return end
	local lv=r:FindFirstChild(WALK_AIR_LV)
	if not lv then
		local att=r:FindFirstChild(WALK_AIR_ATT)
		if not att then att=Instance.new("Attachment"); att.Name=WALK_AIR_ATT; att.Parent=r end
		lv=Instance.new("LinearVelocity"); lv.Name=WALK_AIR_LV; lv.Attachment0=att
		lv.MaxForce=math.huge; lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.VectorVelocity=Vector3.zero; lv.Parent=r
	end
	local mv=h.MoveDirection or Vector3.zero
	local sp=h.WalkSpeed; if sp<=0 then sp=16 end
	local cur=r.AssemblyLinearVelocity
	lv.VectorVelocity=Vector3.new(cur.X+(mv.X*sp-cur.X)*0.35,0,cur.Z+(mv.Z*sp-cur.Z)*0.35)
	if st==Enum.HumanoidStateType.Freefall or st==Enum.HumanoidStateType.FallingDown then h:ChangeState(Enum.HumanoidStateType.Running) end
end
local function walkWaterTick()
	if not S.walkWater or S.fly or S.stick or S.tpLoop then return end
	local r,h=getRoot(),getHum(); if not r or not h then return end
	if h:GetState()==Enum.HumanoidStateType.Swimming then
		local v=r.AssemblyLinearVelocity
		if v.Y<2 then r.AssemblyLinearVelocity=Vector3.new(v.X,2,v.Z) end
		h:ChangeState(Enum.HumanoidStateType.Running)
	end
end
local function setNoclip(on)
	local c=lp.Character; if not c then return end
	if on then
		for _,p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end); noclipTracked[p]=true end
		end
	else
		for p in pairs(noclipTracked) do if p and p.Parent then pcall(function() p.CanCollide=true end) end end
		noclipTracked={}
	end
end
local function noclipTick()
	if not S.noclip then return end
	local c=lp.Character; if not c then return end
	for _,p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end); noclipTracked[p]=true end
	end
	local r=getRoot()
	if r and not S.fly and not S.stick and not S.walkAir then
		local v=r.AssemblyLinearVelocity
		if v.Y<0 then r.AssemblyLinearVelocity=Vector3.new(v.X,0,v.Z) end
	end
end
local function applyNoFall(h,en) if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,not en) end) end end
local function hookHum(h)
	if not h or h==hookedHum then return end
	hookedHum=h
	h.StateChanged:Connect(function(_,ns)
		if not S.noFall then return end
		if ns==Enum.HumanoidStateType.Landed or ns==Enum.HumanoidStateType.FallingDown or ns==Enum.HumanoidStateType.Ragdoll then
			task.defer(function() if S.noFall and h.Parent and h.Health<h.MaxHealth then h.Health=h.MaxHealth end end)
		end
	end)
	applyNoFall(h,S.noFall)
end

-- ANTI-FLING
local function antiFlingTick()
	if not S.noFling or S.stick or S.fly then return end
	local c=lp.Character; local r=c and c:FindFirstChild("HumanoidRootPart"); local h=getHum()
	if not r or not h then return end
	for _,p in ipairs(c:GetDescendants()) do
		local cls=p.ClassName
		if cls=="BodyVelocity" or cls=="BodyAngularVelocity" or cls=="BodyGyro" or cls=="BodyPosition" or cls=="BodyForce" or cls=="VectorForce" or cls=="Torque" or cls=="AngularVelocity" or cls=="LinearVelocity" or cls=="AlignPosition" or cls=="AlignOrientation" then
			if p.Name~=WALK_AIR_LV and p.Name~=FLY_LV and p.Name~=FLY_AO then pcall(function() p:Destroy() end) end
		end
	end
	for _,p in ipairs(c:GetDescendants()) do
		if p:IsA("Weld") or p:IsA("WeldConstraint") then
			local a=p.Part0 and p.Part0:IsDescendantOf(c)
			local b=p.Part1 and p.Part1:IsDescendantOf(c)
			if not (a and b) then pcall(function() p:Destroy() end) end
		end
	end
	local av=r.AssemblyAngularVelocity
	if av and av.Magnitude>0.5 then pcall(function() r.AssemblyAngularVelocity=Vector3.zero end) end
	if not (S.speed or S.walkAir) then
		local lv=r.AssemblyLinearVelocity
		if lv then
			local m=lv.Magnitude
			if m>ANTI_VIOLENT then pcall(function() r.AssemblyLinearVelocity=Vector3.zero end)
			elseif m>ANTI_MAX_VEL then pcall(function() r.AssemblyLinearVelocity=lv.Unit*ANTI_MAX_VEL end) end
		end
	end
	if h.PlatformStand then h.PlatformStand=false end
	local st=h:GetState()
	if st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown or st==Enum.HumanoidStateType.Physics then
		h:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

-- GOD MODE
local function applyGod(on)
	S.godMode=on
	if on then
		local h=getHum()
		if h and h.Health>0 then pcall(function() h.Health=h.MaxHealth end) end
	end
end
task.spawn(function()
	while true do
		task.wait(0.1)
		if S.godMode then
			local h=getHum()
			if h and h.Health>0 and h.Health<h.MaxHealth then pcall(function() h.Health=h.MaxHealth end) end
		end
	end
end)

-- ANTI-RAGDOLL
task.spawn(function()
	local t=0
	while true do
		task.wait(0.15)
		if S.antiRagdoll and not S.fly and not S.stick and not S.walkAir then
			local h=getHum()
			if h and h.Health>0 then
				local st=h:GetState()
				if st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown or st==Enum.HumanoidStateType.PlatformStanding then
					t=t+0.15
					if t>=0.9 then
						pcall(function()
							h:ChangeState(Enum.HumanoidStateType.GettingUp)
							local r=getRoot()
							if r then r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero end
						end)
						t=0
					end
				else t=0 end
			else t=0 end
		else t=0 end
	end
end)

-- TELEPORT & STICK
local function tpTo(p)
	if not p then return false end
	local mc=lp.Character; local mr=mc and mc:FindFirstChild("HumanoidRootPart"); if not mr then return false end
	local tc=p.Character; local tr=tc and tc:FindFirstChild("HumanoidRootPart"); if not tr then return false end
	if workspace.StreamingEnabled then
		pcall(function() lp:RequestStreamAroundAsync(tr.Position) end); task.wait(0.15)
		tr=tc and tc:FindFirstChild("HumanoidRootPart"); if not tr then return false end
	end
	local tCF=tr.CFrame*CFrame.new(0,2,4)
	for i=1,3 do
		pcall(function() mc:PivotTo(tCF) end); pcall(function() mr.CFrame=tCF end)
		pcall(function() mr.AssemblyLinearVelocity=Vector3.zero end)
		if i<3 then RunService.Heartbeat:Wait() end
	end
	return true
end
local function ensureCG() pcall(function() PhysicsService:RegisterCollisionGroup("MPStick") end); pcall(function() PhysicsService:CollisionGroupSetCollidable("MPStick","Default",false) end) end
local function setGroup(c,g) if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CollisionGroup=g end) end end end end
local function stopStick(keep)
	stickTarget,stickManual=nil,false
	setGroup(lp.Character,"Default")
	local h=getHum()
	if h and keep~=true then
		h.PlatformStand=false; h.AutoRotate=true
		if stickOrigWS then h.WalkSpeed=stickOrigWS end
		if stickOrigJP then if h.UseJumpPower then h.JumpPower=stickOrigJP else h.JumpHeight=stickOrigJP end end
		h:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	stickOrigWS,stickOrigJP=nil,nil
end
local function startStick(tp,manual)
	stopStick(true)
	local mc=lp.Character; local mr=mc and mc:FindFirstChild("HumanoidRootPart")
	local h=mc and mc:FindFirstChildOfClass("Humanoid")
	if not mr or not h or not tp or not tp.Character then return false end
	local tr=tp.Character:FindFirstChild("HumanoidRootPart"); if not tr then return false end
	ensureCG(); setGroup(mc,"MPStick")
	stickOrigWS=h.WalkSpeed; stickOrigJP=h.UseJumpPower and h.JumpPower or h.JumpHeight
	h.PlatformStand=true; h.AutoRotate=false; h.WalkSpeed=0
	if h.UseJumpPower then h.JumpPower=0 else h.JumpHeight=0 end
	h:ChangeState(Enum.HumanoidStateType.Physics)
	stickTarget=tp; stickManual=manual or (tp==selectedPlayer)
	mr.CFrame=tr.CFrame*STICK_OFFSET
	mr.AssemblyLinearVelocity=Vector3.zero; mr.AssemblyAngularVelocity=Vector3.zero
	return true
end

-- ESP
local function clearESP()
	for _,o in pairs(espObjs) do if o.hl then o.hl:Destroy() end; if o.bb then o.bb:Destroy() end end
	espObjs={}
end
local function makeESP(p)
	if p==lp or not p.Character then return end
	if espObjs[p] then
		local o=espObjs[p]
		if o.hl then o.hl.Adornee=p.Character end
		if o.bb then o.bb.Adornee=p.Character:FindFirstChild("Head") end
		return
	end
	local hl=Instance.new("Highlight")
	hl.FillColor=Color3.fromRGB(250,100,100); hl.FillTransparency=0.55
	hl.OutlineColor=Color3.fromRGB(255,150,150); hl.OutlineTransparency=0
	hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee=p.Character; hl.Parent=gui
	local bb=Instance.new("BillboardGui")
	bb.Size=UDim2.fromOffset(150,20); bb.StudsOffset=Vector3.new(0,2.8,0)
	bb.AlwaysOnTop=true; bb.Adornee=p.Character:FindFirstChild("Head"); bb.Parent=gui
	local lbl=Instance.new("TextLabel")
	lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
	lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.Font=Enum.Font.Arcade; lbl.TextSize=13
	lbl.TextStrokeTransparency=0; lbl.Text=p.Name; lbl.Parent=bb
	espObjs[p]={hl=hl,bb=bb}
end
local function startESP() clearESP(); for _,p in pairs(Players:GetPlayers()) do if p~=lp then makeESP(p) end end end
local function stopESP() clearESP() end

-- HIDE NAMES
local function applyHideNames(on)
	S.hideNames=on
	for _,p in pairs(Players:GetPlayers()) do
		if p~=lp and p.Character then
			local h=p.Character:FindFirstChildOfClass("Humanoid")
			if h then
				if on then
					if not hideNameSaved[p] then hideNameSaved[p]=h.DisplayDistanceType end
					pcall(function() h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end)
				else
					pcall(function() h.DisplayDistanceType=hideNameSaved[p] or Enum.HumanoidDisplayDistanceType.Viewer end)
					hideNameSaved[p]=nil
				end
			end
		end
	end
end
task.spawn(function()
	while true do task.wait(2); if S.hideNames then pcall(applyHideNames,true) end end
end)

-- LOW GFX
local function applyLowGFX(on)
	S.lowGraphics=on
	if on then
		for _,d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
				if d.Enabled then d.Enabled=false; lowGFXSaved[d]=true end
			elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				if d.Enabled then d.Enabled=false; lowGFXSaved[d]=true end
			end
		end
		local t=workspace.Terrain
		if t then
			pcall(function() t.WaterWaveSize=0 end)
			pcall(function() t.WaterWaveSpeed=0 end)
		end
	else
		for d in pairs(lowGFXSaved) do if d and d.Parent then pcall(function() d.Enabled=true end) end end
		lowGFXSaved={}
	end
end
workspace.DescendantAdded:Connect(function(d)
	if not S.lowGraphics then return end
	if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
		pcall(function() if d.Enabled then d.Enabled=false; lowGFXSaved[d]=true end end)
	end
end)

-- SHADER
local function applyBright(en)
	local cc=Lighting:FindFirstChild("MP_BS"); local bl=Lighting:FindFirstChild("MP_BB")
	if not en then if cc then cc:Destroy() end; if bl then bl:Destroy() end; return end
	if not cc then cc=Instance.new("ColorCorrectionEffect"); cc.Name="MP_BS"; cc.Contrast=0.08; cc.Saturation=0.05; cc.Parent=Lighting end
	if not bl then bl=Instance.new("BloomEffect"); bl.Name="MP_BB"; bl.Intensity=0.2; bl.Size=24; bl.Threshold=0.9; bl.Parent=Lighting end
	cc.Brightness=0.25
end
local function applyFullbright(en)
	if en then
		if not fullbrightSaved then fullbrightSaved={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime} end
		Lighting.Ambient=Color3.fromRGB(185,185,185); Lighting.OutdoorAmbient=Color3.fromRGB(185,185,185)
		Lighting.Brightness=2; Lighting.ClockTime=14
	elseif fullbrightSaved then
		Lighting.Ambient=fullbrightSaved.Ambient; Lighting.OutdoorAmbient=fullbrightSaved.OutdoorAmbient
		Lighting.Brightness=fullbrightSaved.Brightness; Lighting.ClockTime=fullbrightSaved.ClockTime
		fullbrightSaved=nil
	end
end
task.spawn(function()
	while true do
		task.wait(0.6)
		if S.fullbright and Lighting.Brightness<1.5 then
			Lighting.Brightness=2; Lighting.Ambient=Color3.fromRGB(185,185,185); Lighting.OutdoorAmbient=Color3.fromRGB(185,185,185)
		end
	end
end)
local function applyNoFog(en)
	local at=Lighting:FindFirstChildOfClass("Atmosphere")
	if en then
		if not fogSaved then fogSaved={FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,atmosDensity=at and at.Density or nil} end
		Lighting.FogEnd=100000; Lighting.FogStart=100000; if at then at.Density=0 end
	elseif fogSaved then
		Lighting.FogEnd=fogSaved.FogEnd; Lighting.FogStart=fogSaved.FogStart
		if at and fogSaved.atmosDensity then at.Density=fogSaved.atmosDensity end
		fogSaved=nil
	end
end

-- CAMERA + AUTO CAM
local function getBaseFOV() return S.fov end
local function computeAutoCam(p, root, e)
	e=math.min(e,3600)
	local rp=root.Position
	local look=rp+Vector3.new(0,2,0)
	if p=="orbit" then
		local a=e*0.5
		return rp+Vector3.new(math.cos(a)*15,5,math.sin(a)*15),look
	elseif p=="dj" then
		local a=math.sin(e*0.8)*0.9
		local h=3+math.sin(e*1.5)*2
		return rp+Vector3.new(math.sin(a)*10,h,math.cos(a)*10),look
	elseif p=="car" then
		local h=getHum()
		local d=h and h.MoveDirection or Vector3.zero
		if d.Magnitude<0.1 then d=Vector3.new(0,0,-1) end
		d=Vector3.new(d.X,0,d.Z)
		if d.Magnitude<0.01 then d=Vector3.new(0,0,-1) end
		return rp-d.Unit*10+Vector3.new(0,5,0),look
	elseif p=="crane" then
		local pr=math.min(e/8,1)
		return rp+Vector3.new(5,2+pr*20,-5),look
	elseif p=="drone" then
		local a=e*0.3
		return rp+Vector3.new(math.cos(a)*14,14,math.sin(a)*14),look
	elseif p=="figure8" then
		return rp+Vector3.new(math.sin(e*0.5)*12,6,math.sin(e*1.0)*6),look
	elseif p=="sway" then
		local a=math.sin(e*0.4)*0.6
		return rp+Vector3.new(math.sin(a)*12,4,math.cos(a)*12),look
	elseif p=="dolly" then
		local ph=math.sin(e*0.5)
		return rp+Vector3.new(0,5,-(10+ph*6)),look,70+ph*20
	elseif p=="spiral" then
		local a=e*0.6
		local r=10+math.sin(e*0.3)*4
		local h=5+math.sin(e*0.4)*4
		return rp+Vector3.new(math.cos(a)*r,h,math.sin(a)*r),look
	elseif p=="reveal" then
		local pr=math.min(e/5,1)
		return rp+Vector3.new(0,8,-(30-pr*22)),look
	end
	return nil
end
local function setAutoCam(p)
	S.autoCam=p
	autoCamStart=tick()
	for pat,row in pairs(autoCamRows) do
		S["_ac_"..pat]=(p==pat)
		if row and row.refresh then pcall(function() row.refresh(false) end) end
	end
end
RunService:BindToRenderStep(CAM_BIND, Enum.RenderPriority.Camera.Value+1, function(dt)
	if not cam then return end
	local baseCF=cam.CFrame
	local autoFov=nil
	if S.autoCam and not S.camFP then
		local r=getRoot()
		if r then
			local e=tick()-autoCamStart
			local pat=S.autoCam
			local se=e
			if pat=="auto" then
				local cyc=6
				local pats={"orbit","dj","car","drone","figure8","sway","dolly","spiral"}
				local idx=math.floor(e/cyc)%#pats+1
				pat=pats[idx]; se=e%cyc
			end
			local pos,look,fov=computeAutoCam(pat,r,se)
			if pos and look then baseCF=CFrame.lookAt(pos,look); if fov then autoFov=fov end end
		end
	end
	if S.camShake then
		local sx=(math.random()-0.5)*0.6; local sy=(math.random()-0.5)*0.6
		baseCF=baseCF*CFrame.new(sx,sy,0)
	end
	if S.camDrift then
		local t=tick()
		baseCF=baseCF*CFrame.Angles(math.sin(t*0.6)*0.015,math.sin(t*0.4)*0.015,math.sin(t*0.5)*0.02)
	end
	if S.camRoll~=0 then baseCF=baseCF*CFrame.Angles(0,0,math.rad(S.camRoll)) end
	if S.camHeight~=0 then baseCF=baseCF*CFrame.new(0,S.camHeight,0) end
	if S.camDist>0 and not S.camFP and not S.autoCam then baseCF=baseCF-baseCF.LookVector*S.camDist end
	cam.CFrame=baseCF
	if autoFov then cam.FieldOfView=autoFov
	elseif S.camZoomPulse then cam.FieldOfView=getBaseFOV()+math.sin(tick()*1.5)*25
	elseif math.abs(cam.FieldOfView-getBaseFOV())>0.5 then cam.FieldOfView=getBaseFOV() end
end)

local function applyCamDist(v)
	if not camOrigMinZoom then
		camOrigMinZoom=lp.CameraMinZoomDistance; camOrigMaxZoom=lp.CameraMaxZoomDistance; camOrigMode=lp.CameraMode
	end
	pcall(function()
		if v>0 then lp.CameraMinZoomDistance=v; lp.CameraMaxZoomDistance=v
		else lp.CameraMinZoomDistance=camOrigMinZoom or 0.5; lp.CameraMaxZoomDistance=camOrigMaxZoom or 128 end
	end)
end
local function toggleFP(on)
	S.camFP=on
	pcall(function()
		if on then
			if not camOrigMode then camOrigMinZoom=lp.CameraMinZoomDistance; camOrigMaxZoom=lp.CameraMaxZoomDistance; camOrigMode=lp.CameraMode end
			lp.CameraMode=Enum.CameraMode.LockFirstPerson
		else
			lp.CameraMode=camOrigMode or Enum.CameraMode.Classic
			if S.camDist>0 then applyCamDist(S.camDist) end
		end
	end)
end

-- CINEMA
local ccHD, ccDoF, ccBloom
local uiBarsTop, uiBarsBottom, uiCleanExit
local function toggleHD(on)
	if on then
		if not ccHD then ccHD=Instance.new("ColorCorrectionEffect",Lighting); ccHD.Brightness=0.1; ccHD.Contrast=0.35; ccHD.Saturation=0.4 end
		if not ccBloom then ccBloom=Instance.new("BloomEffect",Lighting); ccBloom.Intensity=0.4; ccBloom.Size=24 end
	else
		if ccHD then ccHD:Destroy(); ccHD=nil end
		if ccBloom then ccBloom:Destroy(); ccBloom=nil end
	end
end
local function toggleDoF(on)
	if on then if not ccDoF then ccDoF=Instance.new("DepthOfFieldEffect",Lighting); ccDoF.FocusDistance=15; ccDoF.InFocusRadius=10; ccDoF.NearIntensity=0.6; ccDoF.FarIntensity=0.9 end
	elseif ccDoF then ccDoF:Destroy(); ccDoF=nil end
end
local function toggleBars(on)
	if on then
		if not uiBarsTop then
			uiBarsTop=Instance.new("Frame",gui); uiBarsTop.Size=UDim2.new(1,0,0.08,0); uiBarsTop.BackgroundColor3=Color3.new(0,0,0); uiBarsTop.BorderSizePixel=0; uiBarsTop.ZIndex=997
			uiBarsBottom=Instance.new("Frame",gui); uiBarsBottom.Size=UDim2.new(1,0,0.08,0); uiBarsBottom.Position=UDim2.new(0,0,1,0); uiBarsBottom.AnchorPoint=Vector2.new(0,1); uiBarsBottom.BackgroundColor3=Color3.new(0,0,0); uiBarsBottom.BorderSizePixel=0; uiBarsBottom.ZIndex=997
		end
	else
		if uiBarsTop then uiBarsTop:Destroy(); uiBarsTop=nil end
		if uiBarsBottom then uiBarsBottom:Destroy(); uiBarsBottom=nil end
	end
end
local function toggleClean(on)
	if on then
		if container then container.Visible=false end
		if kBtn then kBtn.Visible=false end
		if pad then pad.Visible=false end
		if uiCleanExit then uiCleanExit:Destroy() end
		uiCleanExit=Instance.new("TextButton")
		uiCleanExit.Size=UDim2.fromOffset(36,36); uiCleanExit.Position=UDim2.new(1,-46,0,10)
		uiCleanExit.BackgroundColor3=Color3.fromRGB(255,30,80); uiCleanExit.Text="X"; uiCleanExit.TextColor3=Color3.new(1,1,1)
		uiCleanExit.Font=Enum.Font.Arcade; uiCleanExit.TextSize=18; uiCleanExit.ZIndex=9999; uiCleanExit.Parent=gui
		local co=Instance.new("UICorner"); co.CornerRadius=UDim.new(1,0); co.Parent=uiCleanExit
		uiCleanExit.MouseButton1Click:Connect(function()
			S.cinemaClean=false; toggleClean(false); if cinemaCleanRow then cinemaCleanRow.refresh(false) end
		end)
	else
		if uiCleanExit then uiCleanExit:Destroy(); uiCleanExit=nil end
		if container then container.Visible=true end
		if pad then pad.Visible=S.fly end
	end
end
local function toggleBloom(on)
	if on then if not ccBloom then ccBloom=Instance.new("BloomEffect",Lighting); ccBloom.Intensity=1.5; ccBloom.Size=40 end
	elseif ccBloom then ccBloom:Destroy(); ccBloom=nil end
end

-- UI CONSTANTS
local FONT = Enum.Font.Arcade
local P = {
	ink=Color3.fromRGB(12,14,34), bg=Color3.fromRGB(29,43,83), bg2=Color3.fromRGB(18,25,56),
	row=Color3.fromRGB(41,58,108), plum=Color3.fromRGB(126,37,83), plum2=Color3.fromRGB(78,22,54),
	text=Color3.fromRGB(255,241,232), dim=Color3.fromRGB(131,118,156),
	ok=Color3.fromRGB(0,228,54), warn=Color3.fromRGB(255,236,39), bad=Color3.fromRGB(255,0,77),
	orange=Color3.fromRGB(255,163,0), blue=Color3.fromRGB(41,173,255), pink=Color3.fromRGB(255,119,168),
	silver=Color3.fromRGB(194,195,199), lav=Color3.fromRGB(190,170,255), teal=Color3.fromRGB(0,200,190),
	peach=Color3.fromRGB(255,204,170), card=Color3.fromRGB(36,41,54),
	border=Color3.fromRGB(60,66,84), accent=Color3.fromRGB(130,168,255), accent2=Color3.fromRGB(180,140,255)
}
local SPR = {
	fly="...#...|..###..|..###..|..###..|.#####.|#.###.#|...#...",
	speed=".......|#..#...|.#..#..|..#..#.|.#..#..|#..#...|.......",
	jump="...#...|..###..|.#.#.#.|...#...|...#...|.#####.|.......",
	grav="..###..|.#####.|.#####.|.#####.|..###..|...#...|...#...",
	air=".......|..##...|.#####.|#######|#######|.#####.|.......",
	water=".......|.#..#..|#.##.##|.......|.#..#..|#.##.##|.......",
	shield="#######|#######|#######|#######|.#####.|..###..|...#...",
	chute=".#####.|#######|#.#.#.#|.#.#.#.|..#.#..|...#...|...#...",
	ghost="..###..|.#####.|##.#.##|#######|#######|#######|#.#.#.#",
	eye=".......|..###..|.#####.|###.###|.#####.|..###..|.......",
	sun="...#...|.#...#.|..###..|#.###.#|..###..|.#...#.|...#...",
	bulb="..###..|.#####.|.#####.|..###..|..###..|..#.#..|..###..",
	fog=".......|##.###.|.......|.###.##|.......|##.###.|.......",
	fov="##...##|#.....#|.......|...#...|.......|#.....#|##...##",
	loop="..#....|.######|..#....|.......|....#..|######.|....#..",
	up="...#...|..###..|.#####.|#######|...#...|...#...|...#...",
	check=".....#|....##|#..##.|.###..|..#...",
	k="##...##|##..##.|##.##..|####...|##.##..|##..##.|##...##",
	cam="..###..|.#####.|##.#.##|#######|.#####.|..###..|.......",
	star="...#...|..###..|#######|.#####.|..###..|.#...#.|#.....#",
	pin="...#...|..###..|.#####.|#######|#######|..###..|...#..."
}

-- PULSE SYSTEM
local strokePulses = {}
local function addPulse(s, base, amp, spd) strokePulses[s]={base=base,amp=amp,speed=spd,start=os.clock()} end
local function removePulse(s) strokePulses[s]=nil end
RunService.RenderStepped:Connect(function()
	local now=os.clock(); local rm
	for s,p in pairs(strokePulses) do
		if s and s.Parent then s.Transparency=math.clamp(p.base+math.sin((now-p.start)*p.speed)*p.amp,0,1)
		else rm=rm or {}; rm[#rm+1]=s end
	end
	if rm then for _,s in ipairs(rm) do strokePulses[s]=nil end end
end)

-- HELPERS
local function mk(c,p,par) local o=Instance.new(c); for k,v in pairs(p) do o[k]=v end; o.Parent=par; return o end
local function box(parent,size,pos,fill,class)
	local o=mk(class or "Frame",{Size=size,Position=pos,BackgroundColor3=P.ink,BorderSizePixel=0},parent)
	if o:IsA("GuiButton") then o.Text=""; o.AutoButtonColor=false end
	local f=mk("Frame",{Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=fill,BorderSizePixel=0},o)
	mk("Frame",{Size=UDim2.new(1,0,0,2),BackgroundColor3=fill:Lerp(Color3.new(1,1,1),0.22),BorderSizePixel=0},f)
	mk("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=fill:Lerp(Color3.new(0,0,0),0.35),BorderSizePixel=0},f)
	return o,f
end
local function sprite(parent,key,color,px,x,y)
	local h=mk("Frame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(x,y)},parent)
	local rows,wmax=0,0
	for line in SPR[key]:gmatch("[^|]+") do
		wmax=math.max(wmax,#line); local i=1
		while true do
			local a,b=line:find("#+",i); if not a then break end
			mk("Frame",{Size=UDim2.fromOffset((b-a+1)*px,px),Position=UDim2.fromOffset((a-1)*px,rows*px),BackgroundColor3=color,BorderSizePixel=0},h)
			i=b+1
		end
		rows+=1
	end
	h.Size=UDim2.fromOffset(wmax*px,rows*px); return h
end
local function tint(h,c) for _,f in ipairs(h:GetChildren()) do f.BackgroundColor3=c end end
local function txt(parent,s,size,color,pos,sz,align)
	local l=mk("TextLabel",{BackgroundTransparency=1,BorderSizePixel=0,Text=s,Font=FONT,TextSize=size,TextColor3=color,TextScaled=true,Position=pos,Size=sz or UDim2.fromScale(1,1),TextXAlignment=align or Enum.TextXAlignment.Left},parent)
	mk("UITextSizeConstraint",{MaxTextSize=size,MinTextSize=7},l); return l
end
local function drag(handle,target,onTap)
	handle.InputBegan:Connect(function(input)
		local t=input.UserInputType
		if t~=Enum.UserInputType.MouseButton1 and t~=Enum.UserInputType.Touch then return end
		local start,from,moved=input.Position,target.Position,false
		local conn=UIS.InputChanged:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
				local d=i.Position-start; if d.Magnitude>4 then moved=true end
				target.Position=UDim2.new(from.X.Scale,from.X.Offset+d.X,from.Y.Scale,from.Y.Offset+d.Y)
			end
		end)
		local c2; c2=input.Changed:Connect(function()
			if input.UserInputState==Enum.UserInputState.End then conn:Disconnect(); c2:Disconnect(); if not moved and onTap then onTap() end end
		end)
	end)
end
local function hold(btn,fn)
	btn.InputBegan:Connect(function(input)
		local t=input.UserInputType
		if t~=Enum.UserInputType.MouseButton1 and t~=Enum.UserInputType.Touch then return end
		local alive=true
		local c; c=input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then alive=false; c:Disconnect() end end)
		task.spawn(function() fn(); task.wait(0.4); while alive do fn(); task.wait(0.07) end end)
	end)
end

-- BUILD UI
local W,H,TITLE_H,TAB_H,FOOT_H,PROFILE_H = 290, 340, 28, 24, 18, 48
local container=mk("Frame",{Size=UDim2.fromOffset(W+6,H+6),Position=UDim2.new(0,12,0.14,0),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Visible=false},gui)
mk("Frame",{Size=UDim2.fromOffset(W,H),Position=UDim2.fromOffset(6,6),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.4},container)
local _,face=box(container,UDim2.fromOffset(W,H),nil,P.bg)
local mainStroke=mk("UIStroke",{Color=P.border,Thickness=1,Transparency=0.3},face); addPulse(mainStroke,0.5,0.3,1.5)
local bar=mk("Frame",{Size=UDim2.new(1,0,0,TITLE_H),BackgroundColor3=P.plum},face)
mk("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=P.ink},bar)
sprite(bar,"k",P.warn,2,8,7)
txt(bar,"MOVEMENT PANEL",13,P.text,UDim2.fromOffset(28,0),UDim2.new(1,-110,1,-2))
local led=mk("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-78,0.5,-4),BackgroundColor3=P.dim},bar)
local stat=txt(bar,"IDLE",11,P.dim,UDim2.new(1,-66,0,0),UDim2.fromOffset(48,TITLE_H-2))
local miniBtn,miniFace=box(bar,UDim2.fromOffset(22,20),UDim2.new(1,-28,0.5,-10),P.plum2,"TextButton")
txt(miniFace,"-",16,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)
drag(bar,container)
local function updateStatus()
	local n=0
	for k,v in pairs(S) do
		if v==true and not (type(k)=="string" and k:sub(1,1)=="_") then n+=1 end
	end
	led.BackgroundColor3=n>0 and P.ok or P.dim
	stat.Text=n>0 and (n.." ON") or "IDLE"
	stat.TextColor3=n>0 and P.ok or P.dim
end

-- PROFILE STRIP
local profileFrame=mk("Frame",{Size=UDim2.new(1,0,0,PROFILE_H),Position=UDim2.fromOffset(0,TITLE_H),BackgroundColor3=P.bg2},face)
mk("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=P.ink},profileFrame)
mk("Frame",{Size=UDim2.new(0,3,1,0),BackgroundColor3=P.accent2},profileFrame)
local avatar=mk("ImageLabel",{Size=UDim2.fromOffset(36,36),Position=UDim2.fromOffset(10,6),BackgroundColor3=P.ink,Image="rbxthumb://type=AvatarHeadShot&id="..lp.UserId.."&w=150&h=150",ScaleType=Enum.ScaleType.Crop},profileFrame)
mk("UICorner",{CornerRadius=UDim.new(1,0)},avatar)
mk("UIStroke",{Color=P.accent2,Thickness=1.5,Transparency=0.2},avatar)
local dnLbl=txt(profileFrame,lp.DisplayName or lp.Name,13,P.text,UDim2.fromOffset(54,4),UDim2.new(1,-150,0,15)); dnLbl.TextTruncate=Enum.TextTruncate.AtEnd
local uiLbl=txt(profileFrame,"@"..lp.Name,10,P.dim,UDim2.fromOffset(54,20),UDim2.new(1,-150,0,12)); uiLbl.TextTruncate=Enum.TextTruncate.AtEnd
local mapLbl=txt(profileFrame,game.Name or "Unknown",11,P.warn,UDim2.new(1,-140,0,4),UDim2.fromOffset(132,15),Enum.TextXAlignment.Right); mapLbl.TextTruncate=Enum.TextTruncate.AtEnd
local frLbl=txt(profileFrame,"...",10,P.dim,UDim2.new(1,-140,0,20),UDim2.fromOffset(132,12),Enum.TextXAlignment.Right)
task.spawn(function()
	local function upd()
		local cnt=0
		for _,p in pairs(Players:GetPlayers()) do
			if p~=lp then
				local ok2,isF=pcall(function() return lp:IsFriendsWith(p.UserId) end)
				if ok2 and isF then cnt=cnt+1 end
			end
		end
		if frLbl then
			if cnt==0 then frLbl.Text="No friends"; frLbl.TextColor3=P.dim
			else frLbl.Text=cnt.." friend"..(cnt>1 and "s" or ""); frLbl.TextColor3=P.ok end
		end
	end
	task.wait(0.3); pcall(upd)
	while true do task.wait(5); if gui.Parent then pcall(upd) end end
end)

local content=mk("Frame",{Size=UDim2.new(1,-12,1,-(TITLE_H+PROFILE_H+TAB_H+11+FOOT_H+4)),Position=UDim2.fromOffset(6,TITLE_H+PROFILE_H+TAB_H+11),BackgroundTransparency=1},face)
local foot=mk("Frame",{Size=UDim2.new(1,0,0,FOOT_H),Position=UDim2.new(0,0,1,-FOOT_H),BackgroundColor3=P.bg2},face)
mk("Frame",{Size=UDim2.new(1,0,0,2),BackgroundColor3=P.ink},foot)
local cred=txt(foot,"by <font color=\"#FF77A8\">"..CREDIT.."</font>",10,P.dim,UDim2.fromOffset(8,2),UDim2.new(0.7,0,1,-2)); cred.RichText=true
txt(foot,"v34",10,P.dim,UDim2.new(0.7,0,0,2),UDim2.new(0.3,-8,1,-2),Enum.TextXAlignment.Right)

-- TABS
local tabList={{"move","MOVE"},{"guard","GUARD"},{"vision","VISION"},{"util","UTIL"},{"photo","PHOTO"}}
local TAB_W=(W-4-12-12)/5
local tabs,pages={},{}
local TAB_Y=TITLE_H+PROFILE_H+5
for i,t in ipairs(tabList) do
	local name=t[1]
	local pg=mk("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageColor3=P.plum,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
	mk("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},pg)
	mk("UIPadding",{PaddingRight=UDim.new(0,6)},pg)
	pages[name]=pg
	local b,f=box(face,UDim2.fromOffset(TAB_W,TAB_H),UDim2.fromOffset(6+(i-1)*(TAB_W+4),TAB_Y),P.bg2,"TextButton")
	tabs[name]={face=f,lbl=txt(f,t[2],10,P.dim,UDim2.new(),nil,Enum.TextXAlignment.Center)}
	b.MouseButton1Click:Connect(function() setTab(name) end)
end

local tabIndicator=mk("Frame",{Size=UDim2.fromOffset(TAB_W,TAB_H),Position=UDim2.fromOffset(6,TAB_Y),BackgroundColor3=P.accent,ZIndex=1},face)
mk("UICorner",{CornerRadius=UDim.new(0,7)},tabIndicator)
mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,P.accent),ColorSequenceKeypoint.new(0.5,P.accent2),ColorSequenceKeypoint.new(1,P.pink)}),Rotation=0},tabIndicator)
addPulse(tabIndicator,0.2,0.2,4)

setTab=function(name)
	local ti=1
	for i,t in ipairs(tabList) do if t[1]==name then ti=i; break end end
	local tx=6+(ti-1)*(TAB_W+4)
	TweenService:Create(tabIndicator,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(tx,TAB_Y)}):Play()
	for n,p in pairs(pages) do p.Visible=(n==name) end
	for n,t in pairs(tabs) do t.lbl.TextColor3=(n==name) and Color3.new(1,1,1) or P.dim end
	currentTab=name
	if name=="util" and refreshPlayerList then pcall(refreshPlayerList) end
end

local function makeRow(page,order,o)
	local btn,f=box(page,UDim2.new(1,0,0,30),nil,P.row,"TextButton"); btn.LayoutOrder=order
	local stripe=mk("Frame",{Size=UDim2.new(0,4,1,0),BackgroundColor3=o.color,Visible=false},f)
	local icon=sprite(f,o.icon,o.key and P.dim or o.color,2,10,6)
	local right=(o.key and 26 or 0)+(o.st and (o.key and 86 or 88) or 0)
	txt(f,o.label,13,P.text,UDim2.fromOffset(30,0),UDim2.new(1,-(30+right+4),1,0))
	local cb,cbf,chk
	if o.key then
		cb=mk("Frame",{Size=UDim2.fromOffset(18,18),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-17,0.5,0),BackgroundColor3=P.ink},f)
		cbf=mk("Frame",{Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=P.bg2},cb)
		chk=sprite(cbf,"check",P.ink,2,1,2); chk.Visible=false
	end
	if o.st then
		local get,set,step,mn,mx,fmt=table.unpack(o.st)
		local sb=mk("Frame",{Size=UDim2.fromOffset(80,18),Position=UDim2.new(1,o.key and -112 or -88,0.5,-9),BackgroundTransparency=1},f)
		local vb=mk("Frame",{Size=UDim2.fromOffset(40,18),Position=UDim2.fromOffset(20,0),BackgroundColor3=P.ink},sb)
		local vf=mk("Frame",{Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=P.bg2},vb)
		local val=txt(vf,"",10,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)
		local function show() val.Text=string.format(fmt,get()) end
		local function stepBtn(sym,x,dir)
			local b,bf=box(sb,UDim2.fromOffset(18,18),UDim2.fromOffset(x,0),P.bg,"TextButton")
			txt(bf,sym,14,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)
			hold(b,function() set(math.clamp(get()+dir*step,mn,mx)); show() end)
		end
		stepBtn("-",0,-1); stepBtn("+",62,1); show()
	end
	local rowStroke=mk("UIStroke",{Color=P.border,Thickness=1,Transparency=0.55},f)
	local function refresh(anim)
		if not o.key then return end
		if type(S[o.key])~="boolean" then return end
		local on=S[o.key]
		stripe.Visible=on; tint(icon,on and o.color or P.dim)
		cbf.BackgroundColor3=on and o.color or P.bg2; chk.Visible=on
		if on then rowStroke.Color=o.color; addPulse(rowStroke,0.3,0.3,3)
		else removePulse(rowStroke); rowStroke.Color=P.border; rowStroke.Transparency=0.55 end
		if anim and cb then cb.Size=UDim2.fromOffset(24,24); task.delay(0.06,function() cb.Size=UDim2.fromOffset(18,18) end) end
		updateStatus()
	end
	if o.key and type(S[o.key])=="boolean" then
		btn.MouseButton1Click:Connect(function()
			S[o.key]=not S[o.key]
			if o.on then pcall(o.on,S[o.key]) end
			refresh(true)
		end)
	end
	refresh(false); return {refresh=refresh}
end

local kBtn,kFace=box(gui,UDim2.fromOffset(44,44),UDim2.new(0,12,0.14,0),P.plum,"TextButton")
kBtn.Visible=false; kBtn.ZIndex=10
txt(kFace,"K",24,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)
local kStroke=mk("UIStroke",{Color=P.accent2,Thickness=2,Transparency=0.3},kBtn); addPulse(kStroke,0.4,0.4,3)
task.spawn(function()
	local lit=false
	while true do task.wait(0.5); if kBtn.Visible then lit=not lit; kBtn.BackgroundColor3=lit and P.warn or P.ink end end
end)
drag(kBtn,kBtn,function() container.Position=kBtn.Position; container.Visible=true; kBtn.Visible=false end)
miniBtn.MouseButton1Click:Connect(function() kBtn.Position=container.Position; kBtn.Visible=true; container.Visible=false end)

local pad=mk("Frame",{Size=UDim2.fromOffset(50,106),Position=UDim2.new(1,-64,1,-136),BackgroundTransparency=1,Visible=false},gui)
local function padBtn(sym,y,setter)
	local b,f=box(pad,UDim2.fromOffset(50,50),UDim2.fromOffset(0,y),P.bg,"TextButton")
	sprite(f,"up",P.text,4,10,10)
	if sym=="v" then f.BackgroundRotation=180; sprite(f,"up",P.text,4,10,10).Rotation=180 end
	b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then setter(true) end end)
	b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then setter(false) end end)
end
padBtn("^",0,function(v) upHeld=v end); padBtn("v",56,function(v) downHeld=v end)
RunService.RenderStepped:Connect(function() if not S.cinemaClean then pad.Visible=S.fly end end)

-- MOVE
local flyRow=makeRow(pages.move,1,{label="Fly",icon="fly",color=P.orange,key="fly",
	st={function() return S.flySpeed end,function(v) S.flySpeed=v end,10,10,300,"%d"},
	on=function(on) if on then
		if S.stick then S.stick=false; stopStick() end
		if S.tpLoop then S.tpLoop=false; if tpLoopRow then tpLoopRow.refresh(true) end end
		if not startFly() then S.fly=false end
	else stopFly(); local h=getHum(); if h and S.speed then h.WalkSpeed=S.walkSpeed end end end})
makeRow(pages.move,2,{label="Speed",icon="speed",color=P.warn,key="speed",
	st={function() return S.walkSpeed end,function(v) S.walkSpeed=v end,5,16,200,"%d"},
	on=function(on) local h=getHum(); if not h then return end; if on then origWalk=h.WalkSpeed; h.WalkSpeed=S.walkSpeed else h.WalkSpeed=origWalk end end})
makeRow(pages.move,3,{label="Inf Jump (Spam Space)",icon="jump",color=P.ok,key="inf"})
makeRow(pages.move,4,{label="Anti-Grav",icon="grav",color=P.pink,key="anti",
	st={function() return S.gravFactor end,function(v) S.gravFactor=v end,0.05,0.02,1,"%.2fx"},
	on=function(on) if not on then workspace.Gravity=DEFAULT_GRAVITY end end})
makeRow(pages.move,5,{label="Air Walk",icon="air",color=P.silver,key="walkAir",on=function(on) if not on then stopWalkAir() end end})
makeRow(pages.move,6,{label="Water Walk",icon="water",color=P.teal,key="walkWater"})

-- GUARD
makeRow(pages.guard,1,{label="Noclip",icon="ghost",color=P.lav,key="noclip",on=function(on) setNoclip(on) end})
makeRow(pages.guard,2,{label="Anti-Fling+",icon="shield",color=P.blue,key="noFling",
	on=function(on) if not on then local h=getHum(); if h then h.PlatformStand=false end end end})
makeRow(pages.guard,3,{label="No Fall",icon="chute",color=P.peach,key="noFall",
	st={function() return S.fallCap end,function(v) S.fallCap=v end,2,10,60,"%d"},
	on=function(on) local h=getHum(); if h then applyNoFall(h,on) end end})
makeRow(pages.guard,4,{label="God Mode",icon="shield",color=P.bad,key="godMode",on=function(on) applyGod(on) end})
makeRow(pages.guard,5,{label="Anti-Ragdoll",icon="ghost",color=P.lav,key="antiRagdoll",on=function(on) end})

-- VISION
makeRow(pages.vision,1,{label="ESP",icon="eye",color=P.ok,key="esp",on=function(on) if on then startESP() else stopESP() end end})
makeRow(pages.vision,2,{label="Bright",icon="sun",color=P.warn,key="brightShader",on=function(on) applyBright(on) end})
makeRow(pages.vision,3,{label="Fullbright",icon="bulb",color=P.text,key="fullbright",on=function(on) applyFullbright(on) end})
makeRow(pages.vision,4,{label="No Fog",icon="fog",color=P.silver,key="noFog",on=function(on) applyNoFog(on) end})
makeRow(pages.vision,5,{label="FOV",icon="fov",color=P.blue,
	st={function() return S.fov end,function(v) S.fov=v end,5,70,120,"%d"}})
makeRow(pages.vision,6,{label="Hide Names",icon="eye",color=P.pink,key="hideNames",on=function(on) applyHideNames(on) end})
makeRow(pages.vision,7,{label="Low Graphics",icon="sun",color=P.teal,key="lowGraphics",on=function(on) applyLowGFX(on) end})

-- UTIL (players + waypoints)
local uHdr=mk("Frame",{Size=UDim2.new(1,0,0,18),LayoutOrder=1,BackgroundTransparency=1},pages.util)
local countLbl=txt(uHdr,"PLAYERS 0",11,P.dim,UDim2.new(),UDim2.new(1,-60,1,0))
local refBtn,refFace=box(uHdr,UDim2.fromOffset(56,18),UDim2.new(1,-56,0,0),P.bg,"TextButton")
local refTxt=txt(refFace,"REFRESH",9,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)

local listBox,listFace=box(pages.util,UDim2.new(1,0,0,90),nil,P.bg2)
listBox.LayoutOrder=2
playerListFrame=mk("ScrollingFrame",{Size=UDim2.new(1,-6,1,-6),Position=UDim2.fromOffset(3,3),BackgroundTransparency=1,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},listFace)
mk("UIListLayout",{Padding=UDim.new(0,1),SortOrder=Enum.SortOrder.LayoutOrder},playerListFrame)
targetLabel=txt(pages.util,"TARGET -",10,P.dim,nil,UDim2.new(1,0,0,14)); targetLabel.LayoutOrder=3

local function updateTarget()
	local n="-"
	if S.stick and stickTarget then n=stickTarget.Name
	elseif selectedPlayer then n=selectedPlayer.Name end
	targetLabel.Text="TARGET "..n
end

local act=mk("Frame",{Size=UDim2.new(1,0,0,26),LayoutOrder=4,BackgroundTransparency=1},pages.util)
mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},act)
local teleBtn,teleFace=box(act,UDim2.new(0.5,-2,1,0),nil,P.pink,"TextButton"); teleBtn.LayoutOrder=1
local teleTxt=txt(teleFace,"TELEPORT",12,P.ink,UDim2.new(),nil,Enum.TextXAlignment.Center)
local stickBtn,stickFace=box(act,UDim2.new(0.5,-2,1,0),nil,P.bg,"TextButton"); stickBtn.LayoutOrder=2
local stickTxt=txt(stickFace,"STICK",12,P.text,UDim2.new(),nil,Enum.TextXAlignment.Center)
local function updateStickBtn() stickTxt.Text=S.stick and "UNSTICK" or "STICK"; stickTxt.TextColor3=S.stick and P.warn or P.text end

tpLoopRow=makeRow(pages.util,5,{label="TP Loop",icon="loop",color=P.orange,key="tpLoop",
	on=function(on)
		if not on then return end
		if not selectedPlayer then selectedPlayer=findNearest(math.huge); if not selectedPlayer then S.tpLoop=false; return end; updateTarget(); refreshPlayerList() end
		if S.stick then S.stick=false; stopStick(); updateStickBtn() end
		if S.fly then S.fly=false; stopFly(); flyRow.refresh(true) end
	end})

makeRow(pages.util,6,{label="Auto Respawn",icon="chute",color=P.ok,key="autorespawn",
	on=function(on)
		local h=getHum()
		if h and on then
			h.Died:Connect(function() if S.autorespawn then task.wait(0.1); pcall(function() lp:LoadCharacter() end) end end)
		end
	end})
makeRow(pages.util,7,{label="Anti-AFK",icon="loop",color=P.warn,key="antiAFK",
	on=function(on)
		S.antiAFK=on
		if on then
			if antiAFKThread then task.cancel(antiAFKThread) end
			antiAFKThread=task.spawn(function()
				local VIM
				pcall(function() VIM=game:GetService("VirtualInputManager") end)
				while S.antiAFK do
					task.wait(15)
					if S.antiAFK and VIM then
						pcall(function()
							VIM:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
							task.wait(0.1)
							VIM:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
						end)
					end
				end
			end)
		elseif antiAFKThread then task.cancel(antiAFKThread); antiAFKThread=nil end
	end})

-- WAYPOINT SECTION
local wpHdr=mk("Frame",{Size=UDim2.new(1,0,0,18),LayoutOrder=8,BackgroundTransparency=1},pages.util)
txt(wpHdr,"WAYPOINTS (3 SLOT)",11,P.warn,UDim2.new(),UDim2.new(1,0,1,0))
local function createWP(idx,order)
	local r=mk("Frame",{Size=UDim2.new(1,0,0,26),LayoutOrder=order,BackgroundColor3=P.row},pages.util)
	mk("UICorner",{CornerRadius=UDim.new(0,4)},r)
	txt(r,"Slot "..idx,11,P.text,UDim2.fromOffset(8,0),UDim2.new(0.4,0,1,0))
	local saveBtn=mk("TextButton",{Size=UDim2.new(0.3,-4,0.8,0),Position=UDim2.new(0.4,0,0.1,0),BackgroundColor3=P.ok,Text="SAVE",TextColor3=P.ink,Font=FONT,TextSize=10},r)
	mk("UICorner",{CornerRadius=UDim.new(0,3)},saveBtn)
	local tpBtn=mk("TextButton",{Size=UDim2.new(0.3,-4,0.8,0),Position=UDim2.new(0.7,0,0.1,0),BackgroundColor3=P.bg,Text="TP",TextColor3=P.dim,Font=FONT,TextSize=10},r)
	mk("UICorner",{CornerRadius=UDim.new(0,3)},tpBtn)
	saveBtn.MouseButton1Click:Connect(function()
		local root=getRoot()
		if root then
			waypoints[idx]=root.Position
			local orig=saveBtn.BackgroundColor3
			saveBtn.BackgroundColor3=Color3.fromRGB(200,255,200)
			TweenService:Create(saveBtn,TweenInfo.new(0.4),{BackgroundColor3=orig}):Play()
			tpBtn.BackgroundColor3=P.blue; tpBtn.TextColor3=P.ink
		end
	end)
	tpBtn.MouseButton1Click:Connect(function()
		local root=getRoot()
		if root and waypoints[idx] then
			root.CFrame=CFrame.new(waypoints[idx]+Vector3.new(0,3,0))
		end
	end)
end
createWP(1,9); createWP(2,10); createWP(3,11)

refreshPlayerList=function()
	if not playerListFrame then return end
	for _,c in ipairs(playerListFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	if selectedPlayer and not isAlive(selectedPlayer) then selectedPlayer=nil
		if S.stick and stickManual then S.stick=false; stopStick(); updateStickBtn() end
		if S.tpLoop then S.tpLoop=false; if tpLoopRow then tpLoopRow.refresh(true) end end end
	local list={}
	for _,p in pairs(Players:GetPlayers()) do if p~=lp and isAlive(p) then table.insert(list,p) end end
	table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end)
	countLbl.Text="PLAYERS "..#list
	if #list==0 then txt(playerListFrame,"NO ONE ELSE HERE",10,P.dim,nil,UDim2.new(1,0,0,24),Enum.TextXAlignment.Center) end
	local mr=getRoot(); local pos=mr and mr.Position or Vector3.zero
	for i,p in ipairs(list) do
		local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local tr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local hp=h and (h.Health/math.max(h.MaxHealth,1)) or 1
		local hc=hp>0.5 and P.ok or (hp>0.25 and P.warn or P.bad)
		local d=tr and (tr.Position-pos).Magnitude or 0
		local sel=(p==selectedPlayer)
		local r=mk("TextButton",{Size=UDim2.new(1,0,0,20),LayoutOrder=i,BackgroundColor3=sel and P.plum or P.row,Text="",AutoButtonColor=false},playerListFrame)
		mk("Frame",{Size=UDim2.fromOffset(6,6),Position=UDim2.fromOffset(6,7),BackgroundColor3=hc},r)
		txt(r,p.Name,11,P.text,UDim2.fromOffset(16,0),UDim2.new(1,-58,1,0))
		txt(r,fmtDist(d),10,P.dim,UDim2.new(1,-44,0,0),UDim2.fromOffset(40,20),Enum.TextXAlignment.Right)
		r.MouseButton1Click:Connect(function() selectedPlayer=p; updateTarget(); refreshPlayerList() end)
	end
	updateTarget()
end

refBtn.MouseButton1Click:Connect(function() refTxt.Text="..."; refreshPlayerList(); task.delay(0.4,function() refTxt.Text="REFRESH" end) end)
teleBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then selectedPlayer=findNearest(math.huge); if not selectedPlayer then return end; updateTarget(); refreshPlayerList() end
	teleTxt.Text="..."; if tpTo(selectedPlayer) then task.delay(0.5,function() teleTxt.Text="TELEPORT" end) else teleTxt.Text="TELEPORT" end
end)
stickBtn.MouseButton1Click:Connect(function()
	if S.stick then S.stick=false; stopStick(); updateStickBtn(); updateTarget(); return end
	local t=selectedPlayer or findNearest(math.huge); if not t then return end
	if not selectedPlayer then selectedPlayer=t; refreshPlayerList() end
	if S.tpLoop then S.tpLoop=false; tpLoopRow.refresh(true) end
	tpTo(t); if startStick(t,true) then S.stick=true; updateStickBtn(); updateTarget() end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if currentTab=="util" and container.Visible then pcall(refreshPlayerList) end
	end
end)

local function watchPlayer(p)
	p.CharacterAdded:Connect(function()
		task.delay(0.5,function()
			pcall(refreshPlayerList)
			if S.esp then makeESP(p) end
			if S.hideNames then pcall(applyHideNames,true) end
		end)
	end)
end
for _,p in pairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(function(p) watchPlayer(p); task.delay(0.3,function() pcall(refreshPlayerList); if S.esp then makeESP(p) end; if S.hideNames then pcall(applyHideNames,true) end end) end)
Players.PlayerRemoving:Connect(function(p)
	if espObjs[p] then if espObjs[p].hl then espObjs[p].hl:Destroy() end; if espObjs[p].bb then espObjs[p].bb:Destroy() end; espObjs[p]=nil end
	hideNameSaved[p]=nil
	if selectedPlayer==p then selectedPlayer=nil
		if S.stick and stickManual then S.stick=false; stopStick(); updateStickBtn() end
		if S.tpLoop then S.tpLoop=false; if tpLoopRow then tpLoopRow.refresh(true) end end end
	task.delay(0.2,function() pcall(refreshPlayerList) end)
end)

-- PHOTO
local phHdr=mk("Frame",{Size=UDim2.new(1,0,0,18),LayoutOrder=1,BackgroundTransparency=1},pages.photo)
txt(phHdr,"CAMERA CONTROLS",11,P.teal,UDim2.new(),UDim2.new(1,0,1,0))
makeRow(pages.photo,2,{label="Camera Roll",icon="cam",color=P.teal,
	st={function() return S.camRoll end,function(v) S.camRoll=v end,5,-45,45,"%d"}})
makeRow(pages.photo,3,{label="Camera Height",icon="up",color=P.teal,
	st={function() return S.camHeight end,function(v) S.camHeight=v end,0.5,-5,5,"%.1f"}})
makeRow(pages.photo,4,{label="Camera Distance",icon="cam",color=P.blue,
	st={function() return S.camDist end,function(v) S.camDist=v; applyCamDist(v) end,0.5,0,30,"%.1f"}})
makeRow(pages.photo,5,{label="Camera Shake",icon="cam",color=P.orange,key="camShake",on=function(on) end})
makeRow(pages.photo,6,{label="Camera Drift",icon="cam",color=P.pink,key="camDrift",on=function(on) end})
makeRow(pages.photo,7,{label="Cinematic Zoom",icon="fov",color=P.lav,key="camZoomPulse",
	on=function(on) if not on then cam.FieldOfView=getBaseFOV() end end})
makeRow(pages.photo,8,{label="First Person",icon="eye",color=P.ok,key="camFP",on=function(on) toggleFP(on) end})

local acHdr=mk("Frame",{Size=UDim2.new(1,0,0,18),LayoutOrder=9,BackgroundTransparency=1},pages.photo)
txt(acHdr,"AUTO CAMERA (MOVES ITSELF)",11,P.pink,UDim2.new(),UDim2.new(1,0,1,0))

local function makeACam(order,pat,label,icon,color)
	S["_ac_"..pat]=false
	local row=makeRow(pages.photo,order,{label=label,icon=icon,color=color,key="_ac_"..pat,
		on=function(on)
			if on then setAutoCam(pat)
			elseif S.autoCam==pat then setAutoCam(nil) end
		end})
	autoCamRows[pat]=row
end
makeACam(10,"dj","DJ Mode (Swing)","star",P.pink)
makeACam(11,"car","Cinematic Car","speed",P.orange)
makeACam(12,"auto","Cinematic AUTO (Cycle)","loop",P.warn)
makeACam(13,"orbit","Orbit 360","loop",P.teal)
makeACam(14,"drone","Drone (High)","fly",P.blue)
makeACam(15,"crane","Crane Shot","up",P.lav)
makeACam(16,"dolly","Dolly Zoom","fov",P.bad)
makeACam(17,"spiral","Spiral","loop",P.silver)
makeACam(18,"figure8","Figure 8","loop",P.silver)
makeACam(19,"sway","Music Video Sway","cam",P.peach)
makeACam(20,"reveal","Cinematic Reveal","cam",P.ok)

local vHdr=mk("Frame",{Size=UDim2.new(1,0,0,18),LayoutOrder=21,BackgroundTransparency=1},pages.photo)
txt(vHdr,"VISUAL EFFECTS",11,P.warn,UDim2.new(),UDim2.new(1,0,1,0))
makeRow(pages.photo,22,{label="HD Clarity",icon="sun",color=P.ok,key="cinemaHD",on=function(on) toggleHD(on) end})
makeRow(pages.photo,23,{label="Aesthetic DoF",icon="eye",color=P.lav,key="cinemaDoF",on=function(on) toggleDoF(on) end})
makeRow(pages.photo,24,{label="Cinematic Bars",icon="fov",color=P.silver,key="cinemaBars",on=function(on) toggleBars(on) end})
cinemaCleanRow=makeRow(pages.photo,25,{label="Clean UI",icon="cam",color=P.blue,key="cinemaClean",on=function(on) toggleClean(on) end})
makeRow(pages.photo,26,{label="Bloom (Neon)",icon="sun",color=P.pink,key="cinemaBloom",on=function(on) toggleBloom(on) end})

-- INPUT
UIS.JumpRequest:Connect(function()
	if S.inf and not S.fly then
		local h=getHum()
		if h and h.Health>0 then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
	end
end)
UIS.InputBegan:Connect(function(i,gp)
	if i.KeyCode==Enum.KeyCode.RightShift and S.cinemaClean then
		S.cinemaClean=false; toggleClean(false); if cinemaCleanRow then cinemaCleanRow.refresh(false) end
	end
	if gp then return end
	if i.KeyCode==Enum.KeyCode.E then upHeld=true
	elseif i.KeyCode==Enum.KeyCode.Q then downHeld=true end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.E then upHeld=false elseif i.KeyCode==Enum.KeyCode.Q then downHeld=false end end)

-- LOOPS
RunService.PreSimulation:Connect(function()
	if S.noFall and not S.stick and not S.fly and not S.tpLoop and not S.walkAir and not S.noclip then
		local r=getRoot()
		if r then local v=r.AssemblyLinearVelocity; if v.Y<-S.fallCap then r.AssemblyLinearVelocity=Vector3.new(v.X,-S.fallCap,v.Z) end end
	end
end)
RunService.Heartbeat:Connect(function(dt)
	if S.speed and not S.fly and not S.stick and not S.tpLoop then local h=getHum(); if h then h.WalkSpeed=S.walkSpeed end end
	if S.anti then workspace.Gravity=DEFAULT_GRAVITY*S.gravFactor end
	antiFlingTick(); walkAirTick(); walkWaterTick(); noclipTick()
	if S.stick then
		local mc,mr,mh=lp.Character,getRoot(),getHum()
		if not mr or not mh or not mc then S.stick=false; stopStick()
		else
			if mh:GetState()~=Enum.HumanoidStateType.Physics then mh:ChangeState(Enum.HumanoidStateType.Physics) end
			if mh.AutoRotate then mh.AutoRotate=false end
			if not mh.PlatformStand then mh.PlatformStand=true end
			local tc=stickTarget and stickTarget.Character
			local tr=tc and tc:FindFirstChild("HumanoidRootPart")
			if not (isAlive(stickTarget) and tr) then
				if stickManual then S.stick=false; stopStick(); selectedPlayer=nil
				else
					local nt=findNearest(STICK_RANGE)
					if nt then stopStick(true); if not startStick(nt,false) then S.stick=false; stopStick() end
					else S.stick=false; stopStick() end
				end
			else
				local tCF=tr.CFrame*STICK_OFFSET; local a=1-math.exp(-dt*STICK_LERP)
				mr.CFrame=mr.CFrame:Lerp(tCF,a); mr.AssemblyLinearVelocity=Vector3.zero; mr.AssemblyAngularVelocity=Vector3.zero
			end
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.15)
		if S.tpLoop then
			if selectedPlayer and isAlive(selectedPlayer) then
				local mr=getRoot(); local tr=selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
				if mr and tr and (tr.Position-mr.Position).Magnitude>4 then tpTo(selectedPlayer) end
			else S.tpLoop=false; if tpLoopRow then tpLoopRow.refresh(true) end end
		end
	end
end)

-- INTRO
local function openWindow(fast)
	container.Visible=true
	if not fast then
		for _,h in ipairs({8,64,150,240,H+6}) do container.Size=UDim2.fromOffset(W+6,h); task.wait(0.04) end
	end
	container.Size=UDim2.fromOffset(W+6,H+6)
end
local function runIntro(done)
	local skip=false
	local ov=mk("TextButton",{Size=UDim2.fromScale(1,1),BackgroundColor3=P.ink,BackgroundTransparency=1,Text="",ZIndex=5000},gui)
	ov.MouseButton1Click:Connect(function() skip=true end)
	local function w(t) if not skip then task.wait(t) end end
	local CW,CH=280,130
	local card,cf=box(ov,UDim2.fromOffset(CW,CH),UDim2.new(0.5,-CW/2,0,-CH-20),P.bg)
	card.ClipsDescendants=true
	sprite(cf,"k",P.warn,3,14,10)
	local l1=txt(cf,"",12,P.dim,UDim2.fromOffset(44,10),UDim2.fromOffset(220,14))
	local l2s=txt(cf,"",24,P.plum,UDim2.fromOffset(18,32),UDim2.fromOffset(240,26))
	local l2=txt(cf,"",24,P.warn,UDim2.fromOffset(16,30),UDim2.fromOffset(240,26))
	local l3=txt(cf,"",12,P.text,UDim2.fromOffset(16,62),UDim2.fromOffset(240,14))
	local _,bf=box(cf,UDim2.fromOffset(248,16),UDim2.fromOffset(16,84),P.bg2)
	local N,segs=16,{}
	for i=1,N do segs[i]=mk("Frame",{Size=UDim2.fromOffset(12,6),Position=UDim2.fromOffset(8+(i-1)*14.5,5),BackgroundColor3=P.ink},bf) end
	local st=txt(cf,"",10,P.dim,UDim2.fromOffset(16,104),UDim2.fromOffset(240,14))
	for _,tr in ipairs({0.85,0.7,0.55}) do ov.BackgroundTransparency=tr; w(0.04) end
	for i=1,4 do card.Position=UDim2.new(0.5,-CW/2,0.5,-CH/2-(4-i)*60); w(0.05) end
	local function to(lbls,s,d)
		for i=1,#s do for _,l in ipairs(lbls) do l.Text=s:sub(1,i).."_" end; w(d) end
		for _,l in ipairs(lbls) do l.Text=s end
	end
	to({l1},"CREATED BY",0.03); to({l2s,l2},CREDIT,0.05); to({l3},"MOVEMENT PANEL V34",0.02)
	local ramp={P.bad,P.orange,P.warn,P.ok}
	local msg={"INIT PHYSICS","LOAD MODULES","BUILD UI","READY!"}
	for i=1,N do
		segs[i].BackgroundColor3=ramp[math.ceil(i/N*#ramp)]
		st.Text=msg[math.ceil(i/N*#msg)].."  "..math.floor(i/N*100).."%"
		w(0.05)
	end
	for _=1,2 do st.TextColor3=P.warn; w(0.08); st.TextColor3=P.ok; w(0.08) end
	w(0.1)
	local fades={0.7,0.85,1}
	for i,h in ipairs({85,40,8}) do
		card.Size=UDim2.fromOffset(CW,h); card.Position=UDim2.new(0.5,-CW/2,0.5,-h/2); ov.BackgroundTransparency=fades[i]; w(0.04)
	end
	ov:Destroy(); done()
end

setTab("move"); updateStatus(); task.spawn(pcall,refreshPlayerList)
if CFG.intro then task.spawn(runIntro,openWindow) else openWindow(true) end

-- RESPAWN
local function onCharacter(char)
	local h=char:WaitForChild("Humanoid",10); if not h then return end
	origWalk=h.WalkSpeed; flyObjs={}; stickTarget=nil; stickManual=false; hookedHum=nil; noclipTracked={}
	stopWalkAir(); if S.stick then S.stick=false; updateStickBtn() end; updateTarget(); hookHum(h)
	if S.fly then task.wait(0.5); if S.fly then startFly() end end
	if S.speed then h.WalkSpeed=S.walkSpeed end
	if S.noFall then applyNoFall(h,true) end
	if S.noclip then task.wait(0.1); setNoclip(true) end
	if S.godMode then task.wait(0.3); if S.godMode then pcall(function() h.Health=h.MaxHealth end) end end
	if S.cinemaClean then S.cinemaClean=false; toggleClean(false); if cinemaCleanRow then cinemaCleanRow.refresh(false) end end
	if S.hideNames then task.wait(0.5); pcall(applyHideNames,true) end
	if S.camFP then pcall(function() lp.CameraMode=Enum.CameraMode.LockFirstPerson end) end
	if S.camDist>0 and not S.camFP then pcall(function() applyCamDist(S.camDist) end) end
end
lp.CharacterAdded:Connect(onCharacter); if lp.Character then task.spawn(onCharacter,lp.Character) end