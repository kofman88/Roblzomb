--!strict
-- ZT_Analytics: economy and progression analytics for the Creator Dashboard (pipeline: "analytics from day one").
-- It does not touch the game: it watches leaderstats (Coins, Level, Wins) that the main script keeps up to date.
--  * every change of Coins -> LogEconomyEvent (Source/Sink, with a best guess of the reason)
--  * a new level -> LogProgressionEvent ("Level", Complete)
--  * a new win -> LogCustomEvent("RoundWin")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")

local CURRENCY = "Coins"
local T = Enum.AnalyticsEconomyTransactionType

local boughtAt: { [Player]: number } = {} -- a Robux purchase just finished: the next coin gain is IAP

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _: number, purchased: boolean)
	if purchased then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			boughtAt[player] = os.clock()
		end
	end
end)

local function inRound(player: Player): boolean
	return player:GetAttribute("ZT_S") == true or player:GetAttribute("ZT_Z") == true
end

local function log(f: () -> ())
	local ok, err = pcall(f)
	if not ok then
		warn("[ZT_Analytics] " .. tostring(err))
	end
end

local function watch(player: Player)
	local stats = player:WaitForChild("leaderstats", 60)
	if not stats then
		return
	end
	local coins = stats:WaitForChild("Coins", 30)
	local level = stats:WaitForChild("Level", 30)
	local wins = stats:WaitForChild("Wins", 30)
	-- the profile loads a moment after the stats appear: start counting once it settled
	task.wait(5)
	if not player.Parent then
		return
	end
	if coins and coins:IsA("IntValue") then
		local last = coins.Value
		coins.Changed:Connect(function(now: number)
			local delta = now - last
			last = now
			if delta == 0 then
				return
			end
			if delta > 0 then
				local kind = T.Gameplay.Name
				local sku = if inRound(player) then "round" else "lobby"
				if boughtAt[player] and os.clock() - boughtAt[player] < 30 then
					kind = T.IAP.Name
					sku = "coin_pack"
					boughtAt[player] = nil
				end
				log(function()
					AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, CURRENCY, delta, now, kind, sku)
				end)
			else
				log(function()
					AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, CURRENCY, -delta, now, T.Shop.Name, "shop")
				end)
			end
		end)
	end
	if level and level:IsA("IntValue") then
		local last = level.Value
		level.Changed:Connect(function(now: number)
			if now > last then
				for reached = last + 1, now do
					log(function()
						AnalyticsService:LogProgressionEvent(player, "Level", Enum.AnalyticsProgressionType.Complete, reached - 1, "Level " .. (reached - 1))
					end)
				end
			end
			last = now
		end)
	end
	if wins and wins:IsA("IntValue") then
		local last = wins.Value
		wins.Changed:Connect(function(now: number)
			if now > last then
				log(function()
					AnalyticsService:LogCustomEvent(player, "RoundWin", now - last)
				end)
			end
			last = now
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(watch, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watch, player)
end
Players.PlayerRemoving:Connect(function(player)
	boughtAt[player] = nil
end)
