--!strict
--[[
	ВИТРИНЫ И ОБЛИКИ (модуль Showcase).
	1. На витринах магазина в лобби вместо цветных шаров стоят фигурки, по которым видно, что покупаешь:
	   - облик зомби: зомби в цветах облика и со всеми его украшениями (рога, крылья, корона, искры);
	   - след: бегун, за которым тянется лента в цветах этого следа.
	2. Те же украшения надеваются на игрока, когда он становится зомби в купленном облике.
	   Кто только что надел облик в лобби, несколько секунд видит его на себе.
	Модуль отвечает только за вид. Покупки, цены и подписи остаются за главным скриптом;
	без этого модуля на витринах остаются шары, а облик - это только цвет подсветки зомби.
	Подсветок (Highlight) на витринах нет нарочно: игра показывает только 31 подсветку сразу,
	и все они нужны зомби в городе.
]]

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
local SCALE = 0.68   -- рост фигурки относительно игрока: под подписью витрины помещается 3.6 шага
local RIBBON = 4.2   -- длина ленты следа за бегуном
local STYLE = true   -- украшения обликов на зомби-игроках (false: облик - только цвет, как раньше)
local PREVIEW = 10   -- сколько секунд игрок видит на себе облик, который только что надел в лобби (0 - не показывать)
local LIFT = 0.9     -- на сколько шагов выше висят подписи витрин с обликами: под ними помещаются рога и короны

-- ТЕКСТЫ. Они добавляются к общим текстам игры (модуль Texts).
local TEXT: { [string]: { [string]: string } } = {
	en = {
		sc_look = "🧟 This is your zombie look!",
	},
	ru = {
		sc_look = "🧟 Так ты выглядишь, когда станешь зомби!",
	},
	es = {
		sc_look = "🧟 ¡Así te ves cuando eres zombi!",
	},
	pt = {
		sc_look = "🧟 É assim que você fica como zumbi!",
	},
	fr = {
		sc_look = "🧟 Voilà ton look de zombie!",
	},
	de = {
		sc_look = "🧟 So siehst du als Zombie aus!",
	},
	it = {
		sc_look = "🧟 Ecco il tuo aspetto da zombie!",
	},
	pl = {
		sc_look = "🧟 Tak wyglądasz jako zombie!",
	},
	tr = {
		sc_look = "🧟 Zombi olunca böyle görünürsün!",
	},
	id = {
		sc_look = "🧟 Begini penampilanmu saat jadi zombi!",
	},
	vi = {
		sc_look = "🧟 Đây là diện mạo zombie của bạn!",
	},
	th = {
		sc_look = "🧟 นี่คือหน้าตาของคุณตอนเป็นซอมบี้!",
	},
	ko = {
		sc_look = "🧟 좀비가 되면 이런 모습이에요!",
	},
	ja = {
		sc_look = "🧟 ゾンビになるとこの姿になるよ!",
	},
}

return function(ctx: any): any
	local map = workspace:FindFirstChild(ctx.mapName or "ZombieTagMap")
	local lobby = if map then map:FindFirstChild("Lobby") else nil
	if not map or not lobby or type(ctx.items) ~= "table" then
		return nil
	end
	local byId: { [string]: any } = {}
	for _, item in ipairs(ctx.items) do
		byId[item.id] = item
	end
	-- тексты модуля становятся обычными текстами игры
	do
		local home = script.Parent
		local shared = if home then home:FindFirstChild("Texts") else nil
		local all: any = if shared then (require :: any)(shared) else nil
		if type(all) == "table" then
			for lang, set in pairs(TEXT) do
				local target = all[lang]
				if type(target) == "table" then
					for key, text in pairs(set) do
						target[key] = text
					end
				end
			end
		end
	end

	local world = Instance.new("Model")
	world.Name = "Showcase"
	world.Parent = map

	local WHITE = Color3.fromRGB(255, 255, 255)
	local BLACK = Color3.fromRGB(20, 20, 24)
	-- бегун одет как всем знакомый новичок Roblox: жёлтая голова и руки, синяя рубашка, зелёные штаны
	local SKIN = Color3.fromRGB(245, 205, 48)
	local SHIRT = Color3.fromRGB(13, 105, 172)
	local PANTS = Color3.fromRGB(75, 151, 75)

	local function mix(a: Color3, b: Color3, t: number): Color3
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end

	---------------------------------------------------------------------
	-- ОБЛИКИ ЗОМБИ. У каждого облика свой набор украшений. Один и тот же набор надевается
	-- на зомби-игрока в городе (детали приварены к голове и телу) и на фигурку на витрине (детали стоят на месте).
	-- Размеры и места заданы в шагах обычного игрока: голова - от её середины (макушка +0.6, лицо -0.6 по Z),
	-- тело - от середины туловища (плечи +1, спина +0.5 по Z).
	---------------------------------------------------------------------
	type Mount = { part: BasePart, at: CFrame }
	local NEON = Enum.Material.Neon
	local SIDES = { -1, 1 }
	local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
	local FIRE = "rbxasset://textures/particles/fire_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

	-- head и body - куда крепить, feet - земля под ногами игрока (у фигурки её нет: там свой круг),
	-- s - рост (1 у игрока, SCALE у фигурки), fixed - детали стоят на месте (фигурка) или приварены к телу (игрок)
	local function wear(item: any, head: Mount, body: Mount, feet: Mount?, s: number, parent: Instance, fixed: boolean)
		local a: Color3, b: Color3 = item.colorA, item.colorB
		local id: string = item.id
		-- смещение в шагах игрока
		local function at(x: number, y: number, z: number): CFrame
			return CFrame.new(x * s, y * s, z * s)
		end
		local function Z(angle: number): CFrame
			return CFrame.Angles(0, 0, angle)
		end
		local function Y(angle: number): CFrame
			return CFrame.Angles(0, angle, 0)
		end
		local function X(angle: number): CFrame
			return CFrame.Angles(angle, 0, 0)
		end
		-- деталь: сквозь неё проходят, кнопкам и лучам она не мешает, веса у неё нет
		local function add(mount: Mount, shape: string, x: number, y: number, z: number, where: CFrame, color: Color3, material: Enum.Material?, clear: number?): BasePart
			local part: BasePart
			if shape == "wedge" then
				part = Instance.new("WedgePart")
			else
				local plain = Instance.new("Part")
				if shape == "ball" then
					plain.Shape = Enum.PartType.Ball
				elseif shape == "tube" then
					plain.Shape = Enum.PartType.Cylinder
				end
				plain.TopSurface = Enum.SurfaceType.Smooth
				plain.BottomSurface = Enum.SurfaceType.Smooth
				part = plain
			end
			part.Name = "Style"
			part.Anchored = fixed
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
			part.Size = Vector3.new(x, y, z) * s
			part.CFrame = mount.at * where
			part.Color = color
			part.Material = material or Enum.Material.SmoothPlastic
			part.Transparency = clear or 0
			part.Parent = parent
			if not fixed then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = mount.part
				weld.Part1 = part
				weld.Parent = part
			end
			return part
		end
		-- невидимый объём, из которого летят частицы
		local function cloud(mount: Mount, x: number, y: number, z: number, where: CFrame): BasePart
			local part = add(mount, "block", x, y, z, where, WHITE, nil, 1)
			part.Name = "Cloud"
			return part
		end
		-- частицы: сколько в секунду, сколько живут, с какой скоростью летят, размер в начале и в конце, цвета
		local function spray(on: BasePart, texture: string, rate: number, life0: number, life1: number, speed0: number, speed1: number, size0: number, size1: number, c0: Color3, c1: Color3): ParticleEmitter
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Fx"
			emitter.Texture = texture
			emitter.Rate = rate
			emitter.Lifetime = NumberRange.new(life0, life1)
			emitter.Speed = NumberRange.new(speed0 * s, speed1 * s)
			emitter.Size = NumberSequence.new(size0 * s, size1 * s)
			emitter.Color = ColorSequence.new(c0, c1)
			emitter.Transparency = NumberSequence.new(0, 1)
			emitter.LightEmission = 0.6 -- не чистое свечение: такие частицы видны и днём на светлом фоне
			emitter.LightInfluence = 0
			emitter.SpreadAngle = Vector2.new(25, 25)
			pcall(function()
				-- частицы рождаются во всём объёме, а не только на верхней грани
				emitter.Shape = Enum.ParticleEmitterShape.Box
				emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				emitter.Brightness = 2
			end)
			emitter.Parent = on
			return emitter
		end
		-- свет от облика: только на игроке (на витринах света хватает)
		local function lamp(on: BasePart, color: Color3, range: number, power: number)
			if fixed then
				return
			end
			local light = Instance.new("PointLight")
			light.Name = "Fx"
			light.Color = color
			light.Range = range * s
			light.Brightness = power
			light.Shadows = false
			light.Parent = on
		end
		-- светящиеся глаза
		local function eyes(color: Color3, wide: number?, tall: number?)
			for _, side in ipairs(SIDES) do
				add(head, "block", wide or 0.22, tall or 0.2, 0.08, at(0.24 * side, 0.14, -0.6), color, NEON)
			end
		end
		-- кольцо из прямых кусочков: середина, радиус, толщина
		local function ring(mount: Mount, where: CFrame, radius: number, thick: number, color: Color3, material: Enum.Material?, clear: number?)
			local count = if radius > 1 then 12 else 8
			local length = 2 * radius * math.tan(math.pi / count) + thick * 0.6
			for k = 0, count - 1 do
				add(mount, "block", length, thick, thick, where * Y(k * 2 * math.pi / count) * at(0, 0, -radius), color, material, clear)
			end
		end
		-- крылья за спиной: по четыре пера веером с каждой стороны, кончики светятся
		local function wings(feather: Color3, tip: Color3, material: Enum.Material?, clear: number?)
			for _, side in ipairs(SIDES) do
				for k, blade in ipairs({ { 0.4, 3 }, { 0.72, 2.7 }, { 1.04, 2.3 }, { 1.36, 1.8 } }) do
					local angle, length = blade[1], blade[2]
					local root = at(0.45 * side, 0.5, 0.6 + k * 0.04) * X(0.2) * Z(-angle * side)
					add(body, "block", 0.62, length, 0.08, root * at(0, length / 2, 0), feather, material, clear)
					add(body, "block", 0.5, 0.36, 0.1, root * at(0, length + 0.1, 0) * Z(math.pi / 4), tip, NEON)
				end
			end
		end
		-- звезда: два светящихся квадрата крест-накрест
		local function star(mount: Mount, where: CFrame, size: number, color: Color3)
			add(mount, "block", size, size, 0.07, where, color, NEON)
			add(mount, "block", size, size, 0.07, where * Z(math.pi / 4), color, NEON)
		end

		-- светящийся круг под ногами: зомби в купленном облике видно издалека
		if feet then
			ring(feet, at(0, 0.12, 0), 2.2, 0.14, a, NEON, 0.15)
			add(feet, "tube", 0.05, 4.2, 4.2, at(0, 0.05, 0) * Z(math.pi / 2), a, NEON, 0.8)
		end

		if id == "skin_crimson" then
			-- БАГРОВЫЙ: демон. Изогнутые рога с раскалёнными кончиками, шипы на плечах, угольки.
			local hot = Color3.fromRGB(255, 120, 60)
			eyes(Color3.fromRGB(255, 70, 40))
			for _, side in ipairs(SIDES) do
				add(head, "block", 0.36, 0.54, 0.36, at(0.38 * side, 0.78, -0.04) * Z(-0.5 * side), b)
				add(head, "block", 0.27, 0.5, 0.27, at(0.62 * side, 1.12, -0.04) * Z(-0.15 * side), mix(b, a, 0.45))
				add(head, "block", 0.18, 0.44, 0.18, at(0.63 * side, 1.5, -0.04) * Z(0.34 * side), hot, NEON)
				add(body, "block", 0.4, 0.7, 0.4, at(1.5 * side, 1.26, 0) * Z(-0.5 * side), b)
				add(body, "block", 0.22, 0.4, 0.22, at(1.76 * side, 1.68, 0) * Z(-0.5 * side), hot, NEON)
			end
			-- хвост с наконечником
			local tail = at(0, -0.85, 0.5) * X(-0.9)
			add(body, "block", 0.22, 1.2, 0.22, tail * at(0, -0.6, 0), b)
			tail = tail * at(0, -1.2, 0) * X(1.1)
			add(body, "block", 0.18, 1, 0.18, tail * at(0, -0.5, 0), mix(b, a, 0.45))
			add(body, "block", 0.4, 0.4, 0.14, tail * at(0, -1.1, 0) * Z(math.pi / 4), hot, NEON)
			local embers = spray(cloud(body, 2.6, 2.4, 1.3, at(0, -0.3, 0)), SPARK, 12, 0.8, 1.4, 1.5, 3, 0.55, 0, Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 40, 20))
			embers.Acceleration = Vector3.new(0, 3 * s, 0)
		elseif id == "skin_frost" then
			-- ЛЕДЯНОЙ: корона из льдин, кристаллы на плечах, идёт снег.
			local ice = Color3.fromRGB(175, 232, 255)
			eyes(Color3.fromRGB(150, 240, 255))
			for _, shard in ipairs({ { -1.05, 0.5 }, { -0.52, 0.68 }, { 0, 0.86 }, { 0.52, 0.68 }, { 1.05, 0.5 } }) do
				local turn, tall = shard[1], shard[2]
				add(head, "block", 0.2, tall, 0.2, Y(-turn) * at(0, 0.5 + tall / 2, -0.46) * X(-0.3), ice, Enum.Material.Ice, 0.12)
			end
			for _, side in ipairs(SIDES) do
				add(body, "block", 0.36, 0.95, 0.36, at(1.42 * side, 1.3, 0.05) * Z(-0.5 * side), ice, Enum.Material.Ice, 0.12)
				add(body, "block", 0.26, 0.62, 0.26, at(1.05 * side, 1.25, 0.22) * Z(-0.15 * side) * X(0.3), a, Enum.Material.Ice, 0.12)
				add(body, "block", 0.22, 0.5, 0.22, at(1.8 * side, 1.08, -0.05) * Z(-1 * side), WHITE, Enum.Material.Ice, 0.12)
			end
			for k = 0, 2 do
				add(body, "block", 0.3 - k * 0.04, 0.8 - k * 0.14, 0.3 - k * 0.04, at(0, 0.7 - k * 0.6, 0.6) * X(0.9), if k == 1 then WHITE else ice, Enum.Material.Ice, 0.12)
			end
			local snow = spray(cloud(head, 3, 0.3, 3, at(0, 1.5, 0)), SPARK, 14, 1.2, 1.8, 1, 2, 0.36, 0.12, WHITE, ice)
			snow.EmissionDirection = Enum.NormalId.Bottom
			snow.Acceleration = Vector3.new(0, -2 * s, 0)
			snow.Drag = 1
		elseif id == "skin_shadow" then
			-- ТЕНЬ: тёмные крылья с лиловыми кончиками, огоньки над плечами, чёрный дым.
			local dark = Color3.fromRGB(28, 10, 46)
			eyes(Color3.fromRGB(200, 100, 255))
			wings(dark, a, nil, nil)
			for _, side in ipairs(SIDES) do
				local orb = add(body, "ball", 0.3, 0.3, 0.3, at(1.55 * side, 1.85, 0.1), a, NEON)
				lamp(orb, a, 6, 0.8)
			end
			local smoke = spray(cloud(body, 2.2, 2.8, 1.2, at(0, -0.4, 0.2)), SMOKE, 7, 1, 1.7, 0.6, 1.6, 0.9, 2, Color3.fromRGB(70, 25, 110), Color3.fromRGB(8, 0, 16))
			smoke.LightEmission = 0
			smoke.Transparency = NumberSequence.new(0.55, 1)
			smoke.RotSpeed = NumberRange.new(-40, 40)
			smoke.Rotation = NumberRange.new(0, 360)
		elseif id == "skin_gold" then
			-- ЗОЛОТОЙ: корона с камнями, золотые наплечники, медальон, блеск.
			local gold = Color3.fromRGB(255, 200, 55)
			local gem = Color3.fromRGB(255, 70, 90)
			eyes(Color3.fromRGB(255, 235, 130))
			add(head, "tube", 0.26, 1.42, 1.42, at(0, 0.68, 0) * Z(math.pi / 2), gold, Enum.Material.Metal)
			for k = 0, 5 do
				local turn = Y(k * math.pi / 3)
				add(head, "block", 0.26, 0.46, 0.1, turn * at(0, 0.98, -0.62), gold, Enum.Material.Metal)
				add(head, "ball", 0.18, 0.18, 0.18, turn * at(0, 1.27, -0.62), if k % 2 == 0 then gem else WHITE, NEON)
			end
			add(head, "block", 0.2, 0.2, 0.08, at(0, 0.68, -0.73) * Z(math.pi / 4), gem, NEON)
			for _, side in ipairs(SIDES) do
				add(body, "block", 1.2, 0.3, 1.2, at(1.5 * side, 1.14, 0) * Z(-0.12 * side), gold, Enum.Material.Metal)
				add(body, "block", 0.8, 0.16, 0.8, at(1.55 * side, 1.34, 0) * Z(-0.12 * side), b, Enum.Material.Metal)
				add(body, "ball", 0.3, 0.3, 0.3, at(1.6 * side, 1.5, 0), gem, NEON)
			end
			-- королевский плащ
			local cape = at(0, 1, 0.56) * X(-0.16)
			add(body, "block", 2.5, 3.5, 0.1, cape * at(0, -1.75, 0), Color3.fromRGB(150, 20, 45), Enum.Material.Fabric)
			add(body, "block", 2.56, 0.3, 0.14, cape * at(0, -3.4, 0), gold, Enum.Material.Metal)
			add(body, "block", 2.56, 0.22, 0.14, cape * at(0, -0.1, 0), gold, Enum.Material.Metal)
			add(body, "tube", 0.1, 0.62, 0.62, at(0, 0.3, -0.54) * Y(math.pi / 2), gold, Enum.Material.Metal)
			add(body, "ball", 0.3, 0.3, 0.3, at(0, 0.3, -0.6), gem, NEON)
			local aura = cloud(body, 3, 3.6, 1.6, at(0, 0, 0))
			local shine = spray(aura, SPARK, 12, 0.7, 1.2, 0.4, 1.6, 0.6, 0, Color3.fromRGB(255, 240, 170), gold)
			shine.SpreadAngle = Vector2.new(180, 180)
			lamp(aura, gold, 9, 0.9)
		elseif id == "skin_neon" then
			-- НЕОН: светящийся визор, антенна, кольца вокруг тела, электрические искры.
			local cyan = Color3.fromRGB(70, 235, 255)
			add(head, "block", 1.16, 0.24, 0.14, at(0, 0.16, -0.6), a, NEON)
			add(head, "block", 0.5, 0.06, 0.16, at(0, 0.16, -0.6), WHITE, NEON)
			for _, side in ipairs(SIDES) do
				add(head, "tube", 0.16, 0.44, 0.44, at(0.66 * side, 0.12, 0), cyan, NEON)
			end
			add(head, "block", 0.07, 0.62, 0.07, at(0.66, 0.6, 0) * Z(-0.15), BLACK)
			add(head, "ball", 0.18, 0.18, 0.18, at(0.71, 0.94, 0), a, NEON)
			ring(body, at(0, -0.75, 0) * X(0.3) * Z(0.2), 1.8, 0.14, cyan, NEON, 0.05)
			ring(body, at(0, 0.2, 0) * X(-0.3) * Z(-0.25), 2.05, 0.12, a, NEON, 0.05)
			add(body, "ball", 0.42, 0.42, 0.42, at(0, 0.35, -0.48), cyan, NEON)
			for k = 0, 2 do
				add(body, "block", 1.5 - k * 0.4, 0.14, 0.1, at(0, 0.65 - k * 0.5, 0.54), if k % 2 == 0 then a else cyan, NEON)
			end
			local aura = cloud(body, 3.2, 3.2, 2.4, at(0, -0.2, 0))
			local sparks = spray(aura, SPARK, 14, 0.25, 0.5, 3, 6, 0.46, 0, cyan, a)
			sparks.SpreadAngle = Vector2.new(180, 180)
			lamp(aura, a, 10, 1)
		elseif id == "skin_ghost" then
			-- ПРИЗРАК: нимб, рваный светящийся плащ, огоньки-духи с туманом.
			local pale = Color3.fromRGB(210, 235, 255)
			eyes(Color3.fromRGB(190, 240, 255), 0.26, 0.26)
			ring(head, X(0.16) * at(0, 1.2, 0), 0.72, 0.1, WHITE, NEON)
			for k, strip in ipairs({ { -0.66, 2.5, 0.1 }, { -0.22, 3, -0.04 }, { 0.22, 2.8, 0.05 }, { 0.66, 2.4, -0.1 } }) do
				local x, length, lean = strip[1], strip[2], strip[3]
				add(body, "block", 0.42, length, 0.06, at(x, 0.9, 0.6) * X(-0.2) * Z(lean + x * 0.12) * at(0, -length / 2, 0), if k % 2 == 0 then pale else a, NEON, 0.55)
			end
			for _, wisp in ipairs({ { -1.7, 2, 0.3, 0.4 }, { 1.8, 1.3, 0.5, 0.34 }, { 0.9, 2.9, 0.8, 0.28 }, { -2.1, 0.2, 0.6, 0.3 }, { 2.2, -0.4, 0.4, 0.26 } }) do
				local orb = add(body, "ball", wisp[4], wisp[4], wisp[4], at(wisp[1], wisp[2], wisp[3]), pale, NEON, 0.1)
				local tail = spray(orb, SPARK, 8, 0.5, 0.9, 0.4, 1, 0.3, 0, WHITE, b)
				tail.SpreadAngle = Vector2.new(180, 180)
			end
			local low = cloud(body, 3, 1, 2, at(0, -2.2, 0))
			local mist = spray(low, SMOKE, 5, 1.4, 2.2, 0.3, 0.9, 1.3, 2.4, WHITE, pale)
			mist.Transparency = NumberSequence.new(0.78, 1)
			mist.LightEmission = 0.4
			mist.Rotation = NumberRange.new(0, 360)
			lamp(low, pale, 10, 0.8)
		elseif id == "skin_lava" then
			-- ЛАВА: раскалённые каменные наплечники и рога, гребень на спине, огонь и дым.
			local rock = Color3.fromRGB(255, 110, 30)
			local coal = Color3.fromRGB(46, 34, 32)
			local glow = Color3.fromRGB(255, 170, 50)
			eyes(glow)
			for _, side in ipairs(SIDES) do
				add(head, "block", 0.36, 0.5, 0.36, at(0.38 * side, 0.76, 0) * Z(-0.55 * side), coal, Enum.Material.Slate)
				add(head, "block", 0.22, 0.4, 0.22, at(0.62 * side, 1.08, 0) * Z(-0.2 * side), rock, Enum.Material.CrackedLava)
				local pad = add(body, "block", 1.36, 0.6, 1.36, at(1.5 * side, 1.22, 0) * Z(-0.14 * side) * Y(0.3 * side), rock, Enum.Material.CrackedLava)
				add(body, "block", 0.5, 0.9, 0.5, at(1.78 * side, 1.84, 0) * Z(-0.45 * side), coal, Enum.Material.Slate)
				add(body, "block", 0.24, 0.36, 0.24, at(2.04 * side, 2.3, 0) * Z(-0.45 * side), glow, NEON)
				local fire = spray(pad, FIRE, 12, 0.5, 0.9, 2.5, 4.5, 1.1, 0.3, Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 60, 10))
				fire.Rotation = NumberRange.new(0, 360)
				fire.Acceleration = Vector3.new(0, 4 * s, 0)
				fire.Transparency = NumberSequence.new(0.15, 1)
			end
			for k = 0, 2 do
				add(body, "block", 0.5 - k * 0.08, 0.5 - k * 0.08, 0.5 - k * 0.08, at(0, 0.75 - k * 0.62, 0.62) * X(math.pi / 4), if k == 1 then rock else coal, if k == 1 then Enum.Material.CrackedLava else Enum.Material.Slate)
			end
			for _, crack in ipairs({ { -0.3, 0.55, 0.5 }, { 0.12, 0.15, -0.6 }, { -0.1, -0.3, 0.45 } }) do
				add(body, "block", 0.62, 0.09, 0.06, at(crack[1], crack[2], -0.52) * Z(crack[3]), glow, NEON)
			end
			local smoke = spray(cloud(head, 1.2, 0.3, 1.2, at(0, 1.2, 0)), SMOKE, 5, 1.2, 1.9, 1.5, 2.5, 0.8, 2.2, Color3.fromRGB(90, 70, 60), Color3.fromRGB(20, 16, 16))
			smoke.LightEmission = 0
			smoke.Transparency = NumberSequence.new(0.6, 1)
			smoke.Rotation = NumberRange.new(0, 360)
			local low = cloud(body, 2.6, 0.4, 1.4, at(0, -2.6, 0))
			local embers = spray(low, SPARK, 8, 0.7, 1.3, 1.5, 3.5, 0.36, 0, glow, Color3.fromRGB(255, 50, 10))
			embers.Acceleration = Vector3.new(0, 4 * s, 0)
			lamp(add(body, "block", 0.2, 0.2, 0.2, at(0, 0.4, 0), WHITE, nil, 1), rock, 12, 1.4)
		elseif id == "skin_star" then
			-- ЗВЁЗДНЫЙ (подарок за дни в игре): крылья из света, венец из звёзд, звёздная пыль.
			local warm = Color3.fromRGB(255, 225, 120)
			eyes(WHITE, 0.24, 0.24)
			wings(a, WHITE, NEON, 0.3)
			for k = 0, 4 do
				star(head, Y(k * 2 * math.pi / 5 + math.pi) * at(0, 0.92, -1.02), 0.3, if k % 2 == 0 then warm else WHITE)
			end
			star(head, at(0, 1.26, 0), 0.46, warm)
			star(body, at(0, 0.35, -0.54), 0.6, warm)
			local aura = cloud(body, 3.4, 4, 2, at(0, 0.2, 0))
			local dust = spray(aura, SPARK, 14, 0.8, 1.4, 0.4, 1.8, 0.72, 0, WHITE, warm)
			dust.SpreadAngle = Vector2.new(180, 180)
			dust.RotSpeed = NumberRange.new(-90, 90)
			lamp(aura, warm, 11, 1.1)
		else
			-- облик, которого этот модуль ещё не знает: хотя бы светящиеся глаза в его цвете
			eyes(mix(a, WHITE, 0.4))
		end
	end

	---------------------------------------------------------------------
	-- ФИГУРКИ НА ВИТРИНАХ
	---------------------------------------------------------------------
	-- деталь фигурки: стоит на месте, сквозь неё проходят, кнопкам и лучам она не мешает
	local function piece(name: string, size: Vector3, at: CFrame, color: Color3, parent: Instance, material: Enum.Material?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size * SCALE
		part.CFrame = at
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end
	-- точка фигурки: шаги игрока от ступней, фигурка смотрит в сторону -Z своей основы
	local function spot(base: CFrame, x: number, y: number, z: number): CFrame
		return base * CFrame.new(x * SCALE, y * SCALE, z * SCALE)
	end
	-- рука или нога: висит от сустава вниз и повёрнута вперёд (угол больше нуля) или назад
	local function limb(name: string, base: CFrame, x: number, y: number, swing: number, color: Color3, tip: Color3, parent: Instance)
		local joint = spot(base, x, y, 0) * CFrame.Angles(swing, 0, 0)
		piece(name, Vector3.new(1, 1.5, 1), joint * CFrame.new(0, -0.75 * SCALE, 0), color, parent)
		-- кисть или ступня другого цвета
		piece(name .. "Tip", Vector3.new(1.02, 0.5, 1.02), joint * CFrame.new(0, -1.75 * SCALE, 0), tip, parent)
	end
	-- голова со ртом и глазами (eyes = nil: глаза добавит облик)
	local function head(base: CFrame, color: Color3, eyes: Color3?, parent: Instance): Part
		local part = piece("Head", Vector3.new(2, 1, 1), spot(base, 0, 4.6, 0), color, parent)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = part
		if eyes then
			for _, x in ipairs({ -0.24, 0.24 }) do
				piece("Eye", Vector3.new(0.2, 0.24, 0.08), spot(base, x, 4.72, -0.6), eyes, parent)
			end
		end
		piece("Mouth", Vector3.new(0.5, 0.08, 0.08), spot(base, 0, 4.36, -0.6), BLACK, parent)
		return part
	end
	-- светящийся круг под ногами фигурки
	local function disc(base: CFrame, color: Color3, parent: Instance)
		local part = piece("Disc", Vector3.new(0.16, 4.4, 4.4), spot(base, 0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), color, parent, Enum.Material.Neon)
		part.Shape = Enum.PartType.Cylinder
	end

	-- ОБЛИК ЗОМБИ: зомби с вытянутыми руками в цветах облика и со всеми его украшениями
	local function zombie(base: CFrame, item: any, parent: Instance)
		local fill: Color3, edge: Color3 = item.colorA, item.colorB
		local dim = mix(fill, edge, 0.3)
		disc(base, edge, parent)
		limb("Leg", base, -0.5, 2, 0.2, dim, edge, parent)
		limb("Leg", base, 0.5, 2, -0.14, dim, edge, parent)
		local torso = piece("Torso", Vector3.new(2, 2, 1), spot(base, 0, 3, 0), fill, parent)
		limb("Arm", base, -1.5, 4, 1.4, dim, edge, parent)
		limb("Arm", base, 1.5, 4, 1.62, dim, edge, parent)
		local top = head(base, mix(fill, WHITE, 0.18), nil, parent)
		wear(item, { part = top, at = top.CFrame }, { part = torso, at = torso.CFrame }, nil, SCALE, parent, true)
	end

	-- СЛЕД: бегун, за спиной которого тянется лента в цветах следа (как настоящий след в игре)
	local function runner(base: CFrame, item: any, parent: Instance)
		disc(base, item.colorA, parent)
		limb("Leg", base, -0.5, 2, 0.62, PANTS, PANTS, parent)
		limb("Leg", base, 0.5, 2, -0.55, PANTS, PANTS, parent)
		local torso = piece("Torso", Vector3.new(2, 2, 1), spot(base, 0, 3, 0), SHIRT, parent)
		limb("Arm", base, -1.5, 4, -0.62, SKIN, SKIN, parent)
		limb("Arm", base, 1.5, 4, 0.7, SKIN, SKIN, parent)
		head(base, SKIN, BLACK, parent)
		local from = Instance.new("Attachment")
		from.Name = "RibbonFrom"
		from.Position = Vector3.new(0, 0.1, 0.5 * SCALE)
		from.Orientation = Vector3.new(0, 0, 90) -- лента изгибается вверх и вниз, а не вбок
		from.Parent = torso
		local to = Instance.new("Attachment")
		to.Name = "RibbonTo"
		to.Position = Vector3.new(0, -0.15, 0.5 * SCALE + RIBBON)
		to.Orientation = Vector3.new(0, 0, 90)
		to.Parent = torso
		local ribbon = Instance.new("Beam")
		ribbon.Name = "Ribbon"
		ribbon.Attachment0 = from
		ribbon.Attachment1 = to
		ribbon.Color = if item.id == "trail_rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 100)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 150, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 255)),
			})
			else ColorSequence.new(item.colorA, item.colorB)
		ribbon.Transparency = NumberSequence.new(0, 1)
		ribbon.Width0 = 2.1 * SCALE
		ribbon.Width1 = 0.9 * SCALE
		ribbon.CurveSize0 = 0.8
		ribbon.CurveSize1 = 0.8
		ribbon.Segments = 16
		ribbon.FaceCamera = true
		ribbon.Brightness = 1.6 -- ярче неба за витриной: цвет следа читается и днём
		ribbon.LightEmission = 0.25
		ribbon.LightInfluence = 0
		ribbon.Parent = torso
	end

	local count = 0
	for _, stand in ipairs(lobby:GetChildren()) do
		if stand:IsA("BasePart") and stand.Name == "ShopStand" then
			-- что продаёт витрина, видно по имени её кнопки: Buy_<товар>
			local item: any = nil
			for _, child in ipairs(stand:GetChildren()) do
				if child:IsA("ProximityPrompt") and string.sub(child.Name, 1, 4) == "Buy_" then
					item = byId[string.sub(child.Name, 5)]
				end
			end
			if item then
				local figure = Instance.new("Model")
				figure.Name = "Figure_" .. item.id
				local feet = stand.Position + Vector3.new(0, stand.Size.Y / 2, 0)
				-- обе фигурки повёрнуты на четверть оборота: зомби со своей стены смотрит на покупателя,
				-- бегун у дальней стены стоит боком - так видно и его, и ленту следа
				local base = CFrame.new(feet) * CFrame.Angles(0, -math.pi / 2, 0)
				if item.kind == "skin" then
					zombie(base, item, figure)
				else
					runner(base, item, figure)
				end
				figure.Parent = world
				count += 1
			end
		elseif stand:IsA("BasePart") and stand.Name == "ShopSample" then
			stand.Transparency = 1 -- шар-образец больше не нужен
		elseif stand:IsA("BasePart") and stand.Name == "ShopSign" and LIFT ~= 0 and math.abs(stand.Position.X) > math.abs(stand.Position.Z) then
			stand.CFrame += Vector3.new(0, LIFT + 0.3, 0) -- вывеска над обликами: подписи под ней теперь висят выше
		end
	end

	---------------------------------------------------------------------
	-- ОБЛИК НА ИГРОКЕ. Раз в полсекунды модуль смотрит, кто сейчас зомби и в каком облике,
	-- и надевает или снимает украшения. Они лежат в модели ZT_Style внутри персонажа:
	-- исчезают вместе с ним и не видны самому игроку, когда он смотрит от первого лица.
	---------------------------------------------------------------------
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local LOBBY_Y: number = ctx.LOBBY_Y or 150
	local worn: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any         -- что сейчас надето на игроке
	local lastSkin: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any  -- какой облик был выбран в прошлый раз
	local showUntil: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- до какого времени игрок примеряет облик
	local forced: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any       -- проверка в Studio: облик надет всегда

	local function dress(character: Model, item: any, glow: boolean): Model?
		local top = character:FindFirstChild("Head")
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if not (top and top:IsA("BasePart") and torso and torso:IsA("BasePart")) then
			return nil
		end
		local s = character:GetScale()
		local style = Instance.new("Model")
		style.Name = "ZT_Style"
		-- земля под ногами: от середины корневой детали вниз
		local feet: Mount? = nil
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid then
			local down = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3 * s
			feet = { part = root, at = root.CFrame * CFrame.new(0, -down, 0) }
		end
		-- тело: середина туловища высотой в два шага (у новых фигурок верхняя часть туловища короче)
		wear(item, { part = top, at = top.CFrame }, { part = torso, at = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - s, 0) }, feet, s, style, false)
		if glow then
			-- примерка в лобби: тот же цвет, что будет у зомби в городе
			local light = Instance.new("Highlight")
			light.Name = "Glow"
			light.FillColor = item.colorA
			light.OutlineColor = item.colorB
			light.FillTransparency = 0.4
			light.DepthMode = Enum.HighlightDepthMode.Occluded
			light.Adornee = character
			light.Parent = style
		end
		style.Parent = character
		return style
	end
	local function strip(player: Player)
		local record = worn[player]
		if record then
			worn[player] = nil
			record.style:Destroy()
		end
	end
	local function update(player: Player, now: number)
		local session = sessions[player]
		local character = player.Character
		local root: BasePart? = ctx.getAlive(player)
		local want: any = nil
		local glow = false
		if session and character and root then
			local night: boolean = ctx.state()
			local id: string = session.profile.skin or ""
			local item: any = byId[id]
			if item and item.kind ~= "skin" then
				item = nil
			end
			if forced[player] then
				want = forced[player]
			elseif inRound[player] then
				if night and isZombie[player] then
					want = item
				end
			else
				-- игрок в лобби сменил облик: несколько секунд он видит его на себе
				if PREVIEW > 0 and item and lastSkin[player] ~= nil and lastSkin[player] ~= id and root.Position.Y > LOBBY_Y - 30 then
					showUntil[player] = now + PREVIEW
					ctx.toast(player, "sc_look")
				end
				if (showUntil[player] or 0) > now then
					want = item
					glow = not night -- пока идёт раунд, все подсветки нужны зомби в городе
				end
			end
			lastSkin[player] = id
		end
		local record = worn[player]
		if record and (record.item ~= want or record.character ~= character or record.style.Parent ~= character
			or record.glow ~= glow or (character and record.scale ~= character:GetScale())) then
			strip(player)
			record = nil
		end
		if want and character and not record then
			local style = dress(character, want, glow)
			if style then
				worn[player] = { item = want, character = character, style = style, glow = glow, scale = character:GetScale() }
			end
		end
	end

	-- Подписи витрин с обликами (их у каждого игрока свой набор) поднимаются повыше, один раз.
	-- Пометка о том, что подпись уже поднята, лежит на ней самой: так она не теряется.
	local function lift(player: Player)
		local hud: any = ctx.huds[player]
		local labels: any = if hud then hud.itemLabels else nil
		if type(labels) ~= "table" then
			return
		end
		for id, label in pairs(labels) do
			local item = byId[id]
			local board: Instance? = label.Parent
			if item and item.kind == "skin" and board and board:IsA("BillboardGui") then
				local was = board:GetAttribute("ZT_Lift")
				local done: number = if type(was) == "number" then was else 0
				if done ~= LIFT then
					board:SetAttribute("ZT_Lift", LIFT)
					board.StudsOffset += Vector3.new(0, LIFT - done, 0)
				end
			end
		end
	end

	local warned = -100
	local bots = map:FindFirstChild("Bots")
	task.spawn(function()
		local turn = 0
		while world.Parent do
			task.wait(0.5)
			local now = os.clock()
			turn += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = (pcall :: any)(function()
					if LIFT ~= 0 then
						lift(player)
					end
					if STYLE then
						update(player, now)
					end
				end)
				if not ok and now - warned > 60 then
					warned = now
					warn("[Zombie Tag] Showcase (style): " .. tostring(err))
				end
			end
			-- фигурки ботов иногда копируются с персонажа игрока: чужие украшения с них снимаются
			if turn % 4 == 0 and bots then
				for _, bot in ipairs(bots:GetChildren()) do
					local stray = bot:FindFirstChild("ZT_Style")
					if stray then
						stray:Destroy()
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pcall(strip, player)
	end)

	-- ТОЛЬКО В STUDIO: game.ServerStorage.ZT_Look:Invoke("skin_gold") надевает облик на первого игрока,
	-- :Invoke("") снимает. В опубликованной игре этот блок не выполняется.
	if STYLE and game:GetService("RunService"):IsStudio() then
		pcall(function()
			local storage = game:GetService("ServerStorage")
			local old = storage:FindFirstChild("ZT_Look")
			if old then
				old:Destroy()
			end
			local door = Instance.new("BindableFunction")
			door.Name = "ZT_Look"
			door.OnInvoke = function(id: string): string
				local player = Players:GetPlayers()[1]
				if not player then
					return "no player"
				end
				local item = byId[id]
				forced[player] = if item and item.kind == "skin" then item else nil
				return if forced[player] then "wearing " .. id else "off"
			end
			door.Parent = storage
		end)
	end

	return { world = world, count = count, wear = wear, dress = dress, worn = worn, update = update }
end
