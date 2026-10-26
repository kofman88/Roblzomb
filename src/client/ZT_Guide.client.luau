--[[
	ОБУЧЕНИЕ: КАРТОЧКИ И КНИГА «КАК ИГРАТЬ» (LocalScript ZT_Guide)

	КУДА ВСТАВИТЬ: StarterPlayer -> StarterPlayerScripts -> LocalScript с именем ZT_Guide.
	Тексты и моменты показа решает модуль Tutorial на сервере (ReplicatedStorage.ZT_Tut).

	Что здесь:
	- карточка подсказки слева: значок, заголовок, объяснение, кнопка «Понятно!», сама закрывается через 11 секунд;
	- кнопка «❓ КАК ИГРАТЬ» под кошельком: открывает книгу со всеми темами (✔ - уже изучено).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOXIC = Color3.fromRGB(130, 255, 80)
local PANEL = Color3.fromRGB(14, 18, 24)
local PANEL2 = Color3.fromRGB(26, 32, 40)
local FONT = Enum.Font.FredokaOne
local SHOW_FOR = 11

local DEFAULT = { btn = "❓ HOW TO PLAY", title = "📚 HOW TO PLAY", ok = "Got it!", count = "", goal = "", new = "NEW TIP" }
local function ui(key: string): string
	local v = player:GetAttribute("ZT_Tu_" .. key)
	return if type(v) == "string" then v else (DEFAULT[key] or "")
end

local function tween(object: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end
local function stroke(parent: Instance, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = TOXIC
	s.Thickness = thickness
	s.Transparency = transparency or 0.1
	s.Parent = parent
	return s
end
local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3, maxText: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText
	c.MinTextSize = 9
	c.Parent = l
	l.Parent = parent
	return l
end

local function isPhone(): boolean
	local view = workspace.CurrentCamera.ViewportSize
	return math.min(view.X, view.Y) <= 500
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZT_GuideGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 9
gui.Parent = playerGui

---------------------------------------------------------------------
-- КАРТОЧКА ПОДСКАЗКИ
---------------------------------------------------------------------
local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0, 0.5)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.06
card.Visible = false
card.Parent = gui
corner(card, 16)
stroke(card, 3)
local cardIcon = label(card, "Icon", "", UDim2.fromScale(0.2, 0.42), UDim2.fromScale(0.04, 0.08), Color3.new(1, 1, 1), 60)
cardIcon.TextXAlignment = Enum.TextXAlignment.Center
local cardNew = label(card, "New", "", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.27, 0.07), TOXIC, 16)
local cardTitle = label(card, "Title", "", UDim2.fromScale(0.69, 0.2), UDim2.fromScale(0.27, 0.19), Color3.new(1, 1, 1), 30)
local cardBody = label(card, "Body", "", UDim2.fromScale(0.9, 0.38), UDim2.fromScale(0.05, 0.42), Color3.fromRGB(220, 230, 220), 22)
cardBody.TextYAlignment = Enum.TextYAlignment.Top
local cardCount = label(card, "Count", "", UDim2.fromScale(0.45, 0.1), UDim2.fromScale(0.05, 0.84), Color3.fromRGB(150, 170, 150), 14)
local okButton = Instance.new("TextButton")
okButton.Name = "Ok"
okButton.AnchorPoint = Vector2.new(1, 1)
okButton.Position = UDim2.fromScale(0.95, 0.95)
okButton.Size = UDim2.fromScale(0.36, 0.15)
okButton.BackgroundColor3 = TOXIC
okButton.AutoButtonColor = true
okButton.Font = FONT
okButton.TextScaled = true
okButton.TextColor3 = PANEL
okButton.Text = ""
okButton.Parent = card
corner(okButton, 10)
do
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 22
	c.Parent = okButton
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0.15, 0)
	p.PaddingBottom = UDim.new(0.15, 0)
	p.Parent = okButton
end
-- полоска времени: сколько карточка ещё провисит
local timeBar = Instance.new("Frame")
timeBar.Name = "Time"
timeBar.AnchorPoint = Vector2.new(0, 1)
timeBar.Position = UDim2.fromScale(0, 1)
timeBar.Size = UDim2.new(1, 0, 0, 4)
timeBar.BackgroundColor3 = TOXIC
timeBar.BorderSizePixel = 0
timeBar.Parent = card

local function placeCard()
	-- на телефоне карточка выше и шире (внизу слева джойстик)
	if isPhone() then
		card.Size = UDim2.new(0.44, 0, 0.46, 0)
		card.Position = UDim2.new(0.01, 0, 0.47, 0)
	else
		card.Size = UDim2.new(0, 400, 0, 230)
		card.Position = UDim2.new(0, 16, 0.52, 0)
	end
end
placeCard()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeCard)

local cardToken = 0
local queue: { any } = {}
local function hideCard()
	cardToken += 1
	local token = cardToken
	local target = card.Position
	tween(card, 0.25, { Position = UDim2.new(target.X.Scale, target.X.Offset - 40, target.Y.Scale, target.Y.Offset) })
	task.delay(0.25, function()
		if token == cardToken then
			card.Visible = false
			placeCard()
			local nextOne = table.remove(queue, 1)
			if nextOne then
				task.delay(0.3, function()
					-- следующая карточка из очереди (если за это время не пришла другая)
					if not card.Visible then
						(_G :: any).ZT_ShowTip(nextOne)
					end
				end)
			end
		end
	end)
end
local function showTip(data: any)
	if card.Visible then
		table.insert(queue, data)
		return
	end
	cardToken += 1
	local token = cardToken
	placeCard()
	cardIcon.Text = tostring(data.icon or "❓")
	cardNew.Text = ui("new")
	cardTitle.Text = tostring(data.title or "")
	cardBody.Text = tostring(data.body or "")
	cardCount.Text = tostring(data.count or "")
	okButton.Text = ui("ok")
	local home = card.Position
	card.Position = UDim2.new(home.X.Scale, home.X.Offset - 60, home.Y.Scale, home.Y.Offset)
	card.Visible = true
	tween(card, 0.3, { Position = home }, Enum.EasingStyle.Back)
	timeBar.Size = UDim2.new(1, 0, 0, 4)
	tween(timeBar, SHOW_FOR, { Size = UDim2.new(0, 0, 0, 4) }, Enum.EasingStyle.Linear)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://119377051797825"; s.PlaybackRegionsEnabled = true; s.PlaybackRegion = NumberRange.new(23.7918, 25.2718) -- our pack: "quest"
	s.Volume = 0.5
	s.Parent = gui
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(SHOW_FOR, function()
		if token == cardToken and card.Visible then
			hideCard()
		end
	end)
end
(_G :: any).ZT_ShowTip = showTip
okButton.Activated:Connect(hideCard)

---------------------------------------------------------------------
-- КНИГА «КАК ИГРАТЬ»
---------------------------------------------------------------------
local openButton = Instance.new("TextButton")
openButton.Name = "HowToPlay"
openButton.BackgroundColor3 = PANEL
openButton.BackgroundTransparency = 0.12
openButton.AutoButtonColor = true
openButton.Font = FONT
openButton.TextScaled = true
openButton.TextColor3 = TOXIC
openButton.Text = ui("btn")
openButton.Parent = gui
corner(openButton, 12)
stroke(openButton, 2.5, 0.15)
do
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 20
	c.MinTextSize = 9
	c.Parent = openButton
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0.18, 0)
	p.PaddingBottom = UDim.new(0.18, 0)
	p.PaddingLeft = UDim.new(0.05, 0)
	p.PaddingRight = UDim.new(0.05, 0)
	p.Parent = openButton
end
-- кнопка стоит под кошельком (кошелёк: левый верхний угол экрана игры)
openButton.Size = UDim2.fromScale(0.175, 0.05)
openButton.Position = UDim2.fromScale(0.008, 0.095)

local book = Instance.new("Frame")
book.Name = "Book"
book.AnchorPoint = Vector2.new(0.5, 0.5)
book.Position = UDim2.fromScale(0.5, 0.52)
book.Size = UDim2.fromScale(0.72, 0.74)
book.BackgroundColor3 = PANEL
book.BackgroundTransparency = 0.03
book.Visible = false
book.Parent = gui
corner(book, 18)
stroke(book, 3)
do
	local c = Instance.new("UISizeConstraint")
	c.MaxSize = Vector2.new(940, 600)
	c.Parent = book
end
local bookTitle = label(book, "Title", "", UDim2.fromScale(0.5, 0.09), UDim2.fromScale(0.03, 0.03), TOXIC, 34)
local bookCount = label(book, "Count", "", UDim2.fromScale(0.3, 0.06), UDim2.fromScale(0.03, 0.12), Color3.new(1, 1, 1), 20)
local bookGoal = label(book, "Goal", "", UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.33, 0.12), Color3.fromRGB(255, 215, 90), 20)
local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.fromOffset(44, 44)
closeButton.BackgroundColor3 = PANEL2
closeButton.Font = FONT
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Text = "X"
closeButton.Parent = book
corner(closeButton, 10)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "List"
listFrame.Position = UDim2.fromScale(0.03, 0.2)
listFrame.Size = UDim2.fromScale(0.36, 0.76)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.ScrollBarImageColor3 = TOXIC
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new()
listFrame.Parent = book
do
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame
end

local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.Position = UDim2.fromScale(0.42, 0.2)
detail.Size = UDim2.fromScale(0.55, 0.76)
detail.BackgroundColor3 = PANEL2
detail.Parent = book
corner(detail, 14)
local detailIcon = label(detail, "Icon", "", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.35, 0.04), Color3.new(1, 1, 1), 90)
detailIcon.TextXAlignment = Enum.TextXAlignment.Center
local detailTitle = label(detail, "Title", "", UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.36), Color3.new(1, 1, 1), 34)
detailTitle.TextXAlignment = Enum.TextXAlignment.Center
local detailBody = label(detail, "Body", "", UDim2.fromScale(0.88, 0.44), UDim2.fromScale(0.06, 0.52), Color3.fromRGB(220, 230, 220), 26)
detailBody.TextXAlignment = Enum.TextXAlignment.Center
detailBody.TextYAlignment = Enum.TextYAlignment.Top

local remote = RS:FindFirstChild("ZT_Tut") :: RemoteEvent?
local rows: { [string]: TextButton } = {}

local function selectTopic(data: any)
	detailIcon.Text = tostring(data.icon or "")
	detailTitle.Text = tostring(data.title or "")
	detailBody.Text = tostring(data.body or "")
	for key, row in pairs(rows) do
		local selected = key == data.key
		row.BackgroundColor3 = if selected then Color3.fromRGB(40, 70, 40) else PANEL2
	end
	if not data.seen and remote then
		data.seen = true
		remote:FireServer("read", data.key)
		local row = rows[data.key]
		if row then
			local mark = row:FindFirstChild("Mark") :: TextLabel?
			if mark then
				mark.Text = "✔"
			end
		end
	end
end

local function fillBook(list: { any }, count: string)
	for _, row in pairs(rows) do
		row:Destroy()
	end
	table.clear(rows)
	bookTitle.Text = ui("title")
	bookCount.Text = count
	bookGoal.Text = ui("goal")
	local rowHeight = if isPhone() then 34 else 44
	for index, data in ipairs(list) do
		local row = Instance.new("TextButton")
		row.Name = "Row_" .. tostring(data.key)
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -10, 0, rowHeight)
		row.BackgroundColor3 = PANEL2
		row.AutoButtonColor = true
		row.Text = ""
		row.Parent = listFrame
		corner(row, 10)
		local icon = label(row, "Icon", tostring(data.icon or ""), UDim2.new(0, rowHeight, 1, -6), UDim2.fromOffset(4, 3), Color3.new(1, 1, 1), 28)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		label(row, "Name", tostring(data.title or ""), UDim2.new(1, -rowHeight - 40, 0.7, 0), UDim2.new(0, rowHeight + 8, 0.15, 0), Color3.new(1, 1, 1), 20)
		local mark = label(row, "Mark", if data.seen then "✔" else "•", UDim2.new(0, 26, 0.7, 0), UDim2.new(1, -30, 0.15, 0), TOXIC, 22)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		row.Activated:Connect(function()
			selectTopic(data)
		end)
		rows[data.key] = row
	end
	-- сразу открыта первая неизученная тема
	local first = list[1]
	for _, data in ipairs(list) do
		if not data.seen then
			first = data
			break
		end
	end
	if first then
		selectTopic(first)
	end
end

local function openBook()
	if not remote then
		return
	end
	-- на телефоне книга почти на весь экран
	local w, h = 0.72, 0.74
	if isPhone() then
		w, h = 0.94, 0.86
	end
	book.Visible = true
	book.Size = UDim2.fromScale(w - 0.04, h - 0.04)
	tween(book, 0.2, { Size = UDim2.fromScale(w, h) }, Enum.EasingStyle.Back)
	remote:FireServer("guide")
end
local function closeBook()
	book.Visible = false
end
openButton.Activated:Connect(function()
	if book.Visible then
		closeBook()
	else
		openBook()
	end
end)
closeButton.Activated:Connect(closeBook)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.H then
		if book.Visible then
			closeBook()
		else
			openBook()
		end
	end
end)

local function listen(r: RemoteEvent)
	r.OnClientEvent:Connect(function(what: string, a: any, b: any)
		if what == "tip" and type(a) == "table" then
			showTip(a)
		elseif what == "guide" and type(a) == "table" then
			fillBook(a, tostring(b or ""))
		elseif what == "count" then
			bookCount.Text = tostring(a or "")
		end
	end)
end
if remote then
	listen(remote)
else
	task.spawn(function()
		local r = RS:WaitForChild("ZT_Tut") :: RemoteEvent
		remote = r
		listen(r)
	end)
end

-- подписи меняются, когда сервер узнал язык игрока
player:GetAttributeChangedSignal("ZT_Tu_btn"):Connect(function()
	openButton.Text = ui("btn")
end)

-- во время интро новичка кнопки не видно (экран игры тоже выключен)
task.spawn(function()
	while true do
		local hud = playerGui:FindFirstChild("ZombieTagHud") :: ScreenGui?
		openButton.Visible = hud == nil or hud.Enabled
		task.wait(0.5)
	end
end)
