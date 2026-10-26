--!strict
-- ZT_CharSounds (ZOMBLOCK): takes the place of the default Roblox character sounds.
-- Our sfx pack only: footsteps (a loop region) while running on the ground, a short whoosh on a jump.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PACK = "rbxassetid://119377051797825"
local STEPS = NumberRange.new(68.8641, 72.1641)
local WHOOSH = NumberRange.new(76.0241, 76.6877)

local function make(root: BasePart, name: string, region: NumberRange, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = PACK
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = region
	if looped then
		s.LoopRegion = region
	end
	s.Looped = looped
	s.Volume = volume
	s.RollOffMaxDistance = 60
	s.RollOffMinDistance = 6
	s.Parent = root
	return s
end

-- the default Roblox character sounds script still comes with every player: stop it and take its sounds away
local DEFAULT = { Climbing = true, Died = true, FreeFalling = true, GettingUp = true, Jumping = true, Landing = true, Running = true, Splash = true, Swimming = true }
local function killDefault()
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local def = scripts and scripts:FindFirstChild("RbxCharacterSounds")
	if def and def:IsA("LocalScript") and def ~= script then
		def.Enabled = false
	end
end
local function clearDefault(root: BasePart)
	for _, s in ipairs(root:GetChildren()) do
		if s:IsA("Sound") and DEFAULT[s.Name] then
			s:Destroy()
		end
	end
	root.ChildAdded:Connect(function(s)
		if s:IsA("Sound") and DEFAULT[s.Name] then
			task.defer(function()
				s:Destroy()
			end)
		end
	end)
end
killDefault()
task.delay(3, killDefault)

local rigs: { [Model]: { steps: Sound, jump: Sound, humanoid: Humanoid, root: BasePart, air: boolean } } = {}

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	clearDefault(root)
	rigs[character] = {
		steps = make(root, "ZT_Steps", STEPS, 0.35, true),
		jump = make(root, "ZT_Jump", WHOOSH, 0.25, false),
		humanoid = humanoid, root = root, air = false,
	}
	humanoid.StateChanged:Connect(function(_, new)
		local rig = rigs[character]
		if rig and new == Enum.HumanoidStateType.Jumping then
			rig.jump.PlaybackSpeed = 1.5
			rig.jump:Play()
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end

RunService.Heartbeat:Connect(function()
	for character, rig in pairs(rigs) do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		local v = rig.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local onGround = rig.humanoid.FloorMaterial ~= Enum.Material.Air
		local run = onGround and speed > 3 and rig.humanoid.Health > 0
		if run then
			rig.steps.PlaybackSpeed = math.clamp(speed / 16, 0.7, 1.4)
			if not rig.steps.IsPlaying then
				rig.steps:Play()
			end
		elseif rig.steps.IsPlaying then
			rig.steps:Stop()
		end
	end
end)