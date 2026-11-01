--!strict
--[[
	ДОПОЛНЕНИЯ ИГРЫ ZOMBIE TAG

	КУДА ВСТАВИТЬ: это ModuleScript с именем Extras. Он лежит ВНУТРИ главного скрипта:
	ServerScriptService -> Script -> Extras (рядом с модулем Texts).

	Что здесь:
	- подсказки новичку в первых раундах и стрелка к укрытию, монете и вертолёту;
	- в финальной охоте зомби-игрок на пару секунд видит ближайших выживших;
	- касание зомби-игрока засчитывается по его экрану (с проверкой на сервере): задержка связи не мешает ловить;
	- защита от читеров: сервер возвращает назад тех, кто телепортируется, летает
	  или бегает слишком быстро, а упорных нарушителей отключает от игры;
	- значки (номера значков вписываются в главном скрипте, в настройке BADGES);
	- если прогресс игрока не загрузился при входе, он загружается позже сам;
	- таблица лидеров в лобби;
	- подарок новичку после первого раунда и стрелка к первой покупке;
	- задания и серия дней на экране, призы за 7 и 14 дней подряд;
	- режим недели и товар недели со скидкой (меняются сами каждый понедельник);
	- отметки шагов новичка для статистики: Creator Hub -> Analytics -> Funnels.

	Настройки лежат в главном скрипте. Здесь менять ничего не нужно.
]]

local BadgeService = game:GetService("BadgeService")

return function(ctx: any)
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local huds: { [Player]: any } = ctx.huds
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local RULES = ctx.RULES

	local function flat(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	-- ошибка у одного игрока не должна останавливать проверку остальных
	local warned: { [string]: number } = {}
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok and os.clock() - (warned[what] or -100) > 60 then
			warned[what] = os.clock()
			warn("[Zombie Tag] Extras (" .. what .. "): " .. tostring(err))
		end
	end

	---------------------------------------------------------------------
	-- ЗАЩИТА ОТ ЧИТЕРОВ
	-- У каждого игрока есть запас пути. Он пополняется со скоростью бега и тратится на каждый шаг.
	-- Кто прошёл больше, чем мог (телепорт, ускорение), взлетел или вышел за край города,
	-- возвращается туда, где ещё играл честно, и пару секунд не может ловить, подбирать
	-- предметы и садиться в вертолёт. Кто нарушает раз за разом, отключается от игры.
	---------------------------------------------------------------------
	local HOLD = 2.5      -- на сколько секунд бега хватает запаса: столько прощается при задержках связи
	local RISE = 34       -- на сколько шагов вверх можно подняться разом (прыжок, батут)
	local RISE_RATE = 30  -- и с какой скоростью можно лезть вверх дальше (лестница)
	local AIR_TIME = 2.5  -- сколько секунд можно висеть в воздухе, не падая
	local KICK_MARKS = 6  -- столько нарушений за полторы минуты - и игрок отключается
	local track: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
	local function entry(player: Player): any
		local e = track[player]
		if not e then
			e = {
				budget = 0, rise = RISE, air = 0, allowUntil = 0, allowAt = 0, skipUntil = 0, flagUntil = 0,
				pos = nil, safe = nil, root = nil, old = nil, oldAt = 0, older = nil, olderAt = 0,
				from = nil, anchor = nil, posAt = 0,
				walked = 0, round = 0, marks = {},
			}
			track[player] = e
		end
		return e
	end
	-- с какой скоростью игрок сейчас может бежать (стоящий на месте зомби - почти ни с какой)
	local function paceOf(humanoid: Humanoid): number
		return if humanoid.WalkSpeed <= 0 then 4 else math.max(humanoid.WalkSpeed, 16)
	end
	-- сервер сам переносит игрока в точку target (старт раунда, люк, вертолёт): это не нарушение.
	-- Но и в эти полторы секунды игрок может быть только там, откуда его забрали, или там, куда перенесли.
	ctx.Guard.allow = function(player: Player, target: Vector3?)
		local e = entry(player)
		local root = ctx.getAlive(player)
		-- два переноса подряд (город -> лобби -> дом): помним и то место, откуда игрока забрали в первый раз
		e.first = if os.clock() < e.allowUntil then (e.first or e.from) else nil
		e.allowAt = os.clock()
		e.allowUntil = e.allowAt + 1.5
		e.from = if root then root.Position else nil
		e.anchor = target
		e.root = root or e.root
		e.pos = nil
		e.old = nil
		e.older = nil
		if not target then
			-- точка не названа: куда сервер перенёс игрока, видно на следующем кадре
			task.delay(0, function()
				local moved = ctx.getAlive(player)
				e.anchor = if moved then moved.Position else nil
			end)
		end
	end
	-- умение «рывок» (модуль Season): на одну проверку запас пути больше на длину рывка.
	-- Остальные проверки (стены не нужны: сервер сам укоротил рывок; воздух, подъём, границы) остаются
	ctx.Guard.dash = function(player: Player, studs: number)
		local e = entry(player)
		e.slack = studs
		e.slackUntil = os.clock() + 1
		e.slackGiven = false
	end
	local function nearTeleport(e: any, pos: Vector3, pace: number, now: number): boolean
		local reach = 14 + pace * 1.4 * (now - e.allowAt)
		local anchor: Vector3?, from: Vector3? = e.anchor, e.from
		if not anchor then
			return true
		end
		local first: Vector3? = e.first
		return (pos - anchor).Magnitude <= reach or (from ~= nil and (pos - from).Magnitude <= reach)
			or (first ~= nil and (pos - first).Magnitude <= reach)
	end
	-- можно ли сейчас верить положению игрока
	ctx.Guard.ok = function(player: Player): boolean
		local e = track[player]
		if not e or not RULES.antiCheat then
			return true
		end
		local now = os.clock()
		if now < e.flagUntil then
			return false
		end
		-- рывок, который ещё не успела заметить проверка ниже: смотрим путь за последние полсекунды
		local root, humanoid = ctx.getAlive(player)
		if root and humanoid and now < e.allowUntil then
			return nearTeleport(e, root.Position, paceOf(humanoid), now)
		end
		local was: Vector3? = e.older or e.old or e.pos
		if root and humanoid and was and root == e.root then
			local pos: Vector3 = root.Position
			local since = now - (if e.older then e.olderAt elseif e.old then e.oldAt else e.posAt)
			local slack = if now < (e.slackUntil or 0) then e.slack or 0 else 0
			if flat(pos, was) > paceOf(humanoid) * 1.4 * since + 8 + slack or pos.Y - was.Y > RISE_RATE * since + 16 then
				return false
			end
		end
		return true
	end
	-- двигался ли игрок в этом раунде (тому, кто просто стоял, награда за раунд не положена)
	ctx.Guard.active = function(player: Player): boolean
		local e = track[player]
		local _, _, roundId = ctx.state()
		return not RULES.antiCheat or (e ~= nil and (e.round ~= roundId or e.walked >= 30))
	end

	if RULES.antiCheat then
		local overlap = OverlapParams.new()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		-- стоит ли игрок на чём-нибудь (или лезет по лестнице)
		local function grounded(character: Model, pos: Vector3): boolean
			params.FilterDescendantsInstances = { character }
			if workspace:Spherecast(pos, 1.5, Vector3.new(0, -9, 0), params) then
				return true
			end
			for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 5, overlap)) do
				if part:IsA("TrussPart") then
					return true
				end
			end
			return false
		end
		local function check(player: Player, now: number, dt: number, roundActive: boolean, roundId: number)
			local root, humanoid = ctx.getAlive(player)
			local character = player.Character
			local e = entry(player)
			if e.round ~= roundId then
				e.round = roundId
				e.walked = 0
			end
			if not root or not humanoid or not character then
				e.pos = nil
				e.old = nil
				e.older = nil
				return
			end
			if e.root ~= root then
				-- новый персонаж (вход или возрождение): даём время появиться на своём месте
				e.root = root
				e.pos = nil
				e.old = nil
				e.older = nil
				e.from = nil
				e.anchor = nil
				e.allowAt = now
				e.allowUntil = now + 3
				return
			end
			local pace = paceOf(humanoid)
			local cap = pace * 1.4 * HOLD
			local riseCap = if workspace.Gravity < 150 then 60 else RISE -- при лунной гравитации прыжки выше
			local pos: Vector3 = root.Position
			local playing = roundActive and inRound[player] == true
			-- возвращает игрока на место back и отмечает нарушение
			local function punish(back: Vector3)
				e.flagUntil = now + 2
				e.budget = cap / 2
				e.rise = riseCap / 2
				e.air = 0
				character:PivotTo(CFrame.new(back))
				-- запас пути не восстанавливается: кто продолжает нарушать, так и останется на месте
				e.pos = back
				e.posAt = now
				e.safe = back
				e.old = nil
				e.older = nil
				e.allowUntil = 0
				e.skipUntil = now + 0.5
				ctx.toast(player, "moved_back")
				-- упорный нарушитель отключается от игры (нарушения подряд за три секунды считаются за одно)
				local marks: { number } = e.marks
				if #marks == 0 or now - marks[#marks] >= 3 then
					table.insert(marks, now)
				end
				while marks[1] and now - marks[1] > 90 do
					table.remove(marks, 1)
				end
				if #marks >= KICK_MARKS then
					player:Kick(ctx.tr(player, "kicked"))
				end
			end
			if now < e.allowUntil or not e.pos then
				local anchor: Vector3? = e.anchor
				if now < e.allowUntil and anchor and not nearTeleport(e, pos, pace, now) then
					punish(anchor)
					return
				end
				e.pos = pos
				e.posAt = now
				e.safe = pos
				e.budget = cap
				e.rise = riseCap
				e.air = 0
				e.old = nil
				e.older = nil
				return
			end
			if now < e.skipUntil then
				-- игрока только что вернули назад: ждём, пока его телефон или компьютер это заметит
				e.budget = math.min(e.budget, cap)
				return
			end
			local step = flat(pos, e.pos)
			local bonus = 0
			if e.slackUntil and now < e.slackUntil + 0.5 and not e.slackGiven then
				bonus = e.slack or 0
				e.slackGiven = true
			end
			e.budget = math.min(cap, e.budget + cap / HOLD * dt) + bonus - step
			e.rise = math.min(riseCap, e.rise + RISE_RATE * dt) - math.max(0, pos.Y - e.pos.Y)
			local onGround = true
			if playing then
				onGround = grounded(character, pos)
				-- в воздухе можно быть, пока падаешь; висеть на месте или лететь вверх нельзя
				e.air = if onGround then 0 elseif pos.Y > e.pos.Y - 0.5 then e.air + dt else e.air
			else
				e.air = 0
			end
			-- участник раунда не может оказаться в лобби, под землёй, на стене вокруг города или за ней
			local limit = ctx.cityHalf + 1.5
			local outside = playing
				and (pos.Y > ctx.LOBBY_Y - 8 or pos.Y < -8 or math.abs(pos.X) > limit or math.abs(pos.Z) > limit)
			if e.budget < 0 or e.rise < 0 or e.air > AIR_TIME or outside then
				-- если возвращать некуда (игрок висит там же, где его видели в последний раз), он едет на перекрёсток
				local stuck = e.air > AIR_TIME and e.safe ~= nil and (e.safe - pos).Magnitude < 4
				punish(if outside or stuck or not e.safe then ctx.randomSpawn() else e.safe)
				return
			end
			if playing then
				e.walked += step
			end
			e.older = e.old
			e.olderAt = e.oldAt
			e.old = e.pos
			e.oldAt = now - dt
			e.pos = pos
			e.posAt = now
			-- сюда вернётся нарушитель: место, где игрок стоял на земле и запас пути был почти полон
			if onGround and e.budget >= cap * 0.6 then
				e.safe = pos
			end
		end
		task.spawn(function()
			local last = os.clock()
			while true do
				task.wait(0.25)
				local now = os.clock()
				local dt = math.min(now - last, 1)
				last = now
				local roundActive, _, roundId = ctx.state()
				for _, player in ipairs(Players:GetPlayers()) do
					safely("guard", function()
						check(player, now, dt, roundActive, roundId)
					end)
				end
			end
		end)
	end

	---------------------------------------------------------------------
	-- ИГРОКИ ПРОХОДЯТ ДРУГ СКВОЗЬ ДРУГА: так никого нельзя вытолкнуть, зажать в углу
	-- или подбросить (читеры умеют "подбрасывать" других игроков своим персонажем)
	---------------------------------------------------------------------
	pcall(function()
		local PhysicsService = game:GetService("PhysicsService")
		PhysicsService:RegisterCollisionGroup("ZT_Players")
		PhysicsService:CollisionGroupSetCollidable("ZT_Players", "ZT_Players", false)
		local function mark(part: Instance)
			if part:IsA("BasePart") then
				part.CollisionGroup = "ZT_Players"
			end
		end
		local function ghost(character: Model)
			for _, part in ipairs(character:GetDescendants()) do
				mark(part)
			end
			character.DescendantAdded:Connect(mark)
		end
		local function watch(player: Player)
			player.CharacterAdded:Connect(ghost)
			if player.Character then
				ghost(player.Character)
			end
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in ipairs(Players:GetPlayers()) do
			watch(player)
		end
	end)

	-- мячи и другие незакреплённые предметы двигает только сервер: читер не может швырнуть мяч в игрока
	task.spawn(function()
		local map = workspace:WaitForChild("ZombieTagMap", 30)
		if map then
			for _, part in ipairs(map:GetDescendants()) do
				if part:IsA("BasePart") and not part.Anchored then
					pcall(function()
						part:SetNetworkOwner(nil)
					end)
				end
			end
		end
	end)

	---------------------------------------------------------------------
	-- ЗНАЧКИ
	---------------------------------------------------------------------
	local function give(player: Player, name: string)
		local id = ctx.BADGES[name]
		local session = sessions[player]
		if type(id) ~= "number" or id <= 0 or not session or session.profile.badges[name] then
			return
		end
		local profile = session.profile
		profile.badges[name] = true
		task.spawn(function()
			local ok = pcall(function()
				BadgeService:AwardBadgeAsync(player.UserId, id)
			end)
			if not ok then
				profile.badges[name] = nil -- не получилось: попробуем в следующий раз
			end
		end)
	end
	-- проверяет, какие значки игрок уже заслужил; extra - значок за событие (например, "escape")
	ctx.Guard.badges = function(player: Player, extra: string?)
		local session = sessions[player]
		if not session then
			return
		end
		local profile = session.profile
		if extra then
			give(player, extra)
		end
		if profile.rounds >= 1 then
			give(player, "welcome")
		end
		if profile.infections >= 25 then
			give(player, "hunter")
		end
		if profile.wins >= 10 then
			give(player, "wins10")
		end
		if ctx.levelOf(profile.xp) >= 5 then
			give(player, "level5")
		end
	end

	---------------------------------------------------------------------
	-- ПРОГРЕСС НЕ ЗАГРУЗИЛСЯ ПРИ ВХОДЕ (сбой у Roblox): пробуем снова, пока не получится.
	-- К загруженному прогрессу добавляется всё, что игрок успел заработать за это время.
	---------------------------------------------------------------------
	local loaded: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- у кого прогресс загружался
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local session = sessions[player]
				-- только для тех, у кого прогресс так и не загрузился (а не для тех, кто зашёл с другого сервера)
				if session and not session.canSave and not loaded[session] and not session.leaving and ctx.saveBroken() then
					safely("reload", function()
						local temp = session.profile
						local profile, ok, lock = ctx.loadProfile(player)
						if not ok then
							return
						end
						if sessions[player] ~= session or session.profile ~= temp or session.canSave then
							-- игрок уже вышел: отпускаем его прогресс
							ctx.saveProfile(player, { profile = profile, canSave = true, lock = lock, leaving = false }, true)
							return
						end
						for _, field in ipairs({ "coins", "wins", "infections", "xp", "rounds" }) do
							profile[field] += math.max(0, temp[field])
						end
						for id in pairs(temp.owned) do
							profile.owned[id] = true
						end
						for name in pairs(temp.badges) do
							profile.badges[name] = true
						end
						if temp.trail ~= "" then
							profile.trail = temp.trail
						end
						if temp.skin ~= "" then
							profile.skin = temp.skin
						end
						profile.musicOff = temp.musicOff
						if ctx.mergeExt then
							ctx.mergeExt(profile, temp) -- запасы из модуля Survival
						end
						session.profile = profile
						session.lock = lock
						session.canSave = true
						ctx.refresh(player)
						ctx.daily(player)
					end)
				end
			end
		end
	end)

	---------------------------------------------------------------------
	-- СТРЕЛКА-ПОДСКАЗКА: её видит только сам игрок
	---------------------------------------------------------------------
	local spots: { [Player]: Part } = setmetatable({}, { __mode = "k" }) :: any
	local aims: { [Player]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any -- куда ведёт стрелка
	local leadParams = RaycastParams.new()
	leadParams.FilterType = Enum.RaycastFilterType.Exclude
	leadParams.RespectCanCollide = true
	-- ставит стрелку рядом с игроком: она висит в стороне цели, не дальше 10 шагов, и не уходит в стену
	local function place(player: Player)
		local spot, aim = spots[player], aims[player]
		if not spot or not aim or spot.Parent == nil then
			return
		end
		local position = aim
		local root = ctx.getAlive(player)
		if root then
			local offset = aim - root.Position
			local level = Vector3.new(offset.X, 0, offset.Z)
			local far = if root.Position.Y > ctx.LOBBY_Y - 5 then 5 else 10
			if level.Magnitude > far then
				local lead = far
				local character = player.Character
				leadParams.FilterDescendantsInstances = if character then { character } else {}
				local hit = workspace:Raycast(root.Position, level.Unit * far, leadParams)
				if hit then
					lead = math.max(3, hit.Distance - 1.5)
				end
				position = root.Position + level.Unit * lead + Vector3.new(0, math.clamp(offset.Y, -3, 6), 0)
			end
		end
		spot.Position = position
	end
	local function guide(player: Player, position: Vector3?, icon: string?)
		local gui = player:FindFirstChild("PlayerGui")
		if not gui then
			return
		end
		local found = gui:FindFirstChild("ZT_Guide")
		local arrow: BillboardGui? = if found and found:IsA("BillboardGui") then found else nil
		if not position then
			aims[player] = nil
			if arrow then
				arrow.Enabled = false
			end
			return
		end
		local old = spots[player]
		local spot: Part
		if old and old.Parent ~= nil then
			spot = old
		else
			spot = Instance.new("Part")
			spot.Name = "ZT_GuideSpot"
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanQuery = false
			spot.CanTouch = false
			spot.Transparency = 1
			spot.Size = Vector3.new(1, 1, 1)
			spot.Parent = workspace
			spots[player] = spot
		end
		aims[player] = position
		place(player)
		if not arrow then
			local created = Instance.new("BillboardGui")
			created.Name = "ZT_Guide"
			-- стрелка висит в воздухе рядом с игроком и светится сама (её видно и в темноте)
			created.AlwaysOnTop = false
			created.LightInfluence = 0
			created.ResetOnSpawn = false
			created.Size = UDim2.fromOffset(48, 88)
			created.StudsOffset = Vector3.new(0, 3.4, 0)
			created.MaxDistance = 1500
			-- над стрелкой - картинка того, к чему она ведёт (укрытие, монета, вертолёт, магазин)
			local picture = Instance.new("TextLabel")
			picture.Name = "Icon"
			picture.Size = UDim2.fromScale(1, 0.48)
			picture.BackgroundTransparency = 1
			picture.Text = ""
			picture.TextScaled = true
			picture.Font = Enum.Font.GothamBold
			picture.Parent = created
			local label = Instance.new("TextLabel")
			label.Name = "Arrow"
			label.Size = UDim2.fromScale(1, 0.52)
			label.Position = UDim2.fromScale(0, 0.48)
			label.BackgroundTransparency = 1
			label.Text = "▼"
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromRGB(255, 225, 60)
			label.TextStrokeTransparency = 0
			label.Parent = created
			created.Parent = gui
			arrow = created
		end
		if arrow then
			arrow.Adornee = spot
			arrow.Enabled = true
			local picture = arrow:FindFirstChild("Icon")
			if picture and picture:IsA("TextLabel") and picture.Text ~= (icon or "") then
				picture.Text = icon or ""
			end
		end
	end
	-- стрелка плавно идёт рядом с бегущим игроком
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in pairs(aims) do
				safely("arrow", function()
					place(player)
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local spot = spots[player]
		if spot then
			spot:Destroy()
		end
	end)

	-- ближайшая точка из списка: не дальше limit и примерно на той же высоте, что игрок
	local function nearest(list: { Vector3 }, from: Vector3, limit: number): Vector3?
		local best: Vector3? = nil
		local bestDistance = limit
		for _, point in ipairs(list) do
			local distance = flat(point, from)
			if distance < bestDistance and math.abs(point.Y - from.Y) < 7 then
				best = point
				bestDistance = distance
			end
		end
		return best
	end
	-- есть ли рядом зомби (игрок или бот)
	local function zombieNear(from: Vector3, limit: number): boolean
		for other in pairs(inRound) do
			local root = ctx.getAlive(other)
			if root and isZombie[other] and (root.Position - from).Magnitude < limit then
				return true
			end
		end
		for _, bot in ipairs(ctx.bots) do
			if bot.zombie and ctx.botPresent(bot) and (bot.root.Position - from).Magnitude < limit then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------------
	-- ФИНАЛЬНАЯ ОХОТА: зомби-игрок раз в несколько секунд видит ближайших выживших сквозь стены
	---------------------------------------------------------------------
	local PINGS = 4
	local function ping(player: Player, from: Vector3?)
		local gui = player:FindFirstChild("PlayerGui")
		if not gui then
			return
		end
		local list: { { any } } = {}
		if from then
			for other in pairs(inRound) do
				local root = ctx.getAlive(other)
				if root and not isZombie[other] and other.Character then
					table.insert(list, { (root.Position - from).Magnitude, other.Character })
				end
			end
			for _, bot in ipairs(ctx.bots) do
				if not bot.zombie and ctx.botPresent(bot) then
					-- сначала показываются выжившие игроки, потом жители-боты
					table.insert(list, { 100000 + (bot.root.Position - from).Magnitude, bot.model })
				end
			end
			table.sort(list, function(a: { any }, b: { any }): boolean
				return a[1] < b[1]
			end)
		end
		for index = 1, PINGS do
			local name = "ZT_Ping" .. index
			local found = gui:FindFirstChild(name)
			local item = list[index]
			if found and found:IsA("Highlight") then
				found.Adornee = if item then item[2] else nil
				found.Enabled = item ~= nil
			elseif item then
				local mark = Instance.new("Highlight")
				mark.Name = name
				mark.FillColor = Color3.fromRGB(255, 70, 70)
				mark.FillTransparency = 0.35
				mark.OutlineColor = Color3.fromRGB(255, 255, 255)
				mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				mark.Adornee = item[2]
				mark.Parent = gui
			end
		end
	end

	---------------------------------------------------------------------
	-- ПЕРВАЯ МИНУТА И ПОВОДЫ ВЕРНУТЬСЯ
	-- Подарок новичку после первого раунда, призы за дни подряд, задания и серия дней на экране,
	-- режим недели и товар недели, отметки шагов новичка для статистики Roblox.
	---------------------------------------------------------------------
	local shopOff: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- кого стрелка в магазин уже не зовёт
	local Grow = {}
	do
		local SHOP_SPOT = Vector3.new(-30, ctx.LOBBY_Y + 4, -18) -- место перед витринами с дешёвыми следами
		local SHOP_LOOK = Vector3.new(-35, ctx.LOBBY_Y + 4, -42)
		local DEAL = 30        -- скидка на товар недели, в процентах
		local WEEK_BONUS = 50  -- прибавка монет в раундах режима недели, в процентах (сам множитель - в главном скрипте)
		-- события, которые бывают режимом недели (туман и темнота на целую неделю - слишком тяжело на телефоне)
		local WEEK_EVENTS = { "gold", "rage", "giant", "moon" }
		-- картинки заданий: их понимает и тот, кто ещё не читает
		local QUEST_ICON: { [string]: string } = {
			catch = "🧟", survive = "🏃", coins = "💰", heli = "🚁", play = "🎮", hide = "🌳", shield = "🛡",
		}
		-- шаги новичка. Roblox показывает, сколько игроков дошло до каждого шага и где они уходят.
		local STEPS = {
			"Joined", "Round started", "Moved in round", "1 minute in game",
			"First round finished", "Second round started", "Second round finished", "Third round finished",
		}
		local analytics: any = nil
		pcall(function()
			analytics = game:GetService("AnalyticsService")
		end)
		local function log(action: (service: any) -> ())
			if analytics then
				pcall(action, analytics)
			end
		end

		local items: { any } = ctx.items or {}
		local prizes: { any } = {}             -- подарки за дни подряд, от ближнего к дальнему
		local prizeIds: { [string]: boolean } = {}
		local basePrice: { [any]: number } = {} -- обычные цены (без скидки недели)
		local cheapest = math.huge             -- цена самого дешёвого следа
		for _, item in ipairs(items) do
			basePrice[item] = item.price
			if item.days then
				table.insert(prizes, item)
				prizeIds[item.id] = true
			elseif not item.level and item.kind == "trail" then
				cheapest = math.min(cheapest, item.price)
			end
		end
		table.sort(prizes, function(a: any, b: any): boolean
			return a.days < b.days
		end)
		-- обновить цены и кошелёк на экране игрока (внешний вид персонажа при этом не трогается)
		local function sync(player: Player)
			local action = ctx.sync or ctx.refresh
			action(player)
		end

		-- где в лобби стоят витрины
		local stands: { [string]: Vector3 } = {}
		local lobby: Instance? = nil
		do
			local map = workspace:FindFirstChild("ZombieTagMap")
			lobby = if map then map:FindFirstChild("Lobby") else nil
			if lobby then
				for _, part in ipairs(lobby:GetChildren()) do
					local prompt = if part.Name == "ShopStand" then part:FindFirstChildOfClass("ProximityPrompt") else nil
					if prompt and part:IsA("BasePart") and string.sub(prompt.Name, 1, 4) == "Buy_" then
						stands[string.sub(prompt.Name, 5)] = part.Position
					end
				end
			end
		end
		local function write(label: TextLabel, text: string)
			if label.Text ~= text then
				label.Text = text
			end
		end

		-- купил ли игрок хоть что-нибудь (подарки не в счёт)
		local function bought(profile: any): boolean
			for id in pairs(profile.owned) do
				if not prizeIds[id] then
					return true
				end
			end
			return false
		end
		-- ближайший подарок, которого у игрока ещё нет
		local function nextPrize(profile: any): any
			for _, item in ipairs(prizes) do
				if not profile.owned[item.id] then
					return item
				end
			end
			return nil
		end
		-- сколько монет игрок получит, если зайдёт завтра
		local function tomorrow(session: any): number
			return (ctx.dailyBase or 0) * math.min(session.profile.streak + 1, 7) * (if session.vip then 2 else 1)
		end
		-- новый ли это игрок: ни одного доигранного раунда и подарок новичку не получал. (Победа или пара
		-- пойманных без раунда бывает у того, кто вышел на экране итогов; у старых игроков их намного больше.)
		local function fresh(profile: any): boolean
			return profile.rounds == 0 and profile.wins + profile.infections < 5 and not profile.badges.gifted
		end
		-- двоеточие в строках, которые собирает код: во французском перед ним ставится неразрывный пробел
		local function colon(session: any): string
			return if session.lang == "fr" then "\194\160: " else ": "
		end

		---------------------------------------------------------------------
		-- РЕЖИМ НЕДЕЛИ И ТОВАР НЕДЕЛИ: меняются сами каждый понедельник (по мировому времени)
		---------------------------------------------------------------------
		local dealItem: any = nil
		local function setWeek()
			local week = (os.time() // 86400 + 3) // 7
			local events: { string } = ctx.events or {}
			local modes: { string } = {}
			for _, name in ipairs(WEEK_EVENTS) do
				if table.find(events, name) then
					table.insert(modes, name)
				end
			end
			-- если события раундов выключены в настройках, режима недели тоже нет
			RULES.week = if RULES.weekly and ctx.eventsOn ~= false and #modes > 0 then modes[week % #modes + 1] else ""
			-- со скидкой бывают только товары средней цены, которые продаются без условий
			local pool: { any } = {}
			for _, item in ipairs(items) do
				if not item.level and not item.days and basePrice[item] >= 200 then
					table.insert(pool, item)
				end
			end
			local chosen: any = if RULES.weekly and #pool > 0 then pool[(week * 7) % #pool + 1] else nil
			if chosen ~= dealItem then
				if dealItem then
					dealItem.price = basePrice[dealItem]
					dealItem.note = nil
				end
				dealItem = chosen
				if chosen then
					-- цена округляется вниз до десятка: скидка получается не меньше обещанной
					chosen.price = math.floor(basePrice[chosen] * (100 - DEAL) / 1000) * 10
					chosen.note = "  ⭐-" .. DEAL .. "%"
				end
				for _, player in ipairs(Players:GetPlayers()) do
					if sessions[player] then
						sync(player)
					end
				end
			end
		end
		safely("week", setWeek)
		task.spawn(function()
			while true do
				task.wait(60)
				safely("week", setWeek)
			end
		end)

		---------------------------------------------------------------------
		-- НОВИЧОК В ЛОББИ: кто уже бегает (игра у него загрузилась), того раунд забирает быстрее
		---------------------------------------------------------------------
		local grown: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any -- что известно про эту игровую сессию
		-- all = true: вопрос только "все ли на сервере новички" (тогда первый раунд короткий: первая победа,
		-- подарок и покупка приходят раньше); иначе ещё и "все ли уже бегают по лобби" (тогда пауза короче)
		ctx.Guard.eager = function(all: boolean?): boolean
			-- вопрос задаёт главный цикл игры: ошибка здесь не должна его останавливать
			local ok, result = pcall(function(): boolean
				if not RULES.eager then
					return false
				end
				local count = 0
				for _, session in pairs(sessions) do
					local state = grown[session]
					-- (короткий раунд - только тому, кто ещё не получал подарок новичка: выход сразу после вертолёта его не повторит)
					if session.profile.rounds > 0 or not state or (all and not state.fresh) or (not all and state.lobbyWalk < 8) then
						return false
					end
					count += 1
				end
				return count > 0
			end)
			return ok and result == true
		end

		-- витрина, к которой стрелка ведёт новичка за первой покупкой (nil - стрелка не нужна)
		function Grow.shopSpot(session: any, from: Vector3): Vector3?
			local profile = session.profile
			local state = grown[session]
			if not RULES.gifts or profile.rounds > 3 or profile.coins < cheapest or bought(profile)
				or not (profile.rounds >= 1 or (state and state.gifted)) then
				return nil
			end
			local best: Vector3? = nil
			local bestDistance = math.huge
			for _, item in ipairs(items) do
				local place = stands[item.id]
				if place and item.kind == "trail" and not item.days and not item.level and item.price <= profile.coins then
					local distance = flat(place, from)
					if distance < bestDistance then
						best = place
						bestDistance = distance
					end
				end
			end
			if not best then
				return nil
			end
			-- стрелка встаёт перед самой витриной, со стороны середины лобби: там уже видна кнопка покупки
			local toCentre = Vector3.new(-best.X, 0, -best.Z)
			return best + (if toCentre.Magnitude > 1 then toCentre.Unit * 2.5 else Vector3.new(0, 0, 0))
		end

		-- строка внизу экрана: серия дней, ближайший подарок и задания дня
		local function tracker(player: Player, session: any, hud: any)
			local gui: Instance = hud.gui
			local found = gui:FindFirstChild("Track")
			local label: TextLabel
			if found and found:IsA("TextLabel") then
				label = found
			else
				label = Instance.new("TextLabel")
				label.Name = "Track"
				-- внизу посередине: там нет ни чата, ни списка игроков, ни кнопок телефона
				label.AnchorPoint = Vector2.new(0.5, 1)
				label.Position = UDim2.fromScale(0.5, 0.985)
				label.Size = UDim2.fromScale(0.6, 0.065)
				label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				label.BackgroundTransparency = 0.4
				label.BorderSizePixel = 0
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextStrokeTransparency = 0.2
				label.TextScaled = true
				label.RichText = true
				label.Font = Enum.Font.GothamBold
				label.Text = ""
				local limit = Instance.new("UITextSizeConstraint")
				limit.MaxTextSize = 24
				limit.MinTextSize = 13
				limit.Parent = label
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 10)
				corner.Parent = label
				-- на компьютере строка не растягивается на пол-экрана
				local box = Instance.new("UISizeConstraint")
				box.MaxSize = Vector2.new(560, 36)
				box.Parent = label
				label.Parent = gui
			end
			local profile = session.profile
			local goal = nextPrize(profile)
			local parts = {
				"🔥 " .. profile.streak .. (if goal then "/" .. goal.days .. " 🎁" else "") .. (if session.friendBoost then "  👥" else ""),
			}
			if ctx.quests then
				for _, quest in ipairs(ctx.quests(player)) do
					local icon = QUEST_ICON[quest.id] or "•"
					if profile.questDone[quest.id] then
						table.insert(parts, '<font color="#8CFF8C">' .. icon .. " ✅</font>")
					else
						table.insert(parts, icon .. " " .. math.min(profile.questProgress[quest.id] or 0, quest.goal) .. "/" .. quest.goal)
					end
				end
			end
			write(label, table.concat(parts, "     "))
		end

		-- В лобби строка подсказки по очереди показывает: серию дней и что будет завтра, ближайший подарок,
		-- товар недели. Новичку, который ждёт первого раунда дольше 8 секунд, она по очереди показывает три
		-- главные подсказки игры: так он узнаёт, что его ждёт, пока идёт чужой раунд.
		function Grow.lobbyLine(player: Player, session: any, now: number): string
			local profile = session.profile
			if not RULES.gifts then
				return ""
			end
			if profile.rounds < 1 then
				local state = grown[session]
				if state and state.fresh and not state.gifted and state.done == 0 and now - state.joined > 8 then
					local tips = { "hint_run", "hint_hide", "hint_coin" }
					return ctx.tr(player, tips[math.floor(now / 5) % #tips + 1])
				end
				return ""
			end
			local lines = { ctx.tr(player, "streak_day", profile.streak) .. "  ·  " .. ctx.tr(player, "tomorrow", tomorrow(session)) }
			local goal = nextPrize(profile)
			if goal then
				table.insert(lines, "🎁 " .. ctx.itemName(player, goal) .. colon(session) .. ctx.tr(player, "prize_days", math.min(profile.streak, goal.days), goal.days))
			end
			if dealItem and not profile.owned[dealItem.id] then
				table.insert(lines, "⭐ " .. ctx.tr(player, "week_deal", ctx.itemName(player, dealItem), DEAL))
			end
			return lines[math.floor(now / 5) % #lines + 1]
		end

		-- у следа-подарка есть искры: такого следа нет ни у кого, кроме тех, кто играл неделю подряд
		local sparkId = ""
		for _, item in ipairs(prizes) do
			if item.kind == "trail" and sparkId == "" then
				sparkId = item.id
			end
		end
		local function spark(root: BasePart, on: boolean)
			local old = root:FindFirstChild("ZT_Spark")
			if on and not old then
				local emitter = Instance.new("ParticleEmitter")
				emitter.Name = "ZT_Spark"
				emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				emitter.Rate = 14
				emitter.Lifetime = NumberRange.new(0.5, 0.9)
				emitter.Speed = NumberRange.new(1, 3)
				emitter.SpreadAngle = Vector2.new(180, 180)
				emitter.Size = NumberSequence.new(0.5, 0)
				emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 60))
				emitter.LightEmission = 1
				emitter.Parent = root
			elseif old and not on then
				old:Destroy()
			end
		end

		-- раз в секунду для каждого игрока
		function Grow.tick(player: Player, now: number, roundActive: boolean, roundId: number)
			local session = sessions[player]
			local hud = huds[player]
			if not session or not hud then
				return
			end
			local profile = session.profile
			-- прогресс настоящий, а не временный после сбоя загрузки
			local trusted = session.canSave or not ctx.saveBroken()
			local state = grown[session]
			if not state then
				local newcomer = trusted and fresh(profile)
				state = {
					profile = profile, step = 0, funnel = newcomer, fresh = newcomer, gifted = false, joined = now,
					walked = 0, lobbyWalk = 0, last = nil, rounds = profile.rounds, done = 0, inGame = 0, told = false,
					bought = bought(profile), questDay = profile.questDay,
				}
				grown[session] = state
			elseif state.profile ~= profile then
				-- Прогресс подменили настоящим (он загрузился позже). Если в настоящем ничего не было (к временному
				-- ничего не прибавилось), это новичок: подарок он получит. В статистику шагов он уже не попадает.
				local temp = state.profile
				state.fresh = trusted and not profile.badges.gifted and profile.rounds == temp.rounds
					and profile.wins == temp.wins and profile.infections == temp.infections
				state.profile = profile
				state.funnel = false
				state.rounds = profile.rounds
				state.bought = bought(profile)
			end
			local root = ctx.getAlive(player)
			local playing = roundActive and inRound[player] == true
			local saved = roundActive and ctx.evac.saved[player] == true -- улетел на вертолёте и ждёт конца раунда в лобби
			-- улетел на вертолёте и уже 2 секунды в лобби: подарок не ждёт, пока раунд досчитают
			if ctx.evac.saved[player] ~= true then
				state.flew = nil
			elseif not state.flew then
				state.flew = now
			end
			local escaped = state.flew ~= nil and now - state.flew >= 2
			-- после каждого из первых раундов стрелка в магазин зовёт снова
			if profile.rounds ~= state.seenRounds then
				state.seenRounds = profile.rounds
				shopOff[player] = nil
			end

			-- сколько игрок прошёл сам (когда его переносит сервер, это не считается)
			local last: Vector3? = state.last
			if root and last then
				local step = flat(root.Position, last)
				if step < 40 and math.abs(root.Position.Y - last.Y) < 30 then
					if playing then
						state.walked += step
					else
						state.lobbyWalk += step
					end
				end
			end
			state.last = if root then root.Position else nil
			-- раунд, в котором игрок участвовал, закончился
			if playing or saved then
				state.inGame = roundId
			elseif state.inGame ~= 0 and (not roundActive or roundId ~= state.inGame) then
				state.inGame = 0
				state.done += 1
			end

			-- шаги новичка: каждый шаг отмечается один раз и строго по порядку
			if state.funnel then
				local rounds = math.max(profile.rounds, state.done)
				while state.step < #STEPS do
					local nextStep = state.step + 1
					local reached = nextStep == 1
						or (nextStep == 2 and playing)
						or (nextStep == 3 and state.walked >= 30)
						or (nextStep == 4 and now - state.joined >= 60)
						or (nextStep == 5 and rounds >= 1)
						or (nextStep == 6 and rounds >= 1 and playing)
						or (nextStep == 7 and rounds >= 2)
						or (nextStep == 8 and rounds >= 3)
					if not reached then
						break
					end
					state.step = nextStep
					log(function(service: any)
						service:LogOnboardingFunnelStepEvent(player, nextStep, STEPS[nextStep])
					end)
				end
			end
			if not state.bought and bought(profile) then
				state.bought = true
				log(function(service: any)
					service:LogCustomEvent(player, "FirstItem")
				end)
			end

			if RULES.gifts then
				-- подарок новичку после первого раунда (или сразу после вертолёта): монет хватит на первый след
				if state.fresh and not state.gifted and (profile.rounds >= 1 or escaped) and cheapest < math.huge then
					state.gifted = true
					profile.badges.gifted = true -- отметка в прогрессе: подарок выдаётся один раз в жизни
					local gift = math.max(50, cheapest - profile.coins)
					profile.coins += gift
					sync(player)
					ctx.big(player, "gift_first", gift)
					ctx.sound(player, "win")
					-- кто вернулся не к витринам (улетел на вертолёте), того ставим перед витринами со следами
					local character = player.Character
					if root and character and not playing and root.Position.Y > ctx.LOBBY_Y - 5
						and flat(root.Position, SHOP_SPOT) > 30 and not ctx.inShopZone(root.Position) and not bought(profile) then
						ctx.Guard.allow(player, SHOP_SPOT)
						character:PivotTo(CFrame.lookAt(SHOP_SPOT, SHOP_LOOK))
					end
					-- подарок сохраняется скоро, а не через три минуты (12 секунд: не рядом с сохранением в конце раунда)
					task.delay(12, function()
						if sessions[player] == session and not session.leaving then
							ctx.saveProfile(player)
						end
					end)
				end
				-- что будет завтра: один раз за заход, после раунда (новичку - после второго: после первого он идёт в магазин)
				if not state.told and profile.rounds > state.rounds and profile.rounds >= 2 then
					state.told = true
					task.delay(6, function()
						if sessions[player] == session then
							ctx.toast(player, "tomorrow", tomorrow(session))
						end
					end)
				end
				-- призы за дни подряд
				for _, item in ipairs(prizes) do
					if trusted and profile.streak >= item.days and not profile.owned[item.id] then
						profile.owned[item.id] = true
						sync(player)
						-- Надпись появляется чуть позже (в первые секунды игра у игрока ещё загружается), и в этот же
						-- момент приз надевается: игрок видит, что получил. Прежний след остаётся у него, вернуть можно у витрины.
						task.delay(RULES.noteDelay, function()
							if sessions[player] == session and session.profile == profile then
								if item.kind == "trail" then
									profile.trail = item.id
								else
									profile.skin = item.id
								end
								ctx.refresh(player)
								ctx.big(player, "prize_got", item.days, ctx.itemName(player, item))
								ctx.sound(player, "win")
							end
						end)
						log(function(service: any)
							service:LogCustomEvent(player, "Prize" .. item.days)
						end)
					end
				end
			end

			-- в полночь по мировому времени задания меняются: доска заданий в лобби обновляется вместе со строкой на экране
			tracker(player, session, hud)
			if profile.questDay ~= state.questDay then
				state.questDay = profile.questDay
				if ctx.questBoard then
					ctx.questBoard(player)
				end
			end
			-- В лобби жёлтая строка события напоминает про режим недели (в раунде её пишет главный скрипт).
			-- Новичку после первого раунда она не показывается: в этот момент ему важнее подарок и магазин.
			local event: TextLabel = hud.event
			if not playing and RULES.week ~= "" and profile.rounds >= 2 then
				-- от текста события остаётся только название (до восклицательного знака): строка короткая и на телефоне
				local mode: string = ctx.tr(player, "ev_" .. RULES.week)
				local cut = string.find(mode, "!", 1, true) or select(2, string.find(mode, "！", 1, true))
				write(event, ctx.tr(player, "week_mode") .. colon(session) .. (if cut then string.sub(mode, 1, cut) else mode) .. "  +" .. WEEK_BONUS .. "% 💰")
			end
			-- в лобби под строкой есть тёмная подложка: за ней видны подписи витрин, и без подложки её не прочитать
			local plate = if not playing and event.Text ~= "" then 0.4 else 1
			if event.BackgroundTransparency ~= plate then
				event.BackgroundTransparency = plate
			end
			if root then
				-- у выжившего в раунде искр нет: иначе они выдали бы того, кто спрятался
				spark(root, sparkId ~= "" and profile.trail == sparkId and not (playing and not isZombie[player]))
			end
		end
	end

	---------------------------------------------------------------------
	-- СТРОКА ПОДСКАЗКИ: что сейчас делать. Новичок получает подсказки первые три раунда.
	---------------------------------------------------------------------
	local seenRound = 0
	local roundStart = 0
	local growTurn = false
	local pingAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local zoneSince: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local runUntil: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local function advise(player: Player, now: number, roundActive: boolean, finalHunt: boolean)
		local session = sessions[player]
		local hud = huds[player]
		if not session or not hud then
			return
		end
		if session.canSave then
			loaded[session] = true
		end
		local elapsed = now - roundStart
		local key = ""
		local text = ""
		local target: Vector3? = nil
		local icon = ""
		local reach = 7
		local root = ctx.getAlive(player)
		local playing = roundActive and inRound[player] == true
		local wantPing = false
		local inZone = false
		local shop: Vector3? = if not playing and root and root.Position.Y > ctx.LOBBY_Y - 30 then Grow.shopSpot(session, root.Position) else nil
		if playing and root then
			local newbie = session.profile.rounds < 3
			local heli: Vector3? = ctx.evac.spot
			if isZombie[player] then
				if finalHunt then
					wantPing = true
					key = "hunt_ping"
				elseif heli then
					key = "hint_heli_zombie"
					if newbie then
						target = heli
						icon = "🚁"
					end
				elseif newbie then
					key = "hint_zombie"
				end
			elseif heli then
				-- вертолёт часто садится на крышу: стрелка показывает, куда бежать и лезть
				key = if heli.Y - root.Position.Y > 8 then "hint_heli_up" else "hint_heli"
				target = heli
				icon = "🚁"
				if heli.Y - root.Position.Y > 8 then
					-- площадка наверху: стрелка ведёт к лестнице, по которой туда залезть
					local bestDistance = math.huge
					for _, ladder in ipairs(ctx.ladders) do
						local foot: Vector3 = ladder.bottom
						if math.abs(ladder.top.Y - heli.Y) < 8 and flat(ladder.top, heli) < 35 and math.abs(foot.Y - root.Position.Y) < 8 then
							local distance = flat(foot, root.Position)
							if distance < bestDistance then
								bestDistance = distance
								-- у самой лестницы стрелка показывает уже наверх
								target = if distance < 7 then ladder.top + Vector3.new(0, 2, 0) else foot + Vector3.new(0, 2, 0)
							end
						end
					end
				end
			elseif newbie then
				if zombieNear(root.Position, 25) then
					runUntil[player] = now + 3 -- подсказка не мигает, когда зомби то ближе, то дальше
				end
				if elapsed < 9 or now < (runUntil[player] or 0) then
					key = "hint_run"
				elseif (elapsed >= 26 and elapsed < 44) or (elapsed >= 72 and (elapsed - 72) % 26 < 14) then
					key = "hint_coin"
					icon = "💰"
					local coins: { Vector3 } = {}
					for _, pickup in ipairs(ctx.pickups) do
						if pickup.kind == "coin" then
							table.insert(coins, pickup.part.Position)
						end
					end
					target = nearest(coins, root.Position, 200)
				elseif elapsed >= 44 and elapsed < 60 then
					key = "hint_climb"
				else
					key = "hint_hide"
					icon = "🌳"
					if elapsed < 26 then
						target = nearest(ctx.hideSpots, root.Position, 150)
					end
				end
			end
		elseif not playing and not session.canSave and ctx.saveBroken() then
			key = "no_save"
		elseif not playing and root then
			local since = zoneSince[player] or now
			if session.profile.rounds > 0 and ctx.inShopZone(root.Position) then
				inZone = true
				zoneSince[player] = since
			end
			-- Новичка с подарком стрелка ведёт к витрине за первой покупкой. Но если он стоит на синем полу
			-- и не покупает, а раунд идёт без него (или прошло 20 секунд), важнее сказать, как вернуться в игру.
			if shop and inZone and now - since > 20 then
				shopOff[player] = true -- постоял у витрин и не купил: в этот заход стрелка в магазин больше не зовёт
			end
			if shop and not shopOff[player] and not (inZone and roundActive) then
				key = "hint_shop"
				icon = "🛒"
				target = shop
				reach = 5
			elseif inZone then
				-- игрок стоит в зоне магазина: напоминаем, почему его не берут в раунд
				key = "skipped"
				-- кто стоит там давно, тому стрелка показывает, куда выйти
				if shop or now - since > (if session.profile.rounds <= 3 then 8 else 45) then
					target = Vector3.new(0, ctx.LOBBY_Y + 2, 12)
				end
			else
				-- в лобби: серия дней, что будет завтра, подарок, товар недели
				text = Grow.lobbyLine(player, session, now)
			end
		end
		if not inZone then
			zoneSince[player] = nil
		end
		-- стрелка не нужна, когда игрок уже дошёл
		if target and root and (target - root.Position).Magnitude < reach then
			target = nil
		end
		if key ~= "" then
			text = ctx.tr(player, key, ctx.board)
		end
		if hud.hint.Text ~= text then
			hud.hint.Text = text
			hud.hint.BackgroundTransparency = if text == "" then 1 else 0.4
		end
		guide(player, target, icon)
		if wantPing and root then
			if now >= (pingAt[player] or 0) then
				pingAt[player] = now + 4
				ping(player, root.Position)
				task.delay(2, function()
					ping(player, nil)
				end)
			end
		elseif pingAt[player] then
			pingAt[player] = nil
			ping(player, nil)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			local roundActive, finalHunt, roundId, roundEvent = ctx.state()
			-- для скрипта графики (Looks): какое событие идёт в раунде и началась ли финальная охота
			if workspace:GetAttribute("ZT_Event") ~= roundEvent then
				workspace:SetAttribute("ZT_Event", roundEvent)
			end
			if workspace:GetAttribute("ZT_Final") ~= finalHunt then
				workspace:SetAttribute("ZT_Final", finalHunt)
			end
			local now = os.clock()
			if roundActive and roundId ~= seenRound then
				seenRound = roundId
				roundStart = now
			end
			growTurn = not growTurn
			for _, player in ipairs(Players:GetPlayers()) do
				-- сначала подарки и счётчики, потом подсказка: она сразу учитывает только что выданный подарок
				if growTurn then
					safely("growth", function()
						Grow.tick(player, now, roundActive, roundId)
					end)
				end
				safely("hints", function()
					advise(player, now, roundActive, finalHunt)
				end)
			end
		end
	end)

	---------------------------------------------------------------------
	-- ТАБЛИЦА ЛИДЕРОВ В ЛОББИ: общая (по победам) обновляется раз в две минуты
	---------------------------------------------------------------------
	task.spawn(function()
		local names: { [string]: string } = {}
		local globalLines: { string }? = nil
		local nextGlobal = 0
		while true do
			local board = ctx.topStore
			if board and os.clock() >= nextGlobal then
				local fresh: { string } = {}
				local ok = pcall(function()
					local page = board:GetSortedAsync(false, 10):GetCurrentPage()
					for rank, entry in ipairs(page) do
						local key = tostring(entry.key)
						if not names[key] then
							local found, name = pcall(function(): string
								return Players:GetNameFromUserIdAsync(tonumber(key) or 0)
							end)
							names[key] = if found then name else "?"
						end
						table.insert(fresh, rank .. ". " .. names[key] .. "  -  " .. tostring(entry.value))
					end
				end)
				globalLines = if ok and #fresh > 0 then fresh else nil
				-- если общая таблица недоступна (например, в Studio), пробуем снова не скоро
				nextGlobal = os.clock() + (if ok then 120 else 600)
			end
			local lines = { "TOP 10" }
			local shown = globalLines
			if shown then
				for _, line in ipairs(shown) do
					table.insert(lines, line)
				end
			else
				-- общей таблицы пока нет: показываем игроков этого сервера
				local list = Players:GetPlayers()
				table.sort(list, function(a: Player, b: Player): boolean
					local first, second = sessions[a], sessions[b]
					return (if first then first.profile.wins else 0) > (if second then second.profile.wins else 0)
				end)
				for _, player in ipairs(list) do
					local session = sessions[player]
					if #lines <= 10 and session then
						table.insert(lines, #lines .. ". " .. player.Name .. "  -  " .. session.profile.wins)
					end
				end
			end
			for rank = #lines, 10 do
				table.insert(lines, rank .. ". ...") -- пустые места: надпись остаётся ровной
			end
			for _, label in ipairs(ctx.topLabels) do
				label.Text = table.concat(lines, "\n")
			end
			task.wait(20)
		end
	end)

	---------------------------------------------------------------------
	-- КАСАНИЕ ЗОМБИ-ИГРОКА. Сервер видит всех с задержкой связи: на экране зомби уже догнал
	-- выжившего, а на сервере между ними ещё несколько шагов, и заражение не срабатывает.
	-- Поэтому экран зомби сам сообщает о касании (скрипт ZT_Touch у игрока), а сервер проверяет:
	-- зомби в раунде и не оглушён, цель рядом (с запасом на задержку связи) и не за стеной.
	---------------------------------------------------------------------
	local TOUCH_REACH = 9 -- насколько далеко может быть цель на сервере, когда зомби коснулся её у себя на экране...
	local TOUCH_LAG = 17.5 -- ...и сколько шагов добавляется за каждую секунду задержки связи зомби сверх 0.15 с (до 0.5 с)
	if ctx.catch and ctx.botCatch and ctx.wall then safely("touch_start", function()
		local remote = Instance.new("RemoteEvent")
		remote.Name = "ZT_Touch"
		remote.Parent = game:GetService("ReplicatedStorage")
		local lastTouch: { [Player]: number } = {}
		Players.PlayerRemoving:Connect(function(player: Player)
			lastTouch[player] = nil
		end)
		remote.OnServerEvent:Connect(function(player: Player, target: any)
			safely("touch", function()
				local now = os.clock()
				if now - (lastTouch[player] or 0) < 0.12 then
					return
				end
				lastTouch[player] = now
				local roundActive = ctx.state()
				local session = sessions[player]
				if not roundActive or not inRound[player] or not isZombie[player] or not session
					or now < session.stunUntil or not ctx.Guard.ok(player) then
					return
				end
				local root, humanoid = ctx.getAlive(player)
				-- стоящий зомби (начало раунда, оглушение щитом или вакциной) никого не ловит
				if not root or not humanoid or humanoid.WalkSpeed <= 0 or typeof(target) ~= "Instance" then
					return
				end
				local from: Vector3 = root.Position
				local ok, ping = pcall(function(): number
					return player:GetNetworkPing()
				end)
				local lag = if ok and type(ping) == "number" then math.clamp(ping - 0.15, 0, 0.5) else 0
				local reach = (TOUCH_REACH + TOUCH_LAG * lag) * (if session.giant then 1.3 else 1)
				if target:IsA("Player") then
					if target == player or not inRound[target] or isZombie[target] then
						return
					end
					local other = ctx.getAlive(target)
					if other and (other.Position - from).Magnitude <= reach and not ctx.wall(from, other.Position) then
						ctx.catch(target, player, nil)
					end
				elseif target:IsA("Model") then
					for _, bot in ipairs(ctx.bots) do
						if bot.model == target then
							if not bot.zombie and ctx.botPresent(bot) and (bot.root.Position - from).Magnitude <= reach
								and not ctx.wall(from, bot.root.Position) then
								ctx.botCatch(bot, player)
							end
							break
						end
					end
				end
			end)
		end)
		-- отметки на игроках: экран зомби знает, кто сейчас выживший в раунде (ZT_S), а кто зомби (ZT_Z)
		local LOBBY_POINT = Vector3.new(0, ctx.LOBBY_Y + 4, 20)
		local wasActive = false
		local heliSeen = false
		-- лобби висит в воздухе: перед переносом туда телефон заранее загружает его, иначе игрок может провалиться
		local function preload(list: { Player })
			for _, other in ipairs(list) do
				task.spawn(function()
					pcall(function()
						other:RequestStreamAroundAsync(LOBBY_POINT, 5)
					end)
				end)
			end
		end
		task.spawn(function()
			while true do
				task.wait(0.2)
				safely("touch_marks", function()
					local roundActive = ctx.state()
					-- конец раунда: через несколько секунд все из города переносятся в лобби
					if wasActive and not roundActive then
						local list = {}
						for _, other in ipairs(Players:GetPlayers()) do
							local root = ctx.getAlive(other)
							if root and root.Position.Y < ctx.LOBBY_Y - 30 and math.abs(root.Position.Z) < ctx.cityHalf + 10 then
								table.insert(list, other)
							end
						end
						preload(list)
					end
					wasActive = roundActive
					-- сел вертолёт: выжившие скоро улетят в лобби
					local heli = roundActive and ctx.evac.spot ~= nil
					if heli and not heliSeen then
						local list = {}
						for other in pairs(inRound) do
							if not isZombie[other] then
								table.insert(list, other)
							end
						end
						preload(list)
					end
					heliSeen = heli
					for _, other in ipairs(Players:GetPlayers()) do
						local playing = roundActive and inRound[other] == true
						local zombie = playing and isZombie[other] == true
						local survivor = playing and not zombie
						if other:GetAttribute("ZT_Z") ~= zombie then
							other:SetAttribute("ZT_Z", zombie)
						end
						if other:GetAttribute("ZT_S") ~= survivor then
							other:SetAttribute("ZT_S", survivor)
						end
					end
				end)
			end
		end)
	end) end

	---------------------------------------------------------------------
	-- ВЫЖИВАНИЕ (добыча, рюкзак, вакцина, голод) - отдельный модуль Survival, он лежит рядом с этим.
	-- Запускается последним, когда всё, что выше, уже работает. Без него игра идёт по-старому.
	---------------------------------------------------------------------
	local home = script.Parent
	-- ВИТРИНЫ (модуль Showcase): фигурки на витринах магазина вместо шаров. Только вид; без него остаются шары.
	local show = if home then home:FindFirstChild("Showcase") else nil
	if show then
		safely("showcase", function()
			(require :: any)(show)(ctx)
		end)
	end
	local more = if home then home:FindFirstChild("Survival") else nil
	if more then
		safely("survival", function()
			(require :: any)(more)(ctx)
		end)
	end
	-- ПЕРВЫЕ МИНУТЫ НОВИЧКА (модуль Onboarding): интро, вход в идущий раунд, страх и первая награда. Без него всё как раньше.
	local first = if home then home:FindFirstChild("Onboarding") else nil
	if first then
		safely("onboarding", function()
			(require :: any)(first)(ctx)
		end)
	end
	-- УДАЧА (модуль Luck): колесо удачи и табло серии дней в лобби. Без него лобби как раньше.
	local luck = if home then home:FindFirstChild("Luck") else nil
	if luck then
		safely("luck", function()
			(require :: any)(luck)(ctx)
		end)
	end
	-- ТЫКВЕННАЯ НОЧЬ (модуль Halloween): хэллоуинский ивент до 9 ноября. Без него всё как раньше.
	local fest = if home then home:FindFirstChild("Halloween") else nil
	if fest then
		safely("halloween", function()
			(require :: any)(fest)(ctx)
		end)
	end
	-- ДРУЗЬЯ И КОДЫ (модуль Social): награда за приглашение друга и стойка кодов в лобби.
	local social = if home then home:FindFirstChild("Social") else nil
	if social then
		safely("social", function()
			(require :: any)(social)(ctx)
		end)
	end
	-- СЕЗОН 1 (модуль Season): умение (рывок / прыжок), эффекты поимки, последний выживший. Без него всё как раньше.
	local season = if home then home:FindFirstChild("Season") else nil
	if season then
		safely("season", function()
			(require :: any)(season)(ctx)
		end)
	end
	-- ОБУЧЕНИЕ (модуль Tutorial): подсказки в нужный момент и книга «Как играть». Без него всё как раньше.
	local tutorial = if home then home:FindFirstChild("Tutorial") else nil
	if tutorial then
		safely("tutorial", function()
			(require :: any)(tutorial)(ctx)
		end)
	end
	-- КОСТЮМЫ (модуль Costumes): костюмы за монеты для людей и зомби, гардероб в центре лобби. Без него всё как раньше.
	local costumes = if home then home:FindFirstChild("Costumes") else nil
	if costumes then
		safely("costumes", function()
			(require :: any)(costumes)(ctx)
		end)
	end
	-- ВЕРТОЛЁТ НЕ РЕЗИНОВЫЙ (модуль Evac): мест на одно меньше, чем выживших; жители тоже бегут к вертолёту
	local evacSeats = if home then home:FindFirstChild("Evac") else nil
	if evacSeats then
		safely("evac", function()
			(require :: any)(evacSeats)(ctx)
		end)
	end
	-- ПЕРВАЯ ПОКУПКА И ПЕРВЫЙ ДОМ (модуль Welcome): окно «выбери свой первый след» после первого раунда
	local welcome = if home then home:FindFirstChild("Welcome") else nil
	if welcome then
		safely("welcome", function()
			(require :: any)(welcome)(ctx)
		end)
	end

	return true
end
