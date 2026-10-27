--!strict
-- ZT_Art (client): the parts of the art bible that live on the screen.
--  1. Our own character animation, made in code: walk, run, idle, jump/fall, sit, zombie shuffle.
--     Every client animates every character (players, bots, mannequins) the same way.
--  2. UI: two fonts only, palette colours, a spring on every button with our click sound.
--  3. Light per location: lobby, settlement, cave get their own colour grade over the time-of-day look.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function safely(name: string, f: () -> ())
	local ok, err = pcall(f)
	if not ok then
		warn("[ZT_Art] " .. name .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------
-- 1. ANIMATION
---------------------------------------------------------------------
type Rig = {
	model: Model, humanoid: Humanoid, root: BasePart,
	joints: { [string]: any }, now: { [string]: Vector3 }, bob: number,
	phase: number, seed: number, r6: boolean,
}
local rigs: { [Model]: Rig } = {}

local R15 = { "Root", "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftWrist", "RightWrist",
	"LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle" }
local R6 = { ["RootJoint"] = "Root", ["Neck"] = "Neck", ["Left Shoulder"] = "LeftShoulder", ["Right Shoulder"] = "RightShoulder",
	["Left Hip"] = "LeftHip", ["Right Hip"] = "RightHip" }

local function isZombie(model: Model): boolean
	local glow = model:FindFirstChild("ZT_Highlight")
	if glow and glow:IsA("Highlight") then
		local f = glow.FillColor
		-- light blue = the last survivor, not a zombie
		return not (math.abs(f.R * 255 - 120) < 3 and math.abs(f.G * 255 - 235) < 3 and math.abs(f.B * 255 - 255) < 3)
	end
	return model.Name == "Zombie"
end

local function track(model: Model)
	if rigs[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local joints: { [string]: any } = {}
	local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
	for _, d in ipairs(model:GetDescendants()) do
		-- classic rigs use Motor6D; the new physics rigs use AnimationConstraint (same names, same Transform)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			if r6 then
				local key = R6[d.Name]
				if key then
					joints[key] = d
				end
			elseif table.find(R15, d.Name) then
				joints[d.Name] = d
			end
		end
	end
	if next(joints) == nil then
		return
	end
	local now: { [string]: Vector3 } = {}
	for key in pairs(joints) do
		now[key] = Vector3.zero
	end
	rigs[model] = { model = model, humanoid = humanoid, root = root, joints = joints, now = now, bob = 0,
		phase = math.random() * 6.28, seed = math.random() * 100, r6 = r6 }
	-- stop any animation track that is still around (old saves, other scripts)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			t:Stop(0)
		end
	end
end

local function untrack(model: Model)
	local rig = rigs[model]
	if rig then
		for _, j in pairs(rig.joints) do
			if j.Parent then
				j.Transform = CFrame.identity
			end
		end
		rigs[model] = nil
	end
end

-- targets for one frame: { joint = Vector3(pitch, yaw, roll) } and a vertical offset of the body.
-- pitch: + = limb forward (knee: - = bend); roll of shoulders and hips: + = away from the body
-- (left side written with +, right side with -, the apply step turns both outward)
local function pose(rig: Rig, dt: number): ({ [string]: Vector3 }, number)
	local t: { [string]: Vector3 } = {}
	local h = rig.humanoid
	local v = rig.root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z).Magnitude
	local zombie = isZombie(rig.model)
	local clock = os.clock() + rig.seed
	local breathe = math.sin(clock * 2.1)
	local Z = Vector3.zero

	if h.Health <= 0 then
		return t, 0
	end

	if h.Sit then
		t.LeftHip = Vector3.new(1.45, 0, 0.08)
		t.RightHip = Vector3.new(1.45, 0, -0.08)
		t.LeftKnee = Vector3.new(-1.45, 0, 0)
		t.RightKnee = Vector3.new(-1.45, 0, 0)
		t.LeftShoulder = Vector3.new(0.35, 0, 0.1)
		t.RightShoulder = Vector3.new(0.35, 0, -0.1)
		t.LeftElbow = Vector3.new(0.5, 0, 0)
		t.RightElbow = Vector3.new(0.5, 0, 0)
		t.Waist = Vector3.new(0.03 * breathe, 0, 0)
		t.Neck = Vector3.new(-0.05, math.sin(clock * 0.4) * 0.35, 0)
		return t, 0
	end

	local airborne = math.abs(v.Y) > 7 and h.FloorMaterial == Enum.Material.Air
	if airborne then
		local up = v.Y > 0
		t.LeftShoulder = Vector3.new(if up then 2.6 else 1.9, 0, 0.45)
		t.RightShoulder = Vector3.new(if up then 2.6 else 1.9, 0, -0.45)
		t.LeftElbow = Vector3.new(0.35, 0, 0)
		t.RightElbow = Vector3.new(0.35, 0, 0)
		t.LeftHip = Vector3.new(if up then 0.7 else 0.25, 0, 0.05)
		t.RightHip = Vector3.new(if up then -0.15 else 0.45, 0, -0.05)
		t.LeftKnee = Vector3.new(if up then -1.1 else -0.4, 0, 0)
		t.RightKnee = Vector3.new(if up then -0.3 else -0.7, 0, 0)
		t.Waist = Vector3.new(if up then 0.12 else -0.08, 0, 0)
		t.Neck = Vector3.new(if up then 0.15 else -0.2, 0, 0)
		return t, 0
	end

	local speed = math.min(flat, 34)
	local moving = speed > 0.8
	local run = math.clamp(speed / 16, 0, 1.4)
	if moving then
		local rate = if zombie then 0.42 else 0.6
		rig.phase = (rig.phase + dt * (3 + speed * rate)) % (math.pi * 2)
	end
	local p = rig.phase
	local s, c = math.sin(p), math.cos(p)

	if zombie then
		-- the shuffle: arms out in front, head on one side, a limping step
		local a = if moving then 0.35 + 0.25 * run else 0
		local reach = 1.42 + 0.06 * math.sin(clock * 3.1)
		t.LeftShoulder = Vector3.new(reach + 0.12 * s * a, 0.1, 0.12 + 0.05 * math.sin(clock * 2.3))
		t.RightShoulder = Vector3.new(reach - 0.12 * s * a + 0.1, -0.1, -0.12 - 0.05 * math.sin(clock * 2.7))
		t.LeftElbow = Vector3.new(0.15 + 0.08 * math.sin(clock * 4), 0, 0)
		t.RightElbow = Vector3.new(0.3, 0, 0)
		t.LeftWrist = Vector3.new(-0.3, 0, 0)
		t.RightWrist = Vector3.new(-0.45, 0, 0)
		t.LeftHip = Vector3.new(a * 0.9 * s, 0, 0.04)
		t.RightHip = Vector3.new(-a * 0.6 * s, 0, -0.04)
		t.LeftKnee = Vector3.new(-a * 1.1 * math.max(0, c), 0, 0)
		t.RightKnee = Vector3.new(-0.25 - a * 0.7 * math.max(0, -c), 0, 0) -- the stiff leg
		t.LeftAnkle = Vector3.new(-a * 0.3 * math.max(0, -s), 0, 0)
		t.RightAnkle = Z
		t.Waist = Vector3.new(-0.22 - 0.05 * run, 0.12 * s * a, 0.08 * math.sin(clock * 1.3))
		t.Neck = Vector3.new(0.12, 0.1 * math.sin(clock * 0.9), 0.32 + 0.06 * math.sin(clock * 1.7))
		t.Root = Vector3.new(0, 0, 0.06 * s * a)
		return t, if moving then -0.18 * math.abs(s) * a else 0.03 * breathe
	end

	if moving then
		local a = 0.35 + 0.45 * math.min(run, 1.2)
		t.LeftHip = Vector3.new(a * s, 0, 0.03)
		t.RightHip = Vector3.new(-a * s, 0, -0.03)
		t.LeftKnee = Vector3.new(-(0.15 + a * 1.25 * math.max(0, c)), 0, 0)
		t.RightKnee = Vector3.new(-(0.15 + a * 1.25 * math.max(0, -c)), 0, 0)
		t.LeftAnkle = Vector3.new(-a * 0.35 * math.max(0, -s), 0, 0)
		t.RightAnkle = Vector3.new(-a * 0.35 * math.max(0, s), 0, 0)
		t.LeftShoulder = Vector3.new(-a * 0.95 * s, 0, 0.06)
		t.RightShoulder = Vector3.new(a * 0.95 * s, 0, -0.06)
		t.LeftElbow = Vector3.new(0.25 + 0.55 * run, 0, 0)
		t.RightElbow = Vector3.new(0.25 + 0.55 * run, 0, 0)
		t.Waist = Vector3.new(-0.06 - 0.12 * math.min(run, 1.2), 0.14 * s * a, 0)
		t.Neck = Vector3.new(0.05 + 0.06 * run, -0.1 * s * a, 0)
		t.Root = Vector3.new(0, 0.05 * s * a, 0)
		return t, -0.22 * a * math.abs(c) + 0.06 * a
	end

	-- idle: breathing, weight on one leg now and then, a look around
	local shift = math.sin(clock * 0.37)
	t.Waist = Vector3.new(0.025 * breathe, 0.04 * shift, 0.03 * shift)
	t.Neck = Vector3.new(-0.02 * breathe, 0.25 * math.sin(clock * 0.23), 0)
	t.LeftShoulder = Vector3.new(0.04 * breathe, 0, 0.09 + 0.02 * breathe)
	t.RightShoulder = Vector3.new(0.04 * breathe, 0, -0.09 - 0.02 * breathe)
	t.LeftElbow = Vector3.new(0.12, 0, 0)
	t.RightElbow = Vector3.new(0.12, 0, 0)
	t.LeftHip = Vector3.new(0, 0, 0.03 + 0.03 * shift)
	t.RightHip = Vector3.new(0, 0, -0.03 + 0.03 * shift)
	t.LeftKnee = Vector3.new(-0.04 * math.max(0, shift), 0, 0)
	t.RightKnee = Vector3.new(-0.04 * math.max(0, -shift), 0, 0)
	t.Root = Vector3.new(0, 0, -0.025 * shift)
	return t, 0.015 * breathe
end

local DIST = 220 -- characters farther than this from the camera are not animated (phones)
RunService.Stepped:Connect(function(_, dt)
	dt = math.min(dt, 0.1)
	local eye = camera.CFrame.Position
	local k = 1 - math.exp(-14 * dt)
	for model, rig in pairs(rigs) do
		if not model.Parent or not rig.root.Parent then
			rigs[model] = nil
			continue
		end
		if (rig.root.Position - eye).Magnitude > DIST then
			continue
		end
		local ok, err = pcall(function()
			local target, bob = pose(rig, dt)
			rig.bob += (bob - rig.bob) * k
			local scale = model:GetScale()
			for key, joint in pairs(rig.joints) do
				local want = target[key] or Vector3.zero
				local cur = rig.now[key] + (want - rig.now[key]) * k
				rig.now[key] = cur
				-- poses are written with "+roll = away from the body" for both sides
				local roll = if key == "LeftShoulder" or key == "LeftHip" or key == "RightShoulder" or key == "RightHip" then -cur.Z else cur.Z
				local rot = CFrame.Angles(cur.X, cur.Y, roll)
				if rig.r6 then
					-- R6 joints are turned 90 degrees: limbs swing around their local Z
					if key == "LeftShoulder" or key == "LeftHip" then
						rot = CFrame.Angles(0, 0, -cur.X)
					elseif key == "RightShoulder" or key == "RightHip" then
						rot = CFrame.Angles(0, 0, cur.X)
					end
				end
				if key == "Root" then
					joint.Transform = CFrame.new(0, rig.bob * scale, 0) * rot
				else
					joint.Transform = rot
				end
			end
		end)
		if not ok then
			rigs[model] = nil
			warn("[ZT_Art] anim: " .. tostring(err))
		end
	end
end)

-- built-in Roblox particle textures -> our own particle images (also for effects made on this client)
local PARTICLE: { [string]: string } = {
	["rbxasset://textures/particles/sparkles_main.dds"] = "rbxassetid://121492703539177",
	["rbxasset://textures/particles/smoke_main.dds"] = "rbxassetid://80076731723169",
	["rbxasset://textures/particles/fire_main.dds"] = "rbxassetid://80076731723169",
}

local function consider(item: Instance)
	if item:IsA("ParticleEmitter") then
		local own = PARTICLE[item.Texture]
		if own then
			item.Texture = own
		end
		return
	end
	if item:IsA("Humanoid") then
		local model = item.Parent
		if model and model:IsA("Model") then
			task.delay(0.3, function()
				if model.Parent then
					track(model)
				end
			end)
		end
	end
end
workspace.DescendantAdded:Connect(consider)
workspace.DescendantRemoving:Connect(function(item)
	if item:IsA("Model") and rigs[item] then
		rigs[item] = nil
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	consider(d)
end
-- a new character's joints come a moment after the humanoid
task.spawn(function()
	while true do
		task.wait(2)
		for model, rig in pairs(rigs) do
			if not model.Parent then
				rigs[model] = nil
			else
				local count = 0
				for _ in pairs(rig.joints) do
					count += 1
				end
				if count < 6 then
					untrack(model)
					track(model)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- 2. UI: fonts, palette, buttons
---------------------------------------------------------------------
local PALETTE = { "1B1C22", "26314D", "4A505C", "9DA1AA", "ECEEE8", "D8B07A", "B4664E", "7A5332", "3C7D40", "7CF25A",
	"F2C433", "F0862C", "D93A33", "4C6A94", "A05CF5" }
local function lin(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end
local function oklab(c: Color3): (number, number, number)
	local r, g, b = lin(c.R), lin(c.G), lin(c.B)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end
local swatches = {}
for _, hex in ipairs(PALETTE) do
	local col = Color3.fromHex(hex)
	local l, a, b = oklab(col)
	table.insert(swatches, { col, l, a, b })
end
local cache: { [string]: Color3 } = {}
local function nearest(c: Color3): Color3
	local key = c:ToHex()
	if cache[key] then
		return cache[key]
	end
	local l, a, b = oklab(c)
	local best, bestD = swatches[1][1], math.huge
	for _, s in ipairs(swatches) do
		local d = (l - s[2]) ^ 2 + 1.6 * ((a - s[3]) ^ 2 + (b - s[4]) ^ 2)
		if d < bestD then
			best, bestD = s[1], d
		end
	end
	cache[key] = best
	return best
end

local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"

local function fixFont(g: TextLabel | TextButton | TextBox)
	local face = g.FontFace
	if face.Family ~= FREDOKA and face.Family ~= GOTHAM then
		local weight = face.Weight
		if weight.Value < Enum.FontWeight.Bold.Value then
			weight = Enum.FontWeight.Bold
		end
		g.FontFace = Font.new(GOTHAM, weight, face.Style)
	end
end

local click: Sound? = nil
local function clickSound(): Sound
	if click and click.Parent then
		return click
	end
	local s = Instance.new("Sound")
	s.Name = "ZT_Click"
	s.SoundId = "rbxassetid://119377051797825" -- our sfx pack, region "tick"
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(31.3124, 31.52)
	s.Volume = 0.35
	s.PlaybackSpeed = 1.35
	s.Parent = SoundService
	click = s
	return s
end

local SPRING = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function juice(button: GuiButton)
	if button:GetAttribute("ZT_Juice") or button:FindFirstChildOfClass("UIScale") then
		return
	end
	button:SetAttribute("ZT_Juice", true)
	local scale = Instance.new("UIScale")
	scale.Name = "ZT_Press"
	scale.Parent = button
	local over = false
	button.MouseEnter:Connect(function()
		over = true
		TweenService:Create(scale, HOVER, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		over = false
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.92 }):Play()
		local s = clickSound()
		s.TimePosition = s.PlaybackRegion.Min
		s:Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, SPRING, { Scale = if over then 1.05 else 1 }):Play()
	end)
	button.Activated:Connect(function()
		TweenService:Create(scale, SPRING, { Scale = if over then 1.05 else 1 }):Play()
	end)
end

local function paint(g: Instance)
	if g:GetAttribute("ZT_KeepColor") then
		return
	end
	if g:IsA("GuiObject") then
		g.BackgroundColor3 = nearest(g.BackgroundColor3)
		if g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox") then
			g.TextColor3 = nearest(g.TextColor3)
			g.TextStrokeColor3 = nearest(g.TextStrokeColor3)
			fixFont(g)
		end
		if g:IsA("GuiButton") then
			juice(g)
		end
	elseif g:IsA("UIStroke") then
		g.Color = nearest(g.Color)
	elseif g:IsA("UIGradient") then
		local keys = {}
		for _, kp in ipairs(g.Color.Keypoints) do
			table.insert(keys, ColorSequenceKeypoint.new(kp.Time, nearest(kp.Value)))
		end
		g.Color = ColorSequence.new(keys)
	end
end

local function dressGui(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		safely("gui", function()
			paint(d)
		end)
	end
	root.DescendantAdded:Connect(function(d)
		task.defer(function()
			if d.Parent then
				safely("gui", function()
					paint(d)
				end)
			end
		end)
	end)
end

local gui = player:WaitForChild("PlayerGui")
dressGui(gui)
-- world labels (BillboardGui / SurfaceGui on the map)
task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 120)
	if map then
		dressGui(map)
	end
end)

---------------------------------------------------------------------
-- 3. LIGHT PER LOCATION
---------------------------------------------------------------------
type Grade = { Brightness: number, Contrast: number, Saturation: number, TintColor: Color3 }
local GRADES: { [string]: Grade } = {
	city = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) },
	lobby = { Brightness = 0, Contrast = 0.04, Saturation = 0.05, TintColor = Color3.fromHex("F4FFF0") },
	settle = { Brightness = 0, Contrast = 0.05, Saturation = 0.06, TintColor = Color3.fromHex("FFE8CC") },
	cave = { Brightness = -0.04, Contrast = 0.12, Saturation = -0.1, TintColor = Color3.fromHex("D8FFE2") },
}
local zoneCC = Lighting:FindFirstChild("ZT_ZoneGrade") :: ColorCorrectionEffect?
if not zoneCC then
	local made = Instance.new("ColorCorrectionEffect")
	made.Name = "ZT_ZoneGrade"
	made.Parent = Lighting
	zoneCC = made
end
local function zoneAt(p: Vector3): string
	if p.Y > 130 then
		return "lobby"
	elseif p.Z > 286 and math.abs(p.X) < 240 then
		return "settle"
	elseif p.Z < -286 and math.abs(p.X) < 240 then
		return "cave"
	end
	return "city"
end
local current = ""
local SLOW = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
task.spawn(function()
	while true do
		task.wait(0.5)
		local zone = zoneAt(camera.CFrame.Position)
		if zone ~= current and zoneCC then
			current = zone
			workspace:SetAttribute("ZT_Zone", zone)
			TweenService:Create(zoneCC, SLOW, GRADES[zone]):Play()
		end
	end
end)

---------------------------------------------------------------------
-- 4. SOUND GROUPS + SETTINGS (music / effects / ambience volume, saved on the server)
---------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g or not g:IsA("SoundGroup") then
		local made = Instance.new("SoundGroup")
		made.Name = name
		made.Parent = SoundService
		g = made
	end
	return g :: SoundGroup
end
local GROUPS = { music = group("ZT_Music"), sfx = group("ZT_Sfx"), amb = group("ZT_Ambience") }
local MUSIC_IDS = { ["73658686799079"] = true, ["92910886797225"] = true, ["83126643280020"] = true, ["122733443114283"] = true }
local AMBIENT = { w_heli = true, w_steps = true, ZT_Steps = true }

local function classify(s: Sound)
	if s.SoundGroup then
		return
	end
	local id = s.SoundId:match("%d+") or ""
	if MUSIC_IDS[id] or s.Name:sub(1, 2) == "m_" then
		s.SoundGroup = GROUPS.music
	elseif AMBIENT[s.Name] or (s.Looped and s.Name ~= "ZT_Click") then
		s.SoundGroup = GROUPS.amb
	else
		s.SoundGroup = GROUPS.sfx
	end
end
local function watchSounds(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") then
			classify(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			task.defer(function()
				if d.Parent then
					classify(d)
				end
			end)
		end
	end)
end
for _, root in ipairs({ workspace, gui, SoundService, player :: Instance }) do
	watchSounds(root)
end

local remote = ReplicatedStorage:WaitForChild("ZT_ArtSettings", 30) :: RemoteEvent?
local vol = { music = 1, sfx = 1, amb = 1 }
local function applyVolumes()
	for key, g in pairs(GROUPS) do
		g.Volume = vol[key]
	end
end
local function readSaved()
	for key in pairs(vol) do
		local v = player:GetAttribute("ZT_Vol_" .. key)
		if type(v) == "number" then
			vol[key] = math.clamp(v, 0, 1)
		end
	end
	applyVolumes()
end
readSaved()
for key in pairs(vol) do
	player:GetAttributeChangedSignal("ZT_Vol_" .. key):Connect(readSaved)
end

-- the panel: a gear under "How to play"; three rows (icon, -, bar, +). Few words: icons do the talking.
local screen = Instance.new("ScreenGui")
screen.Name = "ZT_ArtSettings"
screen.ResetOnSpawn = false
screen.DisplayOrder = 20
screen.IgnoreGuiInset = true
screen.Parent = gui

-- where a GUI object is on the real screen (its ScreenGui may or may not skip the top bar)
local function onScreen(o: GuiObject): Vector2
	local holder = o:FindFirstAncestorWhichIsA("ScreenGui")
	local p = o.AbsolutePosition
	if holder and not holder.IgnoreGuiInset then
		p += game:GetService("GuiService"):GetGuiInset()
	end
	return p
end

local NIGHT, TOXIC, CHALK, COAL = Color3.fromHex("26314D"), Color3.fromHex("7CF25A"), Color3.fromHex("ECEEE8"), Color3.fromHex("1B1C22")
local function corner(o: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function stroke(o: Instance)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = TOXIC
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
end

local gear = Instance.new("TextButton")
gear.Name = "Gear"
gear.Text = "⚙"
gear.FontFace = Font.new(FREDOKA)
gear.TextScaled = true
gear.TextColor3 = CHALK
gear.BackgroundColor3 = NIGHT
gear.BackgroundTransparency = 0.1
gear.Size = UDim2.fromOffset(44, 44)
gear.AutoButtonColor = false
gear.Parent = screen
corner(gear, 12)
stroke(gear)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.72)
panel.BackgroundColor3 = NIGHT
panel.Visible = false
panel.Parent = screen
corner(panel, 12)
stroke(panel)
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1.5
ratio.Parent = panel
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(480, 320)
limit.Parent = panel
local pop = Instance.new("UIScale")
pop.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.fromScale(0.8, 0.18)
title.Position = UDim2.fromScale(0.06, 0.04)
title.TextXAlignment = Enum.TextXAlignment.Left
title.FontFace = Font.new(FREDOKA)
title.TextScaled = true
title.TextColor3 = CHALK
title.Text = "🔊"
title.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromScale(0.13, 0.18)
close.Position = UDim2.fromScale(0.83, 0.04)
close.BackgroundColor3 = Color3.fromHex("D93A33")
close.Text = "X"
close.FontFace = Font.new(FREDOKA)
close.TextScaled = true
close.TextColor3 = CHALK
close.Parent = panel
corner(close, 10)

local saveSoon = false
local function save()
	if saveSoon or not remote then
		return
	end
	saveSoon = true
	task.delay(1.5, function()
		saveSoon = false
		if remote then
			remote:FireServer({ music = vol.music, sfx = vol.sfx, amb = vol.amb })
		end
	end)
end

local ROWS = { { "music", "🎵" }, { "sfx", "💥" }, { "amb", "🌆" } }
for i, row in ipairs(ROWS) do
	local key, icon = row[1], row[2]
	local y = 0.27 + (i - 1) * 0.24
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.14, 0.18)
	label.Position = UDim2.fromScale(0.05, y)
	label.Text = icon
	label.TextScaled = true
	label.FontFace = Font.new(FREDOKA)
	label.TextColor3 = CHALK
	label.Parent = panel
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0.46, 0.1)
	bar.Position = UDim2.fromScale(0.34, y + 0.04)
	bar.BackgroundColor3 = COAL
	bar.Parent = panel
	corner(bar, 6)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = TOXIC
	fill.Size = UDim2.fromScale(vol[key], 1)
	fill.Parent = bar
	corner(fill, 6)
	local function button(text: string, x: number, delta: number)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromScale(0.11, 0.18)
		b.Position = UDim2.fromScale(x, y)
		b.BackgroundColor3 = COAL
		b.Text = text
		b.FontFace = Font.new(FREDOKA)
		b.TextScaled = true
		b.TextColor3 = TOXIC
		b.Parent = panel
		corner(b, 10)
		b.Activated:Connect(function()
			vol[key] = math.clamp(math.round((vol[key] + delta) * 10) / 10, 0, 1)
			TweenService:Create(fill, HOVER, { Size = UDim2.fromScale(vol[key], 1) }):Play()
			applyVolumes()
			save()
		end)
	end
	button("-", 0.2, -0.1)
	button("+", 0.83, 0.1)
	player:GetAttributeChangedSignal("ZT_Vol_" .. key):Connect(function()
		fill.Size = UDim2.fromScale(vol[key], 1)
	end)
end

local function openPanel(open: boolean)
	if open then
		panel.Visible = true
		pop.Scale = 0.9
		TweenService:Create(pop, SPRING, { Scale = 1 }):Play()
	else
		panel.Visible = false
	end
end
gear.Activated:Connect(function()
	openPanel(not panel.Visible)
end)
close.Activated:Connect(function()
	openPanel(false)
end)

-- the gear sits right under the "How to play" button and follows it
task.spawn(function()
	local guide = gui:WaitForChild("ZT_GuideGui", 30)
	local how = guide and guide:WaitForChild("HowToPlay", 30)
	local function place()
		if how and how:IsA("GuiObject") then
			local p, s = onScreen(how), how.AbsoluteSize
			local side = math.max(36, math.floor(s.Y * 1.1))
			gear.Size = UDim2.fromOffset(side, side)
			gear.Position = UDim2.fromOffset(p.X, p.Y + s.Y + 6)
			gear.Visible = how.Visible
		else
			gear.Position = UDim2.new(0, 6, 0, 120)
		end
	end
	place()
	if how and how:IsA("GuiObject") then
		how:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		how:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		how:GetPropertyChangedSignal("Visible"):Connect(place)
	end
end)

---------------------------------------------------------------------
-- 5. JUICE: the coin counter pulses and a "+N" flies out when coins come in
---------------------------------------------------------------------
task.spawn(function()
	local hud = gui:WaitForChild("ZombieTagHud", 60)
	local wallet = hud and hud:WaitForChild("Wallet", 60)
	if not wallet or not wallet:IsA("TextLabel") then
		return
	end
	local function coins(): number?
		local plain = wallet.Text:gsub("<[^>]->", "")
		local n = plain:match("(%d+)")
		return if n then tonumber(n) else nil
	end
	local last = coins()
	local scale = wallet:FindFirstChildOfClass("UIScale")
	if not scale then
		local s = Instance.new("UIScale")
		s.Name = "ZT_Pulse"
		s.Parent = wallet
		scale = s
	end
	wallet:GetPropertyChangedSignal("Text"):Connect(function()
		local now = coins()
		if now and last and now > last and scale then
			local gain = now - last
			local s = scale :: UIScale
			s.Scale = 1.18
			TweenService:Create(s, SPRING, { Scale = 1 }):Play()
			local fly = Instance.new("TextLabel")
			fly.BackgroundTransparency = 1
			fly.Text = "+" .. gain
			fly.FontFace = Font.new(FREDOKA)
			fly.TextColor3 = Color3.fromHex("F2C433")
			fly.TextStrokeTransparency = 0.2
			fly.TextStrokeColor3 = COAL
			fly.TextScaled = true
			fly.AnchorPoint = Vector2.new(0, 0.5)
			fly.Size = UDim2.fromOffset(80, 30)
			local p, sz = onScreen(wallet), wallet.AbsoluteSize
			fly.Position = UDim2.fromOffset(p.X + sz.X + 6, p.Y + sz.Y / 2)
			fly.Parent = screen
			TweenService:Create(fly, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = fly.Position + UDim2.fromOffset(10, -36), TextTransparency = 1, TextStrokeTransparency = 1,
			}):Play()
			task.delay(1, function()
				fly:Destroy()
			end)
		end
		if now then
			last = now
		end
	end)
end)

---------------------------------------------------------------------
-- 6. PHONE: fingers and small screens (audit of 27 Oct)
--  * close buttons ("X") and the small HUD buttons are at least 44 px
--  * a big panel made in pixels is scaled down to fit the screen
--  * Esc / gamepad B closes the sound panel
---------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local FINGER = 44
local CLOSE_TEXT = { X = true, ["✕"] = true, ["×"] = true, ["✖"] = true }

local function minSize(button: GuiButton, w: number, h: number)
	if button:FindFirstChild("ZT_Finger") then
		return
	end
	local c = Instance.new("UISizeConstraint")
	c.Name = "ZT_Finger"
	c.MinSize = Vector2.new(w, h)
	c.Parent = button
end

local function fitPanel(frame: Frame)
	if frame:FindFirstChild("ZT_Fit") or frame:FindFirstChildOfClass("UIScale") then
		return
	end
	local fit = Instance.new("UIScale")
	fit.Name = "ZT_Fit"
	fit.Parent = frame
	local function update()
		local view = camera.ViewportSize
		fit.Scale = 1
		local size = frame.AbsoluteSize
		local room = Vector2.new(view.X - 24, view.Y - 24)
		if size.X > 0 and size.Y > 0 then
			fit.Scale = math.min(1, room.X / size.X, room.Y / size.Y)
		end
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

local function phone(g: Instance)
	if g:IsA("TextButton") and CLOSE_TEXT[g.Text] then
		minSize(g, FINGER, FINGER)
	elseif g:IsA("Frame") and g.Parent and g.Parent:IsA("ScreenGui") and g.Size.Y.Offset >= 300 and g.Size.Y.Scale == 0 then
		task.defer(fitPanel, g) -- a panel sized in pixels (the build menu is 340 x 430)
	end
end
for _, d in ipairs(gui:GetDescendants()) do
	safely("phone", function()
		phone(d)
	end)
end
gui.DescendantAdded:Connect(function(d)
	task.defer(function()
		if d.Parent then
			safely("phone", function()
				phone(d)
			end)
		end
	end)
end)
minSize(gear, FINGER, FINGER)
task.spawn(function()
	local guide = gui:WaitForChild("ZT_GuideGui", 30)
	local how = guide and guide:WaitForChild("HowToPlay", 30)
	if how and how:IsA("GuiButton") then
		minSize(how, 96, FINGER)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if panel.Visible then
			openPanel(false)
		end
	end
end)

---------------------------------------------------------------------
-- 7. VFX: a burst of sparks where a coin / boost / shield was picked up (everyone near sees it)
---------------------------------------------------------------------
task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 120)
	local folder = map and map:WaitForChild("Pickups", 120)
	if not folder then
		return
	end
	local seen: { [Instance]: { pos: Vector3, color: Color3 } } = {}
	local function remember(item: Instance)
		local part = if item:IsA("BasePart") then item else item:FindFirstChildWhichIsA("BasePart", true)
		if part then
			seen[item] = { pos = part.Position, color = part.Color }
		end
	end
	for _, item in ipairs(folder:GetChildren()) do
		remember(item)
	end
	folder.ChildAdded:Connect(function(item)
		task.defer(remember, item)
	end)
	folder.ChildRemoved:Connect(function(item)
		local info = seen[item]
		seen[item] = nil
		if not info then
			return
		end
		-- only when somebody is right there (a pick-up), not when the round clears the street
		local near = false
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - info.pos).Magnitude < 7 then
				near = true
				break
			end
		end
		if not near or (info.pos - camera.CFrame.Position).Magnitude > 150 then
			return
		end
		local spot = Instance.new("Part")
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Transparency = 1
		spot.Size = Vector3.new(0.2, 0.2, 0.2)
		spot.Position = info.pos
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxassetid://121492703539177" -- our p_spark
		burst.Color = ColorSequence.new(info.color, Color3.fromHex("F2C433"))
		burst.LightEmission = 0.8
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		burst.Lifetime = NumberRange.new(0.35, 0.6)
		burst.Speed = NumberRange.new(8, 14)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Acceleration = Vector3.new(0, -20, 0)
		burst.Rate = 0
		burst.Parent = spot
		spot.Parent = workspace
		burst:Emit(16)
		task.delay(1, function()
			spot:Destroy()
		end)
	end)
end)