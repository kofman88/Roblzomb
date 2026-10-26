--[[
	СТРОЙКА С ЭФФЕКТАМИ (модуль HomesFX)

	КУДА ВСТАВИТЬ: ModuleScript с именем HomesFX внутри главного скрипта, рядом с Homes
	(ServerScriptService -> Script -> HomesFX). Его запускает модуль Homes. Без него всё как раньше.

	Что здесь:
	- дом выживших строится "по-настоящему": сначала голубой чертёж-голограмма, строительные леса,
	  потом детали падают сверху и встают на место с пылью, щепками и стуком молотка; в конце - леса
	  разбираются, вспышка, искры и звёзды ступени над домом;
	- логово зомби вырастает из земли: трещины с зелёным светом, гул, брызги слизи; части поднимаются
	  из-под земли покрытые светящейся слизью и "застывают"; в конце - рёв орды и споры;
	- у всех построек свои материалы (брезент, черепица, камень крепости, плоть улья, кость, обсидиан);
	- таблички и значки участка - картинками: иконка деталей или мозгов, полоска прогресса, звёзды, луна.
	Модуль только украшает: что и когда построено, решает Homes.
]]

local IMG = {
	parts = "rbxassetid://130367461437463",
	brain = "rbxassetid://101960799443050",
	moon = "rbxassetid://73616133698620",
	house = "rbxassetid://117065070927400",
	nest = "rbxassetid://87100024214999",
	star = "rbxassetid://73086948412580",
	dust = "rbxassetid://80076731723169",
	spark = "rbxassetid://121492703539177",
	slime = "rbxassetid://75953201274465",
	chips = "rbxassetid://95986971857173",
	patch = "rbxassetid://130837685572870",
}
-- звуки стройки: один файл, у каждого звука свой кусок (секунды от и до)
local SND_PACK = "rbxassetid://91852844501226"
local SND = {
	b_clank = NumberRange.new(0.2600, 0.9800),
	b_done = NumberRange.new(1.4600, 4.0600),
	b_drill = NumberRange.new(4.5400, 5.6600),
	b_drop = NumberRange.new(6.1400, 6.6510),
	b_hammer1 = NumberRange.new(7.1310, 7.8510),
	b_hammer2 = NumberRange.new(8.3310, 8.8856),
	b_hammer3 = NumberRange.new(9.3656, 10.1658),
	b_saw = NumberRange.new(10.6458, 11.8809),
	b_whoosh = NumberRange.new(12.3609, 13.7790),
	n_burst = NumberRange.new(14.2590, 15.1296),
	n_done = NumberRange.new(15.6096, 18.2751),
	n_grow = NumberRange.new(18.7551, 20.8152),
	n_rumble = NumberRange.new(21.2952, 23.6052),
	n_squelch1 = NumberRange.new(24.0852, 24.8479),
	n_squelch2 = NumberRange.new(25.3279, 26.1059),
}

local BLUEPRINT = Color3.fromRGB(90, 200, 255)
local GOLD = Color3.fromRGB(255, 214, 110)
local SLIME = Color3.fromRGB(120, 255, 110)
local HOUSE_TIME = 3.2   -- секунд на то, чтобы все детали дома встали на место
local NEST_TIME = 3.0    -- и логова

return function(env: any): any
	local ctx = env.ctx
	local TweenService = game:GetService("TweenService")
	local api = {}

	---------------------------------------------------------------------
	-- ЗВУК
	---------------------------------------------------------------------
	local function play(host: Instance, name: string, volume: number?, speed: number?)
		local region = SND[name]
		if not region or not host.Parent then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "FX_" .. name
		sound.SoundId = SND_PACK
		sound.Volume = volume or 0.7
		sound.PlaybackSpeed = speed or 1
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 140
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = region
		sound.TimePosition = region.Min
		sound.Parent = host
		sound:Play()
		task.delay((region.Max - region.Min) / (speed or 1) + 0.3, function()
			sound:Destroy()
		end)
	end

	---------------------------------------------------------------------
	-- ЧАСТИЦЫ
	---------------------------------------------------------------------
	local function emitter(parent: Instance, texture: string, color: Color3, size: { number }, life: { number }, speed: { number }, light: number?): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(color)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size[1]), NumberSequenceKeypoint.new(1, size[2]) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Speed = NumberRange.new(speed[1], speed[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = light or 0
		e.Rate = 0
		e.Parent = parent
		return e
	end
	-- невидимая точка для частиц и звуков
	local function anchor(folder: Instance, at: Vector3): Part
		local p = Instance.new("Part")
		p.Name = "FX_Point"
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Position = at
		p.Parent = folder
		return p
	end
	local function flash(folder: Instance, at: Vector3, color: Color3, brightness: number, range: number, time: number)
		local p = anchor(folder, at)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		light.Parent = p
		TweenService:Create(light, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		task.delay(time + 0.1, function()
			p:Destroy()
		end)
	end

	---------------------------------------------------------------------
	-- ОБЩЕЕ ДЛЯ СТРОЙКИ
	---------------------------------------------------------------------
	local function bounds(parts: { BasePart }): (Vector3, Vector3)
		local lo = Vector3.new(math.huge, math.huge, math.huge)
		local hi = -lo
		for _, part in ipairs(parts) do
			local h = part.Size / 2
			local c = part.Position
			local r = math.max(h.X, h.Z)
			lo = Vector3.new(math.min(lo.X, c.X - r), math.min(lo.Y, c.Y - h.Y), math.min(lo.Z, c.Z - r))
			hi = Vector3.new(math.max(hi.X, c.X + r), math.max(hi.Y, c.Y + h.Y), math.max(hi.Z, c.Z + r))
		end
		return lo, hi
	end
	local function fxFolder(site: any): Folder
		local old = site.model:FindFirstChild("BuildFX")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "BuildFX"
		folder.Parent = site.model
		return folder
	end
	local function plain(part: BasePart)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end
	-- над постройкой поднимаются звёзды ступени и тают
	local function starsBurst(folder: Instance, at: Vector3, tier: number, color: Color3)
		local p = anchor(folder, at)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(9, 3)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.MaxDistance = 220
		gui.Parent = p
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(1, 1)
		row.BackgroundTransparency = 1
		row.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0.02, 0)
		layout.Parent = row
		local images = {}
		for i = 1, 3 do
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.fromScale(0.3, 1)
			img.BackgroundTransparency = 1
			img.Image = IMG.star
			img.ImageColor3 = if i <= tier then Color3.new(1, 1, 1) else Color3.fromRGB(70, 70, 80)
			img.ImageTransparency = 1
			img.ScaleType = Enum.ScaleType.Fit
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.Parent = img
			img.Parent = row
			table.insert(images, img)
		end
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = p
		task.spawn(function()
			for i, img in ipairs(images) do
				TweenService:Create(img, TweenInfo.new(0.25), { ImageTransparency = 0 }):Play()
				task.wait(0.12)
			end
			TweenService:Create(p, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at + Vector3.new(0, 7, 0) }):Play()
			task.wait(1.6)
			for _, img in ipairs(images) do
				TweenService:Create(img, TweenInfo.new(1), { ImageTransparency = 1 }):Play()
			end
			TweenService:Create(glow, TweenInfo.new(1), { Brightness = 0 }):Play()
			task.wait(1.1)
			p:Destroy()
		end)
	end

	---------------------------------------------------------------------
	-- ДОМ: чертёж, леса, детали падают на место
	---------------------------------------------------------------------
	local function buildHouse(site: any, parts: { BasePart })
		local folder = fxFolder(site)
		local lo, hi = bounds(parts)
		local centre = (lo + hi) / 2
		-- уровень земли участка (у купола логова низ шара закопан глубоко под землю)
		local groundY = if site.origin then site.origin.Y else lo.Y
		local base = Vector3.new(centre.X, groundY, centre.Z)
		local board: BasePart = site.board
		local tier: number = site.tier or 0

		-- итог каждой детали; пока идёт стройка, детали спрятаны
		local finals = {}
		for _, part in ipairs(parts) do
			finals[part] = { cf = part.CFrame, t = part.Transparency, collide = part.CanCollide }
			part.Transparency = 1
			part.CanCollide = false
		end

		-- 1. чертёж: голубые призраки всех деталей и сканирующая плоскость
		play(board, "b_whoosh", 0.6)
		local ghosts = {}
		for _, part in ipairs(parts) do
			if finals[part].t < 0.95 then
				local ghost = part:Clone()
				for _, child in ipairs(ghost:GetChildren()) do
					child:Destroy()
				end
				plain(ghost)
				ghost.Material = Enum.Material.Neon
				ghost.MaterialVariant = ""
				ghost.Color = BLUEPRINT
				ghost.Transparency = 1
				ghost.Name = "FX_Ghost"
				ghost.Parent = folder
				ghosts[part] = ghost
				-- светящийся контур поверх полупрозрачного объёма
				local edge = Instance.new("SelectionBox")
				edge.Adornee = ghost
				edge.Color3 = BLUEPRINT
				edge.LineThickness = 0.06
				edge.SurfaceTransparency = 1
				edge.Transparency = 0.25
				edge.Parent = ghost
				TweenService:Create(ghost, TweenInfo.new(0.5), { Transparency = 0.78 }):Play()
			end
		end
		local size = hi - lo
		local scan = Instance.new("Part")
		scan.Name = "FX_Scan"
		plain(scan)
		scan.Material = Enum.Material.Neon
		scan.Color = BLUEPRINT
		scan.Transparency = 0.55
		scan.Size = Vector3.new(size.X + 2, 0.12, size.Z + 2)
		scan.Position = base + Vector3.new(0, 0.1, 0)
		scan.Parent = folder
		TweenService:Create(scan, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = base + Vector3.new(0, size.Y + 0.5, 0), Transparency = 1 }):Play()
		flash(folder, centre, BLUEPRINT, 3, size.Magnitude * 0.6, 1.2)

		-- 2. леса: четыре стойки по углам и перекладины (у палатки - без лесов)
		local poles = {}
		if tier >= 1 then
			task.wait(0.35)
			local corners = { { lo.X - 0.6, lo.Z - 0.6 }, { hi.X + 0.6, lo.Z - 0.6 }, { lo.X - 0.6, hi.Z + 0.6 }, { hi.X + 0.6, hi.Z + 0.6 } }
			local high = size.Y + 1.5
			for i, c in ipairs(corners) do
				local pole = Instance.new("Part")
				pole.Name = "FX_Pole"
				plain(pole)
				pole.Material = Enum.Material.Metal
				pole.Color = Color3.fromRGB(196, 150, 60)
				pole.Size = Vector3.new(0.35, 0.1, 0.35)
				pole.Position = Vector3.new(c[1], lo.Y, c[2])
				pole.Parent = folder
				table.insert(poles, pole)
				TweenService:Create(pole, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(0.35, high, 0.35), Position = Vector3.new(c[1], lo.Y + high / 2, c[2]) }):Play()
				if i % 2 == 1 then
					play(board, "b_clank", 0.5, 0.9 + math.random() * 0.3)
				end
			end
			task.wait(0.3)
			for _, level in ipairs({ 0.34, 0.68 }) do
				local y = lo.Y + high * level
				for _, rail in ipairs({
					{ Vector3.new(size.X + 1.2, 0.25, 0.25), Vector3.new(centre.X, y, lo.Z - 0.6) },
					{ Vector3.new(size.X + 1.2, 0.25, 0.25), Vector3.new(centre.X, y, hi.Z + 0.6) },
					{ Vector3.new(0.25, 0.25, size.Z + 1.2), Vector3.new(lo.X - 0.6, y, centre.Z) },
					{ Vector3.new(0.25, 0.25, size.Z + 1.2), Vector3.new(hi.X + 0.6, y, centre.Z) },
				}) do
					local bar = Instance.new("Part")
					bar.Name = "FX_Rail"
					plain(bar)
					bar.Material = Enum.Material.Metal
					bar.Color = Color3.fromRGB(150, 150, 156)
					bar.Size = rail[1]
					bar.Position = rail[2]
					bar.Transparency = 1
					bar.Parent = folder
					table.insert(poles, bar)
					TweenService:Create(bar, TweenInfo.new(0.25), { Transparency = 0 }):Play()
				end
				play(board, "b_clank", 0.45, 1.1)
				task.wait(0.12)
			end
		end

		-- 3. детали падают сверху снизу вверх, у каждой - пыль и стук
		local dustPoint = anchor(folder, base)
		local dust = emitter(dustPoint, IMG.dust, Color3.fromRGB(214, 196, 168), { 2.2, 6 }, { 0.9, 1.7 }, { 3, 8 })
		local chips = emitter(dustPoint, IMG.chips, Color3.fromRGB(255, 255, 255), { 0.5, 0.3 }, { 0.6, 1.1 }, { 8, 16 })
		chips.Acceleration = Vector3.new(0, -40, 0)
		chips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		local sparks = emitter(dustPoint, IMG.spark, Color3.fromRGB(255, 220, 140), { 0.6, 0 }, { 0.3, 0.6 }, { 6, 14 }, 1)

		table.sort(parts, function(a: BasePart, b: BasePart): boolean
			return finals[a].cf.Position.Y - a.Size.Y / 2 < finals[b].cf.Position.Y - b.Size.Y / 2
		end)
		local per = math.clamp(HOUSE_TIME / math.max(1, #parts), 0.03, 0.2)
		local knocks = { "b_hammer1", "b_hammer2", "b_hammer3", "b_drop" }
		for i, part in ipairs(parts) do
			local final = finals[part]
			if part.Parent then
				local drop = 7 + math.random() * 5
				local spin = CFrame.Angles(math.rad(math.random(-25, 25)), math.rad(math.random(-35, 35)), math.rad(math.random(-25, 25)))
				part.CFrame = final.cf * CFrame.new(0, drop, 0) * spin
				part.Transparency = final.t
				TweenService:Create(part, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = final.cf }):Play()
				local ghost = ghosts[part]
				local landing = final.cf.Position - Vector3.new(0, part.Size.Y / 2, 0)
				task.delay(0.42, function()
					if part.Parent then
						part.CanCollide = final.collide
					end
					if ghost then
						ghost:Destroy()
					end
					if dustPoint.Parent then
						dustPoint.Position = landing
						dust:Emit(4)
						if part.Material == Enum.Material.WoodPlanks or part.Material == Enum.Material.Wood then
							chips:Emit(5)
						elseif part.Material == Enum.Material.Metal or part.Material == Enum.Material.Cobblestone then
							sparks:Emit(6)
						end
					end
				end)
				if i % 3 == 1 then
					local name = if part.Material == Enum.Material.Metal then "b_clank" else knocks[math.random(1, #knocks)]
					task.delay(0.42, play, board, name, 0.6, 0.92 + math.random() * 0.2)
				end
				if i % 11 == 6 then
					task.delay(0.2, play, board, if math.random() < 0.5 then "b_saw" else "b_drill", 0.4)
				end
			end
			task.wait(per)
		end
		task.wait(0.55)

		-- 4. леса разбираются, вспышка, искры и звёзды ступени
		for _, ghost in pairs(ghosts) do
			if ghost.Parent then
				ghost:Destroy()
			end
		end
		for _, pole in ipairs(poles) do
			TweenService:Create(pole, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Position = pole.Position - Vector3.new(0, 1.5, 0) }):Play()
		end
		play(board, "b_done", 0.8)
		dustPoint.Position = centre
		dust:Emit(24)
		sparks.SpreadAngle = Vector2.new(70, 70)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Speed = NumberRange.new(14, 26)
		sparks.Acceleration = Vector3.new(0, -18, 0)
		sparks.Lifetime = NumberRange.new(0.8, 1.4)
		dustPoint.Position = Vector3.new(centre.X, hi.Y, centre.Z)
		sparks:Emit(46)
		flash(folder, Vector3.new(centre.X, hi.Y + 2, centre.Z), GOLD, 6, size.Magnitude, 1.4)
		starsBurst(folder, Vector3.new(centre.X, hi.Y + 3.5, centre.Z), math.max(0, tier), GOLD)
		task.wait(3.2)
		if folder.Parent then
			folder:Destroy()
		end
	end

	---------------------------------------------------------------------
	-- ЛОГОВО: трещины, слизь, части вырастают из земли
	---------------------------------------------------------------------
	local function buildNest(site: any, parts: { BasePart })
		local folder = fxFolder(site)
		local lo, hi = bounds(parts)
		local centre = (lo + hi) / 2
		-- уровень земли участка (у купола логова низ шара закопан глубоко под землю)
		local groundY = if site.origin then site.origin.Y else lo.Y
		local base = Vector3.new(centre.X, groundY, centre.Z)
		local board: BasePart = site.board
		local tier: number = site.tier or 0
		local size = hi - lo

		local finals = {}
		for _, part in ipairs(parts) do
			finals[part] = {
				cf = part.CFrame, t = part.Transparency, collide = part.CanCollide,
				material = part.Material, variant = part.MaterialVariant, color = part.Color,
			}
			part.Transparency = 1
			part.CanCollide = false
		end

		-- 1. земля трескается: зелёные трещины расходятся от центра, гул, свет снизу
		play(board, "n_rumble", 0.8)
		local glow = anchor(folder, base + Vector3.new(0, 0.5, 0))
		local light = Instance.new("PointLight")
		light.Color = SLIME
		light.Range = math.max(18, size.Magnitude * 0.7)
		light.Brightness = 0
		light.Shadows = false
		light.Parent = glow
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 4 }):Play()
		local reach = math.max(size.X, size.Z) * 0.62 + 2
		local cracks = {}
		for k = 1, 9 do
			local angle = (k / 9) * math.pi * 2 + math.random() * 0.4
			local from = base
			for seg = 1, 3 do
				local len = reach / 3 * (0.8 + math.random() * 0.5)
				local a = angle + (math.random() - 0.5) * 0.7
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local mid = from + dir * len / 2 + Vector3.new(0, 0.06, 0)
				local crack = Instance.new("Part")
				crack.Name = "FX_Crack"
				plain(crack)
				crack.Material = Enum.Material.Neon
				crack.Color = SLIME
				crack.Size = Vector3.new(0.05, 0.08, 0.05)
				crack.CFrame = CFrame.lookAt(mid, mid + dir)
				crack.Parent = folder
				table.insert(cracks, crack)
				TweenService:Create(crack, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, (seg - 1) * 0.22 + k * 0.02), { Size = Vector3.new(0.35 - seg * 0.07, 0.08, len) }):Play()
				from = from + dir * len
			end
		end
		local slimePoint = anchor(folder, base)
		local splash = emitter(slimePoint, IMG.slime, Color3.fromRGB(255, 255, 255), { 0.9, 0.2 }, { 0.6, 1.2 }, { 10, 22 }, 0.6)
		splash.EmissionDirection = Enum.NormalId.Top
		splash.SpreadAngle = Vector2.new(35, 35)
		splash.Acceleration = Vector3.new(0, -45, 0)
		local spores = emitter(slimePoint, IMG.spark, SLIME, { 0.4, 0 }, { 1.5, 2.6 }, { 1, 3 }, 1)
		spores.Acceleration = Vector3.new(0, 2.5, 0)
		local mud = emitter(slimePoint, IMG.dust, Color3.fromRGB(90, 96, 70), { 1.6, 4.4 }, { 0.8, 1.4 }, { 2, 6 })
		task.wait(0.7)
		play(board, "n_burst", 0.7)
		splash:Emit(30)
		mud:Emit(12)

		-- 2. части поднимаются из-под земли в светящейся слизи и застывают
		play(board, "n_grow", 0.6)
		table.sort(parts, function(a: BasePart, b: BasePart): boolean
			return finals[a].cf.Position.Y < finals[b].cf.Position.Y
		end)
		local per = math.clamp(NEST_TIME / math.max(1, #parts), 0.04, 0.22)
		for i, part in ipairs(parts) do
			local final = finals[part]
			if part.Parent then
				local depth = part.Size.Y + 1.2
				part.CFrame = final.cf * CFrame.new(0, -depth, 0) * CFrame.Angles(0, math.rad(math.random(-40, 40)), 0)
				part.Transparency = math.min(final.t, 0.05)
				if final.material ~= Enum.Material.Neon then
					part.Material = Enum.Material.Neon
					part.MaterialVariant = ""
					part.Color = SLIME
				end
				TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final.cf }):Play()
				local at = final.cf.Position - Vector3.new(0, part.Size.Y / 2, 0)
				task.delay(0.55, function()
					if not part.Parent then
						return
					end
					-- слизь стекает: деталь становится собой
					part.Material = final.material
					part.MaterialVariant = final.variant
					part.Color = final.color
					part.Transparency = final.t
					part.CanCollide = final.collide
					if slimePoint.Parent then
						slimePoint.Position = at
						splash:Emit(5)
						mud:Emit(2)
					end
				end)
				if i % 2 == 1 then
					task.delay(0.5, play, board, if math.random() < 0.5 then "n_squelch1" else "n_squelch2", 0.55, 0.85 + math.random() * 0.3)
				end
			end
			task.wait(per)
		end
		task.wait(0.7)

		-- 3. рёв орды, споры, трещины гаснут
		play(board, "n_done", 0.85)
		slimePoint.Position = Vector3.new(centre.X, hi.Y, centre.Z)
		spores:Emit(60)
		splash:Emit(24)
		flash(folder, Vector3.new(centre.X, hi.Y + 2, centre.Z), SLIME, 7, size.Magnitude + 10, 1.6)
		starsBurst(folder, Vector3.new(centre.X, hi.Y + 3.5, centre.Z), math.max(0, tier), SLIME)
		for _, crack in ipairs(cracks) do
			TweenService:Create(crack, TweenInfo.new(1.4), { Transparency = 1 }):Play()
		end
		TweenService:Create(light, TweenInfo.new(1.6), { Brightness = 0 }):Play()
		task.wait(3.2)
		if folder.Parent then
			folder:Destroy()
		end
	end

	-- Homes вызывает это сразу после того, как перестроил участок: детали уже стоят на итоговых местах
	function api.build(site: any, parts: { BasePart }, _owner: Player?)
		if #parts == 0 then
			return
		end
		task.spawn(function()
			local ok, err = pcall(if site.kind == "house" then buildHouse else buildNest, site, parts)
			if not ok then
				warn("[Zombie Tag] HomesFX build: " .. tostring(err))
				-- что бы ни случилось, постройка должна остаться видимой
				for _, part in ipairs(parts) do
					if part.Parent and part.Transparency >= 1 and part.Name ~= "Dust" then
						part.Transparency = 0
					end
				end
			end
		end)
	end

	---------------------------------------------------------------------
	-- МАТЕРИАЛЫ ПОСТРОЕК (варианты лежат в MaterialService -> ZB_Textures)
	---------------------------------------------------------------------
	local HOUSE_LOOK: { [string]: { any } } = {
		-- имя детали = { материал, вариант, цвет (nil - оставить) }
		Tent = { Enum.Material.Fabric, "ZH_Canvas" },
		TentDoor = { Enum.Material.Fabric, "ZH_Canvas" },
		Bedroll = { Enum.Material.Fabric, "ZH_Canvas" },
		Fence = { Enum.Material.Cobblestone, "ZH_Stone", Color3.fromRGB(170, 166, 158) },
		Tower = { Enum.Material.Cobblestone, "ZH_Stone", Color3.fromRGB(170, 166, 158) },
		TowerTop = { Enum.Material.Cobblestone, "ZH_Stone", Color3.fromRGB(170, 166, 158) },
		WellRing = { Enum.Material.Cobblestone, "ZH_Stone", Color3.fromRGB(170, 166, 158) },
		Chimney = { Enum.Material.Brick, "" },
		Porch = { Enum.Material.Concrete, "" },
		BuildBoard = { Enum.Material.WoodPlanks, "", Color3.fromRGB(196, 160, 110) },
		NamePlate = { Enum.Material.WoodPlanks, "", Color3.fromRGB(170, 128, 84) },
	}
	local NEST_LOOK: { [string]: { any } } = {
		Mound = { Enum.Material.Ground, "ZH_Hive", Color3.fromRGB(200, 186, 170) },
		Rib = { Enum.Material.Slate, "ZH_Bone", Color3.fromRGB(236, 228, 206) },
		Bone = { Enum.Material.Slate, "ZH_Bone", Color3.fromRGB(236, 228, 206) },
		Skull = { Enum.Material.Slate, "ZH_Bone", Color3.fromRGB(236, 228, 206) },
		Stem = { Enum.Material.Slate, "ZH_Bone", Color3.fromRGB(236, 228, 206) },
		Dais = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(150, 150, 156) },
		Throne = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(170, 170, 176) },
		Brazier = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(150, 150, 156) },
		Stone = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(140, 140, 146) },
		Moss = { Enum.Material.LeafyGrass, "" },
		Yard = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(120, 122, 116) },
		BuildBoard = { Enum.Material.Slate, "ZH_Bone", Color3.fromRGB(214, 206, 186) },
		NamePlate = { Enum.Material.Slate, "ZH_Obsidian", Color3.fromRGB(150, 150, 156) },
	}
	local function look(part: BasePart, kind: string)
		local set = if kind == "house" then HOUSE_LOOK else NEST_LOOK
		local entry = set[part.Name]
		if entry then
			part.Material = entry[1]
			part.MaterialVariant = entry[2]
			if entry[3] then
				part.Color = entry[3]
			end
		elseif kind == "house" and part.Name == "Roof" then
			if part.Material == Enum.Material.Metal then
				part.MaterialVariant = "ZT_Corrugated"
			else
				part.Material = Enum.Material.RoofShingles
				part.MaterialVariant = "ZH_Shingles"
				part.Color = Color3.fromRGB(150, 96, 84)
			end
		elseif part.Name == "Flag" and not part:FindFirstChild("FX_Patch") then
			for _, side in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local d = Instance.new("Decal")
				d.Name = "FX_Patch"
				d.Texture = IMG.patch
				d.Face = side
				d.Parent = part
			end
		end
	end
	function api.dress(site: any)
		for _, d in ipairs(site.model:GetDescendants()) do
			if d:IsA("BasePart") and d.Parent and d.Parent.Name ~= "BuildFX" then
				look(d, site.kind)
			end
		end
		api.signs(site)
	end

	---------------------------------------------------------------------
	-- ТАБЛИЧКИ: картинки вместо значков-смайликов
	---------------------------------------------------------------------
	local function image(parent: Instance, name: string, img: string, size: UDim2, pos: UDim2, anchorPoint: Vector2?): ImageLabel
		local i = Instance.new("ImageLabel")
		i.Name = name
		i.BackgroundTransparency = 1
		i.Image = img
		i.ScaleType = Enum.ScaleType.Fit
		i.Size = size
		i.Position = pos
		i.AnchorPoint = anchorPoint or Vector2.new(0.5, 0.5)
		i.Parent = parent
		return i
	end
	local function text(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.35
		t.Size = size
		t.Position = pos
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Parent = parent
		return t
	end
	-- доска стройки: название следующей ступени, иконка деталей (мозгов), "5/12" и полоска
	local function styleBoard(site: any, label: TextLabel)
		local gui = label.Parent :: BillboardGui
		if gui:FindFirstChild("FX_Board") then
			return
		end
		local house = site.kind == "house"
		local accent = if house then GOLD else SLIME
		gui.Size = UDim2.fromScale(6.4, 3.6)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		local card = Instance.new("Frame")
		card.Name = "FX_Board"
		card.Size = UDim2.fromScale(1, 1)
		card.BackgroundColor3 = if house then Color3.fromRGB(28, 22, 16) else Color3.fromRGB(14, 22, 14)
		card.BackgroundTransparency = 0.18
		card.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.14, 0)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 3
		stroke.Transparency = 0.15
		stroke.Parent = card
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
		grad.Parent = card
		local title = text(card, "Title", UDim2.fromScale(0.9, 0.26), UDim2.fromScale(0.5, 0.2), Color3.fromRGB(255, 248, 230))
		local icon = image(card, "Icon", if house then IMG.parts else IMG.brain, UDim2.fromScale(0.34, 0.5), UDim2.fromScale(0.2, 0.58))
		local count = text(card, "Count", UDim2.fromScale(0.58, 0.34), UDim2.fromScale(0.66, 0.56), accent)
		local barBack = Instance.new("Frame")
		barBack.Name = "Bar"
		barBack.Size = UDim2.fromScale(0.84, 0.1)
		barBack.Position = UDim2.fromScale(0.5, 0.86)
		barBack.AnchorPoint = Vector2.new(0.5, 0.5)
		barBack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		barBack.BackgroundTransparency = 0.35
		barBack.Parent = card
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = barBack
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = accent
		fill.Parent = barBack
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		local function update()
			local raw = label.Text
			local lines = string.split(raw, "\n")
			local last = lines[#lines] or ""
			local have, need = string.match(last, "(%d+)%s*/%s*(%d+)")
			local only = string.match(last, "(%d+)")
			if string.find(raw, "⭐", 1, true) then
				title.Text = ""
				icon.Image = IMG.star
				count.Text = "MAX"
				fill.Size = UDim2.fromScale(1, 1)
			else
				icon.Image = if house then IMG.parts else IMG.brain
				title.Text = if #lines > 1 then lines[1] else ""
				if have and need then
					count.Text = have .. "/" .. need
					local k = math.clamp(tonumber(have) / math.max(1, tonumber(need)), 0, 1)
					TweenService:Create(fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(k, 1) }):Play()
				else
					count.Text = only or ""
					fill.Size = UDim2.fromScale(0, 1)
				end
			end
		end
		update()
		label:GetPropertyChangedSignal("Text"):Connect(update)
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			card.Visible = gui.Enabled
		end)
	end
	-- табличка хозяина: имя и три звезды ступени
	local function styleName(site: any, label: TextLabel)
		local gui = label.Parent :: BillboardGui
		if gui:FindFirstChild("FX_Name") then
			return
		end
		gui.Size = UDim2.fromScale(7, 3)
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		local frame = Instance.new("Frame")
		frame.Name = "FX_Name"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local icon = image(frame, "Kind", if site.kind == "house" then IMG.house else IMG.nest, UDim2.fromScale(0.28, 0.62), UDim2.fromScale(0.13, 0.36))
		local name = text(frame, "Name", UDim2.fromScale(0.72, 0.42), UDim2.fromScale(0.62, 0.3), Color3.fromRGB(255, 255, 255))
		local stars = {}
		for i = 1, 3 do
			stars[i] = image(frame, "Star" .. i, IMG.star, UDim2.fromScale(0.16, 0.38), UDim2.fromScale(0.36 + i * 0.17, 0.76))
		end
		local function update()
			local lines = string.split(label.Text, "\n")
			name.Text = lines[1] or ""
			local row = lines[2] or ""
			local _, filled = string.gsub(row, "★", "")
			for i = 1, 3 do
				stars[i].ImageColor3 = if i <= filled then Color3.new(1, 1, 1) else Color3.fromRGB(60, 60, 70)
				stars[i].ImageTransparency = if i <= filled then 0 else 0.35
			end
			icon.Visible = true
		end
		update()
		label:GetPropertyChangedSignal("Text"):Connect(update)
	end
	local function styleMoon(sign: BillboardGui)
		if sign:FindFirstChild("FX_Moon") then
			return
		end
		local label = sign:FindFirstChildOfClass("TextLabel")
		if label then
			label.TextTransparency = 1
			label.TextStrokeTransparency = 1
		end
		local img = image(sign, "FX_Moon", IMG.moon, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
		-- значок медленно покачивается
		task.spawn(function()
			local t = 0
			while img.Parent do
				t += 0.05
				img.Rotation = math.sin(t) * 6
				task.wait(0.05)
			end
		end)
	end
	function api.signs(site: any)
		if site.fxSigns then
			return
		end
		site.fxSigns = true
		if site.cost then
			styleBoard(site, site.cost)
		end
		if site.label then
			styleName(site, site.label)
		end
		if site.moonSign then
			styleMoon(site.moonSign)
		end
	end

	return api
end
