--!strict
-- ArtBible (server): keeps the map inside the art bible.
--  * every part colour of the map -> nearest of the 15 palette colours (OKLab)
--  * rare Roblox materials -> materials of our set
--  * scale fixes (facade doors were lower than a character)
--  * mannequins lose the default "Animate" script (ZT_Art animates every character itself)
-- Characters (players, bots, mannequin bodies) keep their avatar colours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PALETTE: { [string]: string } = {
	coal = "1B1C22", night = "26314D", asphalt = "4A505C", concrete = "9DA1AA", chalk = "ECEEE8",
	stucco = "D8B07A", brick = "B4664E", wood = "7A5332", leaf = "3C7D40", toxic = "7CF25A",
	signal = "F2C433", pumpkin = "F0862C", alarm = "D93A33", glass = "4C6A94", mutant = "A05CF5",
}

-- OKLab of a colour (for "nearest colour as the eye sees it")
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

type Swatch = { key: string, color: Color3, l: number, a: number, b: number }
local swatches: { Swatch } = {}
for key, hex in pairs(PALETTE) do
	local color = Color3.fromHex(hex)
	local l, a, b = oklab(color)
	table.insert(swatches, { key = key, color = color, l = l, a = a, b = b })
end

local NEUTRAL: { [string]: boolean } = { coal = true, asphalt = true, concrete = true, chalk = true }
local cache: { [string]: Color3 } = {}
local function nearest(c: Color3): Color3
	local key = c:ToHex()
	local hit = cache[key]
	if hit then
		return hit
	end
	local l, a, b = oklab(c)
	local chroma = math.sqrt(a * a + b * b)
	local best, bestD = swatches[1].color, math.huge
	for _, s in ipairs(swatches) do
		-- chroma counts a little more than lightness: a grey wall stays grey, a red car stays red
		local d = (l - s.l) ^ 2 + 1.6 * ((a - s.a) ^ 2 + (b - s.b) ^ 2)
		-- a grey stays a grey (Coal / Asphalt / Concrete / Chalk), never turns blue or beige;
		-- "Night" navy is a UI colour: on the map only clearly blue things get it (a dark road stays Asphalt)
		if chroma < 0.03 and not NEUTRAL[s.key] then
			d += 1
		elseif s.key == "night" and chroma < 0.05 then
			d += 0.02
		end
		if d < bestD then
			best, bestD = s.color, d
		end
	end
	cache[key] = best
	return best
end

local MATERIAL_SWAP: { [Enum.Material]: Enum.Material } = {
	[Enum.Material.Marble] = Enum.Material.Concrete,
	[Enum.Material.Sand] = Enum.Material.Ground,
	[Enum.Material.Ice] = Enum.Material.Glass,
	[Enum.Material.Leather] = Enum.Material.Fabric,
	[Enum.Material.DiamondPlate] = Enum.Material.Metal,
	[Enum.Material.LeafyGrass] = Enum.Material.Grass,
	[Enum.Material.Granite] = Enum.Material.Concrete,
	[Enum.Material.Pebble] = Enum.Material.Cobblestone,
	[Enum.Material.Basalt] = Enum.Material.Slate,
	[Enum.Material.Rock] = Enum.Material.Slate,
	[Enum.Material.Limestone] = Enum.Material.Concrete,
	[Enum.Material.Mud] = Enum.Material.Ground,
	[Enum.Material.Salt] = Enum.Material.Concrete,
	[Enum.Material.Sandstone] = Enum.Material.Concrete,
	[Enum.Material.Foil] = Enum.Material.Metal,
	[Enum.Material.CorrodedMetal] = Enum.Material.Metal,
	[Enum.Material.Glacier] = Enum.Material.Glass,
	[Enum.Material.Snow] = Enum.Material.Concrete,
}

-- built-in Roblox particle textures -> our own particle images
local PARTICLE: { [string]: string } = {
	["rbxasset://textures/particles/sparkles_main.dds"] = "rbxassetid://121492703539177",
	["rbxasset://textures/particles/smoke_main.dds"] = "rbxassetid://80076731723169",
	["rbxasset://textures/particles/fire_main.dds"] = "rbxassetid://80076731723169",
}

-- a part of a character (body, hair, hats) keeps its colour; a costume worn over it does not
local function isBody(part: BasePart): boolean
	local node: Instance? = part.Parent
	while node and node ~= workspace do
		if node.Name == "ZT_Costume" then
			return false
		end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function keep(part: Instance): boolean
	local node: Instance? = part
	while node and node ~= workspace do
		if node:GetAttribute("ZT_KeepColor") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function dress(item: Instance)
	if item:IsA("BasePart") and not item:IsA("Terrain") then
		if isBody(item) or keep(item) then
			return
		end
		local swap = MATERIAL_SWAP[item.Material]
		if swap then
			item.Material = swap
			if swap == Enum.Material.Slate and item.MaterialVariant == "" then
				item.MaterialVariant = "ZH_Obsidian"
			end
		end
		if item.Material == Enum.Material.CrackedLava then
			item.Material = Enum.Material.Slate
			item.MaterialVariant = "ZH_Obsidian"
		end
		local want = nearest(item.Color)
		if want ~= item.Color then
			item.Color = want
		end
		-- performance budget (phones): light sources and small details cast no shadow
		if item.CastShadow then
			local size = item.Size
			if item.Material == Enum.Material.Neon or item.Transparency > 0.5 or math.max(size.X, size.Y, size.Z) < 1.2 then
				item.CastShadow = false
			end
		end
	elseif item:IsA("ParticleEmitter") then
		local own = PARTICLE[item.Texture]
		if own then
			item.Texture = own
		end
	elseif item:IsA("Light") then
		local want = nearest(item.Color)
		if want ~= item.Color then
			item.Color = want
		end
	elseif item:IsA("Script") and item.Name == "Animate" then
		local model = item.Parent
		if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
			item:Destroy()
		end
	end
end

-- facade doors: a doorway is 1.2 x the height of a character (was 5.3, the character is 5.5)
local DOOR_H = 6.6
local DOOR_W = 3.6
local function fixDoor(door: BasePart)
	if door:GetAttribute("ZT_Scaled") or math.abs(door.Size.Y - 5.3) > 0.05 then
		return
	end
	door:SetAttribute("ZT_Scaled", true)
	local bottom = door.Position.Y - door.Size.Y / 2
	local grow = DOOR_H - door.Size.Y
	local cf = door.CFrame
	door.Size = Vector3.new(DOOR_W, DOOR_H, door.Size.Z)
	door.CFrame = cf + Vector3.new(0, (bottom + DOOR_H / 2) - cf.Position.Y, 0)
	-- the lintel above it moves up with it
	local parent = door.Parent
	if parent then
		for _, other in ipairs(parent:GetChildren()) do
			if other:IsA("BasePart") and other.Name == "DoorTop" and not other:GetAttribute("ZT_Scaled") then
				local d = other.Position - cf.Position
				if math.abs(d.X) < 0.6 and math.abs(d.Z) < 0.6 and d.Y > 0 and d.Y < 4 then
					other:SetAttribute("ZT_Scaled", true)
					other.Size = Vector3.new(DOOR_W + 0.6, other.Size.Y, other.Size.Z)
					other.CFrame = other.CFrame + Vector3.new(0, grow, 0)
				end
			end
		end
	end
end

local function watch(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		dress(item)
	end
	root.DescendantAdded:Connect(function(item)
		task.defer(function()
			if item.Parent then
				dress(item)
			end
		end)
	end)
end

local function start(map: Instance)
	local count = 0
	for _, item in ipairs(map:GetDescendants()) do
		dress(item)
		if item:IsA("BasePart") and item.Name == "Door" then
			fixDoor(item)
		end
		count += 1
		if count % 1500 == 0 then
			task.wait()
		end
	end
	map.DescendantAdded:Connect(function(item)
		task.defer(function()
			if item.Parent then
				dress(item)
				if item:IsA("BasePart") and item.Name == "Door" then
					fixDoor(item)
				end
			end
		end)
	end)
end

task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 120)
	if map then
		task.wait(3) -- the city is built in steps: let the first pass finish
		start(map)
		-- other modules recolour things later (lit windows, events): a slow sweep brings them back
		while map.Parent do
			task.wait(12)
			local n = 0
			for _, item in ipairs(map:GetDescendants()) do
				if item:IsA("BasePart") or item:IsA("Light") then
					dress(item)
				end
				n += 1
				if n % 2500 == 0 then
					task.wait()
				end
			end
		end
	end
end)

task.spawn(function()
	local dolls = ReplicatedStorage:WaitForChild("ZT_CosDolls", 120)
	if dolls then
		watch(dolls)
	end
end)

-- costume parts on players (the model ZT_Costume is welded to the body)
local function onCharacter(character: Model)
	character.DescendantAdded:Connect(function(item)
		task.defer(function()
			if item.Parent and item:IsA("BasePart") then
				local model = item:FindFirstAncestor("ZT_Costume")
				if model then
					dress(item)
				end
			elseif item.Parent and item:IsA("ParticleEmitter") then
				dress(item)
			end
		end)
	end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacter)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

workspace:SetAttribute("ZT_ArtBible", 1)

---------------------------------------------------------------------
-- sound settings: the client sends three volumes, we keep them in a DataStore and give them back as attributes
---------------------------------------------------------------------
local DataStoreService = game:GetService("DataStoreService")
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("ZT_Settings_v1")
end)
local remote = ReplicatedStorage:FindFirstChild("ZT_ArtSettings")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "ZT_ArtSettings"
	remote.Parent = ReplicatedStorage
end
local KEYS = { "music", "sfx", "amb" }
local lastSave: { [Player]: number } = {}

local function apply(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	for _, key in ipairs(KEYS) do
		local v = data[key]
		if type(v) == "number" and v == v then
			player:SetAttribute("ZT_Vol_" .. key, math.clamp(math.round(v * 10) / 10, 0, 1))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	if okStore and store then
		local ok, data = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok then
			apply(player, data)
		end
	end
end)

local settingsEvent = remote :: RemoteEvent
settingsEvent.OnServerEvent:Connect(function(player, data)
	apply(player, data)
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < 6 then
		return -- the next change saves; attributes already hold the values
	end
	lastSave[player] = now
	if okStore and store then
		local values = {}
		for _, key in ipairs(KEYS) do
			values[key] = player:GetAttribute("ZT_Vol_" .. key)
		end
		task.spawn(function()
			pcall(function()
				store:SetAsync("u" .. player.UserId, values)
			end)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if okStore and store and lastSave[player] then
		local values = {}
		for _, key in ipairs(KEYS) do
			values[key] = player:GetAttribute("ZT_Vol_" .. key)
		end
		pcall(function()
			store:SetAsync("u" .. player.UserId, values)
		end)
	end
	lastSave[player] = nil
end)
