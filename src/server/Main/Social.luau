--!strict
--[[
	ДРУЗЬЯ И КОДЫ (модуль Social)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Social. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Social, рядом с Extras). Запускает его модуль Extras.

	Что здесь:
	- награда за приглашение друга (официальная система Roblox): новичок, пришедший по ссылке друга,
	  получает подарок; пригласивший получает награду сразу (если он на сервере) или при следующем входе.
	  Баннер в окне приглашения включается в Creator Hub: Engagement -> Referral Rewards;
	- стойка "КОДЫ" в лобби: игрок вводит код и получает подарок. Каждый код - один раз на игрока.
	Экран ввода кода рисует сервер, нажатия передаёт скрипт ZT_Touch (ReplicatedStorage.ZT_Code).
]]

local INVITER_COINS = 150     -- пригласившему за каждого друга
local INVITER_SPINS = 1       -- и бесплатных вращений колеса
local NEWCOMER_COINS = 100    -- новичку, пришедшему по приглашению
local NEWCOMER_SPINS = 2
local INVITE_CAP = 20         -- больше скольких друзей награда не выдаётся
local STORE_NAME = "ZT_Referrals_v1"

-- КОДЫ: имя (большими буквами), подарок и срок (until - время UTC в секундах; nil - без срока).
-- coins - монеты, spins - вращения колеса, pumpkins - тыквы ивента, parts - детали стройки
local CODES: { [string]: { coins: number?, spins: number?, pumpkins: number?, parts: number?, untilTime: number? } } = {
	ZOMBLOCK = { coins = 100, spins = 1 },
	HALLOWEEN = { pumpkins = 10, spins = 1, untilTime = 1794268800 },
	RELEASE = { parts = 8, coins = 50 },
	TIKTOK = { coins = 150, spins = 1 }, -- только для роликов TikTok: по нему видно, сколько игроков пришло оттуда
}

local TEXT: { [string]: { [string]: string } } = {
	en = {
		cd_title = "🎁 CODES",
		cd_enter = "Enter a code",
		cd_redeem = "Redeem",
		cd_where = "New codes are in our TikTok and Roblox group",
		cd_ok = "✅ Done: %s",
		cd_big = "🎁 Code %s: %s",
		cd_used = "You have already used this code",
		cd_bad = "No such code",
		cd_wait = "Too many tries, wait a moment",
		cd_over = "This code has expired",
		rf_sign = "👥 Invite a friend: you get %d 💰 + 🎡 for each one!",
		rf_welcome = "👥 You came with a friend's invite! %s",
		rf_thanks = "👥 %s joined with your invite! %s",
		rf_thanks_n = "👥 Friends joined with your invite: %d! %s",
	},
	ru = {
		cd_title = "🎁 КОДЫ",
		cd_enter = "Введи код",
		cd_redeem = "Активировать",
		cd_where = "Новые коды — в нашем TikTok и группе Roblox",
		cd_ok = "✅ Готово: %s",
		cd_big = "🎁 Код %s: %s",
		cd_used = "Этот код ты уже вводил",
		cd_bad = "Такого кода нет",
		cd_wait = "Слишком много попыток, подожди немного",
		cd_over = "Срок этого кода закончился",
		rf_sign = "👥 Позови друга: за каждого %d 💰 + 🎡!",
		rf_welcome = "👥 Ты пришёл по приглашению друга! %s",
		rf_thanks = "👥 %s пришёл по твоему приглашению! %s",
		rf_thanks_n = "👥 По твоему приглашению пришли друзья: %d! %s",
	},
	es = {
		cd_title = "🎁 CÓDIGOS",
		cd_enter = "Escribe un código",
		cd_redeem = "Canjear",
		cd_where = "Los códigos nuevos están en nuestro TikTok y grupo de Roblox",
		cd_ok = "✅ Listo: %s",
		cd_big = "🎁 Código %s: %s",
		cd_used = "Ya usaste este código",
		cd_bad = "Ese código no existe",
		cd_wait = "Demasiados intentos, espera un momento",
		cd_over = "Este código ha caducado",
		rf_sign = "👥 Invita a un amigo: ¡%d 💰 + 🎡 por cada uno!",
		rf_welcome = "👥 ¡Llegaste con la invitación de un amigo! %s",
		rf_thanks = "👥 ¡%s llegó con tu invitación! %s",
		rf_thanks_n = "👥 Amigos que llegaron con tu invitación: %d. %s",
	},
	pt = {
		cd_title = "🎁 CÓDIGOS",
		cd_enter = "Digite um código",
		cd_redeem = "Resgatar",
		cd_where = "Códigos novos no nosso TikTok e grupo do Roblox",
		cd_ok = "✅ Pronto: %s",
		cd_big = "🎁 Código %s: %s",
		cd_used = "Você já usou este código",
		cd_bad = "Esse código não existe",
		cd_wait = "Tentativas demais, espere um pouco",
		cd_over = "Este código expirou",
		rf_sign = "👥 Convide um amigo: %d 💰 + 🎡 por cada um!",
		rf_welcome = "👥 Você veio pelo convite de um amigo! %s",
		rf_thanks = "👥 %s entrou pelo seu convite! %s",
		rf_thanks_n = "👥 Amigos que entraram pelo seu convite: %d! %s",
	},
	fr = {
		cd_title = "🎁 CODES",
		cd_enter = "Entre un code",
		cd_redeem = "Valider",
		cd_where = "Les nouveaux codes sont sur notre TikTok et notre groupe Roblox",
		cd_ok = "✅ C'est fait : %s",
		cd_big = "🎁 Code %s : %s",
		cd_used = "Tu as déjà utilisé ce code",
		cd_bad = "Ce code n'existe pas",
		cd_wait = "Trop d'essais, attends un peu",
		cd_over = "Ce code a expiré",
		rf_sign = "👥 Invite un ami : %d 💰 + 🎡 pour chacun !",
		rf_welcome = "👥 Tu es venu grâce à l'invitation d'un ami ! %s",
		rf_thanks = "👥 %s est venu grâce à ton invitation ! %s",
		rf_thanks_n = "👥 Amis venus grâce à ton invitation : %d ! %s",
	},
	de = {
		cd_title = "🎁 CODES",
		cd_enter = "Code eingeben",
		cd_redeem = "Einlösen",
		cd_where = "Neue Codes gibt es auf unserem TikTok und in der Roblox-Gruppe",
		cd_ok = "✅ Fertig: %s",
		cd_big = "🎁 Code %s: %s",
		cd_used = "Diesen Code hast du schon benutzt",
		cd_bad = "Diesen Code gibt es nicht",
		cd_wait = "Zu viele Versuche, warte kurz",
		cd_over = "Dieser Code ist abgelaufen",
		rf_sign = "👥 Lade einen Freund ein: %d 💰 + 🎡 für jeden!",
		rf_welcome = "👥 Du bist über die Einladung eines Freundes gekommen! %s",
		rf_thanks = "👥 %s ist über deine Einladung gekommen! %s",
		rf_thanks_n = "👥 Freunde über deine Einladung: %d! %s",
	},
	it = {
		cd_title = "🎁 CODICI",
		cd_enter = "Inserisci un codice",
		cd_redeem = "Riscatta",
		cd_where = "I nuovi codici sono sul nostro TikTok e nel gruppo Roblox",
		cd_ok = "✅ Fatto: %s",
		cd_big = "🎁 Codice %s: %s",
		cd_used = "Hai già usato questo codice",
		cd_bad = "Questo codice non esiste",
		cd_wait = "Troppi tentativi, aspetta un attimo",
		cd_over = "Questo codice è scaduto",
		rf_sign = "👥 Invita un amico: %d 💰 + 🎡 per ognuno!",
		rf_welcome = "👥 Sei arrivato con l'invito di un amico! %s",
		rf_thanks = "👥 %s è arrivato con il tuo invito! %s",
		rf_thanks_n = "👥 Amici arrivati con il tuo invito: %d! %s",
	},
	pl = {
		cd_title = "🎁 KODY",
		cd_enter = "Wpisz kod",
		cd_redeem = "Odbierz",
		cd_where = "Nowe kody są na naszym TikToku i w grupie Roblox",
		cd_ok = "✅ Gotowe: %s",
		cd_big = "🎁 Kod %s: %s",
		cd_used = "Ten kod został już przez ciebie użyty",
		cd_bad = "Nie ma takiego kodu",
		cd_wait = "Za dużo prób, poczekaj chwilę",
		cd_over = "Ten kod wygasł",
		rf_sign = "👥 Zaproś znajomego: %d 💰 + 🎡 za każdego!",
		rf_welcome = "👥 Przyszedłeś z zaproszenia znajomego! %s",
		rf_thanks = "👥 %s przyszedł z twojego zaproszenia! %s",
		rf_thanks_n = "👥 Znajomi z twojego zaproszenia: %d! %s",
	},
	tr = {
		cd_title = "🎁 KODLAR",
		cd_enter = "Bir kod gir",
		cd_redeem = "Kullan",
		cd_where = "Yeni kodlar TikTok hesabımızda ve Roblox grubumuzda",
		cd_ok = "✅ Tamam: %s",
		cd_big = "🎁 Kod %s: %s",
		cd_used = "Bu kodu zaten kullandın",
		cd_bad = "Böyle bir kod yok",
		cd_wait = "Çok fazla deneme, biraz bekle",
		cd_over = "Bu kodun süresi doldu",
		rf_sign = "👥 Arkadaşını davet et: her biri için %d 💰 + 🎡!",
		rf_welcome = "👥 Bir arkadaşının davetiyle geldin! %s",
		rf_thanks = "👥 %s davetinle geldi! %s",
		rf_thanks_n = "👥 Davetinle gelen arkadaşlar: %d! %s",
	},
	id = {
		cd_title = "🎁 KODE",
		cd_enter = "Masukkan kode",
		cd_redeem = "Tukar",
		cd_where = "Kode baru ada di TikTok dan grup Roblox kami",
		cd_ok = "✅ Berhasil: %s",
		cd_big = "🎁 Kode %s: %s",
		cd_used = "Kamu sudah memakai kode ini",
		cd_bad = "Kode itu tidak ada",
		cd_wait = "Terlalu banyak percobaan, tunggu sebentar",
		cd_over = "Kode ini sudah kedaluwarsa",
		rf_sign = "👥 Ajak teman: %d 💰 + 🎡 untuk setiap teman!",
		rf_welcome = "👥 Kamu datang lewat undangan teman! %s",
		rf_thanks = "👥 %s datang lewat undanganmu! %s",
		rf_thanks_n = "👥 Teman yang datang lewat undanganmu: %d! %s",
	},
	vi = {
		cd_title = "🎁 MÃ QUÀ",
		cd_enter = "Nhập mã",
		cd_redeem = "Đổi quà",
		cd_where = "Mã mới có trên TikTok và nhóm Roblox của chúng tôi",
		cd_ok = "✅ Xong: %s",
		cd_big = "🎁 Mã %s: %s",
		cd_used = "Bạn đã dùng mã này rồi",
		cd_bad = "Không có mã này",
		cd_wait = "Thử quá nhiều lần, chờ một chút",
		cd_over = "Mã này đã hết hạn",
		rf_sign = "👥 Mời bạn bè: mỗi người %d 💰 + 🎡!",
		rf_welcome = "👥 Bạn đến nhờ lời mời của bạn bè! %s",
		rf_thanks = "👥 %s đã vào nhờ lời mời của bạn! %s",
		rf_thanks_n = "👥 Bạn bè vào nhờ lời mời của bạn: %d! %s",
	},
	th = {
		cd_title = "🎁 โค้ด",
		cd_enter = "ใส่โค้ด",
		cd_redeem = "แลก",
		cd_where = "โค้ดใหม่อยู่ใน TikTok และกลุ่ม Roblox ของเรา",
		cd_ok = "✅ เรียบร้อย: %s",
		cd_big = "🎁 โค้ด %s: %s",
		cd_used = "คุณใช้โค้ดนี้ไปแล้ว",
		cd_bad = "ไม่มีโค้ดนี้",
		cd_wait = "ลองหลายครั้งเกินไป รอสักครู่",
		cd_over = "โค้ดนี้หมดอายุแล้ว",
		rf_sign = "👥 ชวนเพื่อน: ได้ %d 💰 + 🎡 ต่อเพื่อนหนึ่งคน!",
		rf_welcome = "👥 คุณมาตามคำชวนของเพื่อน! %s",
		rf_thanks = "👥 %s มาตามคำชวนของคุณ! %s",
		rf_thanks_n = "👥 เพื่อนที่มาตามคำชวนของคุณ: %d คน! %s",
	},
	ko = {
		cd_title = "🎁 코드",
		cd_enter = "코드를 입력하세요",
		cd_redeem = "받기",
		cd_where = "새 코드는 TikTok과 로블록스 그룹에 있어요",
		cd_ok = "✅ 완료: %s",
		cd_big = "🎁 코드 %s: %s",
		cd_used = "이미 사용한 코드예요",
		cd_bad = "없는 코드예요",
		cd_wait = "시도가 너무 많아요, 잠시 기다려요",
		cd_over = "기간이 끝난 코드예요",
		rf_sign = "👥 친구를 초대해요: 한 명마다 %d 💰 + 🎡!",
		rf_welcome = "👥 친구의 초대로 왔어요! %s",
		rf_thanks = "👥 %s님이 내 초대로 왔어요! %s",
		rf_thanks_n = "👥 내 초대로 온 친구: %d명! %s",
	},
	ja = {
		cd_title = "🎁 コード",
		cd_enter = "コードを入力",
		cd_redeem = "受け取る",
		cd_where = "新しいコードは TikTok とRobloxグループで発表",
		cd_ok = "✅ 完了: %s",
		cd_big = "🎁 コード %s: %s",
		cd_used = "このコードはもう使ったよ",
		cd_bad = "そのコードはないよ",
		cd_wait = "ためしすぎ、少し待ってね",
		cd_over = "このコードは期限切れ",
		rf_sign = "👥 フレンドを招待: 1人ごとに %d 💰 + 🎡!",
		rf_welcome = "👥 フレンドの招待で来たね! %s",
		rf_thanks = "👥 %s があなたの招待で来たよ! %s",
		rf_thanks_n = "👥 あなたの招待で来たフレンド: %d 人! %s",
	},
}

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local sv = ctx.survival
	local map = workspace:FindFirstChild("ZombieTagMap")
	if not sv or not map then
		return nil
	end
	local LOBBY_Y: number = ctx.LOBBY_Y
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
	local warned: { [string]: number } = {}
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok and os.clock() - (warned[what] or -100) > 60 then
			warned[what] = os.clock()
			warn("[Zombie Tag] Social (" .. what .. "): " .. tostring(err))
		end
	end
	local function trusted(session: any): boolean
		return session.canSave or not ctx.saveBroken()
	end
	local function items(session: any): any
		return sv.stock(session).items
	end
	-- подарок: монеты, вращения, тыквы, детали; возвращает строку вида "+100 💰  +1 🎡"
	local function give(session: any, gift: any): string
		local parts = {}
		if gift.coins and gift.coins > 0 then
			session.profile.coins += gift.coins
			table.insert(parts, "+" .. gift.coins .. " 💰")
		end
		if gift.spins and gift.spins > 0 and ctx.luck then
			ctx.luck.addSpin(session, gift.spins)
			table.insert(parts, "+" .. gift.spins .. " 🎡")
		end
		if gift.pumpkins and gift.pumpkins > 0 and ctx.halloween then
			ctx.halloween.addPumpkins(session, gift.pumpkins)
			table.insert(parts, "+" .. gift.pumpkins .. " 🎃")
		end
		if gift.parts and gift.parts > 0 then
			local ext = sv.stock(session)
			ext.mats = math.min(9999, ext.mats + gift.parts)
			table.insert(parts, "+" .. gift.parts .. " 🔩")
		end
		return table.concat(parts, "  ")
	end

	---------------------------------------------------------------------
	-- ПРИГЛАШЕНИЯ
	---------------------------------------------------------------------
	local store: any = nil
	pcall(function()
		store = game:GetService("DataStoreService"):GetDataStore(STORE_NAME)
	end)
	local checked: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function rewardInviter(inviter: Player, session: any, count: number, who: string?)
		local list = items(session)
		local room = math.max(0, INVITE_CAP - (list.rf_n or 0))
		local n = math.min(count, room)
		if n <= 0 then
			return
		end
		list.rf_n = (list.rf_n or 0) + n
		local text = give(session, { coins = INVITER_COINS * n, spins = INVITER_SPINS * n })
		if ctx.sync then
			ctx.sync(inviter)
		end
		if who then
			ctx.big(inviter, "rf_thanks", who, text)
		else
			ctx.big(inviter, "rf_thanks_n", n, text)
		end
		ctx.sound(inviter, "win")
	end
	-- новичок пришёл по ссылке друга: подарок ему; другу - сейчас или при следующем входе
	local function checkReferral(player: Player, session: any)
		local profile = session.profile
		local list = items(session)
		if list.rf_in or profile.rounds + profile.wins + profile.infections > 0 then
			return
		end
		local ok, data = pcall(function(): any
			return (player :: any):GetJoinData()
		end)
		local from = if ok and type(data) == "table" then tonumber(data.ReferredByPlayerId) else nil
		if not from or from <= 0 or from == player.UserId then
			return
		end
		list.rf_in = 1
		local text = give(session, { coins = NEWCOMER_COINS, spins = NEWCOMER_SPINS })
		if ctx.sync then
			ctx.sync(player)
		end
		task.delay(12, function()
			if player.Parent then
				ctx.toast(player, "rf_welcome", text)
			end
		end)
		local inviter = Players:GetPlayerByUserId(from)
		local other = if inviter then sessions[inviter] else nil
		if inviter and other and trusted(other) then
			rewardInviter(inviter, other, 1, player.DisplayName)
		elseif store then
			task.spawn(function()
				pcall(function()
					store:UpdateAsync("u" .. from, function(old: any): any
						return math.min(50, (tonumber(old) or 0) + 1)
					end)
				end)
			end)
		end
	end
	-- пригласивший зашёл: забрать награды за друзей, пришедших без него
	local function collectPending(player: Player, session: any)
		if not store then
			return
		end
		local taken = 0
		local ok = pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old: any): any
				taken = tonumber(old) or 0
				return if taken > 0 then 0 else nil
			end)
		end)
		if ok and taken > 0 and player.Parent and sessions[player] == session then
			task.delay(8, function()
				if player.Parent and sessions[player] == session then
					rewardInviter(player, session, taken, nil)
				end
			end)
		end
	end

	---------------------------------------------------------------------
	-- СТОЙКА КОДОВ В ЛОББИ
	---------------------------------------------------------------------
	local FLOOR = LOBBY_Y + 0.5
	local KIOSK = Vector3.new(-24, FLOOR, 10)
	local face = Vector3.new(0 - KIOSK.X, 0, 26 - KIOSK.Z).Unit
	local model = Instance.new("Model")
	model.Name = "CodesKiosk"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local deskAt = KIOSK + Vector3.new(0, 1.6, 0) + face * 1.2
	local desk = part("Desk", Vector3.new(5, 3.2, 2), CFrame.lookAt(deskAt, deskAt + face), Color3.fromRGB(52, 40, 82), Enum.Material.SmoothPlastic)
	desk.CanQuery = true
	part("DeskTop", Vector3.new(5.4, 0.3, 2.4), CFrame.lookAt(deskAt + Vector3.new(0, 1.7, 0), deskAt + Vector3.new(0, 1.7, 0) + face), Color3.fromRGB(120, 230, 160), Enum.Material.Neon)
	local signAt = KIOSK + Vector3.new(0, 5.6, 0)
	local sign = part("CodesSign", Vector3.new(9, 4.6, 0.4), CFrame.lookAt(signAt, signAt + face), Color3.fromRGB(26, 22, 44), Enum.Material.SmoothPlastic)
	part("CodesTrim", Vector3.new(9.6, 5.2, 0.3), CFrame.lookAt(signAt - face * 0.15, signAt - face * 0.15 + face), Color3.fromRGB(120, 230, 160), Enum.Material.Neon)
	local right = Vector3.new(-face.Z, 0, face.X)
	for _, side in ipairs({ -3.8, 3.8 }) do
		local leg = KIOSK + right * side + Vector3.new(0, 1.6, 0) - face * 0.3
		part("CodesLeg", Vector3.new(0.45, 3.2, 0.45), CFrame.new(leg), Color3.fromRGB(70, 60, 100), Enum.Material.Metal)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Codes"
	prompt.ActionText = "🎁"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = desk
	model.Parent = map

	local remote = Instance.new("RemoteEvent")
	remote.Name = "ZT_Code"
	remote.Parent = RS
	local DARK = Color3.fromRGB(18, 22, 30)
	local function label(parent: Instance, name: string, pos: UDim2, size: UDim2, font: Enum.Font, color: Color3, text: string): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = pos
		t.Size = size
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = text
		t.Parent = parent
		return t
	end
	local function corner(parent: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = parent
	end
	local function openCodes(player: Player)
		local holder = player:FindFirstChild("PlayerGui")
		if not holder then
			return
		end
		local old = holder:FindFirstChild("ZT_Codes")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "ZT_Codes"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 25
		gui.IgnoreGuiInset = true
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.45)
		panel.Size = UDim2.new(0, 340, 0, 210)
		panel.BackgroundColor3 = DARK
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.Parent = gui
		corner(panel, 14)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 230, 160)
		stroke.Thickness = 2
		stroke.Parent = panel
		label(panel, "Title", UDim2.new(0, 14, 0, 8), UDim2.new(1, -64, 0, 36), Enum.Font.GothamBlack, Color3.new(1, 1, 1), ctx.tr(player, "cd_title"))
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Size = UDim2.new(0, 34, 0, 34)
		close.Position = UDim2.new(1, -44, 0, 9)
		close.BackgroundColor3 = Color3.fromRGB(60, 64, 76)
		close.Text = "X"
		close.TextScaled = true
		close.Font = Enum.Font.GothamBold
		close.TextColor3 = Color3.new(1, 1, 1)
		close.Parent = panel
		corner(close, 8)
		local box = Instance.new("TextBox")
		box.Name = "Input"
		box.Position = UDim2.new(0, 14, 0, 54)
		box.Size = UDim2.new(1, -28, 0, 46)
		box.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
		box.Font = Enum.Font.GothamBold
		box.TextScaled = true
		box.TextColor3 = Color3.new(1, 1, 1)
		box.PlaceholderText = ctx.tr(player, "cd_enter")
		box.PlaceholderColor3 = Color3.fromRGB(150, 156, 170)
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Parent = panel
		corner(box, 10)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = box
		local go = Instance.new("TextButton")
		go.Name = "Redeem"
		go.Position = UDim2.new(0, 14, 0, 108)
		go.Size = UDim2.new(1, -28, 0, 46)
		go.BackgroundColor3 = Color3.fromRGB(70, 190, 90)
		go.Font = Enum.Font.GothamBlack
		go.TextScaled = true
		go.TextColor3 = Color3.new(1, 1, 1)
		go.Text = ctx.tr(player, "cd_redeem")
		go.Parent = panel
		corner(go, 10)
		local pad2 = pad:Clone()
		pad2.Parent = go
		label(panel, "Status", UDim2.new(0, 14, 0, 162), UDim2.new(1, -28, 0, 34), Enum.Font.GothamBold, Color3.fromRGB(255, 225, 120), ctx.tr(player, "cd_where"))
		gui.Parent = holder
	end
	local function status(player: Player, text: string, good: boolean)
		local holder = player:FindFirstChild("PlayerGui")
		local gui = if holder then holder:FindFirstChild("ZT_Codes") else nil
		local panel = if gui then gui:FindFirstChild("Panel") else nil
		local line = if panel then panel:FindFirstChild("Status") else nil
		if line and line:IsA("TextLabel") then
			line.Text = text
			line.TextColor3 = if good then Color3.fromRGB(140, 255, 150) else Color3.fromRGB(255, 140, 130)
		end
	end
	local tries: { [Player]: { at: number, bad: number } } = setmetatable({}, { __mode = "k" }) :: any
	local function redeem(player: Player, raw: string)
		local session = sessions[player]
		if not session then
			return
		end
		local t: any = tries[player] or { at = -100, bad = 0 }
		tries[player] = t
		local now = os.clock()
		if now - t.at < 1.5 or t.bad >= 12 then
			status(player, ctx.tr(player, "cd_wait"), false)
			return
		end
		t.at = now
		if not trusted(session) then
			status(player, ctx.tr(player, "no_save"), false)
			return
		end
		local code = string.upper((string.gsub(string.sub(raw, 1, 40), "%s", "")))
		local gift = CODES[code]
		if not gift then
			t.bad += 1
			status(player, ctx.tr(player, "cd_bad"), false)
			ctx.sound(player, "deny")
			return
		end
		local key = "cd_" .. string.sub(code, 1, 20)
		local list = items(session)
		if list[key] then
			status(player, ctx.tr(player, "cd_used"), false)
			ctx.sound(player, "deny")
			return
		end
		if gift.untilTime and os.time() >= gift.untilTime then
			status(player, ctx.tr(player, "cd_over"), false)
			ctx.sound(player, "deny")
			return
		end
		list[key] = 1
		-- в аналитику: какой код ввели (Code_TIKTOK = игрок из TikTok)
		pcall(function()
			game:GetService("AnalyticsService"):LogCustomEvent(player, "Code_" .. code, 1)
		end)
		local text = give(session, gift)
		if ctx.sync then
			ctx.sync(player)
		end
		status(player, ctx.tr(player, "cd_ok", text), true)
		ctx.big(player, "cd_big", code, text)
		ctx.sound(player, "win")
	end
	prompt.Triggered:Connect(function(player: Player)
		safely("open", function()
			local root = ctx.getAlive(player)
			if root and (root.Position - desk.Position).Magnitude < 16 then
				openCodes(player)
			end
		end)
	end)
	remote.OnServerEvent:Connect(function(player: Player, what: any)
		safely("code", function()
			if type(what) ~= "string" or #what > 60 then
				return
			end
			if what == "close" then
				local holder = player:FindFirstChild("PlayerGui")
				local gui = if holder then holder:FindFirstChild("ZT_Codes") else nil
				if gui then
					gui:Destroy()
				end
			elseif string.sub(what, 1, 5) == "code:" then
				redeem(player, string.sub(what, 6))
			end
		end)
	end)

	-- надпись на стойке на языке игрока; экран кодов закрывается, когда игрок ушёл от стойки
	local signs: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				safely("tick", function()
					local session = sessions[player]
					if not session then
						return
					end
					if not checked[player] and trusted(session) then
						checked[player] = true
						checkReferral(player, session)
						task.spawn(collectPending, player, session)
					end
					local ui = signs[player]
					if not ui or not ui.gui.Parent then
						local holder = player:FindFirstChild("PlayerGui")
						if not holder then
							return
						end
						local gui = Instance.new("SurfaceGui")
						gui.Name = "ZT_CodesSign"
						gui.Adornee = sign
						gui.Face = Enum.NormalId.Front
						gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
						gui.PixelsPerStud = 50
						gui.LightInfluence = 0
						gui.ResetOnSpawn = false
						ui = {
							gui = gui,
							title = label(gui, "Title", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.3), Enum.Font.GothamBlack, Color3.fromRGB(140, 255, 170), ""),
							where = label(gui, "Where", UDim2.fromScale(0.04, 0.38), UDim2.fromScale(0.92, 0.18), Enum.Font.GothamBold, Color3.new(1, 1, 1), ""),
							invite = label(gui, "Invite", UDim2.fromScale(0.04, 0.62), UDim2.fromScale(0.92, 0.3), Enum.Font.GothamBold, Color3.fromRGB(255, 225, 120), ""),
						}
						gui.Parent = holder
						signs[player] = ui
					end
					local title, where, invite = ctx.tr(player, "cd_title"), ctx.tr(player, "cd_where"), ctx.tr(player, "rf_sign", INVITER_COINS)
					if ui.title.Text ~= title then
						ui.title.Text = title
						ui.where.Text = where
						ui.invite.Text = invite
					end
					local holder = player:FindFirstChild("PlayerGui")
					local open = if holder then holder:FindFirstChild("ZT_Codes") else nil
					local root = ctx.getAlive(player)
					if open and (not root or (root.Position - desk.Position).Magnitude > 20) then
						open:Destroy()
					end
				end)
			end
		end
	end)

	local api = { codes = CODES, redeem = redeem, open = openCodes, prompt = prompt, desk = desk, signs = signs, give = give, store = store }
	ctx.social = api
	return api
end
