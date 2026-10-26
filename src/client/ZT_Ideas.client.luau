--[[
	СТЕНА ИДЕЙ - окно игрока (LocalScript ZT_Ideas в StarterPlayer -> StarterPlayerScripts)
	Открывается кнопкой у "Стены идей" в лобби: поле для своей идеи и список лучших идей с лайками.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ru = string.sub(string.lower(player.LocaleId or ""), 1, 2) == "ru"
local T = if ru then {
	title = "💡 ПРЕДЛОЖИ ИДЕЮ",
	sub = "Лучшая идея по лайкам попадёт в игру, а твой ник - на стену!",
	hint = "Что добавить в игру? Новый зомби, оружие, карта...",
	send = "ОТПРАВИТЬ",
	top = "🔥 ИДЕИ ИГРОКОВ — ставь лайк лучшим",
	done = "✅ Уже в игре",
	empty = "Пока идей нет — стань первым!",
	ok = "Спасибо! Идея на стене 💡",
	short = "Напиши хотя бы пару слов",
	wait = "Подожди %d сек. перед новой идеей",
	day = "На сегодня хватит: 5 идей в день",
	filter = "Не получилось проверить текст, попробуй позже",
	blocked = "Этот текст нельзя показать другим игрокам",
	error = "Что-то пошло не так, попробуй ещё раз",
	mine = "твоя",
} else {
	title = "💡 SUGGEST AN IDEA",
	sub = "The most liked idea gets into the game, and your name goes on the wall!",
	hint = "What should we add? A new zombie, weapon, map...",
	send = "SEND",
	top = "🔥 PLAYER IDEAS — like the best ones",
	done = "✅ Already in the game",
	empty = "No ideas yet — be the first!",
	ok = "Thanks! Your idea is on the wall 💡",
	short = "Write at least a couple of words",
	wait = "Wait %d s before the next idea",
	day = "That's enough for today: 5 ideas a day",
	filter = "Couldn't check the text, try later",
	blocked = "This text can't be shown to other players",
	error = "Something went wrong, try again",
	mine = "yours",
}

local remote: RemoteFunction = ReplicatedStorage:WaitForChild("ZT_Ideas", 60) :: RemoteFunction
if not remote then
	return
end

local GREEN = Color3.fromRGB(130, 255, 80)
local GOLD = Color3.fromRGB(255, 214, 90)

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = p
end
local function text(parent: Instance, s: string, size: UDim2, pos: UDim2, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = s
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = size
	l.Position = pos
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZT_IdeasGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("TextButton")
shade.Text = ""
shade.AutoButtonColor = false
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.8)
panel.BackgroundColor3 = Color3.fromRGB(16, 20, 24)
panel.Parent = gui
corner(panel, 0.04)
local ratio = Instance.new("UISizeConstraint")
ratio.MaxSize = Vector2.new(760, 640)
ratio.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GREEN
stroke.Thickness = 3
stroke.Parent = panel

text(panel, T.title, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.05, 0.03), GREEN, Enum.Font.GothamBlack)
text(panel, T.sub, UDim2.fromScale(0.86, 0.05), UDim2.fromScale(0.05, 0.11), Color3.fromRGB(220, 225, 220))

local close = Instance.new("TextButton")
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextScaled = true
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
close.Size = UDim2.fromScale(0.07, 0.08)
close.Position = UDim2.fromScale(0.9, 0.03)
close.Parent = panel
corner(close, 0.3)

local box = Instance.new("TextBox")
box.PlaceholderText = T.hint
box.Text = ""
box.ClearTextOnFocus = false
box.MultiLine = false
box.TextWrapped = true
box.TextScaled = true
box.Font = Enum.Font.Gotham
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderColor3 = Color3.fromRGB(150, 155, 160)
box.TextXAlignment = Enum.TextXAlignment.Left
box.BackgroundColor3 = Color3.fromRGB(32, 38, 44)
box.Size = UDim2.fromScale(0.66, 0.1)
box.Position = UDim2.fromScale(0.05, 0.19)
box.Parent = panel
corner(box, 0.2)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0.02, 0)
pad.PaddingRight = UDim.new(0.02, 0)
pad.Parent = box

local send = Instance.new("TextButton")
send.Text = T.send
send.Font = Enum.Font.GothamBlack
send.TextScaled = true
send.TextColor3 = Color3.fromRGB(10, 20, 10)
send.BackgroundColor3 = GREEN
send.Size = UDim2.fromScale(0.22, 0.1)
send.Position = UDim2.fromScale(0.73, 0.19)
send.Parent = panel
corner(send, 0.2)

local status = text(panel, "", UDim2.fromScale(0.9, 0.045), UDim2.fromScale(0.05, 0.3), GOLD)
text(panel, T.top, UDim2.fromScale(0.9, 0.055), UDim2.fromScale(0.05, 0.36), GOLD, Enum.Font.GothamBlack)

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Size = UDim2.fromScale(0.9, 0.54)
list.Position = UDim2.fromScale(0.05, 0.43)
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local voting = false
local function fill(data: any)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if type(data) ~= "table" then
		return
	end
	local order = 0
	for _, d in ipairs(data.done or {}) do
		order += 1
		local r = Instance.new("Frame")
		r.LayoutOrder = order
		r.Size = UDim2.new(1, -8, 0, 52)
		r.BackgroundColor3 = Color3.fromRGB(30, 60, 34)
		r.Parent = list
		corner(r, 0.2)
		text(r, "✅ " .. d.t, UDim2.fromScale(0.7, 0.6), UDim2.fromScale(0.03, 0.05), Color3.new(1, 1, 1))
		text(r, T.done .. " · " .. d.a, UDim2.fromScale(0.7, 0.32), UDim2.fromScale(0.03, 0.65), GREEN, Enum.Font.Gotham)
	end
	if #(data.ideas or {}) == 0 then
		order += 1
		local r = Instance.new("Frame")
		r.LayoutOrder = order
		r.Size = UDim2.new(1, -8, 0, 44)
		r.BackgroundTransparency = 1
		r.Parent = list
		text(r, T.empty, UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Color3.fromRGB(200, 200, 200))
	end
	for _, idea in ipairs(data.ideas or {}) do
		order += 1
		local r = Instance.new("Frame")
		r.LayoutOrder = order
		r.Size = UDim2.new(1, -8, 0, 56)
		r.BackgroundColor3 = Color3.fromRGB(34, 40, 46)
		r.Parent = list
		corner(r, 0.2)
		text(r, idea.t, UDim2.fromScale(0.74, 0.6), UDim2.fromScale(0.03, 0.05), Color3.new(1, 1, 1))
		text(r, idea.a .. (if idea.mine then " (" .. T.mine .. ")" else ""), UDim2.fromScale(0.74, 0.3), UDim2.fromScale(0.03, 0.66), GOLD, Enum.Font.Gotham)
		local like = Instance.new("TextButton")
		like.Text = "👍 " .. tostring(idea.v)
		like.Font = Enum.Font.GothamBlack
		like.TextScaled = true
		like.TextColor3 = if idea.voted then Color3.fromRGB(10, 20, 10) else Color3.new(1, 1, 1)
		like.BackgroundColor3 = if idea.voted then GREEN else Color3.fromRGB(60, 70, 80)
		like.Size = UDim2.fromScale(0.18, 0.7)
		like.Position = UDim2.fromScale(0.8, 0.15)
		like.Parent = r
		corner(like, 0.3)
		like.Activated:Connect(function()
			if idea.voted or voting then
				return
			end
			voting = true
			local ok, res = pcall(function()
				return remote:InvokeServer("vote", idea.id)
			end)
			voting = false
			if ok and type(res) == "table" and res.ok then
				fill(res.data)
			end
		end)
	end
end

local function say(key: string, n: number?)
	local s = T[key] or T.error
	status.Text = if n then string.format(s, n) else s
end

local function open()
	gui.Enabled = true
	status.Text = ""
	panel.Size = UDim2.fromScale(0.5, 0.64)
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.62, 0.8) }):Play()
	task.spawn(function()
		local ok, res = pcall(function()
			return remote:InvokeServer("list")
		end)
		if ok and type(res) == "table" and res.ok then
			fill(res.data)
		end
	end)
end
local function hide()
	gui.Enabled = false
	box:ReleaseFocus()
end

local sending = false
local function submit()
	if sending then
		return
	end
	sending = true
	send.AutoButtonColor = false
	send.BackgroundTransparency = 0.4
	local ok, res = pcall(function()
		return remote:InvokeServer("submit", box.Text)
	end)
	sending = false
	send.BackgroundTransparency = 0
	if ok and type(res) == "table" then
		if res.ok then
			box.Text = ""
			say("ok")
			fill(res.data)
		else
			say(res.err or "error", res.left)
		end
	else
		say("error")
	end
end

send.Activated:Connect(submit)
box.FocusLost:Connect(function(enter)
	if enter then
		submit()
	end
end)
close.Activated:Connect(hide)
shade.Activated:Connect(hide)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ZT_IdeaPrompt" then
		open()
	end
end)
