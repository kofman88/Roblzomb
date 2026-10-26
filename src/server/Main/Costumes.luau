--!nocheck
--[[
	КОСТЮМЫ ЗА МОНЕТЫ (модуль Costumes, лежит рядом с Extras; Extras запускает его последним)

	- 4 костюма для людей и 4 для зомби: одежда (рубашка и штаны из тканей Nano Banana) + объёмные детали
	  (фуражка и рация, каска и баллон, катана, шлем космонавта; шапочка хирурга и стетоскоп, треуголка
	  и скелет попугая, бинты мумии, ирокез и гитара).
	- человеческий костюм надет всегда, когда игрок человек (лобби, дом, раунд); зомби-костюм - когда его поймали.
	- ГАРДЕРОБ в лобби: две вращающиеся витрины с манекенами и окно с карточками (купить / надеть / снять / примерить).
	- покупки хранятся вместе с остальными товарами (profile.owned): "cos_<id>" - куплено,
	  "cq_h_<id>" / "cq_z_<id>" - что сейчас надето у человека / у зомби.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- где стоит гардероб в лобби (центр площадки) и куда он смотрит
local WARDROBE_AT = Vector3.new(0, 150.5, 0)
local WARDROBE_FACE = Vector3.new(0, 0, -1) -- направление "вперёд" (к игрокам)
local PREVIEW_TIME = 12 -- примерка, секунд

-- картинки (Nano Banana -> портной -> Roblox): одежда и эмблемы для объёмных деталей
local IMG = {
	police = { shirt = "rbxassetid://94520983202004", pants = "rbxassetid://109382075517443" },
	ninja = { shirt = "rbxassetid://107709558994925", pants = "rbxassetid://72499373066416" },
	fire = { shirt = "rbxassetid://80689891012879", pants = "rbxassetid://128793412469996" },
	astro = { shirt = "rbxassetid://76166867801640", pants = "rbxassetid://89445300362584" },
	surgeon = { shirt = "rbxassetid://104310359048991", pants = "rbxassetid://79366198273853" },
	mummy = { shirt = "rbxassetid://109016964166109", pants = "rbxassetid://86312221733080" },
	pirate = { shirt = "rbxassetid://76635170318053", pants = "rbxassetid://137034774921152" },
	rocker = { shirt = "rbxassetid://137912121090505", pants = "rbxassetid://136668024831847" },
	e_fire = "rbxassetid://116846740145635",
	e_ninja = "rbxassetid://72975018807900",
	e_skull = "rbxassetid://94707870343137",
}

local TEXT = {
	en = {
		n_police = "Police Officer",
		n_ninja = "Ninja",
		n_fire = "Firefighter",
		n_astro = "Astronaut",
		n_surgeon = "Zombie Surgeon",
		n_mummy = "Mummy",
		n_pirate = "Zombie Pirate",
		n_rocker = "Zombie Rocker",
		d_police = "Cap, badge, aviators, radio and a duty belt",
		d_ninja = "Hood with an eye slit, headband, katana and stars",
		d_fire = "Helmet, reflective coat, air tank and an axe",
		d_astro = "Glass helmet with a gold visor and a life pack",
		d_surgeon = "Stained scrubs, cap, mask, stethoscope, syringe",
		d_mummy = "Ancient bandages, glowing eyes, scarab, sand",
		d_pirate = "Tricorn, eyepatch, hook, cutlass, parrot skeleton",
		d_rocker = "Neon mohawk, studded leather, guitar",
		title = "👗 WARDROBE",
		humans = "🧍 HUMANS",
		zombies = "🧟 ZOMBIES",
		hint_h = "You wear a human costume in the lobby, at home and while you run.",
		hint_z = "A zombie costume appears when you get caught.",
		buy = "BUY  %d 💰",
		wear = "WEAR",
		off = "TAKE OFF",
		try = "TRY ON",
		lvl = "🔒 LVL %d",
		msg_bought = "New costume! It's on you now 🎉",
		msg_worn = "Costume on ✓",
		msg_off = "Costume off",
		msg_try = "Trying on for %d seconds",
		err_coins = "Not enough coins: %d 💰 more",
		err_level = "Opens at level %d",
		err_wait = "Loading your progress, try again",
		err_bad = "Something went wrong",
		err_busy = "One moment...",
		zpreview = "zombie look shown for a moment",
	},
	ru = {
		n_police = "Полицейский",
		n_ninja = "Ниндзя",
		n_fire = "Пожарный",
		n_astro = "Космонавт",
		n_surgeon = "Зомби-хирург",
		n_mummy = "Мумия",
		n_pirate = "Зомби-пират",
		n_rocker = "Зомби-рокер",
		d_police = "Фуражка, жетон, очки, рация и пояс с кобурой",
		d_ninja = "Капюшон с прорезью, повязка, катана, сюрикены",
		d_fire = "Каска, костюм со светоотражателями, баллон, топор",
		d_astro = "Стеклянный шлем с золотым визором и ранец",
		d_surgeon = "Грязная форма, шапочка, маска, стетоскоп, шприц",
		d_mummy = "Древние бинты, светящиеся глаза, скарабей",
		d_pirate = "Треуголка, повязка, крюк, сабля, скелет попугая",
		d_rocker = "Неоновый ирокез, кожанка с шипами, гитара",
		title = "👗 ГАРДЕРОБ",
		humans = "🧍 ЛЮДИ",
		zombies = "🧟 ЗОМБИ",
		hint_h = "Костюм человека виден в лобби, дома и пока ты убегаешь.",
		hint_z = "Костюм зомби появляется, когда тебя поймали.",
		buy = "КУПИТЬ  %d 💰",
		wear = "НАДЕТЬ",
		off = "СНЯТЬ",
		try = "ПРИМЕРИТЬ",
		lvl = "🔒 УР. %d",
		msg_bought = "Новый костюм! Он уже на тебе 🎉",
		msg_worn = "Костюм надет ✓",
		msg_off = "Костюм снят",
		msg_try = "Примерка на %d секунд",
		err_coins = "Не хватает монет: ещё %d 💰",
		err_level = "Откроется на %d уровне",
		err_wait = "Загружаем прогресс, попробуй ещё раз",
		err_bad = "Что-то пошло не так",
		err_busy = "Секунду...",
		zpreview = "зомби-образ показан на миг",
	},
	es = {
		n_police = "Policía",
		n_ninja = "Ninja",
		n_fire = "Bombero",
		n_astro = "Astronauta",
		n_surgeon = "Cirujano zombi",
		n_mummy = "Momia",
		n_pirate = "Pirata zombi",
		n_rocker = "Rockero zombi",
		d_police = "Gorra, placa, gafas, radio y cinturón",
		d_ninja = "Capucha, cinta, katana y estrellas",
		d_fire = "Casco, traje reflectante, tanque y hacha",
		d_astro = "Casco de cristal con visor dorado y mochila",
		d_surgeon = "Uniforme sucio, gorro, mascarilla, jeringa",
		d_mummy = "Vendas antiguas, ojos brillantes, escarabajo",
		d_pirate = "Tricornio, parche, garfio, sable, loro esqueleto",
		d_rocker = "Cresta neón, cuero con tachas, guitarra",
		title = "👗 VESTUARIO",
		humans = "🧍 HUMANOS",
		zombies = "🧟 ZOMBIS",
		hint_h = "El traje humano se ve en el lobby, en casa y mientras corres.",
		hint_z = "El traje zombi aparece cuando te atrapan.",
		buy = "COMPRAR  %d 💰",
		wear = "PONER",
		off = "QUITAR",
		try = "PROBAR",
		lvl = "🔒 NIV %d",
		msg_bought = "¡Traje nuevo! Ya lo llevas 🎉",
		msg_worn = "Traje puesto ✓",
		msg_off = "Traje quitado",
		msg_try = "Probando %d segundos",
		err_coins = "Faltan monedas: %d 💰",
		err_level = "Se abre en el nivel %d",
		err_wait = "Cargando tu progreso",
		err_bad = "Algo salió mal",
		err_busy = "Un momento...",
		zpreview = "aspecto zombi por un momento",
	},
	pt = {
		n_police = "Policial",
		n_ninja = "Ninja",
		n_fire = "Bombeiro",
		n_astro = "Astronauta",
		n_surgeon = "Cirurgião zumbi",
		n_mummy = "Múmia",
		n_pirate = "Pirata zumbi",
		n_rocker = "Roqueiro zumbi",
		d_police = "Quepe, distintivo, óculos, rádio e cinto",
		d_ninja = "Capuz, faixa, katana e estrelas",
		d_fire = "Capacete, roupa refletiva, cilindro e machado",
		d_astro = "Capacete de vidro com viseira dourada",
		d_surgeon = "Uniforme sujo, touca, máscara, seringa",
		d_mummy = "Faixas antigas, olhos brilhantes, escaravelho",
		d_pirate = "Tricórnio, tapa-olho, gancho, sabre, papagaio",
		d_rocker = "Moicano neon, couro com tachas, guitarra",
		title = "👗 GUARDA-ROUPA",
		humans = "🧍 HUMANOS",
		zombies = "🧟 ZUMBIS",
		hint_h = "A roupa humana aparece no lobby, em casa e enquanto você foge.",
		hint_z = "A roupa zumbi aparece quando você é pego.",
		buy = "COMPRAR  %d 💰",
		wear = "VESTIR",
		off = "TIRAR",
		try = "PROVAR",
		lvl = "🔒 NÍV %d",
		msg_bought = "Roupa nova! Já está em você 🎉",
		msg_worn = "Roupa vestida ✓",
		msg_off = "Roupa tirada",
		msg_try = "Provando por %d segundos",
		err_coins = "Faltam moedas: %d 💰",
		err_level = "Abre no nível %d",
		err_wait = "Carregando seu progresso",
		err_bad = "Algo deu errado",
		err_busy = "Um momento...",
		zpreview = "visual zumbi por um momento",
	},
	de = {
		n_police = "Polizist",
		n_ninja = "Ninja",
		n_fire = "Feuerwehrmann",
		n_astro = "Astronaut",
		n_surgeon = "Zombie-Chirurg",
		n_mummy = "Mumie",
		n_pirate = "Zombie-Pirat",
		n_rocker = "Zombie-Rocker",
		d_police = "Mütze, Marke, Brille, Funkgerät, Gürtel",
		d_ninja = "Kapuze, Stirnband, Katana, Wurfsterne",
		d_fire = "Helm, Reflexjacke, Atemflasche, Axt",
		d_astro = "Glashelm mit Goldvisier und Rucksack",
		d_surgeon = "Schmutzige Kleidung, Haube, Maske, Spritze",
		d_mummy = "Alte Bandagen, leuchtende Augen, Skarabäus",
		d_pirate = "Dreispitz, Augenklappe, Haken, Säbel, Papagei",
		d_rocker = "Neon-Irokese, Nietenleder, Gitarre",
		title = "👗 GARDEROBE",
		humans = "🧍 MENSCHEN",
		zombies = "🧟 ZOMBIES",
		hint_h = "Das Menschenkostüm siehst du in der Lobby, zu Hause und auf der Flucht.",
		hint_z = "Das Zombiekostüm erscheint, wenn du gefangen wirst.",
		buy = "KAUFEN  %d 💰",
		wear = "ANZIEHEN",
		off = "AUSZIEHEN",
		try = "ANPROBE",
		lvl = "🔒 LVL %d",
		msg_bought = "Neues Kostüm! Du trägst es 🎉",
		msg_worn = "Kostüm an ✓",
		msg_off = "Kostüm aus",
		msg_try = "Anprobe für %d Sekunden",
		err_coins = "Zu wenig Münzen: noch %d 💰",
		err_level = "Ab Level %d",
		err_wait = "Fortschritt wird geladen",
		err_bad = "Etwas ist schiefgelaufen",
		err_busy = "Moment...",
		zpreview = "Zombie-Look kurz gezeigt",
	},
	fr = {
		n_police = "Policier",
		n_ninja = "Ninja",
		n_fire = "Pompier",
		n_astro = "Astronaute",
		n_surgeon = "Chirurgien zombie",
		n_mummy = "Momie",
		n_pirate = "Pirate zombie",
		n_rocker = "Rockeur zombie",
		d_police = "Casquette, insigne, lunettes, radio, ceinture",
		d_ninja = "Cagoule, bandeau, katana, shurikens",
		d_fire = "Casque, veste réfléchissante, bouteille, hache",
		d_astro = "Casque en verre à visière dorée et sac",
		d_surgeon = "Blouse tachée, calot, masque, seringue",
		d_mummy = "Bandelettes, yeux brillants, scarabée",
		d_pirate = "Tricorne, bandeau, crochet, sabre, perroquet",
		d_rocker = "Crête néon, cuir clouté, guitare",
		title = "👗 VESTIAIRE",
		humans = "🧍 HUMAINS",
		zombies = "🧟 ZOMBIES",
		hint_h = "Le costume humain se voit au lobby, à la maison et pendant la fuite.",
		hint_z = "Le costume zombie apparaît quand tu es attrapé.",
		buy = "ACHETER  %d 💰",
		wear = "PORTER",
		off = "RETIRER",
		try = "ESSAYER",
		lvl = "🔒 NIV %d",
		msg_bought = "Nouveau costume ! Tu le portes 🎉",
		msg_worn = "Costume porté ✓",
		msg_off = "Costume retiré",
		msg_try = "Essayage pendant %d secondes",
		err_coins = "Pas assez de pièces : encore %d 💰",
		err_level = "Débloqué au niveau %d",
		err_wait = "Chargement de ta progression",
		err_bad = "Un problème est survenu",
		err_busy = "Un instant...",
		zpreview = "look zombie montré un instant",
	},
}

local COSTUMES = {
	{ id = "police", side = "h", price = 450, color = Color3.fromRGB(70, 110, 220) },
	{ id = "ninja", side = "h", price = 900, color = Color3.fromRGB(220, 50, 60) },
	{ id = "fire", side = "h", price = 1400, color = Color3.fromRGB(255, 150, 40) },
	{ id = "astro", side = "h", price = 2200, level = 8, color = Color3.fromRGB(120, 200, 255) },
	{ id = "surgeon", side = "z", price = 450, color = Color3.fromRGB(60, 200, 190) },
	{ id = "mummy", side = "z", price = 900, color = Color3.fromRGB(230, 200, 130) },
	{ id = "pirate", side = "z", price = 1400, color = Color3.fromRGB(230, 60, 60) },
	{ id = "rocker", side = "z", price = 2200, level = 8, color = Color3.fromRGB(170, 255, 60) },
}
local BY_ID = {}
for _, c in ipairs(COSTUMES) do
	BY_ID[c.id] = c
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return function(ctx)
	local sessions = ctx.sessions

	local function lang(player: Player): string
		local id = string.lower(string.sub(player.LocaleId or "en", 1, 2))
		return if TEXT[id] then id else "en"
	end
	local function t(player: Player, key: string, ...): string
		local set = TEXT[lang(player)]
		local s = set[key] or TEXT.en[key] or key
		if select("#", ...) > 0 then
			s = string.format(s, ...)
		end
		return s
	end
	local function safely(what: string, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Zombie Tag] Costumes " .. what .. ": " .. tostring(err))
		end
		return ok
	end

	---------------------------------------------------------------------
	-- ДЕТАЛИ: всё приварено к частям тела, не мешает ходить и не ловит касания
	---------------------------------------------------------------------
	local function part(model: Instance, host: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: any?): BasePart
		local p
		if shape == "wedge" then
			p = Instance.new("WedgePart")
		else
			p = Instance.new("Part")
			if shape == "ball" then
				p.Shape = Enum.PartType.Ball
			elseif shape == "cyl" then
				p.Shape = Enum.PartType.Cylinder
			end
		end
		p.Name = name
		p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "egg" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.CFrame = host.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = p
		weld.Parent = p
		p:SetAttribute("ZT_Cos", true)
		p.Parent = model
		return p
	end
	-- цилиндр между двумя точками в системе детали-хозяина
	local function tube(model: Instance, host: BasePart, name: string, a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material?)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
		return part(model, host, name, Vector3.new(len, d, d), cf, color, material, "cyl")
	end
	local function label(p: BasePart, face: Enum.NormalId, s: string, color: Color3)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.LightInfluence = 0.4
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 120
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = s
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = color
		l.Parent = g
		g.Parent = p
	end
	local function decal(p: BasePart, face: Enum.NormalId, img: string?)
		if not img or img == "" then
			return
		end
		local d = Instance.new("Decal")
		d.Face = face
		d.Texture = img
		d.Parent = p
	end

	local GOLD, SILVER, BLACK = rgb(214, 168, 58), rgb(196, 200, 206), rgb(24, 24, 28)

	-- каждый строитель получает модель-папку и части тела; размеры берутся от тела (аватары бывают разные)
	local BUILD = {}

	BUILD.police = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local d = math.max(H.X, H.Z) * 1.06
		local top = H.Y / 2
		part(m, h, "CapCrown", Vector3.new(0.4 * k, d, d), CFrame.new(0, top + 0.02 * k, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(26, 38, 70), Enum.Material.Fabric, "cyl")
		part(m, h, "CapTop", Vector3.new(0.12 * k, d * 1.16, d * 1.16), CFrame.new(0, top + 0.24 * k, 0.03 * k) * CFrame.Angles(math.rad(-6), 0, math.pi / 2), rgb(30, 44, 80), Enum.Material.Fabric, "cyl")
		part(m, h, "CapBand", Vector3.new(0.13 * k, d * 1.02, d * 1.02), CFrame.new(0, top - 0.12 * k, 0) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.SmoothPlastic, "cyl")
		part(m, h, "CapVisor", Vector3.new(H.X * 0.9, 0.06 * k, 0.42 * k), CFrame.new(0, top - 0.16 * k, -H.Z / 2 - 0.12 * k) * CFrame.Angles(math.rad(14), 0, 0), rgb(12, 12, 14), Enum.Material.Glass, "egg").Reflectance = 0.25
		local badge = part(m, h, "CapBadge", Vector3.new(0.24 * k, 0.26 * k, 0.04), CFrame.new(0, top + 0.06 * k, -d / 2 - 0.02), GOLD, Enum.Material.Metal)
		badge.Reflectance = 0.2
		part(m, h, "CapCord", Vector3.new(H.X * 0.92, 0.04 * k, 0.04), CFrame.new(0, top - 0.06 * k, -d / 2 - 0.03), GOLD, Enum.Material.Metal)
		-- тёмные очки-авиаторы
		for _, sx in ipairs({ -1, 1 }) do
			part(m, h, "Lens", Vector3.new(0.3 * k, 0.2 * k, 0.04), CFrame.new(sx * 0.21 * k, 0.17 * k, -H.Z / 2 - 0.04), rgb(16, 18, 22), Enum.Material.SmoothPlastic, "egg").Reflectance = 0.12
		end
		part(m, h, "Bridge", Vector3.new(0.14 * k, 0.03 * k, 0.03), CFrame.new(0, 0.23 * k, -H.Z / 2 - 0.05), GOLD, Enum.Material.Metal)
		-- рация на груди
		local u, U = b.ut, b.ut.Size
		local radio = part(m, u, "Radio", Vector3.new(0.26, 0.46, 0.16), CFrame.new(-U.X * 0.3, U.Y * 0.22, -U.Z / 2 - 0.09), BLACK, Enum.Material.SmoothPlastic)
		part(m, radio, "RadioGrill", Vector3.new(0.2, 0.18, 0.02), CFrame.new(0, -0.08, -0.08), rgb(60, 62, 66), Enum.Material.DiamondPlate)
		part(m, radio, "RadioLed", Vector3.new(0.05, 0.05, 0.02), CFrame.new(0.07, 0.17, -0.08), rgb(60, 255, 90), Enum.Material.Neon)
		part(m, radio, "Antenna", Vector3.new(0.42, 0.05, 0.05), CFrame.new(-0.08, 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.SmoothPlastic, "cyl")
		tube(m, u, "RadioCord", Vector3.new(-U.X * 0.3, U.Y * 0.05, -U.Z / 2 - 0.08), Vector3.new(-U.X * 0.38, -U.Y * 0.45, -U.Z / 2 - 0.04), 0.035, BLACK)
		-- пояс: кобура, наручники, фонарик
		local l, L = b.lt, b.lt.Size
		local holster = part(m, l, "Holster", Vector3.new(0.22, 0.52, 0.34), CFrame.new(L.X / 2 + 0.1, -0.12, 0.05), rgb(18, 18, 20), Enum.Material.Fabric)
		part(m, holster, "Grip", Vector3.new(0.16, 0.24, 0.22), CFrame.new(0, 0.34, -0.04) * CFrame.Angles(math.rad(-10), 0, 0), rgb(48, 48, 52), Enum.Material.SmoothPlastic)
		part(m, holster, "Snap", Vector3.new(0.24, 0.06, 0.1), CFrame.new(0, 0.2, -0.05), SILVER, Enum.Material.Metal)
		for i = 0, 1 do
			part(m, l, "Cuff", Vector3.new(0.05, 0.28, 0.28), CFrame.new(L.X * 0.22 + i * 0.18, -0.06, L.Z / 2 + 0.06) * CFrame.Angles(0, math.pi / 2, 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.3
		end
		local torch = part(m, l, "Torch", Vector3.new(0.56, 0.14, 0.14), CFrame.new(-L.X / 2 - 0.08, -0.16, -0.1) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.Metal, "cyl")
		part(m, torch, "TorchLens", Vector3.new(0.04, 0.16, 0.16), CFrame.new(-0.3, 0, 0), rgb(255, 250, 210), Enum.Material.Neon, "cyl")
	end

	BUILD.fire = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local red = rgb(196, 30, 26)
		part(m, h, "HelmetDome", Vector3.new(H.X * 1.16, H.Y * 0.82, H.Z * 1.2), CFrame.new(0, H.Y * 0.3, 0.02 * k), red, Enum.Material.SmoothPlastic, "egg").Reflectance = 0.12
		part(m, h, "HelmetBrim", Vector3.new(H.X * 1.6, 0.1 * k, H.Z * 2.0), CFrame.new(0, H.Y * 0.08, 0.22 * k) * CFrame.Angles(math.rad(-4), 0, 0), red, Enum.Material.SmoothPlastic, "egg")
		part(m, h, "HelmetComb", Vector3.new(0.12 * k, 0.16 * k, H.Z * 1.0), CFrame.new(0, H.Y * 0.68, 0.04 * k), rgb(170, 22, 20), Enum.Material.SmoothPlastic)
		part(m, h, "HelmetTrim", Vector3.new(H.X * 1.6, 0.04 * k, H.Z * 2.0), CFrame.new(0, H.Y * 0.03, 0.22 * k) * CFrame.Angles(math.rad(-4), 0, 0), GOLD, Enum.Material.Metal, "egg")
		local shield = part(m, h, "HelmetShield", Vector3.new(0.46 * k, 0.5 * k, 0.06), CFrame.new(0, H.Y * 0.4, -H.Z * 0.6) * CFrame.Angles(math.rad(-16), 0, 0), rgb(30, 22, 16), Enum.Material.Leather)
		decal(shield, Enum.NormalId.Front, IMG.e_fire)
		part(m, h, "HelmetBolt", Vector3.new(0.1 * k, 0.1 * k, 0.04), CFrame.new(0, H.Y * 0.66, -H.Z * 0.5) * CFrame.Angles(math.rad(-16), 0, 0), GOLD, Enum.Material.Metal, "ball")
		-- баллон, ремни, топор, фонарь
		local u, U = b.ut, b.ut.Size
		local tank = part(m, u, "AirTank", Vector3.new(U.Y * 1.0, U.X * 0.34, U.X * 0.34), CFrame.new(0, -0.05, U.Z * 0.66) * CFrame.Angles(0, 0, math.pi / 2), rgb(206, 210, 216), Enum.Material.Metal, "cyl")
		tank.Reflectance = 0.25
		part(m, tank, "TankCap", Vector3.new(0.16, U.X * 0.2, U.X * 0.2), CFrame.new(U.Y * 0.52, 0, 0), rgb(40, 40, 44), Enum.Material.Metal, "cyl")
		part(m, tank, "TankValve", Vector3.new(0.14, 0.12, 0.12), CFrame.new(U.Y * 0.6, 0, 0), rgb(230, 190, 40), Enum.Material.Metal, "cyl")
		part(m, tank, "TankBand", Vector3.new(0.12, U.X * 0.35, U.X * 0.35), CFrame.new(-U.Y * 0.2, 0, 0), rgb(230, 200, 40), Enum.Material.SmoothPlastic, "cyl")
		for _, sx in ipairs({ -1, 1 }) do
			part(m, u, "Strap", Vector3.new(0.14, U.Y * 1.0, 0.06), CFrame.new(sx * U.X * 0.24, 0, -U.Z / 2 - 0.04), BLACK, Enum.Material.Fabric)
			part(m, u, "StrapTop", Vector3.new(0.14, 0.06, U.Z + 0.12), CFrame.new(sx * U.X * 0.24, U.Y / 2 + 0.02, 0), BLACK, Enum.Material.Fabric)
		end
		local axe = part(m, u, "AxeHandle", Vector3.new(1.9, 0.12, 0.12), CFrame.new(U.X * 0.08, 0.05, U.Z / 2 + 0.24) * CFrame.Angles(0, 0, math.rad(60)), rgb(150, 96, 52), Enum.Material.Wood, "cyl")
		part(m, axe, "AxeHead", Vector3.new(0.22, 0.42, 0.1), CFrame.new(0.9, 0.12, 0), red, Enum.Material.Metal)
		part(m, axe, "AxeBlade", Vector3.new(0.24, 0.12, 0.06), CFrame.new(0.9, 0.38, 0), SILVER, Enum.Material.Metal).Reflectance = 0.4
		part(m, axe, "AxePick", Vector3.new(0.08, 0.3, 0.06), CFrame.new(0.9, -0.3, 0), rgb(60, 60, 64), Enum.Material.Metal)
		local lamp = part(m, u, "Lamp", Vector3.new(0.24, 0.34, 0.18), CFrame.new(U.X * 0.26, U.Y * 0.2, -U.Z / 2 - 0.14) * CFrame.Angles(math.rad(-10), 0, 0), rgb(240, 200, 30), Enum.Material.SmoothPlastic)
		part(m, lamp, "LampLens", Vector3.new(0.16, 0.16, 0.03), CFrame.new(0, 0.06, -0.1), rgb(255, 250, 220), Enum.Material.Neon)
	end

	BUILD.ninja = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local cloth = rgb(26, 26, 32)
		-- капюшон и маска: щель для глаз остаётся открытой
		part(m, h, "Hood", Vector3.new(H.X * 1.07, 0.4 * k, H.Z * 1.07), CFrame.new(0, 0.46 * k, 0), cloth, Enum.Material.Fabric)
		part(m, h, "Mask", Vector3.new(H.X * 1.07, 0.64 * k, H.Z * 1.07), CFrame.new(0, -0.32 * k, 0), cloth, Enum.Material.Fabric)
		part(m, h, "HoodBack", Vector3.new(H.X * 1.07, 0.28 * k, H.Z * 1.0), CFrame.new(0, 0.13 * k, H.Z * 0.035), cloth, Enum.Material.Fabric)
		part(m, h, "MaskFold", Vector3.new(H.X * 1.08, 0.04 * k, H.Z * 1.08), CFrame.new(0, -0.1 * k, 0), rgb(14, 14, 18), Enum.Material.Fabric)
		part(m, h, "Headband", Vector3.new(H.X * 1.12, 0.12 * k, H.Z * 1.12), CFrame.new(0, 0.36 * k, 0), rgb(170, 24, 30), Enum.Material.Fabric)
		-- в прорези: тёмная полоса и нарисованные глаза (у "живых" голов глаза - часть модели и прячутся под капюшоном)
		part(m, h, "EyeBand", Vector3.new(H.X * 1.06, 0.27 * k, 0.04), CFrame.new(0, 0.13 * k, -H.Z * 0.52), rgb(40, 32, 30), Enum.Material.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			local eye = part(m, h, "Eye", Vector3.new(0.22 * k, 0.12 * k, 0.03), CFrame.new(sx * 0.19 * k, 0.13 * k, -H.Z * 0.54) * CFrame.Angles(0, 0, math.rad(sx * -8)), rgb(245, 245, 240), Enum.Material.SmoothPlastic, "egg")
			part(m, eye, "Pupil", Vector3.new(0.08 * k, 0.09 * k, 0.02), CFrame.new(-sx * 0.02 * k, -0.005 * k, -0.02), rgb(14, 14, 16), Enum.Material.SmoothPlastic, "egg")
			part(m, h, "Brow", Vector3.new(0.24 * k, 0.04 * k, 0.03), CFrame.new(sx * 0.19 * k, 0.22 * k, -H.Z * 0.545) * CFrame.Angles(0, 0, math.rad(sx * 14)), rgb(10, 10, 12), Enum.Material.SmoothPlastic)
		end
		local plate = part(m, h, "BandPlate", Vector3.new(0.4 * k, 0.16 * k, 0.04), CFrame.new(0, 0.36 * k, -H.Z * 0.57), rgb(150, 156, 164), Enum.Material.Metal)
		plate.Reflectance = 0.3
		decal(plate, Enum.NormalId.Front, IMG.e_ninja)
		for _, sx in ipairs({ -1, 1 }) do
			part(m, h, "BandTail", Vector3.new(0.12 * k, 0.75 * k, 0.03), CFrame.new(sx * 0.12 * k, 0.12 * k, H.Z * 0.6) * CFrame.Angles(math.rad(18), 0, math.rad(sx * 18)), rgb(170, 24, 30), Enum.Material.Fabric)
		end
		-- катана за спиной
		local u, U = b.ut, b.ut.Size
		local sheath = part(m, u, "Sheath", Vector3.new(0.14, 2.3, 0.1), CFrame.new(0, 0.1, U.Z / 2 + 0.1) * CFrame.Angles(0, 0, math.rad(-38)), rgb(16, 16, 18), Enum.Material.SmoothPlastic)
		sheath.Reflectance = 0.15
		part(m, sheath, "SheathTip", Vector3.new(0.16, 0.12, 0.12), CFrame.new(0, -1.15, 0), GOLD, Enum.Material.Metal)
		part(m, sheath, "Tsuba", Vector3.new(0.05, 0.36, 0.36), CFrame.new(0, 1.18, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, "cyl")
		local grip = part(m, sheath, "Grip", Vector3.new(0.13, 0.7, 0.13), CFrame.new(0, 1.55, 0), rgb(120, 20, 24), Enum.Material.Fabric)
		for i = -2, 2 do
			part(m, grip, "Wrap", Vector3.new(0.14, 0.05, 0.14), CFrame.new(0, i * 0.13, 0) * CFrame.Angles(0, math.rad(45), 0), BLACK, Enum.Material.Fabric)
		end
		part(m, grip, "Pommel", Vector3.new(0.15, 0.06, 0.15), CFrame.new(0, 0.37, 0), GOLD, Enum.Material.Metal)
		part(m, u, "Cord", Vector3.new(0.06, U.Y * 1.25, 0.04), CFrame.new(0, 0, -U.Z / 2 - 0.03) * CFrame.Angles(0, 0, math.rad(38)), rgb(120, 20, 24), Enum.Material.Fabric)
		-- сюрикены на поясе
		local l, L = b.lt, b.lt.Size
		for i = 0, 1 do
			local c = CFrame.new(-L.X * 0.32 + i * 0.26, -0.02, -L.Z / 2 - 0.05)
			part(m, l, "Star", Vector3.new(0.3, 0.06, 0.02), c * CFrame.Angles(0, 0, math.rad(45)), rgb(150, 156, 164), Enum.Material.Metal).Reflectance = 0.35
			part(m, l, "Star", Vector3.new(0.3, 0.06, 0.02), c * CFrame.Angles(0, 0, math.rad(-45)), rgb(150, 156, 164), Enum.Material.Metal).Reflectance = 0.35
			part(m, l, "StarHub", Vector3.new(0.03, 0.08, 0.08), c * CFrame.Angles(0, math.pi / 2, 0), BLACK, Enum.Material.Metal, "cyl")
		end
	end

	BUILD.astro = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local d = math.max(H.X, H.Y, H.Z) * 1.55
		local glass = part(m, h, "Helmet", Vector3.new(d, d, d), CFrame.new(0, 0.06 * k, 0), rgb(220, 235, 255), Enum.Material.Glass, "ball")
		glass.Transparency = 0.62
		glass.Reflectance = 0.15
		local visor = part(m, h, "Visor", Vector3.new(d * 0.84, d * 0.6, d * 0.52), CFrame.new(0, 0.1 * k, -d * 0.22), rgb(255, 186, 60), Enum.Material.Glass, "egg")
		visor.Transparency = 0.12
		visor.Reflectance = 0.5
		part(m, h, "Rim", Vector3.new(d * 0.98, d * 0.06, d * 0.98), CFrame.new(0, 0.06 * k - d * 0.36, 0), rgb(200, 206, 214), Enum.Material.Metal, "egg")
		for _, sx in ipairs({ -1, 1 }) do
			local lampHost = part(m, h, "HelmetLamp", Vector3.new(0.26 * k, 0.16 * k, 0.16 * k), CFrame.new(sx * d * 0.47, 0.22 * k, -0.12 * k), rgb(236, 238, 242), Enum.Material.SmoothPlastic, "cyl")
			part(m, lampHost, "LampGlow", Vector3.new(0.02, 0.12 * k, 0.12 * k), CFrame.new(0, 0, -0.08 * k) * CFrame.Angles(0, math.pi / 2, 0), rgb(255, 255, 230), Enum.Material.Neon, "cyl")
		end
		local u, U = b.ut, b.ut.Size
		part(m, u, "Collar", Vector3.new(0.2, U.X * 0.62, U.X * 0.62), CFrame.new(0, U.Y / 2 + 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(170, 178, 188), Enum.Material.Metal, "cyl").Reflectance = 0.2
		local pack = part(m, u, "Backpack", Vector3.new(U.X * 0.92, U.Y * 1.08, 0.56), CFrame.new(0, 0.06, U.Z / 2 + 0.3), rgb(238, 240, 244), Enum.Material.SmoothPlastic)
		part(m, pack, "PackTop", Vector3.new(U.X * 0.7, 0.14, 0.4), CFrame.new(0, U.Y * 0.56, 0), rgb(160, 168, 178), Enum.Material.Metal)
		part(m, pack, "PackVent", Vector3.new(U.X * 0.5, 0.34, 0.03), CFrame.new(0, -U.Y * 0.22, 0.29), rgb(80, 86, 94), Enum.Material.DiamondPlate)
		part(m, pack, "PackScreen", Vector3.new(0.3, 0.2, 0.03), CFrame.new(-U.X * 0.22, U.Y * 0.18, 0.29), rgb(20, 70, 50), Enum.Material.Neon)
		for _, sx in ipairs({ -1, 1 }) do
			part(m, pack, "SideTank", Vector3.new(U.Y * 0.9, 0.26, 0.26), CFrame.new(sx * (U.X * 0.46 + 0.1), 0, 0.02) * CFrame.Angles(0, 0, math.pi / 2), rgb(214, 218, 224), Enum.Material.Metal, "cyl")
			tube(m, u, "Hose", Vector3.new(sx * U.X * 0.4, -U.Y * 0.08, -U.Z / 2 - 0.06), Vector3.new(sx * (U.X / 2 + 0.12), U.Y * 0.18, U.Z / 2 + 0.12), 0.09, if sx < 0 then rgb(60, 120, 220) else rgb(220, 60, 60), Enum.Material.SmoothPlastic)
		end
		part(m, pack, "Antenna", Vector3.new(0.9, 0.04, 0.04), CFrame.new(U.X * 0.3, U.Y * 0.9, 0.1) * CFrame.Angles(0, 0, math.pi / 2), SILVER, Enum.Material.Metal, "cyl")
		part(m, pack, "AntennaTip", Vector3.new(0.09, 0.09, 0.09), CFrame.new(U.X * 0.3, U.Y * 0.9 + 0.46, 0.1), rgb(255, 40, 40), Enum.Material.Neon, "ball")
	end

	BUILD.surgeon = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local teal = rgb(64, 150, 146)
		part(m, h, "Cap", Vector3.new(H.X * 1.1, H.Y * 0.56, H.Z * 1.12), CFrame.new(0, H.Y * 0.34, 0.02 * k), teal, Enum.Material.Fabric, "egg")
		part(m, h, "CapTie", Vector3.new(0.18 * k, 0.1 * k, 0.1 * k), CFrame.new(0, H.Y * 0.22, H.Z * 0.56), teal, Enum.Material.Fabric, "egg")
		part(m, h, "Mirror", Vector3.new(0.04, 0.34 * k, 0.34 * k), CFrame.new(-0.16 * k, H.Y * 0.28, -H.Z * 0.58) * CFrame.Angles(math.rad(-12), math.pi / 2, 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.6
		part(m, h, "MirrorBand", Vector3.new(H.X * 1.12, 0.06 * k, H.Z * 1.12), CFrame.new(0, H.Y * 0.2, 0), BLACK, Enum.Material.SmoothPlastic)
		local mask = part(m, h, "Mask", Vector3.new(0.64 * k, 0.36 * k, 0.06), CFrame.new(0, -H.Y * 0.54, -H.Z * 0.36) * CFrame.Angles(math.rad(28), 0, 0), rgb(150, 200, 230), Enum.Material.Fabric)
		for _, sx in ipairs({ -1, 1 }) do
			tube(m, h, "MaskString", Vector3.new(sx * 0.3 * k, -H.Y * 0.5, -H.Z * 0.38), Vector3.new(sx * H.X * 0.53, -0.02 * k, 0), 0.03, rgb(240, 240, 240))
		end
		part(m, mask, "Stain", Vector3.new(0.2 * k, 0.14 * k, 0.02), CFrame.new(0.12 * k, -0.04 * k, -0.035), rgb(110, 150, 50), Enum.Material.SmoothPlastic, "egg")
		-- стетоскоп
		local u, U = b.ut, b.ut.Size
		local z = -U.Z / 2 - 0.05
		tube(m, u, "Tube", Vector3.new(-U.X * 0.2, U.Y * 0.5, z), Vector3.new(-U.X * 0.14, -U.Y * 0.1, z), 0.06, BLACK)
		tube(m, u, "Tube", Vector3.new(U.X * 0.2, U.Y * 0.5, z), Vector3.new(U.X * 0.06, U.Y * 0.04, z), 0.06, BLACK)
		tube(m, u, "Tube", Vector3.new(U.X * 0.06, U.Y * 0.04, z), Vector3.new(-U.X * 0.14, -U.Y * 0.1, z), 0.06, BLACK)
		tube(m, u, "Tube", Vector3.new(-U.X * 0.2, U.Y * 0.5, z), Vector3.new(U.X * 0.2, U.Y * 0.5, z + 0.05), 0.06, BLACK)
		part(m, u, "Chestpiece", Vector3.new(0.08, 0.24, 0.24), CFrame.new(-U.X * 0.14, -U.Y * 0.18, z - 0.02) * CFrame.Angles(0, math.pi / 2, 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.4
		-- шприц в плече
		local arm = b.lua
		if arm then
			local A = arm.Size
			local syr = part(m, arm, "Syringe", Vector3.new(0.5, 0.12, 0.12), CFrame.new(-A.X / 2 - 0.2, A.Y * 0.1, 0) * CFrame.Angles(0, 0, math.rad(-20)), rgb(230, 240, 245), Enum.Material.Glass, "cyl")
			syr.Transparency = 0.4
			part(m, syr, "Liquid", Vector3.new(0.3, 0.08, 0.08), CFrame.new(0.02, 0, 0), rgb(120, 255, 60), Enum.Material.Neon, "cyl")
			part(m, syr, "Plunger", Vector3.new(0.04, 0.18, 0.18), CFrame.new(-0.27, 0, 0), rgb(250, 250, 250), Enum.Material.SmoothPlastic, "cyl")
			part(m, syr, "Needle", Vector3.new(0.24, 0.02, 0.02), CFrame.new(0.36, 0, 0), SILVER, Enum.Material.Metal, "cyl")
		end
	end

	BUILD.mummy = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local linen = rgb(214, 202, 172)
		part(m, h, "Wrap", Vector3.new(H.X * 1.05, H.Y * 1.04, H.Z * 1.05), CFrame.new(0, 0, 0), linen, Enum.Material.Fabric)
		local r = Random.new(7)
		for i = 0, 5 do
			local y = (-0.5 + i * 0.2) * H.Y
			part(m, h, "Strip", Vector3.new(H.X * 1.09, 0.1 * k, H.Z * 1.09), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(r:NextNumber(-9, 9))) * CFrame.Angles(math.rad(r:NextNumber(-6, 6)), 0, 0), if i % 2 == 0 then rgb(196, 184, 150) else rgb(224, 214, 186), Enum.Material.Fabric)
		end
		part(m, h, "EyeGap", Vector3.new(0.7 * k, 0.16 * k, 0.02), CFrame.new(0, 0.1 * k, -H.Z * 0.555), rgb(20, 14, 10), Enum.Material.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			part(m, h, "Eye", Vector3.new(0.14 * k, 0.07 * k, 0.02), CFrame.new(sx * 0.17 * k, 0.1 * k, -H.Z * 0.565), rgb(255, 196, 40), Enum.Material.Neon, "egg")
		end
		part(m, h, "Tail", Vector3.new(0.12 * k, 0.7 * k, 0.03), CFrame.new(0.2 * k, -0.2 * k, H.Z * 0.56) * CFrame.Angles(math.rad(14), 0, math.rad(12)), linen, Enum.Material.Fabric)
		part(m, h, "Tail", Vector3.new(0.1 * k, 0.5 * k, 0.03), CFrame.new(-0.1 * k, -0.1 * k, H.Z * 0.56) * CFrame.Angles(math.rad(10), 0, math.rad(-20)), rgb(196, 184, 150), Enum.Material.Fabric)
		-- скарабей на груди
		local u, U = b.ut, b.ut.Size
		local z = -U.Z / 2 - 0.04
		tube(m, u, "Chain", Vector3.new(-U.X * 0.22, U.Y * 0.5, z), Vector3.new(0, U.Y * 0.08, z), 0.04, GOLD, Enum.Material.Metal)
		tube(m, u, "Chain", Vector3.new(U.X * 0.22, U.Y * 0.5, z), Vector3.new(0, U.Y * 0.08, z), 0.04, GOLD, Enum.Material.Metal)
		local disc = part(m, u, "Amulet", Vector3.new(0.06, 0.42, 0.42), CFrame.new(0, -U.Y * 0.04, z - 0.02) * CFrame.Angles(0, math.pi / 2, 0), GOLD, Enum.Material.Metal, "cyl")
		disc.Reflectance = 0.3
		part(m, u, "Scarab", Vector3.new(0.22, 0.3, 0.12), CFrame.new(0, -U.Y * 0.04, z - 0.07), rgb(30, 170, 160), Enum.Material.Glass, "egg").Reflectance = 0.3
		-- свисающие бинты и песок
		if b.rla then
			part(m, b.rla, "Loose", Vector3.new(0.14, 0.9, 0.03), CFrame.new(b.rla.Size.X / 2 + 0.03, -0.4, 0) * CFrame.Angles(0, 0, math.rad(8)), linen, Enum.Material.Fabric)
		end
		if b.lul then
			part(m, b.lul, "Loose", Vector3.new(0.14, 0.7, 0.03), CFrame.new(-b.lul.Size.X / 2 - 0.03, -0.4, 0) * CFrame.Angles(0, 0, math.rad(-6)), rgb(196, 184, 150), Enum.Material.Fabric)
		end
		local sand = Instance.new("ParticleEmitter")
		sand.Name = "ZT_CosSand"
		sand.Texture = "rbxasset://textures/particles/smoke_main.dds"
		sand.Color = ColorSequence.new(rgb(214, 190, 140))
		sand.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) })
		sand.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		sand.Lifetime = NumberRange.new(0.8, 1.4)
		sand.Rate = 4
		sand.Speed = NumberRange.new(0.3, 1)
		sand.Acceleration = Vector3.new(0, -2, 0)
		sand.SpreadAngle = Vector2.new(180, 180)
		sand.Parent = disc
	end

	BUILD.pirate = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local hat = rgb(22, 18, 16)
		part(m, h, "HatCrown", Vector3.new(H.X * 0.98, H.Y * 0.5, H.Z * 0.98), CFrame.new(0, H.Y * 0.56, 0), hat, Enum.Material.Fabric, "egg")
		part(m, h, "HatBrim", Vector3.new(H.X * 1.5, 0.08 * k, H.Z * 1.5), CFrame.new(0, H.Y * 0.43, 0), hat, Enum.Material.Fabric, "egg")
		for i = 0, 2 do
			local a = math.rad(i * 120 + 180)
			local side = part(m, h, "HatSide", Vector3.new(H.X * 1.06, 0.42 * k, 0.08), CFrame.new(0, H.Y * 0.43, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.2 * k, -H.Z * 0.66) * CFrame.Angles(math.rad(-28), 0, 0), hat, Enum.Material.Fabric)
			part(m, side, "HatTrim", Vector3.new(H.X * 1.08, 0.05 * k, 0.1), CFrame.new(0, 0.21 * k, 0), GOLD, Enum.Material.Metal)
			if i == 0 then
				decal(side, Enum.NormalId.Front, IMG.e_skull)
			end
		end
		part(m, h, "Patch", Vector3.new(0.24 * k, 0.22 * k, 0.04), CFrame.new(0.2 * k, 0.1 * k, -H.Z / 2 - 0.03), BLACK, Enum.Material.Leather, "egg")
		part(m, h, "PatchStrap", Vector3.new(H.X * 1.06, 0.04 * k, H.Z * 1.06), CFrame.new(0, 0.12 * k, 0) * CFrame.Angles(0, 0, math.rad(-22)), BLACK, Enum.Material.Leather)
		part(m, h, "Earring", Vector3.new(0.03, 0.14 * k, 0.14 * k), CFrame.new(-H.X / 2 - 0.03, -0.18 * k, 0), GOLD, Enum.Material.Metal, "cyl").Reflectance = 0.4
		-- скелет попугая на левом плече: косточки и зелёные огоньки в глазницах
		local u, U = b.ut, b.ut.Size
		local bone = rgb(236, 228, 206)
		local perch = CFrame.new(-U.X * 0.36, U.Y / 2 + 0.22, 0.05)
		local body = part(m, u, "ParrotBody", Vector3.new(0.24, 0.36, 0.26), perch, bone, Enum.Material.Slate, "egg")
		for i = 0, 2 do
			part(m, body, "Rib", Vector3.new(0.26, 0.03, 0.28), CFrame.new(0, 0.08 - i * 0.08, 0), rgb(200, 190, 166), Enum.Material.Slate, "egg")
		end
		local skull = part(m, body, "ParrotSkull", Vector3.new(0.2, 0.2, 0.22), CFrame.new(0, 0.26, -0.04), bone, Enum.Material.Slate, "ball")
		part(m, skull, "Beak", Vector3.new(0.08, 0.12, 0.14), CFrame.new(0, -0.04, -0.14) * CFrame.Angles(math.rad(25), 0, 0), rgb(214, 190, 120), Enum.Material.Slate, "wedge")
		for _, sx in ipairs({ -1, 1 }) do
			part(m, skull, "Socket", Vector3.new(0.05, 0.05, 0.02), CFrame.new(sx * 0.07, 0.02, -0.1), rgb(110, 255, 80), Enum.Material.Neon, "ball")
			part(m, body, "Wing", Vector3.new(0.03, 0.3, 0.22), CFrame.new(sx * 0.13, 0.02, 0.04) * CFrame.Angles(math.rad(10), 0, math.rad(sx * 12)), bone, Enum.Material.Slate)
			part(m, body, "Foot", Vector3.new(0.03, 0.12, 0.03), CFrame.new(sx * 0.05, -0.22, 0), rgb(200, 190, 166), Enum.Material.Slate)
		end
		part(m, body, "Tail", Vector3.new(0.06, 0.34, 0.03), CFrame.new(0, -0.24, 0.14) * CFrame.Angles(math.rad(35), 0, 0), bone, Enum.Material.Slate)
		-- крюк вместо правой руки и сабля
		if b.rh then
			local hand = b.rh
			local cuff = part(m, hand, "HookCuff", Vector3.new(0.34, math.min(hand.Size.X, hand.Size.Z) * 0.8, math.min(hand.Size.X, hand.Size.Z) * 0.8), CFrame.new(0, -hand.Size.Y * 0.5 - 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(60, 40, 28), Enum.Material.Leather, "cyl")
			part(m, cuff, "HookStem", Vector3.new(0.44, 0.1, 0.1), CFrame.new(-0.36, 0, 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.5
			part(m, cuff, "HookCurve", Vector3.new(0.26, 0.09, 0.09), CFrame.new(-0.64, 0, -0.09) * CFrame.Angles(0, math.rad(50), 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.5
			part(m, cuff, "HookTip", Vector3.new(0.2, 0.08, 0.08), CFrame.new(-0.62, 0, -0.27) * CFrame.Angles(0, math.rad(130), 0), SILVER, Enum.Material.Metal, "cyl").Reflectance = 0.5
		end
		local l, L = b.lt, b.lt.Size
		local blade = part(m, l, "Cutlass", Vector3.new(0.05, 1.3, 0.2), CFrame.new(-L.X / 2 - 0.12, -0.6, 0.1) * CFrame.Angles(math.rad(-20), 0, math.rad(6)), SILVER, Enum.Material.Metal)
		blade.Reflectance = 0.45
		part(m, blade, "Tip", Vector3.new(0.05, 0.22, 0.2), CFrame.new(0, -0.76, 0) * CFrame.Angles(math.pi, 0, 0), SILVER, Enum.Material.Metal, "wedge").Reflectance = 0.45
		part(m, blade, "Guard", Vector3.new(0.06, 0.1, 0.36), CFrame.new(0, 0.68, -0.02), GOLD, Enum.Material.Metal)
		part(m, blade, "Hilt", Vector3.new(0.08, 0.3, 0.08), CFrame.new(0, 0.88, 0), rgb(40, 24, 16), Enum.Material.Leather)
		part(m, blade, "Knob", Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, 1.06, 0), GOLD, Enum.Material.Metal, "ball")
	end

	BUILD.rocker = function(m, b)
		local h, H = b.head, b.head.Size
		local k = H.Y / 1.2
		local neon = rgb(150, 255, 60)
		for i = 0, 5 do
			local z = (-0.42 + i * 0.17) * H.Z
			local tall = (0.5 - math.abs(i - 2) * 0.06) * k
			part(m, h, "Spike", Vector3.new(0.09 * k, tall, 0.16 * k), CFrame.new(0, H.Y / 2 + tall / 2 - 0.06 * k, z) * CFrame.Angles(math.rad(-10 - i * 4), 0, 0), neon, Enum.Material.Neon)
		end
		part(m, h, "Shades", Vector3.new(0.78 * k, 0.2 * k, 0.04), CFrame.new(0, 0.2 * k, -H.Z / 2 - 0.04), rgb(8, 8, 10), Enum.Material.SmoothPlastic).Reflectance = 0.12
		part(m, h, "Earring", Vector3.new(0.12 * k, 0.12 * k, 0.12 * k), CFrame.new(-H.X / 2 - 0.05, -0.22 * k, 0), rgb(236, 228, 206), Enum.Material.Slate, "ball")
		-- гитара за спиной
		local u, U = b.ut, b.ut.Size
		local g = part(m, u, "GuitarBody", Vector3.new(0.8, 0.9, 0.16), CFrame.new(-U.X * 0.06, -U.Y * 0.3, U.Z / 2 + 0.16) * CFrame.Angles(0, 0, math.rad(32)), rgb(196, 24, 30), Enum.Material.SmoothPlastic, "egg")
		g.Reflectance = 0.2
		part(m, g, "GuitarUpper", Vector3.new(0.6, 0.66, 0.16), CFrame.new(0, 0.5, 0), rgb(196, 24, 30), Enum.Material.SmoothPlastic, "egg").Reflectance = 0.2
		part(m, g, "Guard", Vector3.new(0.3, 0.4, 0.02), CFrame.new(0.12, -0.05, 0.09), rgb(240, 240, 240), Enum.Material.SmoothPlastic, "egg")
		local neck = part(m, g, "Neck", Vector3.new(0.13, 1.5, 0.06), CFrame.new(0, 1.4, 0.02), rgb(110, 70, 40), Enum.Material.Wood)
		part(m, neck, "Head", Vector3.new(0.18, 0.3, 0.07), CFrame.new(0, 0.86, 0), BLACK, Enum.Material.SmoothPlastic)
		for i = -1, 1, 2 do
			part(m, neck, "String", Vector3.new(0.01, 2.0, 0.01), CFrame.new(i * 0.03, -0.2, 0.04), SILVER, Enum.Material.Metal)
		end
		for i = 0, 2 do
			part(m, neck, "Fret", Vector3.new(0.13, 0.015, 0.065), CFrame.new(0, 0.5 - i * 0.35, 0.002), SILVER, Enum.Material.Metal)
		end
		part(m, g, "Pickup", Vector3.new(0.26, 0.08, 0.03), CFrame.new(0, 0.15, 0.09), BLACK, Enum.Material.Metal)
		part(m, g, "Knob", Vector3.new(0.03, 0.08, 0.08), CFrame.new(0.24, -0.26, 0.09) * CFrame.Angles(0, math.pi / 2, 0), SILVER, Enum.Material.Metal, "cyl")
		part(m, u, "GuitarStrap", Vector3.new(0.12, U.Y * 1.3, 0.04), CFrame.new(0, 0, -U.Z / 2 - 0.03) * CFrame.Angles(0, 0, math.rad(-34)), BLACK, Enum.Material.Leather)
		-- браслеты с шипами
		for _, arm in ipairs({ b.lla, b.rla }) do
			if arm then
				local A = arm.Size
				local band = part(m, arm, "Wristband", Vector3.new(0.24, A.X * 1.25, A.Z * 1.25), CFrame.new(0, -A.Y * 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.Leather, "cyl")
				for i = 0, 3 do
					local a = i * math.pi / 2
					part(m, band, "Stud", Vector3.new(0.1, 0.1, 0.1), CFrame.Angles(a, 0, 0) * CFrame.new(0, A.X * 0.64, 0), SILVER, Enum.Material.Metal, "ball").Reflectance = 0.4
				end
			end
		end
	end

	---------------------------------------------------------------------
	-- НАДЕТЬ / СНЯТЬ
	---------------------------------------------------------------------
	local function bodyOf(character: Model)
		local function bp(name)
			local p = character:FindFirstChild(name)
			return if p and p:IsA("BasePart") then p else nil
		end
		local head, ut, lt = bp("Head"), bp("UpperTorso"), bp("LowerTorso")
		if not head or not ut or not lt then
			return nil -- R6 и необычные тела: только одежда
		end
		return { head = head, ut = ut, lt = lt, lua = bp("LeftUpperArm"), rla = bp("RightLowerArm"), lla = bp("LeftLowerArm"), rh = bp("RightHand"), lul = bp("LeftUpperLeg") }
	end

	local HEADWEAR = { Enum.AccessoryType.Hat, Enum.AccessoryType.Hair, Enum.AccessoryType.Face, Enum.AccessoryType.Eyebrow, Enum.AccessoryType.Eyelash }
	local function hides(acc: Accessory): boolean
		if acc:FindFirstChildWhichIsA("WrapLayer", true) then
			return true -- 3D-одежда закрыла бы костюм
		end
		local ok, kind = pcall(function()
			return acc.AccessoryType
		end)
		if ok and table.find(HEADWEAR, kind) then
			return true
		end
		local handle = acc:FindFirstChild("Handle")
		local att = if handle then handle:FindFirstChildWhichIsA("Attachment") else nil
		local n = if att then att.Name else ""
		return n == "HatAttachment" or n == "HairAttachment" or n == "FaceFrontAttachment" or n == "FaceCenterAttachment"
	end

	local function strip(character: Model)
		local folder = character:FindFirstChild("ZT_Costume")
		if folder then
			folder:Destroy()
		end
		local store = character:FindFirstChild("ZT_CosStore")
		for _, c in ipairs(character:GetChildren()) do
			if c.Name == "ZT_CosShirt" or c.Name == "ZT_CosPants" then
				c:Destroy()
			end
		end
		if store then
			for _, c in ipairs(store:GetChildren()) do
				c.Parent = character
			end
			store:Destroy()
		end
		for _, d in ipairs(character:GetDescendants()) do
			local was = d:GetAttribute("ZT_CosWas")
			if was ~= nil and (d:IsA("BasePart") or d:IsA("Decal")) then
				d.Transparency = was
				d:SetAttribute("ZT_CosWas", nil)
			end
		end
	end

	local function hide(inst: Instance)
		if inst:GetAttribute("ZT_CosWas") == nil then
			inst:SetAttribute("ZT_CosWas", (inst :: any).Transparency)
		end
		(inst :: any).Transparency = 1
	end

	-- хэллоуинская голова-тыква (в папке PumpkinHeads, приварена к голове) и шляпа ведьмы: под костюмом их не видно
	local function pumpkinOf(character: Model): Model?
		local head = character:FindFirstChild("Head")
		local map = workspace:FindFirstChild("ZombieTagMap")
		local heads = if map then map:FindFirstChild("PumpkinHeads") else nil
		if not head or not heads then
			return nil
		end
		for _, m in ipairs(heads:GetChildren()) do
			for _, w in ipairs(m:GetDescendants()) do
				if (w:IsA("WeldConstraint") or w:IsA("Weld")) and (w.Part0 == head or w.Part1 == head) then
					return m
				end
			end
		end
		return nil
	end
	local function hideExtras(character: Model)
		local hat = character:FindFirstChild("ZT_WitchHat")
		if hat then
			for _, d in ipairs(hat:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then
					hide(d)
				end
			end
		end
		local pumpkin = pumpkinOf(character)
		if pumpkin and not pumpkin:GetAttribute("ZT_CosHidden") then
			pumpkin:SetAttribute("ZT_CosHidden", true)
			for _, d in ipairs(pumpkin:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = 1
				elseif d:IsA("Decal") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
					pcall(function()
						(d :: any).Enabled = false
					end)
					if d:IsA("Decal") then
						d.Transparency = 1
					end
				end
			end
		end
	end
	local function showExtras(character: Model)
		local pumpkin = pumpkinOf(character)
		if pumpkin and pumpkin:GetAttribute("ZT_CosHidden") then
			pumpkin:Destroy() -- модуль Halloween сам наденет новую, видимую
		end
	end

	local function dress(character: Model, id: string)
		strip(character)
		local c = BY_ID[id]
		local img = IMG[id]
		if not c then
			return
		end
		-- своя одежда игрока переезжает в папку (там она не видна) и вернётся при снятии
		local store = Instance.new("Folder")
		store.Name = "ZT_CosStore"
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
				child.Parent = store
			end
		end
		store.Parent = character
		if img then
			local shirt = Instance.new("Shirt")
			shirt.Name = "ZT_CosShirt"
			shirt.ShirtTemplate = img.shirt
			shirt.Parent = character
			local pants = Instance.new("Pants")
			pants.Name = "ZT_CosPants"
			pants.PantsTemplate = img.pants
			pants.Parent = character
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") and hides(acc) then
				local handle = acc:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					hide(handle)
				end
			end
		end
		local body = bodyOf(character)
		if body then
			if id == "mummy" then
				for _, d in ipairs(body.head:GetChildren()) do
					if d:IsA("Decal") then
						hide(d)
					end
				end
			end
			local folder = Instance.new("Model")
			folder.Name = "ZT_Costume"
			folder:SetAttribute("Id", id)
			local ok, err = pcall(BUILD[id], folder, body)
			if not ok then
				warn("[Zombie Tag] Costumes build " .. id .. ": " .. tostring(err))
			end
			folder.Parent = character
		end
	end

	---------------------------------------------------------------------
	-- ДАННЫЕ ИГРОКА
	---------------------------------------------------------------------
	local function profileOf(player: Player)
		local s = sessions[player]
		return if s then s.profile else nil
	end
	local function owns(profile, id: string): boolean
		return profile.owned["cos_" .. id] == true
	end
	local function worn(profile, side: string): string?
		for _, c in ipairs(COSTUMES) do
			if c.side == side and profile.owned["cq_" .. side .. "_" .. c.id] == true then
				return c.id
			end
		end
		return nil
	end
	local function setWorn(profile, side: string, id: string?)
		for _, c in ipairs(COSTUMES) do
			if c.side == side then
				profile.owned["cq_" .. side .. "_" .. c.id] = nil
			end
		end
		if id then
			profile.owned["cq_" .. side .. "_" .. id] = true
		end
	end

	local preview: { [Player]: { id: string, untilAt: number } } = {}
	local applied: { [Player]: { character: Model?, id: string? } } = {}

	local function wanted(player: Player): string?
		local p = preview[player]
		if p and os.clock() < p.untilAt then
			return p.id
		end
		preview[player] = nil
		local profile = profileOf(player)
		if not profile then
			return nil
		end
		local active = ctx.state()
		local zombie = active and ctx.inRound[player] == true and ctx.isZombie[player] == true
		return worn(profile, if zombie then "z" else "h")
	end

	local function update(player: Player)
		local character = player.Character
		if not character or not character.Parent then
			return
		end
		local id = wanted(player)
		if id then
			hideExtras(character)
		end
		local state = applied[player]
		local current = character:FindFirstChild("ZT_Costume")
		local intact = id == nil or (current ~= nil and current:GetAttribute("Id") == id) or bodyOf(character) == nil
		if state and state.character == character and state.id == id and intact then
			return
		end
		if id then
			dress(character, id)
			hideExtras(character)
		else
			strip(character)
			showExtras(character)
		end
		applied[player] = { character = character, id = id }
	end

	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, player in ipairs(Players:GetPlayers()) do
				safely("update", update, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		preview[player] = nil
		applied[player] = nil
	end)

	---------------------------------------------------------------------
	-- МАНЕКЕНЫ (для витрин в лобби и для окна гардероба)
	---------------------------------------------------------------------
	local dolls = Instance.new("Folder")
	dolls.Name = "ZT_CosDolls"
	dolls.Parent = ReplicatedStorage

	local function makeDoll(id: string?, zombie: boolean): Model?
		local desc = Instance.new("HumanoidDescription")
		local skin = if zombie then rgb(132, 168, 104) else rgb(234, 184, 146)
		desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin, skin, skin
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok or not rig then
			warn("[Zombie Tag] Costumes doll: " .. tostring(rig))
			return nil
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local head = rig:FindFirstChild("Head")
		if zombie and head then
			local face = head:FindFirstChildOfClass("Decal")
			if face then
				face.Texture = "rbxassetid://131515873235590"
			end
		end
		rig.Name = id or "Doll"
		local root = rig:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		rig:PivotTo(CFrame.new(0, 1000, 0))
		rig.Parent = workspace -- одежда и детали встают по позе, пока манекен в мире
		if id then
			dress(rig, id)
		end
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		return rig
	end

	task.spawn(function()
		for _, c in ipairs(COSTUMES) do
			local rig = makeDoll(c.id, c.side == "z")
			if rig then
				rig.Parent = dolls
			end
			task.wait()
		end
	end)

	---------------------------------------------------------------------
	-- ГАРДЕРОБ В ЛОББИ: подиум, две витрины-карусели, вешалки, вывеска, кнопка
	---------------------------------------------------------------------
	local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: any?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == "ball" then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = parent
		return p
	end

	local stage = nil
	local pedestals = {}
	-- круглый "бутик" в центре лобби (на стеклянном полу): видно отовсюду, подойти можно с двух сторон
	local function buildWardrobe()
		local map = workspace:WaitForChild("ZombieTagMap", 60)
		local lobby = if map then map:WaitForChild("Lobby", 60) else nil
		if not lobby then
			return
		end
		local old = lobby:FindFirstChild("Wardrobe")
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "Wardrobe"
		local face = Vector3.new(WARDROBE_FACE.X, 0, WARDROBE_FACE.Z).Unit
		local base = CFrame.lookAt(WARDROBE_AT, WARDROBE_AT + face)
		local function at(x, y, z)
			return base * CFrame.new(x, y, -z)
		end
		local up = CFrame.Angles(0, 0, math.pi / 2) -- цилиндр стоя
		local trim, pink = rgb(214, 168, 58), rgb(255, 120, 220)
		local floor = solid(model, "Base", Vector3.new(0.5, 15, 15), at(0, 0.25, 0) * up, rgb(44, 36, 58), Enum.Material.Marble, "cyl")
		floor.CanCollide = true
		solid(model, "BaseTrim", Vector3.new(0.22, 15.5, 15.5), at(0, 0.11, 0) * up, trim, Enum.Material.Metal, "cyl")
		solid(model, "BaseGlow", Vector3.new(0.06, 14.6, 14.6), at(0, 0.52, 0) * up, pink, Enum.Material.Neon, "cyl")
		solid(model, "BaseInlay", Vector3.new(0.07, 13.6, 13.6), at(0, 0.53, 0) * up, rgb(44, 36, 58), Enum.Material.Marble, "cyl")
		-- центральная колонна с зеркалом и короной
		solid(model, "Column", Vector3.new(8.6, 1.1, 1.1), at(0, 4.8, 0) * up, rgb(24, 22, 30), Enum.Material.Metal, "cyl")
		for _, y in ipairs({ 1.2, 4.8, 8.6 }) do
			solid(model, "ColumnRing", Vector3.new(0.18, 1.4, 1.4), at(0, y, 0) * up, trim, Enum.Material.Metal, "cyl")
		end
		for _, z in ipairs({ -1, 1 }) do
			local mirror = solid(model, "Mirror", Vector3.new(2.4, 5.4, 0.08), at(0, 4.6, z * 0.62), rgb(205, 214, 224), Enum.Material.Glass)
			mirror.Reflectance = 0.6
			solid(model, "MirrorFrame", Vector3.new(2.7, 5.7, 0.06), at(0, 4.6, z * 0.58), trim, Enum.Material.Metal)
		end
		-- светящееся кольцо над бутиком и два прожектора на витрины
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2
			solid(model, "Halo", Vector3.new(2.0, 0.22, 0.22), at(math.cos(a) * 7, 10.6, math.sin(a) * 7) * CFrame.Angles(0, a + math.pi / 2, 0), pink, Enum.Material.Neon)
		end
		for _, sx in ipairs({ -1, 1 }) do
			solid(model, "HaloArm", Vector3.new(7, 0.16, 0.16), at(sx * 3.5, 10.6, 0), rgb(24, 22, 30), Enum.Material.Metal)
		end
		local sign = solid(model, "SignAnchor", Vector3.new(0.2, 0.2, 0.2), at(0, 12.6, 0), rgb(0, 0, 0), Enum.Material.SmoothPlastic)
		sign.Transparency = 1
		local board = Instance.new("BillboardGui")
		board.Name = "Sign"
		board.Size = UDim2.fromScale(15, 3)
		board.MaxDistance = 140
		board.LightInfluence = 0
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.66)
		title.Text = "👗 ГАРДЕРОБ · WARDROBE"
		title.TextScaled = true
		title.Font = Enum.Font.GothamBlack
		title.TextColor3 = rgb(255, 230, 250)
		title.TextStrokeColor3 = rgb(120, 20, 90)
		title.TextStrokeTransparency = 0
		title.Parent = board
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.66)
		sub.Size = UDim2.fromScale(1, 0.34)
		sub.Text = "Костюмы для людей и зомби · Costumes for humans & zombies"
		sub.TextScaled = true
		sub.Font = Enum.Font.GothamBold
		sub.TextColor3 = rgb(255, 214, 90)
		sub.TextStrokeTransparency = 0.2
		sub.Parent = board
		board.Parent = sign
		-- маленькие вешалки спереди и сзади: ткани цветов костюмов
		for _, z in ipairs({ -1, 1 }) do
			local list = {}
			for _, c in ipairs(COSTUMES) do
				if (z < 0) == (c.side == "h") then
					table.insert(list, c)
				end
			end
			solid(model, "RackBar", Vector3.new(3.6, 0.12, 0.12), at(0, 4.2, z * 3.6), SILVER, Enum.Material.Metal)
			for _, sx in ipairs({ -1.9, 1.9 }) do
				solid(model, "RackPole", Vector3.new(0.14, 3.7, 0.14), at(sx, 2.35, z * 3.6), SILVER, Enum.Material.Metal)
			end
			for i, c in ipairs(list) do
				local x = -1.35 + (i - 1) * 0.9
				solid(model, "Hanger", Vector3.new(0.06, 0.3, 0.06), at(x, 4.0, z * 3.6), SILVER, Enum.Material.Metal)
				solid(model, "Cloth", Vector3.new(0.14, 1.7, 0.8), at(x, 3.0, z * 3.6) * CFrame.Angles(0, math.rad(8), 0), c.color, Enum.Material.Fabric)
			end
		end
		-- две вращающиеся витрины: слева люди, справа зомби
		for i, sx in ipairs({ -1, 1 }) do
			local p0 = at(sx * 4.4, 0.5, 0)
			local ped = solid(model, "Pedestal", Vector3.new(0.9, 3.6, 3.6), p0 * CFrame.new(0, 0.45, 0) * up, rgb(236, 232, 240), Enum.Material.Marble, "cyl")
			ped.CanCollide = true
			solid(model, "PedestalRing", Vector3.new(0.14, 3.8, 3.8), p0 * CFrame.new(0, 0.9, 0) * up, if sx < 0 then rgb(90, 170, 255) else rgb(130, 255, 80), Enum.Material.Neon, "cyl")
			local spot = solid(model, "Spot", Vector3.new(0.5, 0.5, 0.5), at(sx * 4.4, 10.4, 0), BLACK, Enum.Material.Metal)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 45
			light.Range = 14
			light.Brightness = 2.5
			light.Color = if sx < 0 then rgb(200, 225, 255) else rgb(210, 255, 200)
			light.Parent = spot
			local tag = Instance.new("BillboardGui")
			tag.Name = "Tag"
			tag.Size = UDim2.fromScale(6, 1.4)
			tag.MaxDistance = 80
			tag.LightInfluence = 0
			local tl = Instance.new("TextLabel")
			tl.Name = "Text"
			tl.BackgroundTransparency = 1
			tl.Size = UDim2.fromScale(1, 1)
			tl.TextScaled = true
			tl.Font = Enum.Font.GothamBlack
			tl.TextStrokeTransparency = 0.2
			tl.TextColor3 = rgb(255, 255, 255)
			tl.Text = if sx < 0 then "ЛЮДИ · HUMANS" else "ЗОМБИ · ZOMBIES"
			tl.Parent = tag
			local anchor = solid(model, "TagAnchor", Vector3.new(0.2, 0.2, 0.2), p0 * CFrame.new(0, 8, 0), rgb(0, 0, 0), Enum.Material.SmoothPlastic)
			anchor.Transparency = 1
			tag.Parent = anchor
			pedestals[i] = { cf = p0 * CFrame.new(0, 0.9, 0), side = if sx < 0 then "h" else "z", tag = tl, rig = nil, index = 0, angle = if sx < 0 then 0 else math.pi }
		end
		-- кнопки с двух сторон: открывают окно гардероба
		for _, z in ipairs({ -1, 1 }) do
			local pad = solid(model, "PromptPad", Vector3.new(0.12, 2.4, 2.4), at(0, 0.6, z * 6.2) * up, pink, Enum.Material.Neon, "cyl")
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ZT_WardrobePrompt"
			prompt.ActionText = "👗 Гардероб · Wardrobe"
			prompt.ObjectText = ""
			prompt.HoldDuration = 0
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
		end
		model.Parent = lobby
		stage = model
	end

	-- витрины по очереди показывают костюмы своей стороны и медленно вращаются
	local function showNext(ped)
		local list = {}
		for _, c in ipairs(COSTUMES) do
			if c.side == ped.side then
				table.insert(list, c)
			end
		end
		ped.index = ped.index % #list + 1
		local c = list[ped.index]
		local src = dolls:FindFirstChild(c.id)
		if not src or not stage then
			return
		end
		if ped.rig then
			ped.rig:Destroy()
		end
		local rig = src:Clone()
		rig.Parent = stage
		ped.rig = rig
		ped.height = rig:GetExtentsSize().Y
		ped.tag.Text = TEXT.ru["n_" .. c.id] .. " · " .. TEXT.en["n_" .. c.id] .. "\n" .. c.price .. " 💰" .. (if c.level then "  🔒 LVL " .. c.level else "")
		ped.tag.TextColor3 = c.color
	end

	task.spawn(function()
		safely("wardrobe", buildWardrobe)
		repeat
			task.wait(0.5)
		until #dolls:GetChildren() >= #COSTUMES
		local last = 0
		RunService.Heartbeat:Connect(function(dt)
			for _, ped in ipairs(pedestals) do
				if ped.rig and ped.rig.Parent then
					ped.angle += dt * 0.6
					local hip = 2
					local hum = ped.rig:FindFirstChildOfClass("Humanoid")
					if hum then
						hip = hum.HipHeight
					end
					local root = ped.rig:FindFirstChild("HumanoidRootPart")
					local lift = hip + (if root then root.Size.Y / 2 else 1)
					ped.rig:PivotTo(ped.cf * CFrame.new(0, lift, 0) * CFrame.Angles(0, ped.angle, 0))
				end
			end
		end)
		while true do
			safely("showcase", function()
				for _, ped in ipairs(pedestals) do
					showNext(ped)
				end
			end)
			task.wait(6)
		end
	end)

	---------------------------------------------------------------------
	-- ОКНО ГАРДЕРОБА: запросы от экрана игрока
	---------------------------------------------------------------------
	local remote = ReplicatedStorage:FindFirstChild("ZT_Costume")
	if remote then
		remote:Destroy()
	end
	local fn = Instance.new("RemoteFunction")
	fn.Name = "ZT_Costume"
	fn.Parent = ReplicatedStorage

	local function stateFor(player: Player)
		local profile = profileOf(player)
		local list = {}
		for _, c in ipairs(COSTUMES) do
			table.insert(list, {
				id = c.id, side = c.side, price = c.price, level = c.level or 0, color = c.color,
				name = t(player, "n_" .. c.id), about = t(player, "d_" .. c.id),
				owned = profile ~= nil and owns(profile, c.id),
			})
		end
		return {
			list = list,
			coins = if profile then profile.coins else 0,
			level = if profile and ctx.levelOf then ctx.levelOf(profile.xp) else 0,
			h = if profile then worn(profile, "h") else nil,
			z = if profile then worn(profile, "z") else nil,
			ui = TEXT[lang(player)],
			uiEn = TEXT.en,
		}
	end

	local busy = {}
	fn.OnServerInvoke = function(player: Player, action: any, id: any)
		if busy[player] then
			return { ok = false, err = "busy" }
		end
		busy[player] = true
		local result = { ok = false, err = "bad" }
		safely("request", function()
			local profile = profileOf(player)
			if not profile then
				result = { ok = false, err = "wait" }
				return
			end
			local c = if type(id) == "string" then BY_ID[id] else nil
			if action == "state" then
				result = { ok = true }
			elseif action == "buy" and c then
				if owns(profile, c.id) then
					result = { ok = true }
				elseif ctx.levelOf and ctx.levelOf(profile.xp) < (c.level or 0) then
					result = { ok = false, err = "level", n = c.level }
					ctx.sound(player, "deny")
				elseif profile.coins < c.price then
					result = { ok = false, err = "coins", n = c.price - profile.coins }
					ctx.sound(player, "deny")
				else
					profile.coins -= c.price
					profile.owned["cos_" .. c.id] = true
					setWorn(profile, c.side, c.id)
					ctx.sync(player)
					ctx.sound(player, "buy")
					result = { ok = true, msg = "bought" }
					if c.side == "z" then
						-- показать сразу, даже если сейчас человек
						preview[player] = { id = c.id, untilAt = os.clock() + 6 }
					end
				end
			elseif action == "wear" and c and owns(profile, c.id) then
				setWorn(profile, c.side, c.id)
				ctx.sound(player, "coin")
				result = { ok = true, msg = "worn" }
				if c.side == "z" then
					preview[player] = { id = c.id, untilAt = os.clock() + 6 }
				end
			elseif action == "off" and c then
				if worn(profile, c.side) == c.id then
					setWorn(profile, c.side, nil)
				end
				preview[player] = nil
				ctx.sound(player, "coin")
				result = { ok = true, msg = "off" }
			elseif action == "try" and c then
				preview[player] = { id = c.id, untilAt = os.clock() + PREVIEW_TIME }
				result = { ok = true, msg = "try", n = PREVIEW_TIME }
			end
			update(player)
		end)
		busy[player] = nil
		result.state = stateFor(player)
		return result
	end

	return { costumes = COSTUMES, dress = dress, strip = strip, state = stateFor }
end
