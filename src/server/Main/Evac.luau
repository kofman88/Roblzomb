--!strict
--[[
	ВЕРТОЛЁТ НЕ РЕЗИНОВЫЙ (модуль Evac)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Evac. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Evac, рядом с Extras). Запускает его модуль Extras.

	Что здесь:
	- в вертолёте мест на одно меньше, чем выживших (игроков и жителей) в момент посадки: на всех не хватит;
	- над вертолётом горит табличка «💺 3»: сколько мест осталось;
	- жители тоже бегут к вертолёту и занимают места: это гонка, даже если на сервере один игрок;
	- когда места кончились, вертолёт сразу улетает: кто не успел, остаётся в городе до конца раунда;
	- каждое занятое место видят все (кто сел, сколько осталось), последнее место - отдельное событие.
	Без этого модуля всё как раньше: мест сколько угодно, жители к вертолёту не бегут.
	Сервер главного скрипта спрашивает модуль через Guard.seat (можно ли сесть) и Guard.goal (куда бежит житель).
]]

local BOT_DELAY = 4        -- через сколько секунд после посадки жители замечают вертолёт (игроки видят его первыми)
local BOT_RANGE = 230      -- жители дальше этого расстояния к вертолёту не бегут
local BOT_SHARE = 0.75     -- какая часть жителей вообще бежит к вертолёту (остальные прячутся)
local BOARD_RADIUS = 11    -- как близко к центру площадки нужно стоять (как у игроков)
local BOARD_TIME = 3       -- сколько секунд жителю нужно простоять у вертолёта
local SEAT_COLOR = Color3.fromRGB(130, 255, 80)

local TEXT: { [string]: { [string]: string } } = {
	en = {
		ev_land = "🚁 The helicopter is here: only %d seats! Not enough for everyone - RUN!",
		ev_land_z = "🚁 The helicopter landed with %d seats. Catch them before they board!",
		ev_seat = "💺 %s took a seat! Seats left: %d",
		ev_seat_bot = "💺 A citizen took a seat! Seats left: %d",
		ev_last = "🏁 %s took the LAST seat! The helicopter is leaving!",
		ev_last_bot = "🏁 A citizen took the LAST seat! The helicopter is leaving!",
		ev_full = "🚁 No seats left - the helicopter flew away!",
		ev_gone = "LEFT BEHIND! SURVIVE TO THE END",
	},
	ru = {
		ev_land = "🚁 Вертолёт прилетел: всего %d мест! На всех не хватит - БЕГИ!",
		ev_land_z = "🚁 Вертолёт сел, в нём %d мест. Поймай их, пока не улетели!",
		ev_seat = "💺 %s занял место! Осталось мест: %d",
		ev_seat_bot = "💺 Житель занял место! Осталось мест: %d",
		ev_last = "🏁 %s занял ПОСЛЕДНЕЕ место! Вертолёт улетает!",
		ev_last_bot = "🏁 Житель занял ПОСЛЕДНЕЕ место! Вертолёт улетает!",
		ev_full = "🚁 Мест не осталось - вертолёт улетел!",
		ev_gone = "НЕ УСПЕЛ! ПРОДЕРЖИСЬ ДО КОНЦА",
	},
	es = {
		ev_land = "🚁 ¡Llegó el helicóptero: solo %d plazas! No hay para todos - ¡CORRE!",
		ev_land_z = "🚁 El helicóptero aterrizó con %d plazas. ¡Atrápalos antes de que suban!",
		ev_seat = "💺 ¡%s tomó una plaza! Quedan: %d",
		ev_seat_bot = "💺 ¡Un ciudadano tomó una plaza! Quedan: %d",
		ev_last = "🏁 ¡%s tomó la ÚLTIMA plaza! ¡El helicóptero se va!",
		ev_last_bot = "🏁 ¡Un ciudadano tomó la ÚLTIMA plaza! ¡El helicóptero se va!",
		ev_full = "🚁 ¡No quedan plazas - el helicóptero se fue!",
		ev_gone = "¡TE QUEDASTE! AGUANTA HASTA EL FINAL",
	},
	pt = {
		ev_land = "🚁 O helicóptero chegou: só %d lugares! Não dá para todos - CORRA!",
		ev_land_z = "🚁 O helicóptero pousou com %d lugares. Pegue-os antes que embarquem!",
		ev_seat = "💺 %s pegou um lugar! Restam: %d",
		ev_seat_bot = "💺 Um cidadão pegou um lugar! Restam: %d",
		ev_last = "🏁 %s pegou o ÚLTIMO lugar! O helicóptero está partindo!",
		ev_last_bot = "🏁 Um cidadão pegou o ÚLTIMO lugar! O helicóptero está partindo!",
		ev_full = "🚁 Sem lugares - o helicóptero foi embora!",
		ev_gone = "FICOU PARA TRÁS! SOBREVIVA ATÉ O FIM",
	},
	fr = {
		ev_land = "🚁 L'hélico est là : seulement %d places ! Pas assez pour tous - COURS !",
		ev_land_z = "🚁 L'hélico a atterri avec %d places. Attrape-les avant l'embarquement !",
		ev_seat = "💺 %s a pris une place ! Places restantes : %d",
		ev_seat_bot = "💺 Un habitant a pris une place ! Places restantes : %d",
		ev_last = "🏁 %s a pris la DERNIÈRE place ! L'hélico s'en va !",
		ev_last_bot = "🏁 Un habitant a pris la DERNIÈRE place ! L'hélico s'en va !",
		ev_full = "🚁 Plus de places - l'hélico est parti !",
		ev_gone = "LAISSÉ DERRIÈRE ! TIENS JUSQU'À LA FIN",
	},
	de = {
		ev_land = "🚁 Der Hubschrauber ist da: nur %d Plätze! Nicht genug für alle - LAUF!",
		ev_land_z = "🚁 Der Hubschrauber ist gelandet: %d Plätze. Fang sie vor dem Einsteigen!",
		ev_seat = "💺 %s hat einen Platz! Noch frei: %d",
		ev_seat_bot = "💺 Ein Bürger hat einen Platz! Noch frei: %d",
		ev_last = "🏁 %s hat den LETZTEN Platz! Der Hubschrauber fliegt los!",
		ev_last_bot = "🏁 Ein Bürger hat den LETZTEN Platz! Der Hubschrauber fliegt los!",
		ev_full = "🚁 Keine Plätze mehr - der Hubschrauber ist weg!",
		ev_gone = "ZURÜCKGELASSEN! HALTE BIS ZUM ENDE DURCH",
	},
	it = {
		ev_land = "🚁 È arrivato l'elicottero: solo %d posti! Non bastano per tutti - CORRI!",
		ev_land_z = "🚁 L'elicottero è atterrato con %d posti. Prendili prima che salgano!",
		ev_seat = "💺 %s ha preso un posto! Posti rimasti: %d",
		ev_seat_bot = "💺 Un cittadino ha preso un posto! Posti rimasti: %d",
		ev_last = "🏁 %s ha preso l'ULTIMO posto! L'elicottero parte!",
		ev_last_bot = "🏁 Un cittadino ha preso l'ULTIMO posto! L'elicottero parte!",
		ev_full = "🚁 Niente più posti - l'elicottero è partito!",
		ev_gone = "RIMASTO A TERRA! RESISTI FINO ALLA FINE",
	},
	pl = {
		ev_land = "🚁 Helikopter przyleciał: tylko %d miejsc! Nie dla wszystkich - UCIEKAJ!",
		ev_land_z = "🚁 Helikopter wylądował, ma %d miejsc. Złap ich, zanim wsiądą!",
		ev_seat = "💺 %s zajął miejsce! Zostało miejsc: %d",
		ev_seat_bot = "💺 Mieszkaniec zajął miejsce! Zostało miejsc: %d",
		ev_last = "🏁 %s zajął OSTATNIE miejsce! Helikopter odlatuje!",
		ev_last_bot = "🏁 Mieszkaniec zajął OSTATNIE miejsce! Helikopter odlatuje!",
		ev_full = "🚁 Brak miejsc - helikopter odleciał!",
		ev_gone = "ZOSTAŁEŚ! PRZETRWAJ DO KOŃCA",
	},
	tr = {
		ev_land = "🚁 Helikopter geldi: sadece %d koltuk! Herkese yetmez - KOŞ!",
		ev_land_z = "🚁 Helikopter %d koltukla indi. Binmeden yakala!",
		ev_seat = "💺 %s bir koltuk kaptı! Kalan koltuk: %d",
		ev_seat_bot = "💺 Bir vatandaş koltuk kaptı! Kalan koltuk: %d",
		ev_last = "🏁 %s SON koltuğu kaptı! Helikopter kalkıyor!",
		ev_last_bot = "🏁 Bir vatandaş SON koltuğu kaptı! Helikopter kalkıyor!",
		ev_full = "🚁 Koltuk kalmadı - helikopter uçtu gitti!",
		ev_gone = "GERİDE KALDIN! SONUNA KADAR DAYAN",
	},
	id = {
		ev_land = "🚁 Helikopter datang: hanya %d kursi! Tidak cukup untuk semua - LARI!",
		ev_land_z = "🚁 Helikopter mendarat dengan %d kursi. Tangkap mereka sebelum naik!",
		ev_seat = "💺 %s dapat kursi! Sisa kursi: %d",
		ev_seat_bot = "💺 Seorang warga dapat kursi! Sisa kursi: %d",
		ev_last = "🏁 %s dapat kursi TERAKHIR! Helikopter berangkat!",
		ev_last_bot = "🏁 Seorang warga dapat kursi TERAKHIR! Helikopter berangkat!",
		ev_full = "🚁 Kursi habis - helikopter sudah terbang!",
		ev_gone = "TERTINGGAL! BERTAHAN SAMPAI AKHIR",
	},
	vi = {
		ev_land = "🚁 Trực thăng đến rồi: chỉ có %d chỗ! Không đủ cho tất cả - CHẠY!",
		ev_land_z = "🚁 Trực thăng hạ cánh với %d chỗ. Bắt họ trước khi lên máy bay!",
		ev_seat = "💺 %s đã giành một chỗ! Còn lại: %d",
		ev_seat_bot = "💺 Một người dân đã giành một chỗ! Còn lại: %d",
		ev_last = "🏁 %s giành chỗ CUỐI CÙNG! Trực thăng cất cánh!",
		ev_last_bot = "🏁 Một người dân giành chỗ CUỐI CÙNG! Trực thăng cất cánh!",
		ev_full = "🚁 Hết chỗ - trực thăng đã bay đi!",
		ev_gone = "BỊ BỎ LẠI! CỐ SỐNG ĐẾN CUỐI",
	},
	th = {
		ev_land = "🚁 เฮลิคอปเตอร์มาแล้ว: มีแค่ %d ที่นั่ง! ไม่พอทุกคน - วิ่ง!",
		ev_land_z = "🚁 เฮลิคอปเตอร์ลงจอดแล้ว มี %d ที่นั่ง จับพวกเขาก่อนขึ้น!",
		ev_seat = "💺 %s ได้ที่นั่งแล้ว! เหลือ %d ที่",
		ev_seat_bot = "💺 ชาวเมืองได้ที่นั่งแล้ว! เหลือ %d ที่",
		ev_last = "🏁 %s ได้ที่นั่งสุดท้าย! เฮลิคอปเตอร์กำลังออก!",
		ev_last_bot = "🏁 ชาวเมืองได้ที่นั่งสุดท้าย! เฮลิคอปเตอร์กำลังออก!",
		ev_full = "🚁 ที่นั่งเต็ม - เฮลิคอปเตอร์บินไปแล้ว!",
		ev_gone = "ตกเครื่อง! เอาตัวรอดให้ถึงจบ",
	},
	ko = {
		ev_land = "🚁 헬기 도착: 자리는 %d개뿐! 모두 탈 수 없어 - 달려!",
		ev_land_z = "🚁 헬기가 %d개의 자리로 착륙했다. 타기 전에 잡아!",
		ev_seat = "💺 %s 님이 자리를 차지했다! 남은 자리: %d",
		ev_seat_bot = "💺 시민이 자리를 차지했다! 남은 자리: %d",
		ev_last = "🏁 %s 님이 마지막 자리를 차지했다! 헬기가 떠난다!",
		ev_last_bot = "🏁 시민이 마지막 자리를 차지했다! 헬기가 떠난다!",
		ev_full = "🚁 자리가 없다 - 헬기가 떠났다!",
		ev_gone = "남겨졌다! 끝까지 버텨라",
	},
	ja = {
		ev_land = "🚁 ヘリが来た：席は%d個だけ！全員は乗れない - 走れ！",
		ev_land_z = "🚁 ヘリが着陸、席は%d個。乗る前に捕まえろ！",
		ev_seat = "💺 %sが席を取った！残り：%d",
		ev_seat_bot = "💺 市民が席を取った！残り：%d",
		ev_last = "🏁 %sが最後の席を取った！ヘリが飛び立つ！",
		ev_last_bot = "🏁 市民が最後の席を取った！ヘリが飛び立つ！",
		ev_full = "🚁 席がない - ヘリは飛び去った！",
		ev_gone = "取り残された！最後まで生き延びろ",
	},
}

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local bots: { any } = ctx.bots
	local evac: any = ctx.evac
	local Guard: any = ctx.Guard
	local botPresent: (any) -> boolean = ctx.botPresent

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

	type Flight = {
		model: Model,
		spot: Vector3,
		seats: number,      -- сколько мест было
		left: number,       -- сколько осталось
		landedAt: number,
		runners: { [any]: boolean }, -- жители, которые бегут к вертолёту
		boarding: { [any]: number }, -- житель -> с какого времени стоит у вертолёта
		sign: TextLabel?,
		gone: boolean,
	}
	local flight: Flight? = nil
	local api: any = { flights = 0, botSeats = 0, playerSeats = 0 }
	ctx.evacSeats = api

	local function survivorsNow(): ({ Player }, { any })
		local players: { Player } = {}
		for player in pairs(inRound) do
			if not isZombie[player] and player.Parent then
				table.insert(players, player)
			end
		end
		local citizens: { any } = {}
		for _, bot in ipairs(bots) do
			if botPresent(bot) and not bot.zombie then
				table.insert(citizens, bot)
			end
		end
		return players, citizens
	end

	local function tellAll(key: string, ...: any)
		for player in pairs(inRound) do
			if player.Parent then
				ctx.toast(player, key, ...)
			end
		end
	end

	local function refreshSign(f: Flight)
		local sign = f.sign
		if sign then
			sign.Text = "💺 " .. tostring(f.left)
			sign.TextColor3 = if f.left <= 1 then Color3.fromRGB(255, 120, 80) else SEAT_COLOR
		end
	end

	local function makeSign(model: Model): TextLabel?
		local ring = model:FindFirstChild("Ring")
		if not ring or not ring:IsA("BasePart") then
			return nil
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "EvacSeats"
		gui.Size = UDim2.fromOffset(150, 60)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 700
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.25
		label.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = SEAT_COLOR
		label.TextStrokeTransparency = 0.4
		label.Text = ""
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = SEAT_COLOR
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		gui.Parent = ring
		return label
	end

	-- места кончились: вертолёт улетает прямо сейчас (как в конце раунда, только раньше)
	local function takeOff(f: Flight)
		if f.gone then
			return
		end
		f.gone = true
		local model = f.model
		if evac.model == model then
			evac.model = nil
			evac.spot = nil
		end
		local craft = model:FindFirstChild("Craft")
		if craft and craft:IsA("Model") and model.Parent then
			craft.Parent = model.Parent
			model:Destroy()
			local rotor = craft:FindFirstChild("w_heli", true)
			if rotor and rotor:IsA("Sound") then
				rotor.PlaybackSpeed = 1.2
			end
			task.spawn(function()
				local from = craft:GetPivot()
				for step = 1, 50 do
					if craft.Parent == nil then
						return
					end
					craft:PivotTo(from + Vector3.new(0, step * step * 0.07, 0))
					task.wait(0.05)
				end
				craft:Destroy()
			end)
		else
			model:Destroy()
		end
		local players = survivorsNow()
		for _, player in ipairs(players) do
			ctx.big(player, "ev_gone")
		end
		tellAll("ev_full")
	end

	local function seatTaken(f: Flight, who: string, isBot: boolean)
		f.left = math.max(0, f.left - 1)
		if isBot then
			api.botSeats += 1
		else
			api.playerSeats += 1
		end
		refreshSign(f)
		if ctx.sound then
			for player in pairs(inRound) do
				if player.Parent then
					ctx.sound(player, "seat")
				end
			end
		end
		if f.left == 0 then
			if isBot then
				tellAll("ev_last_bot")
			else
				tellAll("ev_last", who)
			end
			takeOff(f)
		elseif isBot then
			tellAll("ev_seat_bot", f.left)
		else
			-- сначала все видят «X улетает на вертолёте» (это пишет главный скрипт), через 2 секунды - сколько мест осталось
			local left = f.left
			task.delay(2, function()
				if not f.gone and flight == f then
					tellAll("ev_seat", who, left)
				end
			end)
		end
	end

	local function land(model: Model, spot: Vector3)
		local players, citizens = survivorsNow()
		local total = #players + #citizens
		local seats = math.max(1, total - 1)
		local f: Flight = {
			model = model, spot = spot, seats = seats, left = seats, landedAt = os.clock(),
			runners = {}, boarding = {}, sign = makeSign(model), gone = false,
		}
		for _, bot in ipairs(citizens) do
			if math.random() < BOT_SHARE then
				f.runners[bot] = true
			end
		end
		flight = f
		api.flights += 1
		api.seats = seats
		refreshSign(f)
		for player in pairs(inRound) do
			if player.Parent then
				ctx.toast(player, if isZombie[player] then "ev_land_z" else "ev_land", seats)
			end
		end
	end

	-- сесть может только тот, кому досталось место; занять его - сразу (двое в одну секунду не влезут на одно место)
	local oldSeat = Guard.seat
	Guard.seat = function(player: Player): boolean
		local f = flight
		if not f or f.gone or evac.model ~= f.model then
			return if oldSeat then oldSeat(player) else true
		end
		if f.left <= 0 then
			return false
		end
		seatTaken(f, player.DisplayName, false)
		return true
	end

	-- жители, которые решили улететь, бегут к вертолёту (а не просто убегают от зомби)
	local oldGoal = Guard.goal
	Guard.goal = function(bot: any, from: Vector3, goal: Vector3): Vector3
		local f = flight
		if f and not f.gone and f.left > 0 and evac.spot and f.runners[bot] and os.clock() - f.landedAt >= BOT_DELAY then
			local spot: Vector3 = evac.spot
			local dx, dz = spot.X - from.X, spot.Z - from.Z
			if dx * dx + dz * dz <= BOT_RANGE * BOT_RANGE then
				if bot.humanoid and bot.speed then
					bot.humanoid.WalkSpeed = bot.speed
				end
				return spot + Vector3.new(0, 3, 0)
			end
		end
		return if oldGoal then oldGoal(bot, from, goal) else goal
	end

	local function boardBots(f: Flight)
		local now = os.clock()
		for _, bot in ipairs(bots) do
			if f.left <= 0 or f.gone then
				return
			end
			if botPresent(bot) and not bot.zombie and f.runners[bot] then
				local p = bot.root.Position
				local dx, dz = p.X - f.spot.X, p.Z - f.spot.Z
				local near = dx * dx + dz * dz <= BOARD_RADIUS * BOARD_RADIUS and math.abs(p.Y - 3 - f.spot.Y) <= 8
				if near then
					local since = f.boarding[bot]
					if not since then
						f.boarding[bot] = now
					elseif now - since >= BOARD_TIME then
						f.boarding[bot] = nil
						f.runners[bot] = nil
						bot.alive = false
						bot.model:Destroy()
						seatTaken(f, "", true)
					end
				else
					f.boarding[bot] = nil
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(function()
				local model = evac.model
				local f = flight
				if model and evac.spot and (not f or f.model ~= model) then
					land(model, evac.spot)
				elseif f and not f.gone then
					if evac.model ~= f.model then
						-- раунд кончился и вертолёт убрал главный скрипт
						flight = nil
					else
						boardBots(f)
					end
				elseif f and f.gone and not model then
					flight = nil
				end
			end)
			if not ok then
				warn("[Zombie Tag] Evac: " .. tostring(err))
			end
		end
	end)

	api.flight = function(): any
		return flight
	end
	local _ = Players
	local _s = sessions
	return api
end
