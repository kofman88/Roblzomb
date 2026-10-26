--!strict
--[[
	ZOMBLOCK  /  ЗОМБЛОК: ГОРОД ЗАРАЖЕНИЯ   (версия 11)

	КУДА ВСТАВИТЬ: Roblox Studio -> окно Explorer -> ServerScriptService
	-> нажми "+" -> Script -> удали всё внутри и вставь этот текст целиком.
	Затем наведи на этот Script, нажми "+" -> ModuleScript, назови его Texts
	и вставь в него текст из второго файла (тексты на 14 языках).
	Так же добавь ModuleScript с именем Extras и вставь в него третий файл.
	Больше ничего делать не нужно: скрипт сам строит город, лобби и магазин.

	ЧТО ЕСТЬ В ИГРЕ
	- Большой город с лестницами, батутами и люками; время суток меняется каждый раунд.
	- Боты: жители убегают, зомби ловят; играть можно и одному.
	- Прятки: зомби-боты не видят сквозь стены и кусты, в конце раунда - финальная охота.
	- На улицах монеты, ускорения и щиты; в конце раунда прилетает вертолёт.
	- События раунда, режим недели (каждый третий раунд, +50% монет), товар недели со скидкой.
	- Магазин в лобби, задания на день, уровни, таблица лучших, подарки за 7 и 14 дней подряд.
	- Подсказки и подарок новичку; монеты, задания и серия дней всегда на экране.
	- Синий пол у витрин - зона магазина: пока стоишь на нём, раунд идёт без тебя.
	- Прогресс сохраняется (после публикации игры). 14 языков.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------
-- НАСТРОЙКИ (эти числа можно менять)
---------------------------------------------------------------------
local GAME_TITLE = "ZOMBLOCK"     -- надпись на вывеске в лобби (название игры: Зомблок)

local BOT_FILL = 16               -- до скольки участников город дополняется ботами (0 - без ботов)
local SOLO_ZOMBIE_ROUNDS = true   -- одиночка через раунд сам играет за зомби
local INTERMISSION = 20           -- пауза в лобби между раундами (секунды)
local SOLO_INTERMISSION = 12      -- пауза, если игрок на сервере один (за это время телефон успевает загрузить игру)
local ROUND_TIME = 180            -- длина обычного раунда
local BOT_ROUND_TIME = 150        -- длина раунда с ботами
local HEAD_START = 6              -- сколько секунд зомби стоят в начале раунда

local SURVIVOR_SPEED = 16         -- скорость выживших
local ZOMBIE_SPEED = 17.5         -- скорость зомби-игроков
local BOT_SPEED = 14.5            -- скорость зомби-ботов
local BOT_PATROL_SPEED = 10       -- скорость зомби-ботов, пока они никого не видят и бродят по городу
local CITIZEN_SPEED = 14          -- скорость жителей-ботов, когда они убегают
local CITIZEN_SIGHT = 45          -- с какого расстояния житель замечает зомби-бота и начинает убегать
local CITIZEN_SIGHT_PLAYER = 30   -- с какого расстояния житель замечает зомби-игрока (к жителю можно подкрасться)
local BOOST_SPEED = 25            -- скорость под ускорением
local BOOST_TIME = 4              -- сколько секунд длится ускорение
local INFECT_DISTANCE = 5         -- на каком расстоянии зомби заражает

local MAX_BOTS = 16               -- максимум ботов в раунде
local BOT_LEAP_DELAY = 8          -- через сколько секунд бот запрыгивает на крышу за выжившим
local BOT_TURN_TIME = 2           -- сколько секунд пойманный житель превращается в зомби и стоит на месте

-- ПРЯТКИ: что замечают зомби-боты
local BOT_SIGHT = 70              -- как далеко видит зомби-бот (сквозь стены и кусты он не видит)
local BOT_HEARING = 16            -- бегущего выжившего бот слышит на таком расстоянии даже за стеной
local BOT_SMELL = 6               -- а того, кто стоит на месте, замечает только вплотную
local BOT_MEMORY = 6              -- сколько секунд бот помнит, где видел выжившего
local BOT_MEMORY_ROOF = 20        -- а того, кто залез наверх, помнит дольше: до него ещё надо добраться
local BOT_ROOF_CHECK = 0.2        -- как часто бродящий зомби-бот запрыгивает проверить крышу (0 - никогда, 1 - всегда)
local FINAL_HUNT_TIME = 25        -- за сколько секунд до конца раунда зомби-боты начинают чуять всех (0 - выключить)
local SHIELD_STUN = 2.5           -- на сколько секунд щит оглушает зомби
local HIDE_NAMES = true           -- скрывать имена над головами во время раунда
local SOUNDS = true               -- звуки и музыка (false - полная тишина)
local MUSIC_VOLUME = 1            -- громкость музыки: 0 - без музыки, 1 - обычная, 2 - вдвое громче

-- ВЕРТОЛЁТ И СОБЫТИЯ
local EVAC_TIME = 45              -- за сколько секунд до конца раунда прилетает вертолёт (0 - без вертолёта)
local EVAC_BOARD = 3              -- сколько секунд нужно простоять у вертолёта, чтобы улететь
local ROUND_EVENTS = 0.6          -- как часто в раунде бывает событие (0 - никогда, 1 - в каждом раунде)
local FORCE_EVENT = ""            -- для проверки: "fog", "dark", "gold", "rage", "giant" или "moon"

-- ЧЕСТНАЯ ИГРА И УДОБСТВО
local RULES = {
	zombieGap = 150,   -- зомби начинают раунд не ближе этого расстояния (в шагах) от выживших игроков
	infectStun = 1.5,  -- столько секунд только что заражённый игрок стоит на месте и никого не заражает
	playerReach = 6,   -- с какого расстояния заражает зомби-игрок (чуть больше, чем у бота: у игроков бывает задержка связи)
	antiCheat = true,  -- сервер возвращает назад тех, кто телепортируется, летает или бегает быстрее возможного
	pickupCap = 60,    -- больше стольких монет с улицы за один раунд не собрать
	readGap = 1.5,     -- сколько секунд надпись на экране держится, прежде чем её сменит следующая
	noteDelay = 7,     -- через сколько секунд после входа появляется надпись о ежедневной награде
	weekly = true,     -- режим недели и товар недели со скидкой
	gifts = true,      -- подарок новичку после первого раунда и призы за дни подряд
	eager = true,      -- новичка, который уже бегает по лобби, раунд забирает через 5 секунд
	week = "",         -- событие этой недели (игра вписывает его сама)
	pay = 1,           -- во сколько раз больше монет дают в этом раунде (игра вписывает сама)
}
-- ЗНАЧКИ. Создай значки на create.roblox.com (раздел Badges) и впиши сюда их номера. 0 - значок выключен.
local BADGES: { [string]: number } = {
	welcome = 0, -- сыграл первый раунд
	escape = 0,  -- улетел на вертолёте
	hunter = 0,  -- поймал 25 выживших
	wins10 = 0,  -- 10 побед
	level5 = 0,  -- 5-й уровень
}

-- МУЗЫКА И ЗВУКИ. Всё своё: музыка и звуки сгенерированы специально для ZOMBLOCK и загружены на наш аккаунт.
-- Все короткие звуки лежат в одном файле (zb_sfx_pack): у каждого звука свой кусок этого файла, см. SOUND_REGION.
local SFX_PACK = "rbxassetid://119377051797825"
local SOUND_FILES: { [string]: string } = {
	-- музыка (m_): играет каждому игроку своя
	m_lobby = "rbxassetid://73658686799079",   -- в лобби: "Infection Vector"
	m_hide = "rbxassetid://92910886797225",    -- в раунде, пока ты выживший: "Between the Ticks"
	m_hunt = "rbxassetid://83126643280020",    -- в раунде, пока ты зомби: "Velocity Protocol"
	m_finale = "rbxassetid://122733443114283",  -- конец раунда и вертолёт: "Until the Skies Break"
}
-- кусок файла SFX_PACK для каждого звука (секунды от и до). w_ - звуки в городе (их слышно только рядом), остальные слышит только сам игрок
local SOUND_REGION: { [string]: NumberRange } = {
	block = NumberRange.new(0.2600, 1.2600),
	boost = NumberRange.new(1.7400, 2.7400),
	buy = NumberRange.new(3.2200, 4.2200),
	catch = NumberRange.new(4.7000, 5.5002),
	coin = NumberRange.new(5.9802, 6.7002),
	daily = NumberRange.new(7.1802, 8.9630),
	deny = NumberRange.new(9.4430, 10.0430),
	evac = NumberRange.new(10.5230, 12.7918),
	hunt = NumberRange.new(13.2718, 15.6856),
	infected = NumberRange.new(16.1656, 18.4529),
	land = NumberRange.new(18.9329, 20.9518),
	levelup = NumberRange.new(21.4318, 23.3118),
	quest = NumberRange.new(23.7918, 25.2718),
	seat = NumberRange.new(25.7518, 26.5521),
	shield = NumberRange.new(27.0321, 28.2324),
	start = NumberRange.new(28.7124, 30.8324),
	tick = NumberRange.new(31.3124, 31.7483),
	w_boing = NumberRange.new(32.2283, 33.1145),
	w_growl1 = NumberRange.new(33.5945, 35.2847),
	w_growl2 = NumberRange.new(35.7647, 37.8847),
	w_growl3 = NumberRange.new(38.3647, 39.8441),
	w_heli = NumberRange.new(48.5641, 56.7641),
	w_steps = NumberRange.new(68.8641, 72.1641),
	w_whoosh = NumberRange.new(76.0241, 76.6877),
	win = NumberRange.new(77.1677, 80.2877),
}
for name in pairs(SOUND_REGION) do
	SOUND_FILES[name] = SFX_PACK
end
-- громкость отдельных звуков (у всех остальных 0.5)
local SOUND_LOUD: { [string]: number } = {
	m_lobby = 0.3, m_hide = 0.33, m_hunt = 0.24, m_finale = 0.3,
	w_heli = 1, w_growl1 = 0.9, w_growl2 = 0.9, w_growl3 = 0.9, w_whoosh = 0.7, w_boing = 0.6, w_steps = 0.9,
	win = 0.7, tick = 0.6, start = 0.6, hunt = 0.65, infected = 0.65, evac = 0.7, levelup = 0.65, land = 0.6,
}
-- в мелодии финала самый громкий момент кончается на этой секунде: игра подгадывает его к концу раунда
local FINALE_PEAK = 166
-- из записи вертолёта по кругу играет только этот ровный кусок (секунды от и до)
local HELI_LOOP = SOUND_REGION.w_heli

-- сколько монет за что дают
local COINS = {
	infect = 10,        -- зомби за каждого пойманного игрока
	infectBot = 5,      -- зомби за пойманного жителя-бота
	survive = 50,       -- выжившему в конце обычного раунда
	surviveBots = 30,   -- выжившему в раунде с ботами
	lastSurvivor = 25,  -- бонус последнему выжившему
	zombieWin = 15,     -- каждому зомби, если заразили всех
	zombieWinBots = 10, -- то же самое в раунде с ботами
	consolation = 5,    -- утешительный приз
	aliveTick = 2,      -- выжившему за каждые 10 секунд
	pickup = 3,         -- за монету на улице
	evac = 20,          -- бонус за побег на вертолёте
	streak = 2,         -- бонус зомби за серию поимок (умножается на длину серии)
	allQuests = 50,     -- бонус за все три задания дня
}
local DAILY_REWARD = 25           -- ежедневная награда (умножается на день подряд, но не больше чем на 7)
local FRIEND_BONUS = 0.2          -- +20% монет, если на сервере есть друг

-- МОНЕТИЗАЦИЯ. Пока стоит 0, эти функции выключены и платных витрин в лобби нет.
-- Создай Game Pass и Developer Products на create.roblox.com и впиши сюда их номера (id).
local VIP_GAMEPASS_ID = 2023034346         -- VIP: в 2 раза больше монет и золотая надпись VIP над головой
-- Наборы монет за Robux: id - номер Developer Product, coins - сколько монет он даёт.
local COIN_PRODUCTS: { { id: number, coins: number } } = {
	{ id = 3717387062, coins = 500 },
	{ id = 3717387093, coins = 1500 },
	{ id = 3717387126, coins = 5000 },
}

-- Для проверки: впиши "ru", "ja", "es" и т.д., и все надписи будут на этом языке.
-- Пустые кавычки - язык каждого игрока определяется сам.
local FORCE_LANGUAGE = ""

local SAVE_NAME = "ZombieTagSave_v1"

-- ПЛАН ГОРОДА. Каждая строка - ряд кварталов, каждая буква - один квартал:
-- T высотка, A переулки, L низкий дом, M магазин, C стройка, P парковка, K контейнеры, G парк,
-- S школа со стадионом, F заправка, W торговый центр, H больница, Y детская площадка.
-- Буквы можно менять местами, строки добавлять и убирать (строк и букв в строке должно быть поровну):
-- город перестроится при следующем запуске.
local CITY_PLAN = {
	"TTAMGTLKT",
	"TCLATHWGA",
	"ATGSATYTM",
	"LWTFTLATT",
	"MALTGTCKA",
	"KPTYLATST",
	"THATFTGAL",
	"ATLGAMTTP",
	"TKTATLCWG",
}

---------------------------------------------------------------------
-- ТЕКСТЫ НА РАЗНЫХ ЯЗЫКАХ
-- Сами тексты лежат в модуле Texts внутри этого скрипта (так скрипт не становится слишком длинным).
-- Язык выбирается сам по языку, который стоит у игрока в Roblox.
-- Если какой-то строки нет в языке игрока, показывается английская.
---------------------------------------------------------------------
local TEXT: { [string]: { [string]: string } } = (require :: any)(script:WaitForChild("Texts"))

---------------------------------------------------------------------
-- ТОВАРЫ МАГАЗИНА
---------------------------------------------------------------------
type ShopItem = {
	id: string,
	kind: string, -- "trail" или "skin"; название берётся из текстов: item_<id>
	price: number,
	colorA: Color3,
	colorB: Color3,
	level: number?, -- с какого уровня товар можно купить (если не указано - сразу)
	days: number?,  -- подарок: его нельзя купить, он выдаётся за столько дней игры подряд
	note: string?,  -- пометка у цены (товар недели)
}

-- level - с какого уровня товар можно купить. Так отмечены только три самых редких товара:
-- их нельзя просто купить за Robux, до них нужно доиграть.
local SHOP_ITEMS: { ShopItem } = {
	{ id = "trail_fire", kind = "trail", price = 100, colorA = Color3.fromRGB(255, 170, 40), colorB = Color3.fromRGB(255, 50, 30) },
	{ id = "trail_ice", kind = "trail", price = 100, colorA = Color3.fromRGB(120, 230, 255), colorB = Color3.fromRGB(255, 255, 255) },
	{ id = "trail_toxic", kind = "trail", price = 200, colorA = Color3.fromRGB(170, 255, 60), colorB = Color3.fromRGB(40, 160, 40) },
	{ id = "trail_royal", kind = "trail", price = 350, colorA = Color3.fromRGB(170, 90, 255), colorB = Color3.fromRGB(255, 120, 220) },
	{ id = "trail_gold", kind = "trail", price = 600, colorA = Color3.fromRGB(255, 215, 60), colorB = Color3.fromRGB(255, 250, 200) },
	{ id = "trail_ocean", kind = "trail", price = 900, colorA = Color3.fromRGB(40, 120, 255), colorB = Color3.fromRGB(120, 255, 230) },
	{ id = "trail_sunset", kind = "trail", price = 1200, colorA = Color3.fromRGB(255, 130, 60), colorB = Color3.fromRGB(255, 60, 160) },
	{ id = "trail_candy", kind = "trail", price = 1500, colorA = Color3.fromRGB(255, 150, 210), colorB = Color3.fromRGB(150, 230, 255) },
	{ id = "trail_ghost", kind = "trail", price = 2000, colorA = Color3.fromRGB(240, 240, 255), colorB = Color3.fromRGB(150, 160, 200) },
	{ id = "trail_lava", kind = "trail", price = 2500, colorA = Color3.fromRGB(255, 90, 20), colorB = Color3.fromRGB(120, 10, 0) },
	{ id = "trail_galaxy", kind = "trail", price = 3200, level = 11, colorA = Color3.fromRGB(90, 60, 255), colorB = Color3.fromRGB(255, 80, 220) },
	{ id = "trail_rainbow", kind = "trail", price = 4500, level = 14, colorA = Color3.fromRGB(255, 60, 60), colorB = Color3.fromRGB(150, 70, 255) }, -- радужный
	{ id = "trail_comet", kind = "trail", price = 0, days = 7, colorA = Color3.fromRGB(255, 255, 255), colorB = Color3.fromRGB(255, 200, 60) },
	{ id = "skin_crimson", kind = "skin", price = 150, colorA = Color3.fromRGB(220, 50, 50), colorB = Color3.fromRGB(90, 0, 0) },
	{ id = "skin_frost", kind = "skin", price = 250, colorA = Color3.fromRGB(110, 200, 255), colorB = Color3.fromRGB(0, 60, 120) },
	{ id = "skin_shadow", kind = "skin", price = 400, colorA = Color3.fromRGB(150, 70, 230), colorB = Color3.fromRGB(40, 0, 80) },
	{ id = "skin_gold", kind = "skin", price = 800, colorA = Color3.fromRGB(255, 205, 50), colorB = Color3.fromRGB(120, 80, 0) },
	{ id = "skin_neon", kind = "skin", price = 1200, colorA = Color3.fromRGB(255, 70, 200), colorB = Color3.fromRGB(110, 0, 80) },
	{ id = "skin_ghost", kind = "skin", price = 1800, colorA = Color3.fromRGB(235, 245, 255), colorB = Color3.fromRGB(120, 140, 170) },
	{ id = "skin_lava", kind = "skin", price = 2600, level = 10, colorA = Color3.fromRGB(255, 120, 30), colorB = Color3.fromRGB(140, 20, 0) },
	{ id = "skin_star", kind = "skin", price = 0, days = 14, colorA = Color3.fromRGB(255, 240, 150), colorB = Color3.fromRGB(255, 255, 255) },
}

local ITEM_BY_ID: { [string]: ShopItem } = {}
for _, item in ipairs(SHOP_ITEMS) do
	ITEM_BY_ID[item.id] = item
end

local DEFAULT_ZOMBIE_FILL = Color3.fromRGB(70, 210, 70)
local DEFAULT_ZOMBIE_OUTLINE = Color3.fromRGB(0, 90, 0)

---------------------------------------------------------------------
-- ТИПЫ И СОСТОЯНИЕ
---------------------------------------------------------------------
type Profile = {
	coins: number,
	wins: number,
	infections: number,
	owned: { [string]: boolean },
	trail: string,
	skin: string,
	lastDaily: number,                       -- когда выдана последняя ежедневная награда (в часах)
	streak: number,
	xp: number,                              -- опыт: от него зависит уровень
	questDay: number,                        -- день, на который выданы задания
	questProgress: { [string]: number },
	questDone: { [string]: boolean },
	musicOff: boolean,                       -- игрок выключил музыку у колонки в лобби
	rounds: number,                          -- сколько раундов сыграно (новичку первые раунды помогают подсказки)
	receipts: { string },                    -- номера последних покупок за Robux: одну покупку нельзя выдать дважды
	badges: { [string]: boolean },           -- какие значки уже выданы
}

type Session = {
	profile: Profile,
	canSave: boolean,
	vip: boolean,
	friendBoost: boolean,
	lang: string,
	boostUntil: number,
	shield: boolean,      -- подобран щит
	immuneUntil: number,  -- до этого времени нельзя заразить (сразу после щита)
	stunUntil: number,    -- до этого времени зомби оглушён щитом
	combo: number,        -- серия поимок подряд
	comboAt: number,
	boardStart: number,   -- когда выживший встал у вертолёта (0 - не стоит)
	boardShown: number,
	giant: boolean,       -- зомби-гигант (событие раунда)
	caught: number,       -- сколько выживших поймано в этом раунде
	picked: number,       -- сколько монет подобрано на улице в этом раунде
	leaving: boolean,     -- игрок выходит: последнее сохранение уже идёт
	lock: string,         -- метка этой игровой сессии в сохранении: писать прогресс может только её хозяин
	vipAsk: number,       -- когда сервер открыл этому игроку окно покупки VIP (0 - не открывал)
	pals: { [Player]: boolean }, -- друзья игрока на этом сервере
	day: number,          -- день заданий: не меняется, пока игрок не вышел
	bought: number?,      -- когда куплен последний товар
}

-- строка с надписью на экране: какая надпись в ней сейчас и когда появилась
type LineState = { token: number, key: string, since: number, queue: { { key: string, text: string } } }

type Hud = {
	gui: ScreenGui,
	status: TextLabel,
	role: TextLabel,
	event: TextLabel,
	big: TextLabel,
	toast: TextLabel,
	flash: Frame,
	itemLabels: { [string]: TextLabel }, -- подписи на витринах магазина
	questLabels: { TextLabel },          -- доска заданий в лобби
	sounds: { [string]: Sound },
	music: string,                       -- какая мелодия сейчас играет ("" - тишина)
	musicLabel: TextLabel?,              -- подпись на колонке в лобби
	vipLabel: TextLabel?,                -- подпись на витрине VIP
	hint: TextLabel,                     -- подсказка: что сейчас делать
	wallet: TextLabel,                   -- монеты и уровень
	toastState: LineState,
	bigState: LineState,
}

type Bot = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	alive: boolean,
	zombie: boolean, -- true: зомби, false: житель
	speed: number,
	stunUntil: number, -- до этого времени зомби стоит на месте (превращается или оглушён щитом)
	giant: boolean,
	track: AnimationTrack?, -- анимация бега
}

type LadderInfo = { bottom: Vector3, top: Vector3 }
type WorldLabel = { part: Part, kind: string, item: ShopItem?, coins: number? }
-- цена в Robux для подписи на платной витрине (Roblox сообщает её через секунду после запуска сервера)
local function robuxText(stand: Instance): string
	local price = stand:GetAttribute("Robux")
	return if type(price) == "number" then price .. " Robux" else "Robux"
end

type Pickup = {
	part: Part,
	kind: string, -- "coin", "boost" или "shield"
}

local sessions: { [Player]: Session } = {}
local huds: { [Player]: Hud } = {}

local roundActive = false
local roundId = 0
local roundEndsAt = 0
local botsFrozen = false
local finalHunt = false -- финальная охота: зомби-боты чуют всех
local roundEvent = ""   -- событие этого раунда ("" - обычный раунд)
-- вертолёт: его модель, площадка и те, кто уже улетел в этом раунде
local evac: { model: Model?, spot: Vector3?, saved: { [Player]: boolean } } = { model = nil, spot = nil, saved = {} }
local topLabels: { TextLabel } = {} -- таблица лидеров в лобби
local inRound: { [Player]: boolean } = {}
local isZombie: { [Player]: boolean } = {}
local bots: { Bot } = {}
local pickups: { Pickup } = {}

local statusKey = ""
local statusArgs: { any } = {}

local mapRng = Random.new(2026) -- одинаковое число = одинаковый город каждый раз
local gameRng = Random.new()

---------------------------------------------------------------------
-- ПОСТРОЙКА КАРТЫ
---------------------------------------------------------------------
local GROUND_TOP = 1
local SIDEWALK_TOP = 1.4
local BLOCK_SIZE = 44
local LOBBY_Y = 150

-- центры кварталов и дорог считаются сами по размеру плана города
local BLOCK_CENTERS: { number } = {}
local ROAD_CENTERS: { number } = {}
for index = 1, #CITY_PLAN do
	BLOCK_CENTERS[index] = (index - (#CITY_PLAN + 1) / 2) * 60
	if index < #CITY_PLAN then
		ROAD_CENTERS[index] = BLOCK_CENTERS[index] + 30
	end
end
local CITY_HALF = BLOCK_CENTERS[#CITY_PLAN] + 40
local RAIL_Z = ROAD_CENTERS[math.ceil(#ROAD_CENTERS / 2)] -- над этой улицей идёт надземная железная дорога

for _, object in ipairs(workspace:GetDescendants()) do
	if object:IsA("SpawnLocation") then
		object:Destroy()
	end
end
for _, oldName in ipairs({ "ZombieMap", "ZombieTagMap" }) do
	local old = workspace:FindFirstChild(oldName)
	if old then
		old:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "ZombieTagMap"

local city = Instance.new("Folder")
city.Name = "City"
city.Parent = map

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = map

local pickupFolder = Instance.new("Folder")
pickupFolder.Name = "Pickups"
pickupFolder.Parent = map

local botFolder = Instance.new("Folder")
botFolder.Name = "Bots"
botFolder.Parent = map

local hideFolder = Instance.new("Folder") -- кусты: сквозь них можно ходить, но не видно
hideFolder.Name = "Bushes"
hideFolder.Parent = map

-- Всё, что нужно только для постройки карты, спрятано в блок do ... end:
-- в Roblox у скрипта не может быть больше 200 переменных сразу, а так остаётся запас.
-- Наружу из блока выходит только то, что объявлено здесь.
local roofAnchors: { Vector3 } = {}    -- точки на крышах и площадках, куда бот может запрыгнуть
local ladders: { LadderInfo } = {}     -- все лестницы: низ и верх (чтобы боты умели по ним лазать)
local roadObstacles: { Vector3 } = {}  -- машины и заграждения на дорогах
local hideSpots: { Vector3 } = {}      -- укрытия: кусты, сараи, баки (зомби-боты иногда в них заглядывают)
local heliSpots: { Vector3 } = {}      -- площадки, куда в конце раунда может сесть вертолёт
local citySpawns: { Vector3 } = {}     -- перекрёстки: там появляются участники раунда
local worldLabels: { WorldLabel } = {} -- подписи, которые каждый игрок видит на своём языке
local lobbyCFrame = CFrame.new(0, LOBBY_Y + 4, 20) * CFrame.Angles(0, math.pi, 0) -- лицом к заданиям и таблице лидеров
local shopHandler: (player: Player, item: ShopItem) -> () = function() end
local vipHandler: (player: Player) -> () = function() end
local coinsHandler: (player: Player, productId: number) -> () = function() end
-- ЧЕСТНАЯ ИГРА И ЗНАЧКИ. Сами функции лежат в модуле Extras; без него игра работает, но без них.
local Guard = {
	allow = function(_player: Player, _target: Vector3?) end, -- сервер сам переносит игрока в точку target: это не нарушение
	ok = function(_player: Player): boolean -- можно ли сейчас верить положению игрока
		return true
	end,
	badges = function(_player: Player, _extra: string?) end,
	active = function(_player: Player): boolean -- двигался ли игрок в этом раунде
		return true
	end,
	eager = function(_: boolean?): boolean -- все ли на сервере новички (и бегают ли уже по лобби)
		return false
	end,
	hit = function(_: Player, _by: Player?, _bot: any): boolean -- модуль Survival: true - у выжившего вакцина, укус не подействовал
		return false
	end,
	fresh = function(_: Player): boolean -- модуль Onboarding: новичок входит в идущий раунд выжившим, а не зомби
		return false
	end,
	lure = function(_: Player): number -- модуль Onboarding: с какого расстояния зомби-боты слышат этого игрока (0 - как всех)
		return 0
	end,
	home = function(_: Vector3): boolean -- модуль Homes: точка на участке или в логове
		return false
	end,
	day = function(_: number): number -- модуль Homes: на сколько секунд продлить день
		return 0
	end,
	stay = function(_: Player): boolean -- модуль Homes: игрок дома, и ночь его пока не забирает
		return false
	end,
	seat = function(_: Player): boolean -- модуль Evac: досталось ли игроку место в вертолёте
		return true
	end,
	goal = function(_bot: any, _from: Vector3, goal: Vector3): Vector3 -- модуль Evac: куда бежит житель
		return goal
	end,
}
-- ЗВУК. Сами функции написаны ниже, после ботов; здесь только заготовка, чтобы ими могли
-- пользоваться батуты, люки и колонка в лобби, которые строятся раньше.
local Sfx = {
	finale = false, -- идёт ли конец раунда (играет музыка финала)
	emit = function(_part: BasePart, _name: string, _distance: number, _speed: number) end,
	toggle = function(_player: Player) end,
	label = function(_player: Player) end,
}
local surfaceText: (part: Part, lines: { string }, textColor: Color3, owner: Instance?) -> { TextLabel }
local addBillboard: (part: Part, text: string, height: number, owner: Instance) -> TextLabel
local setTimeOfDay: (index: number) -> ()
local applyVipTag: (player: Player) -> ()

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

do -- НАЧАЛО БЛОКА ПОСТРОЙКИ КАРТЫ

local props = Instance.new("Folder") -- мячи: их можно пинать
props.Name = "Props"
props.Parent = map

local function block(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function deco(part: Part): Part
	part.CanCollide = false
	part.CastShadow = false
	return part
end

-- наклонный пандус от точки bottom до точки top
local function ramp(parent: Instance, bottom: Vector3, top: Vector3, width: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = "Ramp"
	p.Anchored = true
	p.Size = Vector3.new(width, 1, (top - bottom).Magnitude)
	p.CFrame = CFrame.lookAt((bottom + top) / 2, top) * CFrame.new(0, -0.5, 0)
	p.Color = color
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	-- под пандусом, который стоит на земле, сплошная опора: иначе под ним застревают боты
	if bottom.Y <= SIDEWALK_TOP + 0.5 then
		local run = Vector3.new(top.X - bottom.X, 0, top.Z - bottom.Z)
		local length = run.Magnitude
		local rise = top.Y - bottom.Y
		local thickness = math.sqrt(length * length + rise * rise) / length -- толщина настила по вертикали
		local start = thickness * length / rise -- на каком расстоянии от начала настил отрывается от земли
		local center = bottom + run.Unit * ((start + length) / 2) + Vector3.new(0, (rise - thickness) / 2, 0)
		local support = Instance.new("WedgePart")
		support.Name = "RampSupport"
		support.Anchored = true
		support.Size = Vector3.new(width - 0.2, rise - thickness, length - start)
		support.CFrame = CFrame.lookAt(center, center - run.Unit) -- высокая сторона клина смотрит на верх пандуса
		support.Color = Color3.fromRGB(105, 108, 115)
		support.Material = Enum.Material.Concrete
		support.Parent = parent
	end
end

local C_ASPHALT = Color3.fromRGB(52, 54, 60)
local C_SIDEWALK = Color3.fromRGB(150, 150, 152)
local C_LINE = Color3.fromRGB(220, 200, 90)
local C_WALL = Color3.fromRGB(95, 98, 105)
local C_HAZARD = Color3.fromRGB(240, 200, 40)
local C_WINDOW_LIT = Color3.fromRGB(215, 175, 100)
local C_WINDOW_DARK = Color3.fromRGB(40, 55, 80)
local C_ROOF = Color3.fromRGB(45, 45, 50)
local C_GRASS = Color3.fromRGB(70, 130, 65)
local C_TRUNK = Color3.fromRGB(95, 65, 40)
local C_LEAVES = Color3.fromRGB(50, 120, 55)
local C_METAL = Color3.fromRGB(120, 125, 135)
local C_CRATE = Color3.fromRGB(165, 125, 75)

local BUILDING_COLORS = {
	Color3.fromRGB(130, 132, 140),
	Color3.fromRGB(150, 120, 100),
	Color3.fromRGB(110, 120, 140),
	Color3.fromRGB(160, 150, 135),
	Color3.fromRGB(125, 90, 85),
	Color3.fromRGB(100, 110, 105),
}
local CAR_COLORS = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(50, 100, 200),
	Color3.fromRGB(230, 230, 235),
	Color3.fromRGB(240, 190, 40),
	Color3.fromRGB(40, 45, 50),
}
local CONTAINER_COLORS = {
	Color3.fromRGB(170, 70, 50),
	Color3.fromRGB(50, 95, 150),
	Color3.fromRGB(60, 130, 90),
	Color3.fromRGB(190, 150, 50),
}

-- земля, разметка, стены
block(city, "Ground", Vector3.new(CITY_HALF * 2, 1, CITY_HALF * 2), Vector3.new(0, GROUND_TOP - 0.5, 0), C_ASPHALT, Enum.Material.Asphalt)

for _, c in ipairs(ROAD_CENTERS) do
	deco(block(city, "RoadLine", Vector3.new(CITY_HALF * 2 - 20, 0.1, 0.6), Vector3.new(0, GROUND_TOP + 0.03, c), C_LINE, Enum.Material.SmoothPlastic))
	deco(block(city, "RoadLine", Vector3.new(0.6, 0.1, CITY_HALF * 2 - 20), Vector3.new(c, GROUND_TOP + 0.03, 0), C_LINE, Enum.Material.SmoothPlastic))
end

do
	local wallLength = CITY_HALF * 2 + 8
	local wallHeight = 44
	local wallY = GROUND_TOP + wallHeight / 2 - 1
	local sides = {
		{ size = Vector3.new(wallLength, wallHeight, 4), pos = Vector3.new(0, wallY, CITY_HALF + 2), stripe = Vector3.new(wallLength, 2, 4.2) },
		{ size = Vector3.new(wallLength, wallHeight, 4), pos = Vector3.new(0, wallY, -CITY_HALF - 2), stripe = Vector3.new(wallLength, 2, 4.2) },
		{ size = Vector3.new(4, wallHeight, CITY_HALF * 2), pos = Vector3.new(CITY_HALF + 2, wallY, 0), stripe = Vector3.new(4.2, 2, CITY_HALF * 2) },
		{ size = Vector3.new(4, wallHeight, CITY_HALF * 2), pos = Vector3.new(-CITY_HALF - 2, wallY, 0), stripe = Vector3.new(4.2, 2, CITY_HALF * 2) },
	}
	for _, side in ipairs(sides) do
		block(city, "QuarantineWall", side.size, side.pos, C_WALL, Enum.Material.Concrete)
		deco(block(city, "WallStripe", side.stripe, Vector3.new(side.pos.X, GROUND_TOP + 6, side.pos.Z), C_HAZARD, Enum.Material.SmoothPlastic))
	end
end

-- надпись на обеих широких сторонах детали (вывески, таблички).
-- Если указан owner (PlayerGui игрока), надпись видит только этот игрок: так у каждого свой язык.
surfaceText = function(part: Part, lines: { string }, textColor: Color3, owner: Instance?): { TextLabel }
	local labels: { TextLabel } = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "ZombieTagLabel"
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(math.max(part.Size.X, part.Size.Z) * 20, part.Size.Y * 20)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = textColor
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextWrapped = true
		label.Text = table.concat(lines, "\n")
		label.Parent = gui
		table.insert(labels, label)
		if owner then
			gui.Adornee = part
			gui.ResetOnSpawn = false
			gui.Parent = owner
		else
			gui.Parent = part
		end
	end
	return labels
end

-- Куст. Сквозь него можно пройти, а того, кто стоит внутри, не видно.
local BUSH_COLORS = { C_LEAVES, Color3.fromRGB(62, 135, 60), Color3.fromRGB(44, 105, 52) }
local BUSH_BALLS = { { 0, 2.9, 0, 7.5 }, { 2.4, 2.2, 1.2, 5.5 }, { -2.2, 2.3, -1.4, 5.5 }, { 0.6, 2.1, -2.6, 5 } }

local function bush(x: number, z: number)
	for index, ball in ipairs(BUSH_BALLS) do
		local leaves = deco(block(
			hideFolder,
			"Bush",
			Vector3.new(ball[4], ball[4], ball[4]),
			Vector3.new(x + ball[1], SIDEWALK_TOP + ball[2], z + ball[3]),
			BUSH_COLORS[(index % #BUSH_COLORS) + 1],
			Enum.Material.Grass
		))
		leaves.Shape = Enum.PartType.Ball
	end
	table.insert(hideSpots, Vector3.new(x, SIDEWALK_TOP + 3, z))
end

-- Сарай с дверным проёмом: внутри можно спрятаться.
-- (dirX, dirZ) - в какую сторону смотрит вход: (1, 0), (-1, 0), (0, 1) или (0, -1).
local function shed(x: number, z: number, dirX: number, dirZ: number, color: Color3)
	local absX, absZ = math.abs(dirX), math.abs(dirZ)
	-- along: сдвиг в сторону входа; across: сдвиг поперёк; затем размеры детали в этих же направлениях
	local function piece(name: string, along: number, across: number, sizeAlong: number, sizeAcross: number, centerY: number, sizeY: number)
		block(
			city,
			name,
			Vector3.new(absX * sizeAlong + absZ * sizeAcross, sizeY, absZ * sizeAlong + absX * sizeAcross),
			Vector3.new(x + dirX * along + absZ * across, SIDEWALK_TOP + centerY, z + dirZ * along + absX * across),
			color,
			Enum.Material.Metal
		)
	end
	piece("ShedWall", -3.7, 0, 0.6, 10, 4, 8)
	piece("ShedWall", 0, -4.7, 6.8, 0.6, 4, 8)
	piece("ShedWall", 0, 4.7, 6.8, 0.6, 4, 8)
	piece("ShedWall", 3.7, -3.75, 0.6, 2.5, 4, 8)
	piece("ShedWall", 3.7, 3.75, 0.6, 2.5, 4, 8)
	piece("ShedWall", 3.7, 0, 0.6, 5, 7.25, 1.5)
	piece("ShedRoof", 0, 0, 8.6, 10.6, 8.25, 0.5)
	table.insert(hideSpots, Vector3.new(x, SIDEWALK_TOP + 3, z))
end

-- Мусорный бак без крышки: запрыгни внутрь, и с улицы тебя не видно.
local function dumpster(x: number, z: number, alongX: boolean)
	local color = Color3.fromRGB(45, 95, 70)
	local y = SIDEWALK_TOP + 2.1
	if alongX then
		block(city, "Dumpster", Vector3.new(9, 4.2, 0.5), Vector3.new(x, y, z - 2.75), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(9, 4.2, 0.5), Vector3.new(x, y, z + 2.75), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(0.5, 4.2, 5), Vector3.new(x - 4.25, y, z), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(0.5, 4.2, 5), Vector3.new(x + 4.25, y, z), color, Enum.Material.Metal)
	else
		block(city, "Dumpster", Vector3.new(0.5, 4.2, 9), Vector3.new(x - 2.75, y, z), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(0.5, 4.2, 9), Vector3.new(x + 2.75, y, z), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(5, 4.2, 0.5), Vector3.new(x, y, z - 4.25), color, Enum.Material.Metal)
		block(city, "Dumpster", Vector3.new(5, 4.2, 0.5), Vector3.new(x, y, z + 4.25), color, Enum.Material.Metal)
	end
	table.insert(hideSpots, Vector3.new(x, SIDEWALK_TOP + 3, z))
end

-- Батут: подбрасывает любого, кто на него наступит (и игроков, и ботов).
local lastBounce: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function trampoline(x: number, z: number, baseY: number, power: number)
	deco(block(city, "TrampolineRim", Vector3.new(7.4, 0.4, 7.4), Vector3.new(x, baseY + 0.2, z), C_ROOF, Enum.Material.Metal))
	local pad = block(city, "Trampoline", Vector3.new(6, 0.6, 6), Vector3.new(x, baseY + 0.3, z), Color3.fromRGB(255, 90, 170), Enum.Material.Neon)
	pad:SetAttribute("Power", power)
	pad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end
		local now = os.clock()
		if now - (lastBounce[character] or 0) < 0.6 then
			return
		end
		lastBounce[character] = now
		Sfx.emit(pad, "w_boing", 70, 1)
		if character:IsA("Model") and Players:GetPlayerFromCharacter(character) then
			return -- игрока подбрасывает его экран (скрипт ZT_Touch), без задержки связи
		end
		-- короткий толчок вверх
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

-- мяч, который можно пинать
local function ball(x: number, z: number, color: Color3)
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(3.5, 3.5, 3.5)
	part.Position = Vector3.new(x, SIDEWALK_TOP + 2, z)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props
end

-- Лестница. Персонажи Roblox сами лазают по таким решётчатым деталям.
-- (x, z) - где стоит лестница; baseY - откуда она начинается; height - её высота (чётное число);
-- (dirX, dirZ) - в какой стороне от лестницы находится площадка наверху.
local function ladder(x: number, z: number, baseY: number, height: number, dirX: number, dirZ: number)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.Position = Vector3.new(x, baseY + height / 2, z)
	truss.Color = C_HAZARD
	truss.Parent = city
	table.insert(ladders, {
		bottom = Vector3.new(x - dirX * 3, baseY, z - dirZ * 3),
		top = Vector3.new(x + dirX * 4, baseY + height, z + dirZ * 4),
	})
	-- подсказка для ботов: здесь можно подняться
	local low = Instance.new("Attachment")
	low.Position = Vector3.new(-dirX * 3, -height / 2, -dirZ * 3)
	low.Parent = truss
	local high = Instance.new("Attachment")
	high.Position = Vector3.new(dirX * 4, height / 2, dirZ * 4)
	high.Parent = truss
	local link = Instance.new("PathfindingLink")
	link.Attachment0 = low
	link.Attachment1 = high
	link.Label = "Climb"
	link.Parent = truss
end

local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
local SIGN_WORDS = { "HOTEL", "CINEMA", "PIZZA", "ARCADE", "CAFE", "24/7", "GYM", "MUSIC" }
local SIGN_COLORS = {
	Color3.fromRGB(255, 90, 170),
	Color3.fromRGB(90, 230, 255),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(150, 255, 110),
}

-- светящаяся вывеска на стене (стена смотрит в сторону +Z)
local function neonSign(x: number, y: number, z: number, text: string)
	local sign = deco(block(city, "NeonSign", Vector3.new(14, 4, 0.6), Vector3.new(x, y, z), Color3.fromRGB(20, 22, 28), Enum.Material.SmoothPlastic))
	surfaceText(sign, { text }, pick(SIGN_COLORS, mapRng))
end

-- простенки между окнами: без них окна выглядят сплошной полосой вокруг дома
local function facade(cx: number, cz: number, sizeX: number, sizeZ: number, height: number, color: Color3)
	local wall = Color3.new(color.R * 0.82, color.G * 0.82, color.B * 0.82)
	local centerY = SIDEWALK_TOP + height / 2
	local countX = math.max(2, math.floor(sizeX / 7 + 0.5))
	for i = 0, countX do
		local x = cx - sizeX / 2 + sizeX * i / countX
		deco(block(city, "Pilaster", Vector3.new(1.8, height, 0.6), Vector3.new(x, centerY, cz - sizeZ / 2 - 0.1), wall, Enum.Material.Concrete))
		deco(block(city, "Pilaster", Vector3.new(1.8, height, 0.6), Vector3.new(x, centerY, cz + sizeZ / 2 + 0.1), wall, Enum.Material.Concrete))
	end
	local countZ = math.max(2, math.floor(sizeZ / 7 + 0.5))
	for i = 1, countZ - 1 do
		local z = cz - sizeZ / 2 + sizeZ * i / countZ
		deco(block(city, "Pilaster", Vector3.new(0.6, height, 1.8), Vector3.new(cx - sizeX / 2 - 0.1, centerY, z), wall, Enum.Material.Concrete))
		deco(block(city, "Pilaster", Vector3.new(0.6, height, 1.8), Vector3.new(cx + sizeX / 2 + 0.1, centerY, z), wall, Enum.Material.Concrete))
	end
end

-- высотка: на крышу ведёт лестница, если дом не слишком высокий
type Tower = { x: number, z: number, width: number, height: number }
local towers: { [number]: Tower } = {}

local function buildTower(cx: number, cz: number): Tower
	local width = mapRng:NextInteger(15, 19) * 2
	local height = mapRng:NextInteger(3, 6) * 10
	local roofY = SIDEWALK_TOP + height
	local color = pick(BUILDING_COLORS, mapRng)
	local material = if mapRng:NextNumber() < 0.5 then Enum.Material.Concrete else Enum.Material.Brick
	block(city, "Tower", Vector3.new(width, height, width), Vector3.new(cx, SIDEWALK_TOP + height / 2, cz), color, material)
	for y = 8, height - 4, 10 do
		local lit = mapRng:NextNumber() < 0.4
		deco(block(
			city,
			"Windows",
			Vector3.new(width + 0.3, 3, width + 0.3),
			Vector3.new(cx, SIDEWALK_TOP + y, cz),
			if lit then C_WINDOW_LIT else C_WINDOW_DARK,
			if lit then Enum.Material.Neon else Enum.Material.Glass
		))
	end
	deco(block(city, "RoofTrim", Vector3.new(width + 1, 1, width + 1), Vector3.new(cx, roofY - 0.5, cz), C_ROOF, Enum.Material.Metal))
	facade(cx, cz, width, width, height, color)
	if height <= 50 then
		ladder(cx + width / 2 + 1, cz + 8, SIDEWALK_TOP, height, -1, 0)
	end
	if height <= 40 then
		table.insert(heliSpots, Vector3.new(cx - 1, roofY, cz)) -- на невысокую крышу может сесть вертолёт
	end
	-- укрытия на крыше
	block(city, "RoofBox", Vector3.new(5, 3, 5), Vector3.new(cx - 6, roofY + 1.5, cz + 5), C_METAL, Enum.Material.Metal)
	block(city, "RoofBox", Vector3.new(4, 4, 8), Vector3.new(cx + 5, roofY + 2, cz - 7), C_ROOF, Enum.Material.Metal)
	table.insert(roofAnchors, Vector3.new(cx - width / 2 + 4, roofY, cz - width / 2 + 4))
	table.insert(roofAnchors, Vector3.new(cx + width / 2 - 4, roofY, cz + width / 2 - 4))
	if mapRng:NextNumber() < 0.6 then
		neonSign(cx, SIDEWALK_TOP + height * 0.55, cz + width / 2 + 0.4, pick(SIGN_WORDS, mapRng))
	end
	bush(cx + 19.5, cz - 19.5)
	bush(cx - 19.5, cz + 19.5)
	return { x = cx, z = cz, width = width, height = height }
end

-- низкий дом: на крышу ведут пандус и лестница
local function buildLowHouse(cx: number, cz: number)
	local width = 28
	local height = 12
	local bx = cx - 4
	local roofY = SIDEWALK_TOP + height
	local color = pick(BUILDING_COLORS, mapRng)
	block(city, "LowHouse", Vector3.new(width, height, width), Vector3.new(bx, SIDEWALK_TOP + height / 2, cz), color, Enum.Material.Brick)
	deco(block(city, "Windows", Vector3.new(width + 0.3, 3, width + 0.3), Vector3.new(bx, SIDEWALK_TOP + 6, cz), C_WINDOW_LIT, Enum.Material.Neon))
	facade(bx, cz, width, width, height, color)
	local rampX = bx + width / 2 + 3
	ramp(city, Vector3.new(rampX, SIDEWALK_TOP, cz - 14), Vector3.new(rampX, roofY, cz + 6), 6, C_METAL)
	block(city, "Landing", Vector3.new(6, 1, 8), Vector3.new(rampX, roofY - 0.5, cz + 10), C_METAL, Enum.Material.Metal)
	ladder(bx - width / 2 - 1, cz + 6, SIDEWALK_TOP, height, 1, 0)
	-- укрытия на крыше
	block(city, "RoofBox", Vector3.new(6, 4, 6), Vector3.new(bx - 6, roofY + 2, cz - 6), C_METAL, Enum.Material.Metal)
	block(city, "RoofBox", Vector3.new(4, 3, 8), Vector3.new(bx + 5, roofY + 1.5, cz + 7), C_ROOF, Enum.Material.Metal)
	table.insert(roofAnchors, Vector3.new(bx - 11, roofY, cz + 11))
	table.insert(roofAnchors, Vector3.new(bx + 11, roofY, cz - 11))
	dumpster(cx - 6, cz - 18, true)
	bush(cx + 19, cz + 19)
end

-- квартал с переулками: четыре дома, между крышами мостики
local function buildAlleys(cx: number, cz: number)
	local height = mapRng:NextInteger(7, 13) * 2
	local roofY = SIDEWALK_TOP + height
	for _, corner in ipairs(CORNERS) do
		local x = cx + corner[1] * 11.5
		local z = cz + corner[2] * 11.5
		local color = pick(BUILDING_COLORS, mapRng)
		block(city, "House", Vector3.new(17, height, 17), Vector3.new(x, SIDEWALK_TOP + height / 2, z), color, Enum.Material.Brick)
		facade(x, z, 17, 17, height, color)
		local lit = mapRng:NextNumber() < 0.6
		deco(block(
			city,
			"Windows",
			Vector3.new(17.3, 3, 17.3),
			Vector3.new(x, roofY - 6, z),
			if lit then C_WINDOW_LIT else C_WINDOW_DARK,
			if lit then Enum.Material.Neon else Enum.Material.Glass
		))
	end
	block(city, "Plank", Vector3.new(9, 0.5, 4), Vector3.new(cx, roofY + 0.25, cz - 11.5), C_CRATE, Enum.Material.WoodPlanks)
	block(city, "Plank", Vector3.new(4, 0.5, 9), Vector3.new(cx + 11.5, roofY + 0.25, cz), C_CRATE, Enum.Material.WoodPlanks)
	block(city, "Plank", Vector3.new(9, 0.5, 4), Vector3.new(cx, roofY + 0.25, cz + 11.5), C_CRATE, Enum.Material.WoodPlanks)
	ladder(cx + 21, cz + 11.5, SIDEWALK_TOP, height, -1, 0)
	table.insert(roofAnchors, Vector3.new(cx - 11.5, roofY, cz + 11.5))
	table.insert(roofAnchors, Vector3.new(cx + 11.5, roofY, cz - 11.5))
	neonSign(cx - 11.5, SIDEWALK_TOP + height * 0.6, cz + 20.4, pick(SIGN_WORDS, mapRng))
	bush(cx, cz) -- куст на перекрёстке переулков
end

-- стройка: два этажа на колоннах и кран, на который можно залезть
local function buildConstruction(cx: number, cz: number)
	local floor1 = SIDEWALK_TOP + 12
	local floor2 = SIDEWALK_TOP + 24
	local craneTop = SIDEWALK_TOP + 44
	local concrete = Color3.fromRGB(165, 165, 160)
	block(city, "Slab", Vector3.new(30, 1, 30), Vector3.new(cx - 3, floor1 - 0.5, cz), concrete, Enum.Material.Concrete)
	block(city, "Slab", Vector3.new(20, 1, 20), Vector3.new(cx - 6, floor2 - 0.5, cz - 3), concrete, Enum.Material.Concrete)
	for _, corner in ipairs(CORNERS) do
		block(city, "Column", Vector3.new(2, 11, 2), Vector3.new(cx - 3 + corner[1] * 12, SIDEWALK_TOP + 5.5, cz + corner[2] * 12), concrete, Enum.Material.Concrete)
		block(city, "Column", Vector3.new(2, 11, 2), Vector3.new(cx - 6 + corner[1] * 8, floor1 + 5.5, cz - 3 + corner[2] * 8), concrete, Enum.Material.Concrete)
	end
	ramp(city, Vector3.new(cx + 15, SIDEWALK_TOP, cz - 14), Vector3.new(cx + 15, floor1, cz + 6), 6, C_METAL)
	block(city, "Landing", Vector3.new(6, 1, 8), Vector3.new(cx + 15, floor1 - 0.5, cz + 10), C_METAL, Enum.Material.Metal)
	ladder(cx + 5, cz - 3, floor1, 12, -1, 0)
	-- кран
	ladder(cx - 16, cz + 19, SIDEWALK_TOP, 44, 1, 0)
	block(city, "CraneCabin", Vector3.new(8, 1, 8), Vector3.new(cx - 11, craneTop - 0.5, cz + 18), C_HAZARD, Enum.Material.Metal)
	deco(block(city, "CraneArm", Vector3.new(44, 1.5, 1.5), Vector3.new(cx, craneTop + 3, cz + 19), C_HAZARD, Enum.Material.Metal))
	deco(block(city, "CraneCable", Vector3.new(0.4, 14, 0.4), Vector3.new(cx + 16, craneTop - 4.7, cz + 19), C_ROOF, Enum.Material.Metal))
	deco(block(city, "CraneLoad", Vector3.new(4, 4, 4), Vector3.new(cx + 16, craneTop - 13.7, cz + 19), C_CRATE, Enum.Material.WoodPlanks))
	block(city, "Crate", Vector3.new(5, 4, 5), Vector3.new(cx + 17, SIDEWALK_TOP + 2, cz + 18), C_CRATE, Enum.Material.WoodPlanks)
	table.insert(roofAnchors, Vector3.new(cx - 12, floor1, cz + 10))
	table.insert(roofAnchors, Vector3.new(cx - 6, floor2, cz + 2))
	table.insert(roofAnchors, Vector3.new(cx - 11, craneTop, cz + 18))
	shed(cx - 3, cz + 2, 0, -1, Color3.fromRGB(70, 110, 160)) -- бытовка под перекрытием
	bush(cx - 19.5, cz - 8)
end

-- магазин с навесом: на крышу ведут пандус и лестница
local function buildMarket(cx: number, cz: number)
	local roofY = SIDEWALK_TOP + 10
	local color = pick(BUILDING_COLORS, mapRng)
	block(city, "Shop", Vector3.new(16, 10, 20), Vector3.new(cx - 12, SIDEWALK_TOP + 5, cz), color, Enum.Material.Brick)
	facade(cx - 12, cz, 16, 20, 10, color)
	deco(block(city, "Windows", Vector3.new(16.3, 4, 20.3), Vector3.new(cx - 12, SIDEWALK_TOP + 4, cz), C_WINDOW_LIT, Enum.Material.Neon))
	block(city, "Canopy", Vector3.new(24, 1, 28), Vector3.new(cx + 8, roofY - 0.5, cz), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	for _, spot in ipairs({ { 1, -11 }, { 1, 11 }, { 17, -11 }, { 17, 11 } }) do
		block(city, "Pillar", Vector3.new(1.5, 9, 1.5), Vector3.new(cx + spot[1], SIDEWALK_TOP + 4.5, cz + spot[2]), C_METAL, Enum.Material.Metal)
	end
	block(city, "Stall", Vector3.new(3, 4, 6), Vector3.new(cx + 9, SIDEWALK_TOP + 2, cz - 5), C_CRATE, Enum.Material.WoodPlanks)
	block(city, "Stall", Vector3.new(3, 4, 6), Vector3.new(cx + 9, SIDEWALK_TOP + 2, cz + 6), C_CRATE, Enum.Material.WoodPlanks)
	ramp(city, Vector3.new(cx - 2, SIDEWALK_TOP, cz - 13), Vector3.new(cx - 16, roofY, cz - 13), 6, C_METAL)
	block(city, "Landing", Vector3.new(6, 1, 6), Vector3.new(cx - 19, roofY - 0.5, cz - 13), C_METAL, Enum.Material.Metal)
	ladder(cx + 21, cz + 6, SIDEWALK_TOP, 10, -1, 0)
	table.insert(roofAnchors, Vector3.new(cx - 12, roofY, cz + 6))
	table.insert(roofAnchors, Vector3.new(cx + 14, roofY, cz - 10))
	neonSign(cx - 12, SIDEWALK_TOP + 7.5, cz + 10.4, "MARKET")
	dumpster(cx - 12, cz + 15, true)
	bush(cx + 19, cz - 19)
end

-- машина и автобус; alongX = true, если стоят вдоль оси X
local function car(x: number, z: number, baseY: number, alongX: boolean)
	local color = pick(CAR_COLORS, mapRng)
	block(city, "CarBody", if alongX then Vector3.new(11, 2.2, 5.5) else Vector3.new(5.5, 2.2, 11), Vector3.new(x, baseY + 1.6, z), color, Enum.Material.SmoothPlastic)
	block(city, "CarCabin", if alongX then Vector3.new(5.5, 1.8, 5) else Vector3.new(5, 1.8, 5.5), Vector3.new(x, baseY + 3.6, z), C_WINDOW_DARK, Enum.Material.Glass)
	deco(block(city, "CarWheels", if alongX then Vector3.new(8.5, 1.2, 5.9) else Vector3.new(5.9, 1.2, 8.5), Vector3.new(x, baseY + 0.6, z), C_ROOF, Enum.Material.SmoothPlastic))
end

local function bus(x: number, z: number, baseY: number, alongX: boolean)
	block(city, "Bus", if alongX then Vector3.new(24, 7, 6.5) else Vector3.new(6.5, 7, 24), Vector3.new(x, baseY + 4.2, z), Color3.fromRGB(235, 185, 40), Enum.Material.SmoothPlastic)
	deco(block(city, "BusWindows", if alongX then Vector3.new(22, 2.2, 6.8) else Vector3.new(6.8, 2.2, 22), Vector3.new(x, baseY + 5.6, z), C_WINDOW_DARK, Enum.Material.Glass))
	deco(block(city, "BusWheels", if alongX then Vector3.new(18, 1.4, 6.9) else Vector3.new(6.9, 1.4, 18), Vector3.new(x, baseY + 0.7, z), C_ROOF, Enum.Material.SmoothPlastic))
end

-- парковка: с машины можно запрыгнуть на автобус
local function buildParking(cx: number, cz: number)
	car(cx - 12, cz + mapRng:NextInteger(-8, 8), SIDEWALK_TOP, false)
	car(cx, cz + mapRng:NextInteger(-4, 4), SIDEWALK_TOP, false)
	bus(cx + 13, cz, SIDEWALK_TOP, false)
	table.insert(roofAnchors, Vector3.new(cx + 13, SIDEWALK_TOP + 7.7, cz + 8))
	dumpster(cx - 6, cz - 18.5, true)
	bush(cx - 19, cz + 19)
	bush(cx + 19.5, cz - 19)
end

-- площадка с контейнерами (по ящикам можно залезть наверх)
local function buildContainers(cx: number, cz: number)
	block(city, "Container", Vector3.new(8, 8, 20), Vector3.new(cx - 9, SIDEWALK_TOP + 4, cz), pick(CONTAINER_COLORS, mapRng), Enum.Material.Metal)
	block(city, "Container", Vector3.new(8, 8, 20), Vector3.new(cx + 1, SIDEWALK_TOP + 4, cz), pick(CONTAINER_COLORS, mapRng), Enum.Material.Metal)
	block(city, "Container", Vector3.new(20, 8, 8), Vector3.new(cx - 4, SIDEWALK_TOP + 12, cz - 4), pick(CONTAINER_COLORS, mapRng), Enum.Material.Metal)
	block(city, "Crate", Vector3.new(5, 4, 5), Vector3.new(cx + 8, SIDEWALK_TOP + 2, cz + 6), C_CRATE, Enum.Material.WoodPlanks)
	block(city, "Crate", Vector3.new(4, 4, 4), Vector3.new(cx + 13, SIDEWALK_TOP + 2, cz - 8), C_CRATE, Enum.Material.WoodPlanks)
	table.insert(roofAnchors, Vector3.new(cx - 9, SIDEWALK_TOP + 8, cz + 6))
	shed(cx + 15, cz + 14, 0, -1, CONTAINER_COLORS[2]) -- открытый контейнер
	bush(cx - 17, cz + 17)
end

-- школа со стадионом: по трибунам, как по ступеням, можно забраться на крышу
local function buildSchool(cx: number, cz: number)
	local height = 14
	local roofY = SIDEWALK_TOP + height
	local color = Color3.fromRGB(190, 150, 105)
	block(city, "School", Vector3.new(40, height, 14), Vector3.new(cx, SIDEWALK_TOP + height / 2, cz - 13), color, Enum.Material.Brick)
	deco(block(city, "Windows", Vector3.new(40.3, 3, 14.3), Vector3.new(cx, SIDEWALK_TOP + 4.5, cz - 13), C_WINDOW_LIT, Enum.Material.Neon))
	deco(block(city, "Windows", Vector3.new(40.3, 3, 14.3), Vector3.new(cx, SIDEWALK_TOP + 10.5, cz - 13), C_WINDOW_DARK, Enum.Material.Glass))
	facade(cx, cz - 13, 40, 14, height, color)
	for step = 1, 3 do
		block(city, "Bleachers", Vector3.new(16, step * 3, 4), Vector3.new(cx, SIDEWALK_TOP + step * 1.5, cz + 8 - step * 4), C_METAL, Enum.Material.Metal)
	end
	ladder(cx + 21, cz - 13, SIDEWALK_TOP, height, -1, 0)
	block(city, "RoofBox", Vector3.new(5, 3, 5), Vector3.new(cx - 12, roofY + 1.5, cz - 13), C_ROOF, Enum.Material.Metal)
	-- футбольное поле с воротами
	deco(block(city, "Grass", Vector3.new(40, 0.2, 15), Vector3.new(cx, SIDEWALK_TOP + 0.1, cz + 14), C_GRASS, Enum.Material.Grass))
	deco(block(city, "FieldLine", Vector3.new(0.5, 0.1, 15), Vector3.new(cx, SIDEWALK_TOP + 0.25, cz + 14), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic))
	for _, side in ipairs({ -1, 1 }) do
		local x = cx + side * 19
		deco(block(city, "Goal", Vector3.new(0.6, 5, 0.6), Vector3.new(x, SIDEWALK_TOP + 2.5, cz + 10.5), Color3.fromRGB(240, 240, 240), Enum.Material.Metal))
		deco(block(city, "Goal", Vector3.new(0.6, 5, 0.6), Vector3.new(x, SIDEWALK_TOP + 2.5, cz + 17.5), Color3.fromRGB(240, 240, 240), Enum.Material.Metal))
		deco(block(city, "Goal", Vector3.new(0.6, 0.6, 7.6), Vector3.new(x, SIDEWALK_TOP + 5.3, cz + 14), Color3.fromRGB(240, 240, 240), Enum.Material.Metal))
	end
	ball(cx + 4, cz + 14, Color3.fromRGB(245, 245, 245))
	bush(cx - 14, cz + 20.5)
	bush(cx + 14, cz + 20.5)
	table.insert(roofAnchors, Vector3.new(cx - 4, roofY, cz - 13))
	table.insert(roofAnchors, Vector3.new(cx + 14, roofY, cz - 13))
	table.insert(roofAnchors, Vector3.new(cx, SIDEWALK_TOP + 9, cz - 4))
	table.insert(heliSpots, Vector3.new(cx - 6, SIDEWALK_TOP, cz + 14))
	neonSign(cx, SIDEWALK_TOP + 11.5, cz - 5.6, "SCHOOL")
end

-- заправка: навес с колонками, магазин, бензовоз и мойка-туннель, где можно спрятаться
local function buildGas(cx: number, cz: number)
	local roofY = SIDEWALK_TOP + 10
	local color = Color3.fromRGB(215, 215, 220)
	block(city, "GasShop", Vector3.new(16, 10, 14), Vector3.new(cx - 12, SIDEWALK_TOP + 5, cz - 13), color, Enum.Material.Concrete)
	deco(block(city, "Windows", Vector3.new(16.3, 3.5, 14.3), Vector3.new(cx - 12, SIDEWALK_TOP + 4.5, cz - 13), C_WINDOW_LIT, Enum.Material.Neon))
	facade(cx - 12, cz - 13, 16, 14, 10, color)
	ladder(cx - 12, cz - 5, SIDEWALK_TOP, 10, 0, -1)
	block(city, "Canopy", Vector3.new(26, 1, 16), Vector3.new(cx + 7, roofY - 0.5, cz + 8), Color3.fromRGB(210, 60, 50), Enum.Material.Metal)
	for _, spot in ipairs({ { -4, 2 }, { 18, 2 }, { -4, 14 }, { 18, 14 } }) do
		block(city, "Pillar", Vector3.new(1.5, 9, 1.5), Vector3.new(cx + spot[1], SIDEWALK_TOP + 4.5, cz + spot[2]), C_METAL, Enum.Material.Metal)
	end
	block(city, "Pump", Vector3.new(2, 4, 3), Vector3.new(cx + 3, SIDEWALK_TOP + 2, cz + 8), Color3.fromRGB(240, 150, 40), Enum.Material.SmoothPlastic)
	block(city, "Pump", Vector3.new(2, 4, 3), Vector3.new(cx + 11, SIDEWALK_TOP + 2, cz + 8), Color3.fromRGB(240, 150, 40), Enum.Material.SmoothPlastic)
	-- бензовоз: с него можно перепрыгнуть на крышу магазина
	block(city, "Tanker", Vector3.new(22, 6, 6), Vector3.new(cx + 9, SIDEWALK_TOP + 4, cz - 15), Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
	deco(block(city, "TankerWheels", Vector3.new(17, 1.4, 6.4), Vector3.new(cx + 9, SIDEWALK_TOP + 0.7, cz - 15), C_ROOF, Enum.Material.SmoothPlastic))
	-- мойка: туннель, открытый с двух сторон
	block(city, "TunnelWall", Vector3.new(0.6, 7, 14), Vector3.new(cx - 17, SIDEWALK_TOP + 3.5, cz + 13), Color3.fromRGB(70, 130, 190), Enum.Material.Metal)
	block(city, "TunnelWall", Vector3.new(0.6, 7, 14), Vector3.new(cx - 9, SIDEWALK_TOP + 3.5, cz + 13), Color3.fromRGB(70, 130, 190), Enum.Material.Metal)
	block(city, "TunnelRoof", Vector3.new(8.6, 0.5, 14), Vector3.new(cx - 13, SIDEWALK_TOP + 7.25, cz + 13), Color3.fromRGB(70, 130, 190), Enum.Material.Metal)
	table.insert(hideSpots, Vector3.new(cx - 13, SIDEWALK_TOP + 3, cz + 13))
	trampoline(cx + 7, cz - 4, SIDEWALK_TOP, 50) -- с батута можно запрыгнуть на навес
	bush(cx - 20, cz + 2)
	table.insert(roofAnchors, Vector3.new(cx - 12, roofY, cz - 13))
	table.insert(roofAnchors, Vector3.new(cx + 7, roofY, cz + 8))
	table.insert(roofAnchors, Vector3.new(cx + 9, SIDEWALK_TOP + 7, cz - 15))
	deco(block(city, "SignPole", Vector3.new(0.8, 14, 0.8), Vector3.new(cx + 19, SIDEWALK_TOP + 7, cz + 20), C_ROOF, Enum.Material.Metal))
	neonSign(cx + 14, SIDEWALK_TOP + 15, cz + 20, "FUEL")
end

-- торговый центр: внутрь можно зайти через четыре входа, а с батута в середине - вылететь на крышу
local function buildMall(cx: number, cz: number)
	local height = 13
	local roofY = SIDEWALK_TOP + height + 1
	local wallY = SIDEWALK_TOP + height / 2
	local color = Color3.fromRGB(120, 150, 185)
	for _, side in ipairs({ -1, 1 }) do
		for _, part in ipairs({ -1, 1 }) do
			-- стены по бокам от входа (вход шириной 6 посередине каждой стороны)
			block(city, "MallWall", Vector3.new(1, height, 16), Vector3.new(cx + side * 18.5, wallY, cz + part * 11), color, Enum.Material.Concrete)
			block(city, "MallWall", Vector3.new(15, height, 1), Vector3.new(cx + part * 10.5, wallY, cz + side * 18.5), color, Enum.Material.Concrete)
		end
		-- перемычки над входами
		block(city, "MallWall", Vector3.new(1, 6, 6), Vector3.new(cx + side * 18.5, SIDEWALK_TOP + 10, cz), color, Enum.Material.Concrete)
		block(city, "MallWall", Vector3.new(6, 6, 1), Vector3.new(cx, SIDEWALK_TOP + 10, cz + side * 18.5), color, Enum.Material.Concrete)
		-- крыша: посередине окно, в которое можно спрыгнуть
		block(city, "MallRoof", Vector3.new(38, 1, 14), Vector3.new(cx, roofY - 0.5, cz + side * 12), C_ROOF, Enum.Material.Metal)
		block(city, "MallRoof", Vector3.new(14, 1, 10), Vector3.new(cx + side * 12, roofY - 0.5, cz), C_ROOF, Enum.Material.Metal)
		-- прилавки и стеллажи, за которыми можно спрятаться
		block(city, "Kiosk", Vector3.new(3, 3.5, 7), Vector3.new(cx + side * 12, SIDEWALK_TOP + 1.75, cz - side * 2), C_CRATE, Enum.Material.WoodPlanks)
		block(city, "Shelf", Vector3.new(8, 6, 1), Vector3.new(cx - side * 9, SIDEWALK_TOP + 3, cz + side * 12), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		table.insert(hideSpots, Vector3.new(cx + side * 15, SIDEWALK_TOP + 3, cz - side * 2))
		local lamp = deco(block(city, "MallLamp", Vector3.new(2, 0.5, 2), Vector3.new(cx + side * 9, SIDEWALK_TOP + height - 0.3, cz - side * 9), Color3.fromRGB(255, 240, 210), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1.2
		light.Parent = lamp
	end
	for _, corner in ipairs(CORNERS) do
		block(city, "Pillar", Vector3.new(2, height, 2), Vector3.new(cx + corner[1] * 7, wallY, cz + corner[2] * 7), color, Enum.Material.Concrete)
	end
	trampoline(cx, cz, SIDEWALK_TOP, 62)
	ladder(cx + 20, cz - 10, SIDEWALK_TOP, 14, -1, 0)
	table.insert(roofAnchors, Vector3.new(cx - 12, roofY, cz - 13))
	table.insert(roofAnchors, Vector3.new(cx + 12, roofY, cz + 13))
	table.insert(heliSpots, Vector3.new(cx - 6, roofY, cz + 12))
	neonSign(cx, SIDEWALK_TOP + 10, cz + 19.4, "MALL")
end

-- больница: на крыше вертолётная площадка
local function buildHospital(cx: number, cz: number)
	local height = 20
	local roofY = SIDEWALK_TOP + height
	local color = Color3.fromRGB(225, 228, 232)
	block(city, "Hospital", Vector3.new(34, height, 28), Vector3.new(cx, SIDEWALK_TOP + height / 2, cz - 4), color, Enum.Material.Concrete)
	deco(block(city, "Windows", Vector3.new(34.3, 3, 28.3), Vector3.new(cx, SIDEWALK_TOP + 5, cz - 4), C_WINDOW_LIT, Enum.Material.Neon))
	deco(block(city, "Windows", Vector3.new(34.3, 3, 28.3), Vector3.new(cx, SIDEWALK_TOP + 15, cz - 4), C_WINDOW_LIT, Enum.Material.Neon))
	facade(cx, cz - 4, 34, 28, height, color)
	-- красный крест на стене
	deco(block(city, "Cross", Vector3.new(2, 6, 0.5), Vector3.new(cx, SIDEWALK_TOP + 10, cz + 10.5), Color3.fromRGB(230, 40, 40), Enum.Material.Neon))
	deco(block(city, "Cross", Vector3.new(6, 2, 0.5), Vector3.new(cx, SIDEWALK_TOP + 10, cz + 10.5), Color3.fromRGB(230, 40, 40), Enum.Material.Neon))
	-- вертолётная площадка с буквой H
	deco(block(city, "Helipad", Vector3.new(16, 0.2, 16), Vector3.new(cx, roofY + 0.1, cz - 4), Color3.fromRGB(40, 90, 60), Enum.Material.SmoothPlastic))
	deco(block(city, "HelipadMark", Vector3.new(1.2, 0.1, 8), Vector3.new(cx - 3, roofY + 0.25, cz - 4), Color3.fromRGB(245, 245, 245), Enum.Material.Neon))
	deco(block(city, "HelipadMark", Vector3.new(1.2, 0.1, 8), Vector3.new(cx + 3, roofY + 0.25, cz - 4), Color3.fromRGB(245, 245, 245), Enum.Material.Neon))
	deco(block(city, "HelipadMark", Vector3.new(6, 0.1, 1.2), Vector3.new(cx, roofY + 0.25, cz - 4), Color3.fromRGB(245, 245, 245), Enum.Material.Neon))
	block(city, "RoofBox", Vector3.new(4, 3, 4), Vector3.new(cx - 14, roofY + 1.5, cz + 7), C_METAL, Enum.Material.Metal)
	ladder(cx + 18, cz + 4, SIDEWALK_TOP, height, -1, 0)
	car(cx - 8, cz + 17, SIDEWALK_TOP, true)
	dumpster(cx + 10, cz + 17, true)
	bush(cx - 19.5, cz + 19.5)
	table.insert(roofAnchors, Vector3.new(cx - 13, roofY, cz - 15))
	table.insert(roofAnchors, Vector3.new(cx + 13, roofY, cz + 6))
	table.insert(heliSpots, Vector3.new(cx, roofY, cz - 4))
end

-- детская площадка: лазалка с горкой, батуты, домик и мяч
local function buildPlayground(cx: number, cz: number)
	local topY = SIDEWALK_TOP + 10
	deco(block(city, "Grass", Vector3.new(BLOCK_SIZE - 2, 0.2, BLOCK_SIZE - 2), Vector3.new(cx, SIDEWALK_TOP + 0.1, cz), Color3.fromRGB(95, 150, 75), Enum.Material.Grass))
	block(city, "PlayDeck", Vector3.new(8, 1, 8), Vector3.new(cx - 8, topY - 0.5, cz - 8), C_CRATE, Enum.Material.WoodPlanks)
	ladder(cx - 13, cz - 8, SIDEWALK_TOP, 10, 1, 0)
	for _, z in ipairs({ cz - 11, cz - 5 }) do
		local leg = Instance.new("TrussPart")
		leg.Name = "PlayFrame"
		leg.Anchored = true
		leg.Size = Vector3.new(2, 10, 2)
		leg.Position = Vector3.new(cx - 3, SIDEWALK_TOP + 5, z)
		leg.Color = Color3.fromRGB(60, 140, 230)
		leg.Parent = city
	end
	ramp(city, Vector3.new(cx - 8, SIDEWALK_TOP, cz + 10), Vector3.new(cx - 8, topY, cz - 4), 4, Color3.fromRGB(245, 200, 50)) -- горка
	trampoline(cx + 10, cz - 10, SIDEWALK_TOP, 60)
	trampoline(cx + 10, cz + 1, SIDEWALK_TOP, 45)
	deco(block(city, "Sandbox", Vector3.new(10, 0.3, 10), Vector3.new(cx + 12, SIDEWALK_TOP + 0.15, cz + 14), Color3.fromRGB(225, 200, 140), Enum.Material.Sand))
	shed(cx - 15, cz + 16, 1, 0, Color3.fromRGB(215, 70, 60)) -- домик
	ball(cx + 1, cz + 8, Color3.fromRGB(250, 110, 60))
	block(city, "Trunk", Vector3.new(2, 8, 2), Vector3.new(cx + 1, SIDEWALK_TOP + 4, cz - 17), C_TRUNK, Enum.Material.Wood)
	local leaves = deco(block(city, "Leaves", Vector3.new(11, 11, 11), Vector3.new(cx + 1, SIDEWALK_TOP + 11, cz - 17), C_LEAVES, Enum.Material.Grass))
	leaves.Shape = Enum.PartType.Ball
	bush(cx + 19.5, cz + 19.5)
	bush(cx + 19.5, cz - 19.5)
	table.insert(roofAnchors, Vector3.new(cx - 8, topY, cz - 8))
end

-- парк с фонтаном
local function buildPark(cx: number, cz: number)
	deco(block(city, "Grass", Vector3.new(BLOCK_SIZE - 2, 0.2, BLOCK_SIZE - 2), Vector3.new(cx, SIDEWALK_TOP + 0.1, cz), C_GRASS, Enum.Material.Grass))
	for _, spot in ipairs({ { -14, -13 }, { 13, -14 }, { -13, 14 }, { 14, 12 } }) do
		local x = cx + spot[1] + mapRng:NextInteger(-2, 2)
		local z = cz + spot[2] + mapRng:NextInteger(-2, 2)
		local trunkHeight = mapRng:NextInteger(7, 10)
		block(city, "Trunk", Vector3.new(2, trunkHeight, 2), Vector3.new(x, SIDEWALK_TOP + trunkHeight / 2, z), C_TRUNK, Enum.Material.Wood)
		local leaves = deco(block(city, "Leaves", Vector3.new(11, 11, 11), Vector3.new(x, SIDEWALK_TOP + trunkHeight + 3, z), C_LEAVES, Enum.Material.Grass))
		leaves.Shape = Enum.PartType.Ball
	end
	local stone = Color3.fromRGB(170, 170, 175)
	block(city, "FountainBase", Vector3.new(12, 1.4, 12), Vector3.new(cx, SIDEWALK_TOP + 0.7, cz), stone, Enum.Material.Concrete)
	local water = deco(block(city, "FountainWater", Vector3.new(10, 0.4, 10), Vector3.new(cx, SIDEWALK_TOP + 1.5, cz), Color3.fromRGB(80, 170, 230), Enum.Material.Glass))
	water.Transparency = 0.3
	block(city, "FountainPillar", Vector3.new(2, 5, 2), Vector3.new(cx, SIDEWALK_TOP + 3.9, cz), stone, Enum.Material.Concrete)
	block(city, "Bench", Vector3.new(8, 1.5, 2), Vector3.new(cx - 2, SIDEWALK_TOP + 0.75, cz + 12), C_TRUNK, Enum.Material.WoodPlanks)
	block(city, "Bench", Vector3.new(2, 1.5, 8), Vector3.new(cx + 12, SIDEWALK_TOP + 0.75, cz - 3), C_TRUNK, Enum.Material.WoodPlanks)
	bush(cx - 12, cz - 2)
	bush(cx + 3, cz - 16)
	bush(cx - 5, cz + 17)
	bush(cx + 17.5, cz + 2)
end

for i, cx in ipairs(BLOCK_CENTERS) do
	for j, cz in ipairs(BLOCK_CENTERS) do
		block(city, "Sidewalk", Vector3.new(BLOCK_SIZE, SIDEWALK_TOP - GROUND_TOP, BLOCK_SIZE), Vector3.new(cx, (SIDEWALK_TOP + GROUND_TOP) / 2, cz), C_SIDEWALK, Enum.Material.Concrete)
		local kind = string.sub(CITY_PLAN[i] or "", j, j)
		if kind == "T" then
			towers[i * 10 + j] = buildTower(cx, cz)
		elseif kind == "A" then
			buildAlleys(cx, cz)
		elseif kind == "L" then
			buildLowHouse(cx, cz)
		elseif kind == "M" then
			buildMarket(cx, cz)
		elseif kind == "C" then
			buildConstruction(cx, cz)
		elseif kind == "P" then
			buildParking(cx, cz)
		elseif kind == "K" then
			buildContainers(cx, cz)
		elseif kind == "S" then
			buildSchool(cx, cz)
		elseif kind == "F" then
			buildGas(cx, cz)
		elseif kind == "W" then
			buildMall(cx, cz)
		elseif kind == "H" then
			buildHospital(cx, cz)
		elseif kind == "Y" then
			buildPlayground(cx, cz)
		else
			buildPark(cx, cz)
		end
	end
end

-- мосты между крышами соседних высоток
for i = 1, #BLOCK_CENTERS do
	for j = 1, #BLOCK_CENTERS do
		local tower = towers[i * 10 + j]
		if tower then
			local east = towers[(i + 1) * 10 + j]
			if east and math.abs(tower.height - east.height) <= 20 then
				ramp(
					city,
					Vector3.new(tower.x + tower.width / 2 - 1, SIDEWALK_TOP + tower.height + 0.1, tower.z),
					Vector3.new(east.x - east.width / 2 + 1, SIDEWALK_TOP + east.height + 0.1, east.z),
					5,
					C_METAL
				)
			end
			local south = towers[i * 10 + j + 1]
			if south and math.abs(tower.height - south.height) <= 20 then
				ramp(
					city,
					Vector3.new(tower.x, SIDEWALK_TOP + tower.height + 0.1, tower.z + tower.width / 2 - 1),
					Vector3.new(south.x, SIDEWALK_TOP + south.height + 0.1, south.z - south.width / 2 + 1),
					5,
					C_METAL
				)
			end
		end
	end
end

-- брошенные машины, автобусы и заграждения на дорогах
for _, along in ipairs(BLOCK_CENTERS) do
	for _, road in ipairs(ROAD_CENTERS) do
		for pass = 1, 2 do
			local alongX = pass == 1
			local roll = mapRng:NextNumber()
			local offset = along + mapRng:NextInteger(-8, 8)
			local lane = road + (if mapRng:NextNumber() < 0.5 then -4 else 4)
			local x = if alongX then offset else lane
			local z = if alongX then lane else offset
			if alongX and road == RAIL_Z then
				roll = 1 -- под железной дорогой стоят опоры: машин здесь нет
			end
			if roll < 0.16 then
				car(x, z, GROUND_TOP, alongX)
				table.insert(roadObstacles, Vector3.new(x, GROUND_TOP, z))
			elseif roll < 0.24 then
				block(city, "Barrier", if alongX then Vector3.new(1.5, 3, 7) else Vector3.new(7, 3, 1.5), Vector3.new(x, GROUND_TOP + 1.5, z), C_HAZARD, Enum.Material.Concrete)
				table.insert(roadObstacles, Vector3.new(x, GROUND_TOP, z))
			elseif roll < 0.27 then
				bus(x, z, GROUND_TOP, alongX)
				table.insert(roadObstacles, Vector3.new(x, GROUND_TOP, z))
			end
		end
	end
end

-- фонари, разметка и точки появления на перекрёстках
local C_MARKING = Color3.fromRGB(230, 230, 230)
for _, x in ipairs(ROAD_CENTERS) do
	for _, z in ipairs(ROAD_CENTERS) do
		table.insert(citySpawns, Vector3.new(x, GROUND_TOP + 3, z))
		for _, side in ipairs({ -9, 9 }) do
			deco(block(city, "StopLine", Vector3.new(1.2, 0.1, 14), Vector3.new(x + side, GROUND_TOP + 0.04, z), C_MARKING, Enum.Material.SmoothPlastic))
			deco(block(city, "StopLine", Vector3.new(14, 0.1, 1.2), Vector3.new(x, GROUND_TOP + 0.04, z + side), C_MARKING, Enum.Material.SmoothPlastic))
		end
		local lampX = x + 9.5
		local lampZ = z + 9.5
		deco(block(city, "LampPole", Vector3.new(0.6, 16, 0.6), Vector3.new(lampX, SIDEWALK_TOP + 8, lampZ), C_ROOF, Enum.Material.Metal))
		local head = deco(block(city, "LampHead", Vector3.new(2.4, 0.6, 2.4), Vector3.new(lampX, SIDEWALK_TOP + 16.3, lampZ), Color3.fromRGB(255, 225, 170), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = head
	end
end

-- НАДЗЕМНАЯ ЖЕЛЕЗНАЯ ДОРОГА через весь город: по ней можно бегать, как по второму этажу.
-- Наверх ведут лестницы у опор, а в вагонах можно спрятаться.
do
	local deckY = GROUND_TOP + 16
	local length = (CITY_HALF - 14) * 2
	local steel = Color3.fromRGB(85, 90, 100)
	block(city, "RailDeck", Vector3.new(length, 1, 8), Vector3.new(0, deckY - 0.5, RAIL_Z), steel, Enum.Material.Metal)
	deco(block(city, "Rail", Vector3.new(length, 0.3, 0.5), Vector3.new(0, deckY + 0.15, RAIL_Z - 1.6), C_METAL, Enum.Material.Metal))
	deco(block(city, "Rail", Vector3.new(length, 0.3, 0.5), Vector3.new(0, deckY + 0.15, RAIL_Z + 1.6), C_METAL, Enum.Material.Metal))
	for index, cx in ipairs(BLOCK_CENTERS) do
		block(city, "RailPillar", Vector3.new(2, 15, 2), Vector3.new(cx, GROUND_TOP + 7.5, RAIL_Z), steel, Enum.Material.Concrete)
		table.insert(roofAnchors, Vector3.new(cx + 10, deckY, RAIL_Z))
		if index % 2 == 0 then
			ladder(cx, RAIL_Z + 5, GROUND_TOP, 16, 0, -1) -- лестница на каждой второй опоре
		elseif index > 1 and index < #BLOCK_CENTERS then
			-- вагон: туннель с открытыми торцами
			local wagon = pick(CAR_COLORS, mapRng)
			block(city, "WagonWall", Vector3.new(16, 6, 0.5), Vector3.new(cx + 14, deckY + 3, RAIL_Z - 3.75), wagon, Enum.Material.Metal)
			block(city, "WagonWall", Vector3.new(16, 6, 0.5), Vector3.new(cx + 14, deckY + 3, RAIL_Z + 3.75), wagon, Enum.Material.Metal)
			block(city, "WagonRoof", Vector3.new(16, 0.5, 8), Vector3.new(cx + 14, deckY + 6.25, RAIL_Z), wagon, Enum.Material.Metal)
			deco(block(city, "Windows", Vector3.new(12, 2, 0.2), Vector3.new(cx + 14, deckY + 3.8, RAIL_Z - 4.05), C_WINDOW_LIT, Enum.Material.Neon))
			deco(block(city, "Windows", Vector3.new(12, 2, 0.2), Vector3.new(cx + 14, deckY + 3.8, RAIL_Z + 4.05), C_WINDOW_LIT, Enum.Material.Neon))
			table.insert(hideSpots, Vector3.new(cx + 14, deckY + 3, RAIL_Z))
		end
	end
	-- на некоторых перекрёстках стоит батут: с него можно запрыгнуть на железную дорогу
	for index, roadX in ipairs(ROAD_CENTERS) do
		if index % 3 == 1 then
			trampoline(roadX - 4, RAIL_Z - 7.5, GROUND_TOP, 62)
		end
	end
end

-- ЛЮКИ. Встань на люк и нажми кнопку: вылезешь из люка того же цвета в другом конце города.
do
	local count = #ROAD_CENTERS
	local middle = math.ceil(count / 2)
	local links = { { 1, 1, count, count }, { 1, count, count, 1 }, { middle, 2, middle + 1, count - 1 }, { 2, middle + 1, count - 1, middle - 1 } }
	local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 220, 60), Color3.fromRGB(190, 110, 255) }
	local lastUse: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local function lid(roadX: number, roadZ: number, color: Color3): Part
		local x = ROAD_CENTERS[roadX] + 5
		local z = ROAD_CENTERS[roadZ] + 5
		deco(block(city, "ManholeRing", Vector3.new(6.4, 0.1, 6.4), Vector3.new(x, GROUND_TOP + 0.05, z), color, Enum.Material.Neon))
		return block(city, "Manhole", Vector3.new(5, 0.3, 5), Vector3.new(x, GROUND_TOP + 0.15, z), C_ROOF, Enum.Material.Metal)
	end
	for index, link in ipairs(links) do
		if count >= 6 then
			local first = lid(link[1], link[2], colors[index])
			local second = lid(link[3], link[4], colors[index])
			for _, way in ipairs({ { first, second }, { second, first } }) do
				local target = way[2].Position + Vector3.new(0, 4, 0)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Manhole"
				prompt.ObjectText = ""
				prompt.ActionText = ""
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 8
				prompt.RequiresLineOfSight = false
				prompt.Parent = way[1]
				prompt.Triggered:Connect(function(player: Player)
					local character = player.Character
					local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
					local now = os.clock()
					-- оглушённый или ещё не проснувшийся зомби в люк не лезет
					local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
					-- в люк лезет только тот, кто стоит рядом с ним
					if character and humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 and now - (lastUse[player] or 0) > 2
						and root and root:IsA("BasePart") and (root.Position - way[1].Position).Magnitude <= 16 and Guard.ok(player) then
						lastUse[player] = now
						Guard.allow(player, target)
						character:PivotTo(CFrame.new(target))
						Sfx.emit(way[1], "w_whoosh", 60, 1)
						Sfx.emit(way[2], "w_whoosh", 60, 1)
					end
				end)
			end
		end
	end
end

-- освещение меняется каждый раунд: закат, ночь, день
local TIMES_OF_DAY = {
	{ clock = 17.7, brightness = 2, ambient = Color3.fromRGB(95, 100, 120), outdoor = Color3.fromRGB(110, 115, 135) },
	{ clock = 0, brightness = 1.5, ambient = Color3.fromRGB(120, 125, 155), outdoor = Color3.fromRGB(120, 125, 155) },
	{ clock = 13, brightness = 2.5, ambient = Color3.fromRGB(110, 110, 110), outdoor = Color3.fromRGB(140, 140, 140) },
}

setTimeOfDay = function(index: number)
	local preset = TIMES_OF_DAY[((index - 1) % #TIMES_OF_DAY) + 1]
	Lighting.ClockTime = preset.clock
	Lighting.Brightness = preset.brightness
	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoor
end

setTimeOfDay(1)
do
	local atmosphere: Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(150, 170, 150)
	atmosphere.Decay = Color3.fromRGB(70, 90, 70)
	atmosphere.Parent = Lighting
end

Players.RespawnTime = 2

---------------------------------------------------------------------
-- ЛОББИ (стеклянная площадка над городом) И МАГАЗИН
---------------------------------------------------------------------
local LOBBY_HALF = 48

-- кнопка "нажми" у витрины; слов на ней нет, чтобы она была понятна на любом языке
local function addPrompt(part: Part, name: string, callback: (player: Player) -> (), hold: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = ""
	prompt.ActionText = ""
	prompt.HoldDuration = hold or 0 -- покупки - с коротким удержанием, чтобы не купить случайно
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(callback)
end

addBillboard = function(part: Part, text: string, height: number, owner: Instance): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZombieTagLabel"
	billboard.Adornee = part
	billboard.ResetOnSpawn = false
	billboard.Size = UDim2.fromScale(6.4, 2.4)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = 0.45
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = label
	billboard.Parent = owner
	return label
end

do
	local floorColor = Color3.fromRGB(225, 228, 235)
	local glassColor = Color3.fromRGB(160, 215, 255)
	local trimColor = Color3.fromRGB(90, 255, 140)
	local ring = LOBBY_HALF - 18

	-- пол: рамка и стеклянный центр, через который видно город
	block(lobby, "Floor", Vector3.new(LOBBY_HALF * 2, 1, ring), Vector3.new(0, LOBBY_Y, 18 + ring / 2), floorColor, Enum.Material.SmoothPlastic)
	block(lobby, "Floor", Vector3.new(LOBBY_HALF * 2, 1, ring), Vector3.new(0, LOBBY_Y, -18 - ring / 2), floorColor, Enum.Material.SmoothPlastic)
	block(lobby, "Floor", Vector3.new(ring, 1, 36), Vector3.new(18 + ring / 2, LOBBY_Y, 0), floorColor, Enum.Material.SmoothPlastic)
	block(lobby, "Floor", Vector3.new(ring, 1, 36), Vector3.new(-18 - ring / 2, LOBBY_Y, 0), floorColor, Enum.Material.SmoothPlastic)
	local glassFloor = block(lobby, "GlassFloor", Vector3.new(36, 1, 36), Vector3.new(0, LOBBY_Y, 0), glassColor, Enum.Material.Glass)
	glassFloor.Transparency = 0.55

	-- стеклянные стены и светящаяся рамка
	local wallHeight = 14
	local wallY = LOBBY_Y + 0.5 + wallHeight / 2
	local walls = {
		block(lobby, "GlassWall", Vector3.new(LOBBY_HALF * 2, wallHeight, 1), Vector3.new(0, wallY, LOBBY_HALF), glassColor, Enum.Material.Glass),
		block(lobby, "GlassWall", Vector3.new(LOBBY_HALF * 2, wallHeight, 1), Vector3.new(0, wallY, -LOBBY_HALF), glassColor, Enum.Material.Glass),
		block(lobby, "GlassWall", Vector3.new(1, wallHeight, LOBBY_HALF * 2), Vector3.new(LOBBY_HALF, wallY, 0), glassColor, Enum.Material.Glass),
		block(lobby, "GlassWall", Vector3.new(1, wallHeight, LOBBY_HALF * 2), Vector3.new(-LOBBY_HALF, wallY, 0), glassColor, Enum.Material.Glass),
	}
	for _, wall in ipairs(walls) do
		wall.Transparency = 0.6
	end
	local trimY = LOBBY_Y + 0.5 + wallHeight
	deco(block(lobby, "Trim", Vector3.new(LOBBY_HALF * 2 + 1, 0.6, 1.4), Vector3.new(0, trimY, LOBBY_HALF), trimColor, Enum.Material.Neon))
	deco(block(lobby, "Trim", Vector3.new(LOBBY_HALF * 2 + 1, 0.6, 1.4), Vector3.new(0, trimY, -LOBBY_HALF), trimColor, Enum.Material.Neon))
	deco(block(lobby, "Trim", Vector3.new(1.4, 0.6, LOBBY_HALF * 2 + 1), Vector3.new(LOBBY_HALF, trimY, 0), trimColor, Enum.Material.Neon))
	deco(block(lobby, "Trim", Vector3.new(1.4, 0.6, LOBBY_HALF * 2 + 1), Vector3.new(-LOBBY_HALF, trimY, 0), trimColor, Enum.Material.Neon))

	-- свет в лобби
	for _, corner in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local lamp = deco(block(lobby, "LobbyLamp", Vector3.new(2, 2, 2), Vector3.new(corner[1] * 30, LOBBY_Y + 12, corner[2] * 30), Color3.fromRGB(255, 240, 210), Enum.Material.Neon))
		lamp.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 1.2
		light.Parent = lamp
	end

	-- точки появления
	for _, spot in ipairs({ { -12, 26 }, { 0, 26 }, { 12, 26 }, { -12, 36 }, { 0, 36 }, { 12, 36 } }) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.Position = Vector3.new(spot[1], LOBBY_Y + 0.7, spot[2])
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = Color3.fromRGB(90, 220, 130)
		spawn.Material = Enum.Material.Neon
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = lobby
	end

	-- вывеска и правила
	local title = block(lobby, "TitleSign", Vector3.new(56, 9, 1), Vector3.new(0, LOBBY_Y + 21, -LOBBY_HALF + 1), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic)
	surfaceText(title, { GAME_TITLE }, Color3.fromRGB(110, 255, 130))

	local rules = block(lobby, "RulesBoard", Vector3.new(34, 12, 1), Vector3.new(0, LOBBY_Y + 8, LOBBY_HALF - 2), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic)
	table.insert(worldLabels, { part = rules, kind = "rules" })
	-- доска заданий (каждый видит свои задания) и таблица лучших игроков
	local questBoard = block(lobby, "QuestBoard", Vector3.new(22, 12, 1), Vector3.new(-31, LOBBY_Y + 8, LOBBY_HALF - 2), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic)
	table.insert(worldLabels, { part = questBoard, kind = "quests" })
	local topBoard = block(lobby, "TopBoard", Vector3.new(22, 12, 1), Vector3.new(31, LOBBY_Y + 8, LOBBY_HALF - 2), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic)
	topLabels = surfaceText(topBoard, { "TOP 10" }, Color3.fromRGB(255, 215, 90))

	-- колонка: возле неё можно выключить и снова включить музыку (каждый решает сам за себя)
	local speaker = block(lobby, "MusicBox", Vector3.new(3, 6, 4), Vector3.new(LOBBY_HALF - 7, LOBBY_Y + 3.5, 30), Color3.fromRGB(40, 45, 55), Enum.Material.Metal)
	for _, y in ipairs({ 2.2, 4.9 }) do
		local cone = deco(block(lobby, "MusicCone", Vector3.new(0.4, 2.2, 2.2), Vector3.new(LOBBY_HALF - 8.6, LOBBY_Y + y, 30), Color3.fromRGB(255, 90, 170), Enum.Material.Neon))
		cone.Shape = Enum.PartType.Cylinder
	end
	table.insert(worldLabels, { part = speaker, kind = "music" })
	addPrompt(speaker, "Music", function(player: Player)
		Sfx.toggle(player)
	end)

	-- витрины магазина: следы вдоль дальней стены, облики зомби вдоль левой
	local shopZ = -LOBBY_HALF + 6
	local trailTotal, skinTotal = 0, 0
	for _, item in ipairs(SHOP_ITEMS) do
		if item.kind == "trail" then
			trailTotal += 1
		else
			skinTotal += 1
		end
	end
	local trailIndex, skinIndex = 0, 0
	for _, item in ipairs(SHOP_ITEMS) do
		local place: Vector3
		if item.kind == "trail" then
			trailIndex += 1
			place = Vector3.new((trailIndex - (trailTotal + 1) / 2) * 7, LOBBY_Y + 2, shopZ)
		else
			skinIndex += 1
			place = Vector3.new(-LOBBY_HALF + 6, LOBBY_Y + 2, (skinIndex - (skinTotal + 1) / 2) * 8 + 2)
		end
		local stand = block(lobby, "ShopStand", Vector3.new(4, 3, 4), place, Color3.fromRGB(40, 45, 55), Enum.Material.Metal)
		local sample = deco(block(lobby, "ShopSample", Vector3.new(2.4, 2.4, 2.4), place + Vector3.new(0, 3, 0), item.colorA, Enum.Material.Neon))
		sample.Shape = Enum.PartType.Ball
		table.insert(worldLabels, { part = stand, kind = "item", item = item })
		addPrompt(stand, "Buy_" .. item.id, function(player: Player)
			shopHandler(player, item)
		end, 0.3)
	end
	local trailSign = deco(block(lobby, "ShopSign", Vector3.new(30, 3, 0.6), Vector3.new(0, LOBBY_Y + 12.5, shopZ - 3), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic))
	table.insert(worldLabels, { part = trailSign, kind = "trails" })
	local skinSign = deco(block(lobby, "ShopSign", Vector3.new(26, 3, 0.6), Vector3.new(-LOBBY_HALF + 3, LOBBY_Y + 12.5, 2), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic))
	skinSign.CFrame = CFrame.new(skinSign.Position) * CFrame.Angles(0, math.pi / 2, 0)
	table.insert(worldLabels, { part = skinSign, kind = "skins" })

	-- зона магазина: кто стоит на синем полу у витрин, того раунд не забирает
	for _, floor in ipairs({
		deco(block(lobby, "ShopFloor", Vector3.new(LOBBY_HALF * 2 - 2, 0.2, 17), Vector3.new(0, LOBBY_Y + 0.6, -LOBBY_HALF + 9.5), Color3.fromRGB(70, 150, 255), Enum.Material.SmoothPlastic)),
		deco(block(lobby, "ShopFloor", Vector3.new(15, 0.2, 64), Vector3.new(-LOBBY_HALF + 8.5, LOBBY_Y + 0.6, 2), Color3.fromRGB(70, 150, 255), Enum.Material.SmoothPlastic)),
		deco(block(lobby, "ShopFloor", Vector3.new(15, 0.2, 64), Vector3.new(LOBBY_HALF - 8.5, LOBBY_Y + 0.6, 2), Color3.fromRGB(70, 150, 255), Enum.Material.SmoothPlastic)),
	}) do
		floor.Transparency = 0.45
	end
	local zoneSign = deco(block(lobby, "ShopZoneSign", Vector3.new(1, 5, 1), Vector3.new(30, LOBBY_Y + 3, -28), Color3.fromRGB(70, 150, 255), Enum.Material.Neon))
	table.insert(worldLabels, { part = zoneSign, kind = "shopzone" })

	-- стойка "пригласи друзей": открывает окно приглашения Roblox
	local inviteStand = block(lobby, "InviteStand", Vector3.new(4, 3, 4), Vector3.new(LOBBY_HALF - 7, LOBBY_Y + 2, 20), Color3.fromRGB(90, 220, 130), Enum.Material.Neon)
	table.insert(worldLabels, { part = inviteStand, kind = "invite" })
	addPrompt(inviteStand, "Invite", function(player: Player)
		pcall(function()
			game:GetService("SocialService"):PromptGameInvite(player)
		end)
	end)

	-- цену платной витрины сообщает Roblox: она пишется на подписи, чтобы было видно, сколько это стоит
	local function askPrice(stand: Part, id: number, kind: Enum.InfoType)
		task.spawn(function()
			local ok, info = pcall(function(): any
				return MarketplaceService:GetProductInfoAsync(id, kind)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				stand:SetAttribute("Robux", info.PriceInRobux)
			end
		end)
	end
	-- платные витрины появляются, только если вписаны номера в настройках
	if VIP_GAMEPASS_ID > 0 then
		local stand = block(lobby, "VipStand", Vector3.new(5, 3, 5), Vector3.new(LOBBY_HALF - 7, LOBBY_Y + 2, -22), Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
		table.insert(worldLabels, { part = stand, kind = "vip" })
		askPrice(stand, VIP_GAMEPASS_ID, Enum.InfoType.GamePass)
		addPrompt(stand, "Buy_vip", function(player: Player)
			vipHandler(player)
		end, 0.4)
	end
	local coinStands = 0
	for _, product in ipairs(COIN_PRODUCTS) do
		if product.id > 0 then
			coinStands += 1
			local x = LOBBY_HALF - 7
			local z = (coinStands - 2) * 10
			local stand = block(lobby, "CoinsStand", Vector3.new(5, 3, 5), Vector3.new(x, LOBBY_Y + 2, z), Color3.fromRGB(255, 225, 80), Enum.Material.Neon)
			-- чем больше набор, тем больше золотых шаров на витрине
			for index = 1, coinStands do
				local sample = deco(block(lobby, "CoinsSample", Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, LOBBY_Y + 4.3, z + (index - (coinStands + 1) / 2) * 1.7), Color3.fromRGB(255, 215, 50), Enum.Material.Neon))
				sample.Shape = Enum.PartType.Ball
			end
			table.insert(worldLabels, { part = stand, kind = "coins", coins = product.coins })
			local productId = product.id
			askPrice(stand, productId, Enum.InfoType.Product)
			addPrompt(stand, "Buy_coins_" .. product.coins, function(player: Player)
				coinsHandler(player, productId)
			end, 0.4)
		end
	end
end

map.Parent = workspace

end -- КОНЕЦ БЛОКА ПОСТРОЙКИ КАРТЫ

---------------------------------------------------------------------
-- ЯЗЫК И НАДПИСИ НА ЭКРАНЕ
---------------------------------------------------------------------
local function detectLang(player: Player): string
	if TEXT[FORCE_LANGUAGE] then
		return FORCE_LANGUAGE
	end
	local code = string.sub(string.lower(player.LocaleId), 1, 2)
	return if TEXT[code] then code else "en"
end

local function tr(player: Player, key: string, ...: any): string
	local session = sessions[player]
	local lang = if session then session.lang else "en"
	local template = TEXT[lang][key] or TEXT.en[key] or key
	local ok, result = pcall(string.format, template, ...)
	return if ok then result else template
end

-- уровень игрока по его опыту: 2-й уровень - 60 опыта, 3-й - 180, 4-й - 360 и так далее
local function levelOf(xp: number): number
	return math.floor((math.sqrt(1 + xp / 7.5) - 1) / 2) + 1
end

-- стоит ли точка на синем полу магазина в лобби (там раунд игрока не забирает)
local function inShopZone(position: Vector3): boolean
	-- синий пол лежит вдоль трёх стен лобби с витринами: дальней (Z меньше -30), левой и правой
	return position.Y > LOBBY_Y - 5 and (position.Z < -30 or (math.abs(position.X) > 32 and position.Z < 34))
end

-- название товара на языке игрока
local function itemName(player: Player, item: ShopItem): string
	return tr(player, "item_" .. item.id)
end

-- подписи на витринах: название и цена, а у купленного - "надеть" или "надето"
local function refreshShop(player: Player)
	local hud = huds[player]
	local session = sessions[player]
	if not hud or not session then
		return
	end
	local profile = session.profile
	for _, item in ipairs(SHOP_ITEMS) do
		local label = hud.itemLabels[item.id]
		if label then
			local state: string
			local title = itemName(player, item)
			local needLevel = item.level or 0
			if item.days and not profile.owned[item.id] then
				-- подарок за дни подряд
				title ..= " 🎁"
				state = "🔥 " .. math.min(profile.streak, item.days) .. "/" .. item.days
				label.TextColor3 = Color3.fromRGB(255, 190, 240)
			elseif not profile.owned[item.id] and levelOf(profile.xp) < needLevel then
				-- товар откроется с уровнем: серая подпись
				title ..= " 🔒"
				state = tr(player, "lvl", needLevel) .. "  ·  " .. tr(player, "price", item.price)
				label.TextColor3 = Color3.fromRGB(170, 170, 185)
			elseif not profile.owned[item.id] then
				-- жёлтая цена - монет хватает, красная - пока нет
				state = tr(player, "price", item.price) .. (item.note or "")
				label.TextColor3 = if profile.coins >= item.price then Color3.fromRGB(255, 225, 120) else Color3.fromRGB(255, 125, 115)
			elseif profile.trail == item.id or profile.skin == item.id then
				state = tr(player, "wearing")
				label.TextColor3 = Color3.fromRGB(140, 255, 140)
			else
				state = tr(player, "wear")
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
			label.Text = title .. "\n" .. state
		end
	end
end

-- подпись на витрине VIP: у владельца стоит галочка, у остальных - цена
local function refreshVip(player: Player)
	local hud = huds[player]
	local session = sessions[player]
	local label = if hud then hud.vipLabel else nil
	if label and session then
		local board = label.Parent
		local stand = if board and board:IsA("BillboardGui") then board.Adornee else nil
		label.Text = if session.vip then "VIP ✓\n" .. tr(player, "vip_label")
			else "VIP\n" .. tr(player, "vip_label") .. "\n" .. (if stand then robuxText(stand) else "Robux")
	end
end

-- подписи в лобби на языке игрока (их видит только он)
local function createWorldLabels(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui or playerGui:FindFirstChild("ZombieTagLabel") then
		return
	end
	local hud = huds[player]
	for _, info in ipairs(worldLabels) do
		local item = info.item
		if info.kind == "item" and item then
			local label = addBillboard(info.part, "", 6.5, playerGui)
			if hud then
				hud.itemLabels[item.id] = label
			end
		elseif info.kind == "vip" then
			local label = addBillboard(info.part, "", 5, playerGui)
			if hud then
				hud.vipLabel = label
			end
			-- цену Roblox сообщает через секунду-другую после запуска сервера: подпись обновится сама
			for _, pause in ipairs({ 3, 8, 20 }) do
				task.delay(pause, refreshVip, player)
			end
		elseif info.kind == "coins" then
			local label = addBillboard(info.part, "", 5, playerGui)
			local stand, coins = info.part, info.coins or 0
			local function write()
				label.Text = tr(player, "coins", coins) .. "\n" .. robuxText(stand)
			end
			write()
			for _, pause in ipairs({ 3, 8, 20 }) do
				task.delay(pause, write)
			end
		elseif info.kind == "shopzone" then
			addBillboard(info.part, tr(player, "shop_zone"), 6.5, playerGui)
		elseif info.kind == "invite" then
			addBillboard(info.part, tr(player, "invite_label"), 5, playerGui)
		elseif info.kind == "quests" then
			local labels = surfaceText(info.part, { "" }, Color3.fromRGB(255, 255, 255), playerGui)
			if hud then
				hud.questLabels = labels
			end
		elseif info.kind == "music" then
			local label = addBillboard(info.part, "", 5, playerGui)
			if hud then
				hud.musicLabel = label
			end
			Sfx.label(player)
		elseif info.kind == "trails" then
			surfaceText(info.part, { tr(player, "trails_title") }, Color3.fromRGB(255, 210, 90), playerGui)
		elseif info.kind == "skins" then
			surfaceText(info.part, { tr(player, "skins_title") }, Color3.fromRGB(150, 255, 150), playerGui)
		else
			surfaceText(
				info.part,
				{ tr(player, "rules_title"), tr(player, "rules_1"), tr(player, "rules_2"), tr(player, "tip_hide"), tr(player, "rules_3") },
				Color3.fromRGB(255, 255, 255),
				playerGui
			)
		end
	end
	refreshShop(player)
end

local function createHud(player: Player)
	if huds[player] then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", 15)
	if not playerGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZombieTagHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local function makeLabel(name: string, anchorY: number, posY: number, width: number, heightScale: number, maxText: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0.5, anchorY)
		label.Position = UDim2.fromScale(0.5, posY)
		label.Size = UDim2.fromScale(width, heightScale)
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.2
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = ""
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxText
		limit.MinTextSize = 12
		limit.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
		label.Parent = gui
		return label
	end

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	-- строки занимают заметную долю экрана: на телефоне текст остаётся читаемым
	local status = makeLabel("Status", 0, 0.01, 0.62, 0.075, 30)
	status.BackgroundTransparency = 0.4
	local role = makeLabel("Role", 0, 0.095, 0.62, 0.062, 28)
	local event = makeLabel("Event", 0, 0.162, 0.62, 0.055, 24)
	event.TextColor3 = Color3.fromRGB(255, 215, 90)
	-- подсказка: что сейчас делать (новичку, у вертолёта, в финале)
	local hint = makeLabel("Goal", 0, 0.224, 0.62, 0.065, 26)
	hint.TextColor3 = Color3.fromRGB(140, 235, 255)
	local big = makeLabel("Big", 0.5, 0.43, 0.9, 0.12, 52)
	local toast = makeLabel("Toast", 1, 0.8, 0.66, 0.07, 26)
	-- кошелёк: монеты и уровень всегда на виду (на телефоне список игроков свёрнут)
	local wallet = makeLabel("Wallet", 0, 0.01, 0.175, 0.075, 26)
	wallet.AnchorPoint = Vector2.new(0, 0)
	wallet.Position = UDim2.fromScale(0.008, 0.01)
	wallet.BackgroundTransparency = 0.4
	wallet.RichText = true
	-- полоска под кошельком: сколько опыта набрано до следующего уровня
	local xpBar = Instance.new("Frame")
	xpBar.Name = "Xp"
	xpBar.AnchorPoint = Vector2.new(0, 1)
	xpBar.Position = UDim2.fromScale(0.06, 0.97)
	xpBar.Size = UDim2.fromScale(0, 0.14)
	xpBar.BackgroundColor3 = Color3.fromRGB(120, 235, 140)
	xpBar.BorderSizePixel = 0
	xpBar.Parent = wallet

	gui.Parent = playerGui

	local sounds: { [string]: Sound } = {}
	if SOUNDS then
		for name, file in pairs(SOUND_FILES) do
			local kind = string.sub(name, 1, 2)
			if kind ~= "w_" and (kind ~= "m_" or MUSIC_VOLUME > 0) then
				local sound = Instance.new("Sound")
				sound.Name = name
				sound.SoundId = file
				sound.Volume = (SOUND_LOUD[name] or 0.5) * (if kind == "m_" then MUSIC_VOLUME else 1)
				sound.Looped = kind == "m_"
				local region = SOUND_REGION[name]
				if region then
					sound.PlaybackRegionsEnabled = true
					sound.PlaybackRegion = region
				end
				sound.Parent = gui
				sounds[name] = sound
			end
		end
	end

	local hud: Hud = {
		gui = gui, status = status, role = role, event = event, big = big, toast = toast, flash = flash,
		itemLabels = {}, questLabels = {}, sounds = sounds, music = "", musicLabel = nil, vipLabel = nil, hint = hint, wallet = wallet,
		toastState = { token = 0, key = "", since = 0, queue = {} }, bigState = { token = 0, key = "", since = 0, queue = {} },
	}
	huds[player] = hud
	if statusKey ~= "" then
		status.Text = tr(player, statusKey, table.unpack(statusArgs))
	end
end

local function setStatus(key: string, ...: any)
	statusKey = key
	statusArgs = { ... }
	for player, hud in pairs(huds) do
		hud.status.Text = tr(player, key, ...)
	end
end

-- Показывает надпись в строке экрана. Если там уже есть другая надпись, новая встаёт в очередь
-- и ждёт, пока ту успеют прочитать (RULES.readGap). Длинная надпись висит дольше короткой.
local function showLine(label: TextLabel, state: LineState, key: string, text: string, plate: boolean)
	local function show(shownKey: string, shownText: string)
		state.token += 1
		local token = state.token
		state.key = shownKey
		state.since = os.clock()
		label.Text = shownText
		if plate then
			label.BackgroundTransparency = 0.4
		end
		task.delay(math.clamp(2 + #shownText / 16, 3.5, 6), function()
			if state.token == token then
				label.Text = ""
				if plate then
					label.BackgroundTransparency = 1
				end
			end
		end)
	end
	local queue = state.queue
	local function news(name: string): boolean
		return name == "caught" or name == "caught_by_bot" or name == "heli_left"
	end
	if label.Text ~= "" and news(key) and not news(state.key) then
		return -- строка занята: новости о других игроках не оттесняют то, что касается самого игрока
	end
	if label.Text == "" or (state.key == key and #queue == 0) then
		show(key, text) -- строка свободна или это та же надпись с новым числом: меняем сразу
		return
	end
	for _, waiting in ipairs(queue) do
		if waiting.key == key then
			waiting.text = text
			return
		end
	end
	if #queue >= 3 then
		table.remove(queue, 1)
	end
	table.insert(queue, { key = key, text = text })
	if #queue == 1 then
		task.spawn(function()
			while #queue > 0 do
				local gap = RULES.readGap - (os.clock() - state.since)
				if gap > 0 then
					task.wait(gap)
				end
				local nextLine = table.remove(queue, 1)
				if nextLine then
					show(nextLine.key, nextLine.text)
				end
			end
		end)
	end
end

local function toast(player: Player, key: string, ...: any)
	local hud = huds[player]
	if hud then
		showLine(hud.toast, hud.toastState, key, tr(player, key, ...), true)
	end
end

-- крупная надпись посередине экрана: одному игроку или (если игрок не указан) всем
local function bigText(target: Player?, key: string, ...: any)
	for player, hud in pairs(huds) do
		if target == nil or target == player then
			showLine(hud.big, hud.bigState, key, tr(player, key, ...), false)
		end
	end
end

-- звук, который слышит только этот игрок
local function playSound(player: Player, name: string)
	local hud = huds[player]
	local sound = if hud then hud.sounds[name] else nil
	if sound then
		local region = SOUND_REGION[name]
		if region then
			sound.TimePosition = region.Min
		end
		sound:Play()
	end
end

local function setRole(player: Player, key: string, color: Color3)
	local hud = huds[player]
	if hud then
		hud.role.Text = if key == "" then "" else tr(player, key)
		hud.role.TextColor3 = color
	end
end

local function flashScreen(player: Player)
	local hud = huds[player]
	if hud then
		hud.flash.BackgroundTransparency = 0.55
		task.delay(0.35, function()
			hud.flash.BackgroundTransparency = 1
		end)
	end
end

---------------------------------------------------------------------
-- СОХРАНЕНИЕ, МОНЕТЫ, ЕЖЕДНЕВНАЯ НАГРАДА
---------------------------------------------------------------------
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SAVE_NAME)
	end)
	if ok then
		store = result
	end
end
-- общая таблица лучших игроков (по победам)
local topStore: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(SAVE_NAME .. "_TopWins")
	end)
	if ok then
		topStore = result
	end
end
local saveNoticeShown = false
-- flying - сколько сохранений сейчас в пути; id - имя этого сервера (чтобы два сервера не затёрли прогресс друг друга)
local Save = { flying = 0, count = 0, id = if game.JobId ~= "" then game.JobId else "studio" }

local function newProfile(): Profile
	return {
		coins = 0, wins = 0, infections = 0, owned = {}, trail = "", skin = "", lastDaily = 0, streak = 0,
		xp = 0, questDay = 0, questProgress = {}, questDone = {}, musicOff = false,
		rounds = 0, receipts = {}, badges = {},
	}
end

-- Загружает прогресс и ставит на него метку этой игровой сессии. Возвращает прогресс,
-- удалось ли его загрузить, и метку.
local function loadProfile(player: Player): (Profile, boolean, string)
	local profile = newProfile()
	local currentStore = store
	Save.count += 1
	local mine = Save.id .. "/" .. Save.count
	if not currentStore then
		return profile, false, mine
	end
	local data: any = nil
	local loaded = false
	-- до пяти попыток: сеть могла дать сбой, а прошлый сервер - ещё не успеть сохранить прогресс
	for attempt = 1, 5 do
		local busy = false
		local ok = pcall(function()
			currentStore:UpdateAsync("player_" .. player.UserId, function(old: any): any
				if type(old) == "table" and type(old.lock) == "table"
					and os.time() - (tonumber(old.lock.t) or 0) < 600 and attempt < 5 then
					busy = true -- прогресс ещё держит другой сервер (или прошлый заход): подождём, пока он сохранит
					return nil
				end
				local fresh: any = if type(old) == "table" then old else {}
				fresh.lock = { id = mine, t = os.time() }
				data = fresh
				return fresh
			end)
		end)
		if ok and not busy then
			loaded = true
			break
		end
		if (not ok and (attempt >= 3 or RunService:IsStudio())) or player.Parent ~= Players then
			break
		end
		task.wait(if ok then 4 else attempt * 1.5)
	end
	if not loaded then
		if not saveNoticeShown then
			saveNoticeShown = true
			print("[Zombie Tag] Сохранение сейчас выключено (в Studio это нормально). После публикации игры оно заработает само.")
		end
		return profile, false, mine
	end
	if type(data) == "table" then
		local saved = data :: any
		for _, field in ipairs({ "coins", "wins", "infections", "lastDaily", "streak", "xp", "questDay", "rounds" }) do
			if type(saved[field]) == "number" then
				(profile :: any)[field] = saved[field]
			end
		end
		if type(saved.trail) == "string" then profile.trail = saved.trail end
		if type(saved.skin) == "string" then profile.skin = saved.skin end
		if saved.musicOff == true then profile.musicOff = true end
		(profile :: any).ext = saved.ext -- запасы (модуль Survival проверяет их сам)
		if type(saved.receipts) == "table" then
			for _, id in ipairs(saved.receipts) do
				if type(id) == "string" and #profile.receipts < 40 then
					table.insert(profile.receipts, id)
				end
			end
		end
		-- отметки "да/нет": значки, выполненные задания, купленные товары
		-- (покупка остаётся в прогрессе, даже если товар потом убрали из магазина)
		for _, field in ipairs({ "badges", "questDone", "owned" }) do
			if type(saved[field]) == "table" then
				for name, value in pairs(saved[field]) do
					if type(name) == "string" and value == true then
						(profile :: any)[field][name] = true
					end
				end
			end
		end
		if type(saved.questProgress) == "table" then
			for id, value in pairs(saved.questProgress) do
				if type(id) == "string" and type(value) == "number" then
					profile.questProgress[id] = value
				end
			end
		end
	end
	return profile, true, mine
end

-- Сохраняет прогресс. Возвращает true, только если запись точно прошла.
-- given - сессия уходящего игрока, release = true - последнее сохранение (сервер отпускает прогресс).
local function saveProfile(player: Player, given: Session?, release: boolean?): boolean
	local session = given or sessions[player]
	local currentStore = store
	if not session or not session.canSave or not currentStore then
		return false
	end
	if release then
		if session.leaving then
			return true
		end
		session.leaving = true
	elseif session.leaving then
		return false -- игрок уже выходит: прогресс пишет последнее сохранение
	end
	Save.flying += 1
	local stolen = false
	local ok, err: any = false, nil
	-- последнее сохранение при сбое повторяется: другого случая записать прогресс уже не будет
	local tries = if release then 3 else 1
	for attempt = 1, tries do
		stolen = false
		ok, err = pcall(function()
			currentStore:UpdateAsync("player_" .. player.UserId, function(old: any): any
				if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.id ~= session.lock then
					stolen = true -- метка не наша: игрок уже играет в другом месте, там его прогресс новее
					return nil
				end
				local out: any = table.clone(session.profile)
				out.lock = if release then nil else { id = session.lock, t = os.time() }
				return out
			end)
		end)
		if ok or stolen or attempt == tries then
			break
		end
		task.wait(attempt)
	end
	-- победы игрока попадают в общую таблицу лидеров
	local top = topStore
	if ok and not stolen and top and session.profile.wins > 0 then
		pcall(function()
			top:SetAsync(tostring(player.UserId), session.profile.wins)
		end)
	end
	Save.flying -= 1
	if stolen then
		session.canSave = false
		return false
	end
	if not ok then
		warn("[Zombie Tag] Не удалось сохранить данные игрока " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

local function createLeaderstats(player: Player): Instance
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = folder
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = folder
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = folder
	folder.Parent = player
	return folder
end

local function syncStats(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local stats: Instance = player:FindFirstChild("leaderstats") or createLeaderstats(player)
	local coinsValue = stats:FindFirstChild("Coins")
	local winsValue = stats:FindFirstChild("Wins")
	if coinsValue and coinsValue:IsA("IntValue") then
		coinsValue.Value = session.profile.coins
	end
	if winsValue and winsValue:IsA("IntValue") then
		winsValue.Value = session.profile.wins
	end
	local levelValue = stats:FindFirstChild("Level")
	if levelValue and levelValue:IsA("IntValue") then
		levelValue.Value = levelOf(session.profile.xp)
	end
	local hud = huds[player]
	if hud then
		local level = levelOf(session.profile.xp)
		hud.wallet.Text = '<font color="#FFD732">●</font> ' .. session.profile.coins .. "   " .. tr(player, "lvl", level)
		local bar = hud.wallet:FindFirstChild("Xp")
		if bar and bar:IsA("Frame") then
			bar.Size = UDim2.fromScale(0.88 * math.clamp((session.profile.xp - 30 * level * (level - 1)) / (60 * level), 0, 1), 0.14)
		end
		refreshShop(player)
	end
end

-- выдаёт монеты с учётом VIP и бонуса друзей, возвращает сколько выдано
local function award(player: Player, base: number, flat: boolean?): number
	local session = sessions[player]
	if not session then
		return 0
	end
	local multiplier = 1
	if session.vip then
		multiplier += 1
	end
	if session.friendBoost then
		multiplier += FRIEND_BONUS
	end
	if not flat then
		multiplier *= RULES.pay -- раунд с золотой лихорадкой (x2) или в режиме недели (+50%)
	end
	local amount = math.floor(base * multiplier + 0.5)
	local profile = session.profile
	profile.coins += amount
	-- за монеты идёт опыт, а за новый уровень - подарок
	local before = levelOf(profile.xp)
	profile.xp += base
	local level = levelOf(profile.xp)
	if level > before then
		local gift = level * 10
		profile.coins += gift
		bigText(player, "level_up", level, gift)
		playSound(player, "levelup")
		applyVipTag(player)
	end
	syncStats(player)
	return amount
end

local function giveDailyReward(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local profile = session.profile
	-- время хранится в часах (раньше - день). Награда - через 8 часов после прошлой (вечером и утром -
	-- в любой стране), но отметка сдвигается не меньше чем на сутки: в среднем выходит одна награда в день
	local now = os.time() // 3600
	local last = math.min(now + 16, if profile.lastDaily < 100000 then profile.lastDaily * 24 + 16 else profile.lastDaily)
	if now - last < 8 then
		return
	end
	-- серия не рвётся из-за одного пропущенного дня
	profile.streak = if now // 24 - last // 24 <= 2 then profile.streak + 1 else 1
	profile.lastDaily = math.max(now, last + 24)
	local amount = award(player, DAILY_REWARD * math.min(profile.streak, 7), true)
	-- надпись появляется чуть позже (игра ещё загружается); новичку в первом раунде и так есть что читать
	if profile.rounds + profile.wins + profile.infections > 0 then
		task.delay(RULES.noteDelay, function()
			toast(player, "daily", amount, profile.streak)
			playSound(player, "daily")
		end)
	end
end

---------------------------------------------------------------------
-- ЗАДАНИЯ НА ДЕНЬ. Каждый день три задания из списка, за каждое дают монеты.
---------------------------------------------------------------------
local QUESTS: { { id: string, goal: number, reward: number } } = {
	{ id = "catch", goal = 5, reward = 40 },   -- поймать выживших
	{ id = "survive", goal = 2, reward = 50 }, -- выжить в раундах
	{ id = "coins", goal = 15, reward = 30 },  -- собрать монеты на улице
	{ id = "heli", goal = 1, reward = 50 },    -- улететь на вертолёте
	{ id = "play", goal = 4, reward = 30 },    -- сыграть раунды
	{ id = "hide", goal = 45, reward = 40 },   -- просидеть в укрытии (секунды)
	{ id = "shield", goal = 1, reward = 40 },  -- отбить зомби щитом
}
local Quest = {}

-- задания на сегодня (у всех игроков одинаковые); вчерашние успехи при этом сбрасываются
function Quest.today(player: Player): { { id: string, goal: number, reward: number } }
	local session = sessions[player]
	local day = if session then session.day else os.time() // 86400
	if session and session.profile.questDay ~= day then
		session.profile.questDay = day
		session.profile.questProgress = {}
		session.profile.questDone = {}
	end
	local list = {}
	for offset = 0, 2 do
		table.insert(list, QUESTS[(day + offset * 2) % #QUESTS + 1])
	end
	return list
end

-- доска заданий в лобби: выполненные задания зелёные
function Quest.refresh(player: Player)
	local hud = huds[player]
	local session = sessions[player]
	if not hud or not session then
		return
	end
	local lines = { '<font color="#FFD25A">' .. tr(player, "q_title") .. "</font>" }
	for _, quest in ipairs(Quest.today(player)) do
		local progress = math.min(session.profile.questProgress[quest.id] or 0, quest.goal)
		local text = tr(player, "q_" .. quest.id, quest.goal) .. "\n" .. progress .. "/" .. quest.goal .. "  +" .. quest.reward
		if session.profile.questDone[quest.id] then
			text = '<font color="#8CFF8C">' .. text .. "</font>"
		end
		table.insert(lines, text)
	end
	for _, label in ipairs(hud.questLabels) do
		label.RichText = true
		label.Text = table.concat(lines, "\n")
	end
end

-- игрок продвинулся в задании
function Quest.add(player: Player, id: string, amount: number)
	local session = sessions[player]
	if not session then
		return
	end
	for _, quest in ipairs(Quest.today(player)) do
		if quest.id == id and not session.profile.questDone[id] then
			local progress = (session.profile.questProgress[id] or 0) + amount
			session.profile.questProgress[id] = progress
			if progress >= quest.goal then
				session.profile.questDone[id] = true
				bigText(player, "q_done", award(player, quest.reward, true))
				playSound(player, "quest")
				-- все три задания дня выполнены: бонус (один раз в день)
				local left = 0
				for _, other in ipairs(Quest.today(player)) do
					if not session.profile.questDone[other.id] then
						left += 1
					end
				end
				if left == 0 and not session.profile.questDone.all then
					session.profile.questDone.all = true
					toast(player, "q_all", award(player, COINS.allQuests, true))
				end
			end
			Quest.refresh(player)
		end
	end
end

-- награда зомби за пойманного: монеты, задание и бонус за серию поимок подряд
local function rewardCatch(catcher: Player, coins: number)
	local session = sessions[catcher]
	if not session then
		return
	end
	session.profile.infections += 1
	session.caught += 1
	toast(catcher, "coins", award(catcher, coins))
	playSound(catcher, "catch")
	Quest.add(catcher, "catch", 1)
	local now = os.clock()
	session.combo = if now - session.comboAt <= 12 then session.combo + 1 else 1
	session.comboAt = now
	if session.combo >= 2 then
		bigText(catcher, "streak", session.combo, award(catcher, COINS.streak * session.combo))
	end
end

---------------------------------------------------------------------
-- ВНЕШНИЙ ВИД: СЛЕД, ЗОМБИ, VIP
---------------------------------------------------------------------
local function getAlive(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function applyTrail(player: Player)
	local character = player.Character
	local session = sessions[player]
	if not character or not session then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in ipairs({ "ZT_Trail", "ZT_TrailTop", "ZT_TrailBottom" }) do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local item = ITEM_BY_ID[session.profile.trail]
	if not item then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "ZT_TrailTop"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "ZT_TrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "ZT_Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = if item.id == "trail_rainbow"
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 100)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 255)),
		})
		else ColorSequence.new(item.colorA, item.colorB)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.Parent = root
end

local function setHighlight(character: Model, fill: Color3?, outline: Color3?, onTop: boolean)
	local old = character:FindFirstChild("ZT_Highlight")
	if old then
		old:Destroy()
	end
	if not fill or not outline then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ZT_Highlight"
	highlight.FillColor = fill
	highlight.OutlineColor = outline
	highlight.FillTransparency = 0.4
	highlight.DepthMode = if onTop then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
end

-- щит: светящийся шар вокруг персонажа
local function setShield(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("ZT_Shield")
	if on and not old then
		local field = Instance.new("ForceField")
		field.Name = "ZT_Shield"
		field.Visible = true
		field.Parent = character
	elseif not on and old then
		old:Destroy()
	end
end

-- скорость зомби-игрока: гигант медленнее, в "ярости" все быстрее,
-- а оглушённый, только что заражённый и ещё не проснувшийся зомби стоит на месте
local function zombieSpeed(session: Session?): number
	if botsFrozen or (session ~= nil and os.clock() < session.stunUntil) then
		return 0
	end
	return ZOMBIE_SPEED + (if roundEvent == "rage" then 1.5 else 0) - (if session and session.giant then 1 else 0)
end

-- приводит персонажа в вид, который подходит его роли
local function applyLook(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local session = sessions[player]
	local inGame = roundActive and inRound[player] == true
	-- во время раунда имена над головами скрыты: иначе спрятаться не получится
	local hideName = inGame and HIDE_NAMES
	if humanoid then
		humanoid.DisplayDistanceType = if hideName then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
	local head = character:FindFirstChild("Head")
	local vipTag = if head then head:FindFirstChild("ZT_Tag") else nil
	if vipTag and vipTag:IsA("BillboardGui") then
		vipTag.Enabled = not hideName
	end
	if not inGame or isZombie[player] then
		if session then
			session.shield = false
		end
		setShield(player, false)
	end
	-- событие раунда: надпись, фонарик в темноте, высокие прыжки на "луне", рост гиганта
	local hud = huds[player]
	if hud then
		hud.event.Text = if inGame and roundEvent ~= "" then tr(player, "ev_" .. roundEvent) .. (if roundEvent == RULES.week then "  ⭐ +50% 💰" else "") else ""
	end
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if inGame and roundEvent == "moon" then 20 else 7.2
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local lamp = if root then root:FindFirstChild("ZT_Light") else nil
	if inGame and roundEvent == "dark" then
		if root and not lamp then
			local light = Instance.new("SpotLight")
			light.Name = "ZT_Light"
			light.Range = 45
			light.Angle = 75
			light.Brightness = 3
			light.Face = Enum.NormalId.Front
			light.Parent = root
		end
	elseif lamp then
		lamp:Destroy()
	end
	if session and session.giant then
		-- гигант остаётся гигантом и после возрождения, а после раунда снова становится обычным
		local big = inGame and isZombie[player] == true
		session.giant = big
		pcall(function()
			character:ScaleTo(if big then 1.6 else 1)
		end)
	end
	if inGame then
		if isZombie[player] then
			local item = if session then ITEM_BY_ID[session.profile.skin] else nil
			if item and item.kind == "skin" then
				setHighlight(character, item.colorA, item.colorB, false)
			else
				setHighlight(character, DEFAULT_ZOMBIE_FILL, DEFAULT_ZOMBIE_OUTLINE, false)
			end
			if humanoid then
				humanoid.WalkSpeed = zombieSpeed(session)
			end
			setRole(player, "role_zombie", Color3.fromRGB(110, 255, 110))
		else
			setHighlight(character, nil, nil, false)
			if humanoid then
				humanoid.WalkSpeed = SURVIVOR_SPEED
			end
			setRole(player, "role_survivor", Color3.fromRGB(255, 255, 255))
		end
	else
		setHighlight(character, nil, nil, false)
		if humanoid then
			humanoid.WalkSpeed = SURVIVOR_SPEED
		end
		setRole(player, "", Color3.fromRGB(255, 255, 255))
	end
end

-- табличка над головой: уровень игрока, а у владельцев VIP ещё и золотая надпись VIP
applyVipTag = function(player: Player)
	local character = player.Character
	local session = sessions[player]
	local head = if character then character:FindFirstChild("Head") else nil
	if not head or not session then
		return
	end
	local existing = head:FindFirstChild("ZT_Tag")
	local billboard: Instance
	if existing then
		billboard = existing
	else
		local created = Instance.new("BillboardGui")
		created.Name = "ZT_Tag"
		created.Size = UDim2.fromScale(5, 1)
		created.StudsOffset = Vector3.new(0, 2.6, 0)
		created.MaxDistance = 60
		created.Enabled = not (HIDE_NAMES and roundActive and inRound[player] == true)
		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.Parent = created
		created.Parent = head
		billboard = created
	end
	local label = billboard:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = (if session.vip then "VIP  " else "") .. "LVL " .. levelOf(session.profile.xp)
		label.TextColor3 = if session.vip then Color3.fromRGB(255, 215, 70) else Color3.fromRGB(235, 240, 245)
	end
end

---------------------------------------------------------------------
-- МАГАЗИН И ПОКУПКИ ЗА ROBUX
---------------------------------------------------------------------
shopHandler = function(player: Player, item: ShopItem)
	local session = sessions[player]
	if not session then
		return
	end
	local profile = session.profile
	if not profile.owned[item.id] then
		if item.days then
			toast(player, "prize_need", item.days)
			playSound(player, "deny")
			return
		end
		if levelOf(profile.xp) < (item.level or 0) then
			toast(player, "need_level", item.level or 0)
			playSound(player, "deny")
			return
		end
		if profile.coins < item.price then
			toast(player, "need_more", item.price - profile.coins)
			playSound(player, "deny")
			return
		end
		profile.coins -= item.price
		profile.owned[item.id] = true
		session.bought = os.clock()
		if item.kind == "trail" then
			profile.trail = item.id
		else
			profile.skin = item.id
		end
		syncStats(player)
		toast(player, "bought", itemName(player, item))
		playSound(player, "buy")
	else
		local current = if item.kind == "trail" then profile.trail else profile.skin
		if current == item.id and os.clock() - (session.bought or 0) < 2 then return end
		local nextValue = if current == item.id then "" else item.id
		if item.kind == "trail" then
			profile.trail = nextValue
		else
			profile.skin = nextValue
		end
		toast(player, if nextValue == "" then "unequipped" else "equipped", itemName(player, item))
		playSound(player, "coin")
	end
	refreshShop(player)
	applyTrail(player)
	applyLook(player)
end

vipHandler = function(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.vip then
		toast(player, "vip_on")
		return
	end
	session.vipAsk = os.clock()
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, VIP_GAMEPASS_ID)
	end)
end

coinsHandler = function(player: Player, productId: number)
	local session = sessions[player]
	-- пока прогресс не сохраняется, покупку не предлагаем: монеты могли бы пропасть
	if session and store ~= nil and not session.canSave and not RunService:IsStudio() then
		toast(player, "no_save")
		playSound(player, "deny")
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

if VIP_GAMEPASS_ID > 0 then
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local session = sessions[player]
		-- VIP выдаётся сразу после покупки. Засчитывается только ответ на окно, которое сервер
		-- сам открыл этому игроку у витрины; при следующем входе покупку подтверждает сам Roblox.
		if purchased and passId == VIP_GAMEPASS_ID and session and not session.vip
			and session.vipAsk > 0 and os.clock() - session.vipAsk < 900 then
			session.vipAsk = 0
			session.vip = true
			applyVipTag(player)
			refreshVip(player)
			toast(player, "vip_on")
		end
	end)
end

-- сколько монет даёт каждый набор
local coinsByProduct: { [number]: number } = {}
for _, product in ipairs(COIN_PRODUCTS) do
	if product.id > 0 then
		coinsByProduct[product.id] = product.coins
	end
end

if next(coinsByProduct) ~= nil then
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		-- прогресс игрока может ещё загружаться: немного ждём
		local deadline = os.clock() + 35
		while player and player.Parent == Players and not sessions[player] and os.clock() < deadline do
			task.wait(0.5)
		end
		local session = if player then sessions[player] else nil
		local coins = coinsByProduct[receipt.ProductId]
		if not player or not session or not coins then
			-- Roblox повторит покупку при следующем входе, и она не пропадёт
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local studio = RunService:IsStudio()
		if store ~= nil and not session.canSave and not studio then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- номер покупки записывается в прогресс вместе с монетами: дважды одну покупку не выдать
		local profile = session.profile
		local purchaseId = tostring(receipt.PurchaseId)
		if not table.find(profile.receipts, purchaseId) then
			profile.coins += coins
			table.insert(profile.receipts, purchaseId)
			if #profile.receipts > 40 then
				table.remove(profile.receipts, 1)
			end
			syncStats(player)
			toast(player, "bought_coins", coins)
			playSound(player, "buy")
		end
		-- покупка подтверждается, только когда монеты точно сохранились
		local saved = store == nil or studio
		for attempt = 1, 3 do
			if saved or sessions[player] ~= session or not session.canSave then
				break
			end
			if attempt > 1 then
				task.wait(1)
			end
			saved = saveProfile(player)
		end
		if saved then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

---------------------------------------------------------------------
-- ПОМОЩНИКИ РАУНДА
---------------------------------------------------------------------
local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		Guard.allow(player, position)
		character:PivotTo(CFrame.new(position))
	end
end

local function randomSpawn(): Vector3
	return citySpawns[gameRng:NextInteger(1, #citySpawns)]
end

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = gameRng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function getReadyPlayers(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local session = sessions[player]
		local root = getAlive(player)
		-- кто стоит в зоне магазина, тот пропускает раунд (кроме новичка: первый раунд играют все)
		if session and root and not (session.profile.rounds > 0 and inShopZone(root.Position)) and not Guard.stay(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function formatTime(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function roundPlayers(): ({ Player }, { Player })
	local zombies: { Player } = {}
	local survivors: { Player } = {}
	for player in pairs(inRound) do
		if isZombie[player] then
			table.insert(zombies, player)
		else
			table.insert(survivors, player)
		end
	end
	return zombies, survivors
end

local function infect(player: Player, catcher: Player?)
	if not inRound[player] or isZombie[player] then
		return
	end
	isZombie[player] = true
	local infected = sessions[player]
	if infected then
		-- превращение: у соседей есть время убежать
		infected.stunUntil = os.clock() + RULES.infectStun
	end
	applyLook(player)
	flashScreen(player)
	toast(player, "you_infected")
	playSound(player, "infected")
	if catcher then
		rewardCatch(catcher, COINS.infect)
	end
	for other in pairs(inRound) do
		if other ~= player and other ~= catcher then
			if catcher then
				toast(other, "caught", catcher.DisplayName, player.DisplayName)
			else
				toast(other, "caught_by_bot", player.DisplayName)
			end
		end
	end
end

---------------------------------------------------------------------
-- МОНЕТЫ И УСКОРЕНИЯ НА УЛИЦАХ
---------------------------------------------------------------------
local function randomRoadPoint(): Vector3
	local point = Vector3.new(0, GROUND_TOP + 2.5, 0)
	for _ = 1, 12 do
		local road = ROAD_CENTERS[gameRng:NextInteger(1, #ROAD_CENTERS)] + gameRng:NextNumber(-5, 5)
		local along = gameRng:NextNumber(-CITY_HALF + 15, CITY_HALF - 15)
		if gameRng:NextNumber() < 0.5 then
			point = Vector3.new(road, GROUND_TOP + 2.5, along)
		else
			point = Vector3.new(along, GROUND_TOP + 2.5, road)
		end
		-- не кладём монету внутрь машины или заграждения
		local free = true
		for _, obstacle in ipairs(roadObstacles) do
			if math.abs(obstacle.X - point.X) < 14 and math.abs(obstacle.Z - point.Z) < 14 then
				free = false
				break
			end
		end
		if free then
			break
		end
	end
	return point
end

local function spawnPickup(kind: string)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	if kind == "coin" then
		part.Name = "CoinPickup"
		part.Size = Vector3.new(2, 2, 2)
		part.Color = Color3.fromRGB(255, 215, 50)
	elseif kind == "boost" then
		part.Name = "BoostPickup"
		part.Size = Vector3.new(2.8, 2.8, 2.8)
		part.Color = Color3.fromRGB(60, 200, 255)
	else
		part.Name = "ShieldPickup"
		part.Size = Vector3.new(3.4, 3.4, 3.4)
		part.Color = Color3.fromRGB(190, 110, 255)
	end
	-- не кладём два предмета рядом друг с другом
	local position = randomRoadPoint()
	for _ = 1, 6 do
		local crowded = false
		for _, other in ipairs(pickups) do
			if (other.part.Position - position).Magnitude < 12 then
				crowded = true
				break
			end
		end
		if not crowded then
			break
		end
		position = randomRoadPoint()
	end
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.5
	light.Color = part.Color
	light.Parent = part
	if kind ~= "coin" then
		-- значок над ускорением и щитом: их легко отличить не только по цвету
		local mark = Instance.new("BillboardGui")
		mark.Size = UDim2.fromScale(3, 3)
		mark.StudsOffset = Vector3.new(0, 3.2, 0)
		mark.MaxDistance = 70
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextStrokeTransparency = 0
		icon.Text = if kind == "boost" then "»" else "+"
		icon.Parent = mark
		mark.Parent = part
	end
	part.Parent = pickupFolder
	table.insert(pickups, { part = part, kind = kind })
end

local function clearPickups()
	for _, pickup in ipairs(pickups) do
		pickup.part:Destroy()
	end
	table.clear(pickups)
end

local function collectPickups(survivors: { Player })
	if #pickups == 0 then
		return
	end
	for _, survivor in ipairs(survivors) do
		local root, humanoid = getAlive(survivor)
		local session = sessions[survivor]
		-- того, кого только что заразили, пропускаем: зомби предметы не подбирают
		if root and humanoid and session and not isZombie[survivor] and Guard.ok(survivor) then
			for index = #pickups, 1, -1 do
				local pickup = pickups[index]
				-- второй щит взять нельзя, пока цел первый
				if (pickup.part.Position - root.Position).Magnitude <= 4.5 and not (pickup.kind == "shield" and session.shield)
					and not (pickup.kind == "coin" and session.picked >= RULES.pickupCap) then
					table.remove(pickups, index)
					pickup.part:Destroy()
					local kind = pickup.kind
					if kind == "coin" then
						-- за раунд с улицы можно собрать не больше RULES.pickupCap монет (лишние остаются лежать)
						session.picked += 1
						award(survivor, COINS.pickup)
						Quest.add(survivor, "coins", 1)
						playSound(survivor, "coin")
					elseif kind == "boost" then
						session.boostUntil = os.clock() + BOOST_TIME
						humanoid.WalkSpeed = BOOST_SPEED
						toast(survivor, "boost")
						playSound(survivor, "boost")
					else
						session.shield = true
						setShield(survivor, true)
						toast(survivor, "shield_on")
						playSound(survivor, "shield")
					end
					local myRound = roundId
					task.delay(if kind == "shield" then 20 else 8, function()
						if roundActive and roundId == myRound then
							spawnPickup(kind)
						end
					end)
				end
			end
		end
	end
end

-- возвращает обычную скорость, когда закончилось ускорение или оглушение
local function updateSpeeds(zombies: { Player }, survivors: { Player })
	local now = os.clock()
	for _, survivor in ipairs(survivors) do
		local session = sessions[survivor]
		if session and session.boostUntil > 0 and now >= session.boostUntil then
			session.boostUntil = 0
			local _, humanoid = getAlive(survivor)
			if humanoid and not isZombie[survivor] then
				humanoid.WalkSpeed = SURVIVOR_SPEED
			end
		end
	end
	for _, zombie in ipairs(zombies) do
		local session = sessions[zombie]
		if session and session.stunUntil > 0 and now >= session.stunUntil then
			session.stunUntil = 0
			local _, humanoid = getAlive(zombie)
			if humanoid and isZombie[zombie] then
				humanoid.WalkSpeed = zombieSpeed(session)
			end
		end
	end
end

---------------------------------------------------------------------
-- БОТЫ: ЖИТЕЛИ И ЗОМБИ
-- Когда игроков мало, город заполняют боты. Жители убегают от зомби,
-- а пойманный житель сам становится зомби и начинает ловить остальных.
---------------------------------------------------------------------
local function botPresent(bot: Bot): boolean
	return bot.alive and bot.model:IsDescendantOf(workspace)
end

local function flatDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Остальное про ботов тоже спрятано в блок do ... end (см. пояснение у постройки карты).
-- Наружу из блока выходит только это:
local wallBetween: (a: Vector3, b: Vector3) -> boolean
local zombieSpawn: () -> Vector3
local botCanReach: (botPosition: Vector3, targetPosition: Vector3, reach: number?) -> boolean
local infectBot: (bot: Bot, catcher: Player?) -> ()
local spawnBot: (asZombie: boolean, position: Vector3?) -> boolean
local clearBots: () -> ()

do -- НАЧАЛО БЛОКА БОТОВ

-- ЧТО ВИДНО, А ЧТО НЕТ
local sightParams = RaycastParams.new() -- обзор закрывают дома, машины, ящики и кусты
sightParams.FilterType = Enum.RaycastFilterType.Include
sightParams.FilterDescendantsInstances = { city, hideFolder }
local solidParams = RaycastParams.new() -- а поймать мешают только настоящие стены
solidParams.FilterType = Enum.RaycastFilterType.Include
solidParams.FilterDescendantsInstances = { city }
solidParams.RespectCanCollide = true

-- видно ли из точки from точку to
local function canSee(from: Vector3, to: Vector3): boolean
	return workspace:Raycast(from, to - from, sightParams) == nil
end

-- есть ли преграда между двумя точками (через стену, пол и крышу заразить нельзя)
wallBetween = function(a: Vector3, b: Vector3): boolean
	local function blocked(from: Vector3, to: Vector3): boolean
		for _ = 1, 3 do
			local hit = workspace:Raycast(from, to - from, solidParams)
			if not hit then
				return false
			end
			-- лестница не считается стеной: того, кто висит на лестнице, поймать можно.
			-- Но за лестницей может быть стена, поэтому луч идёт дальше сквозь неё.
			if not hit.Instance:IsA("TrussPart") or (to - hit.Position).Magnitude < 0.2 then
				return not hit.Instance:IsA("TrussPart")
			end
			from = hit.Position + (to - from).Unit * 0.01
		end
		return false
	end
	if math.abs(a.Y - b.Y) <= 3 then
		return blocked(a, b)
	end
	-- цель выше или ниже: тянемся сначала вверх (вниз), потом вбок, или наоборот. Так можно достать
	-- того, кто залез на машину или ящик (или стоит под ящиком, на котором зомби),
	-- но не того, кто стоит на крыше над головой или этажом ниже.
	local upFirst = Vector3.new(a.X, b.Y, a.Z)
	local sideFirst = Vector3.new(b.X, a.Y, b.Z)
	return (blocked(a, upFirst) or blocked(upFirst, b)) and (blocked(a, sideFirst) or blocked(sideFirst, b))
end

-- ближайший выживший: игрок или житель-бот
local function nearestSurvivorRoot(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for player in pairs(inRound) do
		if not isZombie[player] then
			local root = getAlive(player)
			if root then
				local distance = (root.Position - from).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = root
				end
			end
		end
	end
	for _, bot in ipairs(bots) do
		if not bot.zombie and botPresent(bot) then
			local distance = (bot.root.Position - from).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = bot.root
			end
		end
	end
	return best
end

-- ближайший зомби (игрок или бот): где он и как далеко
local function nearestZombie(from: Vector3): (Vector3?, number)
	local best: Vector3? = nil
	local bestDistance = math.huge
	for player in pairs(inRound) do
		if isZombie[player] then
			local root = getAlive(player)
			if root then
				local distance = (root.Position - from).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = root.Position
				end
			end
		end
	end
	for _, bot in ipairs(bots) do
		if bot.zombie and botPresent(bot) then
			local distance = (bot.root.Position - from).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = bot.root.Position
			end
		end
	end
	return best, bestDistance
end

-- точка появления для зомби: как можно дальше от выживших, чтобы не ловить их сразу
zombieSpawn = function(): Vector3
	local bestSpawn = randomSpawn()
	local bestDistance = -1
	for _ = 1, 8 do
		local candidate = randomSpawn()
		local nearest = nearestSurvivorRoot(candidate)
		local distance = if nearest then (nearest.Position - candidate).Magnitude else 999
		if distance > bestDistance then
			bestDistance = distance
			bestSpawn = candidate
		end
	end
	return bestSpawn
end

-- бот достаёт выжившего рядом с собой, даже если тот залез на машину или ящик (но не через стену)
botCanReach = function(botPosition: Vector3, targetPosition: Vector3, reach: number?): boolean
	return flatDistance(botPosition, targetPosition) <= (reach or INFECT_DISTANCE)
		and math.abs(botPosition.Y - targetPosition.Y) <= 6.5
		and not wallBetween(botPosition, targetPosition)
end

-- Кого замечает зомби-бот. Он видит тех, кто не закрыт стеной или кустом, слышит тех,
-- кто бежит рядом, а того, кто затаился, находит только вплотную.
-- Жители прятаться не умеют: они шумят, и зомби слышит их так же далеко, как они замечают его.
-- Возвращает ближайшего замеченного выжившего (игрока или жителя).
local function senseTarget(bot: Bot): BasePart?
	local from = bot.root.Position
	local eye = from + Vector3.new(0, 1.5, 0)
	local best: BasePart? = nil
	local bestDistance = math.huge
	-- в тумане и в темноте зомби видит хуже
	local sight = BOT_SIGHT * (if roundEvent == "fog" then 0.5 elseif roundEvent == "dark" then 0.6 else 1)
	local function consider(root: BasePart, noise: number)
		local position = root.Position
		local distance = (position - from).Magnitude
		if distance >= bestDistance then
			return
		end
		if finalHunt or distance <= BOT_SMELL or distance <= noise
			or (distance <= sight and canSee(eye, position)) then
			best = root
			bestDistance = distance
		end
	end
	for player in pairs(inRound) do
		if not isZombie[player] then
			local root = getAlive(player)
			if root then
				consider(root, math.max(Guard.lure(player), if root.AssemblyLinearVelocity.Magnitude < 3 then 0 else BOT_HEARING))
			end
		end
	end
	for _, other in ipairs(bots) do
		if not other.zombie and botPresent(other) then
			consider(other.root, CITIZEN_SIGHT)
		end
	end
	return best
end

-- Зомби, которого заметил житель: зомби-ботов он видит издалека, а зомби-игрок может подкрасться ближе.
local function citizenThreat(from: Vector3): (Vector3?, number)
	local best: Vector3? = nil
	local bestDistance = math.huge
	for player in pairs(inRound) do
		if isZombie[player] then
			local root = getAlive(player)
			if root then
				local distance = (root.Position - from).Magnitude
				if distance < CITIZEN_SIGHT_PLAYER and distance < bestDistance then
					bestDistance = distance
					best = root.Position
				end
			end
		end
	end
	for _, bot in ipairs(bots) do
		if bot.zombie and botPresent(bot) then
			local distance = (bot.root.Position - from).Magnitude
			if distance < CITIZEN_SIGHT and distance < bestDistance then
				bestDistance = distance
				best = bot.root.Position
			end
		end
	end
	return best, bestDistance
end

local SKIN_COLORS = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 95, 53),
	Color3.fromRGB(255, 204, 153),
}
local SHIRT_COLORS = {
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(60, 110, 200),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(230, 230, 235),
	Color3.fromRGB(150, 90, 200),
	Color3.fromRGB(240, 140, 60),
}
local PANTS_COLORS = {
	Color3.fromRGB(50, 60, 90),
	Color3.fromRGB(40, 40, 45),
	Color3.fromRGB(90, 70, 50),
}
local ZOMBIE_SKIN = Color3.fromRGB(95, 160, 80)

-- красит фигурку бота: кожа, рубашка, штаны (nil - не трогать)
local function paintRig(model: Model, skin: Color3?, shirt: Color3?, pants: Color3?)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			local name = child.Name
			if string.find(name, "Torso") then
				if shirt then
					child.Color = shirt
				end
			elseif string.find(name, "Leg") or string.find(name, "Foot") then
				if pants then
					child.Color = pants
				end
			elseif skin then
				child.Color = skin
			end
		end
	end
end

-- заготовка фигурки: создаётся один раз, потом копируется для каждого бота
local rigTemplate: Model? = nil

local function getRig(): Model?
	if not rigTemplate then
		local created: Model? = nil
		local ok, model = pcall(function(): Model
			return Players:CreateHumanoidModelFromDescriptionAsync(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			created = model
		else
			-- запасной способ: копия персонажа одного из игроков
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character and getAlive(player) and not created then
					local cloneOk, clone = pcall(function(): Model?
						character.Archivable = true
						return character:Clone()
					end)
					if cloneOk and clone then
						created = clone
					end
				end
			end
		end
		if created then
			for _, descendant in ipairs(created:GetDescendants()) do
				if descendant:IsA("LuaSourceContainer") or descendant:IsA("Highlight") or descendant:IsA("Trail")
					or descendant:IsA("BillboardGui") or descendant:IsA("BodyColors") then
					descendant:Destroy()
				end
			end
			rigTemplate = created
		end
	end
	local template = rigTemplate
	return if template then template:Clone() else nil
end

-- житель заразился и стал зомби
infectBot = function(bot: Bot, catcher: Player?)
	if bot.zombie then
		return
	end
	bot.zombie = true
	bot.model.Name = "Zombie"
	-- превращение: пару секунд новый зомби стоит на месте, и у соседей есть время убежать
	bot.stunUntil = os.clock() + BOT_TURN_TIME
	bot.humanoid.WalkSpeed = 0
	paintRig(bot.model, ZOMBIE_SKIN, nil, nil)
	setHighlight(bot.model, DEFAULT_ZOMBIE_FILL, DEFAULT_ZOMBIE_OUTLINE, false)
	if catcher then
		rewardCatch(catcher, COINS.infectBot)
	end
end

-- точка на крыше или площадке, куда бот может запрыгнуть за выжившим
local function leapPoint(target: Vector3): Vector3?
	local feetY = target.Y - 3
	local best: Vector3? = nil
	local bestDistance = math.huge
	local nearest: Vector3? = nil
	local nearestDistance = math.huge
	for _, anchor in ipairs(roofAnchors) do
		if math.abs(anchor.Y - feetY) <= 5 then
			local distance = flatDistance(anchor, target)
			if distance < nearestDistance then
				nearest = anchor
				nearestDistance = distance
			end
			-- лучше приземлиться не вплотную к игроку, чтобы у него был шанс убежать
			if distance >= 8 and distance < bestDistance then
				best = anchor
				bestDistance = distance
			end
		end
	end
	if best and bestDistance <= 50 then
		return best
	end
	if nearest and nearestDistance <= 20 then
		return nearest
	end
	return nil
end

-- в каком по счёту квартале находится точка (по одной оси)
local function blockIndex(value: number): number
	return math.floor((value - BLOCK_CENTERS[1]) / 60 + 0.5)
end

-- лестница, по которой удобнее всего добраться до выжившего наверху
local function bestLadder(from: Vector3, target: Vector3): LadderInfo?
	local feetY = target.Y - 3
	local best: LadderInfo? = nil
	local bestCost = math.huge
	for _, info in ipairs(ladders) do
		if math.abs(info.top.Y - feetY) <= 6 and info.bottom.Y < from.Y + 2 then
			local top = info.top
			-- лестница должна вести туда же, где стоит выживший: на крышу в том же квартале
			-- или на ту же железную дорогу (иначе бот залезет на соседний дом)
			local sameBlock = blockIndex(top.X) == blockIndex(target.X) and blockIndex(top.Z) == blockIndex(target.Z)
			local sameRail = math.abs(top.Z - RAIL_Z) < 5 and math.abs(target.Z - RAIL_Z) < 5 and flatDistance(top, target) <= 90
			local cost = flatDistance(from, info.bottom) + flatDistance(top, target)
			if (sameBlock or sameRail) and cost < bestCost then
				best = info
				bestCost = cost
			end
		end
	end
	return best
end

-- куда бежать жителю: к соседнему перекрёстку, подальше от зомби и от других жителей
local function fleePoint(from: Vector3, threat: Vector3?): Vector3
	local best = randomSpawn()
	local bestScore = -math.huge
	for _, spot in ipairs(citySpawns) do
		local away = flatDistance(spot, from)
		if away > 20 and away < 95 then
			local score = gameRng:NextNumber(0, 30)
			if threat then
				local _, zombieDistance = nearestZombie(spot)
				score += math.min(zombieDistance, 120)
				-- точки в сторону зомби почти не выбираем
				local toSpotX, toSpotZ = spot.X - from.X, spot.Z - from.Z
				local toThreatX, toThreatZ = threat.X - from.X, threat.Z - from.Z
				local threatLength = math.sqrt(toThreatX * toThreatX + toThreatZ * toThreatZ)
				if threatLength > 0.1 and (toSpotX * toThreatX + toSpotZ * toThreatZ) / (away * threatLength) > 0.5 then
					score -= 80
				end
			end
			-- жители не сбиваются в кучу: иначе зомби ловят всех разом
			for _, other in ipairs(bots) do
				if not other.zombie and botPresent(other) and flatDistance(other.root.Position, from) > 3
					and flatDistance(other.root.Position, spot) < 30 then
					score -= 25
				end
			end
			if score > bestScore then
				best = spot
				bestScore = score
			end
		end
	end
	return best
end

-- ближайшее укрытие рядом с точкой: туда зомби-бот заглядывает, когда потерял выжившего из виду
local function nearestHideSpot(from: Vector3, maxDistance: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = maxDistance
	for _, spot in ipairs(hideSpots) do
		local distance = flatDistance(spot, from)
		if distance > 6 and distance < bestDistance then
			best = spot
			bestDistance = distance
		end
	end
	return best
end

-- куда идти зомби-боту, пока он никого не видит: на перекрёсток или проверить укрытие
local function patrolPoint(from: Vector3): Vector3
	if #hideSpots > 0 and gameRng:NextNumber() < 0.35 then
		for _ = 1, 6 do
			local spot = hideSpots[gameRng:NextInteger(1, #hideSpots)]
			local away = flatDistance(spot, from)
			if away > 10 and away < 130 then
				return spot
			end
		end
	end
	for _ = 1, 6 do
		local spot = randomSpawn()
		local away = flatDistance(spot, from)
		if away > 30 and away < 140 then
			return spot
		end
	end
	return randomSpawn()
end

-- крыша или площадка неподалёку, которую бродящий зомби-бот может проверить
local function roofToCheck(from: Vector3): Vector3?
	for _ = 1, 8 do
		local anchor = roofAnchors[gameRng:NextInteger(1, #roofAnchors)]
		local away = flatDistance(anchor, from)
		if anchor.Y > from.Y + 5 and away > 15 and away < 110 then
			return anchor
		end
	end
	return nil
end

-- перекрёсток, ближайший к точке: оттуда зомби запрыгивает на крышу
local function nearestCrossing(point: Vector3): Vector3
	local best = citySpawns[1]
	local bestDistance = math.huge
	for _, spot in ipairs(citySpawns) do
		local distance = flatDistance(spot, point)
		if distance < bestDistance then
			best = spot
			bestDistance = distance
		end
	end
	return best
end

-- куда выбраться застрявшему боту: на ближайший перекрёсток, где рядом нет выживших
local function escapePoint(from: Vector3): Vector3
	local best = nearestCrossing(from)
	local bestDistance = math.huge
	for _, spot in ipairs(citySpawns) do
		local distance = flatDistance(spot, from)
		if distance < bestDistance then
			local survivor = nearestSurvivorRoot(spot)
			if not survivor or flatDistance(survivor.Position, spot) > 25 then
				best = spot
				bestDistance = distance
			end
		end
	end
	return best
end

-- дальняя точка на той же крыше: зомби проходит крышу насквозь и осматривает её
local function acrossRoof(anchor: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = 6
	for _, other in ipairs(roofAnchors) do
		local distance = flatDistance(other, anchor)
		if math.abs(other.Y - anchor.Y) < 1 and distance > bestDistance and distance < 60 then
			best = other
			bestDistance = distance
		end
	end
	return best
end

local function runBot(bot: Bot, myRound: number)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		Costs = { Climb = 3 },
	})
	local lastPosition = bot.root.Position
	local stuckTime = 0
	local belowTime = 0
	local lastLeap = -100
	local lastChase = -100 -- когда зомби в последний раз запрыгивал за выжившим
	local lastTick = os.clock()
	local fleeGoal: Vector3? = nil
	local fleeUntil = 0
	local lastSeen: Vector3? = nil   -- где зомби в последний раз видел выжившего
	local lastSeenUntil = 0
	local wanderGoal: Vector3? = nil -- куда зомби бредёт, пока никого не видит
	local wanderUntil = 0
	local wanderRoof: Vector3? = nil -- крыша, которую зомби идёт проверить

	local function active(): boolean
		return botPresent(bot) and roundActive and roundId == myRound
	end

	-- идём по найденному пути примерно duration секунд; false, если пути нет
	local function followPath(goal: Vector3, duration: number): boolean
		local from = bot.root.Position
		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return false
		end
		local legStart = os.clock()
		local followed = false
		local waypoints = path:GetWaypoints()
		for index = 2, #waypoints do
			local waypoint = waypoints[index]
			local point = waypoint.Position
			-- точка намного выше ног бота: значит, это подъём по лестнице
			local climbing = point.Y - (bot.root.Position.Y - 3) > 5
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				bot.humanoid.Jump = true
			end
			bot.humanoid:MoveTo(point)
			followed = true
			local stepStart = os.clock()
			local stepLimit = if climbing then 3 + (point.Y - bot.root.Position.Y) / 5 else 0.8
			local lastOrder = stepStart
			while active() and os.clock() - stepStart < stepLimit do
				local position = bot.root.Position
				if flatDistance(position, point) <= 2 and (not climbing or math.abs(position.Y - 3 - point.Y) <= 3) then
					break
				end
				if os.clock() - lastOrder > 2 then
					lastOrder = os.clock()
					bot.humanoid:MoveTo(point)
				end
				task.wait(0.05)
			end
			if climbing or os.clock() - legStart >= duration then
				break
			end
		end
		return followed
	end

	-- если бот упёрся во что-то и не двигается, он прыгает;
	-- а если застрял всерьёз и прыжки не помогают, выбирается на ближайший перекрёсток
	local stuckTotal = 0
	local function checkStuck(legStart: number)
		local waited = math.max(os.clock() - legStart, 0.05)
		if (bot.root.Position - lastPosition).Magnitude < 2 * waited then
			stuckTime += waited
			stuckTotal += waited
			if stuckTotal >= 5 then
				bot.model:PivotTo(CFrame.new(escapePoint(bot.root.Position)))
				stuckTotal = 0
				stuckTime = 0
			elseif stuckTime >= 1 then
				bot.humanoid.Jump = true
				stuckTime = 0
			end
		else
			stuckTime = 0
			stuckTotal = 0
		end
		lastPosition = bot.root.Position
	end

	local giantPath = false
	while active() do
		local tickTime = os.clock()
		local delta = tickTime - lastTick
		if bot.giant and not giantPath then
			-- гиганту нужен свой маршрут: в узкие двери и под навесы он не пролезает
			giantPath = true
			path = PathfindingService:CreatePath({ AgentRadius = 4, AgentHeight = 10, AgentCanJump = true, Costs = { Climb = 3 } })
		end
		lastTick = tickTime
		local from = bot.root.Position

		if not bot.zombie then
			-- ЖИТЕЛЬ: убегает от ближайшего зомби, а когда спокойно, гуляет по улицам
			local threat, threatDistance = citizenThreat(from)
			local scared = threat ~= nil
			bot.humanoid.WalkSpeed = if scared then bot.speed else 9
			local current = fleeGoal
			local goal: Vector3
			if current == nil or flatDistance(from, current) < 6 or tickTime > fleeUntil
				or (scared and threat ~= nil and flatDistance(current, threat) < threatDistance * 0.8) then
				-- цели нет, дошли до неё или она оказалась в стороне зомби: выбираем новую
				goal = fleePoint(from, if scared then threat else nil)
				fleeGoal = goal
				fleeUntil = tickTime + 10
			else
				goal = current
			end
			goal = Guard.goal(bot, from, goal)
			if not followPath(goal, 0.6) then
				bot.humanoid:MoveTo(goal)
				task.wait(0.3)
			end
			if not active() then
				break
			end
			checkStuck(tickTime)
			continue
		end

		-- ЗОМБИ: гонится за тем, кого заметил; если никого не видно, ищет
		if botsFrozen or tickTime < bot.stunUntil then
			task.wait(0.25)
			continue
		end
		local target = senseTarget(bot)
		local seen = lastSeen
		local targetPosition: Vector3
		if target then
			targetPosition = target.Position
			lastSeen = targetPosition
			lastSeenUntil = tickTime + (if targetPosition.Y - from.Y > 6.5 then BOT_MEMORY_ROOF else BOT_MEMORY)
		elseif seen and tickTime < lastSeenUntil and (flatDistance(from, seen) > 5 or seen.Y - from.Y > 6.5) then
			-- потерял из виду: бежит (или лезет) туда, где видел выжившего в последний раз
			targetPosition = seen
		else
			-- никого не видно: ищет
			belowTime = 0
			if seen then
				-- добежал, а там никого: заглядывает в ближайшее укрытие
				lastSeen = nil
				wanderRoof = nil
				wanderGoal = nearestHideSpot(from, 45)
				wanderUntil = tickTime + 10
			end
			local current = wanderGoal
			local roof = wanderRoof
			if roof and current and (flatDistance(from, current) < 6 or tickTime > wanderUntil) then
				-- дошёл до перекрёстка у дома: запрыгивает на крышу и идёт по ней на другой край
				wanderRoof = nil
				current = nil
				if flatDistance(from, roof) < 60 and tickTime - lastLeap > 8 then
					bot.model:PivotTo(CFrame.new(roof + Vector3.new(0, 4, 0)))
					-- после любого прыжка зомби секунду стоит, приходит в себя и рычит
					bot.humanoid:MoveTo(bot.root.Position)
					bot.stunUntil = math.max(bot.stunUntil, tickTime + 1)
					Sfx.emit(bot.root, "w_growl1", 90, 1)
					lastLeap = tickTime
					stuckTime = 0
					lastPosition = bot.root.Position
					wanderGoal = acrossRoof(roof)
					wanderUntil = tickTime + 6
					task.wait(0.3)
					continue
				end
			end
			local wander: Vector3
			if current == nil or flatDistance(from, current) < 5 or tickTime > wanderUntil then
				local nextRoof = if gameRng:NextNumber() < BOT_ROOF_CHECK then roofToCheck(from) else nil
				if nextRoof then
					wander = nearestCrossing(nextRoof)
				else
					wander = patrolPoint(from)
				end
				wanderRoof = nextRoof
				wanderGoal = wander
				wanderUntil = tickTime + 14
			else
				wander = current
			end
			bot.humanoid.WalkSpeed = BOT_PATROL_SPEED
			if not followPath(wander, 0.6) then
				bot.humanoid:MoveTo(wander)
				task.wait(0.3)
			end
			if not active() then
				break
			end
			checkStuck(tickTime)
			continue
		end
		-- гигант медленнее, а в событии "ярость" все зомби быстрее
		bot.humanoid.WalkSpeed = (if bot.giant then BOT_SPEED - 2 else BOT_SPEED) + (if roundEvent == "rage" then 1 else 0)
		wanderGoal = nil
		wanderRoof = nil
		local goal = targetPosition

		if targetPosition.Y - from.Y > 6.5 then
			stuckTotal = 0 -- под крышей бот стоит нарочно: ждёт, чтобы запрыгнуть
			-- выживший наверху, а бот стоит рядом внизу: через несколько секунд он запрыгивает следом
			if flatDistance(targetPosition, from) < 30 then
				belowTime += delta
				-- в финальной охоте зомби запрыгивает наверх быстрее: на крыше уже не отсидеться
				local leapDelay = if finalHunt then 3 else BOT_LEAP_DELAY
				if belowTime >= leapDelay and tickTime - lastLeap > (if finalHunt then 4 else 8) then
					-- если недавний прыжок на крышу не помог (зомби снова внизу), он прыгает прямо к выжившему
					local retry = tickTime - lastChase < 25
					local landing = if retry then nil else leapPoint(targetPosition)
					local direct = false
					if not landing and (retry or belowTime >= leapDelay + 3) then
						-- выживший висит там, куда не запрыгнуть (например, на середине лестницы):
						-- зомби допрыгивает до него и зависает рядом (не внутри игрока)
						local side = Vector3.new(from.X - targetPosition.X, 0, from.Z - targetPosition.Z)
						side = if side.Magnitude > 0.5 then side.Unit * 3 else Vector3.new(3, 0, 0)
						landing = Vector3.new(targetPosition.X, targetPosition.Y - 3, targetPosition.Z) + side
						direct = true
					end
					if landing then
						if not direct then
							-- несколько зомби не приземляются в одну точку
							landing += Vector3.new(gameRng:NextNumber(-1, 1), 0, gameRng:NextNumber(-1, 1))
						end
						bot.model:PivotTo(CFrame.new(landing + Vector3.new(0, 4, 0)))
						bot.humanoid:MoveTo(bot.root.Position)
						lastChase = tickTime
						-- после прыжка зомби секунду приходит в себя и рычит: у выжившего есть время убежать
						bot.stunUntil = math.max(bot.stunUntil, tickTime + 1)
						if direct then
							-- рядом с выжившим зомби на эту секунду зависает на месте, чтобы не упасть
							bot.root.Anchored = true
							task.delay(1, function()
								if botPresent(bot) then
									bot.root.Anchored = false
									pcall(function()
										bot.root:SetNetworkOwner(nil)
									end)
								end
							end)
						end
						Sfx.emit(bot.root, "w_growl1", 90, 1)
						lastLeap = tickTime
						belowTime = 0
						stuckTime = 0
						lastPosition = bot.root.Position
						task.wait(0.3)
						continue
					end
				end
			else
				belowTime = 0
			end
			-- а пока пробует подняться по лестнице
			local info = bestLadder(from, targetPosition)
			if info then
				if flatDistance(from, info.bottom) > 1.5 or math.abs(from.Y - 3 - info.bottom.Y) > 4 then
					-- сначала встаёт ровно перед лестницей: сбоку за неё не зацепиться
					goal = info.bottom + Vector3.new(0, 3, 0)
				else
					local climbStart = os.clock()
					local climbLimit = 4 + (info.top.Y - from.Y) / 6
					while active() and os.clock() - climbStart < climbLimit do
						bot.humanoid:MoveTo(info.top)
						task.wait(0.4)
						local position = bot.root.Position
						if position.Y - 3 >= info.top.Y - 1.5 and flatDistance(position, info.top) <= 3 then
							break
						end
						-- не зацепился за лестницу: подойдёт к ней заново
						if os.clock() - climbStart > 1.2 and position.Y - from.Y < 2 then
							break
						end
					end
					stuckTime = 0
					lastPosition = bot.root.Position
					continue
				end
			end
		elseif targetPosition.Y - from.Y < 5 then
			belowTime = 0
		end

		-- вплотную бежим напрямую; иначе (или если застряли, или цель на другой высоте) ищем путь
		local followed = false
		if flatDistance(goal, from) > 8 or stuckTime >= 0.5 or math.abs(goal.Y - from.Y) > 6 then
			followed = followPath(goal, 0.5)
		end
		if not followed then
			bot.humanoid:MoveTo(goal)
			task.wait(0.25)
		end
		if not active() then
			break
		end
		checkStuck(tickTime)
	end
end

-- создаёт бота: зомби (asZombie = true) или жителя
spawnBot = function(asZombie: boolean, position: Vector3?): boolean
	if #bots >= MAX_BOTS then
		return false
	end
	local myRound = roundId
	local model = getRig()
	if not model or not roundActive or roundId ~= myRound or #bots >= MAX_BOTS then
		if model then
			model:Destroy()
		end
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return false
	end

	local speed = if asZombie then BOT_SPEED else CITIZEN_SPEED + gameRng:NextNumber(-0.7, 0.7)
	model.Name = if asZombie then "Zombie" else "Citizen"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = if asZombie and botsFrozen then 0 else speed
	if asZombie then
		paintRig(model, ZOMBIE_SKIN, Color3.fromRGB(70, 110, 65), Color3.fromRGB(60, 70, 90))
		setHighlight(model, DEFAULT_ZOMBIE_FILL, DEFAULT_ZOMBIE_OUTLINE, false)
	else
		paintRig(model, pick(SKIN_COLORS, gameRng), pick(SHIRT_COLORS, gameRng), pick(PANTS_COLORS, gameRng))
	end
	model:PivotTo(CFrame.new(position or zombieSpawn()))
	model.Parent = botFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	-- анимация бега (стандартная анимация Roblox для R15)
	local runTrack: AnimationTrack? = nil
	if false then -- своя анимация в коде (ZT_Art), стандартные анимации Roblox не грузим
		pcall(function()
			local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = ""
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
			runTrack = track
		end)
	end

	local bot: Bot = { model = model, humanoid = humanoid, root = root, alive = true, zombie = asZombie, speed = speed, stunUntil = 0, giant = false, track = runTrack }
	table.insert(bots, bot)
	humanoid.Died:Connect(function()
		bot.alive = false
	end)
	task.spawn(runBot, bot, myRound)
	return true
end

clearBots = function()
	for _, bot in ipairs(bots) do
		bot.alive = false
		bot.model:Destroy()
	end
	table.clear(bots)
end

end -- КОНЕЦ БЛОКА БОТОВ

---------------------------------------------------------------------
-- ЗВУК: музыка, шаги ботов, рычание зомби и звуки в городе
---------------------------------------------------------------------
-- звук, который слышно только рядом с предметом (батут, люк, зомби)
Sfx.emit = function(part: BasePart, name: string, distance: number, speed: number)
	if not SOUNDS then
		return
	end
	local found = part:FindFirstChild(name)
	local sound: Sound
	if found and found:IsA("Sound") then
		sound = found
	else
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = SOUND_FILES[name] or ""
		sound.Volume = SOUND_LOUD[name] or 0.5
		sound.Looped = name == "w_steps"
		local region = SOUND_REGION[name]
		if region then
			sound.PlaybackRegionsEnabled = true
			sound.PlaybackRegion = region
			sound.LoopRegion = region
		end
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = distance / 8
		sound.RollOffMaxDistance = distance
		sound.Parent = part
	end
	sound.PlaybackSpeed = speed
	local region = SOUND_REGION[name]
	if region and not sound.IsPlaying then
		sound.TimePosition = region.Min
	end
	sound:Play()
end

-- подпись на колонке в лобби: включена ли у игрока музыка
Sfx.label = function(player: Player)
	local hud = huds[player]
	local session = sessions[player]
	local label = if hud then hud.musicLabel else nil
	if label and session then
		label.Text = if session.profile.musicOff then tr(player, "music_off") else tr(player, "music_on")
		label.TextColor3 = if session.profile.musicOff then Color3.fromRGB(190, 190, 190) else Color3.fromRGB(255, 130, 200)
	end
end

-- игрок нажал кнопку у колонки
Sfx.toggle = function(player: Player)
	local session = sessions[player]
	if session then
		session.profile.musicOff = not session.profile.musicOff
		Sfx.label(player)
		playSound(player, "deny")
	end
end

-- включает игроку нужную мелодию ("" - тишина)
function Sfx.music(player: Player, name: string)
	local hud = huds[player]
	if not hud or hud.music == name then
		return
	end
	local old = hud.sounds[hud.music]
	if old then
		old.Playing = false -- пауза: в следующий раз мелодия продолжится с того же места
	end
	hud.music = name
	local new = hud.sounds[name]
	if new then
		if name == "m_finale" then
			-- финал начинается с такого места, чтобы самый громкий момент пришёлся на конец раунда
			new.TimePosition = math.clamp(FINALE_PEAK - (roundEndsAt - os.clock()), 0, FINALE_PEAK)
		end
		new.Playing = true
	end
end

-- какая мелодия сейчас нужна каждому игроку: лобби, прятки (выживший), погоня (зомби) или финал
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessions[player]
			local hud = huds[player]
			if session and hud then
				local name = "m_lobby"
				if session.profile.musicOff then
					name = ""
				elseif inRound[player] then
					if not roundActive then
						name = hud.music -- итоги раунда: мелодия доигрывает
					elseif Sfx.finale then
						name = "m_finale"
					elseif isZombie[player] then
						name = "m_hunt"
					else
						name = "m_hide"
					end
				end
				Sfx.music(player, name)
			end
		end
	end
end)

-- шаги ботов и рычание зомби: по ним слышно, что рядом кто-то есть, даже если его не видно
task.spawn(function()
	local rng = Random.new()
	local function growl(root: BasePart, deep: boolean)
		Sfx.emit(root, "w_growl" .. rng:NextInteger(1, 3), 90, (if deep then 0.65 else 1) * rng:NextNumber(0.9, 1.15))
	end
	while SOUNDS do
		task.wait(0.3)
		if roundActive then
			for _, bot in ipairs(bots) do
				if botPresent(bot) then
					local moving = bot.root.AssemblyLinearVelocity.Magnitude > 4
					if bot.track then
						bot.track:AdjustSpeed(if moving then 1 else 0) -- стоящий бот не бежит на месте
					end
					local steps = bot.root:FindFirstChild("w_steps")
					if steps and steps:IsA("Sound") then
						if steps.Playing ~= moving then
							steps.Playing = moving
						end
					elseif moving then
						Sfx.emit(bot.root, "w_steps", 55, 1.85)
					end
					if bot.zombie and not botsFrozen and os.clock() >= bot.stunUntil and rng:NextNumber() < 0.04 then
						growl(bot.root, bot.giant)
					end
				end
			end
			for player in pairs(isZombie) do
				local root = getAlive(player)
				local session = sessions[player]
				if root and session and inRound[player] and rng:NextNumber() < 0.02 then
					growl(root, session.giant)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- ВЕРТОЛЁТ. В конце раунда он садится на одну из площадок. Выживший, который
-- простоял рядом несколько секунд, улетает: для него это победа.
---------------------------------------------------------------------
local Heli = {}

function Heli.land(survivors: { Player })
	-- площадка не слишком близко и не слишком далеко от одного из выживших
	local root = getAlive(survivors[gameRng:NextInteger(1, #survivors)])
	local from = if root then root.Position else Vector3.new(0, 0, 0)
	local spot = heliSpots[1]
	local bestScore = math.huge
	for _, candidate in ipairs(heliSpots) do
		local score = math.abs(flatDistance(candidate, from) - 190) + gameRng:NextNumber(0, 70)
		if score < bestScore then
			spot = candidate
			bestScore = score
		end
	end
	local model = Instance.new("Model")
	model.Name = "Helicopter"
	local craft = Instance.new("Model") -- сам вертолёт: он опускается с неба, а круг и луч ждут на земле
	craft.Name = "Craft"
	craft.Parent = model
	-- сквозь вертолёт можно пройти: так никто не застрянет под ним, а чтобы сесть, достаточно подбежать
	local function piece(parent: Instance, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = parent == craft
		part.Size = size
		part.Position = spot + offset
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end
	-- плоский круг или высокий луч: цилиндр, поставленный вертикально
	local function disc(parent: Instance, name: string, height: number, width: number, y: number, color: Color3, transparency: number): Part
		local part = piece(parent, name, Vector3.new(height, width, width), Vector3.new(0, y, 0), color, Enum.Material.Neon)
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = CFrame.new(spot + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		part.Transparency = transparency
		return part
	end
	local green = Color3.fromRGB(245, 130, 40) -- оранжевый спасательный вертолёт хорошо виден на фоне зелёного луча
	local dark = Color3.fromRGB(40, 40, 45)
	local body = piece(craft, "Body", Vector3.new(9, 4, 5), Vector3.new(0, 3, 0), green, Enum.Material.Metal)
	if SOUNDS then
		-- винт слышно издалека: по звуку вертолёт легче найти
		local rotor = Instance.new("Sound")
		rotor.Name = "w_heli"
		rotor.SoundId = SOUND_FILES.w_heli
		rotor.Volume = SOUND_LOUD.w_heli or 0.5
		rotor.Looped = true
		rotor.PlaybackRegionsEnabled = true
		rotor.PlaybackRegion = HELI_LOOP
		rotor.LoopRegion = HELI_LOOP
		rotor.RollOffMode = Enum.RollOffMode.InverseTapered
		rotor.RollOffMinDistance = 45
		rotor.RollOffMaxDistance = 520
		rotor.Parent = body
		rotor:Play()
	end
	piece(craft, "Glass", Vector3.new(2.4, 2.6, 4.4), Vector3.new(-4.6, 3.3, 0), Color3.fromRGB(120, 190, 230), Enum.Material.Glass)
	piece(craft, "Tail", Vector3.new(8, 1.2, 1.2), Vector3.new(8.5, 4, 0), green, Enum.Material.Metal)
	piece(craft, "Fin", Vector3.new(1.2, 3.4, 0.6), Vector3.new(12, 5.4, 0), green, Enum.Material.Metal)
	piece(craft, "Skid", Vector3.new(8, 0.4, 0.6), Vector3.new(0, 0.5, -2.2), dark, Enum.Material.Metal)
	piece(craft, "Skid", Vector3.new(8, 0.4, 0.6), Vector3.new(0, 0.5, 2.2), dark, Enum.Material.Metal)
	piece(craft, "Mast", Vector3.new(0.8, 1.4, 0.8), Vector3.new(0, 5.7, 0), dark, Enum.Material.Metal)
	disc(craft, "Rotor", 0.3, 17, 6.5, Color3.fromRGB(70, 70, 75), 0.55)
	local ring = disc(model, "Ring", 0.2, 22, 0.12, Color3.fromRGB(90, 255, 130), 0.4)
	disc(model, "Beam", 260, 3.5, 136, Color3.fromRGB(90, 255, 130), 0.6) -- зелёный луч виден издалека
	local light = Instance.new("PointLight")
	light.Range = 32
	light.Brightness = 2
	light.Color = Color3.fromRGB(90, 255, 130)
	light.Parent = ring
	-- вертолёт опускается с неба за три секунды
	local home = craft:GetPivot()
	craft:PivotTo(home + Vector3.new(0, 162, 0))
	model.Parent = map
	evac.model = model
	evac.spot = spot
	for other in pairs(inRound) do
		playSound(other, "land")
	end
	task.spawn(function()
		for step = 59, 0, -1 do
			if craft.Parent ~= model then
				return
			end
			craft:PivotTo(home + Vector3.new(0, step * step * 0.045, 0))
			task.wait(0.05)
		end
	end)
end

-- убирает вертолёт; если leave = true, он сначала красиво улетает в небо
function Heli.clear(leave: boolean?)
	local model = evac.model
	evac.model = nil
	evac.spot = nil
	if not model then
		return
	end
	local craft = model:FindFirstChild("Craft")
	if leave and craft and craft:IsA("Model") then
		craft.Parent = map
		model:Destroy()
		local rotor = craft:FindFirstChild("w_heli", true)
		if rotor and rotor:IsA("Sound") then
			rotor.PlaybackSpeed = 1.2 -- на взлёте винт воет выше
		end
		task.spawn(function()
			local from = craft:GetPivot()
			for step = 1, 50 do
				craft:PivotTo(from + Vector3.new(0, step * step * 0.07, 0))
				task.wait(0.05)
			end
			craft:Destroy()
		end)
	else
		model:Destroy()
	end
end

-- выживший улетел: победа, награда и возвращение в лобби
function Heli.rescue(player: Player, base: number)
	local session = sessions[player]
	if not session or not inRound[player] then
		return
	end
	inRound[player] = nil
	evac.saved[player] = true
	session.boardStart = 0
	session.profile.wins += 1
	local amount = award(player, base + COINS.evac)
	Quest.add(player, "survive", 1)
	Quest.add(player, "heli", 1)
	applyLook(player)
	local character = player.Character
	if character and getAlive(player) then
		local place = lobbyCFrame * CFrame.new(gameRng:NextNumber(-10, 10), 0, gameRng:NextNumber(-6, 6))
		Guard.allow(player, place.Position)
		character:PivotTo(place)
	end
	Guard.badges(player, "escape")
	toast(player, "heli_saved", amount)
	playSound(player, "evac")
	for other in pairs(inRound) do
		toast(other, "heli_left", player.DisplayName)
	end
end

---------------------------------------------------------------------
-- СОБЫТИЯ РАУНДА: туман, темнота, золотая лихорадка, ярость, гигант, лунная гравитация
---------------------------------------------------------------------
local EVENTS = { "fog", "dark", "gold", "rage", "giant", "moon" }
local Event = { last = "" }

-- выбирает событие для нового раунда ("" - раунд без события)
function Event.pick(): string
	if TEXT.en["ev_" .. FORCE_EVENT] then
		return FORCE_EVENT
	end
	if roundId % 3 == 0 and RULES.week ~= "" then
		Event.last = RULES.week
		return RULES.week -- каждый третий раунд - режим недели
	end
	if roundId < 2 or gameRng:NextNumber() >= ROUND_EVENTS then
		return "" -- первый раунд на сервере всегда обычный
	end
	local soft = false -- пока на сервере новичок, тумана и темноты не бывает
	for _, s in sessions do
		soft = soft or s.profile.rounds < 2
	end
	-- одно и то же событие дважды подряд не выпадает, а событие недели идёт только в свой раунд
	local pool = {}
	for _, e in EVENTS do
		if e ~= Event.last and e ~= RULES.week and not (soft and (e == "fog" or e == "dark")) then
			table.insert(pool, e)
		end
	end
	Event.last = pool[gameRng:NextInteger(1, math.max(1, #pool))] or ""
	return Event.last
end

-- включает и выключает уличные фонари
function Event.lamps(on: boolean)
	for _, part in ipairs(city:GetChildren()) do
		if part.Name == "LampHead" then
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = on
			end
		end
	end
end

function Event.start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if roundEvent == "fog" and atmosphere then
		atmosphere.Density = 0.7
		atmosphere.Haze = 3
	elseif roundEvent == "dark" then
		Lighting.ClockTime = 0
		Lighting.Brightness = 0.3
		Lighting.Ambient = Color3.fromRGB(20, 20, 28)
		Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 28)
		Event.lamps(false)
	elseif roundEvent == "moon" then
		workspace.Gravity = 75
	end
end

-- возвращает мир в обычное состояние
function Event.stop()
	if roundEvent == "dark" then
		Event.lamps(true)
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.3
		atmosphere.Haze = 1.2
	end
	workspace.Gravity = 196.2
	roundEvent = ""
	setTimeOfDay(roundId)
	for _, hud in pairs(huds) do
		hud.event.Text = ""
	end
end

-- событие "гигант": один зомби вырастает. Он медленнее, зато достаёт дальше.
function Event.giant()
	for _, bot in ipairs(bots) do
		if bot.zombie then
			bot.giant = true
			pcall(function()
				bot.model:ScaleTo(2)
			end)
			return
		end
	end
	for player in pairs(inRound) do
		local session = sessions[player]
		local character = player.Character
		if isZombie[player] and session and character then
			session.giant = true
			applyLook(player)
			return
		end
	end
end

---------------------------------------------------------------------
-- РАУНД
---------------------------------------------------------------------
local soloZombieNext = false                    -- одиночка по очереди играет то выжившим, то зомби
local lastZombieRound: { [Player]: number } = {} -- когда игрок последний раз начинал раунд зомби

-- Зомби дотянулся до выжившего. Щит спасает один раз и оглушает зомби.
local function tryCatch(survivor: Player, catcher: Player?, catcherBot: Bot?)
	local session = sessions[survivor]
	local now = os.clock()
	if session then
		if now < session.immuneUntil then
			return
		end
		if session.shield then
			session.shield = false
			session.immuneUntil = now + SHIELD_STUN
			setShield(survivor, false)
			toast(survivor, "shield_used")
			playSound(survivor, "block")
			Quest.add(survivor, "shield", 1)
			if catcherBot then
				catcherBot.stunUntil = now + SHIELD_STUN
				catcherBot.humanoid.WalkSpeed = 0
			elseif catcher then
				local catcherSession = sessions[catcher]
				local _, humanoid = getAlive(catcher)
				if catcherSession and humanoid then
					catcherSession.stunUntil = now + SHIELD_STUN
					humanoid.WalkSpeed = 0
				end
				playSound(catcher, "block")
				toast(catcher, "stunned")
			end
			return
		end
	end
	if Guard.hit(survivor, catcher, catcherBot) then
		return
	end
	infect(survivor, catcher)
end

-- игрок входит в уже идущий раунд: сразу зомби, чтобы не ждать в лобби
local function lateJoin(player: Player)
	local fresh = Guard.fresh(player)
	inRound[player] = true
	isZombie[player] = not fresh
	if not fresh then
		lastZombieRound[player] = roundId -- он уже побыл зомби: в следующем раунде начнёт выжившим
	end
	local session = sessions[player]
	if session then
		session.caught = 0
		session.picked = 0
	end
	teleport(player, if fresh then randomSpawn() else zombieSpawn())
	toast(player, if fresh then "late_fresh" else "late_join")
	applyLook(player)
end

local function runRound()
	local participants = getReadyPlayers()
	local playerCount = #participants
	if playerCount == 0 then
		return
	end

	roundId += 1
	setTimeOfDay(roundId)
	roundEvent = Event.pick()
	RULES.pay = (if roundEvent == "gold" then 2 else 1) + (if roundEvent ~= "" and roundEvent == RULES.week then 0.5 else 0)
	Event.start()
	Heli.clear()
	table.clear(evac.saved)
	local botCount = math.clamp(BOT_FILL - playerCount, 0, MAX_BOTS)
	local withBots = botCount > 0
	local roundTime = if withBots then BOT_ROUND_TIME else ROUND_TIME
	if Guard.eager(true) then roundTime = math.min(roundTime, 90) end

	-- сколько зомби в начале раунда и сколько из них игроки
	local zombiePlayers = 0
	local zombieBots = 0
	if playerCount == 1 then
		local soloSession = sessions[participants[1]]
		-- новичок свой первый раунд всегда играет выжившим
		if soloZombieNext and withBots and SOLO_ZOMBIE_ROUNDS and soloSession and soloSession.profile.rounds > 0 then
			zombiePlayers = 1
			zombieBots = if botCount >= 10 then 1 else 0 -- в большом городе зомби-игроку помогает один зомби-бот
		else
			zombieBots = math.clamp(botCount // 5, math.min(2, botCount), 4)
		end
		soloZombieNext = not soloZombieNext
	elseif withBots then
		zombiePlayers = math.ceil(playerCount / 6) -- до 6 игроков зомби-игрок один, до 12 - двое, дальше трое
		zombieBots = math.clamp(botCount // 6, math.min(1, botCount), 3)
	else
		zombiePlayers = math.ceil(playerCount / 6)
	end

	table.clear(inRound)
	table.clear(isZombie)
	for _, player in ipairs(participants) do
		inRound[player] = true
		local session = sessions[player]
		session.boostUntil = 0
		session.shield = false
		session.immuneUntil = 0
		session.stunUntil = 0
		session.combo = 0
		session.comboAt = 0
		session.boardStart = 0
		session.boardShown = 0
		session.giant = false
		session.caught = 0
		session.picked = 0
	end
	roundActive = true
	botsFrozen = true
	finalHunt = false
	roundEndsAt = os.clock() + HEAD_START + roundTime
	Sfx.finale = false

	clearPickups()
	-- чем больше город, тем больше предметов на улицах
	local area = math.max(1, #citySpawns / 25)
	for _ = 1, math.floor(14 * area + 0.5) * (if roundEvent == "gold" then 2 else 1) do
		spawnPickup("coin")
	end
	for _ = 1, math.floor(4 * area + 0.5) * (if roundEvent == "rage" then 2 else 1) do
		spawnPickup("boost")
	end
	for _ = 1, math.floor(2 * area + 0.5) do
		spawnPickup("shield")
	end

	-- у каждого участника свой перекрёсток
	local spawns = shuffled(citySpawns)
	local spawnIndex = 0
	local function nextSpawn(): Vector3
		spawnIndex += 1
		return spawns[((spawnIndex - 1) % #spawns) + 1]
	end

	-- зомби становится тот игрок, который дольше всех им не был.
	-- Новичок свой первый раунд по возможности играет выжившим: так он увидит подсказки.
	local function zombieTurn(player: Player): number
		local session = sessions[player]
		return (lastZombieRound[player] or 0) + (if session and session.profile.rounds == 0 then 1e9 else 0)
	end
	local order = shuffled(participants)
	table.sort(order, function(a: Player, b: Player): boolean
		return zombieTurn(a) < zombieTurn(b)
	end)
	local firstZombies: { Player } = {}
	for index = 1, zombiePlayers do
		local zombie = order[index]
		isZombie[zombie] = true
		lastZombieRound[zombie] = roundId
		table.insert(firstZombies, zombie)
	end
	-- выжившие игроки встают на случайные перекрёстки, а зомби - подальше от них
	local humanSpots: { Vector3 } = {}
	for _, player in ipairs(participants) do
		if not isZombie[player] then
			local spot = nextSpawn()
			table.insert(humanSpots, spot)
			teleport(player, spot)
		end
	end
	local function farSpawn(): Vector3
		local bestIndex, bestGap = spawnIndex + 1, -1
		for index = spawnIndex + 1, #spawns do
			local gap = math.huge
			for _, spot in ipairs(humanSpots) do
				gap = math.min(gap, flatDistance(spawns[index], spot))
			end
			if gap > bestGap then
				bestIndex, bestGap = index, gap
			end
			if gap >= RULES.zombieGap then
				break
			end
		end
		if bestIndex <= #spawns then
			spawns[spawnIndex + 1], spawns[bestIndex] = spawns[bestIndex], spawns[spawnIndex + 1]
		end
		return nextSpawn()
	end
	for _, player in ipairs(participants) do
		if isZombie[player] then
			teleport(player, farSpawn())
			flashScreen(player)
		end
		applyLook(player)
	end
	for index = 1, botCount do
		spawnBot(index <= zombieBots, if index <= zombieBots then farSpawn() else nextSpawn())
	end
	if roundEvent == "giant" then
		Event.giant()
	end
	if roundEvent ~= "" then
		bigText(nil, "ev_" .. roundEvent)
	end
	-- совет про укрытия показывается игроку несколько раундов (новичку всё показывает строка подсказки)
	for _, player in ipairs(participants) do
		local session = sessions[player]
		if not isZombie[player] and session and session.profile.rounds >= 3 and session.profile.rounds < 8 then
			toast(player, "tip_hide")
		end
	end
	if playerCount == 1 and roundId % 3 == 1 and roundId > 3 then
		local solo = participants[1]
		if isZombie[solo] then
			toast(solo, "invite")
		else
			local myRound = roundId
			task.delay(HEAD_START + 5, function()
				if roundActive and roundId == myRound then
					toast(solo, "invite")
				end
			end)
		end
	end

	-- зомби стоят на месте, выжившие разбегаются
	for _, zombie in ipairs(firstZombies) do
		local _, humanoid = getAlive(zombie)
		if humanoid then
			humanoid.WalkSpeed = 0
		end
	end
	for i = HEAD_START, 1, -1 do
		setStatus("headstart", i)
		task.wait(1)
	end
	botsFrozen = false
	-- просыпаются все зомби, в том числе те, кто вошёл в раунд во время отсчёта
	for zombie in pairs(inRound) do
		if isZombie[zombie] then
			applyLook(zombie)
		end
	end
	for player in pairs(inRound) do
		playSound(player, "start")
	end

	-- основной цикл раунда
	local startTime = os.clock()
	local shownSecond = -1
	local elapsedWhole = 0
	local lastSurvivor: Player? = nil
	local lastBotAttempt = 0
	local heliCame = false
	local result = "time"

	while true do
		local timeLeft = roundTime - (os.clock() - startTime)
		if timeLeft <= 0 then
			break
		end

		local zombies, survivors = roundPlayers()
		if #survivors == 0 and next(evac.saved) ~= nil then
			result = "escaped" -- все, кто не заразился, улетели на вертолёте
			break
		end
		if #zombies + #survivors == 0 then
			result = "nobody"
			break
		end
		local zombieBotList: { Bot } = {}
		local citizens: { Bot } = {}
		for _, bot in ipairs(bots) do
			if botPresent(bot) then
				table.insert(if bot.zombie then zombieBotList else citizens, bot)
			end
		end
		if #survivors + #citizens == 0 then
			result = "zombies"
			break
		end

		-- если зомби не осталось (вышли из игры), заражается кто-то из выживших
		if #zombies + #zombieBotList == 0 and os.clock() - lastBotAttempt >= 2 then
			lastBotAttempt = os.clock()
			if #citizens > 0 then
				infectBot(citizens[gameRng:NextInteger(1, #citizens)], nil)
			elseif #survivors >= 2 then
				infect(survivors[gameRng:NextInteger(1, #survivors)], nil)
				zombies, survivors = roundPlayers()
			else
				task.spawn(spawnBot, true, nil)
			end
		elseif #zombies == 0 and zombiePlayers > 0 and #survivors >= 2 and roundEndsAt - os.clock() > 45
			and os.clock() - lastBotAttempt >= 2 then
			-- зомби-игрок вышел из игры: его место занимает кто-то из выживших (но не под конец раунда)
			lastBotAttempt = os.clock()
			local drafted = survivors[gameRng:NextInteger(1, #survivors)]
			lastZombieRound[drafted] = roundId
			infect(drafted, nil)
			zombies, survivors = roundPlayers()
		end

		-- заражение: зомби-игроки ловят вплотную (через стену поймать нельзя)
		local now = os.clock()
		for _, zombie in ipairs(zombies) do
			local zombieRoot = getAlive(zombie)
			local zombieSession = sessions[zombie]
			if zombieRoot and not (zombieSession and now < zombieSession.stunUntil) and Guard.ok(zombie) then
				local zombiePosition = zombieRoot.Position
				local reach = RULES.playerReach * (if zombieSession and zombieSession.giant then 1.3 else 1)
				for _, survivor in ipairs(survivors) do
					if inRound[survivor] and not isZombie[survivor] then
						local survivorRoot = getAlive(survivor)
						if survivorRoot and (zombiePosition - survivorRoot.Position).Magnitude <= reach
							and not wallBetween(zombiePosition, survivorRoot.Position) then
							tryCatch(survivor, zombie, nil)
						end
					end
				end
				for _, citizen in ipairs(citizens) do
					if not citizen.zombie and (zombiePosition - citizen.root.Position).Magnitude <= reach
						and not wallBetween(zombiePosition, citizen.root.Position) then
						infectBot(citizen, zombie)
					end
				end
			end
		end
		-- заражение: зомби-боты (оглушённый или превращающийся зомби никого не ловит)
		for _, bot in ipairs(zombieBotList) do
			if now >= bot.stunUntil then
				local botPosition = bot.root.Position
				local reach = if bot.giant then 9 else nil
				for _, survivor in ipairs(survivors) do
					if inRound[survivor] and not isZombie[survivor] then
						local survivorRoot = getAlive(survivor)
						if survivorRoot and botCanReach(botPosition, survivorRoot.Position, reach) then
							tryCatch(survivor, nil, bot)
						end
					end
				end
				for _, citizen in ipairs(citizens) do
					if not citizen.zombie and botCanReach(botPosition, citizen.root.Position, reach) then
						infectBot(citizen, nil)
					end
				end
			end
		end

		-- посадка в вертолёт: нужно простоять рядом несколько секунд
		local pad = evac.spot
		if pad then
			for _, survivor in ipairs(survivors) do
				local session = sessions[survivor]
				local root = getAlive(survivor)
				if session and root and inRound[survivor] and not isZombie[survivor] and Guard.ok(survivor)
					and (root.Position - Vector3.new(pad.X, root.Position.Y, pad.Z)).Magnitude <= 11
					and math.abs(root.Position.Y - 3 - pad.Y) <= 8 then
					if session.boardStart == 0 then
						session.boardStart = now
					end
					local left = math.ceil(EVAC_BOARD - (now - session.boardStart))
					if left <= 0 then
						if Guard.seat(survivor) then
							Heli.rescue(survivor, if withBots then COINS.surviveBots else COINS.survive)
						end
					elseif left ~= session.boardShown then
						session.boardShown = left
						toast(survivor, "heli_boarding", left)
					end
				elseif session then
					session.boardStart = 0
					session.boardShown = 0
				end
			end
		end

		collectPickups(survivors)
		updateSpeeds(zombies, survivors)

		-- раз в секунду: надписи, монеты за выживание, последний выживший
		local second = math.ceil(timeLeft)
		if second ~= shownSecond then
			shownSecond = second
			elapsedWhole += 1
			local nowZombies, nowSurvivors = roundPlayers()
			local citizenCount = 0
			local zombieBotCount = 0
			for _, bot in ipairs(bots) do
				if botPresent(bot) then
					if bot.zombie then
						zombieBotCount += 1
					else
						citizenCount += 1
					end
				end
			end
			setStatus("running", formatTime(second), #nowSurvivors + citizenCount, #nowZombies + zombieBotCount)

			-- в конце раунда прилетает вертолёт
			if not heliCame and EVAC_TIME > 0 and second <= EVAC_TIME and #nowSurvivors > 0 and #heliSpots > 0 then
				heliCame = true
				Sfx.finale = true
				Heli.land(nowSurvivors)
				for _, survivor in ipairs(nowSurvivors) do
					bigText(survivor, "heli_arrived")
				end
				for player in pairs(inRound) do
					playSound(player, "start")
				end
			end
			-- задание "просиди в укрытии": считаются секунды рядом с кустом, сараем, баком или вагоном
			for _, survivor in ipairs(nowSurvivors) do
				local root = getAlive(survivor)
				if root then
					for _, spot in ipairs(hideSpots) do
						if (spot - root.Position).Magnitude <= 6 then
							Quest.add(survivor, "hide", 1)
							break
						end
					end
				end
			end

			-- финальная охота: в конце раунда прятаться бесполезно, зомби-боты чуют всех
			if not finalHunt and FINAL_HUNT_TIME > 0 and second <= FINAL_HUNT_TIME
				and #nowSurvivors + citizenCount > 0 then
				finalHunt = true
				Sfx.finale = true
				bigText(nil, "final_hunt")
				for player in pairs(inRound) do
					playSound(player, "hunt")
				end
			end

			-- кто вышел из зоны магазина посреди раунда, сразу входит в игру зомби
			if roundEndsAt - os.clock() > 20 then
				for _, player in ipairs(Players:GetPlayers()) do
					local root = getAlive(player)
					if root and sessions[player] and not inRound[player] and not evac.saved[player]
						and root.Position.Y > LOBBY_Y - 30 and not inShopZone(root.Position) and not Guard.stay(player) then
						lateJoin(player)
					end
				end
			end

			-- последние десять секунд тикают
			if second <= 10 and second > 0 then
				for player in pairs(inRound) do
					playSound(player, "tick")
				end
			end

			if elapsedWhole % 10 == 0 then
				for _, survivor in ipairs(nowSurvivors) do
					if getAlive(survivor) then
						award(survivor, COINS.aliveTick)
					end
				end
			end
			if #nowSurvivors == 1 and citizenCount == 0 and #nowZombies + zombieBotCount >= 2 and lastSurvivor == nil then
				local last = nowSurvivors[1]
				lastSurvivor = last
				bigText(nil, "last_survivor", last.DisplayName)
				local character = last.Character
				if character then
					-- голубое свечение не видно сквозь стены: последний выживший тоже может прятаться
					setHighlight(character, Color3.fromRGB(120, 235, 255), Color3.fromRGB(255, 255, 255), false)
				end
			end
		end

		task.wait(0.1)
	end

	-- конец раунда и награды
	roundActive = false
	finalHunt = false
	Sfx.finale = false
	clearBots()
	clearPickups()
	Heli.clear(true)
	Event.stop()
	local zombies, survivors = roundPlayers()

	if result == "zombies" then
		setStatus("win_zombies")
		bigText(nil, "win_zombies")
		for _, player in ipairs(zombies) do
			if Guard.active(player) then
				local amount = award(player, if withBots then COINS.zombieWinBots else COINS.zombieWin)
				toast(player, "coins", amount)
				playSound(player, "win")
			end
		end
	elseif result == "time" then
		local solo = participants[1]
		local soloSession = sessions[solo]
		if playerCount == 1 and zombiePlayers == 1 and soloSession then
			-- одиночка играл за зомби: раунд оценивается по числу пойманных
			local targets = botCount - zombieBots
			setStatus("zombie_score", soloSession.caught, targets)
			bigText(nil, "zombie_score", soloSession.caught, targets)
			if soloSession.caught * 2 >= targets then
				-- поймал половину города: это победа зомби
				toast(solo, "coins", award(solo, COINS.zombieWinBots))
				playSound(solo, "win")
			end
		else
			setStatus("win_survivors")
			bigText(nil, "win_survivors")
			for _, player in ipairs(zombies) do
				local session = sessions[player]
				if session then
					toast(player, "you_caught", session.caught)
				end
			end
		end
		for _, player in ipairs(survivors) do
			-- кто весь раунд простоял на месте, тот не играл: награды и победы ему нет
			if Guard.active(player) then
				local base = if withBots then COINS.surviveBots else COINS.survive
				if player == lastSurvivor then
					base += COINS.lastSurvivor
				end
				local amount = award(player, base)
				sessions[player].profile.wins += 1
				syncStats(player)
				toast(player, "coins", amount)
				playSound(player, "win")
				Quest.add(player, "survive", 1)
			end
		end
		for _, player in ipairs(zombies) do
			if Guard.active(player) then
				award(player, COINS.consolation)
			end
		end
	elseif result == "escaped" then
		setStatus("win_escaped")
		bigText(nil, "win_escaped")
		for _, player in ipairs(zombies) do
			if Guard.active(player) then
				award(player, COINS.consolation)
			end
		end
	end

	RULES.pay = 1
	if result ~= "nobody" then
		task.wait(5)
	end

	-- всех возвращаем в лобби обычными персонажами
	local finished = table.clone(inRound)
	local escaped = table.clone(evac.saved)
	table.clear(inRound)
	table.clear(isZombie)
	table.clear(evac.saved)
	for _, player in ipairs(Players:GetPlayers()) do
		local session = sessions[player]
		if session then
			session.boostUntil = 0
			session.stunUntil = 0
			applyLook(player)
			local root = getAlive(player)
			local character = player.Character
			-- в лобби отправляем участников раунда и всех, кто почему-то остался в городе
			if root and character and (finished[player] or (root.Position.Y < LOBBY_Y - 30 and not Guard.home(root.Position))) then
				local place = lobbyCFrame * CFrame.new(gameRng:NextNumber(-10, 10), 0, gameRng:NextNumber(-6, 6))
				if RULES.gifts and session.profile.rounds < 3 and next(session.profile.owned) == nil then
					-- новичок без покупок возвращается к витринам со следами: стрелка покажет первую покупку
					place = CFrame.lookAt(Vector3.new(-30, LOBBY_Y + 4, -18), Vector3.new(-35, LOBBY_Y + 4, -42))
				end
				Guard.allow(player, place.Position)
				character:PivotTo(place)
			end
			if (finished[player] and Guard.active(player)) or escaped[player] then
				session.profile.rounds += 1
				Quest.add(player, "play", 1)
				Guard.badges(player)
				task.spawn(saveProfile, player)
			end
		end
	end
end

---------------------------------------------------------------------
-- ИГРОКИ ЗАХОДЯТ, ВЫХОДЯТ, ПОЯВЛЯЮТСЯ
---------------------------------------------------------------------
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	if humanoid:IsA("Humanoid") then
		-- выживший погиб или сбросил персонажа посреди раунда: он сразу считается заражённым
		humanoid.Died:Connect(function()
			if roundActive and inRound[player] and not isZombie[player] then
				infect(player, nil)
			end
		end)
	end
	task.wait(0.2)
	if character.Parent == nil or player.Character ~= character then
		return
	end

	if roundActive and sessions[player] then
		if inRound[player] then
			-- погиб во время раунда: возвращается в город уже зомби
			if not isZombie[player] then
				infect(player, nil)
			end
			teleport(player, zombieSpawn())
		elseif roundEndsAt - os.clock() > 20 and not evac.saved[player] and not Guard.stay(player) then
			-- зашёл посреди раунда: сразу в игру (новичок - выжившим, остальные - зомби), чтобы не ждать
			lateJoin(player)
		end
	end
	applyLook(player)
	applyTrail(player)
	applyVipTag(player)
end

local function checkFriends(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local otherSession = sessions[other]
		if other ~= player and other.Parent == Players and otherSession then
			local ok, areFriends = pcall(function(): boolean
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and areFriends and sessions[player] == session and sessions[other] == otherSession then
				session.pals[other] = true
				otherSession.pals[player] = true
				if not otherSession.friendBoost then
					otherSession.friendBoost = true
					toast(other, "friend_bonus", math.floor(FRIEND_BONUS * 100))
				end
			end
		end
	end
	session.friendBoost = next(session.pals) ~= nil
	if session.friendBoost then
		toast(player, "friend_bonus", math.floor(FRIEND_BONUS * 100))
	end
end

local function onPlayerAdded(player: Player)
	local profile, canSave, lock = loadProfile(player)
	if player.Parent ~= Players then
		-- игрок вышел, пока прогресс загружался: отпускаем прогресс для другого сервера
		saveProfile(player, ({ profile = profile, canSave = canSave, lock = lock, leaving = false } :: any) :: Session, true)
		return
	end
	local session: Session = {
		profile = profile,
		canSave = canSave,
		vip = false,
		friendBoost = false,
		lang = detectLang(player),
		boostUntil = 0,
		shield = false,
		immuneUntil = 0,
		stunUntil = 0,
		combo = 0,
		comboAt = 0,
		boardStart = 0,
		boardShown = 0,
		giant = false,
		caught = 0,
		picked = 0,
		leaving = false,
		lock = lock,
		vipAsk = 0,
		pals = {},
		day = os.time() // 86400,
	}
	sessions[player] = session
	createHud(player)
	createWorldLabels(player)
	syncStats(player)
	Quest.refresh(player)

	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end

	if VIP_GAMEPASS_ID > 0 then
		-- есть ли у игрока VIP, отвечает Roblox. Если ответа нет (сбой сети), спрашиваем снова.
		-- Вопрос повторяется и позже: вдруг игрок купил VIP на сайте, не выходя из игры.
		local function askVip(): boolean
			local ok, owns = pcall(function(): boolean
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
			end)
			if ok and owns and sessions[player] == session and not session.vip then
				session.vip = true
				applyVipTag(player)
				refreshVip(player)
			end
			return ok
		end
		refreshVip(player)
		local answered = askVip()
		task.spawn(function()
			local attempt = 1
			while sessions[player] == session and not session.vip do
				task.wait(if answered then 180 elseif attempt < 3 then attempt else 60)
				attempt += 1
				answered = askVip()
			end
		end)
	end

	if not canSave and store ~= nil then
		toast(player, "no_save")
	end
	-- на временном прогрессе (сбой загрузки) награды дня нет: её выдаст загрузка настоящего прогресса
	if canSave or store == nil or RunService:IsStudio() then
		giveDailyReward(player)
	end
	task.wait(4)
	if sessions[player] == session then
		checkFriends(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	-- сначала игрок убирается из раунда, потом сохраняется: сохранение может занять несколько секунд
	local session = sessions[player]
	inRound[player] = nil
	isZombie[player] = nil
	sessions[player] = nil
	huds[player] = nil
	lastZombieRound[player] = nil
	evac.saved[player] = nil
	-- бонус друзей остаётся только у тех, у кого на сервере ещё есть друг
	for _, otherSession in pairs(sessions) do
		if otherSession.pals[player] then
			otherSession.pals[player] = nil
			otherSession.friendBoost = next(otherSession.pals) ~= nil
		end
	end
	if session then
		saveProfile(player, session, true)
	end
end)

-- сервер закрывается: сохраняем всех разом и ждём, пока все сохранения дойдут
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local session = sessions[player]
		if session then
			task.spawn(saveProfile, player, session, true)
		end
	end
	local deadline = os.clock() + 25
	repeat
		task.wait(0.2)
	until Save.flying <= 0 or os.clock() > deadline
end)

---------------------------------------------------------------------
-- ДОПОЛНЕНИЯ (модуль Extras): подсказки новичкам, защита от читеров, значки, поиск выживших в финале
---------------------------------------------------------------------
do
	local extras = script:FindFirstChild("Extras")
	local ok, err = pcall(function()
		assert(extras, "модуль не найден")
		local start = (require :: any)(extras)
		start({
			Players = Players, sessions = sessions, huds = huds, inRound = inRound, isZombie = isZombie, bots = bots,
			pickups = pickups, evac = evac, hideSpots = hideSpots, RULES = RULES, BADGES = BADGES, Guard = Guard, LOBBY_Y = LOBBY_Y,
			tr = tr, toast = toast, getAlive = getAlive, levelOf = levelOf, randomSpawn = randomSpawn, botPresent = botPresent,
			state = function(): (boolean, boolean, number, string)
				return roundActive, finalHunt, roundId, roundEvent
			end,
			big = bigText, sound = playSound, quests = Quest.today, sync = syncStats, trail = applyTrail, questBoard = Quest.refresh, eventsOn = ROUND_EVENTS > 0, dailyBase = DAILY_REWARD, items = SHOP_ITEMS, events = EVENTS, itemName = itemName,
			saveBroken = function(): boolean
				return store ~= nil and not RunService:IsStudio()
			end,
			inShopZone = inShopZone, catch = tryCatch, botCatch = infectBot, wall = wallBetween, cityHalf = CITY_HALF, topStore = topStore, topLabels = topLabels, board = EVAC_BOARD, ladders = ladders, loadProfile = loadProfile, saveProfile = saveProfile, daily = giveDailyReward,
			refresh = function(player: Player)
				syncStats(player)
				Quest.refresh(player)
				applyLook(player)
				applyTrail(player)
			end,
		})
	end)
	if not ok then
		warn("[Zombie Tag] Модуль Extras не запущен (" .. tostring(err) .. "). Игра работает, но без подсказок, значков и защиты от читеров.")
	end
end

-- автосохранение каждые 3 минуты
task.spawn(function()
	while true do
		task.wait(180)
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(saveProfile, player)
		end
	end
end)

---------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ ИГРЫ
---------------------------------------------------------------------
while true do
	-- что бы ни сломалось, игра продолжает работать: ошибка пишется в журнал, и цикл идёт дальше
	local alive, problem = pcall(function()
		if #getReadyPlayers() == 0 then
			-- все игроки стоят в зоне магазина: раунд их ждёт
			if next(sessions) ~= nil and statusKey ~= "skipped" then
				for player in pairs(sessions) do
					local root = getAlive(player)
					if root and inShopZone(root.Position) then
						setStatus("skipped")
						break
					end
				end
			end
			task.wait(1)
		else
			local pause = if #Players:GetPlayers() <= 1 then SOLO_INTERMISSION else INTERMISSION
			pause += Guard.day(pause)
			-- между раундами в городе никого быть не должно
			for _, player in ipairs(Players:GetPlayers()) do
				local root = getAlive(player)
				local character = player.Character
				if root and character and root.Position.Y < LOBBY_Y - 30 and not Guard.home(root.Position) then
					Guard.allow(player, lobbyCFrame.Position)
					character:PivotTo(lobbyCFrame)
				end
			end
			for i = pause, 1, -1 do
				if pause - i >= 5 and Guard.eager() then
					break -- новичок уже освоился в лобби: не заставляем его ждать
				end
				setStatus("intermission", i)
				task.wait(1)
			end
			local ok, err = pcall(function(): any
				runRound()
				return nil
			end)
			-- возвращаем игру в исходное состояние
			RULES.pay = 1
			roundActive = false
			finalHunt = false
			Sfx.finale = false
			clearBots()
			clearPickups()
			Heli.clear()
			Event.stop()
			table.clear(evac.saved)
			table.clear(inRound)
			table.clear(isZombie)
			if not ok then
				-- если в раунде что-то сломалось, пишем об этом и возвращаем всех в лобби
				warn("[Zombie Tag] Ошибка в раунде: " .. tostring(err))
				for _, player in ipairs(Players:GetPlayers()) do
					applyLook(player)
					local character = player.Character
					if character and getAlive(player) then
						Guard.allow(player, lobbyCFrame.Position)
						character:PivotTo(lobbyCFrame)
					end
				end
				task.wait(2)
			end
		end
	end)
	if not alive then
		warn("[Zombie Tag] Ошибка в главном цикле: " .. tostring(problem))
		task.wait(2)
	end
end
