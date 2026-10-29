--!strict
--[[
	СЕЗОН 1: ТОКСИЧНАЯ НОЧЬ (модуль Season)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Season. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Season, рядом с Extras). Запускает его модуль Extras.
	Эффекты на экране рисует LocalScript ZT_Fx (StarterPlayer -> StarterPlayerScripts).

	Что здесь:
	- умение в раунде: у выжившего РЫВОК, у зомби ПРЫЖОК (клавиша Q, кнопка ⚡ на телефоне), с перезарядкой.
	  Сервер проверяет, можно ли сейчас, укорачивает рывок перед стеной и даёт защите от читеров
	  запас пути ровно на длину рывка (Guard.dash в модуле Extras);
	- сигналы для эффектов: поимка (и комбо), последний выживший, сколько выживших осталось (атрибут ZT_Alive);
	- в конце раунда надпись «ТЫ ЗОМБИ / ТЫ ВЫЖИВШИЙ» убирается сразу;
	- тексты эффектов на языке игрока (атрибуты игрока ZT_Fx_<ключ>).
]]

local DASH_SURVIVOR = 13   -- длина рывка выжившего (studs)
local DASH_ZOMBIE = 17     -- длина прыжка зомби
local COOLDOWN_SURVIVOR = 11 -- перезарядка (секунды)
local COOLDOWN_ZOMBIE = 8
local LAST_GLOW = Color3.fromRGB(255, 150, 40) -- подсветка последнего выжившего

local TEXT: { [string]: { [string]: string } } = {
	en = {
		fx_dash = "DASH",
		fx_lunge = "LUNGE",
		fx_infected = "INFECTED!",
		fx_combo = "COMBO x%d",
		fx_turned = "YOU'VE BEEN INFECTED",
		fx_turned2 = "Now catch the others!",
		fx_last = "LAST SURVIVOR: %s",
		fx_last_me = "YOU ARE THE LAST ONE. HOLD ON!",
		fx_dash_tip = "Press Q to dash!",
		fx_dash_tip_t = "Tap ⚡ to dash!",
		fx_season = "SEASON 1: TOXIC NIGHT",
	},
	ru = {
		fx_dash = "РЫВОК",
		fx_lunge = "ПРЫЖОК",
		fx_infected = "ЗАРАЖЁН!",
		fx_combo = "КОМБО x%d",
		fx_turned = "ТЕБЯ ЗАРАЗИЛИ",
		fx_turned2 = "Теперь лови остальных!",
		fx_last = "ПОСЛЕДНИЙ ВЫЖИВШИЙ: %s",
		fx_last_me = "ТЫ ПОСЛЕДНИЙ. ДЕРЖИСЬ!",
		fx_dash_tip = "Жми Q, чтобы сделать рывок!",
		fx_dash_tip_t = "Жми ⚡, чтобы сделать рывок!",
		fx_season = "СЕЗОН 1: ТОКСИЧНАЯ НОЧЬ",
	},
	es = {
		fx_dash = "IMPULSO",
		fx_lunge = "SALTO",
		fx_infected = "¡INFECTADO!",
		fx_combo = "COMBO x%d",
		fx_turned = "TE HAN INFECTADO",
		fx_turned2 = "¡Ahora atrapa a los demás!",
		fx_last = "ÚLTIMO SUPERVIVIENTE: %s",
		fx_last_me = "ERES EL ÚLTIMO. ¡AGUANTA!",
		fx_dash_tip = "¡Pulsa Q para dar un impulso!",
		fx_dash_tip_t = "¡Toca ⚡ para dar un impulso!",
		fx_season = "TEMPORADA 1: NOCHE TÓXICA",
	},
	pt = {
		fx_dash = "IMPULSO",
		fx_lunge = "BOTE",
		fx_infected = "INFECTADO!",
		fx_combo = "COMBO x%d",
		fx_turned = "VOCÊ FOI INFECTADO",
		fx_turned2 = "Agora pegue os outros!",
		fx_last = "ÚLTIMO SOBREVIVENTE: %s",
		fx_last_me = "VOCÊ É O ÚLTIMO. AGUENTE!",
		fx_dash_tip = "Aperte Q para dar um impulso!",
		fx_dash_tip_t = "Toque em ⚡ para dar um impulso!",
		fx_season = "TEMPORADA 1: NOITE TÓXICA",
	},
	fr = {
		fx_dash = "SPRINT",
		fx_lunge = "BOND",
		fx_infected = "INFECTÉ !",
		fx_combo = "COMBO x%d",
		fx_turned = "TU AS ÉTÉ INFECTÉ",
		fx_turned2 = "Attrape les autres !",
		fx_last = "DERNIER SURVIVANT : %s",
		fx_last_me = "TU ES LE DERNIER. TIENS BON !",
		fx_dash_tip = "Appuie sur Q pour sprinter !",
		fx_dash_tip_t = "Touche ⚡ pour sprinter !",
		fx_season = "SAISON 1 : NUIT TOXIQUE",
	},
	de = {
		fx_dash = "SPRINT",
		fx_lunge = "SPRUNG",
		fx_infected = "INFIZIERT!",
		fx_combo = "KOMBO x%d",
		fx_turned = "DU WURDEST INFIZIERT",
		fx_turned2 = "Jetzt fang die anderen!",
		fx_last = "LETZTER ÜBERLEBENDER: %s",
		fx_last_me = "DU BIST DER LETZTE. HALT DURCH!",
		fx_dash_tip = "Drück Q für einen Sprint!",
		fx_dash_tip_t = "Tippe auf ⚡ für einen Sprint!",
		fx_season = "SAISON 1: GIFTIGE NACHT",
	},
	it = {
		fx_dash = "SCATTO",
		fx_lunge = "BALZO",
		fx_infected = "INFETTATO!",
		fx_combo = "COMBO x%d",
		fx_turned = "SEI STATO INFETTATO",
		fx_turned2 = "Ora prendi gli altri!",
		fx_last = "ULTIMO SOPRAVVISSUTO: %s",
		fx_last_me = "SEI L'ULTIMO. RESISTI!",
		fx_dash_tip = "Premi Q per scattare!",
		fx_dash_tip_t = "Tocca ⚡ per scattare!",
		fx_season = "STAGIONE 1: NOTTE TOSSICA",
	},
	pl = {
		fx_dash = "ZRYW",
		fx_lunge = "SKOK",
		fx_infected = "ZARAŻONY!",
		fx_combo = "KOMBO x%d",
		fx_turned = "ZOSTAŁEŚ ZARAŻONY",
		fx_turned2 = "Teraz łap pozostałych!",
		fx_last = "OSTATNI OCALAŁY: %s",
		fx_last_me = "JESTEŚ OSTATNI. TRZYMAJ SIĘ!",
		fx_dash_tip = "Wciśnij Q, aby zrobić zryw!",
		fx_dash_tip_t = "Dotknij ⚡, aby zrobić zryw!",
		fx_season = "SEZON 1: TOKSYCZNA NOC",
	},
	tr = {
		fx_dash = "ATILMA",
		fx_lunge = "SIÇRAMA",
		fx_infected = "ENFEKTE!",
		fx_combo = "KOMBO x%d",
		fx_turned = "ENFEKTE OLDUN",
		fx_turned2 = "Şimdi diğerlerini yakala!",
		fx_last = "SON HAYATTA KALAN: %s",
		fx_last_me = "SON SENSİN. DAYAN!",
		fx_dash_tip = "Atılmak için Q'ya bas!",
		fx_dash_tip_t = "Atılmak için ⚡'ya dokun!",
		fx_season = "SEZON 1: ZEHİRLİ GECE",
	},
	id = {
		fx_dash = "LESAT",
		fx_lunge = "TERKAM",
		fx_infected = "TERINFEKSI!",
		fx_combo = "KOMBO x%d",
		fx_turned = "KAMU TERINFEKSI",
		fx_turned2 = "Sekarang tangkap yang lain!",
		fx_last = "PENYINTAS TERAKHIR: %s",
		fx_last_me = "KAMU YANG TERAKHIR. BERTAHANLAH!",
		fx_dash_tip = "Tekan Q untuk melesat!",
		fx_dash_tip_t = "Ketuk ⚡ untuk melesat!",
		fx_season = "MUSIM 1: MALAM BERACUN",
	},
	vi = {
		fx_dash = "LƯỚT",
		fx_lunge = "VỒ",
		fx_infected = "NHIỄM RỒI!",
		fx_combo = "COMBO x%d",
		fx_turned = "BẠN ĐÃ BỊ NHIỄM",
		fx_turned2 = "Giờ hãy bắt những người khác!",
		fx_last = "NGƯỜI SỐNG SÓT CUỐI CÙNG: %s",
		fx_last_me = "BẠN LÀ NGƯỜI CUỐI. CỐ LÊN!",
		fx_dash_tip = "Nhấn Q để lướt!",
		fx_dash_tip_t = "Chạm ⚡ để lướt!",
		fx_season = "MÙA 1: ĐÊM ĐỘC",
	},
	th = {
		fx_dash = "พุ่ง",
		fx_lunge = "กระโจน",
		fx_infected = "ติดเชื้อ!",
		fx_combo = "คอมโบ x%d",
		fx_turned = "คุณติดเชื้อแล้ว",
		fx_turned2 = "ไปจับคนอื่นต่อ!",
		fx_last = "ผู้รอดชีวิตคนสุดท้าย: %s",
		fx_last_me = "คุณเหลือคนสุดท้าย อดทนไว้!",
		fx_dash_tip = "กด Q เพื่อพุ่ง!",
		fx_dash_tip_t = "แตะ ⚡ เพื่อพุ่ง!",
		fx_season = "ซีซัน 1: คืนพิษ",
	},
	ko = {
		fx_dash = "대시",
		fx_lunge = "덮치기",
		fx_infected = "감염!",
		fx_combo = "콤보 x%d",
		fx_turned = "감염됐어요",
		fx_turned2 = "이제 다른 사람을 잡아요!",
		fx_last = "마지막 생존자: %s",
		fx_last_me = "마지막 생존자예요. 버텨요!",
		fx_dash_tip = "Q를 눌러 대시해요!",
		fx_dash_tip_t = "⚡를 눌러 대시해요!",
		fx_season = "시즌 1: 독성의 밤",
	},
	ja = {
		fx_dash = "ダッシュ",
		fx_lunge = "とびかかり",
		fx_infected = "感染！",
		fx_combo = "コンボ x%d",
		fx_turned = "感染しちゃった",
		fx_turned2 = "ほかの人をつかまえよう！",
		fx_last = "最後のサバイバー: %s",
		fx_last_me = "のこりはキミだけ。がんばれ！",
		fx_dash_tip = "Qでダッシュ！",
		fx_dash_tip_t = "⚡をタップでダッシュ！",
		fx_season = "シーズン1: どくの夜",
	},
}

local FX_KEYS = { "fx_dash", "fx_lunge", "fx_infected", "fx_combo", "fx_turned", "fx_turned2", "fx_last", "fx_last_me", "fx_dash_tip", "fx_dash_tip_t", "fx_season" }

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local bots: { any } = ctx.bots
	local RS = game:GetService("ReplicatedStorage")

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

	local remote = RS:FindFirstChild("ZT_Fx") :: RemoteEvent?
	if not remote then
		local made = Instance.new("RemoteEvent")
		made.Name = "ZT_Fx"
		made.Parent = RS
		remote = made
	end
	local fx = remote :: RemoteEvent

	local api: any = { ready = {}, lastSeen = {}, told = {}, last = nil, dashes = 0 }
	ctx.season = api

	-- тексты эффектов: клиент читает их из атрибутов ZT_Fx_<ключ> (у клиента нет доступа к модулю Texts)
	local function sendTexts(player: Player)
		for _, key in ipairs(FX_KEYS) do
			player:SetAttribute("ZT_Fx_" .. key, ctx.tr(player, key))
		end
	end
	local function onJoin(player: Player)
		-- язык игрока известен, когда у него появилась сессия
		for _ = 1, 40 do
			if sessions[player] or player.Parent == nil then
				break
			end
			task.wait(0.25)
		end
		if player.Parent then
			sendTexts(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onJoin, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		api.ready[player] = nil
		api.lastSeen[player] = nil
		api.told[player] = nil
	end)

	-- УМЕНИЕ: рывок выжившего / прыжок зомби
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	api.dash = function(player: Player): boolean
		local active = ctx.state()
		if not active or not inRound[player] then
			return false
		end
		local now = os.clock()
		if (api.ready[player] or 0) > now then
			return false
		end
		local session = sessions[player]
		if not session or (session.stunUntil or 0) > now then
			return false
		end
		-- игрок только что передвинулся подозрительно быстро: рывок не даём
		if ctx.Guard.ok and not ctx.Guard.ok(player) then
			return false
		end
		local root, humanoid = ctx.getAlive(player)
		if not root or not humanoid or humanoid.Health <= 0 or humanoid.WalkSpeed < 1 or humanoid.Sit then
			return false
		end
		local zombie = isZombie[player] == true
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			return false
		end
		flat = flat.Unit
		local length = if zombie then DASH_ZOMBIE else DASH_SURVIVOR
		-- рывок укорачивают только стены и постройки (монеты, тыквы, боты и игроки не мешают)
		local skip: { Instance } = { player.Character :: any }
		local map = workspace:FindFirstChild("ZombieTagMap")
		if map then
			for _, name in ipairs({ "Bots", "Pickups", "Pumpkins", "PumpkinHeads" }) do
				local folder = map:FindFirstChild(name)
				if folder then
					table.insert(skip, folder)
				end
			end
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character and other ~= player then
				table.insert(skip, other.Character)
			end
		end
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(root.Position, flat * (length + 2.5), params)
		if hit then
			length = math.min(length, (hit.Position - root.Position).Magnitude - 2.5)
		end
		if length < 3 then
			return false
		end
		local cooldown = if zombie then COOLDOWN_ZOMBIE else COOLDOWN_SURVIVOR
		api.ready[player] = now + cooldown
		api.dashes += 1
		if ctx.Guard.dash then
			ctx.Guard.dash(player, length)
		end
		fx:FireClient(player, "dash", flat, length, cooldown, zombie)
		-- a trail everybody sees (the dasher's own screen hides this copy: it already draws its own at once)
		local old = root:FindFirstChild("ZT_DashTrail")
		if old then
			old:Destroy()
		end
		local top = Instance.new("Attachment")
		top.Name = "ZT_DashTop"
		top.Position = Vector3.new(0, 1.2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "ZT_DashBottom"
		bottom.Position = Vector3.new(0, -1.2, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "ZT_DashTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(if zombie then Color3.fromRGB(124, 242, 90) else Color3.fromRGB(236, 238, 232), Color3.fromRGB(124, 242, 90))
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Lifetime = 0.35
		trail.LightEmission = 0.8
		trail.Parent = root
		task.delay(0.8, function()
			trail:Destroy()
			top:Destroy()
			bottom:Destroy()
		end)
		return true
	end
	fx.OnServerEvent:Connect(function(player: Player, what: any)
		if what == "dash" then
			api.dash(player)
		end
	end)

	-- СИГНАЛЫ ДЛЯ ЭФФЕКТОВ
	local glow: Highlight? = nil
	local function clearGlow()
		if glow then
			glow:Destroy()
			glow = nil
		end
		api.last = nil
	end
	local wasActive = false
	local lastRound = -1
	local roundAt = 0
	local function tick()
		local ok, err = pcall(function()
			local active, _, roundId = ctx.state()
			-- поимка: число пойманных в раунде выросло
			for player, session in pairs(sessions) do
				local caught = session.caught or 0
				local seen = api.lastSeen[player] or 0
				if caught > seen and active then
					fx:FireClient(player, "catch", session.combo or 1)
				end
				api.lastSeen[player] = caught
			end
			if active and roundId ~= lastRound then
				lastRound = roundId
				roundAt = os.clock()
				clearGlow()
				table.clear(api.ready)
			end
			if active then
				-- сколько выживших осталось (люди и жители)
				local alive, zombies = 0, 0
				local onlyPlayer: Player? = nil
				for player in pairs(inRound) do
					if not isZombie[player] then
						alive += 1
						onlyPlayer = player
					else
						zombies += 1
					end
				end
				for _, bot in ipairs(bots) do
					if bot.alive ~= false and not bot.zombie then
						alive += 1
						onlyPlayer = nil
					elseif bot.alive ~= false then
						zombies += 1
					end
				end
				if workspace:GetAttribute("ZT_Alive") ~= alive then
					workspace:SetAttribute("ZT_Alive", alive)
				end
				-- в первые секунды раунда боты ещё не вышли в город: тогда «последнего» не объявляем
				local settled = os.clock() - roundAt > 8 and zombies >= 1
				if settled and alive == 1 and onlyPlayer and api.last ~= onlyPlayer and api.told[onlyPlayer] ~= roundId then
					api.told[onlyPlayer] = roundId
					clearGlow()
					api.last = onlyPlayer
					local character = onlyPlayer.Character
					if character then
						local h = Instance.new("Highlight")
						h.Name = "ZT_LastGlow"
						h.FillColor = LAST_GLOW
						h.OutlineColor = Color3.fromRGB(255, 230, 120)
						h.FillTransparency = 0.55
						h.DepthMode = Enum.HighlightDepthMode.Occluded
						h.Adornee = character
						h.Parent = character
						glow = h
					end
					fx:FireAllClients("last", onlyPlayer)
				elseif api.last and (alive ~= 1 or isZombie[api.last :: Player]) then
					clearGlow()
					fx:FireAllClients("unlast")
				end
			end
			if wasActive and not active then
				-- раунд закончился: надпись роли больше не нужна
				clearGlow()
				workspace:SetAttribute("ZT_Alive", nil)
				for _, hud in pairs(ctx.huds) do
					if hud.role then
						hud.role.Text = ""
					end
				end
				fx:FireAllClients("over")
			end
			wasActive = active
		end)
		if not ok then
			warn("[Zombie Tag] Season: " .. tostring(err))
		end
	end
	api.tick = tick
	task.spawn(function()
		while true do
			task.wait(0.1)
			tick()
		end
	end)

	return api
end
