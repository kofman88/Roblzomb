--!strict
--[[
	TOXIC - the signature look of ZOMBLOCK: a quarantined city after a toxic leak.

	Only how the game LOOKS. It never changes the rules:
	- everything it adds goes into ZombieTagMap.ToxicDecor: no collisions, no rays, no touch events;
	- original parts are not moved, resized or hidden;
	- if this script is deleted, the game works exactly as before (and looks like before).

	What it adds: graffiti in a dripping horror font, hazard stripes and "QUARANTINE" on the wall,
	glowing toxic puddles and leaking barrels in the streets, toxic colours for awnings and some
	shop windows, a giant ZOMBLOCK billboard and two leaking reactor towers behind the wall,
	and a dark lab look for the lobby.
	The client part (StarterPlayerScripts.ZT_Toxic) adds the zombie look, street mist and the
	toxic sky of the final hunt.
]]

local Players = game:GetService("Players")

local ON = {
	graffiti = true,
	wall = true,
	puddles = true,
	barrels = true,
	awnings = true,
	landmarks = true,
	lobby = true,
	people = true,
}

local rgb = Color3.fromRGB
local TOXIC = rgb(130, 255, 80)
local TOXIC_DARK = rgb(60, 150, 40)
local HAZARD = rgb(255, 214, 40)
local INK = rgb(18, 20, 24)
local rng = Random.new(1031)

local function safely(name: string, action: () -> ())
	local ok, err = pcall(action :: () -> any)
	if not ok then
		warn("[Zombie Tag] Toxic: " .. name .. ": " .. tostring(err))
	end
end

local mapFound = workspace:WaitForChild("ZombieTagMap", 120)
assert(mapFound, "[Zombie Tag] Toxic: the map was not found, toxic look is off")
local map: Instance = mapFound
local city: Instance = map:WaitForChild("City")
local lobby: Instance = map:WaitForChild("Lobby")

-- the Looks script dresses the city first (materials, facades): wait for it, but never forever
do
	local started = os.clock()
	while not workspace:GetAttribute("LooksReady") and os.clock() - started < 40 do
		task.wait(0.5)
	end
end

local decor = Instance.new("Folder")
decor.Name = "ToxicDecor"
decor.Parent = map

local made = 0
local function breathe()
	made += 1
	if made % 200 == 0 then
		task.wait()
	end
end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function box(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	ghost(part)
	part.Parent = parent or decor
	breathe()
	return part
end

local function cylinder(name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance?): Part
	-- a Roblox cylinder lies along X: turn it so that it stands up
	local part = box(name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.pi / 2), color, material, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
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

-- a flat sheet a little in front of a wall, looking out along "normal", with a SurfaceGui on it
local function sheet(name: string, centre: Vector3, normal: Vector3, wide: number, high: number, perStud: number): (Part, SurfaceGui)
	local part = box(name, Vector3.new(wide, high, 0.05), CFrame.lookAt(centre, centre + normal), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = perStud
	gui.LightInfluence = 0.15
	gui.Brightness = 1.6
	gui.MaxDistance = 260
	gui.ClipsDescendants = true
	gui.Parent = part
	return part, gui
end

local function text(parent: Instance, value: string, font: Enum.Font, color: Color3, size: UDim2, position: UDim2, rotation: number, stroke: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Rotation = rotation
	label.Font = font
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	if stroke then
		label.TextStrokeColor3 = stroke
		label.TextStrokeTransparency = 0.2
	end
	label.Parent = parent
	return label
end

---------------------------------------------------------------------
-- GRAFFITI on the ground floor of houses, shops and the school
---------------------------------------------------------------------
-- spray-painted pieces (images uploaded to Roblox): image id and width / height
local PIECES: { { any } } = {
	{ "rbxassetid://114273873834377", 2 }, -- ZOMBLOCK
	{ "rbxassetid://120035105447644", 2 }, -- RUN!
	{ "rbxassetid://115942060639174", 1 }, -- biohazard stencil
	{ "rbxassetid://99815887621278", 2 },  -- БЕГИ!
	{ "rbxassetid://137208698965465", 2 }, -- don't get bitten (tag)
	{ "rbxassetid://73045115080702", 2 },  -- INFECTED
	{ "rbxassetid://81158105327461", 1 },  -- zombie face stencil
	{ "rbxassetid://74782424263030", 2 },  -- ОНИ РЯДОМ
	{ "rbxassetid://105700244404769", 2 }, -- zmblk (tag)
	{ "rbxassetid://130208426020636", 2 }, -- LAST ONE?
	{ "rbxassetid://106204276217307", 2 }, -- EVAC arrow
	{ "rbxassetid://118263834862825", 2 }, -- не дай себя укусить (tag)
}
local GRAFFITI_ON = { LowHouse = true, House = true, Shop = true, School = true, GasShop = true, Hospital = true, Tower = true }

local function firstBandAbove(body: BasePart, bands: { BasePart }): number
	local base = body.Position.Y - body.Size.Y / 2
	local lowest = body.Position.Y + body.Size.Y / 2
	for _, band in ipairs(bands) do
		local bottom = band.Position.Y - band.Size.Y / 2
		if bottom > base and bottom < lowest and math.abs(band.Position.X - body.Position.X) < 1 and math.abs(band.Position.Z - body.Position.Z) < 1 then
			lowest = bottom
		end
	end
	return lowest
end

local function dressGraffiti()
	local bands = named(city, "Windows")
	local bodies: { BasePart } = {}
	for _, child in ipairs(city:GetChildren()) do
		if child:IsA("BasePart") and GRAFFITI_ON[child.Name] then
			table.insert(bodies, child)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { city }
	local pieceIndex = rng:NextInteger(1, #PIECES)
	for _, body in ipairs(bodies) do
		local size, centre = body.Size, body.Position
		local base = centre.Y - size.Y / 2
		local top = firstBandAbove(body, bands)
		-- towers have shop windows on the ground floor: paint above them, under the first windows
		local low, high = base + 1.4, math.min(top - 0.4, base + 7)
		if body.Name == "Tower" then
			low, high = base + 6.6, top - 0.3
		end
		local room = high - low
		if room >= 1.6 and rng:NextNumber() < 0.75 then
			local faces: { { any } } = {
				{ Vector3.new(0, 0, -1), size.X, Vector3.new(centre.X, 0, centre.Z - size.Z / 2) },
				{ Vector3.new(0, 0, 1), size.X, Vector3.new(centre.X, 0, centre.Z + size.Z / 2) },
				{ Vector3.new(-1, 0, 0), size.Z, Vector3.new(centre.X - size.X / 2, 0, centre.Z) },
				{ Vector3.new(1, 0, 0), size.Z, Vector3.new(centre.X + size.X / 2, 0, centre.Z) },
			}
			local count = if rng:NextNumber() < 0.35 then 2 else 1
			for _ = 1, count do
				local face = faces[rng:NextInteger(1, #faces)]
				local normal: Vector3, length: number, middle: Vector3 = face[1] :: Vector3, face[2] :: number, face[3] :: Vector3
				local piece: { any } = PIECES[pieceIndex]
				local aspect: number = piece[2]
				local wide = math.min(room * aspect, length * 0.7, 24)
				local along = Vector3.new(normal.Z, 0, -normal.X)
				local slide = rng:NextNumber(-1, 1) * math.max(0, (length - wide) / 2 - 1)
				local spot = middle + along * slide + normal * 0.32 + Vector3.new(0, low + room / 2, 0)
				-- nothing may stand right in front of the painting (a ladder, a door, a sign)
				local blocked = false
				for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.lookAt(spot + normal * 1.2, spot + normal * 2), Vector3.new(wide, room, 1.6), params)) do
					if part ~= body and part.Name ~= "Sidewalk" and part.Name ~= "Ground" and part.Transparency < 0.9 then
						blocked = true
						break
					end
				end
				if not blocked and wide >= 3.5 then
					pieceIndex = pieceIndex % #PIECES + 1
					local high = wide / aspect
					local _, gui = sheet("Graffiti", spot, normal, wide, high, 30)
					gui.LightInfluence = 0.7 -- paint, not a lamp: darker in the shade, a little glow at night
					gui.Brightness = 1.2
					local image = Instance.new("ImageLabel")
					image.BackgroundTransparency = 1
					image.Size = UDim2.fromScale(1, 1)
					image.Image = piece[1]
					image.ScaleType = Enum.ScaleType.Fit
					image.Rotation = rng:NextNumber(-4, 4)
					image.ImageTransparency = 0.05
					image.Parent = gui
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- THE QUARANTINE WALL: hazard stripes along the bottom and the word QUARANTINE
---------------------------------------------------------------------
local function stripes(parent: Instance, height: UDim2, position: UDim2)
	local band = Instance.new("Frame")
	band.Size = height
	band.Position = position
	band.BackgroundColor3 = HAZARD
	band.BorderSizePixel = 0
	band.ClipsDescendants = true
	band.Parent = parent
	-- diagonal black stripes: many thin rotated frames inside a clipping band
	for i = 0, 59 do
		local stripe = Instance.new("Frame")
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Size = UDim2.new(0, 34, 3, 0)
		stripe.Position = UDim2.new(i / 60, 0, 0.5, 0)
		stripe.Rotation = 35
		stripe.BackgroundColor3 = INK
		stripe.BorderSizePixel = 0
		stripe.Parent = band
	end
end

local function dressWall()
	for _, wall in ipairs(named(city, "QuarantineWall")) do
		local size, centre = wall.Size, wall.Position
		local alongX = size.X >= size.Z
		local length = if alongX then size.X else size.Z
		local thick = if alongX then size.Z else size.X
		local tall = size.Y
		if length > 20 and tall > 4 then
			for _, sign in ipairs({ -1, 1 }) do
				local normal = if alongX then Vector3.new(0, 0, sign) else Vector3.new(sign, 0, 0)
				local face = centre + normal * (thick / 2 + 0.06)
				-- stripes: the lowest 2.2 studs, in pieces (a SurfaceGui is never wider than it can draw sharply)
				local pieces = math.max(1, math.ceil(length / 60))
				local pieceLength = length / pieces
				local along = Vector3.new(normal.Z, 0, -normal.X)
				for p = 0, pieces - 1 do
					local mid = face + along * (-length / 2 + pieceLength * (p + 0.5))
					local band = math.min(2.2, tall * 0.3)
					local _, gui = sheet("Hazard", Vector3.new(mid.X, centre.Y - tall / 2 + band / 2 + 0.2, mid.Z), normal, pieceLength, band, 10)
					gui.LightInfluence = 0.6
					gui.Brightness = 1
					stripes(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
					-- the word, every ~60 studs, high on the wall
					if tall > 7 then
						local wordHigh = math.min(4, tall * 0.35)
						local _, words = sheet("Quarantine", Vector3.new(mid.X, centre.Y + tall / 2 - wordHigh / 2 - 0.6, mid.Z), normal, math.min(40, pieceLength * 0.8), wordHigh, 12)
						words.LightInfluence = 0.3
						text(words, "☣ QUARANTINE · КАРАНТИН ☣", Enum.Font.GothamBlack, HAZARD, UDim2.fromScale(0.98, 0.9), UDim2.fromScale(0.5, 0.5), 0, INK)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- TOXIC PUDDLES on the streets, LEAKING BARRELS by the walls
---------------------------------------------------------------------
local cityMin, cityMax = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
for _, wall in ipairs(named(city, "QuarantineWall")) do
	cityMin = cityMin:Min(wall.Position - wall.Size / 2)
	cityMax = cityMax:Max(wall.Position + wall.Size / 2)
end
if cityMin.X == math.huge then
	for _, part in ipairs(named(city, "Ground")) do
		cityMin = cityMin:Min(part.Position - part.Size / 2)
		cityMax = cityMax:Max(part.Position + part.Size / 2)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { city }

local FLOOR_NAMES = { Ground = true, Sidewalk = true, RoadLine = true, StopLine = true, Cross = true }
local KEEP_AWAY = { Manhole = 7, ManholeRing = 7, Trampoline = 8, TrampolineRim = 8, Helipad = 14, HelipadMark = 14, Ladder = 5, Ramp = 5 }

local function groundAt(x: number, z: number): (Vector3?, string?)
	local hit = workspace:Raycast(Vector3.new(x, cityMax.Y + 120, z), Vector3.new(0, -400, 0), rayParams)
	if hit and FLOOR_NAMES[hit.Instance.Name] and hit.Normal.Y > 0.95 then
		return hit.Position, hit.Instance.Name
	end
	return nil, nil
end

local function freeAround(position: Vector3, radius: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { city }
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position + Vector3.new(0, 2, 0), radius, params)) do
		if not FLOOR_NAMES[part.Name] and part.Name ~= "Grass" then
			return false
		end
	end
	for name, far in pairs(KEEP_AWAY) do
		for _, part in ipairs(named(city, name)) do
			if (part.Position - position).Magnitude < far then
				return false
			end
		end
	end
	return true
end

local function bubbles(parent: BasePart, rate: number)
	local point = Instance.new("Attachment")
	point.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ToxicBubbles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(TOXIC)
	emitter.LightEmission = 0.8
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size = NumberSequence.new(0.35, 0.05)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = point
end

local function puddle(position: Vector3, scale: number)
	-- two or three overlapping round spots: never a perfect circle
	local holder = Instance.new("Model")
	holder.Name = "ToxicPuddle"
	local main = box("Spot", Vector3.new(0.06, 5 * scale, 5 * scale), CFrame.new(position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2), TOXIC_DARK, Enum.Material.Neon, holder)
	main.Shape = Enum.PartType.Cylinder
	main.Transparency = 0.25
	for _ = 1, rng:NextInteger(1, 2) do
		local offset = Vector3.new(rng:NextNumber(-1.8, 1.8), 0.045, rng:NextNumber(-1.8, 1.8)) * scale
		local d = rng:NextNumber(2, 3.4) * scale
		local spot = box("Spot", Vector3.new(0.06, d, d), CFrame.new(position + offset) * CFrame.Angles(0, 0, math.pi / 2), TOXIC_DARK, Enum.Material.Neon, holder)
		spot.Shape = Enum.PartType.Cylinder
		spot.Transparency = 0.3
	end
	local core = box("Core", Vector3.new(0.07, 2.2 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), TOXIC, Enum.Material.Neon, holder)
	core.Shape = Enum.PartType.Cylinder
	core.Transparency = 0.35
	if rng:NextNumber() < 0.45 then
		bubbles(core, 2)
	end
	holder.Parent = decor
end

local function dressPuddles()
	local placed = 0
	local tries = 0
	while placed < 46 and tries < 900 do
		tries += 1
		local x = rng:NextNumber(cityMin.X + 6, cityMax.X - 6)
		local z = rng:NextNumber(cityMin.Z + 6, cityMax.Z - 6)
		local spot = groundAt(x, z)
		if spot and freeAround(spot, 3.2) then
			puddle(spot, rng:NextNumber(0.7, 1.25))
			placed += 1
		end
	end
end

local function barrel(position: Vector3, tipped: boolean)
	local holder = Instance.new("Model")
	holder.Name = "ToxicBarrel"
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local frame = if tipped
		then CFrame.new(position + Vector3.new(0, 1.05, 0)) * turn * CFrame.Angles(math.pi / 2, 0, 0)
		else CFrame.new(position + Vector3.new(0, 1.55, 0)) * turn
	local body = cylinder("Drum", 3.1, 2.1, frame, HAZARD, Enum.Material.Metal, holder)
	body.Reflectance = 0.05
	cylinder("Ring", 0.25, 2.18, frame * CFrame.new(0, 0.85, 0), INK, Enum.Material.Metal, holder)
	cylinder("Ring", 0.25, 2.18, frame * CFrame.new(0, -0.85, 0), INK, Enum.Material.Metal, holder)
	cylinder("Glow", 0.35, 2.2, frame * CFrame.new(0, 0, 0), TOXIC, Enum.Material.Neon, holder)
	local lid = cylinder("Lid", 0.12, 1.9, frame * CFrame.new(0, 1.58, 0), TOXIC, Enum.Material.Neon, holder)
	if not tipped and rng:NextNumber() < 0.5 then
		local point = Instance.new("Attachment")
		point.Parent = lid
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "ToxicSteam"
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(rgb(150, 255, 110))
		steam.LightEmission = 0.35
		steam.Rate = 3
		steam.Lifetime = NumberRange.new(2, 3.5)
		steam.Speed = NumberRange.new(1.5, 2.5)
		steam.SpreadAngle = Vector2.new(12, 12)
		steam.Size = NumberSequence.new(0.8, 3)
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.6), NumberSequenceKeypoint.new(1, 1) })
		steam.EmissionDirection = Enum.NormalId.Right -- the cylinder was turned: its +X looks up
		steam.Parent = point
	end
	holder.Parent = decor
	if tipped then
		puddle(position + (frame.LookVector * -2.2) * Vector3.new(1, 0, 1), 0.8)
	end
end

local function dressBarrels()
	local bodies: { BasePart } = {}
	for _, child in ipairs(city:GetChildren()) do
		if child:IsA("BasePart") and (child.Name == "LowHouse" or child.Name == "House" or child.Name == "Shop" or child.Name == "Tower" or child.Name == "School" or child.Name == "Hospital") then
			table.insert(bodies, child)
		end
	end
	local placed = 0
	local tries = 0
	while placed < 22 and tries < 500 and #bodies > 0 do
		tries += 1
		local body = bodies[rng:NextInteger(1, #bodies)]
		local size, centre = body.Size, body.Position
		local side = rng:NextInteger(1, 4)
		local normal = ({ Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0) })[side]
		local half = if normal.X ~= 0 then size.X / 2 else size.Z / 2
		local length = if normal.X ~= 0 then size.Z else size.X
		local along = Vector3.new(normal.Z, 0, -normal.X)
		local guess = Vector3.new(centre.X, 0, centre.Z) + normal * (half + 2) + along * rng:NextNumber(-length / 2 + 2, length / 2 - 2)
		local spot = groundAt(guess.X, guess.Z)
		if spot and freeAround(spot, 1.8) then
			local cluster = rng:NextInteger(1, 3)
			for i = 1, cluster do
				local p = spot + along * ((i - 1) * 2.3)
				local floorHere = groundAt(p.X, p.Z)
				if floorHere and (i == 1 or freeAround(floorHere, 1.4)) then
					barrel(floorHere, i == cluster and cluster > 1 and rng:NextNumber() < 0.5)
				end
			end
			placed += 1
		end
	end
end

---------------------------------------------------------------------
-- AWNINGS AND SHOP WINDOWS in the toxic colours (they were made by Looks, in map.Decor)
---------------------------------------------------------------------
local AWNING_TOXIC = { rgb(36, 40, 46), HAZARD, rgb(96, 200, 60), rgb(36, 40, 46), rgb(120, 70, 160), rgb(230, 230, 230) }
local function dressAwnings()
	local looks = map:FindFirstChild("Decor")
	if not looks then
		return
	end
	for _, part in ipairs(looks:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Awning" then
				part.Color = AWNING_TOXIC[rng:NextInteger(1, #AWNING_TOXIC)]
			elseif part.Name == "ShopWindow" and part:GetAttribute("LooksLit") ~= nil and rng:NextNumber() < 0.35 then
				part:SetAttribute("LooksLit", rgb(90, 200, 70))
			end
		end
	end
end

---------------------------------------------------------------------
-- LANDMARKS behind the wall: the giant ZOMBLOCK billboard and two leaking reactor towers
---------------------------------------------------------------------
local function steam(parent: BasePart, offset: Vector3, size: number, rate: number)
	local point = Instance.new("Attachment")
	point.Position = offset
	point.Parent = parent
	local cloud = Instance.new("ParticleEmitter")
	cloud.Name = "ToxicCloud"
	cloud.Texture = "rbxasset://textures/particles/smoke_main.dds"
	cloud.Color = ColorSequence.new(rgb(170, 255, 120), rgb(90, 140, 70))
	cloud.LightEmission = 0.4
	cloud.Rate = rate
	cloud.Lifetime = NumberRange.new(7, 11)
	cloud.Speed = NumberRange.new(5, 8)
	cloud.SpreadAngle = Vector2.new(10, 10)
	cloud.Acceleration = Vector3.new(1.5, 0.5, 0.6)
	cloud.Size = NumberSequence.new(size, size * 3.5)
	cloud.Rotation = NumberRange.new(0, 360)
	cloud.RotSpeed = NumberRange.new(-12, 12)
	cloud.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(1, 1) })
	cloud.EmissionDirection = Enum.NormalId.Top
	cloud.Parent = point
end

local function reactor(at: Vector3)
	local holder = Instance.new("Model")
	holder.Name = "ToxicReactor"
	-- a cooling tower: rings that first narrow and then widen again
	local rings = 9
	local tall = 112
	for i = 0, rings - 1 do
		local t = i / (rings - 1)
		local waist = 1 - 0.32 * math.sin(t * math.pi * 0.85)
		local d = 58 * waist
		local ring = cylinder("Tower", tall / rings + 0.2, d, CFrame.new(at + Vector3.new(0, tall / rings * (i + 0.5), 0)), rgb(150, 152, 150), Enum.Material.Concrete, holder)
		ring.CastShadow = false
	end
	cylinder("Stripe", 3, 58 * (1 - 0.32 * math.sin(0.75 * math.pi * 0.85)) + 0.6, CFrame.new(at + Vector3.new(0, tall * 0.75, 0)), TOXIC, Enum.Material.Neon, holder)
	local top = cylinder("Top", 0.4, 52, CFrame.new(at + Vector3.new(0, tall + 0.2, 0)), TOXIC, Enum.Material.Neon, holder)
	steam(top, Vector3.new(0, 0, 0), 14, 3)
	local light = Instance.new("PointLight")
	light.Color = TOXIC
	light.Range = 60
	light.Brightness = 2
	light.Parent = top
	holder.Parent = decor
end

local function billboard(at: Vector3, facing: Vector3, logo: string)
	local holder = Instance.new("Model")
	holder.Name = "ToxicBillboard"
	local wide, high = 84, 24
	local lift = 74 -- the board stands higher than the wall (44 studs): seen from the streets
	local look = CFrame.lookAt(at + Vector3.new(0, lift, 0), at + Vector3.new(0, lift, 0) + facing)
	box("Post", Vector3.new(2.5, lift - high / 2, 2.5), CFrame.new(at + look.RightVector * (wide * 0.3) + Vector3.new(0, (lift - high / 2) / 2, 0)), rgb(50, 52, 58), Enum.Material.Metal, holder)
	box("Post", Vector3.new(2.5, lift - high / 2, 2.5), CFrame.new(at - look.RightVector * (wide * 0.3) + Vector3.new(0, (lift - high / 2) / 2, 0)), rgb(50, 52, 58), Enum.Material.Metal, holder)
	local board = box("Board", Vector3.new(wide, high, 1), look, INK, Enum.Material.SmoothPlastic, holder)
	box("Frame", Vector3.new(wide + 1.6, 0.8, 1.2), look * CFrame.new(0, high / 2 + 0.4, 0), TOXIC, Enum.Material.Neon, holder)
	box("Frame", Vector3.new(wide + 1.6, 0.8, 1.2), look * CFrame.new(0, -high / 2 - 0.4, 0), TOXIC, Enum.Material.Neon, holder)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.MaxDistance = 2000
	gui.Parent = board
	local mark = Instance.new("ImageLabel")
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromScale(0.96, 0.7)
	mark.Position = UDim2.fromScale(0.5, 0.38)
	mark.ScaleType = Enum.ScaleType.Fit
	mark.Image = logo
	mark.Parent = gui
	text(gui, "☣ INFECTION CITY · ГОРОД ЗАРАЖЕНИЯ ☣", Enum.Font.GothamBlack, HAZARD, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.5, 0.82), 0, INK)
	holder.Parent = decor
end

local function dressLandmarks()
	if cityMin.X == math.huge then
		return
	end
	local centre = (cityMin + cityMax) / 2
	local ground = cityMin.Y
	for _, part in ipairs(named(city, "Ground")) do
		ground = part.Position.Y + part.Size.Y / 2
		break
	end
	local span = cityMax - cityMin
	-- the billboard behind the far wall (long side), looking into the city
	local alongX = span.X >= span.Z
	local outside = if alongX then Vector3.new(centre.X, ground, cityMax.Z + 30) else Vector3.new(cityMax.X + 30, ground, centre.Z)
	billboard(outside, (Vector3.new(centre.X, ground, centre.Z) - outside).Unit, "rbxassetid://96216736036365") -- the logo in English
	local opposite = if alongX then Vector3.new(centre.X, ground, cityMin.Z - 30) else Vector3.new(cityMin.X - 30, ground, centre.Z)
	billboard(opposite, (Vector3.new(centre.X, ground, centre.Z) - opposite).Unit, "rbxassetid://121492716147042") -- and in Russian
	-- the reactors in two far corners
	reactor(Vector3.new(cityMax.X + 70, ground, cityMin.Z - 40))
	reactor(Vector3.new(cityMin.X - 70, ground, cityMax.Z + 40))
end

---------------------------------------------------------------------
-- THE LOBBY: a dark lab instead of white marble, with toxic light strips
---------------------------------------------------------------------
local function dressLobby()
	for _, part in ipairs(lobby:GetChildren()) do
		if part:IsA("BasePart") and part.Name == "Floor" and part.Size.X > 20 and part.Size.Z > 20 then
			part.Material = Enum.Material.DiamondPlate
			part.MaterialVariant = ""
			part.Color = rgb(52, 56, 62)
			part.Reflectance = 0.03
			local top = part.Position.Y + part.Size.Y / 2
			local size, centre = part.Size, part.Position
			-- glowing strips around the floor and a cross in the middle
			local inset = 1.5
			for _, edge in ipairs({
				{ Vector3.new(size.X - inset * 2, 0.08, 0.35), Vector3.new(0, 0, size.Z / 2 - inset) },
				{ Vector3.new(size.X - inset * 2, 0.08, 0.35), Vector3.new(0, 0, -size.Z / 2 + inset) },
				{ Vector3.new(0.35, 0.08, size.Z - inset * 2), Vector3.new(size.X / 2 - inset, 0, 0) },
				{ Vector3.new(0.35, 0.08, size.Z - inset * 2), Vector3.new(-size.X / 2 + inset, 0, 0) },
			}) do
				box("LabStrip", edge[1], CFrame.new(centre.X + edge[2].X, top + 0.04, centre.Z + edge[2].Z), TOXIC, Enum.Material.Neon)
			end
			local hazard = box("LabSign", Vector3.new(14, 0.06, 14), CFrame.new(centre.X, top + 0.035, centre.Z), INK, Enum.Material.SmoothPlastic)
			hazard.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0.2
			gui.Brightness = 1.2
			gui.Parent = hazard
			local symbol = text(gui, "☣", Enum.Font.GothamBlack, TOXIC, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.5, 0.5), 0, nil)
			symbol.TextTransparency = 0.35
		end
	end
end


---------------------------------------------------------------------
-- PEOPLE OF THE CITY: citizens (bots) wear yellow hazmat suits with gas masks,
-- infected bots get rotten skin and glowing pustules. Players keep their own avatars.
-- The zombie mark (Highlight "ZT_Highlight" of the main script) gets a thinner fill,
-- so that the body under it can be seen: outline + a light green tint.
---------------------------------------------------------------------
local SUIT = rgb(236, 186, 34)
local SUIT_DARK = rgb(40, 40, 44)
local SKIN_ROT = rgb(118, 150, 96)
local ZOMBIE_FACE = "rbxassetid://131515873235590"
-- clothes drawn from Nano Banana fabrics: a hazmat suit (gloves, boots, reflective stripes, ZOMBLOCK patch) and zombie rags
local OUTFIT = {
	hazmat = { shirt = "rbxassetid://114426398762922", pants = "rbxassetid://98368532157924" },
	zombie = { shirt = "rbxassetid://110326893851005", pants = "rbxassetid://72259973755330" },
}
local LIMBS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local ENDS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

local function attach(model: Model, host: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = host.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	part:SetAttribute("ToxicGear", true)
	part.Parent = model
	return part
end

local function clearGear(model: Model)
	for _, child in ipairs(model:GetChildren()) do
		if child:GetAttribute("ToxicGear") then
			child:Destroy()
		end
	end
end

local function face(model: Model, visible: boolean)
	local head = model:FindFirstChild("Head")
	if head then
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") then
				d.Transparency = if visible then 0 else 1
			end
		end
	end
end

local function wear(model: Model, kind: string)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local set = OUTFIT[kind]
	local shirt = Instance.new("Shirt")
	shirt.Name = "ToxicShirt"
	shirt.ShirtTemplate = set.shirt
	shirt.Parent = model
	local pants = Instance.new("Pants")
	pants.Name = "ToxicPants"
	pants.PantsTemplate = set.pants
	pants.Parent = model
end

local function suitUp(model: Model)
	clearGear(model)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		return
	end
	-- a bot may wear a copy of somebody's clothes and hats: under the suit they are not seen
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("Accessory") then
			child:Destroy()
		end
	end
	for _, name in ipairs(LIMBS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = SUIT
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	for _, name in ipairs(ENDS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = SUIT_DARK
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	head.Color = SUIT
	face(model, false)
	wear(model, "hazmat")
	local k = head.Size.Y / 1.2
	-- the hood is a little bigger than the head, the visor and the filters are in front
	attach(model, head, "Hood", head.Size * 1.08, CFrame.new(0, 0.02 * k, 0.02 * k), SUIT, Enum.Material.SmoothPlastic)
	attach(model, head, "Visor", Vector3.new(0.98, 0.5, 0.12) * k, CFrame.new(0, 0.08 * k, -head.Size.Z * 0.55), rgb(30, 40, 46), Enum.Material.Glass).Reflectance = 0.35
	attach(model, head, "Filter", Vector3.new(0.34, 0.42, 0.42) * k, CFrame.new(0, -0.3 * k, -head.Size.Z * 0.58) * CFrame.Angles(0, math.pi / 2, 0), SUIT_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	attach(model, head, "FilterL", Vector3.new(0.26, 0.3, 0.3) * k, CFrame.new(-0.42 * k, -0.28 * k, -head.Size.Z * 0.42) * CFrame.Angles(0, math.pi / 3, 0), SUIT_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	attach(model, head, "FilterR", Vector3.new(0.26, 0.3, 0.3) * k, CFrame.new(0.42 * k, -0.28 * k, -head.Size.Z * 0.42) * CFrame.Angles(0, -math.pi / 3, 0), SUIT_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- an air tank on the back and a black belt
	local t = torso.Size
	attach(model, torso, "Tank", Vector3.new(t.Y * 0.95, t.X * 0.32, t.X * 0.32), CFrame.new(0, 0, t.Z * 0.62) * CFrame.Angles(0, 0, math.pi / 2), rgb(200, 204, 210), Enum.Material.Metal, Enum.PartType.Cylinder)
	attach(model, torso, "TankBand", Vector3.new(0.14, t.X * 0.34, t.X * 0.34), CFrame.new(0, t.Y * 0.18, t.Z * 0.62) * CFrame.Angles(0, 0, math.pi / 2), HAZARD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	attach(model, torso, "Belt", Vector3.new(t.X * 1.04, 0.16, t.Z * 1.08), CFrame.new(0, -t.Y * 0.46, 0), SUIT_DARK, Enum.Material.SmoothPlastic)
end

local function rot(model: Model)
	clearGear(model)
	local torso = model:FindFirstChild("UpperTorso")
	local head = model:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	if head and head:IsA("BasePart") then
		head.Color = SKIN_ROT
		-- an angry rotten face (the glowing eyes are drawn on top of it by ZT_Toxic)
		local decal = head:FindFirstChild("face")
		if not decal or not decal:IsA("Decal") then
			local made = Instance.new("Decal")
			made.Name = "face"
			made.Face = Enum.NormalId.Front
			made.Parent = head
			decal = made
		end
		local faceDecal = decal :: Decal
		faceDecal.Texture = ZOMBIE_FACE
		faceDecal.Transparency = 0
	end
	wear(model, "zombie")
	-- rotten skin on the arms, dirty rags on the legs
	for _, name in ipairs({ "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = SKIN_ROT
		end
	end
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = rgb(70, 74, 66)
		end
	end
	-- a torn suit: yellow rags stay on the torso, dark tears and glowing pustules on the body
	local t = torso.Size
	local r = Random.new(#model:GetFullName() + math.floor(torso.Position.X))
	torso.Color = rgb(150, 120, 40)
	for i = 1, 4 do
		local host = if i <= 2 then torso else model:FindFirstChild(if i == 3 then "LeftUpperArm" else "RightLowerArm")
		if host and host:IsA("BasePart") then
			local s = host.Size
			local d = r:NextNumber(0.18, 0.3)
			local side = if r:NextNumber() < 0.5 then -1 else 1
			attach(model, host, "Pustule", Vector3.new(d, d, d), CFrame.new(r:NextNumber(-0.3, 0.3) * s.X, r:NextNumber(-0.3, 0.3) * s.Y, side * s.Z * 0.5), TOXIC, Enum.Material.Neon, Enum.PartType.Ball)
		end
	end
end

local function lighterMark(item: Instance)
	if item.Name == "ZT_Highlight" and item:IsA("Highlight") then
		local character = item.Parent
		local isBot = character ~= nil and character.Parent ~= nil and character.Parent.Name == "Bots"
		item.FillTransparency = if isBot then 0.86 else 0.7
	end
end

local function watchBot(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local function dress()
		safely("bot look", function()
			if model.Name == "Citizen" then
				suitUp(model)
			elseif model.Name == "Zombie" then
				rot(model)
			end
		end)
	end
	-- the main script paints the rig a moment after it appears (and again when a citizen is bitten)
	task.delay(0.4, dress)
	model:GetPropertyChangedSignal("Name"):Connect(function()
		task.delay(0.15, dress)
	end)
	model.ChildAdded:Connect(lighterMark)
	local mark = model:FindFirstChild("ZT_Highlight")
	if mark then
		lighterMark(mark)
	end
end

local function dressPeople()
	local bots = map:WaitForChild("Bots", 30)
	if bots then
		bots.ChildAdded:Connect(watchBot)
		for _, bot in ipairs(bots:GetChildren()) do
			watchBot(bot)
		end
	end
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(lighterMark)
		local mark = character:FindFirstChild("ZT_Highlight")
		if mark then
			lighterMark(mark)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end
---------------------------------------------------------------------
-- START
---------------------------------------------------------------------
if ON.awnings then
	safely("awnings", dressAwnings)
end
if ON.wall then
	safely("wall", dressWall)
end
if ON.graffiti then
	safely("graffiti", dressGraffiti)
end
if ON.puddles then
	safely("puddles", dressPuddles)
end
if ON.barrels then
	safely("barrels", dressBarrels)
end
if ON.landmarks then
	safely("landmarks", dressLandmarks)
end
if ON.lobby then
	safely("lobby", dressLobby)
end
if ON.people then
	safely("people", dressPeople)
end
workspace:SetAttribute("ToxicReady", true)
