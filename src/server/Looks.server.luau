--!strict
--[[
	LOOKS - the graphics layer of "Zombie Tag: Infection City".

	This script only changes how the game LOOKS. It never changes the rules:
	- everything it adds goes into the folder ZombieTagMap.Decor and cannot be touched,
	  stood on or seen by the game logic (no collisions, no queries, no touch events);
	- original parts keep their size, place and collisions; some of them only become
	  invisible because a nicer model stands in the same place;
	- if this script is deleted, the game works exactly as before.

	What it does: light and sky for day / sunset / night and for round events, better
	materials, details on buildings, models of trees, bushes, cars, lamps, benches,
	the helicopter and the pickups, particles, a skyline behind the wall.

	Models live in ServerStorage.ZT_Assets, materials in MaterialService.
	Switches are in the table ON below.
]]

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")

local ON = {
	light = true,     -- sky, sun, colours, glow
	materials = true, -- walls, roads, roofs
	facades = true,   -- details on buildings
	nature = true,    -- trees and bushes
	vehicles = true,  -- cars, buses, the tanker
	street = true,    -- lamps, benches, crates, fountains, street furniture
	skyline = true,   -- far buildings behind the wall
	pickups = true,   -- coins, boosts, shields
	heli = true,      -- the helicopter
	effects = true,   -- particles
	lobby = true,     -- the lobby
}

local rgb = Color3.fromRGB
local rng = Random.new(74)

local function safely(name: string, action: () -> ())
	local ok, err = pcall(action :: () -> any)
	if not ok then
		warn("[Zombie Tag] Looks: " .. name .. ": " .. tostring(err))
	end
end

local mapFound = workspace:WaitForChild("ZombieTagMap", 120)
assert(mapFound, "[Zombie Tag] Looks: the map was not found, graphics are off")
local map: Instance = mapFound
local city: Instance = map:WaitForChild("City")
local lobby: Instance = map:WaitForChild("Lobby")
local bushes: Instance = map:WaitForChild("Bushes")
local pickupFolder: Instance = map:WaitForChild("Pickups")
local botFolder: Instance = map:WaitForChild("Bots")

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = map

local assets: Instance? = ServerStorage:FindFirstChild("ZT_Assets")

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local made = 0
-- a pause now and then, so that building the decorations never freezes the server
local function breathe()
	made += 1
	if made % 250 == 0 then
		task.wait()
	end
end

-- a decoration never collides, is never hit by rays and never fires touch events
local function ghost(part: BasePart, shadow: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = shadow
	part.Massless = true
end

local function variantOf(material: Enum.Material, name: string): string
	if name == "" then
		return ""
	end
	local ok, found = pcall(function()
		return MaterialService:GetMaterialVariant(material, name)
	end)
	return if ok and found then name else ""
end

local function box(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, variant: string?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if variant and variant ~= "" then
		part.MaterialVariant = variantOf(material, variant)
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	ghost(part, false)
	part.Parent = decor
	breathe()
	return part
end

local function shade(color: Color3, k: number): Color3
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

local function template(key: string): MeshPart?
	local found = if assets then assets:FindFirstChild(key) else nil
	return if found and found:IsA("MeshPart") then found else nil
end

-- a copy of a model from ZT_Assets, stretched to the given size
local function mesh(key: string, size: Vector3, cframe: CFrame, shadow: boolean, parent: Instance?, name: string?): MeshPart?
	local source = template(key)
	if not source then
		return nil
	end
	local part = source:Clone()
	part.Name = name or key
	part.Size = size
	part.CFrame = cframe
	ghost(part, shadow)
	part.Parent = parent or decor
	if not parent then
		breathe() -- only while the city is being dressed, never inside an event
	end
	return part
end

-- the original stays where it is (the game logic needs it) but is not drawn any more
local function hide(part: BasePart)
	part.CastShadow = false
	if part.CanCollide and part.ClassName == "Part" then
		-- the camera of a player stops only at parts that are not transparent:
		-- an empty shape draws nothing, and the camera still cannot look through a bus
		local none = Instance.new("BlockMesh")
		none.Name = "LooksNone"
		none.Scale = Vector3.zero
		none.Parent = part
	else
		part.Transparency = 1
	end
end

local function named(parent: Instance, name: string): { BasePart }
	local list: { BasePart } = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function key2(x: number, z: number): string
	return math.floor(x * 2 + 0.5) .. ":" .. math.floor(z * 2 + 0.5)
end

-- gives a part a material; true if the generated texture was found and put on
local function skin(part: BasePart, material: Enum.Material, variant: string?): boolean
	part.Material = material
	part.MaterialVariant = if variant then variantOf(material, variant) else ""
	return part.MaterialVariant ~= ""
end

-- a small fountain of sparks (or smoke, or water) on a part
local function spray(parent: BasePart, offset: Vector3, color: Color3, rate: number, speed: number, life: number, spread: number, size: number): ParticleEmitter
	local point = Instance.new("Attachment")
	point.Name = "LooksPoint"
	point.Position = offset
	point.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LooksSpray"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(speed * 0.7, speed)
	emitter.Lifetime = NumberRange.new(life * 0.7, life)
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Size = NumberSequence.new(size, size * 0.3)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.LightEmission = 0.6
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = point
	return emitter
end

---------------------------------------------------------------------
-- LIGHT AND SKY
-- The main script sets the time of day (clock, brightness, two ambient colours) and the
-- fog. This part reads them, decides what moment it is and dresses the picture for it.
---------------------------------------------------------------------
type Props = { [string]: any }
type Look = { sun: Props, color: Props, bloom: Props, rays: Props, air: Props, clouds: Props, lamp: number, lampRange: number, windows: string }

local LOOKS: { [string]: Look } = {
	day = {
		sun = { ClockTime = 14.3, ColorShift_Top = rgb(255, 246, 230), ExposureCompensation = 0.05, ShadowSoftness = 0.12 },
		color = { Brightness = 0.01, Contrast = 0.12, Saturation = 0.12, TintColor = rgb(246, 255, 236) },
		bloom = { Intensity = 0.4, Size = 24, Threshold = 1.8 },
		rays = { Intensity = 0.07, Spread = 0.6 },
		air = { Density = 0.3, Haze = 1.3, Glare = 0.3, Offset = 0.15, Color = rgb(204, 224, 176), Decay = rgb(118, 150, 92) },
		clouds = { Cover = 0.6, Density = 0.45, Color = rgb(226, 240, 206) },
		lamp = 0, lampRange = 30, windows = "day",
	},
	sunset = {
		sun = { ClockTime = 17.2, ColorShift_Top = rgb(255, 190, 130), ExposureCompensation = 0.15, ShadowSoftness = 0.2 },
		color = { Brightness = 0, Contrast = 0.14, Saturation = 0.15, TintColor = rgb(250, 255, 222) },
		bloom = { Intensity = 0.55, Size = 28, Threshold = 1.5 },
		rays = { Intensity = 0.14, Spread = 0.8 },
		air = { Density = 0.32, Haze = 1.8, Glare = 0.5, Offset = 0.2, Color = rgb(232, 230, 150), Decay = rgb(150, 170, 70) },
		clouds = { Cover = 0.62, Density = 0.5, Color = rgb(222, 236, 170) },
		lamp = 1.3, lampRange = 38, windows = "lit",
	},
	night = {
		sun = { ColorShift_Top = rgb(170, 190, 255), ExposureCompensation = 0, ShadowSoftness = 0.3 },
		color = { Brightness = -0.02, Contrast = 0.18, Saturation = 0, TintColor = rgb(200, 236, 222) },
		bloom = { Intensity = 0.7, Size = 30, Threshold = 1.2 },
		rays = { Intensity = 0, Spread = 0.5 },
		air = { Density = 0.33, Haze = 2.3, Glare = 0, Offset = 0.3, Color = rgb(56, 120, 96), Decay = rgb(26, 70, 52) },
		clouds = { Cover = 0.5, Density = 0.45, Color = rgb(96, 140, 110) },
		lamp = 2.2, lampRange = 46, windows = "lit",
	},
	-- the "blackout" round event: the main script makes it dark; nothing here makes it lighter or darker
	dark = {
		sun = { ColorShift_Top = rgb(150, 160, 200), ExposureCompensation = 0, ShadowSoftness = 0.3 },
		color = { Brightness = 0, Contrast = 0.1, Saturation = -0.15, TintColor = rgb(205, 212, 255) },
		bloom = { Intensity = 0.7, Size = 30, Threshold = 1.2 },
		rays = { Intensity = 0, Spread = 0.5 },
		air = { Density = 0.3, Haze = 1.8, Glare = 0, Offset = 0.2, Color = rgb(70, 86, 150), Decay = rgb(36, 46, 96) },
		clouds = { Cover = 0.7, Density = 0.6, Color = rgb(40, 44, 60) },
		lamp = 2.2, lampRange = 46, windows = "lit",
	},
}
local GLOW_WIDE, GLOW_HIGH, GLOW_CLEAR = 0.92, 0.79, 0.55 -- the glow of a street lamp: width (of the lamp), height (of the lamp), how clear
local LATITUDE = 38 -- the sun is lower in the sky, so there are shadows on the streets

local litWindows: { BasePart } = {}  -- window parts that glow in the evening
local nightOnly: { ParticleEmitter } = {} -- fireflies: only when it is dark
local lampGlows: { [PointLight]: BasePart } = {}
local lampLights: { PointLight } = {}

local function findOrMake(parent: Instance, class: string, name: string): Instance
	local found = parent:FindFirstChild(name)
	if not found or not found:IsA(class) then
		found = parent:FindFirstChildOfClass(class)
	end
	if not found then
		local created = Instance.new(class)
		created.Parent = parent
		found = created
	end
	local result = found :: Instance
	result.Name = name
	return result
end

local function put(target: Instance, props: Props)
	local object: any = target
	for name, value in pairs(props) do
		if object[name] ~= value then
			object[name] = value
		end
	end
end

local WINDOW_LIT = rgb(215, 175, 100)
local function setWindows(mode: string)
	for _, part in ipairs(litWindows) do
		if part.Parent then
			if mode == "lit" then
				part.Material = Enum.Material.Neon
				local own = part:GetAttribute("LooksLit")
				part.Color = if typeof(own) == "Color3" then own else WINDOW_LIT
				part.Reflectance = 0
			elseif mode == "day" then
				-- by day a window with the light on is just a window, a little lighter than the others
				part.Material = Enum.Material.Glass
				part.Color = rgb(72, 92, 124)
				part.Reflectance = 0
			else
				part.Material = Enum.Material.Glass
				part.Color = rgb(28, 34, 48)
				part.Reflectance = 0
			end
		end
	end
end

local lightBusy = false
local lastWindows = ""
local function refreshLight()
	if lightBusy then
		return
	end
	lightBusy = true
	safely("light", function()
		local clock = Lighting.ClockTime
		local phase = "day"
		if Lighting.Brightness <= 0.35 then
			phase = "dark"
		elseif clock < 2 or clock > 22 then
			phase = "night"
		elseif clock >= 16 then
			phase = "sunset"
		end
		local look = LOOKS[phase]
		local air = findOrMake(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
		local foggy = air.Density >= 0.6 -- the "fog" round event: the main script made the air thick
		Lighting.GeographicLatitude = LATITUDE
		put(Lighting, look.sun)
		local color = table.clone(look.color)
		local bloom = table.clone(look.bloom)
		-- round events colour the picture a little (the main script tells which event runs)
		local event = workspace:GetAttribute("ZT_Event")
		if foggy then
			color.Saturation = -0.3
			color.TintColor = rgb(225, 240, 225)
		elseif event == "gold" then
			color.TintColor = rgb(255, 236, 190)
			color.Saturation = (color.Saturation :: number) + 0.1
			bloom.Intensity = (bloom.Intensity :: number) + 0.15
		elseif event == "rage" then
			color.TintColor = rgb(255, 216, 212)
			color.Contrast = (color.Contrast :: number) + 0.06
		elseif event == "moon" then
			color.TintColor = rgb(214, 220, 255)
		end
		if workspace:GetAttribute("ZT_Final") == true and not foggy then
			color.Contrast = (color.Contrast :: number) + 0.05
		end
		put(findOrMake(Lighting, "ColorCorrectionEffect", "LooksColor"), color)
		put(findOrMake(Lighting, "BloomEffect", "Bloom"), bloom)
		put(findOrMake(Lighting, "SunRaysEffect", "SunRays"), look.rays)
		if foggy then
			put(air, { Glare = 0, Offset = 0, Color = rgb(150, 170, 150), Decay = rgb(70, 90, 70) })
		else
			put(air, look.air)
		end
		put(findOrMake(workspace.Terrain, "Clouds", "Clouds"), look.clouds)
		for _, light in ipairs(lampLights) do
			if light.Parent then
				light.Brightness = look.lamp
				light.Range = look.lampRange
			end
		end
		for light, glow in pairs(lampGlows) do
			local on = light.Enabled and look.lamp > 0
			glow.Transparency = if on then GLOW_CLEAR else 1
		end
		if look.windows ~= lastWindows then
			lastWindows = look.windows
			setWindows(look.windows)
		end
		local darkNow = phase == "night" or phase == "dark"
		for _, emitter in ipairs(nightOnly) do
			if emitter.Enabled ~= darkNow then
				emitter.Enabled = darkNow
			end
		end
	end)
	lightBusy = false
end

local lightPending = false
local function lightSoon()
	if not lightPending and ON.light then
		lightPending = true
		task.defer(function()
			lightPending = false
			refreshLight()
		end)
	end
end

local function startLight()
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = 4500
		sky.SunAngularSize = 13
		sky.MoonAngularSize = 9
	end
	local blur = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if blur then
		blur.Enabled = false -- far things must stay sharp: players look for zombies
	end
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(lightSoon)
	Lighting:GetPropertyChangedSignal("Brightness"):Connect(lightSoon)
	local air = findOrMake(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	air:GetPropertyChangedSignal("Density"):Connect(lightSoon)
	workspace:GetAttributeChangedSignal("ZT_Event"):Connect(lightSoon)
	workspace:GetAttributeChangedSignal("ZT_Final"):Connect(lightSoon)
	refreshLight()
end

---------------------------------------------------------------------
-- MATERIALS of the original parts (the game logic never looks at them)
---------------------------------------------------------------------
local function dressMaterials()
	local metalNames = { Container = true, ShedWall = true, ShedRoof = true, WagonWall = true, WagonRoof = true, TunnelWall = true, TunnelRoof = true, Dumpster = true }
	for _, child in ipairs(city:GetChildren()) do
		if child:IsA("BasePart") then
			local name = child.Name
			if name == "Sidewalk" then
				if skin(child, Enum.Material.Pavement, "ZT_Tiles1") then
					child.Color = rgb(205, 205, 210)
				end
			elseif name == "Tower" or name == "LowHouse" or name == "House" or name == "Shop" or name == "School" then
				local material = if child.Material == Enum.Material.Brick then Enum.Material.Brick else Enum.Material.Concrete
				if skin(child, material, if material == Enum.Material.Brick then "ZT_Brick" else "ZT_Concrete") then
					child.Color = shade(child.Color, 1.5)
				end
			elseif name == "GasShop" or name == "Hospital" or name == "MallWall" then
				if skin(child, Enum.Material.Concrete, "ZT_Concrete1") then
					child.Color = shade(child.Color, 1.12)
				end
			elseif name == "QuarantineWall" then
				if skin(child, Enum.Material.Concrete, "ZT_Concrete") then
					child.Color = shade(child.Color, 1.4)
				end
			elseif metalNames[name] then
				if skin(child, Enum.Material.Metal, "ZT_Corrugated") then
					child.Color = shade(child.Color, 1.35)
				end
			elseif name == "Windows" then
				if child.Material == Enum.Material.Neon then
					table.insert(litWindows, child)
				end
			elseif name == "Grass" then
				child.Material = Enum.Material.LeafyGrass
			elseif name == "Ground" then
				-- the asphalt texture is multiplied by the part colour: a lighter colour shows the cracks
				if skin(child, Enum.Material.Asphalt, "ZT_Gravel1") then
					child.Color = rgb(118, 120, 126)
				end
			elseif name == "Pilaster" then
				if skin(child, Enum.Material.Concrete, "ZT_Concrete1") then
					child.Color = shade(child.Color, 1.45)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- BUILDINGS: a base, ledges under the windows, a roof, shop windows, doors
---------------------------------------------------------------------
local SHOP_LIGHTS = { rgb(127, 95, 53), rgb(127, 95, 53), rgb(134, 108, 69), rgb(92, 108, 131), rgb(128, 78, 101), rgb(69, 115, 108) }
local AWNINGS = { rgb(196, 62, 58), rgb(58, 112, 190), rgb(232, 180, 62), rgb(66, 150, 108), rgb(226, 226, 230), rgb(150, 92, 170) }
local BODY_NAMES = { "Tower", "LowHouse", "House", "Shop", "School", "GasShop", "Hospital" }

-- places on a wall between the wall strips ("pilasters") of the main script
local function slots(length: number): (number, number)
	local count = math.max(2, math.floor(length / 7 + 0.5))
	return count, length / count
end

local function dressBuilding(body: BasePart, bands: { BasePart })
	local size = body.Size
	local centre = body.Position
	local base = centre.Y - size.Y / 2
	local roof = centre.Y + size.Y / 2
	local color = body.Color
	local kind = body.Name
	-- the base and the roof
	box("Plinth", Vector3.new(size.X + 1, 1, size.Z + 1), CFrame.new(centre.X, base + 0.5, centre.Z), shade(color, 0.55), Enum.Material.Concrete, "ZT_Concrete1")
	if kind ~= "Tower" then
		box("Cornice", Vector3.new(size.X + 1.1, 0.7, size.Z + 1.1), CFrame.new(centre.X, roof - 0.33, centre.Z), shade(color, 0.6), Enum.Material.Concrete, "ZT_Concrete1")
	end
	box("RoofTop", Vector3.new(size.X - 0.1, 0.08, size.Z - 0.1), CFrame.new(centre.X, roof + 0.04, centre.Z), rgb(150, 152, 158), Enum.Material.Asphalt, "ZT_Gravel1")
	-- a ledge under every row of windows, and windows that differ from each other
	local countX, stepX = slots(size.X)
	local countZ, stepZ = slots(size.Z)
	for _, band in ipairs(bands) do
		local y = band.Position.Y
		local high = band.Size.Y
		box("Ledge", Vector3.new(size.X + 1, 0.3, size.Z + 1), CFrame.new(centre.X, y - high / 2 - 0.15, centre.Z), shade(color, 0.7), Enum.Material.Concrete, "ZT_Concrete1")
		local lit = band.Material == Enum.Material.Neon
		local function pane(position: Vector3, wide: number, alongX: boolean)
			local roll = rng:NextNumber()
			local paneSize = if alongX then Vector3.new(wide, high, 0.1) else Vector3.new(0.1, high, wide)
			if lit and roll < 0.28 then
				box("Pane", paneSize, CFrame.new(position), rgb(40, 55, 80), Enum.Material.Glass)
			elseif not lit and roll < 0.2 then
				local glow = if roll < 0.05 then rgb(150, 190, 255) else WINDOW_LIT
				local part = box("Pane", paneSize, CFrame.new(position), glow, Enum.Material.Neon)
				part:SetAttribute("LooksLit", glow)
				table.insert(litWindows, part)
			end
		end
		for i = 0, countX - 1 do
			local x = centre.X - size.X / 2 + stepX * (i + 0.5)
			pane(Vector3.new(x, y, centre.Z - size.Z / 2 - 0.2), stepX - 1.8, true)
			pane(Vector3.new(x, y, centre.Z + size.Z / 2 + 0.2), stepX - 1.8, true)
		end
		for i = 0, countZ - 1 do
			local z = centre.Z - size.Z / 2 + stepZ * (i + 0.5)
			pane(Vector3.new(centre.X - size.X / 2 - 0.2, y, z), stepZ - 1.8, false)
			pane(Vector3.new(centre.X + size.X / 2 + 0.2, y, z), stepZ - 1.8, false)
		end
	end
	-- towers: shop windows, awnings and doors on the ground floor (the first windows start 6.5 studs up)
	if kind == "Tower" then
		local awning = AWNINGS[rng:NextInteger(1, #AWNINGS)]
		local shopLight = SHOP_LIGHTS[rng:NextInteger(1, #SHOP_LIGHTS)]
		local frame = shade(color, 0.45)
		local function front(position: Vector3, wide: number, normal: Vector3, door: boolean)
			local turn = CFrame.lookAt(position, position + normal) -- the part's -Z looks away from the wall
			if door then
				box("Door", Vector3.new(3, 5.3, 0.16), turn * CFrame.new(0, -0.85, 0), rgb(62, 46, 38), Enum.Material.Wood)
				box("DoorTop", Vector3.new(3.6, 0.35, 0.3), turn * CFrame.new(0, 2, 0), frame, Enum.Material.Metal)
				box("DoorGlass", Vector3.new(1.6, 1.6, 0.2), turn * CFrame.new(0, 0.5, 0), rgb(40, 55, 80), Enum.Material.Glass)
			else
				local shop = box("ShopWindow", Vector3.new(wide - 0.5, 3.6, 0.12), turn, rgb(46, 62, 88), Enum.Material.Glass)
				if rng:NextNumber() < 0.55 then
					shop:SetAttribute("LooksLit", shopLight)
					table.insert(litWindows, shop)
				end
				box("ShopSill", Vector3.new(wide - 0.2, 0.3, 0.4), turn * CFrame.new(0, -1.95, -0.05), frame, Enum.Material.Concrete)
				if rng:NextNumber() < 0.6 then
					box("Awning", Vector3.new(wide + 0.3, 0.2, 2.2), turn * CFrame.new(0, 2.5, -0.95) * CFrame.Angles(math.rad(-22), 0, 0), awning, Enum.Material.Fabric)
				end
			end
		end
		local doorX, doorZ = rng:NextInteger(0, countX - 1), rng:NextInteger(0, countZ - 1)
		for i = 0, countX - 1 do
			local x = centre.X - size.X / 2 + stepX * (i + 0.5)
			front(Vector3.new(x, base + 4.5, centre.Z - size.Z / 2 - 0.05), stepX - 1.8, Vector3.new(0, 0, -1), i == doorX)
			front(Vector3.new(x, base + 4.5, centre.Z + size.Z / 2 + 0.05), stepX - 1.8, Vector3.new(0, 0, 1), i == doorX)
		end
		for i = 0, countZ - 1 do
			local z = centre.Z - size.Z / 2 + stepZ * (i + 0.5)
			front(Vector3.new(centre.X - size.X / 2 - 0.05, base + 4.5, z), stepZ - 1.8, Vector3.new(-1, 0, 0), i == doorZ)
			-- the ladder of a tower stands on this wall at z + 8: that place stays empty
			if math.abs(z - (centre.Z + 8)) > stepZ / 2 + 1 then
				front(Vector3.new(centre.X + size.X / 2 + 0.05, base + 4.5, z), stepZ - 1.8, Vector3.new(1, 0, 0), false)
			end
		end
	end
end

local function dressBuildings()
	local bandsAt: { [string]: { BasePart } } = {}
	for _, band in ipairs(named(city, "Windows")) do
		if band.Size.X > 2 and band.Size.Z > 2 then -- (the thin ones are train windows)
			local id = key2(band.Position.X, band.Position.Z)
			bandsAt[id] = bandsAt[id] or {}
			table.insert(bandsAt[id], band)
		end
	end
	for _, name in ipairs(BODY_NAMES) do
		for _, body in ipairs(named(city, name)) do
			dressBuilding(body, bandsAt[key2(body.Position.X, body.Position.Z)] or {})
		end
	end
	-- an antenna on the bigger roof boxes, a little smoke over some of the others
	for _, roofBox in ipairs(named(city, "RoofBox")) do
		if ON.effects and roofBox.Size.Y < 4 and rng:NextNumber() < 0.3 then
			local smoke = spray(roofBox, Vector3.new(0, roofBox.Size.Y / 2, 0), rgb(205, 208, 214), 2.5, 3, 5, 8, 1.4)
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.Size = NumberSequence.new(1.4, 5.5)
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.72), NumberSequenceKeypoint.new(1, 1) })
			smoke.LightEmission = 0
			smoke.LightInfluence = 1
			smoke.Acceleration = Vector3.new(0.6, 0.4, 0.3)
			smoke.Rotation = NumberRange.new(0, 360)
			smoke.RotSpeed = NumberRange.new(-20, 20)
		end
		if roofBox.Size.Y >= 4 and rng:NextNumber() < 0.6 then
			local top = roofBox.Position + Vector3.new(0, roofBox.Size.Y / 2, 0)
			box("Antenna", Vector3.new(0.25, 7, 0.25), CFrame.new(top + Vector3.new(0, 3.5, 0)), rgb(60, 62, 68), Enum.Material.Metal)
			box("Antenna", Vector3.new(2.4, 0.2, 0.2), CFrame.new(top + Vector3.new(0, 5.6, 0)), rgb(60, 62, 68), Enum.Material.Metal)
			box("Antenna", Vector3.new(1.6, 0.2, 0.2), CFrame.new(top + Vector3.new(0, 6.5, 0)), rgb(60, 62, 68), Enum.Material.Metal)
		end
	end
end

---------------------------------------------------------------------
-- TREES AND BUSHES
---------------------------------------------------------------------
local LEAF_TINTS = { rgb(255, 255, 255), rgb(214, 240, 204), rgb(236, 238, 190), rgb(200, 226, 212), rgb(226, 248, 214) }
local BUSH_TINTS = { rgb(128, 168, 112), rgb(146, 176, 104), rgb(112, 158, 124), rgb(136, 182, 128) }
-- every tree and bush gets its own shade of green (models with a "Tint" inside can be coloured)
local function tint(part: MeshPart?, tints: { Color3 })
	local paint = if part then part:FindFirstChildOfClass("SurfaceAppearance") else nil
	if paint then
		local color = tints[rng:NextInteger(1, #tints)]
		pcall(function()
			paint.Color = color
		end)
	end
end

local function dressNature()
	local crowns: { [string]: BasePart } = {}
	for _, crown in ipairs(named(city, "Leaves")) do
		crowns[key2(crown.Position.X, crown.Position.Z)] = crown
	end
	for _, trunk in ipairs(named(city, "Trunk")) do
		local key = if rng:NextNumber() < 0.6 then "Tree1" else "Tree2"
		local source = template(key)
		if source then
			local total = trunk.Size.Y + 8.5 -- the trunk plus the old ball of leaves
			local scale = total / source.Size.Y * rng:NextNumber(0.97, 1.08)
			local base = trunk.Position.Y - trunk.Size.Y / 2
			local size = source.Size * scale
			local placed = mesh(key, size, CFrame.new(trunk.Position.X, base + size.Y / 2, trunk.Position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), true)
			if placed then
				tint(placed, LEAF_TINTS)
				if ON.effects and rng:NextNumber() < 0.4 then
					local flies = spray(placed, Vector3.new(0, -size.Y * 0.2, 0), rgb(214, 255, 140), 1.6, 0.8, 5, 180, 0.32)
					local point = flies.Parent
					flies.Parent = placed -- from the whole tree, not from one point
					if point then
						point:Destroy()
					end
					flies.Size = NumberSequence.new(0.32)
					flies.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
					flies.LightEmission = 1
					flies.Enabled = false
					table.insert(nightOnly, flies)
				end
				hide(trunk)
				local crown = crowns[key2(trunk.Position.X, trunk.Position.Z)]
				if crown then
					hide(crown)
				end
			end
		end
	end
	-- a bush of the main script is four balls in a row of children: the first one is its middle
	local source = template("Bush")
	if source then
		local balls = named(bushes, "Bush")
		for index = 1, #balls - 3, 4 do
			local first = balls[index]
			local ground = first.Position.Y - 2.9
			local size = Vector3.new(12, 8.6, 11.6)
			local turn = if rng:NextNumber() < 0.5 then 0 else math.pi
			local placed = mesh("Bush", size, CFrame.new(first.Position.X + 0.1, ground + size.Y / 2 - 0.9, first.Position.Z - 0.4) * CFrame.Angles(0, turn, 0), false)
			if placed then
				tint(placed, BUSH_TINTS)
				for offset = 0, 3 do
					hide(balls[index + offset])
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- CARS, BUSES, THE TANKER
---------------------------------------------------------------------
local CAR_KEYS = {
	{ color = rgb(200, 50, 50), key = "CarRed" },
	{ color = rgb(50, 100, 200), key = "CarBlue" },
	{ color = rgb(230, 230, 235), key = "CarPolice" },
	{ color = rgb(240, 190, 40), key = "CarTaxi" },
	{ color = rgb(40, 45, 50), key = "CarBlack" },
}

local function nearestCar(color: Color3): string
	local best, bestDistance = "CarRed", math.huge
	for _, entry in ipairs(CAR_KEYS) do
		local d = math.abs(entry.color.R - color.R) + math.abs(entry.color.G - color.G) + math.abs(entry.color.B - color.B)
		if d < bestDistance and template(entry.key) then
			best, bestDistance = entry.key, d
		end
	end
	return best
end

-- a long model stands along the longer side of the original box; its own long side is Z.
-- It keeps its proportions (so the wheels stay round) and is made as long as "length".
local function vehicle(key: string, body: BasePart, bottom: number, length: number, maxHeight: number, others: { BasePart? }, fill: boolean)
	local source = template(key)
	if not source then
		return
	end
	local alongX = body.Size.X > body.Size.Z
	local long = if alongX then body.Size.X else body.Size.Z
	local short = if alongX then body.Size.Z else body.Size.X
	if fill then
		length = long - 0.2
	end
	local size = source.Size * (length / source.Size.Z)
	if size.Y > maxHeight then
		size = Vector3.new(size.X, maxHeight, size.Z)
	end
	if fill then
		size = Vector3.new(math.clamp(size.X, short, short + 0.6), size.Y, size.Z)
	end
	local turn = (if alongX then math.pi / 2 else 0) + (if rng:NextNumber() < 0.5 then math.pi else 0)
	local placed = mesh(key, size, CFrame.new(body.Position.X, bottom + size.Y / 2, body.Position.Z) * CFrame.Angles(0, turn, 0), true)
	if placed then
		hide(body)
		for _, other in pairs(others) do
			if other then
				hide(other)
			end
		end
	end
end

local function dressVehicles()
	local at: { [string]: { [string]: BasePart } } = {}
	for _, name in ipairs({ "CarCabin", "CarWheels", "BusWindows", "BusWheels", "TankerWheels" }) do
		for _, part in ipairs(named(city, name)) do
			local id = key2(part.Position.X, part.Position.Z)
			at[id] = at[id] or {}
			at[id][name] = part
		end
	end
	for _, body in ipairs(named(city, "CarBody")) do
		local group: { [string]: BasePart } = at[key2(body.Position.X, body.Position.Z)] or {}
		vehicle(nearestCar(body.Color), body, body.Position.Y - 1.6, 11.3, 4.8, { group.CarCabin, group.CarWheels }, false)
	end
	for _, body in ipairs(named(city, "Bus")) do
		local group: { [string]: BasePart } = at[key2(body.Position.X, body.Position.Z)] or {}
		vehicle("Bus", body, body.Position.Y - 4.2, 24, 7.7, { group.BusWindows, group.BusWheels }, true)
	end
	for _, body in ipairs(named(city, "Tanker")) do
		local group: { [string]: BasePart } = at[key2(body.Position.X, body.Position.Z)] or {}
		vehicle("Tanker", body, body.Position.Y - 4, 22, 7, { group.TankerWheels }, true)
	end
end

---------------------------------------------------------------------
-- THE STREET: lamps, benches, crates, fountains, hydrants, traffic lights
---------------------------------------------------------------------
local function clearSpot(position: Vector3, radius: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { city, bushes }
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, params)) do
		if part.Name ~= "Sidewalk" and part.Name ~= "Ground" and part.Name ~= "Grass" then
			return false
		end
	end
	return true
end

local function dressStreet()
	-- street lamps
	local heads: { [string]: BasePart } = {}
	for _, head in ipairs(named(city, "LampHead")) do
		heads[key2(head.Position.X, head.Position.Z)] = head
		local light = head:FindFirstChildOfClass("PointLight")
		if light then
			table.insert(lampLights, light)
			light.Color = rgb(255, 208, 150)
		end
	end
	local lampSource = template("Lamp")
	for _, pole in ipairs(named(city, "LampPole")) do
		local head = heads[key2(pole.Position.X, pole.Position.Z)]
		if lampSource and head then
			local base = pole.Position.Y - pole.Size.Y / 2
			local tall = head.Position.Y + 0.6 - base
			local size = Vector3.new(lampSource.Size.X * 1.15, tall, lampSource.Size.Z * 1.15)
			local placed = mesh("Lamp", size, CFrame.new(pole.Position.X, base + tall / 2, pole.Position.Z), false)
			if placed then
				hide(pole)
				hide(head)
				local wide = size.X * GLOW_WIDE
				local glow = box("LampGlow", Vector3.new(wide, wide, wide), CFrame.new(pole.Position.X, base + tall * GLOW_HIGH, pole.Position.Z), rgb(255, 200, 120), Enum.Material.Neon)
				glow.Shape = Enum.PartType.Ball
				glow.Transparency = if ON.light then 1 else GLOW_CLEAR
				local light = head:FindFirstChildOfClass("PointLight")
				if light then
					lampGlows[light] = glow
					light:GetPropertyChangedSignal("Enabled"):Connect(lightSoon)
				end
			end
		end
	end
	-- benches and crates
	local benchSource = template("Bench")
	for _, bench in ipairs(named(city, "Bench")) do
		if benchSource then
			local alongX = bench.Size.X > bench.Size.Z
			local turn = (if alongX then 0 else math.pi / 2) + (if rng:NextNumber() < 0.5 then math.pi else 0)
			local size = Vector3.new(8.2, 3.6, 2.9)
			local base = bench.Position.Y - bench.Size.Y / 2
			if mesh("Bench", size, CFrame.new(bench.Position.X, base + size.Y / 2, bench.Position.Z) * CFrame.Angles(0, turn, 0), true) then
				hide(bench)
			end
		end
	end
	for _, name in ipairs({ "Crate", "CraneLoad" }) do
		for _, crate in ipairs(named(city, name)) do
			local turn = rng:NextInteger(0, 3) * math.pi / 2
			if mesh("Crate", crate.Size + Vector3.new(0.1, 0.1, 0.1), crate.CFrame * CFrame.Angles(0, turn, 0), true) then
				hide(crate)
			end
		end
	end
	-- fountains
	local waters: { [string]: BasePart } = {}
	local pillars: { [string]: BasePart } = {}
	for _, water in ipairs(named(city, "FountainWater")) do
		waters[key2(water.Position.X, water.Position.Z)] = water
	end
	for _, pillar in ipairs(named(city, "FountainPillar")) do
		pillars[key2(pillar.Position.X, pillar.Position.Z)] = pillar
	end
	for _, basin in ipairs(named(city, "FountainBase")) do
		local base = basin.Position.Y - basin.Size.Y / 2
		local size = Vector3.new(12.6, 7.6, 12.6)
		local placed = mesh("Fountain", size, CFrame.new(basin.Position.X, base + size.Y / 2, basin.Position.Z), true)
		if placed then
			hide(basin)
			local id = key2(basin.Position.X, basin.Position.Z)
			if waters[id] then
				hide(waters[id])
			end
			if pillars[id] then
				hide(pillars[id])
			end
			if ON.effects then
				local water = spray(placed, Vector3.new(0, size.Y / 2 - 0.4, 0), rgb(190, 225, 255), 26, 9, 1.1, 14, 0.7)
				water.Acceleration = Vector3.new(0, -26, 0)
				water.LightEmission = 0.2
			end
		end
	end
	-- a traffic light, a hydrant and a bin at every crossing (only where the corner is free)
	for _, head in ipairs(named(city, "LampHead")) do
		local cross = Vector3.new(head.Position.X - 9.5, 1.4, head.Position.Z - 9.5)
		local lightSource = template("TrafficLight")
		local spot = cross + Vector3.new(-9.6, 0, -9.6)
		if lightSource and clearSpot(spot + Vector3.new(0, 3, 0), 2.4) then
			local scale = 12.5 / lightSource.Size.Y
			local size = lightSource.Size * scale
			mesh("TrafficLight", size, CFrame.new(spot.X, spot.Y + size.Y / 2, spot.Z) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0), false)
		end
		local roll = rng:NextNumber()
		local key = if roll < 0.45 then "Hydrant" elseif roll < 0.8 then "Trash" else ""
		local source = if key ~= "" then template(key) else nil
		local place = cross + Vector3.new(9.5 + 2.4, 0, 9.5 - 0.4)
		if source and clearSpot(place + Vector3.new(0, 2, 0), 1.6) then
			local size = source.Size * (if key == "Hydrant" then 1.1 else 1.05)
			mesh(key, size, CFrame.new(place.X, place.Y + size.Y / 2, place.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), false)
		end
	end
	-- road barriers
	local barrierSource = template("Barrier")
	for _, barrier in ipairs(named(city, "Barrier")) do
		if barrierSource then
			-- (the long side of this model is X)
			local alongX = barrier.Size.X > barrier.Size.Z
			local size = Vector3.new(7.1, 3.1, 1.7)
			if mesh("Barrier", size, CFrame.new(barrier.Position) * CFrame.Angles(0, if alongX then 0 else math.pi / 2, 0), true) then
				hide(barrier)
			end
		end
	end
end

---------------------------------------------------------------------
-- THE SKYLINE: far dark buildings behind the wall, so the city does not end at the wall
---------------------------------------------------------------------
local function dressSkyline()
	local tones = { rgb(58, 64, 78), rgb(70, 72, 84), rgb(52, 58, 70), rgb(78, 76, 86) }
	local function tower(x: number, z: number)
		local wide = rng:NextInteger(26, 52)
		local deep = rng:NextInteger(26, 52)
		local tall = rng:NextInteger(60, 170)
		local color = tones[rng:NextInteger(1, #tones)]
		box("FarTower", Vector3.new(wide, tall, deep), CFrame.new(x, tall / 2, z), color, Enum.Material.Concrete)
		if rng:NextNumber() < 0.45 then
			local step = rng:NextInteger(14, 34)
			box("FarTower", Vector3.new(wide * 0.6, step, deep * 0.6), CFrame.new(x, tall + step / 2, z), color, Enum.Material.Concrete)
		end
		local glowColor = rgb(214, 170, 104)
		for y = 24, tall - 6, rng:NextInteger(9, 15) do
			if rng:NextNumber() < 0.6 then
				local glow = box("FarWindows", Vector3.new(wide + 0.4, 1.3, deep + 0.4), CFrame.new(x, y, z), glowColor, Enum.Material.Neon)
				glow:SetAttribute("LooksLit", glowColor)
				table.insert(litWindows, glow)
			end
		end
	end
	for side = 1, 4 do
		local along = -330
		while along < 330 do
			local out = rng:NextInteger(325, 410)
			if side <= 2 then
				out += 120 -- behind these two walls stand the settlement and the nest cave (out to 110 studs)
			end
			if side == 1 then
				tower(along, -out)
			elseif side == 2 then
				tower(along, out)
			elseif side == 3 then
				tower(-out, along)
			else
				tower(out, along)
			end
			along += rng:NextInteger(48, 86)
		end
	end
end

---------------------------------------------------------------------
-- PICKUPS: a coin, a lightning bolt and a shield instead of plain balls.
-- The ball stays (the game logic uses it) and becomes a soft glow around the model.
---------------------------------------------------------------------
local PICKUP_KEYS: { [string]: string } = { CoinPickup = "Coin", BoostPickup = "Bolt", ShieldPickup = "Shield" }

local function dressPickup(item: Instance)
	local key = PICKUP_KEYS[item.Name]
	if not key or not item:IsA("BasePart") then
		return
	end
	local source = template(key)
	if not source then
		return
	end
	local scale = if key == "Coin" then 1.15 elseif key == "Bolt" then 1.6 else 1.05
	-- the client script turns the part named LooksSpin slowly
	local visual = mesh(key, source.Size * scale, CFrame.new(item.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), false, item, "LooksSpin")
	if visual then
		item.Transparency = 0.78
	end
end

---------------------------------------------------------------------
-- THE HELICOPTER: the main script builds it from boxes and moves the model "Craft";
-- a real helicopter is put inside that model and the boxes become invisible.
---------------------------------------------------------------------
local function dressHelicopter(model: Instance)
	local craft = model:WaitForChild("Craft", 5)
	local source = if assets then assets:FindFirstChild("Heli") else nil
	if not craft or not craft:IsA("Model") or not source or not source:IsA("Model") then
		return
	end
	local body = craft:WaitForChild("Body", 5)
	if not body or not body:IsA("BasePart") then
		return
	end
	local copy = source:Clone()
	copy.Name = "LooksHeli"
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			ghost(part, true)
		end
	end
	-- the nose of the box helicopter looks to -X; the nose of the model looks to its own -Z
	copy:PivotTo(body.CFrame * CFrame.new(3.2, 0.9, 0) * CFrame.Angles(0, math.rad(90), 0))
	copy.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hull = copy:FindFirstChild("Fuselage")
	for _, name in ipairs({ "MainRotor", "TailRotor" }) do
		local rotor = copy:FindFirstChild(name)
		if hull and rotor and hull:IsA("BasePart") and rotor:IsA("BasePart") then
			rotor:SetAttribute("LooksOffset", hull.CFrame:ToObjectSpace(rotor.CFrame))
		end
	end
	copy.Parent = craft
	for _, part in ipairs(craft:GetChildren()) do
		if part:IsA("BasePart") then
			hide(part)
		end
	end
end

---------------------------------------------------------------------
-- ZOMBIES: sparks at the moment of infection, a faint glow that follows, and a zombie walk.
-- The main script marks a zombie with a Highlight named ZT_Highlight (it makes a new one
-- every time the look is refreshed). The last survivor has the same mark in light blue:
-- he is not a zombie and gets nothing, so sparks never give away where he hides.
---------------------------------------------------------------------
local ZOMBIE_RUN = ""  -- art bible: no Roblox animations; the zombie shuffle is made in code by ZT_Art
local ZOMBIE_WALK = ""
local ZOMBIE_IDLE = ""

type Mark = { root: BasePart, point: Attachment?, aura: ParticleEmitter?, run: AnimationTrack?, idle: AnimationTrack?, saved: { [Animation]: string }, swap: boolean, swapped: boolean }
local marks: { [Instance]: Mark } = {}

local function zombieGlow(character: Instance): Highlight?
	local glow = character:FindFirstChild("ZT_Highlight")
	if glow and glow:IsA("Highlight") then
		local fill = glow.FillColor
		local lastSurvivor = math.abs(fill.R * 255 - 120) < 3 and math.abs(fill.G * 255 - 235) < 3 and math.abs(fill.B * 255 - 255) < 3
		return if lastSurvivor then nil else glow
	end
	return nil
end

local function track(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local loaded = animator:LoadAnimation(animation)
	loaded.Priority = priority
	loaded.Looped = true
	return loaded
end

-- a player's own "Animate" script reads the animation ids from its children: the server swaps them
local function swapAnimations(character: Instance, mark: Mark)
	local animate = character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local function swap(folder: string, id: string)
		local holder = animate:FindFirstChild(folder)
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Animation") then
					mark.saved[child] = child.AnimationId
					child.AnimationId = id
				end
			end
		end
	end
	swap("run", ZOMBIE_RUN)
	swap("walk", ZOMBIE_WALK)
	swap("idle", ZOMBIE_IDLE)
end

local function restoreAnimations(mark: Mark)
	for animation, id in pairs(mark.saved) do
		if animation.Parent then
			animation.AnimationId = id
		end
	end
	mark.saved = {}
end

-- the zombie animations of Roblox shift a scaled body (their movement is multiplied by the scale twice)
local function isBig(character: Instance): boolean
	return character:IsA("Model") and character:GetScale() > 1.05
end

local function refreshZombie(character: Instance, isBot: boolean)
	if not character:IsDescendantOf(workspace) then
		return
	end
	local glow = zombieGlow(character)
	local mark = marks[character]
	if glow and not mark then
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		local created: Mark = { root = root, saved = {}, swap = false, swapped = false }
		marks[character] = created
		local aura = spray(root, Vector3.new(0, -1.5, 0), glow.FillColor, 5, 2.5, 1.2, 40, 0.9)
		aura:Emit(26)
		created.aura = aura
		created.point = aura.Parent :: Attachment
		if ZOMBIE_RUN ~= "" and humanoid.RigType == Enum.HumanoidRigType.R15 then
			if isBot then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					created.run = track(animator, ZOMBIE_RUN, Enum.AnimationPriority.Movement)
					created.idle = track(animator, ZOMBIE_IDLE, Enum.AnimationPriority.Idle)
				end
			else
				-- the "Animate" script and the player's own animation set may come a little later
				task.spawn(function()
					character:WaitForChild("Animate", 5)
					local player = if character:IsA("Model") then Players:GetPlayerFromCharacter(character) else nil
					local started = os.clock()
					while player and player.Parent and not player:HasAppearanceLoaded() and os.clock() - started < 5 do
						task.wait(0.2)
					end
					if marks[character] == created then
						created.swap = true -- the loop below swaps them (and takes them back while the player is a giant)
					end
				end)
			end
		end
	elseif glow and mark then
		if mark.aura then
			mark.aura.Color = ColorSequence.new(glow.FillColor)
		end
	elseif mark then
		marks[character] = nil
		if mark.point then
			mark.point:Destroy()
		end
		if mark.run then
			mark.run:Stop(0.2)
		end
		if mark.idle then
			mark.idle:Stop(0.2)
		end
		restoreAnimations(mark)
	end
end

local function watchCharacter(character: Instance, isBot: boolean)
	local pending = false
	local function soon(child: Instance)
		if child.Name == "ZT_Highlight" and not pending then
			pending = true
			-- a little later: the old mark is destroyed and the new one made in the same moment
			task.delay(0.1, function()
				pending = false
				safely("zombie", function()
					refreshZombie(character, isBot)
				end)
			end)
		end
	end
	character.ChildAdded:Connect(soon)
	character.ChildRemoved:Connect(soon)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			marks[character] = nil
		end
	end)
	if isBot then
		-- a bot can be a copy of a player who was a zombie at that moment: none of his sparks come along
		for _, item in ipairs(character:GetDescendants()) do
			if item.Name == "LooksPoint" then
				item:Destroy()
			end
		end
	end
	refreshZombie(character, isBot)
end

-- zombie bots: the zombie run while they move, the zombie stand while they wait.
-- zombie players: their animation set is swapped. A giant (bot or player) keeps the ordinary animations.
local function animateBots()
	while true do
		task.wait(0.25)
		for character, mark in pairs(marks) do
			local run, idle = mark.run, mark.idle
			local big = isBig(character)
			if run and idle then
				if big then
					if run.IsPlaying then
						run:Stop(0.15)
					end
					if idle.IsPlaying then
						idle:Stop(0.15)
					end
				else
					local speed = mark.root.AssemblyLinearVelocity
					local moving = mark.root.Parent ~= nil and Vector3.new(speed.X, 0, speed.Z).Magnitude > 3
					if moving and not run.IsPlaying then
						idle:Stop(0.15)
						run:Play(0.15)
					elseif not moving and not idle.IsPlaying then
						run:Stop(0.15)
						idle:Play(0.15)
					end
				end
			elseif mark.swap then
				if big and mark.swapped then
					restoreAnimations(mark)
					mark.swapped = false
				elseif not big and not mark.swapped then
					swapAnimations(character, mark)
					mark.swapped = true
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- SMALL EFFECTS on the map
---------------------------------------------------------------------
local function dressEffects()
	for _, ring in ipairs(named(city, "ManholeRing")) do
		local swirl = spray(ring, Vector3.new(0, 0.2, 0), ring.Color, 7, 3.5, 1.6, 12, 0.55)
		local point = swirl.Parent
		swirl.Parent = ring
		if point then
			point:Destroy()
		end
	end
	for _, pad in ipairs(named(city, "Trampoline")) do
		local burst = spray(pad, Vector3.new(0, 0.4, 0), pad.Color, 0, 14, 0.5, 60, 0.8)
		local last = 0
		pad.Touched:Connect(function()
			if os.clock() - last > 0.5 then
				last = os.clock()
				burst:Emit(18)
			end
		end)
	end
end

---------------------------------------------------------------------
-- THE LOBBY
---------------------------------------------------------------------
local function dressLobby()
	for _, part in ipairs(lobby:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Floor" then
				skin(part, Enum.Material.Marble)
				part.Color = rgb(214, 218, 228)
				part.Reflectance = 0.04
			elseif part.Name == "ShopStand" or part.Name == "MusicBox" then
				skin(part, Enum.Material.DiamondPlate)
			elseif part.Name == "GlassWall" or part.Name == "GlassFloor" then
				part.Reflectance = 0.08
			end
		end
	end
end

---------------------------------------------------------------------
-- START
---------------------------------------------------------------------
if ON.materials then
	safely("materials", dressMaterials)
end
if ON.facades then
	safely("buildings", dressBuildings)
end
if ON.light then
	safely("light", startLight)
end
if ON.nature then
	safely("nature", dressNature)
end
if ON.vehicles then
	safely("vehicles", dressVehicles)
end
if ON.street then
	safely("street", dressStreet)
end
if ON.skyline then
	safely("skyline", dressSkyline)
end
if ON.lobby then
	safely("lobby", dressLobby)
end
if ON.effects then
	safely("effects", dressEffects)
end
if ON.pickups then
	pickupFolder.ChildAdded:Connect(function(item)
		safely("pickup", function()
			dressPickup(item)
		end)
	end)
	for _, item in ipairs(pickupFolder:GetChildren()) do
		safely("pickup", function()
			dressPickup(item)
		end)
	end
end
if ON.heli then
	map.ChildAdded:Connect(function(child)
		if child.Name == "Helicopter" then
			task.spawn(safely, "helicopter", function()
				dressHelicopter(child)
			end)
		end
	end)
end
if ON.effects then
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			safely("zombie", function()
				watchCharacter(character, false)
			end)
		end)
		if player.Character then
			watchCharacter(player.Character, false)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	botFolder.ChildAdded:Connect(function(bot)
		safely("zombie", function()
			watchCharacter(bot, true)
		end)
	end)
	for _, bot in ipairs(botFolder:GetChildren()) do
		watchCharacter(bot, true)
	end
	task.spawn(animateBots)
end
-- the light once more: lamps, glowing windows and far towers were made after the first pass
if ON.light then
	lastWindows = ""
	refreshLight()
end
workspace:SetAttribute("LooksReady", true)
