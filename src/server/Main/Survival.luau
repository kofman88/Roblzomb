--!strict
--[[
	ВЫЖИВАНИЕ (версия 8, этап 1): добыча в городе, рюкзак, вакцина, голод и запасы.

	КУДА ВСТАВИТЬ: это ModuleScript с именем Survival. Он лежит ВНУТРИ главного скрипта, рядом с Texts и Extras:
	ServerScriptService -> Script -> Survival. Его запускает модуль Extras; без него игра работает по-старому.

	ЧТО ОН ДЕЛАЕТ
	- Ночью (в раунде) по городу стоят ящики. Еда - у магазинов и заправок, детали - на стройке и у контейнеров,
	  лучшие ящики - на крышах. Цвет ящика показывает редкость. Чтобы открыть, нужно подержать кнопку:
	  чем ценнее ящик, тем дольше.
	- У больниц стоят шкафчики с вакциной. Вакцина один раз спасает от укуса.
	- Всё найденное лежит в рюкзаке. Дожил до утра или улетел на вертолёте - рюкзак уходит в запасы.
	  Заразили - рюкзак остаётся на земле: еду съедят зомби, остальное подберут другие выжившие.
	- Сытость: кто не ел, бежит медленнее и виден зомби. Ужин из запасов и еда из рюкзака это лечат.
	- Зомби копят мозги: за каждого пойманного и за съеденные чужие припасы.
	Запасы (еда, детали, вакцина, мозги) сохраняются вместе с монетами. На них будут строиться дом и логово.
]]

local LIVE = true -- true - слой выживания (добыча, рюкзак, голод, дома и логово) работает у игроков; false - только в Studio

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
local STEP = 0.25            -- как часто модуль сверяет, что изменилось (секунды)
local PACK_SIZE = 6          -- сколько еды и деталей помещается в рюкзак
local CRATES_BASE = 16       -- столько ящиков стоит в городе...
local CRATES_PER_PLAYER = 2  -- ...плюс столько за каждого выжившего игрока...
local CRATES_MAX = 28        -- ...но не больше этого
local CRATE_RETURN = 20      -- через сколько секунд вместо открытого ящика появляется новый в другом месте
local CRATE_GAP = 20         -- ящики не стоят ближе друг к другу
local BUTTON_REACH = 8       -- с какого расстояния видна кнопка у ящика и шкафчика (с земли ящик на крыше не открыть)
local REACH = 12             -- с какого расстояния сервер верит нажатию (запас на задержку связи)
local REACH_HIGH = 6         -- и на сколько выше или ниже ящика могут быть ноги игрока: на крышу нужно залезть
local HOLD_SLACK = 0.5       -- какая доля удержания кнопки прощается из-за задержки связи (на телефоне сигнал бывает с перебоями)
local OPEN_PAUSE = 1         -- пауза между двумя ящиками у одного игрока
local SPARE_COINS = 3        -- монет за каждую находку, которая не влезла в рюкзак
local VACCINE_HOLD = 3       -- сколько секунд держать кнопку у шкафчика
local VACCINE_RETURN = 40    -- через сколько секунд в шкафчике снова появляется вакцина
local VACCINE_CARRY = 2      -- сколько доз можно носить с собой
local VACCINE_STOCK = 3      -- сколько доз хранится в запасах
local VACCINE_IMMUNE = 3     -- сколько секунд после срабатывания вакцины игрока нельзя заразить
local VACCINE_STUN = 1.5     -- на сколько секунд замирает укусивший зомби
local SUPPER_FULL = 100      -- сытость в начале ночи, если в запасах была еда на ужин
local SUPPER_NONE = 50       -- и если еды не было
local DRAIN = 0.5            -- сколько сытости уходит за секунду (100 хватает на 200 секунд: дольше самой длинной ночи)
local EAT_AT = 30            -- ниже этой сытости выживший сам ест из рюкзака
local FOOD_VALUE = 40        -- сколько сытости даёт одна еда
local HUNGRY_SPEED = 0.93    -- голодный бежит медленнее, но всё ещё быстрее обычного зомби-бота
local HUNGRY_RAGE = 0.985    -- в ночь "ярость" боты быстрее, и голодный замедляется меньше
local HUNGRY_BEAM = 12       -- высота столбика света над головой голодного
local BAG_LIFE = 45          -- сколько секунд брошенный рюкзак лежит на земле
local BAG_REACH = 5          -- с какого расстояния его подбирают
local CARGO_AT = 45          -- на какой секунде ночи с неба падает ценный груз
local CARGO_CLEAR = 16       -- груз не падает ближе к люку: у люка своя кнопка
local START_FOOD = 8         -- еда в запасах у нового игрока: первые ночи сыт и тот, кто ещё не открывает ящики
local BRAINS_CATCH = 1       -- мозгов зомби за пойманного горожанина
local BRAINS_PLAYER = 3      -- и за пойманного игрока
local MAX_FOOD, MAX_MATS, MAX_BRAINS = 99, 9999, 99999

-- РЕДКОСТЬ. hold - сколько секунд открывать, units - сколько находок внутри, coins - монеты сверху,
-- far - с какого расстояния видна звезда над ящиком, beam - высота луча над ним (ценный ящик виден из-за домов).
local TIERS = {
	{ name = "common", color = Color3.fromRGB(200, 205, 215), hold = 1, units = 1, coins = 0, far = 90, beam = 0 },
	{ name = "uncommon", color = Color3.fromRGB(90, 225, 110), hold = 1.5, units = 2, coins = 0, far = 130, beam = 0 },
	{ name = "rare", color = Color3.fromRGB(80, 160, 255), hold = 2, units = 3, coins = 5, far = 200, beam = 24 },
	{ name = "epic", color = Color3.fromRGB(190, 105, 255), hold = 2.5, units = 4, coins = 15, far = 320, beam = 50 },
	{ name = "legendary", color = Color3.fromRGB(255, 200, 60), hold = 3, units = 6, coins = 40, far = 900, beam = 150 },
	-- мифические вещи в ящиках не лежат: они будут даваться только за подвиги
	{ name = "mythic", color = Color3.fromRGB(255, 70, 70), hold = 4, units = 6, coins = 100, far = 900, beam = 150 },
}
-- шансы редкости (в процентах) по опасности места: 1 - на земле, 2 - на невысокой крыше, 3 - на крыше башни
local ODDS = {
	{ 70, 24, 5.5, 0.5, 0 },
	{ 50, 32, 14, 3.5, 0.5 },
	{ 30, 35, 24, 9, 2 },
}
local CARGO_ODDS = { 0, 0, 0, 70, 30 } -- груз с неба: только эпический или легендарный
local FIND_TEXT: { [number]: string } = { [3] = "sv_find3", [4] = "sv_find4", [5] = "sv_find5", [6] = "sv_find5" } -- о какой находке сказать игроку
-- где что лежит: по названию части города
local SPOT_KINDS: { [string]: string } = {
	Stall = "food", Kiosk = "food", Pump = "food", GasShop = "food", Shop = "food", Canopy = "food",
	Crate = "mats", Container = "mats", School = "mix", MallRoof = "mix", Tower = "mix",
}

---------------------------------------------------------------------
-- ТЕКСТЫ. Добавляются к общим текстам игры (модуль Texts) при запуске.
---------------------------------------------------------------------
local TEXT: { [string]: { [string]: string } } = {
	en = {
		sv_supper = "🍞 Supper from your stock: you are full for the night",
		sv_nosupper = "🍗 No food in stock: you start hungry. Look for crates near the shops!",
		sv_hint = "📦 Hold the button next to a crate to open it",
		sv_full = "🎒 The backpack is full! Survive until morning or reach the helicopter",
		sv_saved = "🎒 Loot saved: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 You lost your backpack!",
		sv_bag = "🎒 You picked up a dropped backpack",
		sv_find3 = "Rare crate!",
		sv_find4 = "Epic crate!",
		sv_find5 = "LEGENDARY CRATE!",
		sv_vac_got = "💉 Vaccine! It will save you from one bite",
		sv_vac_have = "💉 You cannot carry more vaccine",
		sv_vac_used = "💉 The vaccine worked! Run!",
		sv_vac_bite = "💉 They had a vaccine! Bite again!",
		sv_hungry = "🍗 You are starving: you run slower and zombies see you. Find food!",
		sv_cargo = "📦 Supply drop! Look for the beam of light",
		sv_brains = "🧠 Brains collected tonight: +%d",
		sv_ate = "🧠 You ate their supplies: +%d",
	},
	ru = {
		sv_supper = "🍞 Ужин из запасов: ты сыт на всю ночь",
		sv_nosupper = "🍗 Еды в запасах нет: ты начинаешь голодным. Ищи ящики у магазинов!",
		sv_hint = "📦 Подержи кнопку рядом с ящиком, чтобы открыть его",
		sv_full = "🎒 Рюкзак полон! Доживи до утра или улетай на вертолёте",
		sv_saved = "🎒 Добыча сохранена: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Ты потерял рюкзак!",
		sv_bag = "🎒 Ты подобрал брошенный рюкзак",
		sv_find3 = "Редкий ящик!",
		sv_find4 = "Эпический ящик!",
		sv_find5 = "ЛЕГЕНДАРНЫЙ ЯЩИК!",
		sv_vac_got = "💉 Вакцина! Она спасёт от одного укуса",
		sv_vac_have = "💉 Больше вакцины не унести",
		sv_vac_used = "💉 Вакцина сработала! Беги!",
		sv_vac_bite = "💉 У него была вакцина! Кусай ещё раз!",
		sv_hungry = "🍗 Ты голоден: бежишь медленнее, и зомби тебя видят. Найди еду!",
		sv_cargo = "📦 Сброшен груз! Ищи луч света",
		sv_brains = "🧠 Мозгов за ночь: +%d",
		sv_ate = "🧠 Ты съел чужие припасы: +%d",
	},
	es = {
		sv_supper = "🍞 Cena de tus reservas: estás lleno para toda la noche",
		sv_nosupper = "🍗 No hay comida en tus reservas: empiezas con hambre. ¡Busca cajas cerca de las tiendas!",
		sv_hint = "📦 Mantén pulsado el botón junto a una caja para abrirla",
		sv_full = "🎒 ¡La mochila está llena! Sobrevive hasta la mañana o llega al helicóptero",
		sv_saved = "🎒 Botín guardado: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 ¡Perdiste tu mochila!",
		sv_bag = "🎒 Recogiste una mochila abandonada",
		sv_find3 = "¡Caja rara!",
		sv_find4 = "¡Caja épica!",
		sv_find5 = "¡CAJA LEGENDARIA!",
		sv_vac_got = "💉 ¡Vacuna! Te salvará de un mordisco",
		sv_vac_have = "💉 No puedes llevar más vacunas",
		sv_vac_used = "💉 ¡La vacuna funcionó! ¡Corre!",
		sv_vac_bite = "💉 ¡Tenía una vacuna! ¡Muerde otra vez!",
		sv_hungry = "🍗 Tienes hambre: corres más lento y los zombis te ven. ¡Busca comida!",
		sv_cargo = "📦 ¡Cayó un suministro! Busca el rayo de luz",
		sv_brains = "🧠 Cerebros de esta noche: +%d",
		sv_ate = "🧠 Te comiste sus provisiones: +%d",
	},
	pt = {
		sv_supper = "🍞 Jantar do seu estoque: você está cheio para a noite toda",
		sv_nosupper = "🍗 Sem comida no estoque: você começa com fome. Procure caixas perto das lojas!",
		sv_hint = "📦 Segure o botão ao lado de uma caixa para abrir",
		sv_full = "🎒 A mochila está cheia! Sobreviva até de manhã ou chegue ao helicóptero",
		sv_saved = "🎒 Itens guardados: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Você perdeu sua mochila!",
		sv_bag = "🎒 Você pegou uma mochila largada",
		sv_find3 = "Caixa rara!",
		sv_find4 = "Caixa épica!",
		sv_find5 = "CAIXA LENDÁRIA!",
		sv_vac_got = "💉 Vacina! Ela salva você de uma mordida",
		sv_vac_have = "💉 Você não consegue levar mais vacinas",
		sv_vac_used = "💉 A vacina funcionou! Corra!",
		sv_vac_bite = "💉 Ele tinha vacina! Morda de novo!",
		sv_hungry = "🍗 Você está com fome: corre mais devagar e os zumbis veem você. Ache comida!",
		sv_cargo = "📦 Caiu uma carga! Procure o feixe de luz",
		sv_brains = "🧠 Cérebros desta noite: +%d",
		sv_ate = "🧠 Você comeu os suprimentos dele: +%d",
	},
	fr = {
		sv_supper = "🍞 Dîner pris dans tes réserves : tu es rassasié pour la nuit",
		sv_nosupper = "🍗 Pas de nourriture en réserve : tu commences affamé. Cherche des caisses près des magasins !",
		sv_hint = "📦 Maintiens le bouton près d'une caisse pour l'ouvrir",
		sv_full = "🎒 Le sac est plein ! Survis jusqu'au matin ou rejoins l'hélicoptère",
		sv_saved = "🎒 Butin sauvegardé : 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Tu as perdu ton sac !",
		sv_bag = "🎒 Tu as ramassé un sac abandonné",
		sv_find3 = "Caisse rare !",
		sv_find4 = "Caisse épique !",
		sv_find5 = "CAISSE LÉGENDAIRE !",
		sv_vac_got = "💉 Vaccin ! Il te sauvera d'une morsure",
		sv_vac_have = "💉 Tu ne peux pas porter plus de vaccins",
		sv_vac_used = "💉 Le vaccin a marché ! Cours !",
		sv_vac_bite = "💉 Il avait un vaccin ! Mords encore !",
		sv_hungry = "🍗 Tu as faim : tu cours moins vite et les zombies te voient. Trouve à manger !",
		sv_cargo = "📦 Un colis est tombé ! Cherche le rayon de lumière",
		sv_brains = "🧠 Cerveaux cette nuit : +%d",
		sv_ate = "🧠 Tu as mangé ses provisions : +%d",
	},
	de = {
		sv_supper = "🍞 Abendessen aus dem Vorrat: Du bist für die Nacht satt",
		sv_nosupper = "🍗 Kein Essen im Vorrat: Du startest hungrig. Such Kisten bei den Läden!",
		sv_hint = "📦 Halte die Taste neben einer Kiste, um sie zu öffnen",
		sv_full = "🎒 Der Rucksack ist voll! Überlebe bis zum Morgen oder erreiche den Hubschrauber",
		sv_saved = "🎒 Beute gesichert: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Du hast deinen Rucksack verloren!",
		sv_bag = "🎒 Du hast einen fremden Rucksack aufgehoben",
		sv_find3 = "Seltene Kiste!",
		sv_find4 = "Epische Kiste!",
		sv_find5 = "LEGENDÄRE KISTE!",
		sv_vac_got = "💉 Impfstoff! Er rettet dich vor einem Biss",
		sv_vac_have = "💉 Mehr Impfstoff kannst du nicht tragen",
		sv_vac_used = "💉 Der Impfstoff hat gewirkt! Lauf!",
		sv_vac_bite = "💉 Er hatte Impfstoff! Beiß noch mal!",
		sv_hungry = "🍗 Du hast Hunger: Du läufst langsamer und Zombies sehen dich. Such Essen!",
		sv_cargo = "📦 Eine Lieferung ist gelandet! Such den Lichtstrahl",
		sv_brains = "🧠 Gehirne in dieser Nacht: +%d",
		sv_ate = "🧠 Du hast seine Vorräte gefressen: +%d",
	},
	it = {
		sv_supper = "🍞 Cena dalle scorte: sei sazio per tutta la notte",
		sv_nosupper = "🍗 Niente cibo nelle scorte: parti affamato. Cerca le casse vicino ai negozi!",
		sv_hint = "📦 Tieni premuto il pulsante vicino a una cassa per aprirla",
		sv_full = "🎒 Lo zaino è pieno! Sopravvivi fino al mattino o raggiungi l'elicottero",
		sv_saved = "🎒 Bottino salvato: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Hai perso il tuo zaino!",
		sv_bag = "🎒 Hai raccolto uno zaino abbandonato",
		sv_find3 = "Cassa rara!",
		sv_find4 = "Cassa epica!",
		sv_find5 = "CASSA LEGGENDARIA!",
		sv_vac_got = "💉 Vaccino! Ti salverà da un morso",
		sv_vac_have = "💉 Non puoi portare altro vaccino",
		sv_vac_used = "💉 Il vaccino ha funzionato! Corri!",
		sv_vac_bite = "💉 Aveva un vaccino! Mordi ancora!",
		sv_hungry = "🍗 Hai fame: corri più piano e gli zombie ti vedono. Trova del cibo!",
		sv_cargo = "📦 È caduto un rifornimento! Cerca il raggio di luce",
		sv_brains = "🧠 Cervelli di questa notte: +%d",
		sv_ate = "🧠 Hai mangiato le sue provviste: +%d",
	},
	pl = {
		sv_supper = "🍞 Kolacja z zapasów: jesteś najedzony na całą noc",
		sv_nosupper = "🍗 Brak jedzenia w zapasach: zaczynasz głodny. Szukaj skrzyń przy sklepach!",
		sv_hint = "📦 Przytrzymaj przycisk przy skrzyni, aby ją otworzyć",
		sv_full = "🎒 Plecak jest pełny! Przetrwaj do rana albo dotrzyj do helikoptera",
		sv_saved = "🎒 Łup zapisany: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Straciłeś plecak!",
		sv_bag = "🎒 Podniosłeś porzucony plecak",
		sv_find3 = "Rzadka skrzynia!",
		sv_find4 = "Epicka skrzynia!",
		sv_find5 = "LEGENDARNA SKRZYNIA!",
		sv_vac_got = "💉 Szczepionka! Uratuje cię przed jednym ugryzieniem",
		sv_vac_have = "💉 Nie uniesiesz więcej szczepionek",
		sv_vac_used = "💉 Szczepionka zadziałała! Uciekaj!",
		sv_vac_bite = "💉 Miał szczepionkę! Ugryź jeszcze raz!",
		sv_hungry = "🍗 Jesteś głodny: biegniesz wolniej i zombie cię widzą. Znajdź jedzenie!",
		sv_cargo = "📦 Spadł zrzut! Szukaj snopu światła",
		sv_brains = "🧠 Mózgi z tej nocy: +%d",
		sv_ate = "🧠 Zjadłeś jego zapasy: +%d",
	},
	tr = {
		sv_supper = "🍞 Stoktan akşam yemeği: gece boyunca toksun",
		sv_nosupper = "🍗 Stokta yemek yok: aç başlıyorsun. Dükkânların yanındaki sandıkları ara!",
		sv_hint = "📦 Sandığı açmak için yanındaki düğmeyi basılı tut",
		sv_full = "🎒 Çanta dolu! Sabaha kadar hayatta kal ya da helikoptere ulaş",
		sv_saved = "🎒 Ganimet kaydedildi: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Çantanı kaybettin!",
		sv_bag = "🎒 Bırakılmış bir çanta aldın",
		sv_find3 = "Nadir sandık!",
		sv_find4 = "Destansı sandık!",
		sv_find5 = "EFSANEVİ SANDIK!",
		sv_vac_got = "💉 Aşı! Seni bir ısırıktan kurtarır",
		sv_vac_have = "💉 Daha fazla aşı taşıyamazsın",
		sv_vac_used = "💉 Aşı işe yaradı! Kaç!",
		sv_vac_bite = "💉 Onda aşı vardı! Bir daha ısır!",
		sv_hungry = "🍗 Açsın: daha yavaş koşuyorsun ve zombiler seni görüyor. Yemek bul!",
		sv_cargo = "📦 Yardım paketi düştü! Işık huzmesini ara",
		sv_brains = "🧠 Bu gecenin beyinleri: +%d",
		sv_ate = "🧠 Onun erzağını yedin: +%d",
	},
	id = {
		sv_supper = "🍞 Makan malam dari persediaan: kamu kenyang sepanjang malam",
		sv_nosupper = "🍗 Tidak ada makanan di persediaan: kamu mulai dengan lapar. Cari peti di dekat toko!",
		sv_hint = "📦 Tahan tombol di dekat peti untuk membukanya",
		sv_full = "🎒 Ransel penuh! Bertahan sampai pagi atau capai helikopter",
		sv_saved = "🎒 Barang tersimpan: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Kamu kehilangan ranselmu!",
		sv_bag = "🎒 Kamu mengambil ransel yang terjatuh",
		sv_find3 = "Peti langka!",
		sv_find4 = "Peti epik!",
		sv_find5 = "PETI LEGENDARIS!",
		sv_vac_got = "💉 Vaksin! Menyelamatkanmu dari satu gigitan",
		sv_vac_have = "💉 Kamu tidak bisa membawa vaksin lagi",
		sv_vac_used = "💉 Vaksin bekerja! Lari!",
		sv_vac_bite = "💉 Dia punya vaksin! Gigit lagi!",
		sv_hungry = "🍗 Kamu lapar: larimu lebih lambat dan zombie melihatmu. Cari makanan!",
		sv_cargo = "📦 Kiriman jatuh! Cari sorotan cahaya",
		sv_brains = "🧠 Otak malam ini: +%d",
		sv_ate = "🧠 Kamu memakan persediaannya: +%d",
	},
	vi = {
		sv_supper = "🍞 Bữa tối từ kho: bạn no suốt đêm",
		sv_nosupper = "🍗 Kho không còn thức ăn: bạn bắt đầu trong cơn đói. Tìm thùng gần các cửa hàng!",
		sv_hint = "📦 Giữ nút bên cạnh thùng để mở",
		sv_full = "🎒 Ba lô đã đầy! Sống sót đến sáng hoặc lên trực thăng",
		sv_saved = "🎒 Đã cất đồ: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 Bạn đã mất ba lô!",
		sv_bag = "🎒 Bạn nhặt được một ba lô bị bỏ lại",
		sv_find3 = "Thùng hiếm!",
		sv_find4 = "Thùng sử thi!",
		sv_find5 = "THÙNG HUYỀN THOẠI!",
		sv_vac_got = "💉 Vắc-xin! Nó cứu bạn khỏi một vết cắn",
		sv_vac_have = "💉 Bạn không thể mang thêm vắc-xin",
		sv_vac_used = "💉 Vắc-xin có tác dụng! Chạy đi!",
		sv_vac_bite = "💉 Họ có vắc-xin! Cắn lần nữa!",
		sv_hungry = "🍗 Bạn đang đói: chạy chậm hơn và zombie nhìn thấy bạn. Tìm thức ăn!",
		sv_cargo = "📦 Hàng tiếp tế đã rơi! Tìm cột ánh sáng",
		sv_brains = "🧠 Não thu được đêm nay: +%d",
		sv_ate = "🧠 Bạn đã ăn đồ dự trữ của họ: +%d",
	},
	th = {
		sv_supper = "🍞 มื้อเย็นจากคลัง: คุณอิ่มตลอดคืน",
		sv_nosupper = "🍗 ไม่มีอาหารในคลัง: คุณเริ่มต้นด้วยความหิว หากล่องใกล้ร้านค้า!",
		sv_hint = "📦 กดปุ่มค้างไว้ข้างกล่องเพื่อเปิด",
		sv_full = "🎒 กระเป๋าเต็มแล้ว! เอาชีวิตรอดถึงเช้าหรือไปที่เฮลิคอปเตอร์",
		sv_saved = "🎒 เก็บของแล้ว: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 คุณทำกระเป๋าหาย!",
		sv_bag = "🎒 คุณเก็บกระเป๋าที่ถูกทิ้งไว้",
		sv_find3 = "กล่องหายาก!",
		sv_find4 = "กล่องมหากาพย์!",
		sv_find5 = "กล่องระดับตำนาน!",
		sv_vac_got = "💉 วัคซีน! ช่วยคุณจากการกัดหนึ่งครั้ง",
		sv_vac_have = "💉 คุณพกวัคซีนเพิ่มไม่ได้แล้ว",
		sv_vac_used = "💉 วัคซีนได้ผล! วิ่ง!",
		sv_vac_bite = "💉 เขามีวัคซีน! กัดอีกครั้ง!",
		sv_hungry = "🍗 คุณหิว: วิ่งช้าลงและซอมบี้มองเห็นคุณ หาอาหาร!",
		sv_cargo = "📦 เสบียงตกลงมาแล้ว! มองหาลำแสง",
		sv_brains = "🧠 สมองที่ได้คืนนี้: +%d",
		sv_ate = "🧠 คุณกินเสบียงของเขา: +%d",
	},
	ko = {
		sv_supper = "🍞 비축 식량으로 저녁 식사: 밤새 배가 부릅니다",
		sv_nosupper = "🍗 비축 식량이 없습니다: 배고픈 채로 시작합니다. 상점 근처 상자를 찾으세요!",
		sv_hint = "📦 상자 옆에서 버튼을 길게 눌러 여세요",
		sv_full = "🎒 배낭이 가득 찼습니다! 아침까지 살아남거나 헬리콥터로 가세요",
		sv_saved = "🎒 전리품 저장: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 배낭을 잃었습니다!",
		sv_bag = "🎒 버려진 배낭을 주웠습니다",
		sv_find3 = "희귀 상자!",
		sv_find4 = "영웅 상자!",
		sv_find5 = "전설 상자!",
		sv_vac_got = "💉 백신! 한 번 물려도 살 수 있습니다",
		sv_vac_have = "💉 백신을 더 들 수 없습니다",
		sv_vac_used = "💉 백신이 효과를 냈습니다! 도망치세요!",
		sv_vac_bite = "💉 상대에게 백신이 있었습니다! 다시 물으세요!",
		sv_hungry = "🍗 배가 고픕니다: 느려지고 좀비에게 보입니다. 음식을 찾으세요!",
		sv_cargo = "📦 보급품이 떨어졌습니다! 빛기둥을 찾으세요",
		sv_brains = "🧠 오늘 밤 모은 뇌: +%d",
		sv_ate = "🧠 상대의 식량을 먹었습니다: +%d",
	},
	ja = {
		sv_supper = "🍞 たくわえから夕食: ひと晩おなかいっぱい",
		sv_nosupper = "🍗 たくわえに食べ物がない: おなかがすいたままスタート。お店の近くの箱をさがそう!",
		sv_hint = "📦 箱のそばでボタンを長押しして開けよう",
		sv_full = "🎒 リュックがいっぱい! 朝まで生きのこるかヘリコプターへ行こう",
		sv_saved = "🎒 せんりひんをほぞん: 🍞 +%d   🔩 +%d",
		sv_lost = "🎒 リュックをなくした!",
		sv_bag = "🎒 落ちていたリュックをひろった",
		sv_find3 = "レアな箱!",
		sv_find4 = "エピックな箱!",
		sv_find5 = "レジェンドの箱!",
		sv_vac_got = "💉 ワクチン! 1回かまれても助かる",
		sv_vac_have = "💉 ワクチンはこれ以上持てない",
		sv_vac_used = "💉 ワクチンがきいた! にげろ!",
		sv_vac_bite = "💉 あいてはワクチンを持っていた! もう一度かもう!",
		sv_hungry = "🍗 おなかがすいた: 足がおそくなり、ゾンビに見つかる。食べ物をさがそう!",
		sv_cargo = "📦 ほきゅう物資が落ちた! 光のはしらをさがそう",
		sv_brains = "🧠 今夜あつめた脳: +%d",
		sv_ate = "🧠 あいての食料を食べた: +%d",
	},
}

return function(ctx: any): any
	if not LIVE and not game:GetService("RunService"):IsStudio() then
		return nil
	end
	local map = workspace:FindFirstChild("ZombieTagMap")
	local city = if map then map:FindFirstChild("City") else nil
	if not map or not city then
		return nil
	end

	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local huds: { [Player]: any } = ctx.huds
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local rng = Random.new()
	-- сюда соседний модуль Homes (дома и логово) кладёт свои функции:
	-- packBonus(player) - лишние места в рюкзаке, catchBonus(player) - лишние мозги за пойманного игрока,
	-- dayRow(player, session, ext) - строка запасов днём, debug(...) - команды проверок в Studio
	local hooks: any = {}

	-- ошибка в одном месте не должна останавливать остальное
	local warned: { [string]: number } = {}
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok and os.clock() - (warned[what] or -100) > 60 then
			warned[what] = os.clock()
			warn("[Zombie Tag] Survival (" .. what .. "): " .. tostring(err))
		end
	end

	-- тексты модуля становятся обычными текстами игры: их понимают ctx.tr, ctx.toast и ctx.big
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

	---------------------------------------------------------------------
	-- ЗАПАСЫ. Хранятся в прогрессе игрока одной таблицей ext и сохраняются вместе с монетами.
	-- Всё, что пришло из сохранения, проверяется: в таблице остаются только известные поля и целые числа.
	---------------------------------------------------------------------
	local clean: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any  -- какие таблицы уже проверены
	local gifted: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- и в какие положена еда для новичка
	local function count(value: any, limit: number): number
		return if type(value) == "number" and value == value then math.clamp(math.floor(value), 0, limit) else 0
	end
	local function stockOf(profile: any): any
		local ext = profile.ext
		if type(ext) == "table" and clean[ext] then
			return ext
		end
		-- house, nest - ступень дома и логова (0-3); home - куда игрок возвращается после ночи (0 лобби, 1 дом, 2 логово)
		local fresh = { v = 1, food = 0, mats = 0, vac = 0, bio = 0, house = 0, nest = 0, home = 0, items = {} :: { [string]: number } }
		if type(ext) == "table" then
			fresh.food = count(ext.food, MAX_FOOD)
			fresh.mats = count(ext.mats, MAX_MATS)
			fresh.vac = count(ext.vac, VACCINE_STOCK)
			fresh.bio = count(ext.bio, MAX_BRAINS)
			fresh.house = count(ext.house, 3)
			fresh.nest = count(ext.nest, 3)
			fresh.home = count(ext.home, 2)
			if type(ext.items) == "table" then
				local kinds = 0
				for id, amount in pairs(ext.items) do
					local have = count(amount, 999)
					if type(id) == "string" and #id <= 24 and have > 0 and kinds < 200 then
						fresh.items[id] = have
						kinds += 1
					end
				end
			end
		else
			fresh.food = START_FOOD
			gifted[fresh] = true
		end
		clean[fresh] = true
		profile.ext = fresh
		return fresh
	end
	local function stock(session: any): any
		return stockOf(session.profile)
	end
	-- Прогресс не загрузился при входе и нашёлся позже (это делает Extras): к загруженным запасам
	-- добавляется всё, что игрок успел добыть за это время. Еда новичка второй раз не выдаётся.
	ctx.mergeExt = function(profile: any, temp: any)
		local earned = temp.ext
		if type(earned) ~= "table" or not clean[earned] then
			return
		end
		local into = stockOf(profile)
		into.food = math.min(MAX_FOOD, into.food + math.max(0, earned.food - (if gifted[earned] then START_FOOD else 0)))
		into.mats = math.min(MAX_MATS, into.mats + earned.mats)
		into.bio = math.min(MAX_BRAINS, into.bio + earned.bio)
		into.vac = math.min(VACCINE_STOCK, into.vac + earned.vac)
		into.house = math.max(into.house, earned.house)
		into.nest = math.max(into.nest, earned.nest)
		into.home = if earned.home > 0 then earned.home else into.home
		for id, amount in pairs(earned.items) do
			into.items[id] = math.min(999, (into.items[id] or 0) + amount)
		end
	end

	---------------------------------------------------------------------
	-- МЕСТА ДЛЯ ЯЩИКОВ. Берутся из готового города по названиям частей: на прилавках, колонках,
	-- контейнерах и на крышах. Город при этом не меняется.
	---------------------------------------------------------------------
	local loot = Instance.new("Model")
	loot.Name = "Loot"
	-- всё содержимое всегда загружено у каждого игрока: луч над ценным ящиком виден с другого конца города
	loot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	loot.Parent = map

	local spots: { any } = {}
	local hospitals: { BasePart } = {}
	local manholes: { Vector3 } = {}
	local solid: { BasePart } = {}
	local parts = city:GetChildren()
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			if part.CanCollide then
				table.insert(solid, part)
			end
			if part.Name == "Hospital" then
				table.insert(hospitals, part)
			elseif part.Name == "Manhole" then
				table.insert(manholes, part.Position)
			end
		end
	end
	-- свободно ли место: ящик не должен торчать из стены, будки или другого контейнера
	local function free(at: Vector3, base: BasePart): boolean
		for _, part in ipairs(solid) do
			if part ~= base then
				local p, size = part.Position, part.Size
				if math.abs(p.X - at.X) < size.X / 2 + 1.7 and math.abs(p.Z - at.Z) < size.Z / 2 + 1.7
					and p.Y + size.Y / 2 > at.Y + 0.2 and p.Y - size.Y / 2 < at.Y + 3 then
					return false
				end
			end
		end
		return true
	end
	local SHIFTS = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5), Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0) }
	for _, part in ipairs(parts) do
		local kind = SPOT_KINDS[part.Name]
		if kind and part:IsA("BasePart") then
			local size, at = part.Size, part.Position
			local x, z = at.X, at.Z
			local fits = true
			if part.Name == "Tower" then
				fits = size.Y <= 50 -- на крыши выше не ведёт лестница
				-- в углу крыши: подальше от вертолётной площадки посередине и от будок
				x -= size.X / 2 - 5
				z += size.Z / 2 - 5
			elseif part.Name == "MallRoof" then
				fits = size.X < 20 -- только боковые плиты: рядом с длинной садится вертолёт
			elseif part.Name == "School" then
				x += 6
			elseif part.Name == "Shop" or part.Name == "GasShop" then
				x += 3
				z += 3
			elseif part.Name == "Container" then
				fits = at.Y - size.Y / 2 < 5 -- на контейнер, который лежит на других, не забраться
			end
			if fits then
				local top = at.Y + size.Y / 2
				-- если место занято, ящик сдвигается по той же крыше; не нашлось свободного - места здесь нет
				for index, shift in ipairs(SHIFTS) do
					local place = Vector3.new(x, top, z) + shift
					local inside = index == 1 or (math.abs(place.X - at.X) <= size.X / 2 - 1.5 and math.abs(place.Z - at.Z) <= size.Z / 2 - 1.5)
					if inside and free(place, part) then
						table.insert(spots, {
							at = place,
							kind = kind,
							level = if top < 9 then 1 elseif top < 20 then 2 else 3,
							busy = false,
						})
						break
					end
				end
			end
		end
	end

	-- части модуля не мешают ни бегать, ни лучам ботов, ни защите от читеров
	local function ghost<T>(part: T): T
		local item = part :: any
		item.Anchored = true
		item.CanCollide = false
		item.CanQuery = false
		item.CanTouch = false
		item.CastShadow = false
		return part
	end
	local function block(name: string, size: Vector3, at: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = at
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		ghost(part)
		part.Parent = parent
		return part
	end
	-- луч света вверх: его видно из-за домов
	local function ray(parent: Instance, base: Vector3, height: number, wide: number, color: Color3): Part
		local beam = block("SV_Beam", Vector3.new(wide, height, wide), base + Vector3.new(0, height / 2, 0), color, Enum.Material.Neon, parent)
		beam.Transparency = 0.45
		return beam
	end
	local function glow(part: Instance, color: Color3, range: number, brightness: number): PointLight
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range
		light.Brightness = brightness
		light.Shadows = false
		light.Parent = part
		return light
	end
	-- значок над предметом: светится сам, а текста в нём нет
	local function sign(part: Instance, text: string, color: Color3, size: number, height: number, far: number): BillboardGui
		local board = Instance.new("BillboardGui")
		board.Name = "SV_Sign"
		board.Size = UDim2.fromScale(size, size)
		board.StudsOffset = Vector3.new(0, height, 0)
		board.AlwaysOnTop = false
		board.MaxDistance = far
		board.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.3
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = board
		board.Parent = part
		return board
	end
	local holding: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any -- кто какую кнопку начал держать и когда
	local function button(part: Instance, name: string, hold: number, action: (player: Player) -> ())
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.ObjectText = "" -- без слов, как и все кнопки в игре: понятно на любом языке
		prompt.ActionText = ""
		prompt.HoldDuration = hold
		prompt.MaxActivationDistance = BUTTON_REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			holding[player] = { prompt = prompt, at = os.clock() }
		end)
		prompt.Triggered:Connect(function(player: Player)
			-- кнопку нужно честно продержать: кто "нажал" быстрее, чем это возможно, ничего не получает
			local began = holding[player]
			holding[player] = nil
			if not began or began.prompt ~= prompt or os.clock() - began.at < hold * (1 - HOLD_SLACK) then
				ctx.sound(player, "deny") -- пусть игрок услышит, что нажатие не засчитано
				return
			end
			safely(name, function()
				action(player)
			end)
		end)
		return prompt
	end
	-- модель ящика из набора графики, если он есть; иначе ящик - простой куб
	local crateModel: Instance? = nil
	pcall(function()
		local assets = game:GetService("ServerStorage"):FindFirstChild("ZT_Assets")
		local found = if assets then assets:FindFirstChild("Crate") else nil
		if found and found:IsA("MeshPart") then
			crateModel = found
		end
	end)

	---------------------------------------------------------------------
	-- РЮКЗАКИ. У каждого участника ночи своя запись; она живёт только до утра.
	---------------------------------------------------------------------
	local packs: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
	local hits: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any   -- кто кого только что укусил
	local hinted: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local supped: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- кому про ужин уже сказано
	local nightId = 0     -- номер идущей ночи (раунда); 0 - сейчас день
	local nightStart = 0
	local cargoDone = false
	local shortNight = false -- короткая первая ночь новичков: груз в ней не падает (через 6 секунд прилетает вертолёт)
	local cargo: any = nil -- ящик с неба этой ночи
	local crateGoal = 0   -- сколько ящиков должно стоять в городе этой ночью

	local function room(pack: any): number
		return pack.size - pack.food - pack.mats
	end
	-- короткая пометка в строке рюкзака: что только что изменилось
	local function note(pack: any, text: string)
		pack.note = text
		pack.noteUntil = os.clock() + 2.5
	end
	local function newPack(player: Player, round: number): any
		local session = sessions[player]
		if not session then
			return nil
		end
		local pack = {
			round = round,
			human = not isZombie[player],
			food = 0, mats = 0,
			vac = 0, lent = 0, -- доз с собой; сколько из них взято из запасов (они остаются в запасах, пока не сработают)
			sat = SUPPER_NONE, hungry = false,
			slow = nil :: number?, normal = nil :: number?, -- скорость голодного и та, что была до неё
			at = nil :: Vector3?, -- где игрок был выжившим в последний раз
			bio = 0, caught = session.caught or 0,
			note = "", noteUntil = 0, nextOpen = 0,
			size = PACK_SIZE, -- дом добавляет места
		}
		if hooks.packBonus then
			local ok, bonus = pcall(hooks.packBonus, player)
			if ok then
				pack.size += count(bonus, 4)
			end
		end
		if pack.human then
			local ext = stock(session)
			if ext.food > 0 then
				ext.food -= 1
				pack.sat = SUPPER_FULL
				-- словами - только в первую ночь; дальше хватает пометки в строке рюкзака
				if not supped[player] then
					supped[player] = true
					ctx.toast(player, "sv_supper")
				end
				pack.note = "🍞 → 🍗"
				pack.noteUntil = os.clock() + 6
			else
				ctx.toast(player, "sv_nosupper")
			end
			if ext.vac > 0 then
				pack.vac, pack.lent = 1, 1
			end
		end
		packs[player] = pack
		return pack
	end

	---------------------------------------------------------------------
	-- ЯЩИКИ
	---------------------------------------------------------------------
	local crates: { any } = {}
	local returns: { number } = {} -- когда вместо открытых ящиков появятся новые

	local function rollTier(odds: { number }): number
		local roll = rng:NextNumber(0, 100)
		for tier, chance in ipairs(odds) do
			roll -= chance
			if roll < 0 then
				return tier
			end
		end
		return 1
	end
	local function freeSpot(avoid: Vector3?): any
		for _ = 1, 16 do
			local spot = spots[rng:NextInteger(1, #spots)]
			local fits = not spot.busy and not (avoid and (spot.at - avoid).Magnitude < 60)
			if fits then
				for _, crate in ipairs(crates) do
					if (crate.at - spot.at).Magnitude < CRATE_GAP then
						fits = false
						break
					end
				end
			end
			if fits then
				return spot
			end
		end
		for _, spot in ipairs(spots) do
			if not spot.busy then
				return spot
			end
		end
		return nil
	end
	local openCrate: (crate: any, player: Player) -> ()
	local function newCrate(spot: any, tier: number): any
		local info = TIERS[tier]
		local base: Vector3 = spot.at
		local box: BasePart
		local model = crateModel
		if model then
			local copy = model:Clone() :: MeshPart
			copy.Size = Vector3.new(3.3, 3, 3.3)
			copy.Position = base + Vector3.new(0, 1.5, 0)
			box = ghost(copy)
		else
			box = block("SV_Crate", Vector3.new(3, 3, 3), base + Vector3.new(0, 1.5, 0), Color3.fromRGB(165, 125, 75), Enum.Material.WoodPlanks, loot)
		end
		box.Name = "SV_Crate"
		-- редкость видна по цвету: светящаяся лента, подставка и звезда
		block("SV_Band", Vector3.new(3.5, 0.55, 3.5), base + Vector3.new(0, 1.5, 0), info.color, Enum.Material.Neon, box)
		local plate = block("SV_Plate", Vector3.new(4.6, 0.2, 4.6), base + Vector3.new(0, 0.12, 0), info.color, Enum.Material.Neon, box)
		plate.Transparency = 0.25
		glow(plate, info.color, 8 + tier * 1.5, 0.6 + tier * 0.15)
		sign(box, "★", info.color, 2 + tier * 0.5, 3.2 + tier * 0.25, info.far)
		if info.beam > 0 then
			ray(box, base + Vector3.new(0, 3.2, 0), info.beam, 0.3 + tier * 0.1, info.color)
		end
		local crate = { box = box, at = base, tier = tier, kind = spot.kind, spot = spot, gone = false }
		button(box, "SV_Open", info.hold, function(player: Player)
			openCrate(crate, player)
		end)
		box.Parent = loot
		spot.busy = true
		table.insert(crates, crate)
		return crate
	end
	local function removeCrate(crate: any)
		crate.gone = true
		crate.spot.busy = false
		crate.box:Destroy()
		local index = table.find(crates, crate)
		if index then
			table.remove(crates, index)
		end
	end
	local function spawnCrate(avoid: Vector3?): any
		local spot = freeSpot(avoid)
		if not spot then
			return nil
		end
		return newCrate(spot, rollTier(ODDS[spot.level]))
	end
	-- Игрок - выживший этой ночи, он жив, стоит рядом и на той же высоте, и его положению можно верить.
	-- base - точка, на которой стоит ящик или шкафчик.
	local function looter(player: Player, base: Vector3): any
		local pack = packs[player]
		if nightId == 0 or not pack or pack.round ~= nightId or not inRound[player] then
			return nil
		end
		if not pack.human or isZombie[player] then
			ctx.sound(player, "deny") -- зомби ящики и вакцина ни к чему
			return nil
		end
		local root = ctx.getAlive(player)
		if not root or (root.Position - base).Magnitude > REACH or math.abs(root.Position.Y - 3 - base.Y) > REACH_HIGH or not ctx.Guard.ok(player) then
			ctx.sound(player, "deny") -- например, игрок подпрыгнул в конце удержания
			return nil
		end
		return pack
	end
	openCrate = function(crate: any, player: Player)
		if crate.gone then
			return
		end
		local pack = looter(player, crate.at)
		local session = sessions[player]
		local now = os.clock()
		if not pack or not session or now < pack.nextOpen then
			return
		end
		local free = room(pack)
		if free <= 0 then
			ctx.toast(player, "sv_full")
			ctx.sound(player, "deny")
			return
		end
		local info = TIERS[crate.tier]
		local food, mats = 0, 0
		local foodChance = if crate.kind == "food" then 0.8 elseif crate.kind == "mats" then 0.2 else 0.5
		for _ = 1, info.units do
			if rng:NextNumber() < foodChance then
				food += 1
			else
				mats += 1
			end
		end
		local tookFood = math.min(food, free)
		local tookMats = math.min(mats, free - tookFood)
		pack.food += tookFood
		pack.mats += tookMats
		-- что не влезло в рюкзак, превращается в монеты
		local coins = info.coins + (info.units - tookFood - tookMats) * SPARE_COINS
		if coins > 0 then
			session.profile.coins += coins
			ctx.sync(player)
		end
		local found = {}
		if tookFood > 0 then
			table.insert(found, "+" .. tookFood .. " 🍞")
		end
		if tookMats > 0 then
			table.insert(found, "+" .. tookMats .. " 🔩")
		end
		if coins > 0 then
			table.insert(found, "+" .. coins .. " 💰")
		end
		note(pack, table.concat(found, "  "))
		ctx.sound(player, if crate.tier >= 3 then "boost" else "coin")
		local praise = FIND_TEXT[crate.tier]
		if praise then
			ctx.toast(player, praise)
		end
		hinted[player] = true
		pack.nextOpen = now + OPEN_PAUSE
		removeCrate(crate)
		table.insert(returns, now + CRATE_RETURN)
	end

	---------------------------------------------------------------------
	-- ШКАФЧИКИ С ВАКЦИНОЙ у больниц: у входа и на крыше
	---------------------------------------------------------------------
	local cabinets: { any } = {}
	local GREEN, GREY = Color3.fromRGB(70, 235, 120), Color3.fromRGB(110, 115, 120)
	local MEDIC = Color3.fromRGB(215, 245, 255) -- луч над больницей белый: зелёный луч в игре - это вертолёт
	local function setCabinet(cabinet: any, full: boolean)
		cabinet.full = full
		cabinet.backAt = if full then 0 else os.clock() + VACCINE_RETURN
		for _, bar in ipairs(cabinet.cross) do
			bar.Color = if full then GREEN else GREY
			bar.Material = if full then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		cabinet.light.Enabled = full
		cabinet.sign.Enabled = full
		cabinet.prompt.Enabled = full
		if cabinet.beam then
			cabinet.beam.Transparency = if full then 0.45 else 1
		end
	end
	local function newCabinet(at: Vector3, beam: number)
		local body = block("SV_Cabinet", Vector3.new(3, 4, 1.2), at, Color3.fromRGB(240, 242, 245), Enum.Material.SmoothPlastic, loot)
		local cabinet = {
			body = body,
			at = at,
			cross = {
				block("SV_Cross", Vector3.new(0.7, 2.4, 0.25), at + Vector3.new(0, 0.3, 0.62), GREEN, Enum.Material.Neon, body),
				block("SV_Cross", Vector3.new(2.4, 0.7, 0.25), at + Vector3.new(0, 0.3, 0.62), GREEN, Enum.Material.Neon, body),
			},
			light = glow(body, GREEN, 14, 1.4),
			sign = sign(body, "💉", Color3.fromRGB(255, 255, 255), 3, 4.2, 220),
			beam = if beam > 0 then ray(body, at + Vector3.new(0, 2.2, 0), beam, 0.6, MEDIC) else nil, -- луч над больницей: вакцина на месте
			prompt = nil :: any,
			full = false,
			backAt = 0,
		}
		cabinet.prompt = button(body, "SV_Vaccine", VACCINE_HOLD, function(player: Player)
			if not cabinet.full then
				return
			end
			local pack = looter(player, at - Vector3.new(0, 2, 0))
			if not pack then
				return
			end
			if pack.vac >= VACCINE_CARRY then
				ctx.toast(player, "sv_vac_have")
				ctx.sound(player, "deny")
				return
			end
			pack.vac += 1
			note(pack, "+1 💉")
			ctx.toast(player, "sv_vac_got")
			ctx.sound(player, "shield")
			setCabinet(cabinet, false)
		end)
		setCabinet(cabinet, false)
		cabinet.backAt = 0
		table.insert(cabinets, cabinet)
	end
	for _, hospital in ipairs(hospitals) do
		local size, at = hospital.Size, hospital.Position
		local ground = at.Y - size.Y / 2
		-- у входа, под красным крестом; и на крыше, в стороне от вертолётной площадки
		newCabinet(Vector3.new(at.X, ground + 2, at.Z + size.Z / 2 + 0.7), 0)
		newCabinet(Vector3.new(at.X - 9, at.Y + size.Y / 2 + 2, at.Z + 11), 45)
	end

	---------------------------------------------------------------------
	-- БРОШЕННЫЕ РЮКЗАКИ
	---------------------------------------------------------------------
	local bags: { any } = {}
	local function dropBag(at: Vector3, food: number, mats: number, vac: number, owner: Player?)
		if food + mats + vac <= 0 then
			return
		end
		local part = block("SV_Bag", Vector3.new(2.4, 2.4, 2.4), at, Color3.fromRGB(150, 105, 60), Enum.Material.Fabric, loot)
		part.Shape = Enum.PartType.Ball
		glow(part, Color3.fromRGB(255, 190, 110), 10, 1.5)
		sign(part, "🎒", Color3.fromRGB(255, 255, 255), 2.6, 2.6, 160)
		table.insert(bags, { part = part, at = at, food = food, mats = mats, vac = vac, owner = owner, lifeEnd = os.clock() + BAG_LIFE })
	end
	local function removeBag(index: number)
		bags[index].part:Destroy()
		table.remove(bags, index)
	end

	---------------------------------------------------------------------
	-- ГОЛОД: значок над головой и скорость
	---------------------------------------------------------------------
	local function hungryMark(player: Player, on: boolean)
		local character = player.Character
		local head = if character then character:FindFirstChild("Head") else nil
		local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
		for _, name in ipairs({ "SV_Hungry", "SV_HungryBeam" }) do
			local onHead = if head then head:FindFirstChild(name) else nil
			if onHead then
				onHead:Destroy()
			end
			local onBody = if body then body:FindFirstChild(name) else nil
			if onBody then
				onBody:Destroy()
			end
		end
		if not on then
			return
		end
		-- значок и столбик света над головой: голодного видно из-за машин, кустов и заборов
		if head then
			local board = sign(head, "🍗", Color3.fromRGB(255, 255, 255), 2.2, 4.6, 160)
			board.Name = "SV_Hungry"
		end
		if body and body:IsA("BasePart") then
			-- столбик держится за туловище: оно не качается при беге, как голова
			local beam = ray(body, body.Position + Vector3.new(0, 4, 0), HUNGRY_BEAM, 0.35, Color3.fromRGB(255, 150, 60))
			beam.Name = "SV_HungryBeam"
			beam.Anchored = false
			beam.Massless = true
			pcall(function()
				beam.CollisionGroup = "ZT_Players" -- как все части персонажа: игроки проходят друг сквозь друга
			end)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = beam
			weld.Parent = beam
		end
	end
	-- Скорость меняется только поверх той, что поставила игра, и возвращается, только если её никто не менял:
	-- ускорение, оглушение и превращение в зомби игра выставляет сама, и модуль с ними не спорит.
	local function pace(session: any, pack: any, humanoid: Humanoid?)
		if not humanoid then
			return
		end
		local speed = humanoid.WalkSpeed
		if pack.hungry then
			if session.boostUntil <= 0 and speed > 1 and not (pack.slow and math.abs(speed - pack.slow) < 0.01) then
				local _, _, _, event = ctx.state()
				pack.normal = speed
				pack.slow = speed * (if event == "rage" then HUNGRY_RAGE else HUNGRY_SPEED)
				humanoid.WalkSpeed = pack.slow
			end
		elseif pack.slow then
			if math.abs(speed - pack.slow) < 0.01 then
				humanoid.WalkSpeed = pack.normal
			end
			pack.slow, pack.normal = nil, nil
		end
	end
	local function fed(player: Player, pack: any)
		if pack.hungry then
			pack.hungry = false
			hungryMark(player, false)
		end
		local _, humanoid = ctx.getAlive(player)
		pace(sessions[player], pack, humanoid)
	end

	---------------------------------------------------------------------
	-- ВАКЦИНА. Главный скрипт спрашивает модуль в ту секунду, когда зомби дотянулся до выжившего:
	-- если у того есть доза, укус не действует, зомби на миг замирает, а выживший успевает убежать.
	---------------------------------------------------------------------
	ctx.Guard.hit = function(survivor: Player, catcher: Player?, catcherBot: any): boolean
		local saved = false
		safely("vaccine", function()
			local pack = packs[survivor]
			local session = sessions[survivor]
			if nightId == 0 or not pack or pack.round ~= nightId or not pack.human or not session then
				return
			end
			local now = os.clock()
			if pack.vac <= 0 then
				hits[survivor] = { by = catcher, at = now }
				return
			end
			pack.vac -= 1
			if pack.lent > 0 then
				pack.lent -= 1
				local ext = stock(session)
				ext.vac = math.max(0, ext.vac - 1)
			end
			saved = true
			session.immuneUntil = now + VACCINE_IMMUNE
			note(pack, "-1 💉")
			ctx.toast(survivor, "sv_vac_used")
			ctx.sound(survivor, "block")
			if catcherBot then
				catcherBot.stunUntil = now + VACCINE_STUN
				catcherBot.humanoid.WalkSpeed = 0
			elseif catcher then
				local theirs = sessions[catcher]
				local _, humanoid = ctx.getAlive(catcher)
				if theirs and humanoid then
					theirs.stunUntil = now + VACCINE_STUN
					humanoid.WalkSpeed = 0
				end
				ctx.toast(catcher, "sv_vac_bite")
				ctx.sound(catcher, "block")
			end
		end)
		return saved
	end

	---------------------------------------------------------------------
	-- ЗАРАЖЕНИЕ И ДОБЫЧА ЗОМБИ
	---------------------------------------------------------------------
	-- выжившего заразили: рюкзак остаётся там, где он был человеком
	local function turned(player: Player, session: any, pack: any, now: number)
		pack.human = false
		pack.caught = session.caught or 0
		pack.hungry = false
		pack.slow, pack.normal = nil, nil
		hungryMark(player, false)
		local spare = math.max(0, pack.vac - pack.lent)
		local food = pack.food
		local lost = food + pack.mats + spare > 0
		-- поймавший зомби-игрок получает больше мозгов, чем за горожанина, и сразу съедает еду из рюкзака
		local hit = hits[player]
		hits[player] = nil
		local catcher: Player? = if hit and now - hit.at < 2 then hit.by else nil
		local theirs = if catcher then packs[catcher] else nil
		if catcher and theirs and not theirs.human then
			theirs.bio += BRAINS_PLAYER - BRAINS_CATCH + food + (if hooks.catchBonus then count(hooks.catchBonus(catcher), 9) else 0)
			if food > 0 then
				ctx.toast(catcher, "sv_ate", food)
			end
			food = 0
		end
		-- остальное лежит на земле: детали и вакцину подберут выжившие
		if pack.at then
			dropBag(pack.at - Vector3.new(0, 1.8, 0), food, pack.mats, spare, player)
		end
		if lost then
			ctx.toast(player, "sv_lost")
		end
		pack.food, pack.mats, pack.vac, pack.lent = 0, 0, 0, 0
	end
	-- мозги за каждого, кого зомби поймал с прошлого шага
	local function tally(session: any, pack: any)
		local caught = session.caught or 0
		if caught > pack.caught then
			pack.bio += (caught - pack.caught) * BRAINS_CATCH
		end
		pack.caught = caught
	end

	---------------------------------------------------------------------
	-- УТРО: рюкзак выжившего уходит в запасы, мозги зомби - тоже
	---------------------------------------------------------------------
	local function bank(player: Player, session: any, pack: any)
		local ext = stock(session)
		if pack.human then
			ext.food = math.min(MAX_FOOD, ext.food + pack.food)
			ext.mats = math.min(MAX_MATS, ext.mats + pack.mats)
			ext.vac = math.min(VACCINE_STOCK, ext.vac + math.max(0, pack.vac - pack.lent))
			if pack.food + pack.mats > 0 then
				ctx.toast(player, "sv_saved", pack.food, pack.mats)
			end
			fed(player, pack)
		elseif pack.bio > 0 then
			ext.bio = math.min(MAX_BRAINS, ext.bio + pack.bio)
			ctx.toast(player, "sv_brains", pack.bio)
		end
		pack.food, pack.mats, pack.vac, pack.lent, pack.bio = 0, 0, 0, 0, 0
	end
	local function clearWorld()
		for index = #crates, 1, -1 do
			removeCrate(crates[index])
		end
		for index = #bags, 1, -1 do
			removeBag(index)
		end
		table.clear(returns)
	end
	local function endNight()
		nightId = 0
		local now = os.clock()
		-- Сначала досчитывается последняя четверть секунды ночи: главный скрипт заканчивает раунд сразу
		-- после последнего заражения, и этот шаг мог его ещё не увидеть. Укус, который прошёл,
		-- записан в hits - по нему заражение видно, даже если игра уже очистила свои списки.
		for player, pack in pairs(packs) do
			local session = sessions[player]
			local hit = hits[player]
			if session and pack.human and (isZombie[player] or (hit and now - hit.at < 1)) then
				turned(player, session, pack, now)
			end
		end
		for player, pack in pairs(packs) do
			local session = sessions[player]
			if session and not pack.human then
				tally(session, pack)
			end
		end
		-- выжил тот, кто к концу ночи не стал зомби; у заражённых рюкзак уже пуст
		for player, pack in pairs(packs) do
			local session = sessions[player]
			if session then
				bank(player, session, pack)
			end
		end
		table.clear(packs)
		table.clear(hits)
		clearWorld()
		for _, cabinet in ipairs(cabinets) do
			setCabinet(cabinet, false)
			cabinet.backAt = 0
		end
	end
	local function startNight(round: number)
		nightId = round
		nightStart = os.clock()
		cargoDone = false
		shortNight = ctx.Guard.eager(true) == true
		cargo = nil
		clearWorld()
		table.clear(packs)
		table.clear(hits)
		local humans = 0
		for player in pairs(inRound) do
			local pack = newPack(player, round)
			if pack and pack.human then
				humans += 1
			end
		end
		-- вакцина и ящики нужны только выжившим: в ночь без них шкафчики закрыты
		for _, cabinet in ipairs(cabinets) do
			setCabinet(cabinet, humans > 0)
			if humans == 0 then
				cabinet.backAt = 0
			end
		end
		crateGoal = if humans > 0 and #spots > 0 then math.min(CRATES_BASE + CRATES_PER_PLAYER * humans, CRATES_MAX, #spots) else 0
		for _ = 1, crateGoal do
			spawnCrate(nil)
		end
	end

	---------------------------------------------------------------------
	-- ЧТО ПРОИСХОДИТ С КАЖДЫМ ИГРОКОМ РАЗ В ЧЕТВЕРТЬ СЕКУНДЫ
	---------------------------------------------------------------------
	local function asHuman(player: Player, session: any, pack: any, now: number)
		if isZombie[player] then
			turned(player, session, pack, now)
			return
		end
		local root, humanoid = ctx.getAlive(player)
		if root then
			pack.at = root.Position
		end
		-- сытость
		pack.sat = math.max(0, pack.sat - DRAIN * STEP)
		if pack.sat < EAT_AT and pack.food > 0 then
			pack.food -= 1
			pack.sat = math.min(100, pack.sat + FOOD_VALUE)
			note(pack, "🍞 → 🍗")
		end
		local hungry = pack.sat <= 0
		if hungry ~= pack.hungry then
			pack.hungry = hungry
			hungryMark(player, hungry)
			if hungry then
				ctx.toast(player, "sv_hungry")
				ctx.sound(player, "deny")
			end
		end
		pace(session, pack, humanoid)
		if not root then
			return
		end
		local here = root.Position
		-- брошенные рюкзаки: выживший забирает то, что влезет
		if #bags > 0 and ctx.Guard.ok(player) then
			for index = #bags, 1, -1 do
				local bag = bags[index]
				if (bag.at - here).Magnitude <= BAG_REACH then
					local food = math.min(bag.food, room(pack))
					local mats = math.min(bag.mats, room(pack) - food)
					local vac = math.min(bag.vac, VACCINE_CARRY - pack.vac)
					if food + mats + vac > 0 then
						pack.food += food
						pack.mats += mats
						pack.vac += vac
						bag.food -= food
						bag.mats -= mats
						bag.vac -= vac
						note(pack, "+" .. (food + mats + vac) .. " 🎒")
						ctx.toast(player, "sv_bag")
						ctx.sound(player, "coin")
					end
					if bag.food + bag.mats + bag.vac <= 0 then
						removeBag(index)
					end
				end
			end
		end
		-- подсказка у первого ящика
		if not hinted[player] then
			for _, crate in ipairs(crates) do
				if (crate.at - here).Magnitude < 16 then
					hinted[player] = true
					ctx.toast(player, "sv_hint")
					break
				end
			end
		end
	end
	local function asZombie(player: Player, session: any, pack: any)
		tally(session, pack)
		local root = ctx.getAlive(player)
		if root and #bags > 0 and ctx.Guard.ok(player) then
			local here = root.Position
			for index = #bags, 1, -1 do
				local bag = bags[index]
				if bag.food > 0 and bag.owner ~= player and (bag.at - here).Magnitude <= BAG_REACH then
					-- зомби съедает еду из чужого брошенного рюкзака; детали и вакцина остаются выжившим
					pack.bio += bag.food
					ctx.toast(player, "sv_ate", bag.food)
					ctx.sound(player, "coin")
					bag.food = 0
					if bag.mats + bag.vac <= 0 then
						removeBag(index)
					end
				end
			end
		end
	end

	-- Сервер закрывается посреди ночи (обновление игры): рюкзаки уходят в запасы, как утром. Главный скрипт
	-- в это же время пишет последнее сохранение и берёт для него запасы уже после этого шага.
	game:BindToClose(function()
		safely("close", function()
			if nightId == 0 then
				return
			end
			for player, pack in pairs(packs) do
				local session = sessions[player]
				if session and pack.round == nightId then
					if not pack.human then
						tally(session, pack)
					end
					bank(player, session, pack)
				end
			end
		end)
	end)
	-- кто вышел из игры посреди ночи, оставляет рюкзак на земле: убежать с ним от укуса нельзя
	Players.PlayerRemoving:Connect(function(player: Player)
		safely("leave", function()
			local pack = packs[player]
			packs[player] = nil
			hits[player] = nil
			if nightId ~= 0 and pack and pack.round == nightId and pack.human and pack.at then
				dropBag(pack.at - Vector3.new(0, 1.8, 0), pack.food, pack.mats, math.max(0, pack.vac - pack.lent), nil)
			end
		end)
	end)

	---------------------------------------------------------------------
	-- СТРОКА РЮКЗАКА на экране: над строкой заданий. Ночью - рюкзак и сытость, днём - запасы.
	---------------------------------------------------------------------
	local function row(player: Player, session: any, hud: any, pack: any, now: number)
		local gui: Instance = hud.gui
		local found = gui:FindFirstChild("Pack")
		local label: TextLabel
		if found and found:IsA("TextLabel") then
			label = found
		else
			label = Instance.new("TextLabel")
			label.Name = "Pack"
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.fromScale(0.5, 0.912)
			label.Size = UDim2.fromScale(0.6, 0.058)
			label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			label.BackgroundTransparency = 0.4
			label.BorderSizePixel = 0
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0.2
			label.TextScaled = true
			label.RichText = true
			label.Font = Enum.Font.GothamBold
			label.Text = ""
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 24
			limit.MinTextSize = 13
			limit.Parent = label
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = label
			local box = Instance.new("UISizeConstraint")
			box.MaxSize = Vector2.new(560, 34)
			box.Parent = label
			label.Parent = gui
		end
		local text: string
		if pack and pack.human then
			local sat = math.ceil(pack.sat)
			local color = if sat <= 0 then "#FF5A5A" elseif sat < EAT_AT then "#FFD24A" else "#8CFF8C"
			local parts = {
				"🎒 " .. (pack.food + pack.mats) .. "/" .. pack.size,
				"🍞 " .. pack.food,
				"🔩 " .. pack.mats,
			}
			if pack.vac > 0 then
				table.insert(parts, "💉 " .. pack.vac)
			end
			table.insert(parts, '<font color="' .. color .. '">🍗 ' .. sat .. "%</font>")
			if now < pack.noteUntil then
				table.insert(parts, '<font color="#FFE08A">' .. pack.note .. "</font>")
			end
			text = table.concat(parts, "    ")
		elseif pack then
			text = "🧟    🧠 +" .. pack.bio .. "    🏠 " .. stock(session).bio
		else
			local ext = stock(session)
			local own: string? = if hooks.dayRow then hooks.dayRow(player, session, ext) else nil
			text = own or ("🏠    🍞 " .. ext.food .. "    🔩 " .. ext.mats .. "    💉 " .. ext.vac .. "    🧠 " .. ext.bio)
		end
		if label.Text ~= text then
			label.Text = text
		end
	end

	---------------------------------------------------------------------
	-- ОБЩИЙ ШАГ
	---------------------------------------------------------------------
	local function world(now: number)
		-- вместо открытых ящиков появляются новые, в других местах
		for index = #returns, 1, -1 do
			if now >= returns[index] then
				table.remove(returns, index)
				-- груз с неба в счёт обычных ящиков не идёт
				if #crates - (if cargo and not cargo.gone then 1 else 0) < crateGoal then
					spawnCrate(nil)
				end
			end
		end
		for _, cabinet in ipairs(cabinets) do
			if not cabinet.full and cabinet.backAt > 0 and now >= cabinet.backAt then
				setCabinet(cabinet, true)
			end
		end
		for index = #bags, 1, -1 do
			if now >= bags[index].lifeEnd then
				removeBag(index)
			end
		end
		-- ценный груз: один раз за ночь падает на перекрёсток, луч виден всему городу
		if not cargoDone and not shortNight and crateGoal > 0 and now - nightStart >= CARGO_AT then
			cargoDone = true
			local humans = false
			for _, pack in pairs(packs) do
				if pack.human then
					humans = true
					break
				end
			end
			if humans then
				local where: Vector3 = ctx.randomSpawn()
				for _ = 1, 8 do
					local clear = true
					for _, hole in ipairs(manholes) do
						if math.abs(hole.X - where.X) < CARGO_CLEAR and math.abs(hole.Z - where.Z) < CARGO_CLEAR then
							clear = false
							break
						end
					end
					if clear then
						break
					end
					where = ctx.randomSpawn()
				end
				local spot = { at = Vector3.new(where.X, where.Y - 3, where.Z), kind = "mix", level = 3, busy = false }
				cargo = newCrate(spot, rollTier(CARGO_ODDS))
				for player in pairs(inRound) do
					ctx.big(player, "sv_cargo")
					ctx.sound(player, "hunt")
				end
			end
		end
	end
	local function step()
		local active, _, round = ctx.state()
		local now = os.clock()
		if active and round ~= nightId then
			if nightId ~= 0 then
				endNight()
			end
			startNight(round)
		elseif not active and nightId ~= 0 then
			endNight()
		end
		if nightId ~= 0 then
			world(now)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessions[player]
			if session then
				safely("player", function()
					local pack = packs[player]
					if nightId ~= 0 then
						if inRound[player] then
							if not pack or pack.round ~= nightId then
								pack = newPack(player, nightId) -- вошёл в ночь позже остальных
							end
							if pack and pack.human then
								asHuman(player, session, pack, now)
							elseif pack then
								asZombie(player, session, pack)
							end
						elseif pack then
							-- улетел на вертолёте: рюкзак спасён
							if ctx.evac.saved[player] then
								bank(player, session, pack)
							else
								fed(player, pack)
							end
							packs[player] = nil
							pack = nil
						end
					end
					local hud = huds[player]
					if hud then
						row(player, session, hud, pack, now)
					end
				end)
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(STEP)
			safely("step", step)
		end
	end)

	-- то, что нужно проверкам и следующим этапам (участки, дома, логово)
	local api = {
		packs = packs, crates = crates, cabinets = cabinets, bags = bags, spots = spots,
		stock = stock, tiers = TIERS, step = step, dropBag = dropBag, newCrate = newCrate,
		night = function(): number
			return nightId
		end,
		-- для модуля Homes: общие заготовки и место для его функций
		hooks = hooks, safely = safely, count = count, block = block, ghost = ghost, glow = glow, sign = sign, ray = ray, button = button,
	}
	ctx.survival = api

	---------------------------------------------------------------------
	-- ТОЛЬКО В STUDIO: команды для проверок. В опубликованной игре этот блок не выполняется.
	-- game.ServerStorage.ZT_Debug:Invoke("info") и другие (смотри ниже).
	---------------------------------------------------------------------
	if game:GetService("RunService"):IsStudio() then
		safely("debug", function()
			local storage = game:GetService("ServerStorage")
			local old = storage:FindFirstChild("ZT_Debug")
			if old then
				old:Destroy()
			end
			local door = Instance.new("BindableFunction")
			door.Name = "ZT_Debug"
			local calm = false
			task.spawn(function()
				while true do
					task.wait(0.2)
					if calm then
						for _, bot in ipairs(ctx.bots) do
							if bot.zombie then
								bot.stunUntil = os.clock() + 1
								bot.humanoid.WalkSpeed = 0
							end
						end
					end
				end
			end)
			door.OnInvoke = function(command: string, a: any, b: any, c: any, d: any): string
				local player = Players:GetPlayers()[1]
				local session = if player then sessions[player] else nil
				if not player or not session then
					return "no player"
				end
				local pack = packs[player]
				local root = ctx.getAlive(player)
				if command == "calm" then -- зомби-боты стоят на месте
					calm = a == true
				elseif command == "go" and root and player.Character then -- перенести игрока
					local target = Vector3.new(a, b, c)
					ctx.Guard.allow(player, target)
					player.Character:PivotTo(CFrame.new(target))
				elseif command == "pack" and pack then -- еда, детали, вакцина, сытость
					pack.food, pack.mats, pack.vac, pack.sat = count(a, pack.size), count(b, pack.size - count(a, pack.size)), count(c, VACCINE_CARRY), count(d, 100)
					pack.lent = math.min(pack.lent, pack.vac)
				elseif command == "stock" then
					local ext = stock(session)
					ext.food, ext.mats, ext.vac, ext.bio = count(a, MAX_FOOD), count(b, MAX_MATS), count(c, VACCINE_STOCK), count(d, MAX_BRAINS)
				elseif command == "crate" and root then -- ящик нужной редкости рядом с игроком
					local at = root.Position + Vector3.new(6, -3, 0)
					newCrate({ at = at, kind = "mix", level = 1, busy = false }, a)
				elseif command == "bag" and root then
					dropBag(root.Position + Vector3.new(8, -1.8, 0), a, b, c, nil)
				elseif command == "human" then -- сделать игрока выжившим этой ночи
					isZombie[player] = nil
					ctx.refresh(player)
					packs[player] = nil
				elseif command == "bite" then -- укус бота
					return "bite " .. tostring(ctx.Guard.hit(player, nil, nil))
				elseif hooks.debug then -- команды модуля Homes
					local answer = hooks.debug(player, command, a, b, c, d)
					if answer then
						return answer
					end
				end
				local ext = stock(session)
				local lines = {
					"night " .. nightId .. " crates " .. #crates .. "/" .. crateGoal .. " bags " .. #bags .. " zombie " .. tostring(isZombie[player] == true) .. " inRound " .. tostring(inRound[player] == true),
					"stock food " .. ext.food .. " mats " .. ext.mats .. " vac " .. ext.vac .. " bio " .. ext.bio,
				}
				if pack then
					table.insert(lines, "pack human " .. tostring(pack.human) .. " food " .. pack.food .. " mats " .. pack.mats .. " vac " .. pack.vac .. " lent " .. pack.lent .. " sat " .. math.floor(pack.sat) .. " hungry " .. tostring(pack.hungry) .. " bio " .. pack.bio)
				end
				if root then
					table.insert(lines, string.format("at %.0f %.1f %.0f", root.Position.X, root.Position.Y, root.Position.Z))
				end
				return table.concat(lines, "\n")
			end
			door.Parent = storage
		end)
	end

	---------------------------------------------------------------------
	-- ДОМА И ЛОГОВО - отдельный модуль Homes, он лежит рядом. Запускается последним.
	---------------------------------------------------------------------
	local home = script.Parent
	local more = if home then home:FindFirstChild("Homes") else nil
	if more then
		safely("homes_start", function()
			(require :: any)(more)(ctx, api)
		end)
	end
	return api
end
