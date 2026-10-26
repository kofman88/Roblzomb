--[[
	ЭФФЕКТЫ «СЕЗОН 1: ТОКСИЧНАЯ НОЧЬ» (LocalScript ZT_Fx)

	КУДА ВСТАВИТЬ: StarterPlayer -> StarterPlayerScripts -> LocalScript с именем ZT_Fx.
	Сигналы присылает модуль Season (ReplicatedStorage.ZT_Fx). Без модуля скрипт только меняет стиль экрана.

	Что здесь:
	- новый стиль интерфейса: шрифт, плашки с токсично-зелёной обводкой, градиенты;
	- кнопка умения (Q / ⚡): рывок выжившего, прыжок зомби, с полоской перезарядки;
	- поимка: вспышка, тряска, «ЗАРАЖЁН!» и комбо; превращение в зомби: короткая сцена;
	- мало выживших: стук сердца; последний выживший: оранжевая подсветка и напряжение;
	- финальная охота: токсичная гамма; интро: лобби в небе спрятано, пока камера летит над городом.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOXIC = Color3.fromRGB(130, 255, 80)
local TOXIC_DARK = Color3.fromRGB(40, 120, 30)
local PANEL = Color3.fromRGB(14, 18, 24)
local FONT = Enum.Font.FredokaOne

local function tween(object: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- ТЕКСТЫ: на языке игрока (их кладёт сервер), иначе английские
local DEFAULT = {
	fx_dash = "DASH", fx_lunge = "LUNGE", fx_infected = "INFECTED!", fx_combo = "COMBO x%d", fx_turned = "YOU'VE BEEN INFECTED",
	fx_turned2 = "Now catch the others!", fx_last = "LAST SURVIVOR: %s", fx_last_me = "YOU ARE THE LAST ONE. HOLD ON!",
	fx_dash_tip = "Press Q to dash!", fx_dash_tip_t = "Tap ⚡ to dash!", fx_season = "SEASON 1: TOXIC NIGHT",
}
local function t(key: string, ...: any): string
	local template = player:GetAttribute("ZT_Fx_" .. key)
	if type(template) ~= "string" then
		template = DEFAULT[key] or key
	end
	local ok, s = pcall(string.format, template, ...)
	return if ok then s else template
end

-- звуки эффектов лежат в своей папке (не в PlayerGui: там каждое новое дитя запускает пересмотр экрана)
local soundHolder = Instance.new("Folder")
soundHolder.Name = "ZT_FxSounds"
soundHolder.Parent = player
-- our sfx pack: one file, every sound is a region of it (art bible: no library sounds)
local ZT_PACK = "rbxassetid://119377051797825"
local ZT_REGION: { [string]: { number } } = {
	thud = { 28.7124, 29.6 }, hunt = { 13.2718, 15.6856 }, tick = { 31.3124, 31.7483 }, win = { 77.1677, 80.2877 },
	w_growl1 = { 33.5945, 35.2847 }, w_growl2 = { 35.7647, 37.8847 }, w_growl3 = { 38.3647, 39.8441 },
	w_whoosh = { 76.0241, 76.6877 }, catch = { 4.7, 5.5002 },
}
local function setSound(s: Sound, id: string)
	local region = ZT_REGION[id]
	if region then
		s.SoundId = ZT_PACK
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
	else
		s.SoundId = id
	end
end
local function sound(id: string, volume: number, pitch: number?)
	local s = Instance.new("Sound")
	setSound(s, id)
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = soundHolder
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end
local SND_BASS = "thud"
local SND_WHOOSH = "w_whoosh"
local SND_HIT = "catch"

---------------------------------------------------------------------
-- СЛОЙ ЭФФЕКТОВ
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZT_FxGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = playerGui

local function vignetteFrame(name: string, color: Color3): Frame
	-- рамка: затемнение по краям экрана (градиент от краёв к центру)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local sides = {
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0.72), 270 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local f = Instance.new("Frame")
		f.Size = side[1]
		f.Position = side[2]
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0
		local g = Instance.new("UIGradient")
		g.Rotation = side[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = holder
	end
	holder.Visible = false
	return holder
end
local redEdge = vignetteFrame("Danger", Color3.fromRGB(200, 20, 20))
local greenEdge = vignetteFrame("Toxic", TOXIC_DARK)

local function edgeAlpha(holder: Frame, alpha: number)
	-- alpha 0 = нет рамки, 1 = полная
	holder.Visible = alpha > 0.01
	for _, f in ipairs(holder:GetChildren()) do
		if f:IsA("Frame") then
			f.BackgroundTransparency = 1 - alpha
		end
	end
end

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = TOXIC
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui
local function doFlash(color: Color3, from: number, time: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = from
	tween(flash, time, { BackgroundTransparency = 1 })
end

local function stamp(text: string, color: Color3, y: number, size: number, life: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.9, size)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Rotation = -4
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	grad.Rotation = 90
	grad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(10, 14, 10)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 2.2
	scale.Parent = label
	label.Parent = gui
	tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(life, function()
		tween(label, 0.25, { TextTransparency = 1 })
		tween(stroke, 0.25, { Transparency = 1 })
		task.wait(0.3)
		label:Destroy()
	end)
	return label
end

-- тряска камеры: короткий толчок
local shakeUntil, shakePower = 0, 0
RunService:BindToRenderStep("ZT_FxShake", Enum.RenderPriority.Camera.Value + 2, function()
	local now = os.clock()
	if now < shakeUntil then
		local k = (shakeUntil - now) * shakePower
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end
end)
local function shake(power: number, time: number)
	shakeUntil = os.clock() + time
	shakePower = power / time
end

local function fovKick(add: number, time: number)
	local cam = workspace.CurrentCamera
	local base = 70
	cam.FieldOfView = base + add
	tween(cam, time, { FieldOfView = base })
end

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ZT_FxColor"
cc.Parent = Lighting
local function grade(goal: { [string]: any }, time: number)
	tween(cc, time, goal)
end

---------------------------------------------------------------------
-- НОВЫЙ СТИЛЬ ИНТЕРФЕЙСА
---------------------------------------------------------------------
local PANELS = { Status = true, Wallet = true, Pack = true, Track = true }
local styled: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local deduped = false
local function styleLabel(label: TextLabel, panel: boolean)
	if styled[label] then
		return
	end
	styled[label] = true
	label.Font = FONT
	if panel then
		label.BackgroundColor3 = PANEL
		label.BackgroundTransparency = 0.12
		local stroke = Instance.new("UIStroke")
		stroke.Name = "ZT_Stroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = TOXIC
		stroke.Thickness = 2.5
		stroke.Transparency = 0.15
		stroke.Parent = label
		local grad = Instance.new("UIGradient")
		grad.Name = "ZT_Grad"
		grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 215, 205))
		grad.Rotation = 90
		grad.Parent = label
		local corner = label:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 14)
		end
	end
end
local function styleWhenText(label: TextLabel)
	-- плашка с подсказкой: обводка только когда в ней есть текст (иначе висит пустая рамка)
	if styled[label] then
		return
	end
	styled[label] = true
	label.Font = FONT
	local stroke = Instance.new("UIStroke")
	stroke.Name = "ZT_Stroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = TOXIC
	stroke.Thickness = 2
	stroke.Parent = label
	local function update()
		local shown = label.Text ~= "" and label.BackgroundTransparency < 0.95 and label.Visible
		stroke.Transparency = if shown then 0.35 else 1
	end
	label:GetPropertyChangedSignal("Text"):Connect(update)
	label:GetPropertyChangedSignal("BackgroundTransparency"):Connect(update)
	update()
end

local hudRefs: { [string]: TextLabel } = {}
local function styleHud(hud: Instance)
	for _, child in ipairs(hud:GetChildren()) do
		if child:IsA("TextLabel") then
			hudRefs[child.Name] = child
			if PANELS[child.Name] then
				styleLabel(child, true)
			elseif child.Name == "Goal" or child.Name == "Toast" then
				styleWhenText(child)
			else
				styleLabel(child, false)
			end
		end
	end
	local big = hudRefs.Big
	local status = hudRefs.Status
	if big and not big:FindFirstChild("ZT_Grad") then
		local grad = Instance.new("UIGradient")
		grad.Name = "ZT_Grad"
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 255, 160))
		grad.Rotation = 90
		grad.Parent = big
		local function pop()
			if big.Text == "" then
				return
			end
			local s = big:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			s.Parent = big
			s.Scale = 1.35
			tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		big:GetPropertyChangedSignal("Text"):Connect(pop)
	end
	-- одинаковый текст в верхней строке и крупно по центру: верхнюю строку на это время прячем
	if big and status and not deduped then
		deduped = true
		local function dedupe()
			status.Visible = not (big.Text ~= "" and big.Text == status.Text)
		end
		big:GetPropertyChangedSignal("Text"):Connect(dedupe)
		status:GetPropertyChangedSignal("Text"):Connect(dedupe)
		dedupe()
	end
end
-- остальные экраны игры (нижние строки: рюкзак, задания, тыквы): тот же шрифт и рамка
local OTHER_GUIS = { ZT_Bag = true, ZT_Tracker = true, ZT_Stash = true, ZT_SvHud = true, ZT_HomeHud = true, ZT_HwHud = true }
local function styleOther(screen: Instance)
	for _, d in ipairs(screen:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not styled[d] then
			if d.BackgroundTransparency < 0.9 and d.AbsoluteSize.Y < 120 then
				styleLabel(d, true)
			else
				styled[d] = true
				d.Font = FONT
			end
		end
	end
end
-- надписи в мире (лобби, витрины, колесо, дома): тот же шрифт, что и на экране
local function styleWorld(board: Instance)
	for _, d in ipairs(board:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not styled[d] then
			styled[d] = true
			if d.TextScaled and (d.Font == Enum.Font.GothamBold or d.Font == Enum.Font.GothamBlack or d.Font == Enum.Font.Gotham) then
				d.Font = FONT
			end
		end
	end
end
local function scanGuis()
	for _, screen in ipairs(playerGui:GetChildren()) do
		if screen:IsA("ScreenGui") then
			if screen.Name == "ZombieTagHud" then
				styleHud(screen)
			elseif OTHER_GUIS[screen.Name] then
				styleOther(screen)
			end
		elseif screen:IsA("BillboardGui") or screen:IsA("SurfaceGui") then
			styleWorld(screen)
		end
	end
end
playerGui.ChildAdded:Connect(function()
	task.wait(0.5)
	scanGuis()
end)
task.spawn(function()
	while true do
		scanGuis()
		task.wait(3)
	end
end)

---------------------------------------------------------------------
-- КНОПКА УМЕНИЯ
---------------------------------------------------------------------
local remote = RS:FindFirstChild("ZT_Fx") :: RemoteEvent?
-- кнопки управления Roblox на экране есть у всех сенсорных устройств (и у планшета с клавиатурой)
local touch = UserInputService.TouchEnabled

local abilityGui = Instance.new("ScreenGui")
abilityGui.Name = "ZT_Ability"
abilityGui.ResetOnSpawn = false
abilityGui.DisplayOrder = 6
abilityGui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "Dash"
button.AnchorPoint = Vector2.new(1, 1)
-- на телефоне кнопка стоит над кнопкой прыжка Roblox (там её привычно жать большим пальцем)
local function placeButton()
	local view = workspace.CurrentCamera.ViewportSize
	local small = math.min(view.X, view.Y) <= 500
	if touch then
		local size = if small then 64 else 92
		button.Size = UDim2.fromOffset(size, size)
		button.Position = if small then UDim2.new(1, -30, 1, -104) else UDim2.new(1, -60, 1, -190)
	else
		button.Size = UDim2.fromOffset(96, 96)
		button.Position = UDim2.new(1, -24, 1, -110)
	end
end
placeButton()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeButton)
button.BackgroundColor3 = PANEL
button.BackgroundTransparency = 0.1
button.AutoButtonColor = false
button.Text = ""
button.Visible = false
button.Parent = abilityGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = button
	local s = Instance.new("UIStroke")
	s.Name = "Ring"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = TOXIC
	s.Thickness = 4
	s.Parent = button
end
local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.BackgroundTransparency = 1
icon.Size = UDim2.fromScale(1, 0.55)
icon.Position = UDim2.fromScale(0, 0.06)
icon.Font = FONT
icon.TextScaled = true
icon.Text = "⚡"
icon.TextColor3 = Color3.new(1, 1, 1)
icon.Parent = button
local caption = Instance.new("TextLabel")
caption.Name = "Caption"
caption.BackgroundTransparency = 1
caption.Size = UDim2.fromScale(0.86, 0.24)
caption.Position = UDim2.fromScale(0.07, 0.6)
caption.Font = FONT
caption.TextScaled = true
caption.TextColor3 = TOXIC
caption.Text = ""
caption.Parent = button
local keyHint = Instance.new("TextLabel")
keyHint.Name = "Key"
keyHint.AnchorPoint = Vector2.new(0.5, 0.5)
keyHint.Position = UDim2.fromScale(0.15, 0.15)
keyHint.Size = UDim2.fromOffset(28, 28)
keyHint.BackgroundColor3 = TOXIC
keyHint.Font = Enum.Font.GothamBlack
keyHint.TextScaled = true
keyHint.Text = "Q"
keyHint.TextColor3 = PANEL
keyHint.Visible = UserInputService.KeyboardEnabled
keyHint.Parent = button
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = keyHint
end
-- полоска перезарядки: тёмная заливка уходит снизу вверх
local cool = Instance.new("Frame")
cool.Name = "Cooldown"
cool.AnchorPoint = Vector2.new(0, 1)
cool.Position = UDim2.fromScale(0, 1)
cool.Size = UDim2.fromScale(1, 0)
cool.BackgroundColor3 = Color3.new(0, 0, 0)
cool.BackgroundTransparency = 0.35
cool.BorderSizePixel = 0
cool.ZIndex = 3
cool.Parent = button
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = cool
end
local coolText = Instance.new("TextLabel")
coolText.BackgroundTransparency = 1
coolText.Size = UDim2.fromScale(1, 1)
coolText.Font = FONT
coolText.TextScaled = true
coolText.TextColor3 = Color3.new(1, 1, 1)
coolText.Text = ""
coolText.ZIndex = 4
coolText.Parent = button
local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.AnchorPoint = Vector2.new(1, 1)
tip.Position = UDim2.new(1, 0, 0, -12)
tip.Size = UDim2.fromOffset(240, 34)
tip.BackgroundColor3 = PANEL
tip.BackgroundTransparency = 0.15
tip.Font = FONT
tip.TextScaled = true
tip.TextColor3 = Color3.new(1, 1, 1)
tip.Visible = false
tip.Parent = button
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = tip
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = TOXIC
	s.Thickness = 2
	s.Parent = tip
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.Parent = tip
end

local readyAt = 0
local coolTotal = 1
local asked = 0
local tipShown = 0
local function inRoundNow(): (boolean, boolean)
	local z = player:GetAttribute("ZT_Z") == true
	local s = player:GetAttribute("ZT_S") == true
	return z or s, z
end
local function tryDash()
	local playing = inRoundNow()
	if not playing or not remote then
		return
	end
	local now = os.clock()
	if now < readyAt or now - asked < 0.4 then
		return
	end
	asked = now
	remote:FireServer("dash")
end
button.Activated:Connect(tryDash)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX then
		tryDash()
	end
end)

local function doDash(dir: Vector3, length: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local time = 0.22
	local speed = length / time
	local started = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - started >= time or not root.Parent then
			conn:Disconnect()
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.new(dir.X * 18, root.AssemblyLinearVelocity.Y, dir.Z * 18)
			end
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, math.max(root.AssemblyLinearVelocity.Y, 2), dir.Z * speed)
	end)
	sound(SND_WHOOSH, 0.7, 1.25)
	fovKick(14, 0.45)
	-- след из «призраков»: пара полупрозрачных копий позади
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 1.2, 0)
	att0.Parent = root
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -1.2, 0)
	att1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(TOXIC)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 0.8
	trail.Parent = root
	task.delay(0.8, function()
		trail:Destroy()
		att0:Destroy()
		att1:Destroy()
	end)
end

---------------------------------------------------------------------
-- СИГНАЛЫ СЕРВЕРА
---------------------------------------------------------------------
local lastHighlight: Highlight? = nil
local function clearLast()
	if lastHighlight then
		lastHighlight:Destroy()
		lastHighlight = nil
	end
end

local function listen(r: RemoteEvent)
	r.OnClientEvent:Connect(function(what: string, a: any, b: any, c: any, d: any)
		if what == "dash" then
			readyAt = os.clock() + (c or 8)
			coolTotal = c or 8
			doDash(a, b)
		elseif what == "catch" then
			local combo = tonumber(a) or 1
			doFlash(TOXIC, 0.55, 0.35)
			shake(2.2, 0.25)
			fovKick(-8, 0.3)
			stamp(t("fx_infected"), TOXIC, 0.58, 0.1, 0.9)
			if combo >= 2 then
				task.delay(0.12, function()
					stamp(t("fx_combo", combo), Color3.fromRGB(255, 210, 60), 0.67, 0.065, 1.1)
				end)
			end
			sound(SND_BASS, 0.8, 1.1 + math.min(combo, 5) * 0.08)
		elseif what == "last" then
			clearLast()
			local who = a :: Player?
			if who and who.Parent then
				if who == player then
					stamp(t("fx_last_me"), Color3.fromRGB(255, 120, 60), 0.32, 0.075, 2.6)
				else
					local character = who.Character
					if character then
						-- подсветка сквозь стены: видно, за кем все бегут
						local h = Instance.new("Highlight")
						h.Name = "ZT_LastSeen"
						h.Adornee = character
						h.FillTransparency = 1
						h.OutlineColor = Color3.fromRGB(255, 160, 40)
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Parent = playerGui
						lastHighlight = h
					end
				end
				sound(SND_BASS, 1, 0.7)
				shake(1.2, 0.4)
			end
		elseif what == "over" or what == "unlast" then
			clearLast()
		end
	end)
end
if remote then
	listen(remote)
else
	-- модуль Season запускается последним: ждём его сколько нужно, не останавливая остальные эффекты
	task.spawn(function()
		local r = RS:WaitForChild("ZT_Fx") :: RemoteEvent
		remote = r
		listen(r)
	end)
end

local finalOn = false -- идёт финальная охота (токсичная гамма включена)
-- превращение в зомби: короткая сцена
local wasSurvivor = player:GetAttribute("ZT_S") == true
local function onRoleChange()
	local z = player:GetAttribute("ZT_Z") == true
	local s = player:GetAttribute("ZT_S") == true
	if z and wasSurvivor then
		doFlash(Color3.fromRGB(40, 255, 40), 0.25, 1.2)
		cc.TintColor = Color3.fromRGB(150, 255, 140)
		cc.Saturation = -0.6
		cc.Contrast = 0.25
		if finalOn then
			grade({ TintColor = Color3.fromRGB(215, 255, 200), Saturation = 0.2, Contrast = 0.12 }, 1.6)
		else
			grade({ TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }, 1.6)
		end
		shake(3, 0.5)
		sound(SND_BASS, 1, 0.6)
		sound(SND_HIT, 0.6, 0.6)
		-- слова «тебя заразили» уже пишет игра (подсказка и экран охотника): здесь только картинка и звук
	end
	wasSurvivor = s
	if not z and not s then
		clearLast()
	end
end
player:GetAttributeChangedSignal("ZT_Z"):Connect(onRoleChange)
player:GetAttributeChangedSignal("ZT_S"):Connect(onRoleChange)

---------------------------------------------------------------------
-- ПОСТОЯННЫЙ ЦИКЛ: кнопка, стук сердца, финал
---------------------------------------------------------------------
local beatAt = 0
local trackHidden = false
local dangerLevel = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local playing, zombie = inRoundNow()
	-- кнопка умения
	button.Visible = playing
	if playing then
		caption.Text = if zombie then t("fx_lunge") else t("fx_dash")
		icon.Text = if zombie then "🧟" else "⚡"
		local left = readyAt - now
		if left > 0 then
			cool.Size = UDim2.fromScale(1, math.clamp(left / coolTotal, 0, 1))
			coolText.Text = tostring(math.ceil(left))
		else
			cool.Size = UDim2.fromScale(1, 0)
			coolText.Text = ""
		end
		if tipShown == 0 then
			tipShown = now
		end
		tip.Visible = now - tipShown < 7 and left <= 0
		tip.Text = if touch then t("fx_dash_tip_t") else t("fx_dash_tip")
	else
		tip.Visible = false
	end
	-- во время погони нижняя строка с заданиями и серией не нужна: экран чище (в лобби она снова видна)
	local track = hudRefs.Track
	if track and track.Parent then
		if playing and track.Visible then
			track.Visible = false
			trackHidden = true
		elseif not playing and trackHidden then
			track.Visible = true
			trackHidden = false
		end
	end
	-- мало выживших и ты среди них: сердце стучит
	local alive = workspace:GetAttribute("ZT_Alive")
	local target = 0
	if playing and not zombie and type(alive) == "number" then
		if alive <= 1 then
			target = 0.55
		elseif alive <= 3 then
			target = 0.3
		end
	end
	dangerLevel += (target - dangerLevel) * 0.05
	if target > 0 then
		local period = if alive <= 1 then 0.62 else 0.9
		if now >= beatAt then
			beatAt = now + period
			sound(SND_BASS, 0.35 + target * 0.5, 0.55)
			task.delay(0.16, function()
				sound(SND_BASS, 0.25 + target * 0.4, 0.5)
			end)
		end
		local pulse = 0.75 + 0.25 * math.sin(now * math.pi * 2 / period)
		edgeAlpha(redEdge, dangerLevel * pulse)
	else
		edgeAlpha(redEdge, dangerLevel)
	end
	-- финальная охота: токсичная гамма и зелёная рамка
	local final = workspace:GetAttribute("ZT_Final") == true and playing
	if final ~= finalOn then
		finalOn = final
		if final then
			grade({ TintColor = Color3.fromRGB(215, 255, 200), Saturation = 0.2, Contrast = 0.12 }, 1.5)
		else
			grade({ TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }, 1.5)
		end
	end
	edgeAlpha(greenEdge, if finalOn then 0.35 + 0.1 * math.sin(now * 3) else 0)
end)

---------------------------------------------------------------------
-- ИНТРО: пока камера летит над городом, лобби в небе не видно
---------------------------------------------------------------------
task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 20)
	if not map then
		return
	end
	local started = os.clock()
	local hidden = false
	local parts: { [BasePart]: number } = {}
	local boards: { LayerCollector } = {}
	-- лобби висит над центром города: прячем только то, что выше 120 и ближе 80 studs к центру
	-- (дальние башни на горизонте остаются)
	local function inSkyLobby(pos: Vector3): boolean
		return pos.Y > 120 and math.abs(pos.X) < 80 and math.abs(pos.Z) < 80
	end
	local function high(gui: Instance): boolean
		-- надпись висит на чём-то в небе (лобби, колесо, витрины)
		local target = if gui:IsA("BillboardGui") then (gui.Adornee or gui.Parent) elseif gui:IsA("SurfaceGui") then (gui.Adornee or gui.Parent) else nil
		return target ~= nil and target:IsA("BasePart") and inSkyLobby(target.Position)
	end
	local function setHidden(on: boolean)
		if on == hidden then
			return
		end
		hidden = on
		if on then
			table.clear(parts)
			table.clear(boards)
			local all = map:GetDescendants()
			local banner = workspace:FindFirstChild("ZT_SeasonBanner")
			if banner then
				table.insert(all, banner)
				for _, d in ipairs(banner:GetDescendants()) do
					table.insert(all, d)
				end
			end
			for _, d in ipairs(all) do
				if d:IsA("BasePart") and d.Transparency < 1 and inSkyLobby(d.Position) then
					parts[d] = d.Transparency
					d.Transparency = 1
				elseif (d:IsA("BillboardGui") or d:IsA("SurfaceGui")) and d.Enabled and high(d) then
					d.Enabled = false
					table.insert(boards, d)
				end
			end
			for _, d in ipairs(playerGui:GetChildren()) do
				if (d:IsA("BillboardGui") or d:IsA("SurfaceGui")) and d.Enabled and high(d) then
					d.Enabled = false
					table.insert(boards, d)
				end
			end
		else
			for part, was in pairs(parts) do
				if part.Parent then
					part.Transparency = was
				end
			end
			for _, board in ipairs(boards) do
				if board.Parent then
					board.Enabled = true
				end
			end
		end
	end
	-- прячем только пока идёт интро: камера летит по сценарию (Scriptable), а экран игры на это время выключен.
	-- Игрок в лобби всё видит
	while os.clock() - started < 25 do
		local hud = playerGui:FindFirstChild("ZombieTagHud") :: ScreenGui?
		local flying = workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable and hud ~= nil and not hud.Enabled
		setHidden(flying)
		task.wait(0.05)
	end
	setHidden(false)
end)

---------------------------------------------------------------------
-- ВЫВЕСКА СЕЗОНА В ЛОББИ: над названием игры, на языке игрока (видит только этот игрок)
---------------------------------------------------------------------
task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 30)
	local lobby = map and map:WaitForChild("Lobby", 30)
	local title = lobby and lobby:WaitForChild("TitleSign", 30) :: BasePart?
	if not title then
		return
	end
	local banner = Instance.new("Part")
	banner.Name = "ZT_SeasonBanner"
	banner.Anchored = true
	banner.CanCollide = false
	banner.CanQuery = false
	banner.CanTouch = false
	banner.CastShadow = false
	banner.Material = Enum.Material.SmoothPlastic
	banner.Color = PANEL
	banner.Size = Vector3.new(math.min(34, title.Size.X * 0.62), 2.4, 0.5)
	banner.CFrame = title.CFrame * CFrame.new(0, title.Size.Y / 2 + 1.7, 0)
	banner.Parent = workspace
	local frame = Instance.new("Part")
	frame.Name = "Glow"
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.CanTouch = false
	frame.CastShadow = false
	frame.Material = Enum.Material.Neon
	frame.Color = TOXIC
	frame.Size = banner.Size + Vector3.new(0.5, 0.5, -0.1)
	frame.CFrame = banner.CFrame
	frame.Parent = banner
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(banner.Size.X * 40, banner.Size.Y * 40)
		sg.LightInfluence = 0
		sg.Adornee = banner
		sg.Parent = banner
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextScaled = true
		label.TextColor3 = TOXIC
		label.Text = "☣ " .. t("fx_season") .. " ☣"
		label.Parent = sg
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(10, 30, 10)
		stroke.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.PaddingLeft = UDim.new(0.03, 0)
		pad.PaddingRight = UDim.new(0.03, 0)
		pad.Parent = label
		player:GetAttributeChangedSignal("ZT_Fx_fx_season"):Connect(function()
			label.Text = "☣ " .. t("fx_season") .. " ☣"
		end)
		-- размер текста считается, когда надпись уже на месте: пересчитываем через секунду
		task.delay(1, function()
			label.TextScaled = false
			label.TextScaled = true
		end)
	end
	-- неоновая рамка мягко «дышит»
	RunService.Heartbeat:Connect(function()
		frame.Transparency = if banner.Transparency >= 1 then 1 else 0.25 + 0.2 * math.sin(os.clock() * 2.2)
	end)
end)
