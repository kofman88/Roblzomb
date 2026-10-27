--[[
	СТЕНА ИДЕЙ (скрипт Ideas)

	КУДА ВСТАВИТЬ: обычный Script с именем Ideas прямо в ServerScriptService (рядом с Toxic и Looks).
	Клиентская часть: StarterPlayer -> StarterPlayerScripts -> ZT_Ideas (LocalScript).

	Что здесь:
	- в лобби на стене справа (над стендами монет) висит большая "Стена идей":
	  слева - идеи игроков, которые уже есть в игре (с ником автора), справа - топ новых идей по лайкам;
	- у стены кнопка "Предложить идею": игрок пишет идею прямо в игре, остальные ставят лайки;
	- каждый текст проходит фильтр Roblox (TextService) до того, как его увидит кто-то ещё;
	- идеи хранятся в DataStore "ZT_Ideas_v1" (ключ "list"); их видно в Creator Hub -> Data Stores.
	Чтобы отметить идею как сделанную, впиши её в DONE ниже (текст и ник автора) - она переедет в левую колонку.
]]

local DONE: { { text: string, author: string } } = {
	-- { text = "Зомби-собаки", author = "Nickname" },
}
local MAX_LEN = 120          -- символов в идее
local COOLDOWN = 60          -- секунд между идеями одного игрока
local PER_DAY = 5            -- идей в день от одного игрока
local KEEP = 300             -- сколько идей хранить
local TOP = 4                -- сколько идей на стене
local STORE_NAME = "ZT_Ideas_v1"

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local function safely(what: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Zombie Tag] Ideas " .. what .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------
-- ХРАНИЛИЩЕ (в Studio без доступа к API - только в памяти сервера)
---------------------------------------------------------------------
local store: GlobalDataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
type Idea = { id: string, t: string, a: string, u: number, v: number, d: number, by: { number } }
local ideas: { Idea } = {}
local changed = Instance.new("BindableEvent")

local function merge(saved: { Idea }?, add: Idea?, vote: { id: string, user: number }?): { Idea }
	local list: { Idea } = if type(saved) == "table" then saved else {}
	if add then
		table.insert(list, add)
	end
	if vote then
		for _, idea in ipairs(list) do
			if idea.id == vote.id then
				idea.by = idea.by or {}
				if not table.find(idea.by, vote.user) and #idea.by < 2000 then
					table.insert(idea.by, vote.user)
					idea.v = #idea.by
				end
			end
		end
	end
	if #list > KEEP then
		-- выбрасываем самые старые из тех, что набрали меньше всего лайков
		table.sort(list, function(x, y)
			if x.v ~= y.v then
				return x.v > y.v
			end
			return x.d > y.d
		end)
		while #list > KEEP do
			table.remove(list)
		end
	end
	return list
end

local function write(add: Idea?, vote: { id: string, user: number }?)
	local s = store
	local done = false
	if s then
		local ok = pcall(function()
			s:UpdateAsync("list", function(saved)
				return merge(saved, add, vote)
			end)
			local fresh = s:GetAsync("list")
			if type(fresh) == "table" then
				ideas = fresh
			end
		end)
		done = ok
	end
	if not done then
		ideas = merge(ideas, add, vote)
	end
	changed:Fire()
end

local function reload()
	local s = store
	if not s then
		return
	end
	local ok, fresh = pcall(function()
		return s:GetAsync("list")
	end)
	if ok and type(fresh) == "table" then
		ideas = fresh
		changed:Fire()
	end
end

local function sorted(): { Idea }
	local list = table.clone(ideas)
	table.sort(list, function(x, y)
		if x.v ~= y.v then
			return x.v > y.v
		end
		return x.d > y.d
	end)
	return list
end

---------------------------------------------------------------------
-- СТЕНА В ЛОББИ
---------------------------------------------------------------------
local GREEN = Color3.fromRGB(130, 255, 80)
local GOLD = Color3.fromRGB(255, 214, 90)
local INK = Color3.fromRGB(14, 16, 20)

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Size = size
	l.Position = pos
	l.Parent = parent
	return l
end
local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = parent
end

local board: Part? = nil
local rowsDone: Frame? = nil
local rowsTop: Frame? = nil

local function buildWall()
	local map = workspace:WaitForChild("ZombieTagMap", 60)
	local lobby = if map then map:WaitForChild("Lobby", 60) else nil
	if not lobby then
		return
	end
	local old = lobby:FindFirstChild("IdeaWall")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "IdeaWall"
	-- на правой стене лобби (x = 48), над стендами монет, лицом внутрь
	local cf = CFrame.lookAt(Vector3.new(47.2, 166.5, 0), Vector3.new(0, 166.5, 0))
	local frame = Instance.new("Part")
	frame.Name = "IdeaFrame"
	frame.Anchored = true
	frame.CanCollide = false
	frame.Size = Vector3.new(33, 14.6, 0.5)
	frame.CFrame = cf * CFrame.new(0, 0, 0.1)
	frame.Color = INK
	frame.Material = Enum.Material.Metal
	frame.Parent = model
	local glow = Instance.new("Part")
	glow.Name = "IdeaGlow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = Vector3.new(33.6, 15.2, 0.3)
	glow.CFrame = cf * CFrame.new(0, 0, 0.3)
	glow.Color = GREEN
	glow.Material = Enum.Material.Neon
	glow.Parent = model
	local part = Instance.new("Part")
	part.Name = "IdeaBoard"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(32, 14, 0.2)
	part.CFrame = cf * CFrame.new(0, 0, -0.25)
	part.Color = INK
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	board = part

	local gui = Instance.new("SurfaceGui")
	gui.Name = "IdeaGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.15
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 22, 26)
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(30, 40, 30), Color3.fromRGB(10, 12, 14))
	grad.Parent = bg
	label(bg, "💡 СТЕНА ИДЕЙ · PLAYER IDEAS", UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.03, 0.03), GREEN, Enum.Font.GothamBlack)
	label(bg, "Ты придумываешь — мы добавляем! · You suggest, we build it!", UDim2.fromScale(0.62, 0.05), UDim2.fromScale(0.03, 0.14), Color3.fromRGB(220, 230, 220), Enum.Font.GothamBold)
	label(bg, "Нажми F у стены · Press F here", UDim2.fromScale(0.3, 0.05), UDim2.fromScale(0.67, 0.05), GOLD, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

	local function column(x: number, title: string, color: Color3): Frame
		local col = Instance.new("Frame")
		col.Size = UDim2.fromScale(0.455, 0.74)
		col.Position = UDim2.fromScale(x, 0.22)
		col.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		col.BackgroundTransparency = 0.45
		col.Parent = bg
		corner(col, 0.04)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 3
		stroke.Transparency = 0.3
		stroke.Parent = col
		label(col, title, UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.03), color, Enum.Font.GothamBlack)
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Size = UDim2.fromScale(0.92, 0.82)
		rows.Position = UDim2.fromScale(0.04, 0.16)
		rows.Parent = col
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0.02, 0)
		layout.Parent = rows
		return rows
	end
	rowsDone = column(0.03, "✅ УЖЕ В ИГРЕ · ADDED", GREEN)
	rowsTop = column(0.515, "🔥 ТОП ИДЕЙ · TOP IDEAS", GOLD)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZT_IdeaPrompt"
	prompt.ActionText = "💡 Идея · Idea"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = part

	model.Parent = lobby
end

local function row(parent: Frame, text: string, author: string, right: string, color: Color3)
	local r = Instance.new("Frame")
	r.Size = UDim2.fromScale(1, 0.235)
	r.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	r.BackgroundTransparency = 0.93
	r.Parent = parent
	corner(r, 0.25)
	label(r, text, UDim2.fromScale(0.68, 0.62), UDim2.fromScale(0.03, 0.04), Color3.fromRGB(245, 245, 245), Enum.Font.GothamBold)
	label(r, author, UDim2.fromScale(0.68, 0.32), UDim2.fromScale(0.03, 0.64), color, Enum.Font.Gotham)
	label(r, right, UDim2.fromScale(0.26, 0.7), UDim2.fromScale(0.72, 0.15), color, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
end

local function refreshWall()
	local done, top = rowsDone, rowsTop
	if not done or not top then
		return
	end
	for _, rows in ipairs({ done, top }) do
		for _, c in ipairs(rows:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
	end
	if #DONE == 0 then
		row(done, "Здесь будет твоя идея и твой ник!", "Your idea and name will be here", "⭐", GREEN)
	else
		for i, d in ipairs(DONE) do
			if i > TOP then
				break
			end
			row(done, d.text, "by " .. d.author, "✅", GREEN)
		end
	end
	local list = sorted()
	if #list == 0 then
		row(top, "Пока пусто — стань первым!", "Be the first to suggest!", "💡", GOLD)
	end
	for i, idea in ipairs(list) do
		if i > TOP then
			break
		end
		row(top, idea.t, "by " .. idea.a, "👍 " .. tostring(idea.v), GOLD)
	end
end

---------------------------------------------------------------------
-- ЗАПРОСЫ ОТ ИГРОКОВ
---------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("ZT_Ideas")
if remote then
	remote:Destroy()
end
local fn = Instance.new("RemoteFunction")
fn.Name = "ZT_Ideas"
fn.Parent = ReplicatedStorage

local sent: { [number]: { last: number, day: number, count: number } } = {}
local busy: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local voteAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- one vote per 2 s: each vote writes the DataStore

local function clean(text: any): string?
	if type(text) ~= "string" then
		return nil
	end
	text = string.gsub(text, "[%c]", " ")
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if utf8.len(text) == nil then
		return nil
	end
	if (utf8.len(text) :: number) > MAX_LEN then
		text = string.sub(text, 1, utf8.offset(text, MAX_LEN + 1) - 1)
	end
	if (utf8.len(text) :: number) < 3 then
		return nil
	end
	return text
end

local function listFor(player: Player): { any }
	local out = {}
	for i, idea in ipairs(sorted()) do
		if i > 30 then
			break
		end
		table.insert(out, { id = idea.id, t = idea.t, a = idea.a, v = idea.v, mine = idea.u == player.UserId, voted = idea.by ~= nil and table.find(idea.by, player.UserId) ~= nil })
	end
	local done = {}
	for _, d in ipairs(DONE) do
		table.insert(done, { t = d.text, a = d.author })
	end
	return { ideas = out, done = done }
end

fn.OnServerInvoke = function(player: Player, action: any, a: any): any
	if busy[player] then
		return { ok = false, err = "busy" }
	end
	busy[player] = true
	local result: any = { ok = false, err = "bad" }
	local ok, err = pcall(function()
		if action == "list" then
			result = { ok = true, data = listFor(player) }
		elseif action == "submit" then
			local text = clean(a)
			if not text then
				result = { ok = false, err = "short" }
				return
			end
			local now = os.time()
			local today = now // 86400
			local mine = sent[player.UserId] or { last = 0, day = today, count = 0 }
			if mine.day ~= today then
				mine.day, mine.count = today, 0
			end
			if now - mine.last < COOLDOWN then
				result = { ok = false, err = "wait", left = COOLDOWN - (now - mine.last) }
				return
			end
			if mine.count >= PER_DAY then
				result = { ok = false, err = "day" }
				return
			end
			-- фильтр Roblox: текст увидят все, поэтому только "для всех"
			local filtered: string? = nil
			local fok = pcall(function()
				local r = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
				filtered = r:GetNonChatStringForBroadcastAsync()
			end)
			if not fok or not filtered then
				result = { ok = false, err = "filter" }
				return
			end
			local shown = filtered :: string
			local _, stars = string.gsub(shown, "#", "")
			if stars > (utf8.len(shown) or 0) * 0.5 then
				result = { ok = false, err = "blocked" }
				return
			end
			mine.last = now
			mine.count += 1
			sent[player.UserId] = mine
			local idea: Idea = { id = HttpService:GenerateGUID(false), t = shown, a = player.DisplayName, u = player.UserId, v = 1, d = now, by = { player.UserId } }
			write(idea, nil)
			result = { ok = true, data = listFor(player) }
		elseif action == "vote" and type(a) == "string" and #a <= 64 then
			-- only a real idea, once per player, not more often than every 2 seconds (protects the DataStore budget)
			local target = nil
			for _, idea in ipairs(ideas) do
				if idea.id == a then
					target = idea
					break
				end
			end
			local clock = os.clock()
			if target and not table.find(target.by or {}, player.UserId) and clock - (voteAt[player] or 0) >= 2 then
				voteAt[player] = clock
				write(nil, { id = a, user = player.UserId })
			end
			result = { ok = true, data = listFor(player) }
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[Zombie Tag] Ideas request: " .. tostring(err))
		return { ok = false, err = "error" }
	end
	return result
end

---------------------------------------------------------------------
-- START
---------------------------------------------------------------------
safely("wall", buildWall)
changed.Event:Connect(function()
	safely("refresh", refreshWall)
end)
task.spawn(function()
	safely("load", reload)
	safely("refresh", refreshWall)
	while true do
		task.wait(90)
		safely("load", reload)
	end
end)
