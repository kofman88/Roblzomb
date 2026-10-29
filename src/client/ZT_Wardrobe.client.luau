--[[
	ГАРДЕРОБ - окно игрока (LocalScript ZT_Wardrobe в StarterPlayer -> StarterPlayerScripts)
	Открывается кнопкой у гардероба в лобби: вкладки "Люди" / "Зомби", карточки с вращающимся манекеном,
	купить / надеть / снять / примерить. Все решения принимает сервер (модуль Costumes).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote: RemoteFunction = ReplicatedStorage:WaitForChild("ZT_Costume", 120) :: RemoteFunction
if not remote then
	return
end
local dolls = ReplicatedStorage:WaitForChild("ZT_CosDolls", 60)

local PINK = Color3.fromRGB(255, 120, 220)
local GOLD = Color3.fromRGB(255, 214, 90)
local INK = Color3.fromRGB(16, 18, 24)

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = p
end
local function label(parent: Instance, s: string, size: UDim2, pos: UDim2, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = s
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Size = size
	l.Position = pos
	l.Parent = parent
	return l
end
local function button(parent: Instance, s: string, size: UDim2, pos: UDim2, bg: Color3, fg: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = s
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = fg
	b.BackgroundColor3 = bg
	b.AutoButtonColor = true
	b.Size = size
	b.Position = pos
	b.Parent = parent
	corner(b, 0.25)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = b
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZT_WardrobeGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 52
gui.IgnoreGuiInset = true
gui.Enabled = false
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
panel.Size = UDim2.fromScale(0.86, 0.86)
panel.BackgroundColor3 = INK
panel.Parent = gui
corner(panel, 0.03)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(980, 700)
limit.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 3
stroke.Parent = panel
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(Color3.fromRGB(34, 26, 44), Color3.fromRGB(12, 12, 18))
grad.Parent = panel

local title = label(panel, "👗", UDim2.fromScale(0.4, 0.08), UDim2.fromScale(0.03, 0.025), PINK, Enum.Font.GothamBlack)
local coins = label(panel, "", UDim2.fromScale(0.25, 0.06), UDim2.fromScale(0.62, 0.035), GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
local close = button(panel, "X", UDim2.fromScale(0.06, 0.075), UDim2.fromScale(0.915, 0.025), Color3.fromRGB(190, 60, 60), Color3.new(1, 1, 1))

local tabH = button(panel, "", UDim2.fromScale(0.2, 0.07), UDim2.fromScale(0.03, 0.12), PINK, INK)
local tabZ = button(panel, "", UDim2.fromScale(0.2, 0.07), UDim2.fromScale(0.245, 0.12), Color3.fromRGB(50, 50, 60), Color3.new(1, 1, 1))
local hint = label(panel, "", UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.47, 0.13), Color3.fromRGB(210, 210, 220), Enum.Font.Gotham)
local status = label(panel, "", UDim2.fromScale(0.94, 0.05), UDim2.fromScale(0.03, 0.93), GOLD, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Size = UDim2.fromScale(0.94, 0.72)
grid.Position = UDim2.fromScale(0.03, 0.21)
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromScale(0.235, 0.98)
layout.CellPadding = UDim2.fromScale(0.02, 0)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local side = "h"
local state: any = nil
local spinners: { { model: Model, base: CFrame } } = {}
local cards: { [string]: any } = {}

local function ui(key: string): string
	if state and state.ui and state.ui[key] then
		return state.ui[key]
	end
	return if state and state.uiEn then state.uiEn[key] or key else key
end

local function say(s: string)
	status.Text = s
	local mine = s
	task.delay(4, function()
		if status.Text == mine then
			status.Text = ""
		end
	end)
end

local function request(action: string, id: string?)
	local ok, res = pcall(function()
		return remote:InvokeServer(action, id)
	end)
	if not ok or type(res) ~= "table" then
		say(ui("err_bad"))
		return
	end
	if res.state then
		state = res.state
	end
	if res.ok then
		if res.msg == "try" then
			say(string.format(ui("msg_try"), res.n or 12))
		elseif res.msg then
			say(ui("msg_" .. res.msg))
		end
	else
		local key = "err_" .. tostring(res.err)
		local s = ui(key)
		if res.n then
			s = string.format(s, res.n)
		end
		say(s)
	end
	return res
end

local function viewport(parent: Instance, id: string)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
	vp.BackgroundTransparency = 0
	vp.Size = UDim2.fromScale(1, 0.56)
	vp.Ambient = Color3.fromRGB(150, 150, 160)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-1, -1.2, -1.4)
	vp.Parent = parent
	corner(vp, 0.06)
	local src = if dolls then dolls:FindFirstChild(id) else nil
	if not src then
		return
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local rig = src:Clone()
	local base = CFrame.new(0, 0, 0)
	rig:PivotTo(base)
	rig.Parent = world
	local cf, size = rig:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = math.max(size.Y, size.X) * 2.1
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.08, -dist), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(spinners, { model = rig, base = base, centre = cf.Position })
end

local function build()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(spinners)
	table.clear(cards)
	if not state then
		return
	end
	title.Text = ui("title")
	tabH.Text = ui("humans")
	tabZ.Text = ui("zombies")
	tabH.BackgroundColor3 = if side == "h" then PINK else Color3.fromRGB(50, 50, 60)
	tabH.TextColor3 = if side == "h" then INK else Color3.new(1, 1, 1)
	tabZ.BackgroundColor3 = if side == "z" then Color3.fromRGB(130, 255, 80) else Color3.fromRGB(50, 50, 60)
	tabZ.TextColor3 = if side == "z" then INK else Color3.new(1, 1, 1)
	hint.Text = ui(if side == "h" then "hint_h" else "hint_z")
	coins.Text = tostring(state.coins) .. " 💰"
	local order = 0
	for _, c in ipairs(state.list) do
		if c.side == side then
			order += 1
			local card = Instance.new("Frame")
			card.LayoutOrder = order
			card.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
			card.Parent = grid
			corner(card, 0.05)
			local wornNow = state[side] == c.id
			local st = Instance.new("UIStroke")
			st.Color = if wornNow then GOLD else c.color
			st.Thickness = if wornNow then 3 else 1.5
			st.Parent = card
			viewport(card, c.id)
			label(card, c.name, UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.05, 0.575), c.color, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			label(card, c.about, UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.66), Color3.fromRGB(200, 200, 210), Enum.Font.Gotham, Enum.TextXAlignment.Center)
			local locked = not c.owned and (state.level or 0) < (c.level or 0)
			local main
			if wornNow then
				main = button(card, ui("off"), UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.765), Color3.fromRGB(70, 70, 84), Color3.new(1, 1, 1))
				main.Activated:Connect(function()
					request("off", c.id)
					build()
				end)
			elseif c.owned then
				main = button(card, ui("wear"), UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.765), Color3.fromRGB(130, 255, 80), INK)
				main.Activated:Connect(function()
					request("wear", c.id)
					build()
				end)
			else
				local text = if locked then string.format(ui("lvl"), c.level) else string.format(ui("buy"), c.price)
				main = button(card, text, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.765), if locked then Color3.fromRGB(80, 70, 50) else GOLD, if locked then Color3.fromRGB(230, 220, 200) else INK)
				main.Activated:Connect(function()
					request("buy", c.id)
					build()
				end)
			end
			if not c.owned then
				local try = button(card, ui("try"), UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.885), Color3.fromRGB(60, 60, 76), Color3.new(1, 1, 1))
				try.Activated:Connect(function()
					request("try", c.id)
				end)
			elseif wornNow then
				label(card, "✓", UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.885), GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
			end
			cards[c.id] = card
		end
	end
end

local spin = 0
local conn: RBXScriptConnection? = nil
local function open()
	gui.Enabled = true
	status.Text = ""
	panel.Size = UDim2.fromScale(0.7, 0.7)
	TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.86, 0.86) }):Play()
	request("state")
	build()
	if not conn then
		conn = RunService.RenderStepped:Connect(function(dt)
			if not gui.Enabled then
				-- closed from outside (the window manager in ZT_Art): stop turning the figures
				if conn then
					conn:Disconnect()
					conn = nil
				end
				return
			end
			spin += dt * 0.9
			for _, s in ipairs(spinners) do
				if s.model.Parent then
					s.model:PivotTo(CFrame.new(s.centre) * CFrame.Angles(0, spin, 0) * CFrame.new(-s.centre) * s.base)
				end
			end
		end)
	end
end
local function hide()
	gui.Enabled = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

tabH.Activated:Connect(function()
	side = "h"
	build()
end)
tabZ.Activated:Connect(function()
	side = "z"
	build()
end)
close.Activated:Connect(hide)
shade.Activated:Connect(hide)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ZT_WardrobePrompt" then
		open()
	end
end)
