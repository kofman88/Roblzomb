--!strict
--[[
	LOOKS (client part) - small motion on the player's own screen.
	Coins, boosts and shields turn slowly, the helicopter rotors spin.
	It changes nothing in the game itself; if it is deleted, these things just stand still.
]]
local RunService = game:GetService("RunService")

local mapFound = workspace:WaitForChild("ZombieTagMap", 120)
assert(mapFound, "[Zombie Tag] Looks: the map was not found")
local map: Instance = mapFound

local NEAR = 170 -- pickups farther than this from the camera are not turned (nobody sees it)

-- pickups: the server puts a model named LooksSpin inside every pickup
local spinning: { [BasePart]: Vector3 } = {}
-- helicopter: the server writes the place of each rotor on the body into the attribute LooksOffset
local rotors: { [BasePart]: boolean } = {}
local AXIS: { [string]: Vector3 } = { MainRotor = Vector3.new(0, 1, 0), TailRotor = Vector3.new(1, 0, 0) }
local SPEED: { [string]: number } = { MainRotor = 22, TailRotor = 30 }

local function add(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	if item.Name == "LooksSpin" then
		local owner = item.Parent
		spinning[item] = if owner and owner:IsA("BasePart") then owner.Position else item.Position
	elseif AXIS[item.Name] then
		local model = item.Parent
		if model and model.Name == "LooksHeli" then
			rotors[item] = true
		end
	end
end

map.DescendantAdded:Connect(add)
map.DescendantRemoving:Connect(function(item)
	if item:IsA("BasePart") then
		spinning[item] = nil
		rotors[item] = nil
	end
end)
for _, item in ipairs(map:GetDescendants()) do
	add(item)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for part, home in pairs(spinning) do
		if not part:IsDescendantOf(workspace) then
			spinning[part] = nil
		elseif (home - eye).Magnitude < NEAR then
			local lift = math.sin(now * 2.2 + home.X) * 0.22
			part.CFrame = CFrame.new(home.X, home.Y + lift, home.Z) * CFrame.Angles(0, now * 2.4 + home.Z, 0)
		end
	end
	for part in pairs(rotors) do
		if not part:IsDescendantOf(workspace) then
			rotors[part] = nil
		else
			local model = part.Parent
			local body = if model then model:FindFirstChild("Fuselage") else nil
			local offset = part:GetAttribute("LooksOffset")
			if body and body:IsA("BasePart") and typeof(offset) == "CFrame" then
				part.CFrame = body.CFrame * offset * CFrame.fromAxisAngle(AXIS[part.Name], now * SPEED[part.Name])
			end
		end
	end
end)
