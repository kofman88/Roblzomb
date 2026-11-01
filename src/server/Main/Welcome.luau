--!strict
--[[
	ПЕРВАЯ ПОКУПКА И ПЕРВЫЙ ДОМ (модуль Welcome). Анализ первых игроков, 1 ноября 2026:
	двое игроков доиграли раунды, накопили 198 и 334 монеты и ничего не купили; дом не построил никто.
	Витрины и стрелка в лобби новичка не довели, а в лобби у одиночки всего 12 секунд.

	Что здесь:
	- после первого раунда новичок без покупок видит окно «Выбери свой первый след»: три самых дешёвых
	  следа, покупка в одно нажатие (обычная покупка главного скрипта, ctx.shop);
	- затем шаг «Построй свой первый дом» с кнопкой «Пойти домой» (модуль Homes);
	- пока окно открыто, следующий раунд игрока не забирает (Guard.stay), но не дольше OFFER_TIMEOUT;
	- каждый шаг пишется в аналитику: Welcome_Offer, Welcome_Bought (какой след), Welcome_Later,
	  Welcome_Home, Welcome_HomeLater.
	Окно рисует скрипт ZT_Welcome (StarterPlayerScripts) по сигналам ReplicatedStorage.ZT_Welcome.
	КУДА ВСТАВИТЬ: ModuleScript Welcome внутри главного скрипта, рядом с Extras. Запускает его Extras.
]]

local OFFER_DELAY = 3     -- через сколько секунд в лобби после раунда открывается окно
local OFFER_TIMEOUT = 45  -- дольше этого окно игрока в лобби не держит
local PICK = 3            -- сколько следов показать

local TEXT: { [string]: { [string]: string } } = {
	en = { wl_title = "🎉 Pick your first trail!", wl_sub = "You have %d coins — it follows you right away", wl_take = "Take", wl_later = "Later", wl_home = "🏠 Build your first house", wl_home_sub = "You already have the materials: from a tent to a fortress", wl_go = "Go home" },
	ru = { wl_title = "🎉 Выбери свой первый след!", wl_sub = "У тебя %d монет — след сразу потянется за тобой", wl_take = "Взять", wl_later = "Позже", wl_home = "🏠 Построй свой первый дом", wl_home_sub = "Материалы уже есть: от палатки до крепости", wl_go = "Пойти домой" },
	es = { wl_title = "🎉 ¡Elige tu primera estela!", wl_sub = "Tienes %d monedas: te seguirá al instante", wl_take = "Tomar", wl_later = "Luego", wl_home = "🏠 Construye tu primera casa", wl_home_sub = "Ya tienes materiales: de tienda a fortaleza", wl_go = "Ir a casa" },
	pt = { wl_title = "🎉 Escolha seu primeiro rastro!", wl_sub = "Você tem %d moedas: ele te segue na hora", wl_take = "Pegar", wl_later = "Depois", wl_home = "🏠 Construa sua primeira casa", wl_home_sub = "Você já tem materiais: de barraca a fortaleza", wl_go = "Ir para casa" },
	fr = { wl_title = "🎉 Choisis ta première traînée !", wl_sub = "Tu as %d pièces : elle te suit tout de suite", wl_take = "Prendre", wl_later = "Plus tard", wl_home = "🏠 Construis ta première maison", wl_home_sub = "Tu as déjà les matériaux : de la tente à la forteresse", wl_go = "À la maison" },
	de = { wl_title = "🎉 Wähle deine erste Spur!", wl_sub = "Du hast %d Münzen – sie folgt dir sofort", wl_take = "Nehmen", wl_later = "Später", wl_home = "🏠 Bau dein erstes Haus", wl_home_sub = "Material hast du schon: vom Zelt zur Festung", wl_go = "Nach Hause" },
	it = { wl_title = "🎉 Scegli la tua prima scia!", wl_sub = "Hai %d monete: ti segue subito", wl_take = "Prendi", wl_later = "Dopo", wl_home = "🏠 Costruisci la tua prima casa", wl_home_sub = "Hai già i materiali: dalla tenda alla fortezza", wl_go = "Vai a casa" },
	pl = { wl_title = "🎉 Wybierz swój pierwszy ślad!", wl_sub = "Masz %d monet — ślad pojawi się od razu", wl_take = "Weź", wl_later = "Później", wl_home = "🏠 Zbuduj swój pierwszy dom", wl_home_sub = "Masz już materiały: od namiotu do twierdzy", wl_go = "Idź do domu" },
	tr = { wl_title = "🎉 İlk izini seç!", wl_sub = "%d altının var: iz hemen peşinden gelir", wl_take = "Al", wl_later = "Sonra", wl_home = "🏠 İlk evini kur", wl_home_sub = "Malzemelerin hazır: çadırdan kaleye", wl_go = "Eve git" },
	id = { wl_title = "🎉 Pilih jejak pertamamu!", wl_sub = "Kamu punya %d koin: jejaknya langsung ikut", wl_take = "Ambil", wl_later = "Nanti", wl_home = "🏠 Bangun rumah pertamamu", wl_home_sub = "Bahannya sudah ada: dari tenda sampai benteng", wl_go = "Pulang" },
	vi = { wl_title = "🎉 Chọn vệt sáng đầu tiên!", wl_sub = "Bạn có %d xu: vệt sáng đi theo bạn ngay", wl_take = "Lấy", wl_later = "Để sau", wl_home = "🏠 Xây ngôi nhà đầu tiên", wl_home_sub = "Bạn đã có vật liệu: từ lều đến pháo đài", wl_go = "Về nhà" },
	th = { wl_title = "🎉 เลือกหางแสงอันแรก!", wl_sub = "คุณมี %d เหรียญ: หางแสงจะตามคุณทันที", wl_take = "รับ", wl_later = "ไว้ก่อน", wl_home = "🏠 สร้างบ้านหลังแรก", wl_home_sub = "มีวัสดุแล้ว: จากเต็นท์สู่ป้อมปราการ", wl_go = "กลับบ้าน" },
	ko = { wl_title = "🎉 첫 트레일을 골라 봐!", wl_sub = "코인 %d개가 있어: 바로 따라와", wl_take = "받기", wl_later = "나중에", wl_home = "🏠 첫 집을 지어 봐", wl_home_sub = "재료는 이미 있어: 텐트부터 요새까지", wl_go = "집으로" },
	ja = { wl_title = "🎉 さいしょのトレイルをえらぼう！", wl_sub = "コインが %d まいある：すぐについてくるよ", wl_take = "えらぶ", wl_later = "あとで", wl_home = "🏠 はじめての家をたてよう", wl_home_sub = "ざいりょうはもうあるよ：テントからとりでまで", wl_go = "家へ行く" },
}

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local LOBBY_Y: number = ctx.LOBBY_Y or 150
	local RS = game:GetService("ReplicatedStorage")
	local AnalyticsService = game:GetService("AnalyticsService")

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

	local found = RS:FindFirstChild("ZT_Welcome")
	local remote: RemoteEvent
	if found and found:IsA("RemoteEvent") then
		remote = found
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "ZT_Welcome"
		remote.Parent = RS
	end

	-- три самых дешёвых обычных следа (без уровня, без подарков за дни, не легенды)
	local offer: { any } = {}
	for _, item in ipairs(ctx.items or {}) do
		if item.kind == "trail" and (item.price or 0) > 0 and not item.level and not item.days and not item.row then
			table.insert(offer, item)
		end
	end
	table.sort(offer, function(a: any, b: any): boolean
		return a.price < b.price
	end)
	while #offer > PICK do
		table.remove(offer)
	end
	local offered: { [string]: any } = {}
	for _, item in ipairs(offer) do
		offered[item.id] = item
	end
	local cheapest: number = if offer[1] then offer[1].price else math.huge

	local function log(player: Player, name: string, field: string?)
		pcall(function()
			if field then
				AnalyticsService:LogCustomEvent(player, name, 1, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field })
			else
				AnalyticsService:LogCustomEvent(player, name, 1)
			end
		end)
	end

	type State = { done: boolean, open: number, step: string, lobbySince: number }
	local states: { [Player]: State } = setmetatable({}, { __mode = "k" }) :: any

	local function stock(session: any): any
		local sv = ctx.survival
		if sv and sv.stock then
			local ok, result = pcall(sv.stock, session)
			if ok then
				return result
			end
		end
		return nil
	end
	local function homes(): any
		return if ctx.survival then ctx.survival.homes else nil
	end
	local function canHome(session: any): boolean
		local s = stock(session)
		return s ~= nil and homes() ~= nil and (s.house or 0) == 0 and (s.mats or 0) > 0
	end

	local function close(player: Player)
		local state = states[player]
		if state then
			state.open = 0
			state.step = ""
		end
		remote:FireClient(player, "close")
	end

	local function homeStep(player: Player, session: any)
		local state = states[player]
		if state and canHome(session) then
			state.step = "home"
			state.open = os.clock()
			remote:FireClient(player, "home", {
				title = ctx.tr(player, "wl_home"), sub = ctx.tr(player, "wl_home_sub"),
				go = ctx.tr(player, "wl_go"), later = ctx.tr(player, "wl_later"),
			})
		else
			close(player)
		end
	end

	-- пока окно открыто, следующий раунд игрока не забирает (пауза одиночки в лобби всего 12 секунд)
	local oldStay = ctx.Guard.stay
	ctx.Guard.stay = function(player: Player): boolean
		local state = states[player]
		if state and state.open > 0 and os.clock() - state.open < OFFER_TIMEOUT then
			return true
		end
		return if oldStay then oldStay(player) else false
	end

	remote.OnServerEvent:Connect(function(player: Player, what: any, id: any)
		local ok, err = pcall(function()
			local state = states[player]
			local session = sessions[player]
			if not state or not session or state.open == 0 or type(what) ~= "string" then
				return
			end
			if what == "buy" and state.step == "trail" and type(id) == "string" then
				local item = offered[id]
				if not item or not ctx.shop then
					return
				end
				ctx.shop(player, id)
				if session.profile.owned[id] then
					log(player, "Welcome_Bought", id)
					task.delay(1.2, function()
						if sessions[player] == session then
							homeStep(player, session)
						end
					end)
				end
			elseif what == "later" then
				if state.step == "trail" then
					log(player, "Welcome_Later")
					homeStep(player, session)
				else
					log(player, "Welcome_HomeLater")
					close(player)
				end
			elseif what == "home" and state.step == "home" then
				log(player, "Welcome_Home")
				close(player)
				local h = homes()
				if h and h.go and not inRound[player] then
					h.go(player, 1, true)
				end
			end
		end)
		if not ok then
			warn("[Welcome] " .. tostring(err))
		end
	end)

	-- раз в полсекунды: кому пора показать окно, у кого оно открыто слишком долго
	task.spawn(function()
		while true do
			task.wait(0.5)
			local roundActive = (ctx.state())
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(function()
					local session = sessions[player]
					if not session then
						return
					end
					local state = states[player]
					if not state then
						state = { done = false, open = 0, step = "", lobbySince = 0 }
						states[player] = state
					end
					local now = os.clock()
					if state.open > 0 then
						if now - state.open > OFFER_TIMEOUT then
							close(player)
						end
						return
					end
					if state.done then
						return
					end
					local root = ctx.getAlive(player)
					local inLobby = root ~= nil and root.Position.Y > LOBBY_Y - 5 and not (roundActive and inRound[player])
					if not inLobby then
						state.lobbySince = 0
						return
					end
					if state.lobbySince == 0 then
						state.lobbySince = now
					end
					local profile = session.profile
					local newcomer = ctx.RULES.gifts and (profile.rounds >= 1 or (profile.badges and profile.badges.gifted))
						and next(profile.owned) == nil
					if not newcomer or profile.coins < cheapest or now - state.lobbySince < OFFER_DELAY then
						return
					end
					state.done = true -- одно окно за заход
					state.step = "trail"
					state.open = now
					local list = {}
					for _, item in ipairs(offer) do
						table.insert(list, {
							id = item.id, name = ctx.itemName(player, item), price = item.price,
							a = item.colorA, b = item.colorB, can = profile.coins >= item.price,
						})
					end
					remote:FireClient(player, "trail", {
						title = ctx.tr(player, "wl_title"), sub = ctx.tr(player, "wl_sub", profile.coins),
						take = ctx.tr(player, "wl_take"), later = ctx.tr(player, "wl_later"), items = list,
					})
					log(player, "Welcome_Offer")
				end)
				if not ok then
					warn("[Welcome] " .. tostring(err))
				end
			end
		end
	end)

	local api = { offer = offer, states = states }
	ctx.welcome = api
	return api
end
