--!strict
--[[
	ОСАДА (версия 10)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Siege. Он лежит ВНУТРИ главного скрипта, рядом с Homes:
	ServerScriptService -> Script -> Siege. Его запускает модуль Homes; без него игра работает по-старому.

	ЧТО ОН ДЕЛАЕТ
	- Каждую ночь зомби идут по улице посёлка к домам игроков и ломают их. У дома есть прочность.
	- Если прочность кончилась, зомби проламывают дом и съедают часть еды из запасов хозяина.
	  Ступень дома не падает, но пролом нужно починить за детали.
	- У каждого дома (начиная с сарая) стоит верстак. Во время осады у него чинят дом: бесплатно, удерживая кнопку.
	  Днём у него же чинят дом за детали и строят защиту: забор, шипы, башню.
	- Каждая четвёртая ночь - орда: зомби в два с половиной раза больше, а к домам и крепостям приходит громила.
	- За дом, который устоял, хозяин получает монеты.
	- Нападают только на дома тех, кто этой ночью дома или в городе. Кто стоит в лобби, тот в безопасности.
	- Когда в городе долго никого нет (все сидят по домам), ночь приходит в посёлок сама.
]]

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
local LIVE = false                   -- осада идёт для игроков (false: только в Studio)
local HOUSE_HP = { 100, 180, 280 }   -- прочность сарая, дома и крепости (у палатки ломать нечего)
local WAVE = { 2, 3, 4 }             -- сколько зомби приходит к сараю, дому и крепости в обычную ночь
local WAVE_GROW = 3                  -- каждые столько ночей, которые дом устоял, приходит на одного зомби больше
local WAVE_MORE = 3                  -- но не больше, чем на столько
local HORDE_EVERY = 4                -- каждая такая ночь - орда (0 - орды нет)
local HORDE_SIZE = 2.5               -- во сколько раз орда больше обычной волны
local BITE = 0.3                     -- сколько прочности в секунду отнимает один зомби (громила - втрое больше)
local ZOMBIE_HP = 30                 -- здоровье зомби (у громилы - втрое больше)
local SPEED = 8                      -- скорость зомби, шагов в секунду
local DEF_COST = { 8, 20, 40 }       -- деталей за забор, шипы и башню
local FENCE_SAVE = 0.35              -- забор: дом получает на такую долю меньше урона
local SPIKES = 1                     -- шипы: столько здоровья в секунду теряет зомби, который ломает дом
local TOWER_HIT = 6                  -- башня: урон одного выстрела
local TOWER_EVERY = 3                -- и раз во сколько секунд она стреляет
local TOWER_RANGE = 45               -- и на сколько шагов
local FIX_HOLD = 1.5                 -- сколько секунд держать кнопку у верстака
local FIX_NIGHT = 4                  -- столько прочности возвращает одно удержание во время осады (бесплатно)
local FIX_DAY = 25                   -- днём одна деталь чинит столько прочности
local GAP_COST = { 4, 8, 14 }        -- деталей за ремонт пролома: сарай, дом, крепость
local GAP_FOOD = 0.3                 -- какую долю еды из запасов съедают зомби, когда проломили дом
local HELD_COINS = 8                 -- монет за каждого зомби волны, если дом устоял (в ночь орды - в полтора раза больше)
local HOME_DAY = 45                  -- в городе никого нет: через столько секунд после утра ночь приходит в посёлок сама
local HOME_NIGHT = 75                -- и столько секунд она длится
local MAX_ZOMBIES = 40               -- больше стольких фигурок зомби в посёлке не бывает (один зомби тогда считается за нескольких)
local REACH = 14                     -- с какого расстояния сервер верит нажатию у верстака
local QUIET = false                  -- зомби не приходят совсем: остаются только верстаки и защита (для проверок)

-- ТЕКСТЫ. Они добавляются к общим текстам игры (модуль Texts).
local TEXT: { [string]: { [string]: string } } = {
	en = {
		sg_night = "🧟 Zombies are coming for the houses! Hold the button at your workbench to repair",
		sg_horde = "☠ A HORDE IS COMING!",
		sg_away = "🧟 While you are in the city, zombies attack your house. Your defences fight without you",
		sg_gap = "💥 Zombies broke into your house and ate food: %d! Repair it at the workbench",
		sg_gap0 = "💥 Zombies broke into your house! Repair it at the workbench",
		sg_held = "🛡 Your house held out! Coins: +%d",
		sg_whole = "🔨 The house is whole again",
		sg_def1 = "🛡 FENCE BUILT! Zombies break the house slower",
		sg_def2 = "🛡 SPIKES SET! Zombies at your walls get hurt",
		sg_def3 = "🛡 TOWER BUILT! It shoots zombies by itself",
		sg_max = "🛡 Your defence is complete",
		sg_status = "🧟 Siege! Zombies: %d   Your house: ❤ %d/%d",
		sg_status0 = "🧟 Siege! Zombies in the settlement: %d",
	},
	ru = {
		sg_night = "🧟 Зомби идут к домам! Держи кнопку у верстака, чтобы чинить дом",
		sg_horde = "☠ ИДЁТ ОРДА!",
		sg_away = "🧟 Пока ты в городе, зомби нападают на твой дом. Защита работает и без тебя",
		sg_gap = "💥 Зомби проломили твой дом и съели еду: %d! Почини дом у верстака",
		sg_gap0 = "💥 Зомби проломили твой дом! Почини его у верстака",
		sg_held = "🛡 Твой дом устоял! Монеты: +%d",
		sg_whole = "🔨 Дом снова целый",
		sg_def1 = "🛡 ЗАБОР ГОТОВ! Зомби ломают дом медленнее",
		sg_def2 = "🛡 ШИПЫ ГОТОВЫ! Зомби у стен получают урон",
		sg_def3 = "🛡 БАШНЯ ГОТОВА! Она сама стреляет по зомби",
		sg_max = "🛡 Защита построена полностью",
		sg_status = "🧟 Осада! Зомби: %d   Твой дом: ❤ %d/%d",
		sg_status0 = "🧟 Осада! Зомби в посёлке: %d",
	},
	es = {
		sg_night = "🧟 ¡Los zombis van por las casas! Mantén el botón del banco de trabajo para reparar",
		sg_horde = "☠ ¡VIENE UNA HORDA!",
		sg_away = "🧟 Mientras estás en la ciudad, los zombis atacan tu casa. Tus defensas luchan sin ti",
		sg_gap = "💥 ¡Los zombis entraron en tu casa y se comieron comida: %d! Repárala en el banco de trabajo",
		sg_gap0 = "💥 ¡Los zombis entraron en tu casa! Repárala en el banco de trabajo",
		sg_held = "🛡 ¡Tu casa resistió! Monedas: +%d",
		sg_whole = "🔨 La casa está entera otra vez",
		sg_def1 = "🛡 ¡VALLA LISTA! Los zombis rompen la casa más despacio",
		sg_def2 = "🛡 ¡PINCHOS LISTOS! Los zombis junto a tus muros se hacen daño",
		sg_def3 = "🛡 ¡TORRE LISTA! Dispara sola a los zombis",
		sg_max = "🛡 Tu defensa está completa",
		sg_status = "🧟 ¡Asedio! Zombis: %d   Tu casa: ❤ %d/%d",
		sg_status0 = "🧟 ¡Asedio! Zombis en el poblado: %d",
	},
	pt = {
		sg_night = "🧟 Os zumbis estão indo para as casas! Segure o botão da bancada para consertar",
		sg_horde = "☠ UMA HORDA ESTÁ VINDO!",
		sg_away = "🧟 Enquanto você está na cidade, os zumbis atacam sua casa. Suas defesas lutam sem você",
		sg_gap = "💥 Os zumbis invadiram sua casa e comeram comida: %d! Conserte na bancada",
		sg_gap0 = "💥 Os zumbis invadiram sua casa! Conserte na bancada",
		sg_held = "🛡 Sua casa resistiu! Moedas: +%d",
		sg_whole = "🔨 A casa está inteira de novo",
		sg_def1 = "🛡 CERCA PRONTA! Os zumbis quebram a casa mais devagar",
		sg_def2 = "🛡 ESPINHOS PRONTOS! Os zumbis nas suas paredes se machucam",
		sg_def3 = "🛡 TORRE PRONTA! Ela atira nos zumbis sozinha",
		sg_max = "🛡 Sua defesa está completa",
		sg_status = "🧟 Cerco! Zumbis: %d   Sua casa: ❤ %d/%d",
		sg_status0 = "🧟 Cerco! Zumbis na vila: %d",
	},
	fr = {
		sg_night = "🧟 Les zombies viennent vers les maisons! Maintiens le bouton de l'établi pour réparer",
		sg_horde = "☠ UNE HORDE ARRIVE!",
		sg_away = "🧟 Pendant que tu es en ville, les zombies attaquent ta maison. Tes défenses se battent sans toi",
		sg_gap = "💥 Les zombies ont forcé ta maison et mangé de la nourriture: %d! Répare-la à l'établi",
		sg_gap0 = "💥 Les zombies ont forcé ta maison! Répare-la à l'établi",
		sg_held = "🛡 Ta maison a tenu! Pièces: +%d",
		sg_whole = "🔨 La maison est de nouveau entière",
		sg_def1 = "🛡 CLÔTURE PRÊTE! Les zombies cassent la maison moins vite",
		sg_def2 = "🛡 PIQUES PRÊTES! Les zombies contre tes murs se blessent",
		sg_def3 = "🛡 TOUR PRÊTE! Elle tire toute seule sur les zombies",
		sg_max = "🛡 Ta défense est complète",
		sg_status = "🧟 Siège! Zombies: %d   Ta maison: ❤ %d/%d",
		sg_status0 = "🧟 Siège! Zombies dans le village: %d",
	},
	de = {
		sg_night = "🧟 Zombies kommen zu den Häusern! Halte den Knopf an deiner Werkbank, um zu reparieren",
		sg_horde = "☠ EINE HORDE KOMMT!",
		sg_away = "🧟 Während du in der Stadt bist, greifen Zombies dein Haus an. Deine Verteidigung kämpft ohne dich",
		sg_gap = "💥 Zombies sind in dein Haus eingebrochen und haben Essen gefressen: %d! Repariere es an der Werkbank",
		sg_gap0 = "💥 Zombies sind in dein Haus eingebrochen! Repariere es an der Werkbank",
		sg_held = "🛡 Dein Haus hat gehalten! Münzen: +%d",
		sg_whole = "🔨 Das Haus ist wieder ganz",
		sg_def1 = "🛡 ZAUN FERTIG! Zombies zerstören das Haus langsamer",
		sg_def2 = "🛡 STACHELN FERTIG! Zombies an deinen Wänden verletzen sich",
		sg_def3 = "🛡 TURM FERTIG! Er schießt von selbst auf Zombies",
		sg_max = "🛡 Deine Verteidigung ist komplett",
		sg_status = "🧟 Belagerung! Zombies: %d   Dein Haus: ❤ %d/%d",
		sg_status0 = "🧟 Belagerung! Zombies in der Siedlung: %d",
	},
	it = {
		sg_night = "🧟 Gli zombie vanno verso le case! Tieni premuto il pulsante al banco da lavoro per riparare",
		sg_horde = "☠ ARRIVA UN'ORDA!",
		sg_away = "🧟 Mentre sei in città, gli zombie attaccano la tua casa. Le tue difese combattono senza di te",
		sg_gap = "💥 Gli zombie hanno sfondato la tua casa e mangiato cibo: %d! Riparala al banco da lavoro",
		sg_gap0 = "💥 Gli zombie hanno sfondato la tua casa! Riparala al banco da lavoro",
		sg_held = "🛡 La tua casa ha resistito! Monete: +%d",
		sg_whole = "🔨 La casa è di nuovo intera",
		sg_def1 = "🛡 RECINTO PRONTO! Gli zombie rompono la casa più lentamente",
		sg_def2 = "🛡 SPUNTONI PRONTI! Gli zombie contro i tuoi muri si feriscono",
		sg_def3 = "🛡 TORRE PRONTA! Spara agli zombie da sola",
		sg_max = "🛡 La tua difesa è completa",
		sg_status = "🧟 Assedio! Zombie: %d   La tua casa: ❤ %d/%d",
		sg_status0 = "🧟 Assedio! Zombie nel villaggio: %d",
	},
	pl = {
		sg_night = "🧟 Zombie idą na domy! Trzymaj przycisk przy warsztacie, żeby naprawiać",
		sg_horde = "☠ NADCHODZI HORDA!",
		sg_away = "🧟 Gdy jesteś w mieście, zombie atakują twój dom. Twoja obrona walczy bez ciebie",
		sg_gap = "💥 Zombie włamały się do twojego domu i zjadły jedzenie: %d! Napraw dom przy warsztacie",
		sg_gap0 = "💥 Zombie włamały się do twojego domu! Napraw go przy warsztacie",
		sg_held = "🛡 Twój dom się obronił! Monety: +%d",
		sg_whole = "🔨 Dom znów jest cały",
		sg_def1 = "🛡 PŁOT GOTOWY! Zombie niszczą dom wolniej",
		sg_def2 = "🛡 KOLCE GOTOWE! Zombie przy twoich ścianach dostają obrażenia",
		sg_def3 = "🛡 WIEŻA GOTOWA! Sama strzela do zombie",
		sg_max = "🛡 Twoja obrona jest kompletna",
		sg_status = "🧟 Oblężenie! Zombie: %d   Twój dom: ❤ %d/%d",
		sg_status0 = "🧟 Oblężenie! Zombie w osadzie: %d",
	},
	tr = {
		sg_night = "🧟 Zombiler evlere geliyor! Tamir için tezgâhtaki düğmeyi basılı tut",
		sg_horde = "☠ SÜRÜ GELİYOR!",
		sg_away = "🧟 Sen şehirdeyken zombiler evine saldırır. Savunman sensiz de savaşır",
		sg_gap = "💥 Zombiler evine girdi ve yemek yedi: %d! Evi tezgâhta tamir et",
		sg_gap0 = "💥 Zombiler evine girdi! Evi tezgâhta tamir et",
		sg_held = "🛡 Evin dayandı! Para: +%d",
		sg_whole = "🔨 Ev yeniden sağlam",
		sg_def1 = "🛡 ÇİT HAZIR! Zombiler evi daha yavaş kırar",
		sg_def2 = "🛡 DİKENLER HAZIR! Duvarındaki zombiler hasar alır",
		sg_def3 = "🛡 KULE HAZIR! Zombilere kendi kendine ateş eder",
		sg_max = "🛡 Savunman tamamlandı",
		sg_status = "🧟 Kuşatma! Zombiler: %d   Evin: ❤ %d/%d",
		sg_status0 = "🧟 Kuşatma! Yerleşimdeki zombiler: %d",
	},
	id = {
		sg_night = "🧟 Zombi menuju rumah-rumah! Tahan tombol di meja kerja untuk memperbaiki",
		sg_horde = "☠ GEROMBOLAN DATANG!",
		sg_away = "🧟 Saat kamu di kota, zombi menyerang rumahmu. Pertahananmu melawan tanpamu",
		sg_gap = "💥 Zombi menjebol rumahmu dan memakan makanan: %d! Perbaiki di meja kerja",
		sg_gap0 = "💥 Zombi menjebol rumahmu! Perbaiki di meja kerja",
		sg_held = "🛡 Rumahmu bertahan! Koin: +%d",
		sg_whole = "🔨 Rumah sudah utuh lagi",
		sg_def1 = "🛡 PAGAR JADI! Zombi merusak rumah lebih lambat",
		sg_def2 = "🛡 DURI JADI! Zombi di dindingmu terluka",
		sg_def3 = "🛡 MENARA JADI! Ia menembak zombi sendiri",
		sg_max = "🛡 Pertahananmu sudah lengkap",
		sg_status = "🧟 Kepungan! Zombi: %d   Rumahmu: ❤ %d/%d",
		sg_status0 = "🧟 Kepungan! Zombi di permukiman: %d",
	},
	vi = {
		sg_night = "🧟 Zombie đang kéo đến các ngôi nhà! Giữ nút ở bàn thợ để sửa nhà",
		sg_horde = "☠ BẦY ĐÀN ĐANG ĐẾN!",
		sg_away = "🧟 Khi bạn ở thành phố, zombie tấn công nhà bạn. Hệ thống phòng thủ vẫn chiến đấu thay bạn",
		sg_gap = "💥 Zombie đã phá nhà bạn và ăn thức ăn: %d! Hãy sửa ở bàn thợ",
		sg_gap0 = "💥 Zombie đã phá nhà bạn! Hãy sửa ở bàn thợ",
		sg_held = "🛡 Nhà bạn đã trụ vững! Xu: +%d",
		sg_whole = "🔨 Ngôi nhà lại nguyên vẹn",
		sg_def1 = "🛡 HÀNG RÀO XONG! Zombie phá nhà chậm hơn",
		sg_def2 = "🛡 CHÔNG XONG! Zombie sát tường bị thương",
		sg_def3 = "🛡 THÁP XONG! Nó tự bắn zombie",
		sg_max = "🛡 Phòng thủ của bạn đã đầy đủ",
		sg_status = "🧟 Vây hãm! Zombie: %d   Nhà bạn: ❤ %d/%d",
		sg_status0 = "🧟 Vây hãm! Zombie trong khu định cư: %d",
	},
	th = {
		sg_night = "🧟 ซอมบี้กำลังบุกบ้าน! กดปุ่มค้างที่โต๊ะช่างเพื่อซ่อมบ้าน",
		sg_horde = "☠ ฝูงซอมบี้กำลังมา!",
		sg_away = "🧟 ขณะที่คุณอยู่ในเมือง ซอมบี้จะโจมตีบ้านคุณ ระบบป้องกันสู้แทนคุณได้",
		sg_gap = "💥 ซอมบี้พังบ้านคุณและกินอาหารไป: %d! ซ่อมที่โต๊ะช่าง",
		sg_gap0 = "💥 ซอมบี้พังบ้านคุณ! ซ่อมที่โต๊ะช่าง",
		sg_held = "🛡 บ้านคุณรอดแล้ว! เหรียญ: +%d",
		sg_whole = "🔨 บ้านกลับมาสมบูรณ์แล้ว",
		sg_def1 = "🛡 รั้วเสร็จแล้ว! ซอมบี้พังบ้านได้ช้าลง",
		sg_def2 = "🛡 หนามเสร็จแล้ว! ซอมบี้ที่กำแพงจะบาดเจ็บ",
		sg_def3 = "🛡 หอคอยเสร็จแล้ว! มันยิงซอมบี้เอง",
		sg_max = "🛡 การป้องกันของคุณครบแล้ว",
		sg_status = "🧟 ถูกล้อม! ซอมบี้: %d   บ้านคุณ: ❤ %d/%d",
		sg_status0 = "🧟 ถูกล้อม! ซอมบี้ในหมู่บ้าน: %d",
	},
	ko = {
		sg_night = "🧟 좀비가 집으로 몰려와요! 작업대의 버튼을 길게 눌러 수리하세요",
		sg_horde = "☠ 좀비 떼가 몰려온다!",
		sg_away = "🧟 도시에 있는 동안 좀비가 집을 공격해요. 방어 시설은 혼자서도 싸워요",
		sg_gap = "💥 좀비가 집을 부수고 음식을 먹었어요: %d! 작업대에서 수리하세요",
		sg_gap0 = "💥 좀비가 집을 부쉈어요! 작업대에서 수리하세요",
		sg_held = "🛡 집을 지켜냈어요! 코인: +%d",
		sg_whole = "🔨 집이 다시 멀쩡해졌어요",
		sg_def1 = "🛡 울타리 완성! 좀비가 집을 더 느리게 부숴요",
		sg_def2 = "🛡 가시 완성! 벽에 붙은 좀비가 다쳐요",
		sg_def3 = "🛡 망루 완성! 스스로 좀비를 쏴요",
		sg_max = "🛡 방어가 모두 완성됐어요",
		sg_status = "🧟 포위! 좀비: %d   내 집: ❤ %d/%d",
		sg_status0 = "🧟 포위! 마을의 좀비: %d",
	},
	ja = {
		sg_night = "🧟 ゾンビが家に向かってくる!作業台のボタンを長押しして修理しよう",
		sg_horde = "☠ 大群が来るぞ!",
		sg_away = "🧟 街にいる間、ゾンビが君の家を襲う。防衛設備は君がいなくても戦うよ",
		sg_gap = "💥 ゾンビが家を破って食料を食べた: %d!作業台で修理しよう",
		sg_gap0 = "💥 ゾンビが家を破った!作業台で修理しよう",
		sg_held = "🛡 家を守りきった!コイン: +%d",
		sg_whole = "🔨 家が元どおりになった",
		sg_def1 = "🛡 フェンス完成!ゾンビが家を壊すのが遅くなる",
		sg_def2 = "🛡 トゲ完成!壁に来たゾンビがダメージを受ける",
		sg_def3 = "🛡 タワー完成!自動でゾンビを撃つ",
		sg_max = "🛡 防衛はすべて完成",
		sg_status = "🧟 包囲!ゾンビ: %d   君の家: ❤ %d/%d",
		sg_status0 = "🧟 包囲!集落のゾンビ: %d",
	},
}

local DEF_TEXT = { "sg_def1", "sg_def2", "sg_def3" }
local DEF_ICON = { "🚧", "📌", "🏹" } -- что построится следующим: забор, шипы, башня

return function(ctx: any, sv: any, hm: any): any
	if not LIVE and not game:GetService("RunService"):IsStudio() then
		return nil
	end
	local map = workspace:FindFirstChild("ZombieTagMap")
	if not map or type(hm) ~= "table" or type(hm.houses) ~= "table" or #hm.houses < 2 then
		return nil
	end
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local safely: (what: string, action: () -> ()) -> () = sv.safely
	local houses: { any } = hm.houses
	local GROUND = 1
	-- улица посёлка идёт посередине между двумя рядами участков
	local STREET_Z: number = (houses[1].origin.Z + houses[#houses].origin.Z) / 2
	local EXIT_X = 211 -- концы улицы: отсюда зомби приходят и сюда уходят

	-- тексты модуля становятся обычными текстами игры
	do
		local home = script.Parent
		local shared = if home then home:FindFirstChild("Texts") else nil
		local all: any = if shared then (require :: any)(shared) else nil
		if type(all) == "table" then
			for lang, set in pairs(TEXT) do
				local target = all[lang]
				if type(target) == "table" then
					for key, text in pairs(set) do
						target[key] = text
					end
				end
			end
		end
	end

	local world = Instance.new("Model")
	world.Name = "Siege"
	world.Parent = map
	local horde = Instance.new("Model") -- фигурки зомби
	horde.Name = "Horde"
	horde.Parent = world

	local WOOD = Color3.fromRGB(150, 112, 72)
	local DARK = Color3.fromRGB(46, 42, 40)
	local IRON = Color3.fromRGB(150, 154, 160)
	local RED = Color3.fromRGB(255, 80, 60)

	---------------------------------------------------------------------
	-- ЗАГОТОВКИ
	---------------------------------------------------------------------
	-- точка на участке: постройки описаны так, будто вход смотрит на +Z (как в модуле Homes)
	local function spot(site: any, x: number, y: number, z: number): Vector3
		local origin: Vector3 = site.origin
		return Vector3.new(origin.X + x * site.f, origin.Y + y, origin.Z + z * site.f)
	end
	local function frame(site: any, x: number, y: number, z: number, turn: CFrame?): CFrame
		local base = CFrame.new(spot(site, x, y, z)) * CFrame.Angles(0, site.yaw, 0)
		return if turn then base * turn else base
	end
	-- украшение: стоит на месте, сквозь него проходят, кнопкам и лучам оно не мешает
	local function deco(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.CFrame = at
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end
	-- запись в запасах игрока: целое число больше нуля (ноль не хранится)
	local function itemsOf(player: Player?): any
		local session = if player then sessions[player] else nil
		return if session then sv.stock(session).items else nil
	end
	local function get(items: any, key: string, limit: number): number
		local value = if items then items[key] else nil
		return if type(value) == "number" and value == value then math.clamp(math.floor(value), 0, limit) else 0
	end
	local function put(items: any, key: string, value: number)
		items[key] = if value > 0 then math.floor(value) else nil
	end
	local function stars(level: number): string
		return string.rep("★", level) .. string.rep("☆", 3 - level)
	end

	---------------------------------------------------------------------
	-- ПОСТЫ. У каждого участка посёлка свой пост: верстак, защита, прочность дома.
	-- Что построено и насколько дом повреждён, хранится в запасах хозяина (ext.items):
	-- def - ступень защиты (1-3), dmg - сколько прочности выбито, gap - пролом (1), held - сколько ночей дом устоял.
	---------------------------------------------------------------------
	local FRONT = { 1.7, 3.15, 3.15 }  -- где у сарая, дома и крепости передняя стена (от середины участка)
	local ROOF = { 11.5, 16, 16 }      -- на какой высоте висит прочность дома
	local BENCH_X, BENCH_Z = 14, 15.4  -- верстак стоит справа от доски стройки, у края улицы
	local posts: { any } = {}
	local night = { on = false, own = false, horde = false, planned = false, total = 0, startedAt = 0, endsAt = 0 }
	local nights = 0          -- сколько ночей уже было на этом сервере
	local lastEnd = os.clock() -- когда кончилась последняя ночь (или раунд в городе)
	local zombies: { any } = {}

	-- что сейчас с домом на участке: хозяин, его запасы, ступень дома, защита, прочность, пролом
	local function read(post: any): (Player?, any, number, number, number, number, boolean)
		local owner: Player? = post.site.owner
		local session = if owner then sessions[owner] else nil
		if not owner or not session then
			return nil, nil, 0, 0, 0, 0, false
		end
		local ext = sv.stock(session)
		local tier: number = ext.house
		local items = ext.items
		local max: number = HOUSE_HP[tier] or 0
		local gap = get(items, "gap", 1) == 1
		local hp = if gap then 0 else math.max(0, max - get(items, "dmg", 999))
		return owner, items, tier, get(items, "def", 3), max, hp, gap
	end

	local work: (post: any, player: Player) -> () = function() end -- нажатие у верстака (задаётся ниже)

	-- верстак: стол с ящиком инструментов и табличка над ним
	local function bench(post: any)
		local site = post.site
		local model = Instance.new("Model")
		model.Name = "Bench"
		local top = deco("SG_BenchTop", Vector3.new(3.2, 0.3, 1.8), frame(site, BENCH_X, 2.25, BENCH_Z), WOOD, Enum.Material.WoodPlanks, model)
		for _, x in ipairs({ -1.3, 1.3 }) do
			deco("SG_BenchLeg", Vector3.new(0.3, 2.1, 1.6), frame(site, BENCH_X + x, 1.05, BENCH_Z), DARK, Enum.Material.Wood, model)
		end
		deco("SG_Toolbox", Vector3.new(1.3, 0.7, 0.8), frame(site, BENCH_X - 0.7, 2.75, BENCH_Z), Color3.fromRGB(200, 60, 50), Enum.Material.Metal, model)
		deco("SG_Hammer", Vector3.new(0.25, 0.25, 1.3), frame(site, BENCH_X + 0.8, 2.55, BENCH_Z, CFrame.Angles(0, 0.5, 0)), IRON, Enum.Material.Metal, model)
		local sign = sv.sign(top, "", Color3.fromRGB(255, 255, 255), 5.2, 3.6, 90)
		post.benchTop = top
		post.benchText = sign:FindFirstChildOfClass("TextLabel")
		post.prompt = sv.button(top, "SG_Bench", FIX_HOLD, function(player: Player)
			work(post, player)
		end)
		post.bench = model
	end

	-- забор вокруг двора: столбы и две жерди; впереди оставлен проход
	local function fence(site: any, parent: Instance)
		local function run(x0: number, z0: number, x1: number, z1: number)
			local length = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
			local along = if math.abs(x1 - x0) > math.abs(z1 - z0) then Vector3.new(length, 0.3, 0.25) else Vector3.new(0.25, 0.3, length)
			for _, y in ipairs({ 1.3, 2.5 }) do
				deco("SG_Rail", along, frame(site, (x0 + x1) / 2, y, (z0 + z1) / 2), WOOD, Enum.Material.WoodPlanks, parent)
			end
			local count = math.max(1, math.floor(length / 3.7 + 0.5))
			for step = 0, count do
				local t = step / count
				deco("SG_Stake", Vector3.new(0.5, 3.6, 0.5), frame(site, x0 + (x1 - x0) * t, 1.8, z0 + (z1 - z0) * t), WOOD, Enum.Material.Wood, parent)
			end
		end
		run(-15.6, -13.6, 15.6, -13.6)
		run(-15.6, -13.6, -15.6, 13.4)
		run(15.6, -13.6, 15.6, 13.4)
		run(-15.6, 13.4, -4.4, 13.4)
		run(4.4, 13.4, 15.6, 13.4)
	end
	-- шипы перед входом: ряд заострённых кольев, наклонённых к улице
	local function spikes(site: any, front: number, parent: Instance)
		deco("SG_SpikeBase", Vector3.new(9.4, 0.25, 2.4), frame(site, 0, 0.13, front + 3.4), DARK, Enum.Material.Wood, parent)
		for step = 0, 7 do
			local x = -4.2 + step * 1.2
			deco("SG_Spike", Vector3.new(0.34, 2.2, 0.34), frame(site, x, 0.95, front + 3.7, CFrame.Angles(0.7, 0, 0)), WOOD, Enum.Material.Wood, parent)
			deco("SG_SpikeTip", Vector3.new(0.36, 0.5, 0.36), frame(site, x, 1.75, front + 4.38, CFrame.Angles(0.7, 0, 0)), IRON, Enum.Material.Metal, parent)
		end
	end
	-- башня в углу двора: четыре ноги, площадка под крышей и самострел
	local TOWER_X, TOWER_Z, TOWER_Y = -11.5, -8.5, 12
	local function tower(site: any, parent: Instance)
		for _, corner in ipairs({ { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } }) do
			deco("SG_TowerLeg", Vector3.new(0.6, TOWER_Y, 0.6), frame(site, TOWER_X + corner[1], TOWER_Y / 2, TOWER_Z + corner[2]), WOOD, Enum.Material.Wood, parent)
			deco("SG_TowerPost", Vector3.new(0.4, 3.4, 0.4), frame(site, TOWER_X + corner[1], TOWER_Y + 1.9, TOWER_Z + corner[2]), WOOD, Enum.Material.Wood, parent)
		end
		deco("SG_TowerBrace", Vector3.new(4.2, 0.3, 0.3), frame(site, TOWER_X, 5, TOWER_Z + 1.8, CFrame.Angles(0, 0, 0.9)), DARK, Enum.Material.Wood, parent)
		deco("SG_TowerBrace", Vector3.new(4.2, 0.3, 0.3), frame(site, TOWER_X, 5, TOWER_Z + 1.8, CFrame.Angles(0, 0, -0.9)), DARK, Enum.Material.Wood, parent)
		deco("SG_TowerFloor", Vector3.new(5, 0.4, 5), frame(site, TOWER_X, TOWER_Y + 0.2, TOWER_Z), WOOD, Enum.Material.WoodPlanks, parent)
		for _, side in ipairs({ { 0, 2.3, 5, 0.3 }, { 0, -2.3, 5, 0.3 }, { 2.3, 0, 0.3, 5 }, { -2.3, 0, 0.3, 5 } }) do
			deco("SG_TowerRail", Vector3.new(side[3], 1.2, side[4]), frame(site, TOWER_X + side[1], TOWER_Y + 1, TOWER_Z + side[2]), WOOD, Enum.Material.WoodPlanks, parent)
		end
		deco("SG_TowerRoof", Vector3.new(6.2, 0.5, 6.2), frame(site, TOWER_X, TOWER_Y + 3.8, TOWER_Z), Color3.fromRGB(112, 62, 54), Enum.Material.Slate, parent)
		deco("SG_TowerRoof", Vector3.new(3.6, 0.9, 3.6), frame(site, TOWER_X, TOWER_Y + 4.5, TOWER_Z), Color3.fromRGB(112, 62, 54), Enum.Material.Slate, parent)
		local eye = deco("SG_TowerEye", Vector3.new(1, 1, 1), frame(site, TOWER_X, TOWER_Y + 1.9, TOWER_Z), Color3.fromRGB(255, 220, 110), Enum.Material.Neon, parent)
		eye.Shape = Enum.PartType.Ball
		sv.glow(eye, Color3.fromRGB(255, 220, 110), 16, 1.2)
	end
	-- дом повреждён: дым; сильно повреждён - ещё и доски крест-накрест на окнах; пролом - выбитая дверь и огонь
	local function wounds(site: any, tier: number, stage: number, gap: boolean, parent: Instance)
		local front = FRONT[tier]
		if stage >= 1 or gap then
			local source = deco("SG_Smoke", Vector3.new(1, 1, 1), frame(site, 0, ROOF[tier] - 5, -3), DARK, Enum.Material.SmoothPlastic, parent)
			source.Transparency = 1
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(60, 56, 54)
			smoke.Opacity = if gap or stage >= 2 then 0.5 else 0.25
			smoke.Size = if gap or stage >= 2 then 6 else 3
			smoke.RiseVelocity = 5
			smoke.Parent = source
		end
		if stage >= 2 or gap then
			for _, x in ipairs({ -3.6, 3.6 }) do
				deco("SG_Plank", Vector3.new(3.4, 0.5, 0.2), frame(site, x, 4.4, front + 0.5, CFrame.Angles(0, 0, 0.5)), WOOD, Enum.Material.WoodPlanks, parent)
				deco("SG_Plank", Vector3.new(3.4, 0.5, 0.2), frame(site, x, 4.4, front + 0.55, CFrame.Angles(0, 0, -0.5)), WOOD, Enum.Material.WoodPlanks, parent)
			end
		end
		if gap then
			deco("SG_Hole", Vector3.new(4.6, 6.6, 0.5), frame(site, 0, 3.3, front + 0.2), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, parent)
			for index, plank in ipairs({ { -1.6, 0.4 }, { 0.6, -0.7 }, { 2, 1.1 } }) do
				deco("SG_Debris", Vector3.new(2.6, 0.25, 0.6), frame(site, plank[1], 0.2, front + 2 + index, CFrame.Angles(0, plank[2], 0)), WOOD, Enum.Material.WoodPlanks, parent)
			end
			local ember = deco("SG_Fire", Vector3.new(1, 1, 1), frame(site, 0, 0.8, front + 0.6), RED, Enum.Material.Neon, parent)
			ember.Transparency = 1
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 8
			fire.Parent = ember
			sv.glow(ember, Color3.fromRGB(255, 140, 60), 18, 1.6)
		end
	end

	-- что написано на табличке верстака: прочность дома и защита; ниже - что сделает кнопка и сколько это стоит
	local function benchLine(post: any): string
		local owner, _items, tier, def, max, hp, gap = read(post)
		if not owner or tier < 1 then
			return ""
		end
		local session = sessions[owner]
		local mats: number = if session then sv.stock(session).mats else 0
		local head = (if gap then "💥 0/" .. max else "❤ " .. hp .. "/" .. max) .. "   🛡 " .. stars(def)
		if night.on and post.wave > 0 then
			-- на дом нападают: у верстака только чинят (бесплатно); пролом чинится утром
			return head .. "\n" .. (if gap then "⏳" elseif hp < max then "🔨" else "🔨 ✔")
		elseif gap then
			return head .. "\n🔨 🔩 " .. mats .. "/" .. GAP_COST[tier]
		elseif hp < max then
			return head .. "\n🔨 🔩 " .. mats .. "/" .. math.ceil((max - hp) / FIX_DAY)
		elseif def < 3 then
			return head .. "\n" .. DEF_ICON[def + 1] .. " 🔩 " .. mats .. "/" .. DEF_COST[def + 1]
		end
		return head .. "\n⭐"
	end

	-- приводит пост в порядок: верстак есть только у дома с хозяином, защита и повреждения - какие записаны в запасах
	local function dress(post: any)
		local site = post.site
		local owner, items, tier, def, max, hp, gap = read(post)
		-- дом достроили до следующей ступени: стены новые, повреждений на них нет
		if owner and post.owner == owner and tier > post.tier and post.tier >= 1 and items then
			put(items, "dmg", 0)
			put(items, "gap", 0)
			post.hurt = 0
			hp, gap = max, false
		end
		post.owner, post.tier = owner, tier
		local has = owner ~= nil and tier >= 1
		post.bench.Parent = if has then post.model else nil
		local stage = if not has or gap then 0 elseif hp < max * 0.3 then 2 elseif hp < max * 0.6 then 1 else 0
		local look = if has then tier .. "/" .. def .. "/" .. stage .. "/" .. tostring(gap) else ""
		if look ~= post.look then
			post.look = look
			for _, child in ipairs(post.extras:GetChildren()) do
				child:Destroy()
			end
			post.eye = nil
			if has then
				if def >= 1 then
					fence(site, post.extras)
				end
				if def >= 2 then
					spikes(site, FRONT[tier], post.extras)
				end
				if def >= 3 then
					tower(site, post.extras)
					post.eye = spot(site, TOWER_X, TOWER_Y + 1.9, TOWER_Z)
				end
				wounds(site, tier, stage, gap, post.extras)
			end
		end
		if has then
			post.benchText.Text = benchLine(post)
			-- прочность над домом видна, когда дому что-то грозит: идёт осада, он повреждён или проломлен
			local show = gap or hp < max or (night.on and post.wave > 0)
			post.life.Enabled = show
			if show then
				post.lifeText.Text = if gap then "💥" else "❤ " .. hp .. "/" .. max
				post.lifeText.TextColor3 = if gap or hp < max * 0.3 then RED elseif hp < max * 0.6 then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(140, 255, 140)
				post.lifePart.Position = spot(site, 0, ROOF[tier], -3)
			end
		else
			post.life.Enabled = false
		end
	end

	for index, site in ipairs(houses) do
		local model = Instance.new("Model")
		model.Name = "Post" .. index
		model.Parent = world
		local extras = Instance.new("Model")
		extras.Name = "Extras"
		extras.Parent = model
		local post: any = {
			index = index, site = site, model = model, extras = extras,
			owner = nil :: Player?, tier = 0, look = "",
			hurt = 0,          -- урон, которого ещё не набралось на целую единицу прочности
			wave = 0,          -- сколько зомби пришло к дому этой ночью (0 - на него не нападали)
			broke = false,     -- дом проломили (или доели) этой ночью
			shotAt = 0,        -- когда башня стреляла в последний раз
			eye = nil :: Vector3?,
		}
		bench(post)
		local lifePart = deco("SG_Life", Vector3.new(1, 1, 1), CFrame.new(spot(site, 0, 16, -3)), DARK, Enum.Material.SmoothPlastic, model)
		lifePart.Transparency = 1
		local life = sv.sign(lifePart, "", Color3.fromRGB(140, 255, 140), 9, 0, 160)
		life.Enabled = false
		post.lifePart, post.life, post.lifeText = lifePart, life, life:FindFirstChildOfClass("TextLabel")
		posts[index] = post
	end

	-- проломы в частоколе на концах улицы: отсюда приходят зомби
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (EXIT_X + 4.9)
		deco("SG_Breach", Vector3.new(0.6, 9, 13), CFrame.new(x, GROUND + 4.5, STREET_Z), Color3.fromRGB(12, 12, 14), Enum.Material.SmoothPlastic, world)
		for _, z in ipairs({ -7.2, 7.2 }) do
			deco("SG_BreachPost", Vector3.new(0.9, 12, 0.9), CFrame.new(x - side * 0.4, GROUND + 6, STREET_Z + z) * CFrame.Angles(0, 0, side * 0.12), DARK, Enum.Material.Wood, world)
			local lamp = deco("SG_BreachLamp", Vector3.new(1, 1, 1), CFrame.new(x - side * 1, GROUND + 9.5, STREET_Z + z), RED, Enum.Material.Neon, world)
			lamp.Shape = Enum.PartType.Ball
		end
	end

	---------------------------------------------------------------------
	-- ЗОМБИ ОСАДЫ. Это фигурки без своего ума: модуль сам ведёт их по улице к дому и обратно.
	-- У фигурки одна стоящая на месте деталь (корень), остальные приварены к ней: по сети идёт одно число.
	---------------------------------------------------------------------
	local SKIN = Color3.fromRGB(126, 170, 96)
	local SHIRTS = { Color3.fromRGB(110, 98, 84), Color3.fromRGB(84, 100, 120), Color3.fromRGB(120, 84, 84), Color3.fromRGB(96, 110, 84) }
	local PANTS = Color3.fromRGB(60, 62, 70)
	local rng = Random.new()

	local function figure(brute: boolean): (Model, Part)
		local s = if brute then 1.6 else 1
		local model = Instance.new("Model")
		model.Name = if brute then "SiegeBrute" else "SiegeZombie"
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.Transparency = 1
		root.Size = Vector3.new(1, 1, 1)
		root.CFrame = CFrame.new(0, -60, 0)
		root.Parent = model
		local skin = if brute then Color3.fromRGB(96, 124, 80) else SKIN
		local shirt = if brute then Color3.fromRGB(70, 50, 48) else SHIRTS[rng:NextInteger(1, #SHIRTS)]
		local function part(name: string, x: number, y: number, z: number, at: CFrame, color: Color3, material: Enum.Material?): Part
			local piece = Instance.new("Part")
			piece.Name = name
			piece.Anchored = false
			piece.Massless = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false
			piece.Size = Vector3.new(x, y, z) * s
			piece.CFrame = root.CFrame * at
			piece.Color = color
			piece.Material = material or Enum.Material.SmoothPlastic
			piece.TopSurface = Enum.SurfaceType.Smooth
			piece.BottomSurface = Enum.SurfaceType.Smooth
			piece.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = piece
			weld.Parent = piece
			return piece
		end
		-- корень стоит на земле; фигурка смотрит в сторону -Z корня
		local function at(x: number, y: number, z: number): CFrame
			return CFrame.new(x * s, y * s, z * s)
		end
		part("Leg", 1, 2, 1, at(-0.5, 1, 0), PANTS)
		part("Leg", 1, 2, 1, at(0.5, 1, 0.15), PANTS)
		part("Torso", 2, 2, 1, at(0, 3, 0) * CFrame.Angles(-0.12, 0, 0), shirt)
		part("Arm", 1, 1, 2.1, at(-1.5, 3.5, -1.1), skin)
		part("Arm", 1, 1, 2.1, at(1.5, 3.3, -1.1), skin)
		part("Head", 1.3, 1.3, 1.3, at(0, 4.65, -0.15), skin)
		for _, x in ipairs({ -0.3, 0.3 }) do
			part("Eye", 0.26, 0.2, 0.1, at(x, 4.75, -0.82), if brute then RED else Color3.fromRGB(230, 255, 120), Enum.Material.Neon)
		end
		if brute then
			for _, x in ipairs({ -1.5, 1.5 }) do
				part("Spike", 0.5, 1.1, 0.5, at(x, 4.4, 0) * CFrame.Angles(0, 0, if x < 0 then 0.5 else -0.5), DARK, Enum.Material.Slate)
			end
		end
		return model, root
	end

	-- куда встаёт у дома зомби с этим номером: в ряд перед стеной
	local function slot(tier: number, order: number, total: number): (number, number)
		local row = (order - 1) // 6
		local inRow = math.min(6, total - row * 6)
		local place = (order - 1) % 6
		return (place - (inRow - 1) / 2) * 2.3, FRONT[tier] + 2.6 + row * 2.4
	end
	-- путь зомби: конец улицы -> улица напротив участка -> проход во двор -> место у стены
	local function route(post: any, tier: number, order: number, total: number): { Vector3 }
		local site = post.site
		local origin: Vector3 = site.origin
		local side = if origin.X < 0 then -1 else 1
		local lane = rng:NextNumber(-3.5, 3.5)
		local x, z = slot(tier, order, total)
		return {
			Vector3.new(side * EXIT_X, GROUND, STREET_Z + lane),
			Vector3.new(origin.X + math.clamp(x, -3, 3) * site.f, GROUND, STREET_Z + lane),
			spot(site, math.clamp(x, -3, 3), 0, 15),
			spot(site, x, 0, z),
		}
	end
	local function spawn(post: any, tier: number, order: number, total: number, weight: number, brute: boolean, delay: number)
		local model, root = figure(brute)
		table.insert(zombies, {
			post = post, model = model, root = root, brute = brute,
			weight = weight,                              -- за скольких зомби считается эта фигурка
			hp = ZOMBIE_HP * (if brute then 3 else 1),
			path = route(post, tier, order, total), leg = 1, -- leg: к какой точке пути он сейчас идёт
			pos = Vector3.new(0, -60, 0),
			state = "wait", at = os.clock() + delay,       -- wait: ещё не вышел; walk, bite, feast, leave
			phase = rng:NextNumber(0, 6),
		})
	end
	local function alive(): number
		local count = 0
		for _, zombie in ipairs(zombies) do
			if zombie.state ~= "leave" then
				count += zombie.weight
			end
		end
		return math.floor(count + 0.5)
	end
	-- ставит фигурку в точку: лицом по ходу, с покачиванием
	local function pose(zombie: any, pos: Vector3, toward: Vector3, now: number, lunge: number)
		local flat = Vector3.new(toward.X - pos.X, 0, toward.Z - pos.Z)
		local yaw = if flat.Magnitude > 0.05 then math.atan2(-flat.X, -flat.Z) else zombie.yaw or 0
		zombie.yaw = yaw
		local sway = math.sin(now * 6 + zombie.phase)
		zombie.pos = pos
		zombie.root.CFrame = CFrame.new(pos.X, pos.Y + math.abs(sway) * 0.25, pos.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, sway * 0.07) * CFrame.new(0, 0, -lunge)
	end
	local function remove(index: number, puff: boolean)
		local zombie = zombies[index]
		table.remove(zombies, index)
		if puff then
			local cloud = deco("SG_Puff", Vector3.new(3, 3, 3), CFrame.new(zombie.pos + Vector3.new(0, 3, 0)), Color3.fromRGB(150, 255, 110), Enum.Material.Neon, world)
			cloud.Shape = Enum.PartType.Ball
			cloud.Transparency = 0.4
			task.delay(0.35, function()
				cloud:Destroy()
			end)
		end
		zombie.model:Destroy()
	end
	-- зомби разворачивается и уходит туда, откуда пришёл
	local function retreat(zombie: any)
		if zombie.state == "leave" then
			return
		end
		if zombie.state == "wait" then
			zombie.at = 0
			zombie.path = { zombie.path[1] }
		else
			local back = {}
			for leg = math.min(zombie.leg, #zombie.path) - 1, 1, -1 do
				table.insert(back, zombie.path[leg])
			end
			if #back == 0 then
				back = { zombie.path[1] }
			end
			zombie.path = back
		end
		zombie.leg = 1
		zombie.state = "leave"
	end

	---------------------------------------------------------------------
	-- ПРОЛОМ И УТРО
	---------------------------------------------------------------------
	-- зомби ворвались в дом: съедают часть еды; хозяин узнаёт об этом, где бы он ни был
	local function breach(post: any)
		if post.broke then
			return
		end
		post.broke = true
		local owner, items = read(post)
		if not owner or not items then
			return
		end
		put(items, "gap", 1)
		put(items, "dmg", 0)
		post.hurt = 0
		local ext = sv.stock(sessions[owner])
		local lost = if ext.food > 0 then math.max(1, math.ceil(ext.food * GAP_FOOD)) else 0
		ext.food -= lost
		if lost > 0 then
			ctx.toast(owner, "sg_gap", lost)
		else
			ctx.toast(owner, "sg_gap0")
		end
		ctx.sound(owner, "block")
		local now = os.clock()
		for _, zombie in ipairs(zombies) do
			if zombie.post == post and zombie.state ~= "leave" then
				-- пируют три секунды и уходят
				if zombie.state == "bite" then
					zombie.state, zombie.at = "feast", now + 3
				end
			end
		end
		dress(post)
	end

	local function finish()
		if not night.on then
			return
		end
		night.on = false
		lastEnd = os.clock()
		for _, post in ipairs(posts) do
			local owner, items, _tier, _def, _max, _hp, gap = read(post)
			if post.wave > 0 and not post.broke and not gap and owner and items and post.waveOwner == owner then
				put(items, "held", math.min(999, get(items, "held", 999) + 1))
				local coins = math.floor(HELD_COINS * post.wave * (if night.horde then 1.5 else 1) + 0.5)
				local session = sessions[owner]
				if session and coins > 0 then
					session.profile.coins += coins
					ctx.sync(owner)
					ctx.toast(owner, "sg_held", coins)
				end
			end
			post.wave = 0
			post.broke = false
			dress(post)
		end
		for _, zombie in ipairs(zombies) do
			retreat(zombie)
		end
	end

	---------------------------------------------------------------------
	-- НОЧЬ
	---------------------------------------------------------------------
	local told: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any -- кому что уже сказано
	local function toldOf(player: Player): any
		local memo = told[player]
		if not memo then
			memo = { night = 0, away = false }
			told[player] = memo
		end
		return memo
	end
	-- игрок сейчас в посёлке (у себя или у соседей) и не участвует в раунде
	local function inSettlement(player: Player): boolean
		local root: BasePart? = ctx.getAlive(player)
		return root ~= nil and not inRound[player] and root.Position.Z > 0 and hm.inHome(root.Position) == true
	end

	local function begin(own: boolean, big: boolean?)
		if night.on then
			return
		end
		nights += 1
		night.on, night.own, night.planned, night.total = true, own, false, 0
		night.horde = big == true or (big == nil and HORDE_EVERY > 0 and nights % HORDE_EVERY == 0)
		night.startedAt = os.clock()
		night.endsAt = if own then night.startedAt + HOME_NIGHT else math.huge
		for _, post in ipairs(posts) do
			post.wave, post.broke, post.hurt = 0, false, 0
		end
	end
	-- Через полторы секунды после начала ночи уже видно, кто ушёл в город, а кто остался дома:
	-- к их домам и выходят зомби. Дом того, кто стоит в лобби, не трогают.
	local function plan()
		night.planned = true
		local list = {}
		local total = 0
		for _, post in ipairs(posts) do
			local owner, items, tier, _def, _max, _hp, gap = read(post)
			local root: BasePart? = if owner then ctx.getAlive(owner) else nil
			local present = owner ~= nil and (inRound[owner] == true or (root ~= nil and hm.inHome(root.Position) == true))
			if owner and items and tier >= 1 and present and not QUIET then
				local count = WAVE[tier] + math.min(WAVE_MORE, get(items, "held", 999) // WAVE_GROW)
				if night.horde then
					count = math.ceil(count * HORDE_SIZE)
				end
				if gap then
					count = math.min(count, 2) -- в проломленный дом приходят доедать
				end
				table.insert(list, { post = post, tier = tier, count = count, brute = night.horde and tier >= 2 and not gap, owner = owner })
				total += count
			end
		end
		night.total = total
		-- на полном сервере зомби больше, чем стоит показывать: одна фигурка тогда считается за нескольких
		local share = math.max(1, total / MAX_ZOMBIES)
		for _, entry in ipairs(list) do
			local post = entry.post
			local figures = math.max(1, math.floor(entry.count / share + 0.5))
			local weight = entry.count / figures
			post.wave, post.waveOwner = entry.count, entry.owner
			local all = figures + (if entry.brute then 1 else 0)
			for order = 1, figures do
				spawn(post, entry.tier, order, all, weight, false, rng:NextNumber(0, 9))
			end
			if entry.brute then
				spawn(post, entry.tier, all, all, 1, true, rng:NextNumber(4, 10))
			end
			dress(post)
			-- хозяин в городе: один раз за игру ему говорят, что дом не остаётся без присмотра
			local memo = toldOf(entry.owner)
			if inRound[entry.owner] and not memo.away then
				memo.away = true
				ctx.toast(entry.owner, "sg_away")
			end
		end
		if total > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				if sessions[player] and inSettlement(player) then
					local memo = toldOf(player)
					if night.horde then
						ctx.big(player, "sg_horde")
						ctx.sound(player, "hunt")
					elseif memo.night < 2 then
						memo.night += 1
						ctx.toast(player, "sg_night")
					end
				end
			end
		end
	end

	-- один шаг осады: зомби идут, ломают, получают от шипов и башни
	local function step(now: number, dt: number)
		local bites: { [any]: number } = {}
		for index = #zombies, 1, -1 do
			local zombie = zombies[index]
			local post = zombie.post
			local owner, _items, tier, def, _max, _hp, gap = read(post)
			local state: string = zombie.state
			if state ~= "leave" and (not night.on or owner ~= post.waveOwner or tier < 1) then
				retreat(zombie) -- хозяин ушёл из игры или ночь кончилась
				state = "leave"
			end
			if zombie.hp <= 0 then
				remove(index, true)
			elseif state == "wait" then
				if now >= zombie.at then
					zombie.state = "walk"
					zombie.leg = 2
					pose(zombie, zombie.path[1], zombie.path[2], now, 0)
					zombie.model.Parent = horde
				end
			elseif state == "walk" or state == "leave" then
				if state == "leave" and zombie.model.Parent == nil then
					remove(index, false) -- так и не вышел на улицу
				else
					local speed = SPEED * (if zombie.brute then 0.75 else 1) * (if state == "leave" then 1.8 else 1)
					local left = speed * dt
					local pos: Vector3 = zombie.pos
					local target: Vector3 = zombie.path[zombie.leg] or pos
					while left > 0 and zombie.leg <= #zombie.path do
						target = zombie.path[zombie.leg]
						local gapTo = (target - pos).Magnitude
						if gapTo <= left then
							pos = target
							left -= gapTo
							zombie.leg += 1
						else
							pos += (target - pos).Unit * left
							left = 0
						end
					end
					pose(zombie, pos, target, now, 0)
					if zombie.leg > #zombie.path then
						if state == "leave" then
							remove(index, false)
						elseif gap then
							-- дом уже проломлен: зомби доедают запасы и уходят
							zombie.state, zombie.at = "feast", now + 3
							breach(post)
						else
							zombie.state = "bite"
						end
					end
				end
			elseif state == "bite" then
				if gap then
					zombie.state, zombie.at = "feast", now + 3
				else
					bites[post] = (bites[post] or 0) + zombie.weight * (if zombie.brute then 3 else 1)
					if def >= 2 then
						zombie.hp -= SPIKES * dt
					end
					local wall = spot(post.site, 0, 0, FRONT[math.max(1, tier)])
					pose(zombie, zombie.path[#zombie.path], Vector3.new(zombie.pos.X, 0, wall.Z), now, math.max(0, math.sin(now * 5 + zombie.phase)) * 0.7)
				end
			elseif state == "feast" then
				pose(zombie, zombie.pos, zombie.pos + Vector3.new(math.sin(now * 3 + zombie.phase), 0, math.cos(now * 3 + zombie.phase)), now, 0)
				if now >= zombie.at then
					retreat(zombie)
				end
			end
		end
		for _, post in ipairs(posts) do
			local owner, items, tier, def, max, _hp, gap = read(post)
			local force = bites[post]
			if force and owner and items and not gap and tier >= 1 then
				post.hurt += force * BITE * dt * (if def >= 1 then 1 - FENCE_SAVE else 1)
				if post.hurt >= 1 then
					local whole = math.floor(post.hurt)
					post.hurt -= whole
					local damage = math.min(max, get(items, "dmg", 999) + whole)
					put(items, "dmg", damage)
					if damage >= max then
						breach(post)
					end
				end
			end
			-- башня: раз в несколько секунд стреляет в ближайшего зомби, который идёт к этому дому
			local eye: Vector3? = post.eye
			if eye and def >= 3 and night.on and now - post.shotAt >= TOWER_EVERY then
				local best, bestGap = nil, TOWER_RANGE
				for _, zombie in ipairs(zombies) do
					if zombie.post == post and (zombie.state == "walk" or zombie.state == "bite") then
						local away = (zombie.pos - eye).Magnitude
						if away < bestGap then
							best, bestGap = zombie, away
						end
					end
				end
				if best then
					post.shotAt = now
					best.hp -= TOWER_HIT / best.weight
					local aim: Vector3 = best.pos + Vector3.new(0, 3, 0)
					local bolt = deco("SG_Bolt", Vector3.new(0.18, 0.18, (aim - eye).Magnitude), CFrame.lookAt((eye + aim) / 2, aim), Color3.fromRGB(255, 230, 120), Enum.Material.Neon, world)
					task.delay(0.15, function()
						bolt:Destroy()
					end)
				end
			end
		end
	end

	---------------------------------------------------------------------
	-- ВЕРСТАК
	---------------------------------------------------------------------
	work = function(post: any, player: Player)
		local session = sessions[player]
		local root: BasePart? = ctx.getAlive(player)
		if not session or not root or (root.Position - post.benchTop.Position).Magnitude > REACH then
			return
		end
		local owner, items, tier, def, max, hp, gap = read(post)
		if not owner or not items or tier < 1 then
			return
		end
		-- зомби этого раунда дома не чинят
		if inRound[player] and isZombie[player] then
			ctx.sound(player, "deny")
			return
		end
		local mine = owner == player
		local ownerSession = sessions[owner]
		local ext = sv.stock(ownerSession)
		-- всё, что стоит деталей, делает только хозяин и только когда его прогресс загружен
		local function owned(): boolean
			if not mine then
				ctx.toast(player, "hm_not_yours")
				ctx.sound(player, "deny")
				return false
			end
			if not ownerSession.canSave and ctx.saveBroken() then
				ctx.toast(player, "no_save")
				ctx.sound(player, "deny")
				return false
			end
			return true
		end
		local function afford(cost: number): boolean
			if ext.mats < cost then
				ctx.toast(player, "hm_need_parts", cost - ext.mats)
				ctx.sound(player, "deny")
				return false
			end
			return true
		end
		if night.on and post.wave > 0 then
			-- На дом нападают: у верстака только чинят. Чинить может любой, и бесплатно: сосед помогает соседу.
			-- Пролом чинится утром, покупки тоже ждут утра: тот, кто часто жмёт кнопку, не купит ничего случайно.
			if gap then
				ctx.sound(player, "deny")
			elseif hp < max then
				local damage = math.max(0, max - hp - FIX_NIGHT)
				put(items, "dmg", damage)
				ctx.sound(player, "tick")
				if damage == 0 then
					ctx.toast(player, "sg_whole")
				end
			else
				ctx.sound(player, "tick")
			end
		elseif gap then
			local cost = GAP_COST[tier]
			if owned() and afford(cost) then
				ext.mats -= cost
				put(items, "gap", 0)
				put(items, "dmg", 0)
				post.hurt = 0
				ctx.toast(player, "sg_whole")
				ctx.sound(player, "buy")
			end
		elseif hp < max then
			-- днём: одна деталь чинит кусок прочности; чинится столько, на сколько хватает деталей
			local need = math.ceil((max - hp) / FIX_DAY)
			if owned() and afford(if ext.mats > 0 then 1 else need) then
				local spend = math.min(need, ext.mats)
				ext.mats -= spend
				local damage = math.max(0, max - hp - spend * FIX_DAY)
				put(items, "dmg", damage)
				ctx.sound(player, "buy")
				if damage == 0 then
					ctx.toast(player, "sg_whole")
				end
			end
		elseif def < 3 then
			local cost = DEF_COST[def + 1]
			if owned() and afford(cost) then
				ext.mats -= cost
				put(items, "def", def + 1)
				ctx.big(player, DEF_TEXT[def + 1])
				ctx.sound(player, "buy")
			end
		elseif mine then
			ctx.toast(player, "sg_max")
		end
		dress(post)
		-- доска стройки рядом показывает те же детали: пусть обновится сразу
		if hm.refresh then
			hm.refresh(post.site)
		end
	end

	-- проломленный дом не добавляет мест в рюкзаке, пока его не починили
	local oldBonus = sv.hooks.packBonus
	sv.hooks.packBonus = function(player: Player): number
		local bonus: number = if oldBonus then oldBonus(player) else 0
		if get(itemsOf(player), "gap", 1) == 1 then
			return 0
		end
		return bonus
	end

	-- верхняя строка экрана у того, кто дома во время осады
	if type(hm.hooks) == "table" then
		hm.hooks.status = function(player: Player): string?
			if not night.on or not night.planned or night.total == 0 then
				return nil
			end
			local left = alive()
			local index: number? = hm.plotOf[player]
			local post = if index then posts[index] else nil
			if post and post.wave > 0 then
				local _owner, _items, _tier, _def, max, hp = read(post)
				return ctx.tr(player, "sg_status", left, hp, max)
			end
			return ctx.tr(player, "sg_status0", left)
		end
	end

	---------------------------------------------------------------------
	-- ГЛАВНЫЙ ЦИКЛ МОДУЛЯ
	---------------------------------------------------------------------
	local function somebodyHome(): boolean
		for _, post in ipairs(posts) do
			local owner, _items, tier = read(post)
			if owner and tier >= 1 and inSettlement(owner) then
				return true
			end
		end
		return false
	end
	task.spawn(function()
		local wasRound = false
		local last = os.clock()
		local slow = 0
		while world.Parent do
			task.wait(0.1)
			local now = os.clock()
			local dt = math.min(0.5, now - last)
			last = now
			safely("siege", function()
				local round: boolean = ctx.state()
				if round and not wasRound then
					begin(false) -- ночь в городе - ночь и в посёлке
				elseif wasRound and not round then
					lastEnd = now
					if night.on and not night.own then
						finish()
					end
				end
				wasRound = round
				-- своя ночь посёлка кончается по часам или раньше, если зомби не осталось
				if night.on and night.own and (now >= night.endsAt or (night.planned and #zombies == 0 and now - night.startedAt > 12)) then
					finish()
				end
				-- в городе никого: ночь приходит в посёлок сама
				if not night.on and not round and now - lastEnd >= HOME_DAY and somebodyHome() then
					begin(true)
				end
				if night.on and not night.planned and now - night.startedAt >= 1.5 then
					plan()
				end
				if #zombies > 0 then
					step(now, dt)
				end
				slow += dt
				if slow >= 1 then
					slow = 0
					for _, post in ipairs(posts) do
						dress(post)
					end
				end
			end)
		end
	end)

	-- команды проверок в Studio (через дверь модуля Survival)
	local oldDebug = sv.hooks.debug
	sv.hooks.debug = function(player: Player, command: string, a: any, b: any): string?
		local index: number? = hm.plotOf[player]
		local post = if index then posts[index] else nil
		local items = itemsOf(player)
		if command == "siege" then -- ночь в посёлке прямо сейчас (a = true: орда)
			begin(true, a == true)
		elseif command == "dawn" then
			finish()
		elseif command == "def" and items then
			put(items, "def", sv.count(a, 3))
		elseif command == "dmg" and items then
			put(items, "dmg", sv.count(a, 999))
			put(items, "gap", if b == true then 1 else 0)
		elseif command ~= "sg" then
			return if oldDebug then oldDebug(player, command, a, b) else nil
		end
		local line = "night " .. tostring(night.on) .. " own " .. tostring(night.own) .. " horde " .. tostring(night.horde) .. " n " .. nights .. " zombies " .. #zombies .. "/" .. alive()
		if post then
			local _owner, _items, tier, def, max, hp, gap = read(post)
			line ..= " | plot " .. post.index .. " tier " .. tier .. " def " .. def .. " hp " .. hp .. "/" .. max .. " gap " .. tostring(gap) .. " wave " .. post.wave .. " held " .. get(items, "held", 999)
		end
		return line
	end

	local api = {
		world = world, posts = posts, zombies = zombies, night = night, begin = begin, finish = finish, plan = plan, step = step,
		work = work, read = read, dress = dress, alive = alive,
		count = function(): number
			return nights
		end,
	}
	sv.siege = api
	return api
end
