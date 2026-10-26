--!strict
--[[
	ДОМА И ЛОГОВО (версия 8, этап 2)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Homes. Он лежит ВНУТРИ главного скрипта, рядом с Survival:
	ServerScriptService -> Script -> Homes. Его запускает модуль Survival; без него игра работает по-старому.

	ЧТО ОН ДЕЛАЕТ
	- За стеной города стоит посёлок выживших: 20 участков вдоль улицы. У каждого игрока свой участок.
	  Дом растёт по ступеням за детали из городских ящиков: палатка -> сарай -> дом -> крепость.
	- С другой стороны города - логово зомби: у каждого игрока своя ниша.
	  Логово растёт за мозги: лежанка -> нора -> улей -> трон.
	- На свободных участках стоят дома соседей-ботов: по ним видно, к чему стремиться.
	- В лобби, посёлке и логове есть значки-переходы: дом, логово, магазин (лобби).
	- Игрок живёт там, куда ушёл по значку в последний раз: дом, логово или лобби. Кто живёт в доме или логове,
	  после ночи возвращается туда.
	- Игрок сам решает, идти ли в город: из дома и из логова ночь никого не забирает. Значок 🌙 у входа
	  на участок - "иду в город": ближайшая ночь возьмёт игрока. Тот же значок ещё раз - "остаюсь".
	- Дом добавляет места в рюкзаке, логово - мозги за каждого пойманного игрока.
]]

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
local DAY_EXTRA = 0                  -- на сколько секунд длиннее день для всех, если кто-то живёт в доме (0: у того, кто дома, свой счёт)
local STAY = true                    -- из дома и из логова ночь не забирает игрока, пока он сам не попросится в город (значок 🌙)
local HOUSE_COST = { 12, 36, 90 }    -- деталей за сарай, дом и крепость
local NEST_COST = { 10, 30, 80 }     -- мозгов за нору, улей и трон
local HOUSE_PACK = { 0, 0, 1, 2 }    -- лишние места в рюкзаке: палатка, сарай, дом, крепость
local NEST_BRAINS = { 0, 1, 2, 3 }   -- лишние мозги за пойманного игрока: лежанка, нора, улей, трон
local BUILD_HOLD = 1.5               -- сколько секунд держать кнопку у доски
local PAD_HOLD = 0.5                 -- и на значке-переходе
local REACH = 14                     -- с какого расстояния сервер верит нажатию
local STREET = 50                    -- на сколько шагов улица посёлка (и тропа логова) отстоит от стены города
local ROW = 24                       -- на сколько шагов участки отстоят от улицы
local ARRIVE = 18                    -- где игрок появляется у своего участка: на краю улицы, перед табличкой и доской стройки
local PLOT_X = { -180, -144, -108, -72, -36, 36, 72, 108, 144, 180 } -- участки вдоль улицы; посередине площадь
-- какие дома стоят на свободных участках (ступени соседей-ботов) и в каком порядке участки раздаются игрокам
local NEIGHBOURS = { 1, 0, 3, 1, 2, 2, 0, 1, 2, 0, 0, 2, 1, 0, 2, 0, 1, 3, 1, 2 }
local ORDER = { 5, 6, 15, 16, 4, 7, 14, 17, 3, 8, 13, 18, 2, 9, 12, 19, 1, 10, 11, 20 }
local WALLS = { -- цвета стен домов: у соседних участков разные
	Color3.fromRGB(176, 104, 84), Color3.fromRGB(214, 196, 160), Color3.fromRGB(124, 146, 170),
	Color3.fromRGB(150, 164, 120), Color3.fromRGB(196, 150, 96),
}
local CANVAS = { Color3.fromRGB(196, 170, 120), Color3.fromRGB(110, 138, 104), Color3.fromRGB(170, 112, 84), Color3.fromRGB(120, 140, 168) }

local HOUSE_TEXT = { "hm_house1", "hm_house2", "hm_house3" }
local NEST_TEXT = { "hm_nest1", "hm_nest2", "hm_nest3" }

---------------------------------------------------------------------
-- ТЕКСТЫ. Добавляются к общим текстам игры (модуль Texts) при запуске.
---------------------------------------------------------------------
local TEXT: { [string]: { [string]: string } } = {
	en = {
		hm_house1 = "🏠 The shed is built! Next: a real house",
		hm_house2 = "🏠 The house is built! Your backpack holds 1 more",
		hm_house3 = "🏠 THE FORTRESS IS BUILT! Your backpack holds 2 more",
		hm_nest1 = "🧟 The burrow is dug! +1 brain for every player you catch",
		hm_nest2 = "🧟 The hive has grown! +2 brains for every player you catch",
		hm_nest3 = "🧟 THE THRONE OF THE HORDE! +3 brains for every player you catch",
		hm_need_parts = "🔩 Not enough parts: %d more needed. Open crates in the city at night!",
		hm_need_brains = "🧠 Not enough brains: %d more needed. Catch people at night!",
		hm_max = "⭐ This is the top level for now",
		bd_title = "BUILD",
		bd_next = "Next level",
		bd_decor = "Yard",
		bd_build = "Build",
		bd_have = "Built ✔",
		bd_need = "%d more",
		bd_close = "Close",
		bd_start = "🔩 Starter kit: %d parts! Build a shed or decorate the yard at the board ⬆",
		bd_t1 = "Shed",
		bd_t1b = "Walls instead of a tent",
		bd_t2 = "House",
		bd_t2b = "+1 backpack slot",
		bd_t3 = "Fortress",
		bd_t3b = "+2 slots, a tower and a wall",
		bd_n1 = "Burrow",
		bd_n1b = "+1 🧠 per caught player",
		bd_n2 = "Hive",
		bd_n2b = "+2 🧠 per caught player",
		bd_n3 = "Throne",
		bd_n3b = "+3 🧠 per caught player",
		bd_fence = "Fence",
		bd_fenceb = "A proper yard",
		bd_lamp = "Lamp post",
		bd_lampb = "Light at night",
		bd_garden = "Garden",
		bd_gardenb = "+1 🍞 every morning",
		bd_flag = "Flag",
		bd_flagb = "Your colour over the yard",
		bd_bench = "Bench",
		bd_benchb = "A place to sit",
		bd_well = "Well",
		bd_wellb = "Water for the garden: +1 🍞 more",
		bd_bones = "Bone pile",
		bd_bonesb = "Scares the neighbours",
		bd_mush = "Glowing mushrooms",
		bd_mushb = "Light in the lair",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 every morning",
		bd_garden_bonus = "🌱 Your garden: +%d 🍞",
		bd_totem_bonus = "🗿 Your totem: +1 🧠",
		bd_built = "🔨 Built: %s",
		hm_not_yours = "This place belongs to someone else",
		hm_no_plot = "All plots on this server are taken",
		hm_hint = "🏠 You have a plot outside the city wall! Use the house sign here in the lobby",
		hm_home = "🏠 This is your plot. Hold the button at the board to build: %d parts",
		hm_lair = "🧟 This is your nest. Hold the button at the board to grow it: %d brains",
		hm_pad1 = "🏠 Hold the button on this sign to go to your plot outside the city wall",
		hm_pad2 = "🧟 Hold the button on this sign to go to your zombie nest",
		hm_moon = "🌙 At home the night does not take you. Want to go to the city? Hold the 🌙 sign",
		hm_go = "🌙 Ready! The next night takes you to the city",
		hm_wait = "🌙 You stay at home. The night will not take you",
		hm_status = "🏠 At home. To go to the city, hold the 🌙 sign",
		hm_go2 = "🌙 A night is on right now. The next one takes you to the city",
		hm_l1 = "MY HOUSE",
		hm_l2 = "ZOMBIE NEST",
		hm_l0 = "SHOP / LOBBY",
		hm_l3 = "TO THE CITY",
	},
	ru = {
		hm_house1 = "🏠 Сарай построен! Дальше - настоящий дом",
		hm_house2 = "🏠 Дом построен! В рюкзаке на 1 место больше",
		hm_house3 = "🏠 КРЕПОСТЬ ПОСТРОЕНА! В рюкзаке на 2 места больше",
		hm_nest1 = "🧟 Нора вырыта! +1 мозг за каждого пойманного игрока",
		hm_nest2 = "🧟 Улей вырос! +2 мозга за каждого пойманного игрока",
		hm_nest3 = "🧟 ТРОН ОРДЫ! +3 мозга за каждого пойманного игрока",
		hm_need_parts = "🔩 Не хватает деталей: ещё %d. Открывай ящики в городе ночью!",
		hm_need_brains = "🧠 Не хватает мозгов: ещё %d. Лови людей ночью!",
		hm_max = "⭐ Пока это высшая ступень",
		bd_title = "СТРОЙКА",
		bd_next = "Следующая ступень",
		bd_decor = "Двор",
		bd_build = "Построить",
		bd_have = "Есть ✔",
		bd_need = "Ещё %d",
		bd_close = "Закрыть",
		bd_start = "🔩 Стартовый набор: %d деталей! Построй сарай или укрась двор у доски ⬆",
		bd_t1 = "Сарай",
		bd_t1b = "Стены вместо палатки",
		bd_t2 = "Дом",
		bd_t2b = "+1 место в рюкзаке",
		bd_t3 = "Крепость",
		bd_t3b = "+2 места, башня и стена",
		bd_n1 = "Нора",
		bd_n1b = "+1 🧠 за пойманного игрока",
		bd_n2 = "Улей",
		bd_n2b = "+2 🧠 за пойманного игрока",
		bd_n3 = "Трон",
		bd_n3b = "+3 🧠 за пойманного игрока",
		bd_fence = "Забор",
		bd_fenceb = "Двор как у людей",
		bd_lamp = "Фонарь",
		bd_lampb = "Светло ночью",
		bd_garden = "Грядки",
		bd_gardenb = "+1 🍞 каждое утро",
		bd_flag = "Флаг",
		bd_flagb = "Твой цвет над двором",
		bd_bench = "Скамейка",
		bd_benchb = "Есть где посидеть",
		bd_well = "Колодец",
		bd_wellb = "Вода для грядок: ещё +1 🍞",
		bd_bones = "Куча костей",
		bd_bonesb = "Пугает соседей",
		bd_mush = "Светящиеся грибы",
		bd_mushb = "Свет в логове",
		bd_totem = "Тотем",
		bd_totemb = "+1 🧠 каждое утро",
		bd_garden_bonus = "🌱 Твои грядки: +%d 🍞",
		bd_totem_bonus = "🗿 Твой тотем: +1 🧠",
		bd_built = "🔨 Построено: %s",
		hm_not_yours = "Это чужой участок",
		hm_no_plot = "Все участки на этом сервере заняты",
		hm_hint = "🏠 У тебя есть участок за стеной города! Значок дома здесь, в лобби",
		hm_home = "🏠 Это твой участок. Подержи кнопку у доски, чтобы строить: %d деталей",
		hm_lair = "🧟 Это твоё логово. Подержи кнопку у доски, чтобы растить: %d мозгов",
		hm_pad1 = "🏠 Подержи кнопку на этом значке: он переносит на твой участок за стеной города",
		hm_pad2 = "🧟 Подержи кнопку на этом значке: он переносит в твоё логово зомби",
		hm_moon = "🌙 Дома ночь тебя не заберёт. Хочешь в город? Подержи кнопку на значке 🌙",
		hm_go = "🌙 Готово! Следующая ночь заберёт тебя в город",
		hm_wait = "🌙 Остаёшься дома. Ночь тебя не заберёт",
		hm_status = "🏠 Ты дома. В город: подержи значок 🌙",
		hm_go2 = "🌙 Сейчас идёт ночь. Следующая заберёт тебя в город",
		hm_l1 = "МОЙ ДОМ",
		hm_l2 = "ЛОГОВО ЗОМБИ",
		hm_l0 = "МАГАЗИН / ЛОББИ",
		hm_l3 = "В ГОРОД",
	},
	es = {
		hm_house1 = "🏠 ¡El cobertizo está listo! Lo siguiente: una casa de verdad",
		hm_house2 = "🏠 ¡La casa está lista! En tu mochila cabe 1 cosa más",
		hm_house3 = "🏠 ¡LA FORTALEZA ESTÁ LISTA! En tu mochila caben 2 cosas más",
		hm_nest1 = "🧟 ¡Madriguera lista! +1 cerebro por cada jugador que atrapes",
		hm_nest2 = "🧟 ¡La colmena ha crecido! +2 cerebros por cada jugador que atrapes",
		hm_nest3 = "🧟 ¡EL TRONO DE LA HORDA! +3 cerebros por cada jugador que atrapes",
		hm_need_parts = "🔩 Faltan piezas: %d más. ¡Abre cajas en la ciudad por la noche!",
		hm_need_brains = "🧠 Faltan cerebros: %d más. ¡Atrapa gente por la noche!",
		hm_max = "⭐ Por ahora este es el nivel más alto",
		bd_title = "CONSTRUIR",
		bd_next = "Siguiente nivel",
		bd_decor = "Patio",
		bd_build = "Construir",
		bd_have = "Hecho ✔",
		bd_need = "Faltan %d",
		bd_close = "Cerrar",
		bd_start = "🔩 ¡Kit inicial: %d piezas! Construye un cobertizo o decora el patio en el tablero ⬆",
		bd_t1 = "Cobertizo",
		bd_t1b = "Paredes en vez de tienda",
		bd_t2 = "Casa",
		bd_t2b = "+1 hueco en la mochila",
		bd_t3 = "Fortaleza",
		bd_t3b = "+2 huecos, torre y muro",
		bd_n1 = "Madriguera",
		bd_n1b = "+1 🧠 por jugador atrapado",
		bd_n2 = "Colmena",
		bd_n2b = "+2 🧠 por jugador atrapado",
		bd_n3 = "Trono",
		bd_n3b = "+3 🧠 por jugador atrapado",
		bd_fence = "Valla",
		bd_fenceb = "Un patio de verdad",
		bd_lamp = "Farola",
		bd_lampb = "Luz de noche",
		bd_garden = "Huerto",
		bd_gardenb = "+1 🍞 cada mañana",
		bd_flag = "Bandera",
		bd_flagb = "Tu color sobre el patio",
		bd_bench = "Banco",
		bd_benchb = "Un sitio para sentarse",
		bd_well = "Pozo",
		bd_wellb = "Agua para el huerto: +1 🍞 más",
		bd_bones = "Pila de huesos",
		bd_bonesb = "Asusta a los vecinos",
		bd_mush = "Setas luminosas",
		bd_mushb = "Luz en la guarida",
		bd_totem = "Tótem",
		bd_totemb = "+1 🧠 cada mañana",
		bd_garden_bonus = "🌱 Tu huerto: +%d 🍞",
		bd_totem_bonus = "🗿 Tu tótem: +1 🧠",
		bd_built = "🔨 Construido: %s",
		hm_not_yours = "Este lugar es de otro jugador",
		hm_no_plot = "Todas las parcelas de este servidor están ocupadas",
		hm_hint = "🏠 ¡Tienes una parcela fuera del muro de la ciudad! Usa la señal de la casa aquí en el lobby",
		hm_home = "🏠 Esta es tu parcela. Mantén el botón junto al tablero para construir: %d piezas",
		hm_lair = "🧟 Este es tu nido. Mantén el botón junto al tablero para hacerlo crecer: %d cerebros",
		hm_pad1 = "🏠 Mantén el botón de esta señal para ir a tu parcela fuera del muro de la ciudad",
		hm_pad2 = "🧟 Mantén el botón de esta señal para ir a tu nido de zombis",
		hm_moon = "🌙 En casa la noche no te lleva. ¿Quieres ir a la ciudad? Mantén la señal 🌙",
		hm_go = "🌙 ¡Listo! La próxima noche te lleva a la ciudad",
		hm_wait = "🌙 Te quedas en casa. La noche no te llevará",
		hm_status = "🏠 En casa. Para ir a la ciudad, mantén la señal 🌙",
		hm_go2 = "🌙 Ahora mismo es de noche. La próxima te lleva a la ciudad",
		hm_l1 = "MI CASA",
		hm_l2 = "NIDO ZOMBI",
		hm_l0 = "TIENDA / LOBBY",
		hm_l3 = "A LA CIUDAD",
	},
	pt = {
		hm_house1 = "🏠 O galpão está pronto! Depois: uma casa de verdade",
		hm_house2 = "🏠 A casa está pronta! Cabe mais 1 coisa na mochila",
		hm_house3 = "🏠 A FORTALEZA ESTÁ PRONTA! Cabem mais 2 coisas na mochila",
		hm_nest1 = "🧟 A toca está pronta! +1 cérebro por cada jogador que você pegar",
		hm_nest2 = "🧟 A colmeia cresceu! +2 cérebros por cada jogador que você pegar",
		hm_nest3 = "🧟 O TRONO DA HORDA! +3 cérebros por cada jogador que você pegar",
		hm_need_parts = "🔩 Faltam peças: mais %d. Abra caixas na cidade à noite!",
		hm_need_brains = "🧠 Faltam cérebros: mais %d. Pegue pessoas à noite!",
		hm_max = "⭐ Por enquanto este é o nível máximo",
		bd_title = "CONSTRUIR",
		bd_next = "Próximo nível",
		bd_decor = "Quintal",
		bd_build = "Construir",
		bd_have = "Pronto ✔",
		bd_need = "Faltam %d",
		bd_close = "Fechar",
		bd_start = "🔩 Kit inicial: %d peças! Construa um galpão ou decore o quintal no quadro ⬆",
		bd_t1 = "Galpão",
		bd_t1b = "Paredes em vez de barraca",
		bd_t2 = "Casa",
		bd_t2b = "+1 vaga na mochila",
		bd_t3 = "Fortaleza",
		bd_t3b = "+2 vagas, torre e muro",
		bd_n1 = "Toca",
		bd_n1b = "+1 🧠 por jogador pego",
		bd_n2 = "Colmeia",
		bd_n2b = "+2 🧠 por jogador pego",
		bd_n3 = "Trono",
		bd_n3b = "+3 🧠 por jogador pego",
		bd_fence = "Cerca",
		bd_fenceb = "Um quintal de verdade",
		bd_lamp = "Poste de luz",
		bd_lampb = "Luz à noite",
		bd_garden = "Horta",
		bd_gardenb = "+1 🍞 toda manhã",
		bd_flag = "Bandeira",
		bd_flagb = "Sua cor sobre o quintal",
		bd_bench = "Banco",
		bd_benchb = "Um lugar para sentar",
		bd_well = "Poço",
		bd_wellb = "Água para a horta: mais +1 🍞",
		bd_bones = "Pilha de ossos",
		bd_bonesb = "Assusta os vizinhos",
		bd_mush = "Cogumelos brilhantes",
		bd_mushb = "Luz no covil",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 toda manhã",
		bd_garden_bonus = "🌱 Sua horta: +%d 🍞",
		bd_totem_bonus = "🗿 Seu totem: +1 🧠",
		bd_built = "🔨 Construído: %s",
		hm_not_yours = "Este lugar é de outro jogador",
		hm_no_plot = "Todos os terrenos deste servidor estão ocupados",
		hm_hint = "🏠 Você tem um terreno fora do muro da cidade! Use a placa da casa aqui no lobby",
		hm_home = "🏠 Este é o seu terreno. Segure o botão na placa para construir: %d peças",
		hm_lair = "🧟 Este é o seu ninho. Segure o botão na placa para fazê-lo crescer: %d cérebros",
		hm_pad1 = "🏠 Segure o botão desta placa para ir ao seu terreno fora do muro da cidade",
		hm_pad2 = "🧟 Segure o botão desta placa para ir ao seu ninho de zumbis",
		hm_moon = "🌙 Em casa a noite não leva você. Quer ir para a cidade? Segure a placa 🌙",
		hm_go = "🌙 Pronto! A próxima noite leva você para a cidade",
		hm_wait = "🌙 Você fica em casa. A noite não vai levar você",
		hm_status = "🏠 Em casa. Para ir à cidade, segure a placa 🌙",
		hm_go2 = "🌙 Agora é noite. A próxima leva você para a cidade",
		hm_l1 = "MINHA CASA",
		hm_l2 = "NINHO ZUMBI",
		hm_l0 = "LOJA / LOBBY",
		hm_l3 = "PARA A CIDADE",
	},
	fr = {
		hm_house1 = "🏠 La cabane est construite ! Ensuite : une vraie maison",
		hm_house2 = "🏠 La maison est construite ! Ton sac contient 1 objet de plus",
		hm_house3 = "🏠 LA FORTERESSE EST CONSTRUITE ! Ton sac contient 2 objets de plus",
		hm_nest1 = "🧟 Le terrier est creusé ! +1 cerveau pour chaque joueur attrapé",
		hm_nest2 = "🧟 La ruche a grandi ! +2 cerveaux pour chaque joueur attrapé",
		hm_nest3 = "🧟 LE TRÔNE DE LA HORDE ! +3 cerveaux pour chaque joueur attrapé",
		hm_need_parts = "🔩 Il manque des pièces : encore %d. Ouvre des caisses en ville la nuit !",
		hm_need_brains = "🧠 Il manque des cerveaux : encore %d. Attrape des gens la nuit !",
		hm_max = "⭐ C'est le niveau maximum pour l'instant",
		bd_title = "CONSTRUIRE",
		bd_next = "Niveau suivant",
		bd_decor = "Cour",
		bd_build = "Construire",
		bd_have = "Fait ✔",
		bd_need = "Encore %d",
		bd_close = "Fermer",
		bd_start = "🔩 Kit de départ : %d pièces ! Construis une cabane ou décore la cour au panneau ⬆",
		bd_t1 = "Cabane",
		bd_t1b = "Des murs au lieu d'une tente",
		bd_t2 = "Maison",
		bd_t2b = "+1 place dans le sac",
		bd_t3 = "Forteresse",
		bd_t3b = "+2 places, une tour et un mur",
		bd_n1 = "Terrier",
		bd_n1b = "+1 🧠 par joueur attrapé",
		bd_n2 = "Ruche",
		bd_n2b = "+2 🧠 par joueur attrapé",
		bd_n3 = "Trône",
		bd_n3b = "+3 🧠 par joueur attrapé",
		bd_fence = "Clôture",
		bd_fenceb = "Une vraie cour",
		bd_lamp = "Lampadaire",
		bd_lampb = "De la lumière la nuit",
		bd_garden = "Potager",
		bd_gardenb = "+1 🍞 chaque matin",
		bd_flag = "Drapeau",
		bd_flagb = "Ta couleur sur la cour",
		bd_bench = "Banc",
		bd_benchb = "Un endroit où s'asseoir",
		bd_well = "Puits",
		bd_wellb = "De l'eau pour le potager : +1 🍞 de plus",
		bd_bones = "Tas d'os",
		bd_bonesb = "Effraie les voisins",
		bd_mush = "Champignons lumineux",
		bd_mushb = "De la lumière dans le repaire",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 chaque matin",
		bd_garden_bonus = "🌱 Ton potager : +%d 🍞",
		bd_totem_bonus = "🗿 Ton totem : +1 🧠",
		bd_built = "🔨 Construit : %s",
		hm_not_yours = "Cet endroit appartient à quelqu'un d'autre",
		hm_no_plot = "Tous les terrains de ce serveur sont pris",
		hm_hint = "🏠 Tu as un terrain derrière le mur de la ville ! Utilise le panneau maison ici dans le lobby",
		hm_home = "🏠 Voici ton terrain. Maintiens le bouton près du panneau pour construire : %d pièces",
		hm_lair = "🧟 Voici ton nid. Maintiens le bouton près du panneau pour le faire grandir : %d cerveaux",
		hm_pad1 = "🏠 Maintiens le bouton de ce panneau pour aller sur ton terrain derrière le mur de la ville",
		hm_pad2 = "🧟 Maintiens le bouton de ce panneau pour aller dans ton nid de zombies",
		hm_moon = "🌙 À la maison, la nuit ne t'emmène pas. Tu veux aller en ville ? Maintiens le panneau 🌙",
		hm_go = "🌙 Prêt ! La prochaine nuit t'emmène en ville",
		hm_wait = "🌙 Tu restes à la maison. La nuit ne t'emmènera pas",
		hm_status = "🏠 À la maison. Pour aller en ville, maintiens le panneau 🌙",
		hm_go2 = "🌙 C'est la nuit en ce moment. La prochaine t'emmène en ville",
		hm_l1 = "MA MAISON",
		hm_l2 = "NID DE ZOMBIES",
		hm_l0 = "BOUTIQUE / LOBBY",
		hm_l3 = "EN VILLE",
	},
	de = {
		hm_house1 = "🏠 Der Schuppen steht! Als Nächstes: ein richtiges Haus",
		hm_house2 = "🏠 Das Haus steht! In deinen Rucksack passt 1 Sache mehr",
		hm_house3 = "🏠 FESTUNG FERTIG! In deinen Rucksack passen 2 Sachen mehr",
		hm_nest1 = "🧟 Der Bau ist gegraben! +1 Gehirn für jeden gefangenen Spieler",
		hm_nest2 = "🧟 Der Stock ist gewachsen! +2 Gehirne für jeden gefangenen Spieler",
		hm_nest3 = "🧟 DER THRON DER HORDE! +3 Gehirne für jeden gefangenen Spieler",
		hm_need_parts = "🔩 Es fehlen Teile: noch %d. Öffne nachts Kisten in der Stadt!",
		hm_need_brains = "🧠 Es fehlen Gehirne: noch %d. Fang nachts Leute!",
		hm_max = "⭐ Das ist vorerst die höchste Stufe",
		bd_title = "BAUEN",
		bd_next = "Nächste Stufe",
		bd_decor = "Hof",
		bd_build = "Bauen",
		bd_have = "Gebaut ✔",
		bd_need = "Noch %d",
		bd_close = "Schließen",
		bd_start = "🔩 Starterpaket: %d Teile! Bau am Brett einen Schuppen oder schmücke den Hof ⬆",
		bd_t1 = "Schuppen",
		bd_t1b = "Wände statt Zelt",
		bd_t2 = "Haus",
		bd_t2b = "+1 Platz im Rucksack",
		bd_t3 = "Festung",
		bd_t3b = "+2 Plätze, Turm und Mauer",
		bd_n1 = "Bau",
		bd_n1b = "+1 🧠 pro gefangenem Spieler",
		bd_n2 = "Nest",
		bd_n2b = "+2 🧠 pro gefangenem Spieler",
		bd_n3 = "Thron",
		bd_n3b = "+3 🧠 pro gefangenem Spieler",
		bd_fence = "Zaun",
		bd_fenceb = "Ein richtiger Hof",
		bd_lamp = "Laterne",
		bd_lampb = "Licht in der Nacht",
		bd_garden = "Beete",
		bd_gardenb = "+1 🍞 jeden Morgen",
		bd_flag = "Fahne",
		bd_flagb = "Deine Farbe über dem Hof",
		bd_bench = "Bank",
		bd_benchb = "Ein Platz zum Sitzen",
		bd_well = "Brunnen",
		bd_wellb = "Wasser für die Beete: noch +1 🍞",
		bd_bones = "Knochenhaufen",
		bd_bonesb = "Erschreckt die Nachbarn",
		bd_mush = "Leuchtpilze",
		bd_mushb = "Licht im Versteck",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 jeden Morgen",
		bd_garden_bonus = "🌱 Deine Beete: +%d 🍞",
		bd_totem_bonus = "🗿 Dein Totem: +1 🧠",
		bd_built = "🔨 Gebaut: %s",
		hm_not_yours = "Dieser Platz gehört jemand anderem",
		hm_no_plot = "Alle Grundstücke auf diesem Server sind vergeben",
		hm_hint = "🏠 Du hast ein Grundstück hinter der Stadtmauer! Nutze das Haus-Zeichen hier in der Lobby",
		hm_home = "🏠 Das ist dein Grundstück. Halte die Taste an der Tafel, um zu bauen: %d Teile",
		hm_lair = "🧟 Das ist dein Nest. Halte die Taste an der Tafel, um es wachsen zu lassen: %d Gehirne",
		hm_pad1 = "🏠 Halte den Knopf an diesem Zeichen: Es bringt dich zu deinem Grundstück hinter der Stadtmauer",
		hm_pad2 = "🧟 Halte den Knopf an diesem Zeichen: Es bringt dich in dein Zombie-Nest",
		hm_moon = "🌙 Zu Hause holt dich die Nacht nicht. Willst du in die Stadt? Halte das Zeichen 🌙",
		hm_go = "🌙 Bereit! Die nächste Nacht bringt dich in die Stadt",
		hm_wait = "🌙 Du bleibst zu Hause. Die Nacht holt dich nicht",
		hm_status = "🏠 Zu Hause. In die Stadt: Zeichen 🌙 halten",
		hm_go2 = "🌙 Gerade ist Nacht. Die nächste bringt dich in die Stadt",
		hm_l1 = "MEIN HAUS",
		hm_l2 = "ZOMBIE-NEST",
		hm_l0 = "SHOP / LOBBY",
		hm_l3 = "IN DIE STADT",
	},
	it = {
		hm_house1 = "🏠 Il capanno è pronto! Poi: una vera casa",
		hm_house2 = "🏠 La casa è pronta! Nello zaino entra 1 cosa in più",
		hm_house3 = "🏠 LA FORTEZZA È PRONTA! Nello zaino entrano 2 cose in più",
		hm_nest1 = "🧟 La tana è scavata! +1 cervello per ogni giocatore che prendi",
		hm_nest2 = "🧟 L'alveare è cresciuto! +2 cervelli per ogni giocatore che prendi",
		hm_nest3 = "🧟 IL TRONO DELL'ORDA! +3 cervelli per ogni giocatore che prendi",
		hm_need_parts = "🔩 Mancano pezzi: ancora %d. Apri le casse in città di notte!",
		hm_need_brains = "🧠 Mancano cervelli: ancora %d. Prendi le persone di notte!",
		hm_max = "⭐ Per ora questo è il livello più alto",
		bd_title = "COSTRUISCI",
		bd_next = "Livello successivo",
		bd_decor = "Cortile",
		bd_build = "Costruisci",
		bd_have = "Fatto ✔",
		bd_need = "Ancora %d",
		bd_close = "Chiudi",
		bd_start = "🔩 Kit iniziale: %d pezzi! Costruisci un capanno o decora il cortile alla bacheca ⬆",
		bd_t1 = "Capanno",
		bd_t1b = "Pareti al posto della tenda",
		bd_t2 = "Casa",
		bd_t2b = "+1 posto nello zaino",
		bd_t3 = "Fortezza",
		bd_t3b = "+2 posti, torre e muro",
		bd_n1 = "Tana",
		bd_n1b = "+1 🧠 per giocatore preso",
		bd_n2 = "Alveare",
		bd_n2b = "+2 🧠 per giocatore preso",
		bd_n3 = "Trono",
		bd_n3b = "+3 🧠 per giocatore preso",
		bd_fence = "Recinto",
		bd_fenceb = "Un vero cortile",
		bd_lamp = "Lampione",
		bd_lampb = "Luce di notte",
		bd_garden = "Orto",
		bd_gardenb = "+1 🍞 ogni mattina",
		bd_flag = "Bandiera",
		bd_flagb = "Il tuo colore sul cortile",
		bd_bench = "Panchina",
		bd_benchb = "Un posto per sedersi",
		bd_well = "Pozzo",
		bd_wellb = "Acqua per l'orto: +1 🍞 in più",
		bd_bones = "Mucchio di ossa",
		bd_bonesb = "Spaventa i vicini",
		bd_mush = "Funghi luminosi",
		bd_mushb = "Luce nella tana",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 ogni mattina",
		bd_garden_bonus = "🌱 Il tuo orto: +%d 🍞",
		bd_totem_bonus = "🗿 Il tuo totem: +1 🧠",
		bd_built = "🔨 Costruito: %s",
		hm_not_yours = "Questo posto è di un altro giocatore",
		hm_no_plot = "Tutti i terreni di questo server sono occupati",
		hm_hint = "🏠 Hai un terreno fuori dalle mura della città! Usa il segnale della casa qui nella lobby",
		hm_home = "🏠 Questo è il tuo terreno. Tieni premuto il pulsante alla bacheca per costruire: %d pezzi",
		hm_lair = "🧟 Questo è il tuo nido. Tieni premuto il pulsante alla bacheca per farlo crescere: %d cervelli",
		hm_pad1 = "🏠 Tieni premuto il pulsante di questo segnale per andare al tuo terreno fuori dalle mura della città",
		hm_pad2 = "🧟 Tieni premuto il pulsante di questo segnale per andare al tuo nido di zombie",
		hm_moon = "🌙 A casa la notte non ti porta via. Vuoi andare in città? Tieni premuto il segnale 🌙",
		hm_go = "🌙 Pronto! La prossima notte ti porta in città",
		hm_wait = "🌙 Resti a casa. La notte non ti porterà via",
		hm_status = "🏠 A casa. Per andare in città, tieni premuto il segnale 🌙",
		hm_go2 = "🌙 Adesso è notte. La prossima ti porta in città",
		hm_l1 = "CASA MIA",
		hm_l2 = "NIDO ZOMBIE",
		hm_l0 = "NEGOZIO / LOBBY",
		hm_l3 = "IN CITTÀ",
	},
	pl = {
		hm_house1 = "🏠 Szopa zbudowana! Następny będzie prawdziwy dom",
		hm_house2 = "🏠 Dom zbudowany! W plecaku mieści się o 1 rzecz więcej",
		hm_house3 = "🏠 TWIERDZA ZBUDOWANA! W plecaku mieszczą się o 2 rzeczy więcej",
		hm_nest1 = "🧟 Nora wykopana! +1 mózg za każdego złapanego gracza",
		hm_nest2 = "🧟 Ul urósł! +2 mózgi za każdego złapanego gracza",
		hm_nest3 = "🧟 TRON HORDY! +3 mózgi za każdego złapanego gracza",
		hm_need_parts = "🔩 Brakuje części: jeszcze %d. Otwieraj skrzynie w mieście nocą!",
		hm_need_brains = "🧠 Brakuje mózgów: jeszcze %d. Łap ludzi nocą!",
		hm_max = "⭐ Na razie to najwyższy poziom",
		bd_title = "BUDOWA",
		bd_next = "Następny poziom",
		bd_decor = "Podwórko",
		bd_build = "Zbuduj",
		bd_have = "Jest ✔",
		bd_need = "Jeszcze %d",
		bd_close = "Zamknij",
		bd_start = "🔩 Zestaw startowy: %d części! Zbuduj szopę albo ozdób podwórko przy tablicy ⬆",
		bd_t1 = "Szopa",
		bd_t1b = "Ściany zamiast namiotu",
		bd_t2 = "Dom",
		bd_t2b = "+1 miejsce w plecaku",
		bd_t3 = "Twierdza",
		bd_t3b = "+2 miejsca, wieża i mur",
		bd_n1 = "Nora",
		bd_n1b = "+1 🧠 za złapanego gracza",
		bd_n2 = "Ul",
		bd_n2b = "+2 🧠 za złapanego gracza",
		bd_n3 = "Tron",
		bd_n3b = "+3 🧠 za złapanego gracza",
		bd_fence = "Płot",
		bd_fenceb = "Prawdziwe podwórko",
		bd_lamp = "Latarnia",
		bd_lampb = "Światło w nocy",
		bd_garden = "Grządki",
		bd_gardenb = "+1 🍞 co rano",
		bd_flag = "Flaga",
		bd_flagb = "Twój kolor nad podwórkiem",
		bd_bench = "Ławka",
		bd_benchb = "Jest gdzie usiąść",
		bd_well = "Studnia",
		bd_wellb = "Woda dla grządek: jeszcze +1 🍞",
		bd_bones = "Stos kości",
		bd_bonesb = "Straszy sąsiadów",
		bd_mush = "Świecące grzyby",
		bd_mushb = "Światło w legowisku",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 co rano",
		bd_garden_bonus = "🌱 Twoje grządki: +%d 🍞",
		bd_totem_bonus = "🗿 Twój totem: +1 🧠",
		bd_built = "🔨 Zbudowano: %s",
		hm_not_yours = "To miejsce należy do kogoś innego",
		hm_no_plot = "Wszystkie działki na tym serwerze są zajęte",
		hm_hint = "🏠 Masz działkę za murem miasta! Użyj znaku domu tutaj, w lobby",
		hm_home = "🏠 To twoja działka. Przytrzymaj przycisk przy tablicy, aby budować: %d części",
		hm_lair = "🧟 To twoje gniazdo. Przytrzymaj przycisk przy tablicy, aby rosło: %d mózgów",
		hm_pad1 = "🏠 Przytrzymaj przycisk na tym znaku, aby przenieść się na swoją działkę za murem miasta",
		hm_pad2 = "🧟 Przytrzymaj przycisk na tym znaku, aby przenieść się do swojego gniazda zombie",
		hm_moon = "🌙 W domu noc cię nie zabierze. Chcesz do miasta? Przytrzymaj znak 🌙",
		hm_go = "🌙 Gotowe! Następna noc zabierze cię do miasta",
		hm_wait = "🌙 Zostajesz w domu. Noc cię nie zabierze",
		hm_status = "🏠 W domu. Do miasta: przytrzymaj znak 🌙",
		hm_go2 = "🌙 Teraz trwa noc. Następna zabierze cię do miasta",
		hm_l1 = "MÓJ DOM",
		hm_l2 = "GNIAZDO ZOMBIE",
		hm_l0 = "SKLEP / LOBBY",
		hm_l3 = "DO MIASTA",
	},
	tr = {
		hm_house1 = "🏠 Baraka hazır! Sırada gerçek bir ev var",
		hm_house2 = "🏠 Ev hazır! Çantana 1 şey daha sığıyor",
		hm_house3 = "🏠 KALE HAZIR! Çantana 2 şey daha sığıyor",
		hm_nest1 = "🧟 Oyuk kazıldı! Yakaladığın her oyuncu için +1 beyin",
		hm_nest2 = "🧟 Kovan büyüdü! Yakaladığın her oyuncu için +2 beyin",
		hm_nest3 = "🧟 SÜRÜNÜN TAHTI! Yakaladığın her oyuncu için +3 beyin",
		hm_need_parts = "🔩 %d parça daha gerekiyor. Gece şehirde sandık aç!",
		hm_need_brains = "🧠 %d beyin daha gerekiyor. Gece insan yakala!",
		hm_max = "⭐ Şimdilik en yüksek seviye bu",
		bd_title = "İNŞAAT",
		bd_next = "Sonraki seviye",
		bd_decor = "Avlu",
		bd_build = "İnşa et",
		bd_have = "Var ✔",
		bd_need = "%d daha",
		bd_close = "Kapat",
		bd_start = "🔩 Başlangıç seti: %d parça! Panoda bir kulübe kur ya da avluyu süsle ⬆",
		bd_t1 = "Kulübe",
		bd_t1b = "Çadır yerine duvarlar",
		bd_t2 = "Ev",
		bd_t2b = "Çantada +1 yer",
		bd_t3 = "Kale",
		bd_t3b = "+2 yer, kule ve duvar",
		bd_n1 = "Yuva",
		bd_n1b = "Yakalanan oyuncu başına +1 🧠",
		bd_n2 = "Kovan",
		bd_n2b = "Yakalanan oyuncu başına +2 🧠",
		bd_n3 = "Taht",
		bd_n3b = "Yakalanan oyuncu başına +3 🧠",
		bd_fence = "Çit",
		bd_fenceb = "Gerçek bir avlu",
		bd_lamp = "Sokak lambası",
		bd_lampb = "Gece ışık",
		bd_garden = "Bahçe",
		bd_gardenb = "Her sabah +1 🍞",
		bd_flag = "Bayrak",
		bd_flagb = "Avlunun üstünde senin rengin",
		bd_bench = "Bank",
		bd_benchb = "Oturacak bir yer",
		bd_well = "Kuyu",
		bd_wellb = "Bahçeye su: +1 🍞 daha",
		bd_bones = "Kemik yığını",
		bd_bonesb = "Komşuları korkutur",
		bd_mush = "Parlayan mantarlar",
		bd_mushb = "İnde ışık",
		bd_totem = "Totem",
		bd_totemb = "Her sabah +1 🧠",
		bd_garden_bonus = "🌱 Bahçen: +%d 🍞",
		bd_totem_bonus = "🗿 Totemin: +1 🧠",
		bd_built = "🔨 İnşa edildi: %s",
		hm_not_yours = "Burası başka birine ait",
		hm_no_plot = "Bu sunucudaki tüm arsalar dolu",
		hm_hint = "🏠 Şehir duvarının dışında bir arsan var! Lobideki ev işaretini kullan",
		hm_home = "🏠 Burası senin arsan. İnşa etmek için panodaki düğmeyi basılı tut: %d parça",
		hm_lair = "🧟 Burası senin yuvan. Büyütmek için panodaki düğmeyi basılı tut: %d beyin",
		hm_pad1 = "🏠 Bu işaretteki düğmeyi basılı tut: seni şehir duvarının dışındaki arsana götürür",
		hm_pad2 = "🧟 Bu işaretteki düğmeyi basılı tut: seni zombi yuvana götürür",
		hm_moon = "🌙 Evdeyken gece seni almaz. Şehre gitmek ister misin? 🌙 işaretini basılı tut",
		hm_go = "🌙 Hazır! Sonraki gece seni şehre götürecek",
		hm_wait = "🌙 Evde kalıyorsun. Gece seni almayacak",
		hm_status = "🏠 Evdesin. Şehre gitmek için 🌙 işaretini basılı tut",
		hm_go2 = "🌙 Şu an gece. Sonraki gece seni şehre götürecek",
		hm_l1 = "EVİM",
		hm_l2 = "ZOMBİ YUVASI",
		hm_l0 = "MAĞAZA / LOBİ",
		hm_l3 = "ŞEHRE",
	},
	id = {
		hm_house1 = "🏠 Gudang sudah jadi! Berikutnya: rumah sungguhan",
		hm_house2 = "🏠 Rumah sudah jadi! Ranselmu muat 1 barang lagi",
		hm_house3 = "🏠 BENTENG SUDAH JADI! Ranselmu muat 2 barang lagi",
		hm_nest1 = "🧟 Liang sudah digali! +1 otak untuk setiap pemain yang kamu tangkap",
		hm_nest2 = "🧟 Sarang membesar! +2 otak untuk setiap pemain yang kamu tangkap",
		hm_nest3 = "🧟 TAKHTA GEROMBOLAN! +3 otak untuk setiap pemain yang kamu tangkap",
		hm_need_parts = "🔩 Kurang %d suku cadang. Buka peti di kota pada malam hari!",
		hm_need_brains = "🧠 Kurang %d otak. Tangkap orang pada malam hari!",
		hm_max = "⭐ Untuk saat ini ini tingkat tertinggi",
		bd_title = "BANGUN",
		bd_next = "Tingkat berikutnya",
		bd_decor = "Halaman",
		bd_build = "Bangun",
		bd_have = "Sudah ✔",
		bd_need = "Kurang %d",
		bd_close = "Tutup",
		bd_start = "🔩 Paket awal: %d suku cadang! Bangun gudang atau hias halaman di papan ⬆",
		bd_t1 = "Gudang",
		bd_t1b = "Dinding, bukan tenda",
		bd_t2 = "Rumah",
		bd_t2b = "+1 slot ransel",
		bd_t3 = "Benteng",
		bd_t3b = "+2 slot, menara dan tembok",
		bd_n1 = "Liang",
		bd_n1b = "+1 🧠 per pemain tertangkap",
		bd_n2 = "Sarang",
		bd_n2b = "+2 🧠 per pemain tertangkap",
		bd_n3 = "Takhta",
		bd_n3b = "+3 🧠 per pemain tertangkap",
		bd_fence = "Pagar",
		bd_fenceb = "Halaman sungguhan",
		bd_lamp = "Lampu taman",
		bd_lampb = "Terang di malam hari",
		bd_garden = "Kebun",
		bd_gardenb = "+1 🍞 setiap pagi",
		bd_flag = "Bendera",
		bd_flagb = "Warnamu di atas halaman",
		bd_bench = "Bangku",
		bd_benchb = "Tempat duduk",
		bd_well = "Sumur",
		bd_wellb = "Air untuk kebun: +1 🍞 lagi",
		bd_bones = "Tumpukan tulang",
		bd_bonesb = "Menakuti tetangga",
		bd_mush = "Jamur bercahaya",
		bd_mushb = "Cahaya di sarang",
		bd_totem = "Totem",
		bd_totemb = "+1 🧠 setiap pagi",
		bd_garden_bonus = "🌱 Kebunmu: +%d 🍞",
		bd_totem_bonus = "🗿 Totemmu: +1 🧠",
		bd_built = "🔨 Dibangun: %s",
		hm_not_yours = "Tempat ini milik pemain lain",
		hm_no_plot = "Semua lahan di server ini sudah terisi",
		hm_hint = "🏠 Kamu punya lahan di luar tembok kota! Pakai tanda rumah di lobi ini",
		hm_home = "🏠 Ini lahanmu. Tahan tombol di papan untuk membangun: %d suku cadang",
		hm_lair = "🧟 Ini sarangmu. Tahan tombol di papan untuk membesarkannya: %d otak",
		hm_pad1 = "🏠 Tahan tombol di tanda ini untuk pergi ke lahanmu di luar tembok kota",
		hm_pad2 = "🧟 Tahan tombol di tanda ini untuk pergi ke sarang zombimu",
		hm_moon = "🌙 Di rumah malam tidak membawamu. Mau ke kota? Tahan tanda 🌙",
		hm_go = "🌙 Siap! Malam berikutnya membawamu ke kota",
		hm_wait = "🌙 Kamu tetap di rumah. Malam tidak akan membawamu",
		hm_status = "🏠 Di rumah. Ke kota: tahan tanda 🌙",
		hm_go2 = "🌙 Sekarang sedang malam. Malam berikutnya membawamu ke kota",
		hm_l1 = "RUMAHKU",
		hm_l2 = "SARANG ZOMBI",
		hm_l0 = "TOKO / LOBI",
		hm_l3 = "KE KOTA",
	},
	vi = {
		hm_house1 = "🏠 Đã dựng xong nhà kho! Tiếp theo: một ngôi nhà thật sự",
		hm_house2 = "🏠 Đã xây xong nhà! Ba lô chứa thêm 1 món",
		hm_house3 = "🏠 ĐÃ XÂY XONG PHÁO ĐÀI! Ba lô chứa thêm 2 món",
		hm_nest1 = "🧟 Đã đào xong hang! +1 não cho mỗi người chơi bạn bắt được",
		hm_nest2 = "🧟 Tổ đã lớn! +2 não cho mỗi người chơi bạn bắt được",
		hm_nest3 = "🧟 NGAI VÀNG CỦA BẦY ĐÀN! +3 não cho mỗi người chơi bạn bắt được",
		hm_need_parts = "🔩 Còn thiếu %d linh kiện. Hãy mở thùng trong thành phố vào ban đêm!",
		hm_need_brains = "🧠 Còn thiếu %d não. Hãy bắt người vào ban đêm!",
		hm_max = "⭐ Hiện tại đây là cấp cao nhất",
		bd_title = "XÂY DỰNG",
		bd_next = "Cấp tiếp theo",
		bd_decor = "Sân",
		bd_build = "Xây",
		bd_have = "Đã có ✔",
		bd_need = "Thiếu %d",
		bd_close = "Đóng",
		bd_start = "🔩 Bộ khởi đầu: %d linh kiện! Xây nhà kho hoặc trang trí sân ở bảng ⬆",
		bd_t1 = "Nhà kho",
		bd_t1b = "Tường thay cho lều",
		bd_t2 = "Nhà",
		bd_t2b = "+1 ô ba lô",
		bd_t3 = "Pháo đài",
		bd_t3b = "+2 ô, tháp và tường",
		bd_n1 = "Hang",
		bd_n1b = "+1 🧠 mỗi người bắt được",
		bd_n2 = "Tổ",
		bd_n2b = "+2 🧠 mỗi người bắt được",
		bd_n3 = "Ngai",
		bd_n3b = "+3 🧠 mỗi người bắt được",
		bd_fence = "Hàng rào",
		bd_fenceb = "Một cái sân thật sự",
		bd_lamp = "Cột đèn",
		bd_lampb = "Sáng ban đêm",
		bd_garden = "Vườn rau",
		bd_gardenb = "+1 🍞 mỗi sáng",
		bd_flag = "Lá cờ",
		bd_flagb = "Màu của bạn trên sân",
		bd_bench = "Ghế dài",
		bd_benchb = "Chỗ để ngồi",
		bd_well = "Giếng",
		bd_wellb = "Nước cho vườn: thêm +1 🍞",
		bd_bones = "Đống xương",
		bd_bonesb = "Dọa hàng xóm",
		bd_mush = "Nấm phát sáng",
		bd_mushb = "Ánh sáng trong hang",
		bd_totem = "Tượng totem",
		bd_totemb = "+1 🧠 mỗi sáng",
		bd_garden_bonus = "🌱 Vườn của bạn: +%d 🍞",
		bd_totem_bonus = "🗿 Totem của bạn: +1 🧠",
		bd_built = "🔨 Đã xây: %s",
		hm_not_yours = "Nơi này thuộc về người khác",
		hm_no_plot = "Tất cả lô đất trên máy chủ này đã có chủ",
		hm_hint = "🏠 Bạn có một lô đất ngoài tường thành! Dùng biển hình ngôi nhà ở sảnh này",
		hm_home = "🏠 Đây là lô đất của bạn. Giữ nút ở bảng để xây: %d linh kiện",
		hm_lair = "🧟 Đây là tổ của bạn. Giữ nút ở bảng để tổ lớn lên: %d não",
		hm_pad1 = "🏠 Giữ nút trên biển này để đến lô đất của bạn ngoài tường thành",
		hm_pad2 = "🧟 Giữ nút trên biển này để đến tổ thây ma của bạn",
		hm_moon = "🌙 Ở nhà thì màn đêm không đưa bạn đi. Muốn vào thành phố? Giữ biển 🌙",
		hm_go = "🌙 Sẵn sàng! Đêm tới sẽ đưa bạn vào thành phố",
		hm_wait = "🌙 Bạn ở lại nhà. Màn đêm sẽ không đưa bạn đi",
		hm_status = "🏠 Đang ở nhà. Vào thành phố: giữ biển 🌙",
		hm_go2 = "🌙 Bây giờ đang là đêm. Đêm sau sẽ đưa bạn vào thành phố",
		hm_l1 = "NHÀ CỦA TÔI",
		hm_l2 = "TỔ THÂY MA",
		hm_l0 = "CỬA HÀNG / SẢNH",
		hm_l3 = "VÀO THÀNH PHỐ",
	},
	th = {
		hm_house1 = "🏠 สร้างโรงเก็บของเสร็จแล้ว! ต่อไปคือบ้านจริง ๆ",
		hm_house2 = "🏠 สร้างบ้านเสร็จแล้ว! กระเป๋าใส่ของได้เพิ่ม 1 ชิ้น",
		hm_house3 = "🏠 สร้างป้อมปราการเสร็จแล้ว! กระเป๋าใส่ของได้เพิ่ม 2 ชิ้น",
		hm_nest1 = "🧟 ขุดโพรงเสร็จแล้ว! +1 สมองต่อผู้เล่นที่คุณจับได้",
		hm_nest2 = "🧟 รังโตขึ้นแล้ว! +2 สมองต่อผู้เล่นที่คุณจับได้",
		hm_nest3 = "🧟 บัลลังก์แห่งฝูงซอมบี้! +3 สมองต่อผู้เล่นที่คุณจับได้",
		hm_need_parts = "🔩 ยังขาดชิ้นส่วนอีก %d ชิ้น เปิดกล่องในเมืองตอนกลางคืน!",
		hm_need_brains = "🧠 ยังขาดสมองอีก %d ก้อน จับคนตอนกลางคืน!",
		hm_max = "⭐ ตอนนี้นี่คือระดับสูงสุด",
		bd_title = "ก่อสร้าง",
		bd_next = "ขั้นต่อไป",
		bd_decor = "ลานบ้าน",
		bd_build = "สร้าง",
		bd_have = "มีแล้ว ✔",
		bd_need = "ขาดอีก %d",
		bd_close = "ปิด",
		bd_start = "🔩 ชุดเริ่มต้น: ชิ้นส่วน %d ชิ้น! สร้างเพิงหรือตกแต่งลานบ้านที่ป้าย ⬆",
		bd_t1 = "เพิง",
		bd_t1b = "กำแพงแทนเต็นท์",
		bd_t2 = "บ้าน",
		bd_t2b = "เป้ +1 ช่อง",
		bd_t3 = "ป้อมปราการ",
		bd_t3b = "+2 ช่อง หอคอยและกำแพง",
		bd_n1 = "โพรง",
		bd_n1b = "+1 🧠 ต่อผู้เล่นที่จับได้",
		bd_n2 = "รัง",
		bd_n2b = "+2 🧠 ต่อผู้เล่นที่จับได้",
		bd_n3 = "บัลลังก์",
		bd_n3b = "+3 🧠 ต่อผู้เล่นที่จับได้",
		bd_fence = "รั้ว",
		bd_fenceb = "ลานบ้านจริงๆ",
		bd_lamp = "เสาไฟ",
		bd_lampb = "สว่างตอนกลางคืน",
		bd_garden = "แปลงผัก",
		bd_gardenb = "+1 🍞 ทุกเช้า",
		bd_flag = "ธง",
		bd_flagb = "สีของคุณเหนือลานบ้าน",
		bd_bench = "ม้านั่ง",
		bd_benchb = "ที่นั่งพัก",
		bd_well = "บ่อน้ำ",
		bd_wellb = "น้ำสำหรับแปลงผัก: +1 🍞 เพิ่ม",
		bd_bones = "กองกระดูก",
		bd_bonesb = "ทำให้เพื่อนบ้านกลัว",
		bd_mush = "เห็ดเรืองแสง",
		bd_mushb = "แสงในรัง",
		bd_totem = "โทเท็ม",
		bd_totemb = "+1 🧠 ทุกเช้า",
		bd_garden_bonus = "🌱 แปลงผักของคุณ: +%d 🍞",
		bd_totem_bonus = "🗿 โทเท็มของคุณ: +1 🧠",
		bd_built = "🔨 สร้างแล้ว: %s",
		hm_not_yours = "ที่นี่เป็นของผู้เล่นคนอื่น",
		hm_no_plot = "ที่ดินทั้งหมดในเซิร์ฟเวอร์นี้มีเจ้าของแล้ว",
		hm_hint = "🏠 คุณมีที่ดินอยู่นอกกำแพงเมือง! ใช้ป้ายรูปบ้านในล็อบบี้นี้",
		hm_home = "🏠 นี่คือที่ดินของคุณ กดปุ่มค้างที่ป้ายเพื่อสร้าง: %d ชิ้นส่วน",
		hm_lair = "🧟 นี่คือรังของคุณ กดปุ่มค้างที่ป้ายเพื่อให้รังโตขึ้น: %d สมอง",
		hm_pad1 = "🏠 กดปุ่มที่ป้ายนี้ค้างไว้เพื่อไปยังที่ดินของคุณนอกกำแพงเมือง",
		hm_pad2 = "🧟 กดปุ่มที่ป้ายนี้ค้างไว้เพื่อไปยังรังซอมบี้ของคุณ",
		hm_moon = "🌙 อยู่บ้าน กลางคืนจะไม่พาคุณไป อยากเข้าเมืองไหม? กดป้าย 🌙 ค้างไว้",
		hm_go = "🌙 พร้อมแล้ว! คืนถัดไปจะพาคุณเข้าเมือง",
		hm_wait = "🌙 คุณอยู่บ้านต่อ กลางคืนจะไม่พาคุณไป",
		hm_status = "🏠 อยู่บ้าน จะเข้าเมือง: กดป้าย 🌙 ค้างไว้",
		hm_go2 = "🌙 ตอนนี้เป็นกลางคืนอยู่ คืนถัดไปจะพาคุณเข้าเมือง",
		hm_l1 = "บ้านของฉัน",
		hm_l2 = "รังซอมบี้",
		hm_l0 = "ร้านค้า / ล็อบบี้",
		hm_l3 = "เข้าเมือง",
	},
	ko = {
		hm_house1 = "🏠 창고를 지었습니다! 다음은 진짜 집입니다",
		hm_house2 = "🏠 집을 지었습니다! 배낭에 1개를 더 넣을 수 있습니다",
		hm_house3 = "🏠 요새를 지었습니다! 배낭에 2개를 더 넣을 수 있습니다",
		hm_nest1 = "🧟 굴을 팠습니다! 잡은 플레이어마다 뇌 +1",
		hm_nest2 = "🧟 둥지가 자랐습니다! 잡은 플레이어마다 뇌 +2",
		hm_nest3 = "🧟 무리의 왕좌! 잡은 플레이어마다 뇌 +3",
		hm_need_parts = "🔩 부품이 %d개 더 필요합니다. 밤에 도시에서 상자를 여세요!",
		hm_need_brains = "🧠 뇌가 %d개 더 필요합니다. 밤에 사람을 잡으세요!",
		hm_max = "⭐ 지금은 이것이 최고 단계입니다",
		bd_title = "건설",
		bd_next = "다음 단계",
		bd_decor = "마당",
		bd_build = "짓기",
		bd_have = "완료 ✔",
		bd_need = "%d개 부족",
		bd_close = "닫기",
		bd_start = "🔩 스타터 키트: 부품 %d개! 게시판에서 창고를 짓거나 마당을 꾸며요 ⬆",
		bd_t1 = "창고",
		bd_t1b = "텐트 대신 벽",
		bd_t2 = "집",
		bd_t2b = "가방 칸 +1",
		bd_t3 = "요새",
		bd_t3b = "+2칸, 탑과 성벽",
		bd_n1 = "굴",
		bd_n1b = "잡은 플레이어당 +1 🧠",
		bd_n2 = "둥지",
		bd_n2b = "잡은 플레이어당 +2 🧠",
		bd_n3 = "왕좌",
		bd_n3b = "잡은 플레이어당 +3 🧠",
		bd_fence = "울타리",
		bd_fenceb = "제대로 된 마당",
		bd_lamp = "가로등",
		bd_lampb = "밤에도 환하게",
		bd_garden = "텃밭",
		bd_gardenb = "매일 아침 +1 🍞",
		bd_flag = "깃발",
		bd_flagb = "마당 위의 내 색깔",
		bd_bench = "벤치",
		bd_benchb = "앉을 자리",
		bd_well = "우물",
		bd_wellb = "텃밭에 물: +1 🍞 추가",
		bd_bones = "뼈 더미",
		bd_bonesb = "이웃을 겁줘요",
		bd_mush = "빛나는 버섯",
		bd_mushb = "소굴의 불빛",
		bd_totem = "토템",
		bd_totemb = "매일 아침 +1 🧠",
		bd_garden_bonus = "🌱 내 텃밭: +%d 🍞",
		bd_totem_bonus = "🗿 내 토템: +1 🧠",
		bd_built = "🔨 완성: %s",
		hm_not_yours = "이곳은 다른 플레이어의 것입니다",
		hm_no_plot = "이 서버의 땅이 모두 찼습니다",
		hm_hint = "🏠 도시 성벽 밖에 내 땅이 있습니다! 로비의 집 표지를 사용하세요",
		hm_home = "🏠 여기가 내 땅입니다. 게시판에서 버튼을 길게 눌러 지으세요: 부품 %d개",
		hm_lair = "🧟 여기가 내 둥지입니다. 게시판에서 버튼을 길게 눌러 키우세요: 뇌 %d개",
		hm_pad1 = "🏠 이 표지의 버튼을 길게 누르면 도시 성벽 밖 내 땅으로 갑니다",
		hm_pad2 = "🧟 이 표지의 버튼을 길게 누르면 내 좀비 둥지로 갑니다",
		hm_moon = "🌙 집에 있으면 밤이 데려가지 않습니다. 도시로 가려면 🌙 표지를 길게 누르세요",
		hm_go = "🌙 준비 완료! 다음 밤에 도시로 갑니다",
		hm_wait = "🌙 집에 남습니다. 밤이 데려가지 않습니다",
		hm_status = "🏠 집입니다. 도시로 가려면 🌙 표지를 길게 누르세요",
		hm_go2 = "🌙 지금은 밤입니다. 다음 밤에 도시로 갑니다",
		hm_l1 = "내 집",
		hm_l2 = "좀비 둥지",
		hm_l0 = "상점 / 로비",
		hm_l3 = "도시로",
	},
	ja = {
		hm_house1 = "🏠 小屋ができた! 次は本物の家だ",
		hm_house2 = "🏠 家ができた! リュックにあと1つ入る",
		hm_house3 = "🏠 とりでができた! リュックにあと2つ入る",
		hm_nest1 = "🧟 巣穴をほった! つかまえたプレイヤー1人につき脳 +1",
		hm_nest2 = "🧟 巣が大きくなった! つかまえたプレイヤー1人につき脳 +2",
		hm_nest3 = "🧟 むれの玉座! つかまえたプレイヤー1人につき脳 +3",
		hm_need_parts = "🔩 パーツがあと%dこ足りない。夜に街で箱を開けよう!",
		hm_need_brains = "🧠 脳があと%dこ足りない。夜に人をつかまえよう!",
		hm_max = "⭐ 今はこれが一番上のレベル",
		bd_title = "建築",
		bd_next = "次の段階",
		bd_decor = "庭",
		bd_build = "建てる",
		bd_have = "完成 ✔",
		bd_need = "あと%d",
		bd_close = "閉じる",
		bd_start = "🔩 スターターセット：パーツ%dこ！掲示板で小屋を建てるか庭を飾ろう ⬆",
		bd_t1 = "小屋",
		bd_t1b = "テントのかわりに壁",
		bd_t2 = "家",
		bd_t2b = "リュックの枠+1",
		bd_t3 = "要塞",
		bd_t3b = "枠+2、塔と城壁",
		bd_n1 = "巣穴",
		bd_n1b = "つかまえた人ごとに+1 🧠",
		bd_n2 = "ハイブ",
		bd_n2b = "つかまえた人ごとに+2 🧠",
		bd_n3 = "王座",
		bd_n3b = "つかまえた人ごとに+3 🧠",
		bd_fence = "フェンス",
		bd_fenceb = "ちゃんとした庭",
		bd_lamp = "街灯",
		bd_lampb = "夜も明るい",
		bd_garden = "畑",
		bd_gardenb = "毎朝+1 🍞",
		bd_flag = "旗",
		bd_flagb = "庭の上に自分の色",
		bd_bench = "ベンチ",
		bd_benchb = "すわる場所",
		bd_well = "井戸",
		bd_wellb = "畑に水：さらに+1 🍞",
		bd_bones = "骨の山",
		bd_bonesb = "近所をこわがらせる",
		bd_mush = "光るキノコ",
		bd_mushb = "巣の明かり",
		bd_totem = "トーテム",
		bd_totemb = "毎朝+1 🧠",
		bd_garden_bonus = "🌱 きみの畑：+%d 🍞",
		bd_totem_bonus = "🗿 きみのトーテム：+1 🧠",
		bd_built = "🔨 完成：%s",
		hm_not_yours = "ここはほかのプレイヤーの場所",
		hm_no_plot = "このサーバーの土地はすべてうまっている",
		hm_hint = "🏠 街のかべの外にきみの土地がある! ロビーの家のマークを使おう",
		hm_home = "🏠 ここがきみの土地。看板のボタンを長押しして建てよう: パーツ%dこ",
		hm_lair = "🧟 ここがきみの巣。看板のボタンを長押しして大きくしよう: 脳%dこ",
		hm_pad1 = "🏠 このマークのボタンを長押しすると、街のかべの外のきみの土地へ行ける",
		hm_pad2 = "🧟 このマークのボタンを長押しすると、きみのゾンビの巣へ行ける",
		hm_moon = "🌙 家にいれば夜につれていかれないよ。街へ行きたいときは🌙マークを長押し",
		hm_go = "🌙 じゅんびOK! 次の夜に街へ行くよ",
		hm_wait = "🌙 家にのこるよ。夜につれていかれない",
		hm_status = "🏠 家にいるよ。街へ行くなら🌙マークを長押し",
		hm_go2 = "🌙 いまは夜のとちゅう。次の夜に街へ行くよ",
		hm_l1 = "わたしの家",
		hm_l2 = "ゾンビの巣",
		hm_l0 = "ショップ / ロビー",
		hm_l3 = "街へ",
	},
}

return function(ctx: any, sv: any): any
	local map = workspace:FindFirstChild("ZombieTagMap")
	local lobby = if map then map:FindFirstChild("Lobby") else nil
	if not map or not lobby then
		return nil
	end
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local safely: (what: string, action: () -> ()) -> () = sv.safely
	local deco: (name: string, size: Vector3, at: Vector3, color: Color3, material: Enum.Material, parent: Instance) -> Part = sv.block
	local GROUND = 1                         -- верх дорог города: посёлок и логово стоят на той же высоте
	local LOBBY_Y: number = ctx.LOBBY_Y
	local EDGE: number = ctx.cityHalf + 4    -- внешняя грань стены города
	local STREET_Z = EDGE + STREET           -- улица посёлка (за стеной со стороны +Z)
	local TRAIL_Z = -EDGE - STREET           -- тропа логова (за стеной со стороны -Z)

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

	---------------------------------------------------------------------
	-- ЗАГОТОВКИ ДЛЯ ПОСТРОЕК
	---------------------------------------------------------------------
	local world = Instance.new("Model")
	world.Name = "Homes"
	world.Parent = map

	-- твёрдая часть: по ней ходят, в неё упираются
	local function solid(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = at
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end
	-- скат крыши: клин поднимается к своей стороне +Z
	local function slope(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material, parent: Instance): WedgePart
		local part = Instance.new("WedgePart")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = at
		part.Color = color
		part.Material = material
		part.Parent = parent
		return part
	end
	local function lamp(parent: Instance, color: Color3, range: number, brightness: number)
		sv.glow(parent, color, range, brightness)
	end
	local function stars(tier: number): string
		return string.rep("★", tier) .. string.rep("☆", 3 - tier)
	end

	local WOOD = Color3.fromRGB(150, 112, 72)
	local DARK = Color3.fromRGB(46, 42, 40)
	local STONE = Color3.fromRGB(124, 124, 130)
	local ROCK = Color3.fromRGB(70, 68, 64)
	local WARM = Color3.fromRGB(255, 214, 140)
	local SLIME = Color3.fromRGB(120, 255, 110)
	local PATH = Color3.fromRGB(132, 122, 106)
	local MOON = Color3.fromRGB(120, 110, 255) -- значок "в город"

	---------------------------------------------------------------------
	-- УЧАСТКИ. Один участок - это место дома в посёлке и ниша в логове с тем же номером.
	-- f = 1 или -1: в какую сторону по оси Z смотрит вход (к улице). Все постройки описаны так,
	-- будто вход смотрит на +Z; at() переносит точку на участок.
	---------------------------------------------------------------------
	local function newSite(index: number, x: number, z: number, facing: number, kind: string): any
		local model = Instance.new("Model")
		model.Name = if kind == "house" then "Plot" .. index else "Niche" .. index
		model.Parent = world
		local build = Instance.new("Model")
		build.Name = "Build"
		build.Parent = model
		return {
			index = index, kind = kind,
			origin = Vector3.new(x, GROUND, z), f = facing, yaw = if facing == 1 then 0 else math.pi,
			model = model, build = build,
			owner = nil :: Player?, tier = -1,
			board = nil :: any, label = nil :: any, cost = nil :: any, prompt = nil :: any,
			moon = nil :: any, moonSign = nil :: any, moonPart = nil :: any,
		}
	end
	local function at(site: any, x: number, y: number, z: number, turn: number?): CFrame
		local origin: Vector3 = site.origin
		return CFrame.new(origin.X + x * site.f, origin.Y + y, origin.Z + z * site.f) * CFrame.Angles(0, site.yaw + (turn or 0), 0)
	end
	local function point(site: any, x: number, y: number, z: number): Vector3
		local origin: Vector3 = site.origin
		return Vector3.new(origin.X + x * site.f, origin.Y + y, origin.Z + z * site.f)
	end

	local houses: { any } = {}
	local nests: { any } = {}
	for row = 1, 2 do
		for column, x in ipairs(PLOT_X) do
			local index = (row - 1) * #PLOT_X + column
			-- первый ряд стоит у стены города, второй - через улицу; входы смотрят на улицу
			local facing = if row == 1 then 1 else -1
			houses[index] = newSite(index, x, STREET_Z - facing * ROW, facing, "house")
			nests[index] = newSite(index, x, TRAIL_Z + facing * ROW, -facing, "nest")
		end
	end

	---------------------------------------------------------------------
	-- ДОМА: палатка, сарай, дом, крепость
	---------------------------------------------------------------------
	-- коробка дома со входом: пол, четыре стены (в передней - проём), свет внутри
	local function shell(site: any, wide: number, deep: number, high: number, thick: number, color: Color3, material: Enum.Material, centre: number)
		local build: Instance = site.build
		local door, doorHigh = 4, 6.4
		solid("Floor", Vector3.new(wide, 0.3, deep), at(site, 0, 0.15, centre), WOOD, Enum.Material.WoodPlanks, build)
		solid("Wall", Vector3.new(wide, high, thick), at(site, 0, high / 2, centre - deep / 2 + thick / 2), color, material, build)
		solid("Wall", Vector3.new(thick, high, deep), at(site, -wide / 2 + thick / 2, high / 2, centre), color, material, build)
		solid("Wall", Vector3.new(thick, high, deep), at(site, wide / 2 - thick / 2, high / 2, centre), color, material, build)
		local side = (wide - door) / 2
		local front = centre + deep / 2 - thick / 2
		solid("Wall", Vector3.new(side, high, thick), at(site, -(door + side) / 2, high / 2, front), color, material, build)
		solid("Wall", Vector3.new(side, high, thick), at(site, (door + side) / 2, high / 2, front), color, material, build)
		solid("Wall", Vector3.new(door, high - doorHigh, thick), at(site, 0, doorHigh + (high - doorHigh) / 2, front), color, material, build)
		local light = deco("HomeLight", Vector3.new(0.6, 0.6, 0.6), point(site, 0, high - 0.8, centre), WARM, Enum.Material.Neon, build)
		lamp(light, WARM, 18, 1.1)
		return front
	end
	-- светящееся окно на передней стене
	local function window(site: any, x: number, y: number, z: number, wide: number, high: number)
		local glass = deco("HomeWindow", Vector3.new(wide, high, 0.2), point(site, x, y, z), WARM, Enum.Material.Neon, site.build)
		glass.Transparency = 0.15
	end
	local function furniture(site: any, centre: number, wide: number, deep: number)
		local build: Instance = site.build
		-- кровать и сундук с запасами
		solid("Bed", Vector3.new(3, 1.2, 6), at(site, -wide / 2 + 2.4, 0.9, centre - deep / 2 + 3.8), Color3.fromRGB(170, 70, 70), Enum.Material.Fabric, build)
		solid("Pillow", Vector3.new(2.4, 0.5, 1.4), at(site, -wide / 2 + 2.4, 1.75, centre - deep / 2 + 1.6), Color3.fromRGB(236, 236, 228), Enum.Material.Fabric, build)
		solid("Chest", Vector3.new(3, 2.2, 2.2), at(site, wide / 2 - 2.6, 1.4, centre - deep / 2 + 2), Color3.fromRGB(128, 86, 48), Enum.Material.WoodPlanks, build)
		deco("ChestBand", Vector3.new(3.1, 0.4, 2.3), point(site, wide / 2 - 2.6, 1.9, centre - deep / 2 + 2), Color3.fromRGB(214, 176, 70), Enum.Material.Metal, build)
	end
	local function fire(site: any, x: number, z: number)
		local build: Instance = site.build
		solid("FireLog", Vector3.new(2.6, 0.5, 0.6), at(site, x, 0.25, z), DARK, Enum.Material.Wood, build)
		solid("FireLog", Vector3.new(0.6, 0.5, 2.6), at(site, x, 0.25, z), DARK, Enum.Material.Wood, build)
		local flame = deco("FireGlow", Vector3.new(1.2, 1.2, 1.2), point(site, x, 1, z), Color3.fromRGB(255, 150, 50), Enum.Material.Neon, build)
		flame.Shape = Enum.PartType.Ball
		lamp(flame, Color3.fromRGB(255, 160, 70), 16, 1.6)
		local burn = Instance.new("Fire")
		burn.Size = 4
		burn.Heat = 6
		burn.Parent = flame
	end

	local function buildHouse(site: any, tier: number)
		local build: Instance = site.build
		local wall = WALLS[(site.index - 1) % #WALLS + 1]
		local C = -3 -- дом стоит чуть в глубине участка
		if tier == 0 then
			-- палатка: два ската, вход смотрит на улицу
			local canvas = CANVAS[(site.index - 1) % #CANVAS + 1]
			slope("Tent", Vector3.new(8, 5, 3.6), at(site, -1.8, 2.5, C, math.pi / 2), canvas, Enum.Material.Fabric, build)
			slope("Tent", Vector3.new(8, 5, 3.6), at(site, 1.8, 2.5, C, -math.pi / 2), canvas, Enum.Material.Fabric, build)
			deco("TentDoor", Vector3.new(2, 3.2, 0.2), point(site, 0, 1.6, C + 4.05), DARK, Enum.Material.Fabric, build)
			solid("Bedroll", Vector3.new(1.6, 0.5, 4.4), at(site, 5.4, 0.25, C), Color3.fromRGB(96, 124, 160), Enum.Material.Fabric, build)
			solid("Chest", Vector3.new(2.2, 2, 2.2), at(site, -6, 1, C - 1), Color3.fromRGB(128, 86, 48), Enum.Material.WoodPlanks, build)
			fire(site, 0, C + 9)
		elseif tier == 1 then
			-- сарай: дощатые стены и односкатная крыша
			local front = shell(site, 12, 10, 7, 0.6, WOOD, Enum.Material.WoodPlanks, C)
			slope("Roof", Vector3.new(13.4, 2.6, 11.4), at(site, 0, 7 + 1.3, C), Color3.fromRGB(78, 70, 66), Enum.Material.Metal, build)
			window(site, -4, 4.4, front + 0.36, 2, 2)
			furniture(site, C, 12, 10)
			fire(site, 7, C + 9.5)
		else
			-- дом: кирпичные стены, двускатная крыша, труба, крыльцо с фонарём
			local front = shell(site, 16, 13, 9, 0.7, wall, Enum.Material.Brick, C)
			local roof = Color3.fromRGB(112, 62, 54)
			slope("Roof", Vector3.new(17.6, 4.6, 7.3), at(site, 0, 9 + 2.3, C - 3.65), roof, Enum.Material.Slate, build)
			slope("Roof", Vector3.new(17.6, 4.6, 7.3), at(site, 0, 9 + 2.3, C + 3.65, math.pi), roof, Enum.Material.Slate, build)
			solid("Chimney", Vector3.new(2, 5.5, 2), at(site, 5, 12.4, C - 3.4), Color3.fromRGB(120, 76, 66), Enum.Material.Brick, build)
			window(site, -5.2, 4.6, front + 0.4, 2.6, 2.6)
			window(site, 5.2, 4.6, front + 0.4, 2.6, 2.6)
			solid("Porch", Vector3.new(6, 0.5, 2.4), at(site, 0, 0.25, front + 1.5), STONE, Enum.Material.Concrete, build)
			deco("PorchLamp", Vector3.new(0.7, 0.7, 0.7), point(site, 2.8, 6.2, front + 0.7), WARM, Enum.Material.Neon, build)
			furniture(site, C, 16, 13)
			solid("Table", Vector3.new(3.4, 2.4, 2.4), at(site, 3.6, 1.5, C + 2.4), WOOD, Enum.Material.Wood, build)
		end
		if tier == 3 then
			-- крепость: каменная ограда с воротами, башня с флагом, факелы по углам
			local fence, high = 1, 5
			solid("Fence", Vector3.new(30, high, fence), at(site, 0, high / 2, -12.5), STONE, Enum.Material.Cobblestone, build)
			solid("Fence", Vector3.new(fence, high, 25), at(site, -14.5, high / 2, 0), STONE, Enum.Material.Cobblestone, build)
			solid("Fence", Vector3.new(fence, high, 25), at(site, 14.5, high / 2, 0), STONE, Enum.Material.Cobblestone, build)
			solid("Fence", Vector3.new(11, high, fence), at(site, -9.5, high / 2, 12.5), STONE, Enum.Material.Cobblestone, build)
			solid("Fence", Vector3.new(11, high, fence), at(site, 9.5, high / 2, 12.5), STONE, Enum.Material.Cobblestone, build)
			solid("Tower", Vector3.new(5.5, 20, 5.5), at(site, 11, 10, C - 5.5), STONE, Enum.Material.Cobblestone, build)
			for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				solid("TowerTop", Vector3.new(1.6, 1.6, 1.6), at(site, 11 + corner[1] * 1.95, 20.8, C - 5.5 + corner[2] * 1.95), STONE, Enum.Material.Cobblestone, build)
			end
			solid("FlagPole", Vector3.new(0.4, 7, 0.4), at(site, 11, 23.5, C - 5.5), DARK, Enum.Material.Metal, build)
			deco("Flag", Vector3.new(3.4, 2.2, 0.15), point(site, 12.8, 25.6, C - 5.5), wall, Enum.Material.Fabric, build)
			for _, corner in ipairs({ { -14.5, 12.5 }, { 14.5, 12.5 } }) do
				local torch = deco("Torch", Vector3.new(0.9, 0.9, 0.9), point(site, corner[1], high + 0.9, corner[2]), Color3.fromRGB(255, 160, 70), Enum.Material.Neon, build)
				lamp(torch, Color3.fromRGB(255, 170, 90), 18, 1.4)
			end
		end
	end

	---------------------------------------------------------------------
	-- ЛОГОВО: лежанка, нора, улей, трон
	---------------------------------------------------------------------
	-- lit - кокон светит вокруг себя (огней немного: их считает каждый телефон)
	local function pod(site: any, x: number, y: number, z: number, size: number, lit: boolean?)
		local ball = deco("Pod", Vector3.new(size, size, size), point(site, x, y, z), SLIME, Enum.Material.Neon, site.build)
		ball.Shape = Enum.PartType.Ball
		ball.Transparency = 0.2
		if lit then
			lamp(ball, SLIME, 20, 1.8)
		end
	end
	local function buildNest(site: any, tier: number)
		local build: Instance = site.build
		local mud = Color3.fromRGB(74, 62, 50)
		local C = -2
		if tier == 0 then
			-- лежанка: мох в кругу камней и огонёк
			solid("Moss", Vector3.new(7, 0.4, 7), at(site, 0, 0.2, C), Color3.fromRGB(70, 104, 62), Enum.Material.Grass, build)
			for step = 0, 5 do
				local angle = step * math.pi / 3
				solid("Stone", Vector3.new(1.8, 1.4, 1.8), at(site, math.cos(angle) * 4.6, 0.7, C + math.sin(angle) * 4.6), ROCK, Enum.Material.Slate, build)
			end
			pod(site, 0, 1.4, C, 1.2, true)
		else
			-- нора (и улей - побольше): земляной купол со входом
			local wide = if tier == 1 then 11 else 15
			local dome = solid("Mound", Vector3.new(wide, wide, wide), at(site, 0, 0, C), mud, Enum.Material.Ground, build)
			dome.Shape = Enum.PartType.Ball
			deco("Hole", Vector3.new(3.2, 3.6, 0.6), point(site, 0, 1.8, C + wide / 2 - 0.5), Color3.fromRGB(14, 16, 14), Enum.Material.SmoothPlastic, build)
			pod(site, -wide / 2 - 1.5, 1, C + 3, 1.4, true)
			pod(site, wide / 2 + 1.5, 1, C + 3, 1.4)
		end
		if tier >= 2 then
			-- улей: светящиеся коконы и рёбра над куполом
			pod(site, -5, 6.4, C - 2, 2.4)
			pod(site, 5, 5.8, C + 1, 2)
			pod(site, 0, 8.2, C, 2.8, true)
			for _, x in ipairs({ -8.6, 8.6 }) do
				solid("Rib", Vector3.new(0.8, 10, 0.8), at(site, x, 5, C), Color3.fromRGB(214, 208, 190), Enum.Material.Slate, build)
				solid("Rib", Vector3.new(0.8, 0.8, 5), at(site, x * 0.82, 10, C), Color3.fromRGB(214, 208, 190), Enum.Material.Slate, build)
			end
		end
		if tier == 3 then
			-- трон орды: помост перед ульем, каменное кресло и четыре зелёных огня
			solid("Dais", Vector3.new(12, 1.2, 7), at(site, 0, 0.6, C + 10.5), ROCK, Enum.Material.Slate, build)
			solid("Throne", Vector3.new(4, 1.4, 3.6), at(site, 0, 1.9, C + 10), STONE, Enum.Material.Slate, build)
			solid("Throne", Vector3.new(4, 7, 1), at(site, 0, 4.7, C + 8.6), STONE, Enum.Material.Slate, build)
			solid("Throne", Vector3.new(0.9, 2.4, 3.6), at(site, -2.4, 3.2, C + 10), STONE, Enum.Material.Slate, build)
			solid("Throne", Vector3.new(0.9, 2.4, 3.6), at(site, 2.4, 3.2, C + 10), STONE, Enum.Material.Slate, build)
			for _, corner in ipairs({ { -5.2, 7.8 }, { 5.2, 7.8 }, { -5.2, 13.2 }, { 5.2, 13.2 } }) do
				solid("Brazier", Vector3.new(1.1, 4.6, 1.1), at(site, corner[1], 3.5, C + corner[2]), ROCK, Enum.Material.Slate, build)
				pod(site, corner[1], 6.4, C + corner[2], 1.3, corner[1] < 0 and corner[2] > 10)
			end
		end
	end

	---------------------------------------------------------------------
	-- ХОЗЯИН УЧАСТКА, ДОСКА И СТРОЙКА
	---------------------------------------------------------------------
	local plotOf: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local welcomed: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any -- кому уже рассказано про дом и логово
	local hinted: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function tierOf(site: any): number
		local owner: Player? = site.owner
		local session = if owner then sessions[owner] else nil
		if not session then
			return NEIGHBOURS[site.index]
		end
		local ext = sv.stock(session)
		return if site.kind == "house" then ext.house else ext.nest
	end
	-- надпись на доске стройки: сколько деталей (мозгов) уже есть у хозяина и сколько нужно на следующую ступень
	local function priceOf(site: any): string
		local tier: number = site.tier
		if tier >= 3 then
			return "⭐"
		end
		local house = site.kind == "house"
		local need: number = if house then HOUSE_COST[tier + 1] else NEST_COST[tier + 1]
		local icon = if house then "🔩 " else "🧠 "
		local owner: Player? = site.owner
		local session = if owner then sessions[owner] else nil
		if not session then
			return icon .. need
		end
		local ext = sv.stock(session)
		local title = ctx.tr(owner :: Player, (if house then "bd_t" else "bd_n") .. (tier + 1))
		return title .. "\n" .. icon .. (if house then ext.mats else ext.bio) .. "/" .. need
	end
	local decorate: (any) -> () = function() end -- украшения двора (задаётся ниже, в разделе стройки)
	local animateBuild: (any) -> () = function() end -- постройка вырастает из земли (задаётся ниже)
	local dressBuild: (any) -> () = function() end -- материалы и таблички-картинки (модуль HomesFX, если он есть)
	-- перестраивает участок, если ступень или хозяин изменились, и обновляет табличку
	local function refresh(site: any, force: boolean?)
		local tier = tierOf(site)
		local owner: Player? = site.owner
		if tier ~= site.tier or force then
			site.tier = tier
			for _, child in ipairs(site.build:GetChildren()) do
				child:Destroy()
			end
			if site.kind == "house" then
				buildHouse(site, tier)
			else
				buildNest(site, tier)
			end
			decorate(site)
			dressBuild(site)
		end
		site.label.Text = (if owner then owner.DisplayName else "🤖") .. "\n" .. stars(tier)
		site.cost.Text = priceOf(site)
		site.cost.Parent.Enabled = owner ~= nil
		site.prompt.Enabled = owner ~= nil
		-- значок "в город" есть только на участке с хозяином
		site.moon.Enabled = owner ~= nil
		site.moonSign.Enabled = owner ~= nil
		site.moonPart.Transparency = if owner then 0.25 else 1
	end
	local step: (Player, any) -> () = function() end -- поставить игрока у входа на участок (задаётся ниже, вместе с переходами)
	local ready: (Player, Vector3) -> () = function() end -- игрок нажал значок "в город" (задаётся ниже)
	-- значок "в город" 🌙: кто дома, того ночь забирает не сразу; нажал - заберёт ближайшая
	local function moonPad(where: Vector3, parent: Instance): (Part, BillboardGui, ProximityPrompt)
		local plate = deco("HM_PadGo", Vector3.new(4.6, 0.3, 4.6), where, MOON, Enum.Material.Neon, parent)
		plate.Transparency = 0.25
		local sign = sv.sign(plate, "🌙", Color3.fromRGB(255, 255, 255), 3.2, 3.4, 120)
		local prompt = sv.button(plate, "HM_PadGo", PAD_HOLD, function(player: Player)
			ready(player, where)
		end)
		return plate, sign, prompt
	end
	local function upgrade(site: any, player: Player)
		local session = sessions[player]
		local root = ctx.getAlive(player)
		if not session or not root or (root.Position - site.board.Position).Magnitude > REACH then
			return
		end
		if site.owner ~= player then
			ctx.toast(player, "hm_not_yours")
			ctx.sound(player, "deny")
			return
		end
		-- прогресс ещё не загрузился (сбой хранилища): в нём может уже стоять эта ступень, детали пропали бы зря
		if not session.canSave and ctx.saveBroken() then
			ctx.toast(player, "no_save")
			ctx.sound(player, "deny")
			return
		end
		local ext = sv.stock(session)
		local house = site.kind == "house"
		local tier: number = if house then ext.house else ext.nest
		if tier >= 3 then
			ctx.toast(player, "hm_max")
			return
		end
		local cost = if house then HOUSE_COST[tier + 1] else NEST_COST[tier + 1]
		local have: number = if house then ext.mats else ext.bio
		if have < cost then
			ctx.toast(player, if house then "hm_need_parts" else "hm_need_brains", cost - have)
			ctx.sound(player, "deny")
			return
		end
		if house then
			ext.mats -= cost
			ext.house = tier + 1
		else
			ext.bio -= cost
			ext.nest = tier + 1
		end
		refresh(site)
		animateBuild(site)
		ctx.big(player, if house then HOUSE_TEXT[tier + 1] else NEST_TEXT[tier + 1])
		ctx.sound(player, "buy")
		-- кто стоял во дворе, там, где выросли новые стены и забор, оказывается перед входом, лицом к постройке
		local origin: Vector3 = site.origin
		local lx, lz = (root.Position.X - origin.X) * site.f, (root.Position.Z - origin.Z) * site.f
		if math.abs(lx) <= 16 and lz >= -14 and lz <= 14.4 then
			step(player, site)
		end
		-- искры над новой постройкой
		local spark = Instance.new("Sparkles")
		spark.SparkleColor = if house then WARM else SLIME
		spark.Parent = site.board
		task.delay(4, function()
			spark:Destroy()
		end)
	end
	-- табличка с именем хозяина и доска стройки у входа на участок
	local function furnish(site: any)
		local model: Instance = site.model
		local house = site.kind == "house"
		deco("Yard", Vector3.new(30, 0.1, 26), point(site, 0, 0.05, 0), if house then Color3.fromRGB(122, 104, 76) else Color3.fromRGB(52, 54, 50), if house then Enum.Material.Ground else Enum.Material.Slate, model)
		deco("YardPath", Vector3.new(4, 0.12, 9), point(site, 0, 0.07, 9.5), PATH, Enum.Material.Cobblestone, model)
		solid("Post", Vector3.new(0.5, 4, 0.5), at(site, -10, 2, 14.2), DARK, Enum.Material.Wood, model)
		local plate = solid("NamePlate", Vector3.new(4, 2, 0.3), at(site, -10, 4.6, 14.2), if house then WOOD else ROCK, Enum.Material.WoodPlanks, model)
		local name = sv.sign(plate, "", Color3.fromRGB(255, 255, 255), 6, 2.6, 110)
		site.label = name:FindFirstChildOfClass("TextLabel")
		solid("Post", Vector3.new(0.5, 4, 0.5), at(site, 10, 2, 14.2), DARK, Enum.Material.Wood, model)
		local board = solid("BuildBoard", Vector3.new(4, 2.6, 0.3), at(site, 10, 4.9, 14.2), if house then Color3.fromRGB(236, 214, 150) else Color3.fromRGB(96, 150, 92), Enum.Material.SmoothPlastic, model)
		site.board = board
		local cost = sv.sign(board, "", Color3.fromRGB(255, 255, 255), 4.4, 2.6, 80)
		site.cost = cost:FindFirstChildOfClass("TextLabel")
		site.prompt = sv.button(board, "HM_Build", BUILD_HOLD, function(player: Player)
			upgrade(site, player)
		end)
		-- слева от входа, там, где игрок появляется: значок "в город"
		site.moonPart, site.moonSign, site.moon = moonPad(point(site, -5.6, 0.2, 16.4), model)
	end

	---------------------------------------------------------------------
	-- ПОСЁЛОК И ЛОГОВО: земля, ограды, улица, площадь
	---------------------------------------------------------------------
	local function ground()
		-- серая плита вокруг города становится землёй (только на время игры: место в Studio не меняется)
		local base = workspace:FindFirstChild("Baseplate")
		if base and base:IsA("BasePart") then
			base.Material = Enum.Material.Ground
			base.Color = Color3.fromRGB(72, 86, 60)
			local studs = base:FindFirstChildOfClass("Texture")
			if studs then
				studs:Destroy()
			end
		end
	end
	local function settlement()
		local centre = STREET_Z
		local grass = Color3.fromRGB(88, 138, 76)
		solid("SettleGround", Vector3.new(432, 1, STREET * 2), CFrame.new(0, GROUND - 0.5, centre), grass, Enum.Material.Grass, world)
		deco("SettleStreet", Vector3.new(432, 0.12, 12), Vector3.new(0, GROUND + 0.06, centre), PATH, Enum.Material.Cobblestone, world)
		deco("SettleSquare", Vector3.new(40, 0.14, STREET * 2 - 4), Vector3.new(0, GROUND + 0.07, centre), PATH, Enum.Material.Cobblestone, world)
		-- частокол с трёх сторон; четвёртая сторона - стена города
		local far = centre + STREET
		solid("Palisade", Vector3.new(434, 11, 1.2), CFrame.new(0, GROUND + 5.5, far + 0.6), WOOD, Enum.Material.WoodPlanks, world)
		for _, x in ipairs({ -216.6, 216.6 }) do
			solid("Palisade", Vector3.new(1.2, 11, STREET * 2), CFrame.new(x, GROUND + 5.5, centre), WOOD, Enum.Material.WoodPlanks, world)
		end
		-- ворота в стене города (закрыты: в город игроков переносит ночь)
		for _, x in ipairs({ -10, 10 }) do
			deco("GatePost", Vector3.new(3, 24, 1.4), Vector3.new(x, GROUND + 12, EDGE + 0.7), DARK, Enum.Material.Metal, world)
		end
		deco("GateTop", Vector3.new(23, 3, 1.4), Vector3.new(0, GROUND + 22.5, EDGE + 0.7), DARK, Enum.Material.Metal, world)
		deco("GateDoor", Vector3.new(17, 21, 0.8), Vector3.new(0, GROUND + 10.5, EDGE + 0.4), Color3.fromRGB(214, 176, 44), Enum.Material.DiamondPlate, world)
		deco("GateBar", Vector3.new(17, 1.6, 1), Vector3.new(0, GROUND + 11, EDGE + 0.6), DARK, Enum.Material.Metal, world)
		-- фонари вдоль улицы
		for index, x in ipairs({ -198, -126, -54, 54, 126, 198 }) do
			local side = if index % 2 == 0 then 7.5 else -7.5
			solid("LanternPole", Vector3.new(0.6, 10, 0.6), CFrame.new(x, GROUND + 5, centre + side), DARK, Enum.Material.Metal, world)
			local head = deco("Lantern", Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, GROUND + 10.6, centre + side), WARM, Enum.Material.Neon, world)
			head.Shape = Enum.PartType.Ball
			lamp(head, WARM, 30, 1.3)
		end
		-- костёр и скамейки на площади
		local square = { origin = Vector3.new(0, GROUND, centre + 26), f = 1, yaw = 0, build = world }
		fire(square, 0, 0)
		for _, x in ipairs({ -6, 6 }) do
			solid("Bench", Vector3.new(1.6, 1.4, 7), CFrame.new(x, GROUND + 0.7, centre + 26), WOOD, Enum.Material.WoodPlanks, world)
		end
	end
	local function cave()
		local centre = TRAIL_Z
		local floor = Color3.fromRGB(74, 78, 72)
		solid("CaveGround", Vector3.new(432, 1, STREET * 2), CFrame.new(0, GROUND - 0.5, centre), floor, Enum.Material.Slate, world)
		deco("CaveTrail", Vector3.new(432, 0.12, 12), Vector3.new(0, GROUND + 0.06, centre), Color3.fromRGB(74, 80, 70), Enum.Material.Ground, world)
		-- скалы с трёх сторон и каменные козырьки над нишами: посередине видно небо
		local far = centre - STREET
		solid("CaveRock", Vector3.new(444, 30, 8), CFrame.new(0, GROUND + 15, far - 4), ROCK, Enum.Material.Slate, world)
		for _, x in ipairs({ -220, 220 }) do
			solid("CaveRock", Vector3.new(8, 30, STREET * 2), CFrame.new(x, GROUND + 15, centre), ROCK, Enum.Material.Slate, world)
		end
		for _, side in ipairs({ -1, 1 }) do
			solid("CaveRoof", Vector3.new(432, 4, STREET - 14), CFrame.new(0, GROUND + 28, centre + side * (STREET + 14) / 2), ROCK, Enum.Material.Slate, world)
		end
		-- светящиеся грибы вдоль тропы
		for index, x in ipairs({ -198, -162, -90, -18, 18, 90, 162, 198 }) do
			local side = if index % 2 == 0 then 8 else -8
			solid("Shroom", Vector3.new(0.7, 2.4, 0.7), CFrame.new(x, GROUND + 1.2, centre + side), Color3.fromRGB(214, 208, 190), Enum.Material.SmoothPlastic, world)
			local cap = deco("ShroomCap", Vector3.new(2.6, 1.2, 2.6), Vector3.new(x, GROUND + 2.8, centre + side), SLIME, Enum.Material.Neon, world)
			cap.Shape = Enum.PartType.Ball
			lamp(cap, SLIME, 34, 2)
		end
	end

	---------------------------------------------------------------------
	-- ПЕРЕХОДЫ: дом, логово, лобби
	---------------------------------------------------------------------
	local moving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- кого сейчас переносит сам модуль
	local homing: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- кого и когда игра поставила в лобби, а модуль несёт домой
	local warmed: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- когда дом игрока в последний раз подгружали заранее
	local function inHome(pos: Vector3): boolean
		if pos.Y > LOBBY_Y - 60 or math.abs(pos.X) > 224 then
			return false
		end
		local z = math.abs(pos.Z)
		return z >= EDGE - 2 and z <= EDGE + STREET * 2 + 6
	end
	-- место подгружается у игрока заранее: тогда после переноса под ногами уже есть земля
	local function preload(player: Player, target: Vector3)
		pcall(function()
			(player :: any):RequestStreamAroundAsync(target, 2)
		end)
	end
	-- ready - место уже подгружено (утром, после ночи): ждать не нужно
	local function send(player: Player, target: Vector3, look: Vector3?, ready: boolean?)
		task.spawn(function()
			if not ready then
				preload(player, target)
			end
			local character = player.Character
			if not character or not ctx.getAlive(player) or inRound[player] then
				return
			end
			moving[player] = true
			ctx.Guard.allow(player, target)
			moving[player] = nil
			character:PivotTo(if look then CFrame.lookAt(target, Vector3.new(look.X, target.Y, look.Z)) else CFrame.new(target))
		end)
	end
	---------------------------------------------------------------------
	-- СТРОЙКА: МЕНЮ У ДОСКИ, УКРАШЕНИЯ ДВОРА, СТАРТОВЫЙ НАБОР, АНИМАЦИЯ ПОСТРОЙКИ
	-- Хозяин подходит к своей доске - на экране открывается меню: следующая ступень дома (с ценой и тем,
	-- что она даёт) и украшения двора. Нажатие на экране приходит на сервер через ZT_Build (ReplicatedStorage),
	-- сервер проверяет хозяина, расстояние и цену. Украшения хранятся в ext.items ("d_" .. id = 1).
	---------------------------------------------------------------------
	local TweenService = game:GetService("TweenService")
	local START_PARTS = 16   -- стартовый набор деталей: на сарай (12) и одно украшение
	local MENU_REACH = 11    -- на каком расстоянии от своей доски открывается меню
	-- украшения дома: id, цена в деталях, что даёт (для текста), и как построить (в координатах участка)
	local DECOR: { { id: string, cost: number, kind: string, build: (any, Instance) -> () } } = {}
	local NEST_DECOR: { { id: string, cost: number, kind: string, build: (any, Instance) -> () } } = {}
	local function item(list: { any }, id: string, cost: number, kind: string, build: (any, Instance) -> ())
		table.insert(list, { id = id, cost = cost, kind = kind, build = build })
	end
	local PLANK = Color3.fromRGB(168, 128, 84)
	item(DECOR, "fence", 4, "house", function(site: any, parent: Instance)
		-- деревянный забор по краю двора с проходом к улице
		local rail = Color3.fromRGB(150, 112, 72)
		local function post(x: number, z: number)
			solid("FencePost", Vector3.new(0.6, 3, 0.6), at(site, x, 1.5, z), DARK, Enum.Material.Wood, parent)
		end
		local function bar(x: number, z: number, long: number, along: boolean)
			solid("FenceRail", if along then Vector3.new(long, 0.35, 0.25) else Vector3.new(0.25, 0.35, long), at(site, x, 1.9, z), rail, Enum.Material.WoodPlanks, parent)
			solid("FenceRail", if along then Vector3.new(long, 0.35, 0.25) else Vector3.new(0.25, 0.35, long), at(site, x, 0.9, z), rail, Enum.Material.WoodPlanks, parent)
		end
		bar(0, -12.8, 30, true)
		bar(-14.8, 0, 25.6, false)
		bar(14.8, 0, 25.6, false)
		bar(-9, 12.8, 11.6, true)
		bar(9, 12.8, 11.6, true)
		for _, x in ipairs({ -14.8, -9.9, -4.9, 0, 4.9, 9.9, 14.8 }) do
			post(x, -12.8)
		end
		for _, z in ipairs({ -8.5, -4.2, 0, 4.2, 8.5 }) do
			post(-14.8, z)
			post(14.8, z)
		end
		for _, x in ipairs({ -14.8, -10.3, -5.8, -3.3, 3.3, 5.8, 10.3, 14.8 }) do
			post(x, 12.8)
		end
	end)
	item(DECOR, "lamp", 3, "house", function(site: any, parent: Instance)
		solid("LampPost", Vector3.new(0.5, 6.5, 0.5), at(site, -5.5, 3.25, 9.5), DARK, Enum.Material.Metal, parent)
		solid("LampArm", Vector3.new(0.3, 0.3, 1.6), at(site, -5.5, 6.4, 10.2), DARK, Enum.Material.Metal, parent)
		local head = deco("LampHead", Vector3.new(1.1, 0.9, 1.1), point(site, -5.5, 6.1, 10.9), WARM, Enum.Material.Neon, parent)
		lamp(head, WARM, 22, 1.6)
	end)
	item(DECOR, "garden", 5, "house", function(site: any, parent: Instance)
		for i = 0, 2 do
			local z = 3.5 + i * 2.4
			solid("Bed", Vector3.new(6, 0.5, 1.6), at(site, 9.5, 0.25, z), Color3.fromRGB(78, 56, 40), Enum.Material.Ground, parent)
			for _, x in ipairs({ 7.4, 9.5, 11.6 }) do
				local bush = deco("Sprout", Vector3.new(1.2, 1.1, 1.2), point(site, x, 0.95, z), Color3.fromRGB(96, 170, 70), Enum.Material.Grass, parent)
				bush.Shape = Enum.PartType.Ball
			end
		end
	end)
	item(DECOR, "flag", 2, "house", function(site: any, parent: Instance)
		local wall = WALLS[(site.index - 1) % #WALLS + 1]
		solid("FlagPole", Vector3.new(0.4, 9, 0.4), at(site, -13, 4.5, -10.5), DARK, Enum.Material.Metal, parent)
		deco("Flag", Vector3.new(3.2, 2, 0.15), point(site, -11.3, 7.9, -10.5), wall, Enum.Material.Fabric, parent)
	end)
	item(DECOR, "bench", 3, "house", function(site: any, parent: Instance)
		solid("BenchSeat", Vector3.new(4.4, 0.4, 1.6), at(site, -9.5, 1.5, 6), PLANK, Enum.Material.WoodPlanks, parent)
		solid("BenchBack", Vector3.new(4.4, 1.6, 0.3), at(site, -9.5, 2.5, 5.2), PLANK, Enum.Material.WoodPlanks, parent)
		solid("BenchLeg", Vector3.new(0.4, 1.3, 1.6), at(site, -11.3, 0.65, 6), DARK, Enum.Material.Metal, parent)
		solid("BenchLeg", Vector3.new(0.4, 1.3, 1.6), at(site, -7.7, 0.65, 6), DARK, Enum.Material.Metal, parent)
	end)
	item(DECOR, "well", 6, "house", function(site: any, parent: Instance)
		local ring = solid("WellRing", Vector3.new(4, 2.2, 4), at(site, 12, 1.1, -9), STONE, Enum.Material.Cobblestone, parent)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = ring.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		local water = deco("WellWater", Vector3.new(2.8, 0.3, 2.8), point(site, 12, 1.4, -9), Color3.fromRGB(80, 170, 255), Enum.Material.Neon, parent)
		water.Shape = Enum.PartType.Cylinder
		water.CFrame = water.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		solid("WellPost", Vector3.new(0.5, 4.6, 0.5), at(site, 10.3, 3.3, -9), DARK, Enum.Material.Wood, parent)
		solid("WellPost", Vector3.new(0.5, 4.6, 0.5), at(site, 13.7, 3.3, -9), DARK, Enum.Material.Wood, parent)
		slope("WellRoof", Vector3.new(5.2, 1.6, 2.4), at(site, 12, 6.3, -10.2), Color3.fromRGB(112, 62, 54), Enum.Material.Slate, parent)
		slope("WellRoof", Vector3.new(5.2, 1.6, 2.4), at(site, 12, 6.3, -7.8, math.pi), Color3.fromRGB(112, 62, 54), Enum.Material.Slate, parent)
		solid("Bucket", Vector3.new(1, 1, 1), at(site, 12, 4.2, -9), Color3.fromRGB(110, 110, 116), Enum.Material.Metal, parent)
	end)
	item(NEST_DECOR, "bones", 2, "nest", function(site: any, parent: Instance)
		local bone = Color3.fromRGB(226, 220, 200)
		solid("Bone", Vector3.new(3.2, 0.6, 0.6), at(site, 9, 0.3, 6, 0.4), bone, Enum.Material.SmoothPlastic, parent)
		solid("Bone", Vector3.new(2.6, 0.6, 0.6), at(site, 10, 0.9, 7, -0.8), bone, Enum.Material.SmoothPlastic, parent)
		solid("Bone", Vector3.new(2.2, 0.5, 0.5), at(site, 8, 1.3, 5.4, 1.3), bone, Enum.Material.SmoothPlastic, parent)
		local skull = solid("Skull", Vector3.new(1.4, 1.4, 1.4), at(site, 9.6, 1.9, 6.4), bone, Enum.Material.SmoothPlastic, parent)
		skull.Shape = Enum.PartType.Ball
	end)
	item(NEST_DECOR, "mush", 3, "nest", function(site: any, parent: Instance)
		for i, spot in ipairs({ { -9, 5 }, { -10.6, 7 }, { -7.8, 7.6 } }) do
			local size = 0.8 + i * 0.3
			solid("Stem", Vector3.new(0.5, size * 1.2, 0.5), at(site, spot[1], size * 0.6, spot[2]), Color3.fromRGB(214, 208, 190), Enum.Material.SmoothPlastic, parent)
			local cap = deco("Cap", Vector3.new(size * 1.6, size * 0.8, size * 1.6), point(site, spot[1], size * 1.2 + size * 0.3, spot[2]), SLIME, Enum.Material.Neon, parent)
			cap.Shape = Enum.PartType.Ball
			if i == 3 then
				lamp(cap, SLIME, 18, 1.4)
			end
		end
	end)
	item(NEST_DECOR, "totem", 4, "nest", function(site: any, parent: Instance)
		solid("TotemPost", Vector3.new(1.4, 6, 1.4), at(site, 12, 3, -9), Color3.fromRGB(90, 70, 50), Enum.Material.Wood, parent)
		solid("TotemHead", Vector3.new(2.2, 2.2, 2.2), at(site, 12, 7, -9), Color3.fromRGB(70, 60, 50), Enum.Material.Wood, parent)
		deco("TotemEye", Vector3.new(0.5, 0.5, 0.3), point(site, 11.5, 7.3, -9 + 1.1 * site.f), SLIME, Enum.Material.Neon, parent)
		deco("TotemEye", Vector3.new(0.5, 0.5, 0.3), point(site, 12.5, 7.3, -9 + 1.1 * site.f), SLIME, Enum.Material.Neon, parent)
	end)
	local function decorOf(site: any): { any }
		return if site.kind == "house" then DECOR else NEST_DECOR
	end
	local function hasDecor(ext: any, id: string): boolean
		local items: { [string]: number } = ext.items
		return (items["d_" .. id] or 0) > 0
	end
	-- украшения участка: своя модель рядом с постройкой; перестраивается вместе с ней
	decorate = function(site: any)
		local model: Instance = site.model
		local old = model:FindFirstChild("Decor")
		if old then
			old:Destroy()
		end
		local owner: Player? = site.owner
		local session = if owner then sessions[owner] else nil
		if not session then
			return
		end
		local ext = sv.stock(session)
		local folder = Instance.new("Model")
		folder.Name = "Decor"
		for _, entry in ipairs(decorOf(site)) do
			-- у крепости свои стена и флаг
			local hidden = site.kind == "house" and site.tier >= 3 and (entry.id == "fence" or entry.id == "flag")
			if hasDecor(ext, entry.id) and not hidden then
				entry.build(site, folder)
			end
		end
		folder.Parent = model
	end
	-- постройка вырастает из земли: каждая часть поднимается и раскрывается, с пылью и стуком
	local function animate(site: any, parts: { BasePart }, player: Player?)
		local origin: Vector3 = site.origin
		local board: BasePart = site.board
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(200, 180, 150))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(1.2, 2)
		dust.Speed = NumberRange.new(4, 9)
		dust.SpreadAngle = Vector2.new(60, 60)
		dust.Rate = 0
		local puff = deco("Dust", Vector3.new(1, 1, 1), Vector3.new(origin.X, origin.Y + 1, origin.Z), WARM, Enum.Material.Neon, site.model)
		puff.Transparency = 1
		dust.Parent = puff
		local knock = Instance.new("Sound")
		knock.SoundId = "rbxassetid://91852844501226"; knock.PlaybackRegionsEnabled = true; knock.PlaybackRegion = NumberRange.new(7.131, 7.851) -- our build pack: hammer
		knock.Volume = 0.6
		knock.RollOffMaxDistance = 90
		knock.Parent = board
		table.sort(parts, function(a: BasePart, b: BasePart): boolean
			return a.Position.Y - a.Size.Y / 2 < b.Position.Y - b.Size.Y / 2
		end)
		local finals: { [BasePart]: { cf: CFrame, size: Vector3 } } = {}
		for _, part in ipairs(parts) do
			finals[part] = { cf = part.CFrame, size = part.Size }
			part.CFrame = part.CFrame * CFrame.new(0, -part.Size.Y * 0.5 - 0.5, 0)
			part.Size = Vector3.new(part.Size.X * 0.2, part.Size.Y * 0.2, part.Size.Z * 0.2)
		end
		task.spawn(function()
			local perPart = math.clamp(1.8 / math.max(1, #parts), 0.02, 0.12)
			for i, part in ipairs(parts) do
				local final = finals[part]
				if part.Parent then
					TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final.cf, Size = final.size }):Play()
				end
				if i % 4 == 1 then
					dust:Emit(6)
					knock.PlaybackSpeed = 0.9 + math.random() * 0.3
					knock:Play()
				end
				task.wait(perPart)
			end
			task.wait(0.4)
			dust:Emit(20)
			local done = Instance.new("Sound")
			done.SoundId = "rbxassetid://91852844501226"; done.PlaybackRegionsEnabled = true; done.PlaybackRegion = NumberRange.new(1.46, 4.06) -- our build pack: done
			done.Volume = 0.7
			done.Parent = board
			done:Play()
			task.wait(2.5)
			puff:Destroy()
			knock:Destroy()
			done:Destroy()
		end)
	end
	local function partsOf(container: Instance): { BasePart }
		local list = {}
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		return list
	end
	-- модуль HomesFX (рядом с Homes): стройка с чертежом, лесами и слизью, премиальные материалы и таблички
	local fx: any = nil
	do
		local home = script.Parent
		local found = if home then home:FindFirstChild("HomesFX") else nil
		if found then
			local ok, made = pcall(function()
				return (require :: any)(found)({ ctx = ctx, sv = sv })
			end)
			if ok and type(made) == "table" then
				fx = made
			else
				warn("[Zombie Tag] HomesFX: " .. tostring(made))
			end
		end
	end
	if fx and fx.dress then
		dressBuild = function(site: any)
			local ok, err = pcall(fx.dress, site)
			if not ok then
				warn("[Zombie Tag] HomesFX dress: " .. tostring(err))
			end
		end
		for _, list in ipairs({ houses, nests }) do
			for _, site in ipairs(list) do
				if site.tier >= 0 then
					dressBuild(site)
				end
			end
		end
	end
	animateBuild = function(site: any)
		if fx and fx.build then
			local ok = pcall(fx.build, site, partsOf(site.build), site.owner)
			if ok then
				return
			end
		end
		animate(site, partsOf(site.build), site.owner)
	end
	-- покупка украшения
	local function buyDecor(site: any, player: Player, id: string)
		local session = sessions[player]
		local root = ctx.getAlive(player)
		if not session or not root or site.owner ~= player or (root.Position - site.board.Position).Magnitude > MENU_REACH + 4 then
			return
		end
		if not session.canSave and ctx.saveBroken() then
			ctx.toast(player, "no_save")
			ctx.sound(player, "deny")
			return
		end
		local entry: any = nil
		for _, e in ipairs(decorOf(site)) do
			if e.id == id then
				entry = e
			end
		end
		local ext = sv.stock(session)
		if not entry or hasDecor(ext, id) then
			return
		end
		if entry.open and not entry.open() then
			return
		end
		local house = site.kind == "house"
		local cur: string? = entry.cur
		local have: number = if cur then (ext.items[cur] or 0) elseif house then ext.mats else ext.bio
		if have < entry.cost then
			ctx.toast(player, if cur then entry.need elseif house then "hm_need_parts" else "hm_need_brains", entry.cost - have)
			ctx.sound(player, "deny")
			return
		end
		if cur then
			local raw: any = ext.items
			raw[cur] = if have - entry.cost > 0 then have - entry.cost else nil
		elseif house then
			ext.mats -= entry.cost
		else
			ext.bio -= entry.cost
		end
		ext.items["d_" .. id] = 1
		decorate(site)
		dressBuild(site)
		local folder = site.model:FindFirstChild("Decor")
		if folder then
			-- анимируются только части нового украшения: они стоят последними в модели
			local fresh = {}
			local all = partsOf(folder)
			for _, part in ipairs(all) do
				table.insert(fresh, part)
			end
			animate(site, fresh, player)
		end
		ctx.toast(player, "bd_built", ctx.tr(player, "bd_" .. id))
		ctx.sound(player, "buy")
	end

	-- МЕНЮ НА ЭКРАНЕ: строится сервером в PlayerGui, нажатия присылает экран (скрипт ZT_Touch) через ZT_Build
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ZT_Build"
	remote.Parent = game:GetService("ReplicatedStorage")
	local menuOf: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any -- { gui, site, rows }
	local DARK_PLATE = Color3.fromRGB(18, 22, 30)
	local function makeMenu(player: Player, site: any): any
		local gui = Instance.new("ScreenGui")
		gui.Name = "ZT_BuildMenu"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 20
		gui.IgnoreGuiInset = true
		local house = site.kind == "house"
		local frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.AnchorPoint = Vector2.new(1, 0.5)
		frame.Position = UDim2.new(1, -16, 0.5, 0)
		frame.Size = UDim2.new(0, 340, 0, 430)
		frame.BackgroundColor3 = DARK_PLATE
		frame.BackgroundTransparency = 0.12
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = if house then WARM else SLIME
		stroke.Thickness = 2
		stroke.Transparency = 0.4
		stroke.Parent = frame
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -214, 0, 40)
		title.Position = UDim2.new(0, 14, 0, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Text = ctx.tr(player, "bd_title")
		title.Parent = frame
		local wallet = Instance.new("TextLabel")
		wallet.Name = "Wallet"
		wallet.Size = UDim2.new(0, 150, 0, 30)
		wallet.Position = UDim2.new(1, -194, 0, 11)
		wallet.BackgroundTransparency = 1
		wallet.Font = Enum.Font.GothamBold
		wallet.TextScaled = true
		wallet.TextXAlignment = Enum.TextXAlignment.Right
		wallet.TextColor3 = Color3.fromRGB(255, 225, 120)
		wallet.Text = ""
		wallet.Parent = frame
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Size = UDim2.new(0, 30, 0, 30)
		close.Position = UDim2.new(1, -40, 0, 8)
		close.BackgroundColor3 = Color3.fromRGB(60, 64, 76)
		close.Text = "X"
		close.TextScaled = true
		close.Font = Enum.Font.GothamBold
		close.TextColor3 = Color3.fromRGB(255, 255, 255)
		close.Parent = frame
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = close
		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.Position = UDim2.new(0, 10, 0, 52)
		list.Size = UDim2.new(1, -20, 1, -62)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		local rows: { [string]: any } = {}
		local order = 0
		local function header(text: string)
			order += 1
			local h = Instance.new("TextLabel")
			h.Size = UDim2.new(1, 0, 0, 22)
			h.BackgroundTransparency = 1
			h.Font = Enum.Font.GothamBold
			h.TextScaled = true
			h.TextXAlignment = Enum.TextXAlignment.Left
			h.TextColor3 = Color3.fromRGB(170, 180, 200)
			h.Text = text
			h.LayoutOrder = order
			h.Parent = list
		end
		local function row(id: string, icon: string)
			order += 1
			local r = Instance.new("Frame")
			r.Name = "Row_" .. id
			r.Size = UDim2.new(1, 0, 0, 58)
			r.BackgroundColor3 = Color3.fromRGB(34, 40, 52)
			r.BorderSizePixel = 0
			r.LayoutOrder = order
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 10)
			rc.Parent = r
			local ic = Instance.new("TextLabel")
			ic.Size = UDim2.new(0, 44, 1, 0)
			ic.BackgroundTransparency = 1
			ic.TextScaled = true
			ic.Text = icon
			ic.Parent = r
			local name = Instance.new("TextLabel")
			name.Name = "Name"
			name.Position = UDim2.new(0, 46, 0, 6)
			name.Size = UDim2.new(1, -150, 0, 22)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.GothamBold
			name.TextScaled = true
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.Parent = r
			local info = Instance.new("TextLabel")
			info.Name = "Info"
			info.Position = UDim2.new(0, 46, 0, 30)
			info.Size = UDim2.new(1, -150, 0, 20)
			info.BackgroundTransparency = 1
			info.Font = Enum.Font.Gotham
			info.TextScaled = true
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.TextColor3 = Color3.fromRGB(190, 200, 215)
			info.Parent = r
			local button = Instance.new("TextButton")
			button.Name = "Buy_" .. id
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -8, 0.5, 0)
			button.Size = UDim2.new(0, 96, 0, 44)
			button.BackgroundColor3 = Color3.fromRGB(70, 190, 90)
			button.Font = Enum.Font.GothamBold
			button.TextScaled = true
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			button.Text = ""
			button.AutoButtonColor = true
			button.Parent = r
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 10)
			bc.Parent = button
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 6)
			pad.PaddingTop = UDim.new(0, 8)
			pad.PaddingBottom = UDim.new(0, 8)
			pad.Parent = button
			r.Parent = list
			rows[id] = { frame = r, name = name, info = info, button = button }
		end
		header(ctx.tr(player, "bd_next"))
		row("tier", if house then "🏠" else "🧟")
		header(ctx.tr(player, "bd_decor"))
		local icons = { fence = "🏡", lamp = "💡", garden = "🌱", flag = "🚩", bench = "🛋", well = "💧", bones = "🦴", mush = "🍄", totem = "🗿" } -- только значки, которые есть в шрифтах Roblox
		local mine = sessions[player]
		local ext0 = if mine then sv.stock(mine) else nil
		local headed = false
		for _, entry in ipairs(decorOf(site)) do
			-- товары ивентов (модуль Halloween): свой заголовок, значок и валюта; после ивента видны только купленные
			if not entry.shown or entry.shown(ext0) then
				if entry.head and not headed then
					headed = true
					header(entry.head(player))
				end
				row(entry.id, entry.icon or icons[entry.id] or "✨")
			end
		end
		gui.Parent = player:FindFirstChild("PlayerGui")
		return { gui = gui, site = site, rows = rows, wallet = wallet }
	end
	local function fillMenu(player: Player, menu: any)
		local site = menu.site
		local session = sessions[player]
		if not session then
			return
		end
		local ext = sv.stock(session)
		local house = site.kind == "house"
		local have: number = if house then ext.mats else ext.bio
		local icon = if house then "🔩" else "🧠"
		menu.wallet.Text = icon .. " " .. have
		for _, entry in ipairs(decorOf(site)) do
			if entry.cur and menu.rows[entry.id] then
				menu.wallet.Text = icon .. " " .. have .. "   " .. (entry.icon or "") .. " " .. (ext.items[entry.cur] or 0)
				break
			end
		end
		local function paint(r: any, name: string, info: string, cost: number?, owned: boolean, have2: number?, icon2: string?)
			local have, icon = have2 or have, icon2 or icon
			r.name.Text = name
			r.info.Text = info
			local b: TextButton = r.button
			if owned then
				b.Text = ctx.tr(player, "bd_have")
				b.BackgroundColor3 = Color3.fromRGB(70, 80, 96)
				b.Active = false
			elseif cost and have >= cost then
				b.Text = ctx.tr(player, "bd_build") .. "\n" .. cost .. " " .. icon
				b.BackgroundColor3 = Color3.fromRGB(70, 190, 90)
				b.Active = true
			elseif cost then
				b.Text = ctx.tr(player, "bd_need", cost - have) .. "\n" .. cost .. " " .. icon
				b.BackgroundColor3 = Color3.fromRGB(150, 70, 70)
				b.Active = true
			end
		end
		local tier: number = if house then ext.house else ext.nest
		local prefix = if house then "bd_t" else "bd_n"
		if tier >= 3 then
			paint(menu.rows.tier, ctx.tr(player, prefix .. "3"), ctx.tr(player, "hm_max"), nil, true)
		else
			local cost = if house then HOUSE_COST[tier + 1] else NEST_COST[tier + 1]
			paint(menu.rows.tier, ctx.tr(player, prefix .. (tier + 1)), ctx.tr(player, prefix .. (tier + 1) .. "b"), cost, false)
		end
		for _, entry in ipairs(decorOf(site)) do
			local r = menu.rows[entry.id]
			if r then
				local cur = entry.cur
				paint(r, ctx.tr(player, "bd_" .. entry.id), ctx.tr(player, "bd_" .. entry.id .. "b"), entry.cost, hasDecor(ext, entry.id), if cur then (ext.items[cur] or 0) else nil, if cur then entry.icon else nil)
			end
		end
	end
	local closedAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- кто закрыл меню крестиком: не открывать, пока не отойдёт
	local function openMenu(player: Player, site: any)
		local menu = menuOf[player]
		if menu and menu.site ~= site then
			menu.gui:Destroy()
			menu = nil
		end
		if not menu or menu.gui.Parent == nil then
			menu = makeMenu(player, site)
			menuOf[player] = menu
		end
		fillMenu(player, menu)
	end
	local function closeMenu(player: Player)
		local menu = menuOf[player]
		if menu then
			menuOf[player] = nil
			menu.gui:Destroy()
		end
	end
	-- какая доска рядом с хозяином (своя), если никакой - nil
	local function boardNear(player: Player): any
		local index = plotOf[player]
		local root = ctx.getAlive(player)
		if not index or not root or inRound[player] then
			return nil
		end
		for _, site in ipairs({ houses[index], nests[index] }) do
			if (root.Position - site.board.Position).Magnitude <= MENU_REACH then
				return site
			end
		end
		return nil
	end
	remote.OnServerEvent:Connect(function(player: Player, id: any)
		safely("build_menu", function()
			if type(id) ~= "string" then
				return
			end
			local site = boardNear(player)
			if not site then
				return
			end
			if id == "close" then
				closedAt[player] = os.clock()
				closeMenu(player)
			elseif id == "tier" then
				upgrade(site, player)
			else
				buyDecor(site, player, id)
			end
			local menu = menuOf[player]
			if menu then
				fillMenu(player, menu)
			end
		end)
	end)
	-- раз в полсекунды: меню открывается у своей доски и закрывается, когда хозяин отошёл
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				safely("menu_tick", function()
					local site = boardNear(player)
					if site then
						local shut = closedAt[player]
						if not shut then
							openMenu(player, site)
						end
					else
						closedAt[player] = nil
						if menuOf[player] then
							closeMenu(player)
						end
					end
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		menuOf[player] = nil
	end)
	-- стартовый набор: при первом участке новичок сразу может что-то построить
	local function starterKit(player: Player)
		local session = sessions[player]
		if not session or (not session.canSave and ctx.saveBroken()) then
			return
		end
		local ext = sv.stock(session)
		if (ext.items.start or 0) > 0 or ext.house > 0 then
			return
		end
		ext.items.start = 1
		ext.mats = math.min(9999, ext.mats + START_PARTS)
		ctx.toast(player, "bd_start", START_PARTS)
		ctx.sound(player, "coin")
	end
	-- утро: грядки кормят, тотем приносит мозг
	local function morningGifts(player: Player)
		local session = sessions[player]
		if not session then
			return
		end
		local ext = sv.stock(session)
		local food = (if hasDecor(ext, "garden") then 1 else 0) + (if hasDecor(ext, "garden") and hasDecor(ext, "well") then 1 else 0)
		if food > 0 and ext.food < 99 then
			ext.food = math.min(99, ext.food + food)
			ctx.toast(player, "bd_garden_bonus", food)
		end
		if hasDecor(ext, "totem") and ext.bio < 99999 then
			ext.bio += 1
			ctx.toast(player, "bd_totem_bonus")
		end
	end
	-- участок игрока: выдаётся при первой надобности; на свободных участках живут соседи
	local function claim(player: Player): number?
		local index = plotOf[player]
		if index then
			return index
		end
		for _, free in ipairs(ORDER) do
			if not houses[free].owner then
				plotOf[player] = free
				houses[free].owner = player
				nests[free].owner = player
				refresh(houses[free], true)
				refresh(nests[free], true)
				starterKit(player)
				refresh(houses[free])
				return free
			end
		end
		return nil
	end
	local function release(player: Player)
		local index = plotOf[player]
		plotOf[player] = nil
		if index then
			houses[index].owner = nil
			nests[index].owner = nil
			refresh(houses[index], true)
			refresh(nests[index], true)
		end
	end
	step = function(player: Player, site: any)
		send(player, point(site, 0, 3.5, ARRIVE), site.origin, true)
	end
	-- куда: 1 - домой, 2 - в логово, 0 - в лобби. remember - запомнить как место, где игрок живёт
	-- (в лобби тоже: кто сам ушёл в лобби, после ночи просыпается там). quiet - игрока несёт сама игра, а не значок.
	local function go(player: Player, where: number, remember: boolean, ready: boolean?, quiet: boolean?)
		local session = sessions[player]
		if not session or inRound[player] then
			return
		end
		if where == 0 then
			if remember then
				sv.stock(session).home = 0
			end
			-- на синий пол магазина, лицом к витринам: ночь не забирает тех, кто стоит в магазине
			send(player, Vector3.new(0, LOBBY_Y + 4, -34), Vector3.new(0, LOBBY_Y + 4, -46))
			return
		end
		local index = claim(player)
		if not index then
			-- участков на всех не хватило: об этом говорит только значок, а не каждое утро
			if not quiet then
				ctx.toast(player, "hm_no_plot")
				ctx.sound(player, "deny")
			end
			return
		end
		local ext = sv.stock(session)
		if remember then
			ext.home = where
		end
		local site = if where == 1 then houses[index] else nests[index]
		send(player, point(site, 0, 3.5, ARRIVE), site.origin, ready)
		-- в первый раз за визит - что здесь делать
		local seen = welcomed[player] or {}
		welcomed[player] = seen
		if not seen[where] then
			seen[where] = true
			local tier: number = if where == 1 then ext.house else ext.nest
			if tier < 3 then
				ctx.toast(player, if where == 1 then "hm_home" else "hm_lair", if where == 1 then HOUSE_COST[tier + 1] else NEST_COST[tier + 1])
			end
		end
		-- и один раз за визит - что отсюда ночь заберёт не сразу
		if not seen.moon and STAY then
			seen.moon = true
			ctx.toast(player, "hm_moon")
		end
	end
	local LABELS: { { part: Part, key: string } } = {} -- значки с подписью: каждый игрок видит её на своём языке
	-- значки в лобби: где стоят и что о них сказать тому, кто подошёл
	local LOBBY_PADS = {
		{ x = -26, z = 22, key = "hm_pad1", name = "HM_PadHome", icon = "🏠", target = 1 },
		{ x = 26, z = 22, key = "hm_pad2", name = "HM_PadNest", icon = "🧟", target = 2 },
	}
	local function pad(name: string, icon: string, color: Color3, where: Vector3, target: number, parent: Instance)
		local plate = deco(name, Vector3.new(6, 0.3, 6), where, color, Enum.Material.Neon, parent)
		plate.Transparency = 0.25
		table.insert(LABELS, { part = plate, key = "hm_l" .. target })
		lamp(plate, color, 14, 1.2)
		sv.sign(plate, icon, Color3.fromRGB(255, 255, 255), 4, 4.4, 250)
		local prompt = sv.button(plate, name, PAD_HOLD, function(player: Player)
			local root = ctx.getAlive(player)
			if root and (root.Position - where).Magnitude <= REACH then
				go(player, target, true)
			end
		end)
		-- значок в лобби можно нажать, стоя на синем полу магазина (иначе ночь забирает игрока по пути к значку)
		if prompt and where.Y > LOBBY_Y - 30 then
			prompt.MaxActivationDistance = 11
		end
	end
	local HOME_COLOR, NEST_COLOR, SHOP_COLOR = Color3.fromRGB(255, 190, 90), Color3.fromRGB(110, 230, 110), Color3.fromRGB(70, 150, 255)

	---------------------------------------------------------------------
	-- СБОРКА МИРА
	---------------------------------------------------------------------
	ground()
	settlement()
	cave()
	for index = 1, #houses do
		furnish(houses[index])
		furnish(nests[index])
		refresh(houses[index], true)
		refresh(nests[index], true)
	end
	-- В лобби: домой и в логово. Слева и справа от места появления (вне зоны магазина и не перед досками
	-- на стене), под воротами: по ним издалека видно, что это вход, а не ещё одна плитка пола.
	local function gate(where: Vector3, color: Color3)
		local inward = if where.X < 0 then 0.55 else -0.55
		for _, side in ipairs({ -3.7, 3.7 }) do
			deco("HM_GatePost", Vector3.new(0.9, 9.2, 0.9), where + Vector3.new(0, 4.6, side), DARK, Enum.Material.Metal, world)
			deco("HM_GateGlow", Vector3.new(0.25, 9.2, 0.5), where + Vector3.new(inward, 4.6, side), color, Enum.Material.Neon, world)
		end
		deco("HM_GateTop", Vector3.new(1.1, 1.2, 8.5), where + Vector3.new(0, 9.6, 0), color, Enum.Material.Neon, world)
	end
	for _, spot in ipairs(LOBBY_PADS) do
		local where = Vector3.new(spot.x, LOBBY_Y + 0.66, spot.z)
		pad(spot.name, spot.icon, if spot.target == 1 then HOME_COLOR else NEST_COLOR, where, spot.target, world)
		gate(where, if spot.target == 1 then HOME_COLOR else NEST_COLOR)
	end
	-- на площади посёлка: в лобби (магазин) и в логово
	pad("HM_PadShop", "🛒", SHOP_COLOR, Vector3.new(-9, GROUND + 0.2, STREET_Z - 30), 0, world)
	pad("HM_PadNest", "🧟", NEST_COLOR, Vector3.new(9, GROUND + 0.2, STREET_Z - 30), 2, world)
	-- в логове: в лобби и домой
	pad("HM_PadShop", "🛒", SHOP_COLOR, Vector3.new(-9, GROUND + 0.2, TRAIL_Z + 30), 0, world)
	pad("HM_PadHome", "🏠", HOME_COLOR, Vector3.new(9, GROUND + 0.2, TRAIL_Z + 30), 1, world)
	-- у ворот города и у выхода из логова: "в город"
	for _, z in ipairs({ EDGE + 9, -EDGE - 9 }) do
		local plate = moonPad(Vector3.new(0, GROUND + 0.2, z), world)
		table.insert(LABELS, { part = plate, key = "hm_l3" })
	end

	---------------------------------------------------------------------
	-- ПОДПИСИ К ЗНАЧКАМ. Лежат у игрока (как подписи витрин магазина), поэтому каждый читает их на своём языке.
	---------------------------------------------------------------------
	local function caption(gui: Instance, name: string, part: Instance, text: string)
		local board = Instance.new("BillboardGui")
		board.Name = name
		board.Adornee = part
		board.ResetOnSpawn = false
		board.Size = UDim2.fromScale(7.5, 1.7)
		board.StudsOffset = Vector3.new(0, 7.4, 0)
		board.MaxDistance = 90
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 0.45
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.Parent = board
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = label
		board.Parent = gui
	end
	-- (у значков "в город" на самих участках подписи нет: она закрывала бы табличку с именем хозяина;
	-- про них говорит верхняя строка экрана)
	local function captions(player: Player)
		local gui = player:FindFirstChild("PlayerGui")
		if not gui or gui:FindFirstChild("HM_Label1") then
			return
		end
		for number, info in ipairs(LABELS) do
			caption(gui, "HM_Label" .. number, info.part, ctx.tr(player, info.key))
		end
	end

	---------------------------------------------------------------------
	-- СВЯЗЬ С ИГРОЙ
	---------------------------------------------------------------------
	-- с участка и из логова игрока не уносит в лобби между ночами
	ctx.Guard.home = function(pos: Vector3): boolean
		local ok, result = pcall(inHome, pos) -- вопрос задаёт главный цикл игры: ошибка здесь не должна его останавливать
		return ok and result == true
	end
	---------------------------------------------------------------------
	-- ИГРОК САМ РЕШАЕТ, ИДТИ ЛИ В ГОРОД. Из дома и из логова ночь никого не забирает.
	-- Значок 🌙 у входа на участок - "иду в город": ближайшая ночь возьмёт игрока. Тот же значок ещё раз -
	-- "остаюсь". Решение действует на одну ночь: вернувшись домой, игрок снова решает сам.
	-- Самый первый раунд играют все (как и в магазине): иначе новичок, который сразу зашёл домой,
	-- так и не увидел бы игру.
	---------------------------------------------------------------------
	local going: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- кто попросился в город
	local function atHome(player: Player): boolean
		local root = ctx.getAlive(player)
		return root ~= nil and not inRound[player] and inHome(root.Position)
	end
	-- остаётся ли игрок дома, когда начинается ночь
	local function stays(player: Player): boolean
		if not STAY or going[player] or inRound[player] then
			return false
		end
		local session = sessions[player]
		if not session or session.profile.rounds < 1 then
			return false
		end
		-- утром игрока сначала ставят в лобби и через мгновение несут домой: он уже считается тем, кто дома
		local carried = homing[player]
		return atHome(player) or (carried ~= nil and os.clock() - carried < 3)
	end
	ctx.Guard.stay = function(player: Player): boolean
		local ok, result = pcall(stays, player) -- вопрос задаёт главный цикл игры: ошибка здесь не должна его останавливать
		return ok and result == true
	end
	-- значок 🌙: "иду в город"; ещё раз - "остаюсь дома"
	ready = function(player: Player, where: Vector3)
		local root = ctx.getAlive(player)
		if not root or (root.Position - where).Magnitude > REACH or not atHome(player) then
			return
		end
		if going[player] then
			going[player] = nil
			ctx.toast(player, "hm_wait")
			ctx.sound(player, "tick")
		else
			going[player] = true
			local night: boolean = ctx.state()
			ctx.toast(player, if night then "hm_go2" else "hm_go")
			ctx.sound(player, "start")
		end
	end
	-- Кто-то попросился в город, а все остальные остаются дома или стоят в магазине (их ночь не берёт):
	-- ждать некого, отсчёт до ночи не нужен
	local oldEager = ctx.Guard.eager
	ctx.Guard.eager = function(all: boolean?): boolean
		if not all then
			local ok, everyone = pcall(function(): boolean
				local any = false
				for _, player in ipairs(Players:GetPlayers()) do
					local session = sessions[player]
					if not session then
						return false
					end
					if going[player] then
						any = true
					elseif not stays(player) then
						local root = ctx.getAlive(player)
						if not (root and session.profile.rounds > 0 and ctx.inShopZone(root.Position)) then
							return false
						end
					end
				end
				return any
			end)
			if ok and everyone then
				return true
			end
		end
		return oldEager(all)
	end
	-- день длиннее для всех, если так задано в настройках (DAY_EXTRA) и на сервере кто-то живёт в доме или логове
	ctx.Guard.day = function(_pause: number): number
		local extra = 0
		safely("day", function()
			if DAY_EXTRA > 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					local session = sessions[player]
					if session and sv.stock(session).home > 0 then
						extra = DAY_EXTRA
						break
					end
				end
			end
		end)
		return extra
	end
	-- Игра несёт игрока в лобби (утро, вертолёт, уборка города). Кто живёт в доме или логове,
	-- сразу после этого оказывается у себя. К витринам (первая покупка новичка) это не относится.
	local oldAllow = ctx.Guard.allow
	ctx.Guard.allow = function(player: Player, target: Vector3?)
		oldAllow(player, target)
		-- (-30, +4, -18) - место у витрин, куда игра ставит новичка без покупок
		if not target or moving[player] or target.Y < LOBBY_Y - 30 or ctx.inShopZone(target)
			or (target - Vector3.new(-30, LOBBY_Y + 4, -18)).Magnitude < 4 then
			return
		end
		safely("return", function()
			local session = sessions[player]
			local where: number = if session then sv.stock(session).home else 0
			-- новичка без покупок игра ведёт к витринам за первым следом (и после вертолёта тоже): домой его не уносит
			if where > 0 and session and ctx.RULES.gifts and session.profile.rounds < 3 and next(session.profile.owned) == nil then
				where = 0
			end
			if where > 0 and plotOf[player] then
				homing[player] = os.clock()
				-- дом считается подгруженным, только если его подгружали этим утром (после вертолёта и уборки города - нет)
				local warm = os.clock() - (warmed[player] or -100) < 15
				-- на следующем шаге: к этому времени игра уже поставила игрока в лобби
				task.delay(0, function()
					safely("return", function()
						if not inRound[player] then
							go(player, where, false, warm, true)
						end
					end)
				end)
			elseif where > 0 then
				-- участка на этом сервере не досталось: нести некуда (значок скажет об этом, если игрок попросит)
				homing[player] = nil
			end
		end)
	end
	-- дом добавляет места в рюкзаке, логово - мозги за пойманного игрока
	sv.hooks.packBonus = function(player: Player): number
		local session = sessions[player]
		return if session then HOUSE_PACK[sv.stock(session).house + 1] else 0
	end
	sv.hooks.catchBonus = function(player: Player): number
		local session = sessions[player]
		return if session then NEST_BRAINS[sv.stock(session).nest + 1] else 0
	end
	-- строка запасов днём: ступени дома и логова и сколько не хватает до следующей
	-- Дома строка короче: только дом, детали и еда; в логове - только логово и мозги. 🌙 ✔ - игрок идёт в город.
	sv.hooks.dayRow = function(player: Player, _session: any, ext: any): string
		local house, nest = ext.house, ext.nest
		local parts = "🔩 " .. ext.mats .. (if house < 3 then "/" .. HOUSE_COST[house + 1] else "")
		local brains = "🧠 " .. ext.bio .. (if nest < 3 then "/" .. NEST_COST[nest + 1] else "")
		local root = ctx.getAlive(player)
		if root and STAY and atHome(player) then
			local moon = if going[player] then "    🌙 ✔" else ""
			if root.Position.Z > 0 then
				return "🏠 " .. stars(house) .. "    " .. parts .. "    🍞 " .. ext.food .. "    💉 " .. ext.vac .. moon
			end
			return "🧟 " .. stars(nest) .. "    " .. brains .. moon
		end
		return "🏠 " .. stars(house) .. "    🍞 " .. ext.food .. "    " .. parts
			.. "    💉 " .. ext.vac .. "    🧟 " .. stars(nest) .. "    " .. brains
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		safely("leave", function()
			release(player)
		end)
	end)
	local wasNight = false
	local padTold: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any  -- кому про какой значок в лобби уже сказано
	local lastText: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any -- верхняя строка экрана: что в ней было
	local lastMine: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any -- и что написал туда этот модуль
	local gameWrote: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- когда её в последний раз меняла игра
	local hooked: { [Player]: TextLabel } = setmetatable({}, { __mode = "k" }) :: any -- за чьей строкой модуль уже следит
	local instant: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- и у кого может поправить её сразу
	local resultUntil = 0 -- до этого времени в верхней строке итог ночи: его модуль не трогает
	-- Что написать в верхней строке тому, кто остаётся дома (nil - строку ведёт игра).
	-- Днём игра пишет туда отсчёт до ночи для тех, кто в лобби; того, кто дома, этот отсчёт не касается.
	local function statusFor(player: Player): string?
		if os.clock() < resultUntil then
			return nil
		end
		if stays(player) then
			return ctx.tr(player, "hm_status") -- днём и ночью: дома ночь не забирает, в город - по значку 🌙
		end
		local night: boolean = ctx.state()
		if night and going[player] and atHome(player) then
			return ctx.tr(player, "hm_go2") -- попросился в город, но ночь уже идёт: заберёт следующая
		end
		return nil
	end
	-- решение идти в город действует, пока игрок дома: ушёл (в ночь или в лобби) - в следующий раз решает заново
	local function homeTick(player: Player, morning: boolean)
		local now = os.clock()
		if morning then
			resultUntil = now + 6
		end
		if not atHome(player) then
			going[player] = nil
		end
		local hud: any = ctx.huds[player]
		local label: TextLabel? = if hud then hud.status else nil
		if not label then
			return
		end
		if hooked[player] ~= label then
			-- где можно, строка поправляется в тот же миг, как её изменила игра (иначе она мигала бы раз в секунду)
			hooked[player] = label
			local watched: TextLabel = label
			instant[player] = pcall(function()
				watched:GetPropertyChangedSignal("Text"):Connect(function()
					safely("status", function()
						if watched.Text ~= lastMine[player] then
							local line = statusFor(player)
							if line then
								lastMine[player] = line
								lastText[player] = line
								watched.Text = line
							end
						end
					end)
				end)
			end)
		end
		local text = label.Text
		if text ~= lastText[player] then
			lastText[player] = text
			if text ~= lastMine[player] then
				gameWrote[player] = now
			end
		end
		local line = statusFor(player)
		if line and text ~= line and (instant[player] or now - (gameWrote[player] or 0) >= 2) then
			lastMine[player] = line
			lastText[player] = line
			label.Text = line
		end
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local night: boolean = ctx.state()
			local morning = wasNight and not night
			wasNight = night
			for _, player in ipairs(Players:GetPlayers()) do
				-- у каждого игрока своя защита: ошибка у одного не оставляет без участка остальных
				safely("plots", function()
					local session = sessions[player]
					if session then
						local index = claim(player)
						captions(player)
						-- утро: пока на экране итоги ночи, дом игрока уже подгружается
						local lives: number = sv.stock(session).home
						if morning and index and lives > 0 then
							local site = if lives == 1 then houses[index] else nests[index]
							task.spawn(function()
								preload(player, site.origin)
								warmed[player] = os.clock()
							end)
						end
						if index then
							-- ступень могла измениться вне стройки (прогресс загрузился позже)
							if tierOf(houses[index]) ~= houses[index].tier then
								refresh(houses[index])
							end
							if tierOf(nests[index]) ~= nests[index].tier then
								refresh(nests[index])
							end
							-- на доске стройки - сколько деталей и мозгов уже собрано
							for _, site in ipairs({ houses[index], nests[index] }) do
								local price = priceOf(site)
								if site.cost.Text ~= price then
									site.cost.Text = price
								end
							end
							local menu = menuOf[player]
							if menu then
								fillMenu(player, menu)
							end
						end
						if morning and index then
							morningGifts(player)
						end
						homeTick(player, morning)
						-- у кого появились детали или мозги, а дома он ещё не видел, тому подсказка в лобби.
						-- Новичку - только когда игра уже не ведёт его к витринам за первой покупкой.
						local ext = sv.stock(session)
						local root = ctx.getAlive(player)
						local profile = session.profile
						local shopping = profile.rounds < 4 and next(profile.owned) == nil
						if not hinted[player] and not shopping and ext.home == 0 and ext.mats + ext.bio > 0 and root and root.Position.Y > LOBBY_Y - 30 and not inRound[player] then
							hinted[player] = true
							ctx.toast(player, "hm_hint")
						end
						-- кто подошёл к значку в лобби, тому один раз за визит сказано, что это за значок
						if root and not shopping and not inRound[player] and root.Position.Y > LOBBY_Y - 30 then
							local told = padTold[player] or {}
							padTold[player] = told
							for _, spot in ipairs(LOBBY_PADS) do
								local dx, dz = root.Position.X - spot.x, root.Position.Z - spot.z
								if not told[spot.key] and dx * dx + dz * dz < 144 then
									told[spot.key] = true
									ctx.toast(player, spot.key)
								end
							end
						end
					end
				end)
			end
		end
	end)

	-- команды проверок в Studio (через дверь модуля Survival)
	sv.hooks.debug = function(player: Player, command: string, a: any, b: any): string?
		local session = sessions[player]
		if not session then
			return nil
		end
		local ext = sv.stock(session)
		if command == "home" then
			go(player, 1, true)
		elseif command == "nest" then
			go(player, 2, true)
		elseif command == "lobby" then
			go(player, 0, false)
		elseif command == "moon" then -- как значок "в город"
			local root = ctx.getAlive(player)
			if root then
				ready(player, root.Position)
			end
		elseif command == "tier" then
			ext.house, ext.nest = sv.count(a, 3), sv.count(b, 3)
		elseif command == "sample" then -- на всех участках дома и логова одной ступени: посмотреть, как выглядят
			for index = 1, #houses do
				NEIGHBOURS[index] = sv.count(a, 3)
				refresh(houses[index], true)
				refresh(nests[index], true)
			end
		else
			return nil
		end
		return "plot " .. tostring(plotOf[player]) .. " house " .. ext.house .. " nest " .. ext.nest .. " home " .. ext.home
			.. " going " .. tostring(going[player] == true)
	end

	local api = {
		houses = houses, nests = nests, plotOf = plotOf, go = go, inHome = inHome, refresh = refresh, world = world,
		ready = ready, going = going, stays = stays, buy = buyDecor, menus = menuOf, decor = DECOR, nestDecor = NEST_DECOR,
		kit = { solid = solid, deco = deco, slope = slope, at = at, point = point, lamp = lamp }, decorate = decorate,
	}
	sv.homes = api
	return api
end
