--!strict
-- ЭКРАН ИГРОКА. Этот LocalScript лежит в StarterPlayer -> StarterPlayerScripts.
-- 1. Касание зомби: сервер видит игроков с задержкой связи, поэтому экран зомби-игрока сам сообщает
--    серверу, что догнал выжившего или жителя-бота. Сервер всё проверяет (модуль Extras, раздел "КАСАНИЕ").
-- 2. Батут подбрасывает своего персонажа сразу, без задержки связи.
-- 3. Зомби не видит кнопок у ящиков и шкафчиков: открыть их может только выживший.
-- 4. Первые минуты новичка (модуль Onboarding): интро-пролёт над городом, предупреждение "зомби рядом",
--    экран "Теперь ты охотник". Сервер кладёт тексты в атрибуты игрока, экран их показывает.
-- 5. Меню стройки у своей доски: кнопки на экране отправляют покупку на сервер (модуль Homes).
-- 6. Колесо удачи в лобби (модуль Luck): вращение, огоньки, щелчки, конфетти джекпота.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer

-- БАТУТ: такой же толчок вверх, как у сервера (сила записана на батуте)
local lastBounce = 0
local function bouncy(pad: Instance)
	if not pad:IsA("BasePart") or pad.Name ~= "Trampoline" then
		return
	end
	pad.Touched:Connect(function(hit: BasePart)
		local character = me.Character
		if not character or not hit:IsDescendantOf(character) then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local power = pad:GetAttribute("Power")
		local now = os.clock()
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or type(power) ~= "number" or now - lastBounce < 0.6 then
			return
		end
		lastBounce = now
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local push = Instance.new("LinearVelocity")
		push.Attachment0 = attachment
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		push.LineDirection = Vector3.new(0, 1, 0)
		push.LineVelocity = power
		push.MaxForce = 1000000
		push.Parent = root
		task.delay(0.15, function()
			push:Destroy()
			attachment:Destroy()
		end)
	end)
end
task.spawn(function()
	local map = workspace:WaitForChild("ZombieTagMap", 120)
	if not map then
		return
	end
	map.DescendantAdded:Connect(bouncy)
	for _, part in ipairs(map:GetDescendants()) do
		bouncy(part)
	end
end)

-- КНОПКИ ЯЩИКОВ И ШКАФЧИКОВ: у зомби они не видны (подойти можно, но нажать нечего)
local hidden: { [ProximityPrompt]: number } = {}
task.spawn(function()
	while true do
		task.wait(0.3)
		pcall(function()
			local zombie = me:GetAttribute("ZT_Z") == true
			local map = workspace:FindFirstChild("ZombieTagMap")
			local loot = if map then map:FindFirstChild("Loot") else nil
			if zombie and loot then
				for _, prompt in ipairs(loot:GetDescendants()) do
					if prompt:IsA("ProximityPrompt") and (prompt.Name == "SV_Open" or prompt.Name == "SV_Vaccine") and prompt.MaxActivationDistance > 0 then
						hidden[prompt] = prompt.MaxActivationDistance
						prompt.MaxActivationDistance = 0
					end
				end
			elseif not zombie and next(hidden) then
				for prompt, reach in pairs(hidden) do
					prompt.MaxActivationDistance = reach
				end
				table.clear(hidden)
			end
		end)
	end
end)

-- ЭКРАН НОВИЧКА
local TweenService = game:GetService("TweenService")
local over = Instance.new("ScreenGui")
over.Name = "ZT_Over"
over.IgnoreGuiInset = true
over.ResetOnSpawn = false
over.DisplayOrder = 50
over.Parent = me:WaitForChild("PlayerGui")
local function label(size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = textSize
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeColor3 = Color3.fromRGB(10, 20, 10)
	l.TextStrokeTransparency = 0
	l.TextWrapped = true
	l.Visible = false
	l.Parent = over
	return l
end
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Parent = over
local introLabel = label(UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.5, 0.5), 72, Color3.fromRGB(170, 255, 90))
local hunterLabel = label(UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.5, 0.42), 64, Color3.fromRGB(120, 255, 120))
local nearLabel = label(UDim2.fromScale(0.7, 0.09), UDim2.fromScale(0.5, 0.24), 48, Color3.fromRGB(255, 70, 70))
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
local function sound(id: string, volume: number)
	local s = Instance.new("Sound")
	setSound(s, id)
	s.Volume = volume
	s.Parent = over
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(8, function() if s.Parent then s:Destroy() end end)
end

-- тряска камеры (зомби рядом): короткая, затухающая
local shakeUntil = 0
RunService:BindToRenderStep("ZT_Shake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left > 0 then
		local k = math.min(1, left / 0.6) * 0.35
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end
end)

-- интро: пролёт над городом и три слова
local function intro(text: string)
	local cam = workspace.CurrentCamera
	local from = CFrame.lookAt(Vector3.new(-60, 70, 290), Vector3.new(0, 18, 40))
	local to = CFrame.lookAt(Vector3.new(50, 34, 120), Vector3.new(10, 12, 30))
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = from
	local hud = me.PlayerGui:FindFirstChild("ZombieTagHud")
	if hud then hud.Enabled = false end
	dim.BackgroundTransparency = 0
	TweenService:Create(dim, TweenInfo.new(0.8), { BackgroundTransparency = 0.25 }):Play()
	local move = TweenService:Create(cam, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = to })
	move:Play()
	-- слова появляются по одному
	local words = string.split(text, "   ")
	introLabel.Text = ""
	introLabel.TextTransparency = 0
	introLabel.Visible = true
	for i, word in ipairs(words) do
		introLabel.Text = table.concat(words, "   ", 1, i)
		sound("thud", 0.6)
		task.wait(1.4)
	end
	task.wait(0.8)
	TweenService:Create(introLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(dim, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.wait(0.6)
	introLabel.Visible = false
	cam.CameraType = Enum.CameraType.Custom
	if hud then hud.Enabled = true end
end
local function onIntro()
	local text = me:GetAttribute("ZT_Intro")
	if type(text) == "string" and text ~= "" then
		me:SetAttribute("ZT_Intro", "")
		task.spawn(function()
			pcall(intro, text)
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			local hud = me.PlayerGui:FindFirstChild("ZombieTagHud")
			if hud then hud.Enabled = true end
		end)
	end
end
me:GetAttributeChangedSignal("ZT_Intro"):Connect(onIntro)
onIntro()

-- "теперь ты охотник": две секунды на весь экран, зелёная вспышка
local function onHunt()
	local text = me:GetAttribute("ZT_Hunt")
	if type(text) ~= "string" or text == "" then
		return
	end
	me:SetAttribute("ZT_Hunt", "")
	task.spawn(function()
		dim.BackgroundColor3 = Color3.fromRGB(20, 80, 20)
		dim.BackgroundTransparency = 0.35
		TweenService:Create(dim, TweenInfo.new(2.2), { BackgroundTransparency = 1 }):Play()
		hunterLabel.Text = text
		hunterLabel.TextTransparency = 0
		hunterLabel.Size = UDim2.fromScale(0.5, 0.12)
		hunterLabel.Visible = true
		TweenService:Create(hunterLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.9, 0.22) }):Play()
		sound("hunt", 0.5)
		shakeUntil = os.clock() + 0.5
		task.wait(2.6)
		TweenService:Create(hunterLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.5)
		hunterLabel.Visible = false
		dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	end)
end
me:GetAttributeChangedSignal("ZT_Hunt"):Connect(onHunt)

-- "зомби рядом": пока я выживший, ближайший зомби ближе 40 шагов - тряска, рык и красная надпись (не чаще раза в 20 с)
local GROWLS = { "w_growl1", "w_growl2", "w_growl3" }
local nearShown = 0
task.spawn(function()
	while true do
		task.wait(0.25)
		pcall(function()
			local text = me:GetAttribute("ZT_NearText")
			if me:GetAttribute("ZT_S") ~= true or type(text) ~= "string" or os.clock() - nearShown < 20 then
				return
			end
			local character = me.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if not root or not root:IsA("BasePart") then
				return
			end
			local best = math.huge
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= me and other:GetAttribute("ZT_Z") == true and other.Character then
					local r = other.Character:FindFirstChild("HumanoidRootPart")
					if r and r:IsA("BasePart") then
						best = math.min(best, (r.Position - root.Position).Magnitude)
					end
				end
			end
			local map = workspace:FindFirstChild("ZombieTagMap")
			local bots = if map then map:FindFirstChild("Bots") else nil
			if bots then
				for _, bot in ipairs(bots:GetChildren()) do
					if bot.Name == "Zombie" then
						local r = bot:FindFirstChild("HumanoidRootPart")
						if r and r:IsA("BasePart") then
							best = math.min(best, (r.Position - root.Position).Magnitude)
						end
					end
				end
			end
			if best < 40 then
				nearShown = os.clock()
				shakeUntil = os.clock() + 0.6
				sound(GROWLS[math.random(1, #GROWLS)], 0.7)
				nearLabel.Text = text
				nearLabel.TextTransparency = 0
				nearLabel.Visible = true
				task.delay(1.6, function()
					TweenService:Create(nearLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
					task.delay(0.4, function() nearLabel.Visible = false end)
				end)
			end
		end)
	end
end)

-- МЕНЮ СТРОЙКИ: сервер кладёт в PlayerGui экран ZT_BuildMenu; нажатия на его кнопках уходят на сервер (ZT_Build)
task.spawn(function()
	local build = game:GetService("ReplicatedStorage"):WaitForChild("ZT_Build", 120)
	if not build or not build:IsA("RemoteEvent") then
		return
	end
	local lastPress = 0
	local function wire(gui: Instance)
		if gui.Name ~= "ZT_BuildMenu" then
			return
		end
		local function hook(button: Instance)
			if not button:IsA("TextButton") then
				return
			end
			local id = if button.Name == "Close" then "close" else string.match(button.Name, "^Buy_(.+)$")
			if not id then
				return
			end
			button.Activated:Connect(function()
				local now = os.clock()
				if now - lastPress < 0.3 then
					return
				end
				lastPress = now
				if id ~= "close" then
					-- кнопка слегка подпрыгивает: нажатие замечено
					local size = button.Size
					button.Size = UDim2.new(size.X.Scale, size.X.Offset - 6, size.Y.Scale, size.Y.Offset - 4)
					task.delay(0.08, function()
						button.Size = size
					end)
				end
				build:FireServer(id)
			end)
		end
		for _, d in ipairs(gui:GetDescendants()) do
			hook(d)
		end
		gui.DescendantAdded:Connect(hook)
	end
	local playerGui = me:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		wire(gui)
	end
	playerGui.ChildAdded:Connect(wire)
end)

-- КОДЫ (модуль Social): сервер кладёт в PlayerGui экран ZT_Codes; текст кода и крестик уходят на сервер (ZT_Code)
task.spawn(function()
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("ZT_Code", 120)
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end
	local function wire(gui: Instance)
		if gui.Name ~= "ZT_Codes" then
			return
		end
		local panel = gui:WaitForChild("Panel", 5)
		if not panel then
			return
		end
		local box = panel:WaitForChild("Input", 5)
		local go = panel:WaitForChild("Redeem", 5)
		local close = panel:WaitForChild("Close", 5)
		local function send()
			if box and box:IsA("TextBox") then
				remote:FireServer("code:" .. string.sub(box.Text, 1, 40))
			end
		end
		if go and go:IsA("TextButton") then
			go.Activated:Connect(send)
		end
		if box and box:IsA("TextBox") then
			box.FocusLost:Connect(function(enter: boolean)
				if enter then
					send()
				end
			end)
		end
		if close and close:IsA("TextButton") then
			close.Activated:Connect(function()
				remote:FireServer("close")
			end)
		end
	end
	local playerGui = me:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		task.spawn(wire, gui)
	end
	playerGui.ChildAdded:Connect(function(gui: Instance)
		task.spawn(wire, gui)
	end)
end)

-- КОЛЕСО УДАЧИ (модуль Luck): когда кто-то крутит, колесо крутится у всех; огоньки мигают, колышки щёлкают
task.spawn(function()
	local luck = game:GetService("ReplicatedStorage"):WaitForChild("ZT_Luck", 120)
	if not luck or not luck:IsA("RemoteEvent") then
		return
	end
	local tick = Instance.new("Sound")
	setSound(tick, "tick")
	tick.Volume = 0.35
	tick.Parent = over
	local fanfare = Instance.new("Sound")
	setSound(fanfare, "win")
	fanfare.Volume = 0.6
	fanfare.Parent = over
	local spinning = 0
	luck.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" or type(data.from) ~= "number" or type(data.to) ~= "number" or type(data.dur) ~= "number" then
			return
		end
		local map = workspace:FindFirstChild("ZombieTagMap")
		local root = map and map:FindFirstChild("Luck")
		local wheel = root and root:FindFirstChild("Wheel")
		local stand = root and root:FindFirstChild("Stand")
		if not wheel or not wheel:IsA("Model") then
			return
		end
		local axis = wheel:GetAttribute("Axis")
		local segments = wheel:GetAttribute("Segments")
		if typeof(axis) ~= "CFrame" or type(segments) ~= "number" then
			return
		end
		spinning += 1
		local mine = spinning
		local bulbs = {}
		if stand then
			for _, b in ipairs(stand:GetChildren()) do
				if b.Name == "Bulb" and b:IsA("BasePart") then
					table.insert(bulbs, { part = b, color = b.Color })
				end
			end
		end
		local seg = 2 * math.pi / segments
		local t0 = if type(data.t0) == "number" then data.t0 else workspace:GetServerTimeNow()
		local lastPeg = math.floor((data.from + seg / 2) / seg)
		local mineToo = data.who == me.UserId
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if mine ~= spinning or not wheel.Parent then
				conn:Disconnect()
				return
			end
			local x = math.clamp((workspace:GetServerTimeNow() - t0) / data.dur, 0, 1)
			-- быстро в начале, долго и медленно в конце: последние колышки щёлкают по одному
			local e = 1 - (1 - x) ^ 4
			local a = data.from + (data.to - data.from) * e
			wheel:PivotTo(axis * CFrame.Angles(0, 0, a))
			local peg = math.floor((a + seg / 2) / seg)
			if peg ~= lastPeg then
				lastPeg = peg
				if (wheel:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 70 then
					tick.PlaybackSpeed = 0.9 + 0.5 * (1 - x)
					tick:Play()
				end
			end
			local blink = math.floor(os.clock() * (if x < 1 then 8 else 3)) % 2
			for i, b in ipairs(bulbs) do
				b.part.Color = if (i + blink) % 2 == 0 then Color3.fromRGB(255, 240, 150) else b.color:Lerp(Color3.fromRGB(40, 20, 60), 0.6)
			end
			if x >= 1 then
				conn:Disconnect()
				for _, b in ipairs(bulbs) do
					b.part.Color = if data.jackpot then Color3.fromRGB(255, 210, 40) else b.color
				end
				if data.jackpot then
					local hub = wheel:FindFirstChild("Hub")
					local confetti = hub and hub:FindFirstChild("Confetti")
					if confetti and confetti:IsA("ParticleEmitter") then
						confetti:Emit(90)
					end
					if mineToo then
						fanfare:Play()
						shakeUntil = os.clock() + 0.6
					end
					task.delay(2.5, function()
						for _, b in ipairs(bulbs) do
							b.part.Color = b.color
						end
					end)
				end
			end
		end)
	end)
end)

-- КАСАНИЕ ЗОМБИ
local remote = game:GetService("ReplicatedStorage"):WaitForChild("ZT_Touch", 120)
if not remote or not remote:IsA("RemoteEvent") then
	return
end
local touch: RemoteEvent = remote
local REACH = 5.5 -- касание на экране: середины персонажей ближе этого
local sent: { [Instance]: number } = {}
local count = 0
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	if me:GetAttribute("ZT_Z") ~= true then
		return
	end
	local character = me.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local pos = root.Position
	local reach = REACH * math.max(1, character:GetScale())
	local now = os.clock()
	local function check(key: Instance, part: Instance?)
		if part and part:IsA("BasePart") and (part.Position - pos).Magnitude <= reach and now - (sent[key] or 0) > 0.25 then
			if not sent[key] then
				count += 1
				if count > 300 then
					table.clear(sent)
					count = 0
				end
			end
			sent[key] = now
			touch:FireServer(key)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= me and other:GetAttribute("ZT_S") == true and other.Character then
			check(other, other.Character:FindFirstChild("HumanoidRootPart"))
		end
	end
	local map = workspace:FindFirstChild("ZombieTagMap")
	local bots = if map then map:FindFirstChild("Bots") else nil
	if bots then
		for _, bot in ipairs(bots:GetChildren()) do
			if bot.Name == "Citizen" then
				check(bot, bot:FindFirstChild("HumanoidRootPart"))
			end
		end
	end
end)
