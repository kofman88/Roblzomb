--!strict
--[[
	ПЕРВЫЕ МИНУТЫ НОВИЧКА (модуль Onboarding)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Onboarding. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Onboarding, рядом с Extras). Запускает его модуль Extras.

	Что здесь:
	- интро 6 секунд при самом первом входе: пролёт над городом и три слова (экран рисует скрипт ZT_Touch);
	- новичок не ждёт в лобби: идущий раунд берёт его сразу, выжившим и с форой - 8 секунд его нельзя поймать;
	- в его первом раунде зомби-боты чуют его издалека: страх приходит в первую минуту, а не через три;
	- одна монета всегда лежит у него на пути, и первая монета объясняет, зачем они нужны;
	- первое заражение - событие: экран "ТЕПЕРЬ ТЫ ОХОТНИК" и подсветка ближайшей жертвы.
	Всё это только для игроков без сыгранных раундов (первые 1-3 раунда). Настройки ниже.
]]

local INTRO_TIME = 6.5     -- сколько секунд длится интро (столько же раунд не забирает новичка)
local FORA = 8             -- сколько секунд новичка, вошедшего в идущий раунд, нельзя поймать
local LURE_FROM = 12       -- через сколько секунд первого раунда зомби-боты начинают чуять новичка...
local LURE_FOR = 40        -- ...и сколько секунд это длится
local LURE_RANGE = 90      -- с какого расстояния они его чуют (обычный слух бота - 16)
local HUNTER_ROUNDS = 3    -- в первых стольких раундах заражение показывает экран "Теперь ты охотник"
local PREY_TIME = 8        -- сколько секунд после заражения подсвечена ближайшая жертва
local COIN_NEAR = 16       -- на каком расстоянии перед новичком кладут монету

local TEXT: { [string]: { [string]: string } } = {
	en = {
		late_fresh = "🏃 The round is on! Run and hide: zombies can't catch you for 8 seconds",
		ob_intro = "HIDE.   RUN.   INFECT.",
		ob_hunter = "YOU ARE THE HUNTER NOW",
		ob_hunter2 = "Catch survivors: run to the glowing one",
		ob_near = "ZOMBIE NEARBY!",
		ob_coin = "💰 +%d! Coins buy zombie looks and trails in the shop",
	},
	ru = {
		late_fresh = "🏃 Раунд уже идёт! Беги и прячься: 8 секунд зомби тебя не поймают",
		ob_intro = "ПРЯЧЬСЯ.   БЕГИ.   ЗАРАЖАЙ.",
		ob_hunter = "ТЕПЕРЬ ТЫ ОХОТНИК",
		ob_hunter2 = "Лови выживших: беги к тому, кто подсвечен",
		ob_near = "ЗОМБИ РЯДОМ!",
		ob_coin = "💰 +%d! За монеты в магазине облики зомби и следы",
	},
	es = {
		late_fresh = "🏃 ¡La ronda ya empezó! Corre y escóndete: 8 segundos sin que te atrapen",
		ob_intro = "ESCÓNDETE.   CORRE.   INFECTA.",
		ob_hunter = "AHORA ERES EL CAZADOR",
		ob_hunter2 = "Atrapa supervivientes: corre hacia el que brilla",
		ob_near = "¡ZOMBI CERCA!",
		ob_coin = "💰 ¡+%d! Con monedas compras aspectos de zombi y estelas",
	},
	pt = {
		late_fresh = "🏃 A rodada já começou! Corra e se esconda: 8 segundos sem ser pego",
		ob_intro = "ESCONDA-SE.   CORRA.   INFECTE.",
		ob_hunter = "AGORA VOCÊ É O CAÇADOR",
		ob_hunter2 = "Pegue sobreviventes: corra até quem está brilhando",
		ob_near = "ZUMBI PERTO!",
		ob_coin = "💰 +%d! Moedas compram visuais de zumbi e rastros na loja",
	},
	fr = {
		late_fresh = "🏃 La manche a commencé ! Cours et cache-toi : 8 secondes sans être attrapé",
		ob_intro = "CACHE-TOI.   COURS.   INFECTE.",
		ob_hunter = "TU ES LE CHASSEUR MAINTENANT",
		ob_hunter2 = "Attrape les survivants : cours vers celui qui brille",
		ob_near = "ZOMBIE TOUT PRÈS !",
		ob_coin = "💰 +%d ! Les pièces achètent des looks de zombie et des traînées",
	},
	de = {
		late_fresh = "🏃 Die Runde läuft schon! Lauf und versteck dich: 8 Sekunden kann dich keiner fangen",
		ob_intro = "VERSTECK DICH.   LAUF.   INFIZIERE.",
		ob_hunter = "JETZT BIST DU DER JÄGER",
		ob_hunter2 = "Fang Überlebende: lauf zu dem, der leuchtet",
		ob_near = "ZOMBIE IN DER NÄHE!",
		ob_coin = "💰 +%d! Für Münzen gibt es Zombie-Looks und Spuren im Shop",
	},
	it = {
		late_fresh = "🏃 Il round è già iniziato! Corri e nasconditi: per 8 secondi nessuno ti prende",
		ob_intro = "NASCONDITI.   CORRI.   INFETTA.",
		ob_hunter = "ORA SEI TU IL CACCIATORE",
		ob_hunter2 = "Prendi i sopravvissuti: corri verso chi brilla",
		ob_near = "ZOMBI VICINO!",
		ob_coin = "💰 +%d! Con le monete compri aspetti da zombi e scie",
	},
	pl = {
		late_fresh = "🏃 Runda już trwa! Biegnij i chowaj się: przez 8 sekund nikt cię nie złapie",
		ob_intro = "CHOWAJ SIĘ.   BIEGNIJ.   ZARAŻAJ.",
		ob_hunter = "TERAZ TY JESTEŚ ŁOWCĄ",
		ob_hunter2 = "Łap ocalałych: biegnij do tego, kto świeci",
		ob_near = "ZOMBIE BLISKO!",
		ob_coin = "💰 +%d! Za monety kupisz wyglądy zombie i ślady w sklepie",
	},
	tr = {
		late_fresh = "🏃 Tur başladı bile! Koş ve saklan: 8 saniye kimse seni yakalayamaz",
		ob_intro = "SAKLAN.   KOŞ.   BULAŞTIR.",
		ob_hunter = "ARTIK AVCI SENSİN",
		ob_hunter2 = "Hayatta kalanları yakala: parlayana doğru koş",
		ob_near = "ZOMBİ YAKINDA!",
		ob_coin = "💰 +%d! Altınla mağazadan zombi görünümleri ve izler alınır",
	},
	id = {
		late_fresh = "🏃 Ronde sudah mulai! Lari dan sembunyi: 8 detik kamu tidak bisa ditangkap",
		ob_intro = "SEMBUNYI.   LARI.   TULARKAN.",
		ob_hunter = "SEKARANG KAMU PEMBURUNYA",
		ob_hunter2 = "Tangkap yang selamat: lari ke yang bersinar",
		ob_near = "ZOMBI DEKAT!",
		ob_coin = "💰 +%d! Koin bisa dipakai beli tampilan zombi dan jejak di toko",
	},
	vi = {
		late_fresh = "🏃 Vòng đấu đang diễn ra! Chạy và trốn đi: 8 giây không ai bắt được bạn",
		ob_intro = "TRỐN.   CHẠY.   LÂY NHIỄM.",
		ob_hunter = "GIỜ BẠN LÀ THỢ SĂN",
		ob_hunter2 = "Bắt người sống sót: chạy tới người đang phát sáng",
		ob_near = "ZOMBIE Ở GẦN!",
		ob_coin = "💰 +%d! Xu mua được diện mạo zombie và vệt sáng trong cửa hàng",
	},
	th = {
		late_fresh = "🏃 รอบเริ่มแล้ว! วิ่งแล้วซ่อนตัว: 8 วินาทีแรกซอมบี้จับคุณไม่ได้",
		ob_intro = "ซ่อน.   วิ่ง.   แพร่เชื้อ.",
		ob_hunter = "ตอนนี้คุณคือนักล่า",
		ob_hunter2 = "จับผู้รอดชีวิต: วิ่งไปหาคนที่เรืองแสง",
		ob_near = "ซอมบี้อยู่ใกล้!",
		ob_coin = "💰 +%d! เหรียญใช้ซื้อหน้าตาซอมบี้และเส้นแสงในร้านค้า",
	},
	ko = {
		late_fresh = "🏃 라운드가 진행 중! 달려서 숨어요: 8초 동안은 잡히지 않아요",
		ob_intro = "숨어라.   달려라.   감염시켜라.",
		ob_hunter = "이제 당신이 사냥꾼",
		ob_hunter2 = "생존자를 잡아요: 빛나는 사람에게 달려가요",
		ob_near = "좀비가 가까이!",
		ob_coin = "💰 +%d! 코인으로 상점에서 좀비 모습과 트레일을 살 수 있어요",
	},
	ja = {
		late_fresh = "🏃 ラウンド進行中！走って隠れて：8秒間はつかまらない",
		ob_intro = "隠れろ。   走れ。   感染させろ。",
		ob_hunter = "今度は君がハンターだ",
		ob_hunter2 = "生存者をつかまえろ：光っている人へ走れ",
		ob_near = "ゾンビが近い！",
		ob_coin = "💰 +%d！コインでショップのゾンビの姿やトレイルが買える",
	},
}

return function(ctx: any)
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local Guard = ctx.Guard

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
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok then
			warn("[Zombie Tag] Onboarding (" .. what .. "): " .. tostring(err))
		end
	end
	local function fresh(player: Player): boolean
		local session = sessions[player]
		return session ~= nil and session.profile.rounds == 0
	end

	---------------------------------------------------------------------
	-- ИНТРО. Самый первый персонаж новичка: сервер ставит на игрока надпись (ZT_Intro), экран показывает
	-- пролёт над городом. Пока интро идёт, раунд новичка не берёт (через Guard.stay).
	---------------------------------------------------------------------
	local introUntil: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local function onCharacter(player: Player)
		task.delay(1, function()
			safely("intro", function()
				if player.Parent ~= Players or not fresh(player) or player:GetAttribute("ZT_IntroDone") then
					return
				end
				player:SetAttribute("ZT_IntroDone", true)
				introUntil[player] = os.clock() + INTRO_TIME
				player:SetAttribute("ZT_Intro", ctx.tr(player, "ob_intro"))
			end)
		end)
	end
	local function watch(player: Player)
		-- профиль загружается чуть позже персонажа: интро ждёт его до 8 секунд
		player.CharacterAdded:Connect(function()
			for _ = 1, 16 do
				if sessions[player] then
					break
				end
				task.wait(0.5)
			end
			onCharacter(player)
		end)
		if player.Character then
			task.spawn(function()
				for _ = 1, 16 do
					if sessions[player] then
						break
					end
					task.wait(0.5)
				end
				onCharacter(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	local oldStay = Guard.stay
	Guard.stay = function(player: Player): boolean
		-- новичка раунд не берёт, пока его интро не закончилось (или ещё не началось)
		if fresh(player) then
			local until_ = introUntil[player]
			if not until_ or os.clock() < until_ then
				return true
			end
		end
		return oldStay(player)
	end

	---------------------------------------------------------------------
	-- СРАЗУ В ИГРУ. Новичок входит в идущий раунд выжившим (Guard.fresh), и пауза в лобби для него короче:
	-- главный цикл спрашивает Guard.eager() через 5 секунд отсчёта.
	---------------------------------------------------------------------
	Guard.fresh = function(player: Player): boolean
		local ok, result = pcall(fresh, player)
		return ok and result == true
	end
	local oldEager = Guard.eager
	Guard.eager = function(all: boolean?): boolean
		if not all then
			for player, session in pairs(sessions) do
				if session.profile.rounds == 0 and player.Parent == Players and not Guard.stay(player) and ctx.getAlive(player) then
					return true -- новичок на сервере: раунд начинается через 5 секунд
				end
			end
		end
		return oldEager(all)
	end

	---------------------------------------------------------------------
	-- ЧТО ПРОИСХОДИТ РАЗ В ЧЕТВЕРТЬ СЕКУНДЫ: фора, приманка для ботов, монета на пути,
	-- экран охотника и подсветка жертвы
	---------------------------------------------------------------------
	local wasIn: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local wasZombie: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local roundSeen = 0
	local roundStart = 0
	local lure: { [Player]: { number } } = setmetatable({}, { __mode = "k" }) :: any -- с какого и до какого времени боты чуют игрока
	local prey: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any    -- до какого времени подсвечена жертва
	local coinTold: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	Guard.lure = function(player: Player): number
		local span = lure[player]
		local now = os.clock()
		return if span and now >= span[1] and now < span[2] then LURE_RANGE else 0
	end
	-- монета на пути: ближайшая к новичку монета переезжает на дорогу перед ним
	local function coinAhead(player: Player)
		local root = ctx.getAlive(player)
		if not root then
			return
		end
		local best: any, bestDistance = nil, math.huge
		for _, pickup in ipairs(ctx.pickups) do
			local part = pickup.part
			if pickup.kind == "coin" and part and part.Parent then
				local distance = (part.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = pickup, distance
				end
			end
		end
		if best and bestDistance > COIN_NEAR + 6 then
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.1 then
				flat = Vector3.new(0, 0, -1)
			end
			local target = root.Position + flat.Unit * COIN_NEAR
			-- только если впереди дорога, а не стена
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character :: any }
			if not workspace:Raycast(root.Position, flat.Unit * COIN_NEAR, params) then
				best.part.Position = Vector3.new(target.X, best.part.Position.Y, target.Z)
			end
		end
	end
	-- подсветка жертвы: Highlight лежит в PlayerGui, поэтому его видит только этот игрок
	local function preyFor(player: Player): Highlight?
		local gui = player:FindFirstChild("PlayerGui")
		if not gui then
			return nil
		end
		local light = gui:FindFirstChild("ZT_Prey")
		if not light then
			local new = Instance.new("Highlight")
			new.Name = "ZT_Prey"
			new.FillColor = Color3.fromRGB(255, 80, 80)
			new.OutlineColor = Color3.fromRGB(255, 255, 255)
			new.FillTransparency = 0.5
			new.OutlineTransparency = 0
			new.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			new.Enabled = false
			new.Parent = gui
			light = new
		end
		return light :: Highlight
	end
	local function nearestPrey(from: Vector3): Model?
		local best: Model?, bestDistance = nil, math.huge
		for other in pairs(inRound) do
			if not isZombie[other] then
				local root = ctx.getAlive(other)
				if root and other.Character then
					local distance = (root.Position - from).Magnitude
					if distance < bestDistance then
						best, bestDistance = other.Character, distance
					end
				end
			end
		end
		for _, bot in ipairs(ctx.bots) do
			if not bot.zombie and ctx.botPresent(bot) then
				local distance = (bot.root.Position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = bot.model, distance
				end
			end
		end
		return best
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			safely("tick", function()
				local now = os.clock()
				local roundActive, _, roundId = ctx.state()
				if roundActive and roundId ~= roundSeen then
					roundSeen = roundId
					roundStart = now
				end
				for _, player in ipairs(Players:GetPlayers()) do
					local session = sessions[player]
					local playing = roundActive and inRound[player] == true
					local zombie = playing and isZombie[player] == true
					if session then
						local rounds: number = session.profile.rounds
						-- вошёл в раунд
						if playing and not wasIn[player] then
							if rounds == 0 and not zombie then
								if now - roundStart > 3 then
									session.immuneUntil = math.max(session.immuneUntil or 0, now + FORA) -- вошёл посреди раунда: фора
								end
								lure[player] = { math.max(now, roundStart + LURE_FROM), math.max(now, roundStart + LURE_FROM) + LURE_FOR }
								task.delay(1.5, function()
									safely("coin", function()
										coinAhead(player)
									end)
								end)
							end
						end
						-- заразили
						if zombie and not wasZombie[player] and rounds < HUNTER_ROUNDS then
							player:SetAttribute("ZT_Hunt", ctx.tr(player, "ob_hunter") .. "\n" .. ctx.tr(player, "ob_hunter2"))
							prey[player] = now + PREY_TIME
						end
						-- первая монета
						if playing and not zombie and rounds == 0 and not coinTold[player] and (session.picked or 0) > 0 then
							coinTold[player] = true
							ctx.toast(player, "ob_coin", 3)
						end
						-- надпись о зомби рядом (экран показывает её сам, когда зомби близко)
						if rounds < HUNTER_ROUNDS and player:GetAttribute("ZT_NearText") == nil then
							player:SetAttribute("ZT_NearText", ctx.tr(player, "ob_near"))
						end
					end
					-- приманка только пока новичок выживший в своём первом раунде
					if lure[player] and (not playing or zombie) then
						lure[player] = nil
					end
					-- подсветка жертвы
					local light = preyFor(player)
					local preyUntil = prey[player]
					if light then
						if preyUntil and now < preyUntil and zombie then
							local root = ctx.getAlive(player)
							local target = if root then nearestPrey(root.Position) else nil
							light.Adornee = target
							light.Enabled = target ~= nil
						elseif light.Enabled then
							light.Enabled = false
							light.Adornee = nil
							prey[player] = nil
						end
					end
					wasIn[player] = playing
					wasZombie[player] = zombie
				end
			end)
		end
	end)
	return true
end
