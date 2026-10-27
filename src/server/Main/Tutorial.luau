--!strict
--[[
	ОБУЧЕНИЕ (модуль Tutorial)

	КУДА ВСТАВИТЬ: это ModuleScript с именем Tutorial. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Tutorial, рядом с Extras). Запускает его модуль Extras.
	Карточки и книгу рисует LocalScript ZT_Guide (StarterPlayer -> StarterPlayerScripts).

	Что здесь:
	- подсказка «в нужный момент»: когда игрок впервые видит механику (лестницу, люк, ящик, вертолёт,
	  колесо, магазин...), сбоку появляется карточка с коротким объяснением. Каждая тема — один раз;
	  что игрок уже видел, хранится в его сохранении (ext.items["tu_<тема>"]);
	- между карточками не меньше GAP секунд, во время интро карточек нет;
	- книга «Как играть» (кнопка ❓ под кошельком): все темы с объяснениями, отметки «изучено»;
	- кто изучил все темы, получает REWARD монет (один раз).
]]

local GAP = 16          -- не чаще одной карточки за столько секунд
local REWARD = 150      -- монет за все изученные темы
local PENDING_FOR = 25  -- столько секунд отложенная карточка ещё уместна

-- темы: значок, где показывать ("round" - в раунде, "lobby" - в лобби) и для кого ("s" выживший, "z" зомби, nil - все)
local TOPICS: { { key: string, icon: string } } = {
	{ key = "survivor", icon = "🏃" }, { key = "zombie", icon = "🧟" }, { key = "dash", icon = "⚡" },
	{ key = "coins", icon = "💰" }, { key = "pickups", icon = "🛡" }, { key = "climb", icon = "🧗" },
	{ key = "manhole", icon = "🕳" }, { key = "heli", icon = "🚁" }, { key = "final", icon = "👀" },
	{ key = "crates", icon = "📦" }, { key = "hunger", icon = "🍗" }, { key = "vaccine", icon = "💉" },
	{ key = "home", icon = "🏠" }, { key = "nest", icon = "🦴" }, { key = "wheel", icon = "🎡" },
	{ key = "shop", icon = "🛒" }, { key = "codes", icon = "🎁" }, { key = "quests", icon = "📋" },
	{ key = "pumpkins", icon = "🎃" },
}
local UI_KEYS = { "tu_btn", "tu_title", "tu_ok", "tu_count", "tu_goal", "tu_new" }

local TEXT: { [string]: { [string]: string } } = {
	en = {
		tu_btn = "❓ HOW TO PLAY",
		tu_title = "📚 HOW TO PLAY",
		tu_ok = "Got it!",
		tu_count = "Learned: %d/%d",
		tu_reward = "📚 You learned everything! +%d 💰",
		tu_goal = "Learn every topic: +%d 💰",
		tu_new = "NEW TIP",
		tu_survivor_t = "You're a SURVIVOR",
		tu_survivor_b = "Run from the glowing zombies and hide behind walls or in bushes. Survive until the timer ends to win coins.",
		tu_zombie_t = "You're a ZOMBIE",
		tu_zombie_b = "Touch survivors to infect them. Every catch gives coins and brains 🧠. Catch several in a row for a combo!",
		tu_dash_t = "Dash",
		tu_dash_b = "Press Q or tap ⚡ to dash forward. Zombies lunge instead. Then wait until the button recharges.",
		tu_coins_t = "Coins",
		tu_coins_b = "Grab the yellow coins on the streets. Spend them in the lobby shop on trails and zombie skins.",
		tu_pickups_t = "Boost and shield",
		tu_pickups_b = "The » ball gives a burst of speed. The + shield blocks one bite and stuns the zombie.",
		tu_climb_t = "Ladders and trampolines",
		tu_climb_b = "Climb the yellow ladders to the roofs. Jump on the pink trampolines to fly up high.",
		tu_manhole_t = "Manholes",
		tu_manhole_b = "Stand on a manhole and hold the button: you come out of the manhole with the same color light.",
		tu_heli_t = "Helicopter escape",
		tu_heli_b = "Near the end a helicopter lands. Reach the green light and stay there 3 seconds to escape with a bonus.",
		tu_final_t = "Final hunt",
		tu_final_b = "In the last seconds zombies see survivors glowing red through walls. Keep moving and don't get cornered!",
		tu_crates_t = "Crates",
		tu_crates_b = "Hold the button next to a crate to open it: food 🍞 and parts 🔩 go into your backpack. Survive to keep them; if you're caught you drop the bag.",
		tu_hunger_t = "Hunger",
		tu_hunger_b = "The 🍗 bar drops during the round. Below 30% you eat bread from your backpack by yourself. At 0 you are slower and zombies see you.",
		tu_vaccine_t = "Vaccine",
		tu_vaccine_b = "Open the medical cabinet to get a vaccine 💉. It saves you from one bite.",
		tu_home_t = "Your house",
		tu_home_b = "You have a plot outside the city wall. Hold the button on this sign to go there and build with parts 🔩.",
		tu_nest_t = "Zombie nest",
		tu_nest_b = "Zombies grow a nest with brains 🧠 from catches. Hold the button on this sign to visit your nest.",
		tu_wheel_t = "Wheel of luck",
		tu_wheel_b = "Spin for free every day and after every 3 rounds. Every spin wins something!",
		tu_shop_t = "Shop",
		tu_shop_b = "Buy trails and zombie skins for coins. While you stand on the blue floor, rounds skip you.",
		tu_codes_t = "Codes",
		tu_codes_b = "Enter codes at this desk for gifts. Each code works once. New codes appear in our TikTok.",
		tu_quests_t = "Daily quests",
		tu_quests_b = "Three new quests on this board every day. Complete them for coins and come back daily to grow your streak 🔥.",
		tu_pumpkins_t = "Pumpkin hunt",
		tu_pumpkins_b = "Find 🎃 on roofs and streets during rounds. Spend them on Halloween decor at your house board.",
	},
	ru = {
		tu_btn = "❓ КАК ИГРАТЬ",
		tu_title = "📚 КАК ИГРАТЬ",
		tu_ok = "Понятно!",
		tu_count = "Изучено: %d/%d",
		tu_reward = "📚 Ты изучил всё! +%d 💰",
		tu_goal = "Изучи все темы: +%d 💰",
		tu_new = "НОВАЯ ПОДСКАЗКА",
		tu_survivor_t = "Ты ВЫЖИВШИЙ",
		tu_survivor_b = "Убегай от светящихся зомби и прячься за стенами и в кустах. Продержись до конца таймера и получи монеты.",
		tu_zombie_t = "Ты ЗОМБИ",
		tu_zombie_b = "Коснись выжившего, чтобы заразить его. За каждого пойманного — монеты и мозги 🧠. Поймай нескольких подряд — будет комбо!",
		tu_dash_t = "Рывок",
		tu_dash_b = "Жми Q или ⚡, чтобы рвануть вперёд. Зомби вместо этого прыгают. Потом подожди, пока кнопка зарядится.",
		tu_coins_t = "Монеты",
		tu_coins_b = "Собирай жёлтые монеты на улицах. Трать их в магазине в лобби на следы и скины зомби.",
		tu_pickups_t = "Ускорение и щит",
		tu_pickups_b = "Шар » даёт рывок скорости. Щит + спасает от одного укуса и оглушает зомби.",
		tu_climb_t = "Лестницы и батуты",
		tu_climb_b = "Залезай по жёлтым лестницам на крыши. Прыгай на розовых батутах, чтобы взлететь высоко.",
		tu_manhole_t = "Люки",
		tu_manhole_b = "Встань на люк и зажми кнопку: вылезешь из люка с огнём того же цвета.",
		tu_heli_t = "Побег на вертолёте",
		tu_heli_b = "Под конец садится вертолёт. Добеги до зелёного света и простой там 3 секунды — сбежишь с бонусом.",
		tu_final_t = "Финальная охота",
		tu_final_b = "В последние секунды зомби видят выживших красными сквозь стены. Не стой на месте и не попадись в угол!",
		tu_crates_t = "Ящики",
		tu_crates_b = "Зажми кнопку у ящика, чтобы открыть его: еда 🍞 и детали 🔩 падают в рюкзак. Выживи, чтобы сохранить их; если поймают — рюкзак выпадет.",
		tu_hunger_t = "Голод",
		tu_hunger_b = "Полоска 🍗 падает за раунд. Ниже 30% ты сам ешь хлеб из рюкзака. На нуле бежишь медленнее, и зомби тебя видят.",
		tu_vaccine_t = "Вакцина",
		tu_vaccine_b = "Открой медицинский шкаф и получи вакцину 💉. Она спасёт от одного укуса.",
		tu_home_t = "Твой дом",
		tu_home_b = "У тебя есть участок за стеной города. Зажми кнопку на этой табличке, чтобы попасть туда и строить из деталей 🔩.",
		tu_nest_t = "Логово зомби",
		tu_nest_b = "Зомби растят логово из мозгов 🧠 за пойманных. Зажми кнопку на этой табличке, чтобы попасть в своё логово.",
		tu_wheel_t = "Колесо удачи",
		tu_wheel_b = "Крути бесплатно каждый день и после каждых 3 раундов. Каждое вращение что-то даёт!",
		tu_shop_t = "Магазин",
		tu_shop_b = "Покупай следы и скины зомби за монеты. Пока стоишь на синем полу, раунды тебя не забирают.",
		tu_codes_t = "Коды",
		tu_codes_b = "Вводи коды за этой стойкой и получай подарки. Каждый код работает один раз. Новые коды — в нашем TikTok.",
		tu_quests_t = "Задания дня",
		tu_quests_b = "Каждый день на этой доске три новых задания. Выполняй их ради монет и заходи каждый день, чтобы росла серия 🔥.",
		tu_pumpkins_t = "Охота на тыквы",
		tu_pumpkins_b = "Ищи 🎃 на крышах и улицах во время раундов. Трать их на хэллоуинский декор у доски своего дома.",
	},
	es = {
		tu_btn = "❓ CÓMO JUGAR",
		tu_title = "📚 CÓMO JUGAR",
		tu_ok = "¡Entendido!",
		tu_count = "Aprendido: %d/%d",
		tu_reward = "📚 ¡Lo aprendiste todo! +%d 💰",
		tu_goal = "Aprende todos los temas: +%d 💰",
		tu_new = "NUEVO CONSEJO",
		tu_survivor_t = "Eres SUPERVIVIENTE",
		tu_survivor_b = "Huye de los zombis brillantes y escóndete tras muros o en arbustos. Aguanta hasta que acabe el tiempo para ganar monedas.",
		tu_zombie_t = "Eres ZOMBI",
		tu_zombie_b = "Toca a los supervivientes para infectarlos. Cada captura da monedas y cerebros 🧠. ¡Atrapa a varios seguidos para hacer combo!",
		tu_dash_t = "Impulso",
		tu_dash_b = "Pulsa Q o toca ⚡ para lanzarte hacia delante. Los zombis saltan. Luego espera a que el botón se recargue.",
		tu_coins_t = "Monedas",
		tu_coins_b = "Recoge las monedas amarillas de las calles. Gástalas en la tienda del lobby en estelas y skins de zombi.",
		tu_pickups_t = "Velocidad y escudo",
		tu_pickups_b = "La bola » te da velocidad. El escudo + bloquea un mordisco y aturde al zombi.",
		tu_climb_t = "Escaleras y camas elásticas",
		tu_climb_b = "Sube por las escaleras amarillas a los tejados. Salta en las camas elásticas rosas para volar alto.",
		tu_manhole_t = "Alcantarillas",
		tu_manhole_b = "Ponte sobre una alcantarilla y mantén el botón: saldrás por la que tiene luz del mismo color.",
		tu_heli_t = "Escape en helicóptero",
		tu_heli_b = "Cerca del final aterriza un helicóptero. Llega a la luz verde y quédate 3 segundos para escapar con premio.",
		tu_final_t = "Caza final",
		tu_final_b = "En los últimos segundos los zombis ven a los supervivientes en rojo a través de las paredes. ¡Muévete y no te dejes acorralar!",
		tu_crates_t = "Cajas",
		tu_crates_b = "Mantén el botón junto a una caja para abrirla: comida 🍞 y piezas 🔩 van a tu mochila. Sobrevive para conservarlas; si te atrapan, la sueltas.",
		tu_hunger_t = "Hambre",
		tu_hunger_b = "La barra 🍗 baja durante la ronda. Por debajo del 30% comes pan de la mochila tú solo. En 0 vas más lento y los zombis te ven.",
		tu_vaccine_t = "Vacuna",
		tu_vaccine_b = "Abre el botiquín para conseguir una vacuna 💉. Te salva de un mordisco.",
		tu_home_t = "Tu casa",
		tu_home_b = "Tienes una parcela fuera de la muralla. Mantén el botón en este cartel para ir y construir con piezas 🔩.",
		tu_nest_t = "Guarida zombi",
		tu_nest_b = "Los zombis hacen crecer su guarida con cerebros 🧠 de las capturas. Mantén el botón en este cartel para visitarla.",
		tu_wheel_t = "Rueda de la suerte",
		tu_wheel_b = "Gira gratis cada día y después de cada 3 rondas. ¡Cada giro da un premio!",
		tu_shop_t = "Tienda",
		tu_shop_b = "Compra estelas y skins de zombi con monedas. Mientras estés en el suelo azul, las rondas te saltan.",
		tu_codes_t = "Códigos",
		tu_codes_b = "Escribe códigos en este mostrador y recibe regalos. Cada código sirve una vez. Los nuevos están en nuestro TikTok.",
		tu_quests_t = "Misiones diarias",
		tu_quests_b = "Tres misiones nuevas cada día en este tablero. Complétalas para ganar monedas y vuelve cada día para alargar tu racha 🔥.",
		tu_pumpkins_t = "Caza de calabazas",
		tu_pumpkins_b = "Busca 🎃 en tejados y calles durante las rondas. Gástalas en decoración de Halloween en el tablero de tu casa.",
	},
	pt = {
		tu_btn = "❓ COMO JOGAR",
		tu_title = "📚 COMO JOGAR",
		tu_ok = "Entendi!",
		tu_count = "Aprendido: %d/%d",
		tu_reward = "📚 Você aprendeu tudo! +%d 💰",
		tu_goal = "Aprenda todos os temas: +%d 💰",
		tu_new = "NOVA DICA",
		tu_survivor_t = "Você é SOBREVIVENTE",
		tu_survivor_b = "Fuja dos zumbis brilhantes e se esconda atrás de paredes ou em arbustos. Aguente até o tempo acabar para ganhar moedas.",
		tu_zombie_t = "Você é ZUMBI",
		tu_zombie_b = "Toque nos sobreviventes para infectá-los. Cada captura dá moedas e cérebros 🧠. Pegue vários seguidos para fazer combo!",
		tu_dash_t = "Impulso",
		tu_dash_b = "Aperte Q ou toque em ⚡ para avançar rápido. Zumbis dão um bote. Depois espere o botão recarregar.",
		tu_coins_t = "Moedas",
		tu_coins_b = "Pegue as moedas amarelas nas ruas. Gaste na loja do lobby em rastros e skins de zumbi.",
		tu_pickups_t = "Velocidade e escudo",
		tu_pickups_b = "A bola » dá um pico de velocidade. O escudo + bloqueia uma mordida e atordoa o zumbi.",
		tu_climb_t = "Escadas e camas elásticas",
		tu_climb_b = "Suba pelas escadas amarelas até os telhados. Pule nas camas elásticas rosa para voar alto.",
		tu_manhole_t = "Bueiros",
		tu_manhole_b = "Fique em cima de um bueiro e segure o botão: você sai pelo bueiro com luz da mesma cor.",
		tu_heli_t = "Fuga de helicóptero",
		tu_heli_b = "Perto do fim um helicóptero pousa. Chegue à luz verde e fique lá 3 segundos para fugir com bônus.",
		tu_final_t = "Caçada final",
		tu_final_b = "Nos últimos segundos os zumbis veem os sobreviventes em vermelho através das paredes. Continue se mexendo!",
		tu_crates_t = "Caixas",
		tu_crates_b = "Segure o botão perto de uma caixa para abri-la: comida 🍞 e peças 🔩 vão para a mochila. Sobreviva para guardá-las; se for pego, você deixa a mochila cair.",
		tu_hunger_t = "Fome",
		tu_hunger_b = "A barra 🍗 cai durante a rodada. Abaixo de 30% você come pão da mochila sozinho. No zero você fica lento e os zumbis te veem.",
		tu_vaccine_t = "Vacina",
		tu_vaccine_b = "Abra o armário médico para pegar uma vacina 💉. Ela salva você de uma mordida.",
		tu_home_t = "Sua casa",
		tu_home_b = "Você tem um terreno fora do muro da cidade. Segure o botão nesta placa para ir até lá e construir com peças 🔩.",
		tu_nest_t = "Toca zumbi",
		tu_nest_b = "Zumbis fazem a toca crescer com cérebros 🧠 das capturas. Segure o botão nesta placa para visitar sua toca.",
		tu_wheel_t = "Roda da sorte",
		tu_wheel_b = "Gire de graça todo dia e depois de cada 3 rodadas. Todo giro ganha algo!",
		tu_shop_t = "Loja",
		tu_shop_b = "Compre rastros e skins de zumbi com moedas. Enquanto estiver no chão azul, as rodadas pulam você.",
		tu_codes_t = "Códigos",
		tu_codes_b = "Digite códigos neste balcão e ganhe presentes. Cada código funciona uma vez. Códigos novos saem no nosso TikTok.",
		tu_quests_t = "Missões diárias",
		tu_quests_b = "Três missões novas neste quadro todo dia. Complete para ganhar moedas e volte todo dia para aumentar sua sequência 🔥.",
		tu_pumpkins_t = "Caça às abóboras",
		tu_pumpkins_b = "Encontre 🎃 nos telhados e ruas durante as rodadas. Gaste em decoração de Halloween no quadro da sua casa.",
	},
	fr = {
		tu_btn = "❓ COMMENT JOUER",
		tu_title = "📚 COMMENT JOUER",
		tu_ok = "Compris !",
		tu_count = "Appris : %d/%d",
		tu_reward = "📚 Tu as tout appris ! +%d 💰",
		tu_goal = "Apprends tous les sujets : +%d 💰",
		tu_new = "NOUVEAU CONSEIL",
		tu_survivor_t = "Tu es SURVIVANT",
		tu_survivor_b = "Fuis les zombies lumineux et cache-toi derrière les murs ou dans les buissons. Tiens jusqu'à la fin du chrono pour gagner des pièces.",
		tu_zombie_t = "Tu es ZOMBIE",
		tu_zombie_b = "Touche les survivants pour les infecter. Chaque capture rapporte des pièces et des cerveaux 🧠. Enchaîne-les pour un combo !",
		tu_dash_t = "Sprint",
		tu_dash_b = "Appuie sur Q ou touche ⚡ pour foncer en avant. Les zombies bondissent. Ensuite, attends que le bouton se recharge.",
		tu_coins_t = "Pièces",
		tu_coins_b = "Ramasse les pièces jaunes dans les rues. Dépense-les à la boutique du lobby en traînées et skins de zombie.",
		tu_pickups_t = "Vitesse et bouclier",
		tu_pickups_b = "La boule » donne un coup de vitesse. Le bouclier + bloque une morsure et étourdit le zombie.",
		tu_climb_t = "Échelles et trampolines",
		tu_climb_b = "Grimpe aux échelles jaunes jusqu'aux toits. Saute sur les trampolines roses pour voler très haut.",
		tu_manhole_t = "Bouches d'égout",
		tu_manhole_b = "Mets-toi sur une bouche d'égout et maintiens le bouton : tu ressors par celle qui a la lumière de la même couleur.",
		tu_heli_t = "Fuite en hélicoptère",
		tu_heli_b = "Vers la fin, un hélicoptère se pose. Atteins la lumière verte et restes-y 3 secondes pour fuir avec un bonus.",
		tu_final_t = "Chasse finale",
		tu_final_b = "Dans les dernières secondes, les zombies voient les survivants en rouge à travers les murs. Bouge sans arrêt !",
		tu_crates_t = "Caisses",
		tu_crates_b = "Maintiens le bouton près d'une caisse pour l'ouvrir : nourriture 🍞 et pièces détachées 🔩 vont dans ton sac. Survis pour les garder ; si tu es attrapé, tu lâches le sac.",
		tu_hunger_t = "Faim",
		tu_hunger_b = "La barre 🍗 baisse pendant la manche. Sous 30 %, tu manges le pain de ton sac tout seul. À 0, tu es plus lent et les zombies te voient.",
		tu_vaccine_t = "Vaccin",
		tu_vaccine_b = "Ouvre l'armoire médicale pour obtenir un vaccin 💉. Il te sauve d'une morsure.",
		tu_home_t = "Ta maison",
		tu_home_b = "Tu as un terrain derrière le mur de la ville. Maintiens le bouton sur ce panneau pour y aller et construire avec des pièces 🔩.",
		tu_nest_t = "Repaire zombie",
		tu_nest_b = "Les zombies agrandissent leur repaire avec les cerveaux 🧠 des captures. Maintiens le bouton sur ce panneau pour le visiter.",
		tu_wheel_t = "Roue de la chance",
		tu_wheel_b = "Tourne gratuitement chaque jour et après chaque série de 3 manches. Chaque tour fait gagner quelque chose !",
		tu_shop_t = "Boutique",
		tu_shop_b = "Achète des traînées et des skins de zombie avec tes pièces. Tant que tu restes sur le sol bleu, les manches te laissent tranquille.",
		tu_codes_t = "Codes",
		tu_codes_b = "Entre des codes à ce comptoir pour recevoir des cadeaux. Chaque code marche une fois. Les nouveaux sont sur notre TikTok.",
		tu_quests_t = "Quêtes du jour",
		tu_quests_b = "Trois nouvelles quêtes sur ce tableau chaque jour. Termine-les pour des pièces et reviens chaque jour pour allonger ta série 🔥.",
		tu_pumpkins_t = "Chasse aux citrouilles",
		tu_pumpkins_b = "Trouve des 🎃 sur les toits et dans les rues pendant les manches. Dépense-les en déco d'Halloween au tableau de ta maison.",
	},
	de = {
		tu_btn = "❓ SO SPIELST DU",
		tu_title = "📚 SO SPIELST DU",
		tu_ok = "Verstanden!",
		tu_count = "Gelernt: %d/%d",
		tu_reward = "📚 Du hast alles gelernt! +%d 💰",
		tu_goal = "Lerne alle Themen: +%d 💰",
		tu_new = "NEUER TIPP",
		tu_survivor_t = "Du bist ÜBERLEBENDER",
		tu_survivor_b = "Lauf vor den leuchtenden Zombies weg und versteck dich hinter Wänden oder in Büschen. Halte bis zum Ende des Timers durch und gewinne Münzen.",
		tu_zombie_t = "Du bist ZOMBIE",
		tu_zombie_b = "Berühre Überlebende, um sie zu infizieren. Jeder Fang bringt Münzen und Gehirne 🧠. Fang mehrere hintereinander für eine Kombo!",
		tu_dash_t = "Sprint",
		tu_dash_b = "Drück Q oder tippe auf ⚡, um nach vorne zu sprinten. Zombies springen stattdessen. Dann warte, bis der Knopf wieder geladen ist.",
		tu_coins_t = "Münzen",
		tu_coins_b = "Sammle die gelben Münzen auf den Straßen. Gib sie im Lobby-Shop für Spuren und Zombie-Skins aus.",
		tu_pickups_t = "Tempo und Schild",
		tu_pickups_b = "Die » Kugel gibt dir einen Tempo-Schub. Der + Schild blockt einen Biss und betäubt den Zombie.",
		tu_climb_t = "Leitern und Trampoline",
		tu_climb_b = "Klettere die gelben Leitern auf die Dächer. Spring auf die pinken Trampoline, um hoch zu fliegen.",
		tu_manhole_t = "Gullys",
		tu_manhole_b = "Stell dich auf einen Gully und halte den Knopf: Du kommst aus dem Gully mit dem gleichfarbigen Licht heraus.",
		tu_heli_t = "Flucht im Hubschrauber",
		tu_heli_b = "Gegen Ende landet ein Hubschrauber. Erreiche das grüne Licht und bleib 3 Sekunden dort, um mit Bonus zu entkommen.",
		tu_final_t = "Finale Jagd",
		tu_final_b = "In den letzten Sekunden sehen Zombies die Überlebenden rot durch die Wände. Bleib in Bewegung!",
		tu_crates_t = "Kisten",
		tu_crates_b = "Halte den Knopf an einer Kiste, um sie zu öffnen: Essen 🍞 und Teile 🔩 landen im Rucksack. Überlebe, um sie zu behalten; wirst du gefangen, verlierst du den Rucksack.",
		tu_hunger_t = "Hunger",
		tu_hunger_b = "Die 🍗 Leiste sinkt während der Runde. Unter 30 % isst du von selbst Brot aus dem Rucksack. Bei 0 bist du langsamer und Zombies sehen dich.",
		tu_vaccine_t = "Impfstoff",
		tu_vaccine_b = "Öffne den Medizinschrank und hol dir einen Impfstoff 💉. Er rettet dich vor einem Biss.",
		tu_home_t = "Dein Haus",
		tu_home_b = "Du hast ein Grundstück vor der Stadtmauer. Halte den Knopf an diesem Schild, um hinzugehen und mit Teilen 🔩 zu bauen.",
		tu_nest_t = "Zombie-Nest",
		tu_nest_b = "Zombies lassen ihr Nest mit Gehirnen 🧠 von Fängen wachsen. Halte den Knopf an diesem Schild, um dein Nest zu besuchen.",
		tu_wheel_t = "Glücksrad",
		tu_wheel_b = "Dreh jeden Tag und nach jeweils 3 Runden gratis. Jede Drehung gewinnt etwas!",
		tu_shop_t = "Shop",
		tu_shop_b = "Kauf Spuren und Zombie-Skins für Münzen. Solange du auf dem blauen Boden stehst, wirst du für Runden übersprungen.",
		tu_codes_t = "Codes",
		tu_codes_b = "Gib an diesem Schalter Codes ein und bekomme Geschenke. Jeder Code geht einmal. Neue Codes gibt's auf unserem TikTok.",
		tu_quests_t = "Tagesaufgaben",
		tu_quests_b = "Jeden Tag drei neue Aufgaben auf dieser Tafel. Erledige sie für Münzen und komm täglich wieder, damit deine Serie 🔥 wächst.",
		tu_pumpkins_t = "Kürbisjagd",
		tu_pumpkins_b = "Finde 🎃 auf Dächern und Straßen während der Runden. Gib sie an der Tafel deines Hauses für Halloween-Deko aus.",
	},
	it = {
		tu_btn = "❓ COME SI GIOCA",
		tu_title = "📚 COME SI GIOCA",
		tu_ok = "Capito!",
		tu_count = "Imparato: %d/%d",
		tu_reward = "📚 Hai imparato tutto! +%d 💰",
		tu_goal = "Impara tutti gli argomenti: +%d 💰",
		tu_new = "NUOVO CONSIGLIO",
		tu_survivor_t = "Sei un SOPRAVVISSUTO",
		tu_survivor_b = "Scappa dagli zombie luminosi e nasconditi dietro i muri o nei cespugli. Resisti fino alla fine del timer per vincere monete.",
		tu_zombie_t = "Sei uno ZOMBIE",
		tu_zombie_b = "Tocca i sopravvissuti per infettarli. Ogni cattura dà monete e cervelli 🧠. Prendine tanti di fila per una combo!",
		tu_dash_t = "Scatto",
		tu_dash_b = "Premi Q o tocca ⚡ per scattare in avanti. Gli zombie balzano. Poi aspetta che il pulsante si ricarichi.",
		tu_coins_t = "Monete",
		tu_coins_b = "Raccogli le monete gialle per strada. Spendile nel negozio della lobby per scie e skin da zombie.",
		tu_pickups_t = "Velocità e scudo",
		tu_pickups_b = "La sfera » ti dà uno scatto di velocità. Lo scudo + blocca un morso e stordisce lo zombie.",
		tu_climb_t = "Scale e trampolini",
		tu_climb_b = "Sali sulle scale gialle fino ai tetti. Salta sui trampolini rosa per volare in alto.",
		tu_manhole_t = "Tombini",
		tu_manhole_b = "Mettiti su un tombino e tieni premuto il pulsante: esci dal tombino con la luce dello stesso colore.",
		tu_heli_t = "Fuga in elicottero",
		tu_heli_b = "Verso la fine atterra un elicottero. Raggiungi la luce verde e restaci 3 secondi per fuggire con un bonus.",
		tu_final_t = "Caccia finale",
		tu_final_b = "Negli ultimi secondi gli zombie vedono i sopravvissuti rossi attraverso i muri. Continua a muoverti!",
		tu_crates_t = "Casse",
		tu_crates_b = "Tieni premuto il pulsante vicino a una cassa per aprirla: cibo 🍞 e pezzi 🔩 finiscono nello zaino. Sopravvivi per tenerli; se ti prendono, perdi lo zaino.",
		tu_hunger_t = "Fame",
		tu_hunger_b = "La barra 🍗 cala durante il round. Sotto il 30% mangi da solo il pane dello zaino. A 0 sei più lento e gli zombie ti vedono.",
		tu_vaccine_t = "Vaccino",
		tu_vaccine_b = "Apri l'armadietto medico per prendere un vaccino 💉. Ti salva da un morso.",
		tu_home_t = "La tua casa",
		tu_home_b = "Hai un terreno fuori dalle mura della città. Tieni premuto il pulsante su questo cartello per andarci e costruire con i pezzi 🔩.",
		tu_nest_t = "Tana zombie",
		tu_nest_b = "Gli zombie fanno crescere la tana con i cervelli 🧠 delle catture. Tieni premuto il pulsante su questo cartello per visitarla.",
		tu_wheel_t = "Ruota della fortuna",
		tu_wheel_b = "Gira gratis ogni giorno e dopo ogni 3 round. Ogni giro vince qualcosa!",
		tu_shop_t = "Negozio",
		tu_shop_b = "Compra scie e skin da zombie con le monete. Finché stai sul pavimento blu, i round ti saltano.",
		tu_codes_t = "Codici",
		tu_codes_b = "Inserisci i codici a questo bancone per avere regali. Ogni codice vale una volta. I nuovi codici sono sul nostro TikTok.",
		tu_quests_t = "Missioni del giorno",
		tu_quests_b = "Tre nuove missioni ogni giorno su questa bacheca. Completale per avere monete e torna ogni giorno per allungare la serie 🔥.",
		tu_pumpkins_t = "Caccia alle zucche",
		tu_pumpkins_b = "Trova le 🎃 su tetti e strade durante i round. Spendile in decorazioni di Halloween alla bacheca di casa tua.",
	},
	pl = {
		tu_btn = "❓ JAK GRAĆ",
		tu_title = "📚 JAK GRAĆ",
		tu_ok = "Jasne!",
		tu_count = "Poznane: %d/%d",
		tu_reward = "📚 Poznałeś wszystko! +%d 💰",
		tu_goal = "Poznaj wszystkie tematy: +%d 💰",
		tu_new = "NOWA WSKAZÓWKA",
		tu_survivor_t = "Jesteś OCALAŁYM",
		tu_survivor_b = "Uciekaj przed świecącymi zombie i chowaj się za ścianami lub w krzakach. Przetrwaj do końca czasu, aby zdobyć monety.",
		tu_zombie_t = "Jesteś ZOMBIE",
		tu_zombie_b = "Dotknij ocalałych, aby ich zarazić. Każde złapanie daje monety i mózgi 🧠. Złap kilku z rzędu, żeby zrobić kombo!",
		tu_dash_t = "Zryw",
		tu_dash_b = "Wciśnij Q albo dotknij ⚡, aby wystrzelić do przodu. Zombie skaczą. Potem poczekaj, aż przycisk się naładuje.",
		tu_coins_t = "Monety",
		tu_coins_b = "Zbieraj żółte monety na ulicach. Wydawaj je w sklepie w lobby na smugi i skórki zombie.",
		tu_pickups_t = "Przyspieszenie i tarcza",
		tu_pickups_b = "Kula » daje zastrzyk szybkości. Tarcza + blokuje jedno ugryzienie i ogłusza zombie.",
		tu_climb_t = "Drabiny i trampoliny",
		tu_climb_b = "Wspinaj się po żółtych drabinach na dachy. Skacz na różowych trampolinach, żeby wylecieć wysoko.",
		tu_manhole_t = "Włazy",
		tu_manhole_b = "Stań na włazie i przytrzymaj przycisk: wyjdziesz z włazu ze światłem tego samego koloru.",
		tu_heli_t = "Ucieczka helikopterem",
		tu_heli_b = "Pod koniec ląduje helikopter. Dobiegnij do zielonego światła i postój tam 3 sekundy, aby uciec z bonusem.",
		tu_final_t = "Ostatnie polowanie",
		tu_final_b = "W ostatnich sekundach zombie widzą ocalałych na czerwono przez ściany. Nie stój w miejscu!",
		tu_crates_t = "Skrzynie",
		tu_crates_b = "Przytrzymaj przycisk przy skrzyni, aby ją otworzyć: jedzenie 🍞 i części 🔩 trafiają do plecaka. Przetrwaj, żeby je zatrzymać; jeśli cię złapią, upuścisz plecak.",
		tu_hunger_t = "Głód",
		tu_hunger_b = "Pasek 🍗 spada w trakcie rundy. Poniżej 30% sam jesz chleb z plecaka. Przy zerze biegasz wolniej i zombie cię widzą.",
		tu_vaccine_t = "Szczepionka",
		tu_vaccine_b = "Otwórz szafkę medyczną, aby zdobyć szczepionkę 💉. Ratuje przed jednym ugryzieniem.",
		tu_home_t = "Twój dom",
		tu_home_b = "Masz działkę za murem miasta. Przytrzymaj przycisk na tej tabliczce, aby tam pójść i budować z części 🔩.",
		tu_nest_t = "Legowisko zombie",
		tu_nest_b = "Zombie rozbudowują legowisko z mózgów 🧠 za złapanych. Przytrzymaj przycisk na tej tabliczce, aby je odwiedzić.",
		tu_wheel_t = "Koło fortuny",
		tu_wheel_b = "Kręć za darmo codziennie i po każdych 3 rundach. Każdy obrót coś daje!",
		tu_shop_t = "Sklep",
		tu_shop_b = "Kupuj smugi i skórki zombie za monety. Dopóki stoisz na niebieskiej podłodze, rundy cię pomijają.",
		tu_codes_t = "Kody",
		tu_codes_b = "Wpisuj kody przy tym stanowisku i odbieraj prezenty. Każdy kod działa raz. Nowe kody są na naszym TikToku.",
		tu_quests_t = "Zadania dnia",
		tu_quests_b = "Codziennie trzy nowe zadania na tej tablicy. Wykonuj je dla monet i wracaj codziennie, żeby rosła seria 🔥.",
		tu_pumpkins_t = "Polowanie na dynie",
		tu_pumpkins_b = "Szukaj 🎃 na dachach i ulicach podczas rund. Wydawaj je na dekoracje na Halloween przy tablicy swojego domu.",
	},
	tr = {
		tu_btn = "❓ NASIL OYNANIR",
		tu_title = "📚 NASIL OYNANIR",
		tu_ok = "Anladım!",
		tu_count = "Öğrenilen: %d/%d",
		tu_reward = "📚 Hepsini öğrendin! +%d 💰",
		tu_goal = "Tüm konuları öğren: +%d 💰",
		tu_new = "YENİ İPUCU",
		tu_survivor_t = "HAYATTA KALANSIN",
		tu_survivor_b = "Parlayan zombilerden kaç, duvarların arkasına veya çalılara saklan. Süre bitene kadar dayan ve para kazan.",
		tu_zombie_t = "ZOMBİSİN",
		tu_zombie_b = "Hayatta kalanlara dokunarak onları enfekte et. Her yakalama para ve beyin 🧠 verir. Art arda yakala, kombo yap!",
		tu_dash_t = "Atılma",
		tu_dash_b = "İleri atılmak için Q'ya bas veya ⚡'ya dokun. Zombiler bunun yerine sıçrar. Sonra düğmenin dolmasını bekle.",
		tu_coins_t = "Paralar",
		tu_coins_b = "Sokaklardaki sarı paraları topla. Lobideki dükkânda iz ve zombi görünümlerine harca.",
		tu_pickups_t = "Hız ve kalkan",
		tu_pickups_b = "» topu sana hız patlaması verir. + kalkanı bir ısırığı engeller ve zombiyi sersemletir.",
		tu_climb_t = "Merdivenler ve trambolinler",
		tu_climb_b = "Sarı merdivenlerle çatılara tırman. Yükseğe uçmak için pembe trambolinlere zıpla.",
		tu_manhole_t = "Rögarlar",
		tu_manhole_b = "Bir rögarın üstünde dur ve düğmeyi basılı tut: aynı renk ışıklı rögardan çıkarsın.",
		tu_heli_t = "Helikopterle kaçış",
		tu_heli_b = "Sona doğru bir helikopter iner. Yeşil ışığa ulaş ve orada 3 saniye kal, bonusla kaç.",
		tu_final_t = "Son av",
		tu_final_b = "Son saniyelerde zombiler hayatta kalanları duvarların arkasından kırmızı görür. Durma, hep hareket et!",
		tu_crates_t = "Sandıklar",
		tu_crates_b = "Açmak için sandığın yanında düğmeyi basılı tut: yiyecek 🍞 ve parçalar 🔩 sırt çantana girer. Saklamak için hayatta kal; yakalanırsan çantayı düşürürsün.",
		tu_hunger_t = "Açlık",
		tu_hunger_b = "🍗 çubuğu tur boyunca azalır. %30'un altında çantadaki ekmeği kendin yersin. Sıfırda yavaşlarsın ve zombiler seni görür.",
		tu_vaccine_t = "Aşı",
		tu_vaccine_b = "Aşı 💉 almak için ilaç dolabını aç. Seni bir ısırıktan kurtarır.",
		tu_home_t = "Evin",
		tu_home_b = "Şehir duvarının dışında bir arsan var. Oraya gitmek ve parçalarla 🔩 inşa etmek için bu tabelada düğmeyi basılı tut.",
		tu_nest_t = "Zombi yuvası",
		tu_nest_b = "Zombiler yuvalarını yakalamalardan gelen beyinlerle 🧠 büyütür. Yuvana gitmek için bu tabelada düğmeyi basılı tut.",
		tu_wheel_t = "Şans çarkı",
		tu_wheel_b = "Her gün ve her 3 turdan sonra bedava çevir. Her çevirme bir şey kazandırır!",
		tu_shop_t = "Dükkân",
		tu_shop_b = "Paralarla iz ve zombi görünümleri al. Mavi zeminde durduğun sürece turlar seni atlar.",
		tu_codes_t = "Kodlar",
		tu_codes_b = "Bu tezgâhta kod gir ve hediye al. Her kod bir kez çalışır. Yeni kodlar TikTok hesabımızda.",
		tu_quests_t = "Günlük görevler",
		tu_quests_b = "Bu panoda her gün üç yeni görev. Para için tamamla ve serini 🔥 büyütmek için her gün gel.",
		tu_pumpkins_t = "Balkabağı avı",
		tu_pumpkins_b = "Turlarda çatılarda ve sokaklarda 🎃 bul. Evinin panosunda Cadılar Bayramı süslerine harca.",
	},
	id = {
		tu_btn = "❓ CARA MAIN",
		tu_title = "📚 CARA MAIN",
		tu_ok = "Mengerti!",
		tu_count = "Dipelajari: %d/%d",
		tu_reward = "📚 Kamu sudah mempelajari semuanya! +%d 💰",
		tu_goal = "Pelajari semua topik: +%d 💰",
		tu_new = "TIPS BARU",
		tu_survivor_t = "Kamu PENYINTAS",
		tu_survivor_b = "Lari dari zombie yang bersinar dan sembunyi di balik dinding atau semak. Bertahan sampai waktu habis untuk dapat koin.",
		tu_zombie_t = "Kamu ZOMBIE",
		tu_zombie_b = "Sentuh penyintas untuk menginfeksi mereka. Setiap tangkapan memberi koin dan otak 🧠. Tangkap beberapa berturut-turut untuk kombo!",
		tu_dash_t = "Lesat",
		tu_dash_b = "Tekan Q atau ketuk ⚡ untuk melesat ke depan. Zombie menerkam. Lalu tunggu sampai tombolnya terisi lagi.",
		tu_coins_t = "Koin",
		tu_coins_b = "Ambil koin kuning di jalan. Belanjakan di toko lobi untuk jejak dan skin zombie.",
		tu_pickups_t = "Kecepatan dan perisai",
		tu_pickups_b = "Bola » memberi ledakan kecepatan. Perisai + menahan satu gigitan dan membuat zombie pusing.",
		tu_climb_t = "Tangga dan trampolin",
		tu_climb_b = "Panjat tangga kuning ke atap. Lompat di trampolin merah muda untuk terbang tinggi.",
		tu_manhole_t = "Lubang got",
		tu_manhole_b = "Berdiri di lubang got dan tahan tombolnya: kamu keluar dari lubang got dengan cahaya warna yang sama.",
		tu_heli_t = "Kabur dengan helikopter",
		tu_heli_b = "Menjelang akhir, helikopter mendarat. Capai cahaya hijau dan tetap di sana 3 detik untuk kabur dengan bonus.",
		tu_final_t = "Perburuan terakhir",
		tu_final_b = "Di detik-detik terakhir zombie melihat penyintas berwarna merah menembus dinding. Terus bergerak!",
		tu_crates_t = "Peti",
		tu_crates_b = "Tahan tombol di dekat peti untuk membukanya: makanan 🍞 dan suku cadang 🔩 masuk ke ransel. Bertahan agar tetap milikmu; kalau tertangkap, ranselmu jatuh.",
		tu_hunger_t = "Lapar",
		tu_hunger_b = "Bar 🍗 turun selama ronde. Di bawah 30% kamu makan roti dari ransel sendiri. Di nol kamu lebih lambat dan zombie melihatmu.",
		tu_vaccine_t = "Vaksin",
		tu_vaccine_b = "Buka lemari medis untuk dapat vaksin 💉. Vaksin menyelamatkanmu dari satu gigitan.",
		tu_home_t = "Rumahmu",
		tu_home_b = "Kamu punya lahan di luar tembok kota. Tahan tombol di papan ini untuk ke sana dan membangun dengan suku cadang 🔩.",
		tu_nest_t = "Sarang zombie",
		tu_nest_b = "Zombie membesarkan sarang dengan otak 🧠 dari tangkapan. Tahan tombol di papan ini untuk mengunjungi sarangmu.",
		tu_wheel_t = "Roda keberuntungan",
		tu_wheel_b = "Putar gratis setiap hari dan setelah setiap 3 ronde. Setiap putaran pasti dapat hadiah!",
		tu_shop_t = "Toko",
		tu_shop_b = "Beli jejak dan skin zombie dengan koin. Selama kamu berdiri di lantai biru, ronde melewatimu.",
		tu_codes_t = "Kode",
		tu_codes_b = "Masukkan kode di meja ini untuk dapat hadiah. Setiap kode berlaku sekali. Kode baru ada di TikTok kami.",
		tu_quests_t = "Misi harian",
		tu_quests_b = "Tiga misi baru di papan ini setiap hari. Selesaikan untuk koin dan datang tiap hari agar runtunanmu 🔥 bertambah.",
		tu_pumpkins_t = "Berburu labu",
		tu_pumpkins_b = "Cari 🎃 di atap dan jalan selama ronde. Belanjakan untuk dekorasi Halloween di papan rumahmu.",
	},
	vi = {
		tu_btn = "❓ CÁCH CHƠI",
		tu_title = "📚 CÁCH CHƠI",
		tu_ok = "Đã hiểu!",
		tu_count = "Đã học: %d/%d",
		tu_reward = "📚 Bạn đã học hết! +%d 💰",
		tu_goal = "Học mọi chủ đề: +%d 💰",
		tu_new = "MẸO MỚI",
		tu_survivor_t = "Bạn là NGƯỜI SỐNG SÓT",
		tu_survivor_b = "Chạy khỏi những con zombie phát sáng, nấp sau tường hoặc trong bụi cây. Trụ đến khi hết giờ để nhận xu.",
		tu_zombie_t = "Bạn là ZOMBIE",
		tu_zombie_b = "Chạm vào người sống sót để lây nhiễm. Mỗi lần bắt được xu và não 🧠. Bắt liên tiếp nhiều người để có combo!",
		tu_dash_t = "Lướt",
		tu_dash_b = "Nhấn Q hoặc chạm ⚡ để lướt về phía trước. Zombie thì vồ. Sau đó chờ nút nạp lại.",
		tu_coins_t = "Xu",
		tu_coins_b = "Nhặt xu vàng trên đường. Tiêu ở cửa hàng sảnh để mua vệt sáng và skin zombie.",
		tu_pickups_t = "Tăng tốc và khiên",
		tu_pickups_b = "Quả cầu » cho bạn tăng tốc. Khiên + chặn một cú cắn và làm zombie choáng.",
		tu_climb_t = "Thang và bạt nhún",
		tu_climb_b = "Leo thang vàng lên mái nhà. Nhảy lên bạt nhún màu hồng để bay thật cao.",
		tu_manhole_t = "Nắp cống",
		tu_manhole_b = "Đứng trên nắp cống và giữ nút: bạn chui ra ở nắp cống có ánh sáng cùng màu.",
		tu_heli_t = "Trốn bằng trực thăng",
		tu_heli_b = "Gần cuối, trực thăng hạ cánh. Đến chỗ ánh sáng xanh và đứng đó 3 giây để trốn thoát kèm thưởng.",
		tu_final_t = "Cuộc săn cuối",
		tu_final_b = "Những giây cuối, zombie thấy người sống sót màu đỏ xuyên tường. Hãy luôn di chuyển!",
		tu_crates_t = "Thùng đồ",
		tu_crates_b = "Giữ nút cạnh thùng để mở: thức ăn 🍞 và linh kiện 🔩 vào ba lô. Sống sót để giữ chúng; bị bắt thì bạn đánh rơi ba lô.",
		tu_hunger_t = "Đói",
		tu_hunger_b = "Thanh 🍗 giảm trong vòng chơi. Dưới 30% bạn tự ăn bánh mì trong ba lô. Về 0 bạn chạy chậm và zombie thấy bạn.",
		tu_vaccine_t = "Vắc xin",
		tu_vaccine_b = "Mở tủ thuốc để lấy vắc xin 💉. Nó cứu bạn khỏi một cú cắn.",
		tu_home_t = "Nhà của bạn",
		tu_home_b = "Bạn có một mảnh đất ngoài tường thành. Giữ nút ở biển này để đến đó và xây bằng linh kiện 🔩.",
		tu_nest_t = "Hang zombie",
		tu_nest_b = "Zombie nuôi lớn hang bằng não 🧠 từ những lần bắt. Giữ nút ở biển này để đến hang của bạn.",
		tu_wheel_t = "Vòng quay may mắn",
		tu_wheel_b = "Quay miễn phí mỗi ngày và sau mỗi 3 vòng chơi. Lần quay nào cũng có quà!",
		tu_shop_t = "Cửa hàng",
		tu_shop_b = "Mua vệt sáng và skin zombie bằng xu. Khi bạn đứng trên sàn xanh dương, các vòng chơi sẽ bỏ qua bạn.",
		tu_codes_t = "Mã",
		tu_codes_b = "Nhập mã ở quầy này để nhận quà. Mỗi mã dùng được một lần. Mã mới có trên TikTok của chúng tôi.",
		tu_quests_t = "Nhiệm vụ hằng ngày",
		tu_quests_b = "Mỗi ngày có ba nhiệm vụ mới trên bảng này. Hoàn thành để nhận xu và quay lại mỗi ngày để kéo dài chuỗi 🔥.",
		tu_pumpkins_t = "Săn bí ngô",
		tu_pumpkins_b = "Tìm 🎃 trên mái nhà và đường phố trong các vòng chơi. Đổi lấy đồ trang trí Halloween ở bảng nhà bạn.",
	},
	th = {
		tu_btn = "❓ วิธีเล่น",
		tu_title = "📚 วิธีเล่น",
		tu_ok = "เข้าใจแล้ว!",
		tu_count = "เรียนรู้แล้ว: %d/%d",
		tu_reward = "📚 คุณเรียนรู้ครบแล้ว! +%d 💰",
		tu_goal = "เรียนรู้ให้ครบทุกหัวข้อ: +%d 💰",
		tu_new = "เคล็ดลับใหม่",
		tu_survivor_t = "คุณคือผู้รอดชีวิต",
		tu_survivor_b = "หนีซอมบี้ที่เรืองแสง แล้วซ่อนหลังกำแพงหรือในพุ่มไม้ อยู่รอดจนหมดเวลาเพื่อรับเหรียญ",
		tu_zombie_t = "คุณคือซอมบี้",
		tu_zombie_b = "แตะผู้รอดชีวิตเพื่อแพร่เชื้อ จับได้ทุกครั้งได้เหรียญและสมอง 🧠 จับหลายคนติดกันจะได้คอมโบ!",
		tu_dash_t = "พุ่ง",
		tu_dash_b = "กด Q หรือแตะ ⚡ เพื่อพุ่งไปข้างหน้า ซอมบี้จะกระโจนแทน จากนั้นรอให้ปุ่มชาร์จใหม่",
		tu_coins_t = "เหรียญ",
		tu_coins_b = "เก็บเหรียญสีเหลืองบนถนน แล้วใช้ซื้อหางแสงและสกินซอมบี้ที่ร้านในล็อบบี้",
		tu_pickups_t = "เร่งความเร็วและโล่",
		tu_pickups_b = "ลูกบอล » ทำให้วิ่งเร็วขึ้นชั่วครู่ โล่ + กันการกัดได้หนึ่งครั้งและทำให้ซอมบี้มึน",
		tu_climb_t = "บันไดและแทรมโพลีน",
		tu_climb_b = "ปีนบันไดสีเหลืองขึ้นหลังคา กระโดดบนแทรมโพลีนสีชมพูเพื่อลอยขึ้นสูง",
		tu_manhole_t = "ท่อระบายน้ำ",
		tu_manhole_b = "ยืนบนฝาท่อแล้วกดปุ่มค้างไว้ คุณจะโผล่ออกที่ฝาท่อที่มีแสงสีเดียวกัน",
		tu_heli_t = "หนีด้วยเฮลิคอปเตอร์",
		tu_heli_b = "ใกล้จบรอบ เฮลิคอปเตอร์จะลงจอด ไปที่แสงสีเขียวและยืนอยู่ 3 วินาทีเพื่อหนีพร้อมโบนัส",
		tu_final_t = "การล่าครั้งสุดท้าย",
		tu_final_b = "ในวินาทีสุดท้าย ซอมบี้จะเห็นผู้รอดชีวิตเป็นสีแดงทะลุกำแพง อย่าหยุดเคลื่อนที่!",
		tu_crates_t = "ลังของ",
		tu_crates_b = "กดปุ่มค้างไว้ข้างลังเพื่อเปิด อาหาร 🍞 และชิ้นส่วน 🔩 จะเข้ากระเป๋า รอดให้ได้เพื่อเก็บไว้ ถ้าถูกจับ กระเป๋าจะหล่น",
		tu_hunger_t = "ความหิว",
		tu_hunger_b = "แถบ 🍗 ลดลงระหว่างรอบ ต่ำกว่า 30% คุณจะกินขนมปังในกระเป๋าเอง ถ้าเหลือ 0 จะวิ่งช้าและซอมบี้มองเห็นคุณ",
		tu_vaccine_t = "วัคซีน",
		tu_vaccine_b = "เปิดตู้ยาเพื่อรับวัคซีน 💉 ช่วยให้รอดจากการถูกกัดได้หนึ่งครั้ง",
		tu_home_t = "บ้านของคุณ",
		tu_home_b = "คุณมีที่ดินอยู่นอกกำแพงเมือง กดปุ่มค้างไว้ที่ป้ายนี้เพื่อไปที่นั่นและสร้างด้วยชิ้นส่วน 🔩",
		tu_nest_t = "รังซอมบี้",
		tu_nest_b = "ซอมบี้ขยายรังด้วยสมอง 🧠 จากการจับ กดปุ่มค้างไว้ที่ป้ายนี้เพื่อไปที่รังของคุณ",
		tu_wheel_t = "วงล้อนำโชค",
		tu_wheel_b = "หมุนฟรีทุกวันและหลังเล่นครบทุก 3 รอบ หมุนครั้งไหนก็ได้รางวัล!",
		tu_shop_t = "ร้านค้า",
		tu_shop_b = "ซื้อหางแสงและสกินซอมบี้ด้วยเหรียญ ขณะยืนบนพื้นสีฟ้า รอบเล่นจะข้ามคุณไป",
		tu_codes_t = "โค้ด",
		tu_codes_b = "ใส่โค้ดที่เคาน์เตอร์นี้เพื่อรับของขวัญ แต่ละโค้ดใช้ได้ครั้งเดียว โค้ดใหม่อยู่ใน TikTok ของเรา",
		tu_quests_t = "ภารกิจประจำวัน",
		tu_quests_b = "มีภารกิจใหม่สามอย่างบนกระดานนี้ทุกวัน ทำให้สำเร็จเพื่อรับเหรียญ และกลับมาทุกวันเพื่อให้สถิติต่อเนื่อง 🔥 เพิ่มขึ้น",
		tu_pumpkins_t = "ล่าฟักทอง",
		tu_pumpkins_b = "หา 🎃 บนหลังคาและถนนระหว่างรอบ แล้วใช้แลกของตกแต่งฮาโลวีนที่กระดานบ้านของคุณ",
	},
	ko = {
		tu_btn = "❓ 플레이 방법",
		tu_title = "📚 플레이 방법",
		tu_ok = "알겠어요!",
		tu_count = "배운 것: %d/%d",
		tu_reward = "📚 모두 배웠어요! +%d 💰",
		tu_goal = "모든 주제 배우기: +%d 💰",
		tu_new = "새 팁",
		tu_survivor_t = "당신은 생존자예요",
		tu_survivor_b = "빛나는 좀비에게서 도망치고 벽 뒤나 덤불에 숨어요. 타이머가 끝날 때까지 버티면 코인을 받아요.",
		tu_zombie_t = "당신은 좀비예요",
		tu_zombie_b = "생존자를 터치하면 감염시켜요. 잡을 때마다 코인과 뇌 🧠를 받아요. 연속으로 잡으면 콤보예요!",
		tu_dash_t = "대시",
		tu_dash_b = "Q를 누르거나 ⚡를 눌러 앞으로 돌진해요. 좀비는 덮치기를 해요. 그다음 버튼이 다시 찰 때까지 기다려요.",
		tu_coins_t = "코인",
		tu_coins_b = "거리의 노란 코인을 모아요. 로비 상점에서 트레일과 좀비 스킨을 사는 데 써요.",
		tu_pickups_t = "부스트와 방패",
		tu_pickups_b = "» 구슬은 순간 속도를 올려 줘요. + 방패는 물기를 한 번 막고 좀비를 기절시켜요.",
		tu_climb_t = "사다리와 트램펄린",
		tu_climb_b = "노란 사다리로 지붕에 올라가요. 분홍 트램펄린에서 뛰면 높이 날아올라요.",
		tu_manhole_t = "맨홀",
		tu_manhole_b = "맨홀 위에 서서 버튼을 길게 눌러요. 같은 색 빛이 나는 맨홀로 나와요.",
		tu_heli_t = "헬리콥터 탈출",
		tu_heli_b = "끝날 무렵 헬리콥터가 착륙해요. 초록 불빛에 가서 3초 동안 있으면 보너스와 함께 탈출해요.",
		tu_final_t = "마지막 사냥",
		tu_final_b = "마지막 몇 초 동안 좀비는 벽 너머의 생존자를 빨갛게 봐요. 계속 움직여요!",
		tu_crates_t = "상자",
		tu_crates_b = "상자 옆에서 버튼을 길게 눌러 열어요. 음식 🍞과 부품 🔩이 배낭에 들어가요. 살아남아야 지킬 수 있고, 잡히면 배낭을 떨어뜨려요.",
		tu_hunger_t = "배고픔",
		tu_hunger_b = "라운드 동안 🍗 막대가 줄어요. 30% 아래가 되면 배낭의 빵을 알아서 먹어요. 0이 되면 느려지고 좀비에게 보여요.",
		tu_vaccine_t = "백신",
		tu_vaccine_b = "의약품 캐비닛을 열어 백신 💉을 얻어요. 한 번 물리는 것을 막아 줘요.",
		tu_home_t = "내 집",
		tu_home_b = "도시 성벽 밖에 내 땅이 있어요. 이 표지판에서 버튼을 길게 누르면 그곳으로 가서 부품 🔩으로 지을 수 있어요.",
		tu_nest_t = "좀비 둥지",
		tu_nest_b = "좀비는 잡아서 얻은 뇌 🧠로 둥지를 키워요. 이 표지판에서 버튼을 길게 누르면 내 둥지로 가요.",
		tu_wheel_t = "행운의 바퀴",
		tu_wheel_b = "매일, 그리고 3라운드마다 무료로 돌려요. 돌릴 때마다 무언가를 받아요!",
		tu_shop_t = "상점",
		tu_shop_b = "코인으로 트레일과 좀비 스킨을 사요. 파란 바닥에 서 있는 동안에는 라운드에 끌려가지 않아요.",
		tu_codes_t = "코드",
		tu_codes_b = "이 데스크에서 코드를 입력하고 선물을 받아요. 코드는 한 번만 쓸 수 있어요. 새 코드는 우리 TikTok에 있어요.",
		tu_quests_t = "일일 퀘스트",
		tu_quests_b = "매일 이 게시판에 새 퀘스트 세 개가 있어요. 완료하면 코인을 받고, 매일 오면 연속 기록 🔥이 늘어요.",
		tu_pumpkins_t = "호박 사냥",
		tu_pumpkins_b = "라운드 중에 지붕과 거리에서 🎃을 찾아요. 집 게시판에서 핼러윈 장식에 써요.",
	},
	ja = {
		tu_btn = "❓ あそびかた",
		tu_title = "📚 あそびかた",
		tu_ok = "わかった!",
		tu_count = "おぼえた: %d/%d",
		tu_reward = "📚 ぜんぶおぼえた! +%d 💰",
		tu_goal = "ぜんぶのテーマをおぼえよう: +%d 💰",
		tu_new = "あたらしいヒント",
		tu_survivor_t = "キミはサバイバー",
		tu_survivor_b = "光るゾンビからにげて、かべのうしろやしげみにかくれよう。タイマーが終わるまで生きのこればコインがもらえる。",
		tu_zombie_t = "キミはゾンビ",
		tu_zombie_b = "サバイバーにさわると感染させられる。つかまえるたびにコインとのう 🧠 がもらえる。つづけてつかまえるとコンボ!",
		tu_dash_t = "ダッシュ",
		tu_dash_b = "Q をおすか ⚡ をタップして前にダッシュ。ゾンビはとびかかりになる。そのあとボタンがたまるまで待とう。",
		tu_coins_t = "コイン",
		tu_coins_b = "道にある黄色いコインをひろおう。ロビーのショップでトレイルやゾンビスキンに使える。",
		tu_pickups_t = "スピードとシールド",
		tu_pickups_b = "» のボールで一気にスピードアップ。+ のシールドは一回かまれるのをふせいで、ゾンビをスタンさせる。",
		tu_climb_t = "はしごとトランポリン",
		tu_climb_b = "黄色いはしごで屋根にのぼろう。ピンクのトランポリンで高くジャンプできる。",
		tu_manhole_t = "マンホール",
		tu_manhole_b = "マンホールの上に立ってボタンを長おし。同じ色の光のマンホールから出てくる。",
		tu_heli_t = "ヘリでだっしゅつ",
		tu_heli_b = "終わりが近づくとヘリがおりてくる。緑の光まで行って3秒とどまれば、ボーナスつきでだっしゅつ。",
		tu_final_t = "さいごの狩り",
		tu_final_b = "のこり数秒になると、ゾンビにはかべのむこうのサバイバーが赤く見える。止まらずに動きつづけよう!",
		tu_crates_t = "木箱",
		tu_crates_b = "木箱のそばでボタンを長おしして開けよう。食べもの 🍞 とパーツ 🔩 がリュックに入る。生きのこればキープ、つかまるとリュックを落とす。",
		tu_hunger_t = "おなか",
		tu_hunger_b = "ラウンド中は 🍗 のゲージがへっていく。30% より下になるとリュックのパンを自動で食べる。0 になると足がおそくなり、ゾンビに見つかる。",
		tu_vaccine_t = "ワクチン",
		tu_vaccine_b = "くすりだなを開けてワクチン 💉 をゲット。一回かまれても助かる。",
		tu_home_t = "キミの家",
		tu_home_b = "町のかべの外にキミの土地がある。このかんばんでボタンを長おしすると行けて、パーツ 🔩 で家をたてられる。",
		tu_nest_t = "ゾンビの巣",
		tu_nest_b = "ゾンビはつかまえてためたのう 🧠 で巣を大きくする。このかんばんでボタンを長おしすると自分の巣に行ける。",
		tu_wheel_t = "ラッキーホイール",
		tu_wheel_b = "毎日、それと3ラウンドごとにただで回せる。回すたびに何かもらえる!",
		tu_shop_t = "ショップ",
		tu_shop_b = "コインでトレイルやゾンビスキンを買おう。青いゆかに立っているあいだは、ラウンドにつれていかれない。",
		tu_codes_t = "コード",
		tu_codes_b = "このカウンターでコードを入れるとプレゼントがもらえる。コードは一回だけ。新しいコードはTikTokで発表。",
		tu_quests_t = "今日のミッション",
		tu_quests_b = "このボードに毎日3つの新しいミッション。クリアしてコインをもらい、毎日来てれんぞく 🔥 をのばそう。",
		tu_pumpkins_t = "かぼちゃ探し",
		tu_pumpkins_b = "ラウンド中に屋根や道で 🎃 を探そう。家のボードでハロウィンのかざりに使える。",
	},
}

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local inRound: { [Player]: boolean } = ctx.inRound
	local isZombie: { [Player]: boolean } = ctx.isZombie
	local RS = game:GetService("ReplicatedStorage")
	local LOBBY_Y: number = ctx.LOBBY_Y

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

	local remote = RS:FindFirstChild("ZT_Tut") :: RemoteEvent?
	if not remote then
		local made = Instance.new("RemoteEvent")
		made.Name = "ZT_Tut"
		made.Parent = RS
		remote = made
	end
	local tut = remote :: RemoteEvent

	local ICON: { [string]: string } = {}
	for _, topic in ipairs(TOPICS) do
		ICON[topic.key] = topic.icon
	end

	type State = { mem: { [string]: boolean }, lastAt: number, pending: string?, pendingAt: number, roleKey: string, roleAt: number,
		joinedRoundAt: number, introAt: number?, asked: number }
	local states: { [Player]: State } = {}
	local api: any = { states = states, shown = {}, gap = GAP, reward = REWARD, topics = TOPICS }
	ctx.tutorial = api

	local function state(player: Player): State
		local s = states[player]
		if not s then
			s = { mem = {}, lastAt = -math.huge, pending = nil, pendingAt = 0, roleKey = "", roleAt = 0, joinedRoundAt = 0, introAt = nil, asked = 0 }
			states[player] = s
		end
		return s
	end
	-- что игрок уже видел: в сохранении (через модуль Survival), иначе только в памяти сервера
	local function items(player: Player): { [string]: number }?
		local sv = ctx.survival
		local session = sessions[player]
		if sv and sv.stock and session then
			local ok, stock = pcall(sv.stock, session)
			if ok and type(stock) == "table" and type(stock.items) == "table" then
				return stock.items
			end
		end
		return nil
	end
	local function isSeen(player: Player, key: string): boolean
		local list = items(player)
		if list and list["tu_" .. key] then
			return true
		end
		return state(player).mem[key] == true
	end
	local function learned(player: Player): number
		local n = 0
		for _, topic in ipairs(TOPICS) do
			if isSeen(player, topic.key) then
				n += 1
			end
		end
		return n
	end
	local function mark(player: Player, key: string)
		if not ICON[key] or isSeen(player, key) then
			return
		end
		state(player).mem[key] = true
		local list = items(player)
		if list then
			list["tu_" .. key] = 1
		end
		-- изучил всё: награда один раз
		if learned(player) >= #TOPICS then
			local session = sessions[player]
			local done = (list and list.tu_done) or state(player).mem.done
			if session and not done then
				if list then
					list.tu_done = 1
				end
				state(player).mem.done = true
				session.profile.coins += REWARD
				pcall(ctx.sync, player)
				ctx.toast(player, "tu_reward", REWARD)
				pcall(ctx.sound, player, "win")
			end
		end
	end
	api.isSeen, api.mark, api.learned = isSeen, mark, learned

	local function cardData(player: Player, key: string): any
		return {
			key = key, icon = ICON[key], title = ctx.tr(player, "tu_" .. key .. "_t"), body = ctx.tr(player, "tu_" .. key .. "_b"),
		}
	end
	local function show(player: Player, key: string)
		local s = state(player)
		s.lastAt = os.clock()
		s.pending = nil
		mark(player, key)
		local data = cardData(player, key)
		data.count = ctx.tr(player, "tu_count", learned(player), #TOPICS)
		table.insert(api.shown, { player = player, key = key })
		tut:FireClient(player, "tip", data)
	end
	-- карточка, если тема новая; если только что была другая карточка - откладываем (одну)
	local function want(player: Player, key: string)
		if isSeen(player, key) then
			return
		end
		local s = state(player)
		local now = os.clock()
		if s.introAt and now - s.introAt < 9 then
			return
		end
		if now - s.lastAt < GAP then
			if not s.pending then
				s.pending = key
				s.pendingAt = now
			end
			return
		end
		show(player, key)
	end
	api.want = want

	-- подписи кнопки и книги на языке игрока (клиенту модуль Texts недоступен)
	local function sendUi(player: Player)
		for _, key in ipairs(UI_KEYS) do
			if key == "tu_count" then
				player:SetAttribute("ZT_Tu_count", ctx.tr(player, "tu_count", learned(player), #TOPICS))
			elseif key == "tu_goal" then
				player:SetAttribute("ZT_Tu_goal", ctx.tr(player, "tu_goal", REWARD))
			else
				player:SetAttribute("ZT_Tu_" .. string.sub(key, 4), ctx.tr(player, key))
			end
		end
	end
	local function onJoin(player: Player)
		for _ = 1, 40 do
			if sessions[player] or player.Parent == nil then
				break
			end
			task.wait(0.25)
		end
		if player.Parent then
			sendUi(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onJoin, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- книга «Как играть»: список тем с отметками; прочитанная в книге тема тоже считается изученной
	tut.OnServerEvent:Connect(function(player: Player, what: any, key: any)
		local s = state(player)
		local now = os.clock()
		-- the list ("guide") and one topic ("read") have their own limits: a read sent right after the list is not lost
		local reading = what == "read"
		local last = if reading then ((s :: any).readAt or 0) else s.asked
		if now - last < (if reading then 0.05 else 0.2) then
			return
		end
		if reading then
			(s :: any).readAt = now
		else
			s.asked = now
		end
		if what == "guide" then
			local list = {}
			for _, topic in ipairs(TOPICS) do
				local data = cardData(player, topic.key)
				data.seen = isSeen(player, topic.key)
				table.insert(list, data)
			end
			tut:FireClient(player, "guide", list, ctx.tr(player, "tu_count", learned(player), #TOPICS))
		elseif what == "read" and type(key) == "string" and ICON[key] then
			mark(player, key)
			tut:FireClient(player, "count", ctx.tr(player, "tu_count", learned(player), #TOPICS), key)
		end
	end)

	-- ГДЕ ЧТО СТОИТ: части карты ищем по именам (раз в несколько секунд: ящики и тыквы появляются в раунде)
	local places: { [string]: { Vector3 } } = {}
	local function collect()
		local map = workspace:FindFirstChild("ZombieTagMap")
		if not map then
			return
		end
		local found: { [string]: { Vector3 } } = {
			climb = {}, manhole = {}, crates = {}, vaccine = {}, pumpkins = {}, home = {}, nest = {}, wheel = {}, shop = {}, codes = {}, quests = {},
		}
		for _, ladder in ipairs(ctx.ladders or {}) do
			if typeof(ladder.bottom) == "Vector3" then
				table.insert(found.climb, ladder.bottom)
			end
		end
		local city = map:FindFirstChild("City")
		if city then
			for _, d in ipairs(city:GetDescendants()) do
				if d:IsA("BasePart") then
					if d.Name == "Trampoline" then
						table.insert(found.climb, d.Position)
					elseif d.Name == "Manhole" then
						table.insert(found.manhole, d.Position)
					end
				end
			end
		end
		local loot = map:FindFirstChild("Loot")
		if loot then
			for _, d in ipairs(loot:GetChildren()) do
				if d:IsA("BasePart") then
					if d.Name == "SV_Crate" then
						table.insert(found.crates, d.Position)
					elseif d.Name == "SV_Cabinet" then
						table.insert(found.vaccine, d.Position)
					end
				end
			end
		end
		local pumpkins = map:FindFirstChild("Pumpkins")
		if pumpkins then
			for _, d in ipairs(pumpkins:GetChildren()) do
				local pos = if d:IsA("BasePart") then d.Position elseif d:IsA("Model") then d:GetPivot().Position else nil
				if pos then
					table.insert(found.pumpkins, pos)
				end
			end
		end
		local homes = map:FindFirstChild("Homes")
		if homes then
			for _, d in ipairs(homes:GetChildren()) do
				if d:IsA("BasePart") then
					if d.Name == "HM_PadHome" then
						table.insert(found.home, d.Position)
					elseif d.Name == "HM_PadNest" then
						table.insert(found.nest, d.Position)
					end
				end
			end
		end
		local luck = map:FindFirstChild("Luck")
		local stand = luck and luck:FindFirstChild("Stand")
		local button = stand and stand:FindFirstChild("Button")
		if button and button:IsA("BasePart") then
			table.insert(found.wheel, button.Position)
		elseif luck and luck:IsA("Model") then
			table.insert(found.wheel, luck:GetPivot().Position)
		end
		local lobby = map:FindFirstChild("Lobby")
		if lobby then
			for _, d in ipairs(lobby:GetChildren()) do
				if d:IsA("BasePart") then
					if d.Name == "ShopStand" then
						table.insert(found.shop, d.Position)
					elseif d.Name == "QuestBoard" then
						table.insert(found.quests, d.Position)
					end
				end
			end
		end
		local kiosk = map:FindFirstChild("CodesKiosk")
		local desk = kiosk and kiosk:FindFirstChild("Desk")
		if desk and desk:IsA("BasePart") then
			table.insert(found.codes, desk.Position)
		end
		places = found
	end
	api.collect = collect
	api.places = function()
		return places
	end
	local function near(list: { Vector3 }?, pos: Vector3, radius: number): boolean
		if not list then
			return false
		end
		for _, p in ipairs(list) do
			if (p - pos).Magnitude <= radius then
				return true
			end
		end
		return false
	end

	local function check(player: Player, now: number)
		local session = sessions[player]
		if not session then
			return
		end
		local s = state(player)
		-- интро новичка: 9 секунд после его начала карточек нет
		if player:GetAttribute("ZT_IntroDone") == true and not s.introAt and player:GetAttribute("ZT_Intro") ~= nil then
			s.introAt = now
		end
		if s.pending and now - s.lastAt >= GAP then
			local key = s.pending :: string
			if now - s.pendingAt <= PENDING_FOR then
				s.pending = nil
				if not isSeen(player, key) then
					show(player, key)
					return
				end
			end
			s.pending = nil
		end
		local root = ctx.getAlive(player)
		if not root then
			return
		end
		local pos: Vector3 = root.Position
		local active, finalHunt = ctx.state()
		local playing = active and inRound[player] == true
		if playing then
			local zombie = isZombie[player] == true
			local role = if zombie then "zombie" else "survivor"
			if s.roleKey ~= role then
				s.roleKey = role
				s.roleAt = now
			end
			if s.joinedRoundAt == 0 then
				s.joinedRoundAt = now
			end
			-- роль: через 4 секунды после начала (новичку сначала говорят главное)
			if now - s.roleAt >= 4 then
				want(player, role)
			end
			if now - s.joinedRoundAt >= 25 then
				want(player, "dash")
			end
			if finalHunt then
				want(player, "final")
			end
			if not zombie then
				if ctx.evac and ctx.evac.spot then
					want(player, "heli")
				end
				for _, pickup in ipairs(ctx.pickups or {}) do
					local part = pickup.part
					if part and part.Parent and (part.Position - pos).Magnitude <= 14 then
						want(player, if pickup.kind == "coin" then "coins" else "pickups")
					end
				end
				if near(places.crates, pos, 16) then
					want(player, "crates")
				end
				if near(places.vaccine, pos, 14) then
					want(player, "vaccine")
				end
				local sv = ctx.survival
				local pack = sv and sv.packs and sv.packs[player]
				if pack and type(pack.sat) == "number" and pack.sat < 45 then
					want(player, "hunger")
				end
			end
			if near(places.climb, pos, 10) then
				want(player, "climb")
			end
			if near(places.manhole, pos, 9) then
				want(player, "manhole")
			end
			if near(places.pumpkins, pos, 22) then
				want(player, "pumpkins")
			end
		else
			s.roleKey = ""
			s.joinedRoundAt = 0
			if pos.Y > LOBBY_Y - 30 then
				if near(places.home, pos, 12) then
					want(player, "home")
				elseif near(places.nest, pos, 12) then
					want(player, "nest")
				elseif near(places.wheel, pos, 14) then
					want(player, "wheel")
				elseif near(places.codes, pos, 10) then
					want(player, "codes")
				elseif near(places.quests, pos, 14) then
					want(player, "quests")
				elseif near(places.shop, pos, 9) then
					want(player, "shop")
				end
			end
		end
	end
	api.check = check

	task.spawn(function()
		local lastCollect = -math.huge
		while true do
			task.wait(0.5)
			local now = os.clock()
			if now - lastCollect >= 4 then
				lastCollect = now
				local ok, err = pcall(collect)
				if not ok then
					warn("[Zombie Tag] Tutorial: " .. tostring(err))
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(check, player, now)
				if not ok then
					warn("[Zombie Tag] Tutorial: " .. tostring(err))
				end
			end
		end
	end)

	return api
end
