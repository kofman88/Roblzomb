--[[
	TOXIC (client part, LocalScript ZT_Toxic in StarterPlayerScripts). Only looks, only on this screen.

	- zombies: glowing toxic eyes, green drops falling from them, glowing footprints behind them;
	- the streets: a low toxic mist around the camera (only in the city, not in the lobby);
	- the final hunt: the sky turns poisonous green and the mist gets thicker.
	A zombie is a character with the Highlight "ZT_Highlight" (made by the main script);
	the last survivor has the same mark in light blue and gets nothing.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TOXIC = Color3.fromRGB(130, 255, 80)
local LOBBY_Y = 120 -- the lobby floats high above the city

local folder = Instance.new("Folder")
folder.Name = "ZT_ToxicLocal"
folder.Parent = workspace

local function ghost(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

---------------------------------------------------------------------
-- ZOMBIES
---------------------------------------------------------------------
local function isZombie(character: Model): boolean
	local glow = character:FindFirstChild("ZT_Highlight")
	if not glow or not glow:IsA("Highlight") then
		return false
	end
	local fill = glow.FillColor
	local lastSurvivor = math.abs(fill.R * 255 - 120) < 3 and math.abs(fill.G * 255 - 235) < 3 and math.abs(fill.B * 255 - 255) < 3
	return not lastSurvivor
end

type Look = { parts: { Instance }, root: BasePart, lastStep: number, left: boolean }
local looks: { [Model]: Look } = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function dress(character: Model): Look?
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return nil
	end
	local parts: { Instance } = {}
	-- the eyes (a pumpkin head has its own face: no eyes then)
	if not character:FindFirstChild("ZT_PumpkinHead", true) then
		local scale = head.Size.Y / 1.2
		for _, side in ipairs({ -1, 1 }) do
			local eye = Instance.new("Part")
			eye.Name = "ToxicEye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(0.26, 0.26, 0.26) * scale
			eye.Material = Enum.Material.Neon
			eye.Color = TOXIC
			ghost(eye)
			eye.CFrame = head.CFrame * CFrame.new(0.2 * side * scale, 0.12 * scale, -head.Size.Z / 2 + 0.02)
			eye.Parent = character
			weld(head, eye)
			table.insert(parts, eye)
		end
		local light = Instance.new("PointLight")
		light.Name = "ToxicEyeLight"
		light.Color = TOXIC
		light.Range = 7
		light.Brightness = 1.2
		light.Parent = head
		table.insert(parts, light)
	end
	-- drops falling from the body
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local point = Instance.new("Attachment")
		point.Name = "ToxicDrops"
		point.Parent = torso
		local drops = Instance.new("ParticleEmitter")
		drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drops.Color = ColorSequence.new(TOXIC)
		drops.LightEmission = 0.7
		drops.Rate = 7
		drops.Lifetime = NumberRange.new(0.6, 1)
		drops.Speed = NumberRange.new(0.5, 1.5)
		drops.SpreadAngle = Vector2.new(60, 60)
		drops.Acceleration = Vector3.new(0, -18, 0)
		drops.Size = NumberSequence.new(0.22, 0.08)
		drops.Transparency = NumberSequence.new(0.1, 0.9)
		drops.Parent = point
		table.insert(parts, point)
	end
	return { parts = parts, root = root, lastStep = 0, left = false }
end

local function undress(look: Look)
	for _, item in ipairs(look.parts) do
		if item.Parent then
			item:Destroy()
		end
	end
end

-- glowing footprints, fading behind a walking zombie
local stepsAlive = 0
local function footprint(look: Look)
	if stepsAlive > 90 then
		return
	end
	local root = look.root
	local speed = root.AssemblyLinearVelocity
	local flat = Vector3.new(speed.X, 0, speed.Z)
	if flat.Magnitude < 4 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance, folder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
	if not hit or hit.Normal.Y < 0.9 then
		return
	end
	look.left = not look.left
	local direction = flat.Unit
	local side = Vector3.new(-direction.Z, 0, direction.X) * (if look.left then 0.45 else -0.45)
	local position = hit.Position + side + Vector3.new(0, 0.03, 0)
	local step = Instance.new("Part")
	step.Name = "ToxicStep"
	step.Size = Vector3.new(0.7, 0.04, 1.1)
	step.CFrame = CFrame.lookAt(position, position + direction)
	step.Material = Enum.Material.Neon
	step.Color = TOXIC
	step.Transparency = 0.35
	ghost(step)
	step.Anchored = true
	step.Parent = folder
	stepsAlive += 1
	local fade = TweenService:Create(step, TweenInfo.new(3, Enum.EasingStyle.Linear), { Transparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		step:Destroy()
		stepsAlive -= 1
	end)
end

local function scan()
	local seen: { [Model]: boolean } = {}
	local function check(character: Instance?)
		if character and character:IsA("Model") and character:IsDescendantOf(workspace) then
			if isZombie(character) then
				seen[character] = true
				if not looks[character] then
					local look = dress(character)
					if look then
						looks[character] = look
					end
				end
			end
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		check(other.Character)
	end
	local map = workspace:FindFirstChild("ZombieTagMap")
	local bots = if map then map:FindFirstChild("Bots") else nil
	if bots then
		for _, bot in ipairs(bots:GetChildren()) do
			check(bot)
		end
	end
	for character, look in pairs(looks) do
		if not seen[character] then
			undress(look)
			looks[character] = nil
		end
	end
end

---------------------------------------------------------------------
-- MIST and the FINAL HUNT sky
---------------------------------------------------------------------
local mistBox = Instance.new("Part")
mistBox.Name = "ToxicMist"
mistBox.Size = Vector3.new(150, 1, 150)
mistBox.Transparency = 1
ghost(mistBox)
mistBox.Anchored = true
mistBox.Parent = folder
local mist = Instance.new("ParticleEmitter")
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.Color = ColorSequence.new(Color3.fromRGB(150, 200, 120))
mist.LightEmission = 0.15
mist.LightInfluence = 0.8
mist.Rate = 10
mist.Lifetime = NumberRange.new(7, 10)
mist.Speed = NumberRange.new(0.3, 0.8)
mist.SpreadAngle = Vector2.new(180, 10)
mist.Size = NumberSequence.new(9, 16)
mist.Rotation = NumberRange.new(0, 360)
mist.RotSpeed = NumberRange.new(-6, 6)
mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) })
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Parent = mistBox

local tone = Instance.new("ColorCorrectionEffect")
tone.Name = "ToxicFinal"
tone.Parent = Lighting

local finalOn = false
local function setFinal(on: boolean)
	if on == finalOn then
		return
	end
	finalOn = on
	local goal = if on
		then { TintColor = Color3.fromRGB(205, 255, 185), Saturation = 0.1, Contrast = 0.06 }
		else { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }
	TweenService:Create(tone, TweenInfo.new(2.5, Enum.EasingStyle.Sine), goal):Play()
	mist.Rate = if on then 22 else 10
	mist.Color = ColorSequence.new(if on then Color3.fromRGB(140, 230, 90) else Color3.fromRGB(150, 200, 120))
end

local groundY: number? = nil
local function findGround(): number?
	local map = workspace:FindFirstChild("ZombieTagMap")
	local city = if map then map:FindFirstChild("City") else nil
	local ground = if city then city:FindFirstChild("Ground") else nil
	if ground and ground:IsA("BasePart") then
		return ground.Position.Y + ground.Size.Y / 2
	end
	return nil
end

workspace:GetAttributeChangedSignal("ZT_Final"):Connect(function()
	setFinal(workspace:GetAttribute("ZT_Final") == true)
end)
setFinal(workspace:GetAttribute("ZT_Final") == true)

---------------------------------------------------------------------
-- LOOP
---------------------------------------------------------------------
local lastScan = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastScan > 0.5 then
		lastScan = now
		scan()
		groundY = groundY or findGround()
	end
	for _, look in pairs(looks) do
		if now - look.lastStep > 0.32 then
			look.lastStep = now
			footprint(look)
		end
	end
	local camera = workspace.CurrentCamera
	if camera and groundY then
		local at = camera.CFrame.Position
		local inCity = at.Y < LOBBY_Y
		mist.Enabled = inCity
		if inCity then
			mistBox.CFrame = CFrame.new(at.X, (groundY :: number) + 2, at.Z)
		end
	end
end)
