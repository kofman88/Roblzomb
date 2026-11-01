--!strict
-- ZT_Welcome (client): the "pick your first trail" window after the first round and the "build your first house" step.
-- The server module Welcome decides when to show it and does the purchase; this script only draws and sends taps.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = RS:WaitForChild("ZT_Welcome", 120)
if not remote or not remote:IsA("RemoteEvent") then
	return
end
local signal = remote :: RemoteEvent

local NIGHT, TOXIC, CHALK, COAL, STEEL = Color3.fromHex("26314D"), Color3.fromHex("7CF25A"), Color3.fromHex("ECEEE8"), Color3.fromHex("1B1C22"), Color3.fromHex("4A505C")
local FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")
local GOTHAM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function corner(o: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function text(parent: Instance, name: string, size: UDim2, pos: UDim2, font: Font, color: Color3, value: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.FontFace = font
	l.TextColor3 = color
	l.TextScaled = true
	l.Text = value
	l.Parent = parent
	return l
end
local function button(parent: Instance, name: string, size: UDim2, pos: UDim2, bg: Color3, fg: Color3, value: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = bg
	b.TextColor3 = fg
	b.FontFace = FREDOKA
	b.TextScaled = true
	b.Text = value
	b.AutoButtonColor = false
	b.Parent = parent
	corner(b, 12)
	local finger = Instance.new("UISizeConstraint")
	finger.Name = "ZT_Finger"
	finger.MinSize = Vector2.new(44, 44)
	finger.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZT_WelcomeGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = COAL
dim.BackgroundTransparency = 0.45
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.92, 0.7)
panel.BackgroundColor3 = NIGHT
panel.Parent = gui
corner(panel, 18)
local stroke = Instance.new("UIStroke")
stroke.Color = TOXIC
stroke.Thickness = 3
stroke.Parent = panel
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1.55
ratio.Parent = panel
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(660, 426)
limit.Parent = panel
local pop = Instance.new("UIScale")
pop.Parent = panel

local title = text(panel, "Title", UDim2.fromScale(0.92, 0.14), UDim2.fromScale(0.04, 0.05), FREDOKA, CHALK, "")
local sub = text(panel, "Sub", UDim2.fromScale(0.92, 0.08), UDim2.fromScale(0.04, 0.2), GOTHAM, CHALK, "")
sub.TextTransparency = 0.2
local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Size = UDim2.fromScale(0.92, 0.5)
body.Position = UDim2.fromScale(0.04, 0.32)
body.Parent = panel
local later = button(panel, "Later", UDim2.fromScale(0.3, 0.11), UDim2.fromScale(0.35, 0.85), COAL, CHALK, "")

local busy = false
local function clear()
	for _, c in ipairs(body:GetChildren()) do
		c:Destroy()
	end
end
local function show()
	busy = false
	gui.Enabled = true
	pop.Scale = 0.88
	TweenService:Create(pop, POP, { Scale = 1 }):Play()
end
local function hide()
	gui.Enabled = false
	clear()
end

later.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	signal:FireServer("later")
end)

local function trailCards(data: any)
	clear()
	title.Text = data.title
	sub.Text = data.sub
	later.Text = data.later
	local items = data.items or {}
	local count = math.max(1, #items)
	local gap = 0.03
	local width = (1 - gap * (count - 1)) / count
	for i, item in ipairs(items) do
		local card = Instance.new("Frame")
		card.Name = "Card_" .. item.id
		card.BackgroundColor3 = COAL
		card.Size = UDim2.fromScale(width, 1)
		card.Position = UDim2.fromScale((i - 1) * (width + gap), 0)
		card.Parent = body
		corner(card, 14)
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.BackgroundColor3 = Color3.new(1, 1, 1)
		swatch.Size = UDim2.fromScale(0.84, 0.34)
		swatch.Position = UDim2.fromScale(0.08, 0.07)
		swatch:SetAttribute("ZT_KeepColor", true) -- the real trail colours, not the UI palette
		swatch.Parent = card
		corner(swatch, 10)
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(item.a, item.b)
		grad:SetAttribute("ZT_KeepColor", true)
		grad.Parent = swatch
		text(card, "Name", UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.45), FREDOKA, CHALK, item.name)
		local buy = button(card, "Buy", UDim2.fromScale(0.84, 0.28), UDim2.fromScale(0.08, 0.67),
			if item.can then TOXIC else STEEL, COAL, data.take .. "  " .. item.price .. " 💰")
		if not item.can then
			buy.Active = false
			buy.AutoButtonColor = false
		end
		buy.Activated:Connect(function()
			if busy or not item.can then
				return
			end
			busy = true
			buy.Text = "✓"
			signal:FireServer("buy", item.id)
		end)
	end
	show()
end

local function homeCard(data: any)
	clear()
	title.Text = data.title
	sub.Text = data.sub
	later.Text = data.later
	local icon = text(body, "Icon", UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), FREDOKA, CHALK, "🏠")
	icon.TextTransparency = 0
	local go = button(body, "Go", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.25, 0.66), TOXIC, COAL, data.go)
	go.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		signal:FireServer("home")
	end)
	show()
end

signal.OnClientEvent:Connect(function(what: string, data: any)
	if what == "trail" and type(data) == "table" then
		trailCards(data)
	elseif what == "home" and type(data) == "table" then
		homeCard(data)
	elseif what == "close" then
		hide()
	end
end)
