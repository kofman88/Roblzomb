--!strict
--[[
	УДАЧА (модуль Luck): колесо удачи и табло серии дней в лобби

	КУДА ВСТАВИТЬ: это ModuleScript с именем Luck. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Luck, рядом с Extras). Запускает его модуль Extras.

	Что здесь:
	- большое колесо удачи в лобби. Его видят все: когда кто-то крутит, колесо крутится у всех на экранах;
	- крутить можно только БЕСПЛАТНЫЕ вращения: одно каждый день (вместе с ежедневной наградой) и одно
	  за каждые 3 сыгранных раунда. Вращения не продаются и не стоят монет: по правилам Roblox платная
	  случайная награда требует отдельных условий, а здесь её нет. Проигрышей нет, шансы написаны на колесе;
	- джекпот видит весь сервер (надпись всем и строка "последний джекпот" над колесом);
	- табло серии дней: сколько монет за каждый день подряд, что будет завтра и какой подарок впереди.
	Экран (крутящееся колесо, огоньки, щелчки) рисует скрипт ZT_Touch. Настройки ниже.
]]

local ROUNDS_PER_SPIN = 3   -- за сколько сыгранных раундов дают бесплатное вращение
local SPIN_CAP = 9          -- больше скольких вращений не копится
local SPIN_TIME = 5.4       -- сколько секунд крутится колесо (плюс до 0.8 с случайно)
local REACH = 14            -- с какого расстояния от колеса можно крутить
local VIP_COINS = 2         -- во сколько раз больше монет на колесе у VIP

-- призы по кругу (по часовой стрелке от верха). w - вес: шанс в процентах (сумма 100)
local PRIZES: { { kind: string, n: number, w: number, color: Color3, text: string } } = {
	{ kind = "jackpot", n = 300, w = 2, color = Color3.fromRGB(255, 196, 40), text = "💰300" },
	{ kind = "coins", n = 15, w = 28, color = Color3.fromRGB(70, 130, 230), text = "15💰" },
	{ kind = "parts", n = 6, w = 16, color = Color3.fromRGB(150, 150, 165), text = "6🔩" },
	{ kind = "coins", n = 75, w = 10, color = Color3.fromRGB(220, 70, 90), text = "75💰" },
	{ kind = "food", n = 3, w = 12, color = Color3.fromRGB(230, 150, 60), text = "3🍞" },
	{ kind = "coins", n = 40, w = 16, color = Color3.fromRGB(60, 180, 110), text = "40💰" },
	{ kind = "spin", n = 1, w = 10, color = Color3.fromRGB(150, 80, 220), text = "+1🎡" },
	{ kind = "brains", n = 15, w = 6, color = Color3.fromRGB(90, 200, 90), text = "15🧠" },
}

local TEXT: { [string]: { [string]: string } } = {
	en = {
		luck_title = "🎡 WHEEL OF LUCK",
		luck_spins = "Free spins: %d",
		luck_next = "Next free spin: play %d more rounds or come back tomorrow",
		luck_vip = "VIP: ×2 💰 on the wheel",
		luck_last = "Last jackpot: %s",
		luck_none = "🎡 No spins yet: play %d more rounds or come back tomorrow",
		luck_busy = "🎡 The wheel is spinning, wait a moment",
		luck_far = "🎡 Come closer to the wheel",
		luck_earned = "🎡 +1 free spin! The wheel is in the lobby",
		luck_daily = "🎡 Your daily free spin is waiting in the lobby!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 SPIN AGAIN!",
		luck_jackpot = "💰 JACKPOT! +%d 💰",
		luck_jackpot_all = "🎉 %s hit the JACKPOT on the wheel: +%d 💰!",
		luck_odds = "Every spin wins. Chances are on the wheel",
		cal_title = "🔥 DAILY STREAK",
		cal_day = "Day %d",
		cal_today = "Today ✔",
		cal_tomorrow = "Come back tomorrow: +%d 💰",
		cal_gift = "🎁 Day %d: %s",
		cal_rule = "Skip more than one day and the streak starts over",
	},
	ru = {
		luck_title = "🎡 КОЛЕСО УДАЧИ",
		luck_spins = "Бесплатных вращений: %d",
		luck_next = "Следующее бесплатно: сыграй ещё раундов: %d или заходи завтра",
		luck_vip = "VIP: ×2 💰 на колесе",
		luck_last = "Последний джекпот: %s",
		luck_none = "🎡 Вращений пока нет: сыграй ещё раундов: %d или заходи завтра",
		luck_busy = "🎡 Колесо крутится, подожди немного",
		luck_far = "🎡 Подойди ближе к колесу",
		luck_earned = "🎡 +1 бесплатное вращение! Колесо — в лобби",
		luck_daily = "🎡 В лобби тебя ждёт бесплатное вращение дня!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 КРУТИ ЕЩЁ!",
		luck_jackpot = "💰 ДЖЕКПОТ! +%d 💰",
		luck_jackpot_all = "🎉 %s сорвал ДЖЕКПОТ на колесе: +%d 💰!",
		luck_odds = "Без проигрышей. Шансы — на колесе",
		cal_title = "🔥 СЕРИЯ ДНЕЙ",
		cal_day = "День %d",
		cal_today = "Сегодня ✔",
		cal_tomorrow = "Заходи завтра: +%d 💰",
		cal_gift = "🎁 День %d: %s",
		cal_rule = "Пропустишь больше дня — серия начнётся заново",
	},
	es = {
		luck_title = "🎡 RUEDA DE LA SUERTE",
		luck_spins = "Giros gratis: %d",
		luck_next = "Próximo giro gratis: juega %d rondas más o vuelve mañana",
		luck_vip = "VIP: ×2 💰 en la rueda",
		luck_last = "Último premio mayor: %s",
		luck_none = "🎡 Aún no hay giros: juega %d rondas más o vuelve mañana",
		luck_busy = "🎡 La rueda está girando, espera un momento",
		luck_far = "🎡 Acércate a la rueda",
		luck_earned = "🎡 ¡+1 giro gratis! La rueda está en el lobby",
		luck_daily = "🎡 ¡Tu giro gratis del día te espera en el lobby!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 ¡GIRA OTRA VEZ!",
		luck_jackpot = "💰 ¡PREMIO MAYOR! +%d 💰",
		luck_jackpot_all = "🎉 ¡%s ganó el PREMIO MAYOR en la rueda: +%d 💰!",
		luck_odds = "Siempre ganas. Las probabilidades están en la rueda",
		cal_title = "🔥 RACHA DIARIA",
		cal_day = "Día %d",
		cal_today = "Hoy ✔",
		cal_tomorrow = "Vuelve mañana: +%d 💰",
		cal_gift = "🎁 Día %d: %s",
		cal_rule = "Si faltas más de un día, la racha empieza de nuevo",
	},
	pt = {
		luck_title = "🎡 RODA DA SORTE",
		luck_spins = "Giros grátis: %d",
		luck_next = "Próximo giro grátis: jogue mais %d rodadas ou volte amanhã",
		luck_vip = "VIP: ×2 💰 na roda",
		luck_last = "Último prêmio máximo: %s",
		luck_none = "🎡 Ainda sem giros: jogue mais %d rodadas ou volte amanhã",
		luck_busy = "🎡 A roda está girando, espere um pouco",
		luck_far = "🎡 Chegue mais perto da roda",
		luck_earned = "🎡 +1 giro grátis! A roda está no lobby",
		luck_daily = "🎡 Seu giro grátis do dia está esperando no lobby!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 GIRE DE NOVO!",
		luck_jackpot = "💰 PRÊMIO MÁXIMO! +%d 💰",
		luck_jackpot_all = "🎉 %s ganhou o PRÊMIO MÁXIMO na roda: +%d 💰!",
		luck_odds = "Todo giro ganha. As chances estão na roda",
		cal_title = "🔥 SEQUÊNCIA DIÁRIA",
		cal_day = "Dia %d",
		cal_today = "Hoje ✔",
		cal_tomorrow = "Volte amanhã: +%d 💰",
		cal_gift = "🎁 Dia %d: %s",
		cal_rule = "Faltou mais de um dia, a sequência recomeça",
	},
	fr = {
		luck_title = "🎡 ROUE DE LA CHANCE",
		luck_spins = "Tours gratuits : %d",
		luck_next = "Prochain tour gratuit : joue encore %d manches ou reviens demain",
		luck_vip = "VIP : ×2 💰 sur la roue",
		luck_last = "Dernier jackpot : %s",
		luck_none = "🎡 Pas encore de tours : joue encore %d manches ou reviens demain",
		luck_busy = "🎡 La roue tourne, attends un instant",
		luck_far = "🎡 Approche-toi de la roue",
		luck_earned = "🎡 +1 tour gratuit ! La roue est dans le lobby",
		luck_daily = "🎡 Ton tour gratuit du jour t'attend dans le lobby !",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 ENCORE UN TOUR !",
		luck_jackpot = "💰 JACKPOT ! +%d 💰",
		luck_jackpot_all = "🎉 %s a décroché le JACKPOT de la roue : +%d 💰 !",
		luck_odds = "Chaque tour gagne. Les chances sont sur la roue",
		cal_title = "🔥 SÉRIE DE JOURS",
		cal_day = "Jour %d",
		cal_today = "Aujourd'hui ✔",
		cal_tomorrow = "Reviens demain : +%d 💰",
		cal_gift = "🎁 Jour %d : %s",
		cal_rule = "Plus d'un jour d'absence et la série recommence",
	},
	de = {
		luck_title = "🎡 GLÜCKSRAD",
		luck_spins = "Gratis-Drehungen: %d",
		luck_next = "Nächste Gratis-Drehung: noch %d Runden spielen oder morgen wiederkommen",
		luck_vip = "VIP: ×2 💰 am Rad",
		luck_last = "Letzter Jackpot: %s",
		luck_none = "🎡 Noch keine Drehungen: spiel noch %d Runden oder komm morgen wieder",
		luck_busy = "🎡 Das Rad dreht sich, warte kurz",
		luck_far = "🎡 Geh näher ans Rad",
		luck_earned = "🎡 +1 Gratis-Drehung! Das Rad steht in der Lobby",
		luck_daily = "🎡 Deine tägliche Gratis-Drehung wartet in der Lobby!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 NOCH MAL DREHEN!",
		luck_jackpot = "💰 JACKPOT! +%d 💰",
		luck_jackpot_all = "🎉 %s hat den JACKPOT am Rad geknackt: +%d 💰!",
		luck_odds = "Jede Drehung gewinnt. Die Chancen stehen auf dem Rad",
		cal_title = "🔥 TAGESSERIE",
		cal_day = "Tag %d",
		cal_today = "Heute ✔",
		cal_tomorrow = "Komm morgen wieder: +%d 💰",
		cal_gift = "🎁 Tag %d: %s",
		cal_rule = "Mehr als einen Tag verpasst – die Serie beginnt von vorn",
	},
	it = {
		luck_title = "🎡 RUOTA DELLA FORTUNA",
		luck_spins = "Giri gratis: %d",
		luck_next = "Prossimo giro gratis: gioca altri %d round o torna domani",
		luck_vip = "VIP: ×2 💰 sulla ruota",
		luck_last = "Ultimo jackpot: %s",
		luck_none = "🎡 Ancora nessun giro: gioca altri %d round o torna domani",
		luck_busy = "🎡 La ruota sta girando, aspetta un attimo",
		luck_far = "🎡 Avvicinati alla ruota",
		luck_earned = "🎡 +1 giro gratis! La ruota è nella lobby",
		luck_daily = "🎡 Il tuo giro gratis del giorno ti aspetta nella lobby!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 GIRA ANCORA!",
		luck_jackpot = "💰 JACKPOT! +%d 💰",
		luck_jackpot_all = "🎉 %s ha vinto il JACKPOT della ruota: +%d 💰!",
		luck_odds = "Ogni giro vince. Le probabilità sono sulla ruota",
		cal_title = "🔥 SERIE DI GIORNI",
		cal_day = "Giorno %d",
		cal_today = "Oggi ✔",
		cal_tomorrow = "Torna domani: +%d 💰",
		cal_gift = "🎁 Giorno %d: %s",
		cal_rule = "Se salti più di un giorno, la serie ricomincia",
	},
	pl = {
		luck_title = "🎡 KOŁO FORTUNY",
		luck_spins = "Darmowe obroty: %d",
		luck_next = "Następny darmowy obrót: zagraj jeszcze %d rund albo wróć jutro",
		luck_vip = "VIP: ×2 💰 na kole",
		luck_last = "Ostatni jackpot: %s",
		luck_none = "🎡 Brak obrotów: zagraj jeszcze %d rund albo wróć jutro",
		luck_busy = "🎡 Koło się kręci, poczekaj chwilę",
		luck_far = "🎡 Podejdź bliżej koła",
		luck_earned = "🎡 +1 darmowy obrót! Koło stoi w lobby",
		luck_daily = "🎡 W lobby czeka twój darmowy obrót dnia!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 KRĘĆ JESZCZE RAZ!",
		luck_jackpot = "💰 JACKPOT! +%d 💰",
		luck_jackpot_all = "🎉 %s trafił JACKPOT na kole: +%d 💰!",
		luck_odds = "Każdy obrót wygrywa. Szanse są na kole",
		cal_title = "🔥 SERIA DNI",
		cal_day = "Dzień %d",
		cal_today = "Dziś ✔",
		cal_tomorrow = "Wróć jutro: +%d 💰",
		cal_gift = "🎁 Dzień %d: %s",
		cal_rule = "Opuścisz więcej niż dzień – seria zacznie się od nowa",
	},
	tr = {
		luck_title = "🎡 ŞANS ÇARKI",
		luck_spins = "Ücretsiz çevirme: %d",
		luck_next = "Sonraki ücretsiz çevirme: %d tur daha oyna ya da yarın gel",
		luck_vip = "VIP: çarkta ×2 💰",
		luck_last = "Son büyük ikramiye: %s",
		luck_none = "🎡 Henüz çevirme yok: %d tur daha oyna ya da yarın gel",
		luck_busy = "🎡 Çark dönüyor, biraz bekle",
		luck_far = "🎡 Çarka yaklaş",
		luck_earned = "🎡 +1 ücretsiz çevirme! Çark lobide",
		luck_daily = "🎡 Günlük ücretsiz çevirmen lobide seni bekliyor!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 BİR DAHA ÇEVİR!",
		luck_jackpot = "💰 BÜYÜK İKRAMİYE! +%d 💰",
		luck_jackpot_all = "🎉 %s çarkta BÜYÜK İKRAMİYEYİ kazandı: +%d 💰!",
		luck_odds = "Her çevirme kazandırır. Şanslar çarkın üstünde",
		cal_title = "🔥 GÜNLÜK SERİ",
		cal_day = "%d. gün",
		cal_today = "Bugün ✔",
		cal_tomorrow = "Yarın gel: +%d 💰",
		cal_gift = "🎁 %d. gün: %s",
		cal_rule = "Bir günden fazla atlarsan seri baştan başlar",
	},
	id = {
		luck_title = "🎡 RODA KEBERUNTUNGAN",
		luck_spins = "Putaran gratis: %d",
		luck_next = "Putaran gratis berikutnya: main %d ronde lagi atau kembali besok",
		luck_vip = "VIP: ×2 💰 di roda",
		luck_last = "Jackpot terakhir: %s",
		luck_none = "🎡 Belum ada putaran: main %d ronde lagi atau kembali besok",
		luck_busy = "🎡 Roda sedang berputar, tunggu sebentar",
		luck_far = "🎡 Mendekatlah ke roda",
		luck_earned = "🎡 +1 putaran gratis! Rodanya ada di lobi",
		luck_daily = "🎡 Putaran gratis harianmu menunggu di lobi!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 PUTAR LAGI!",
		luck_jackpot = "💰 JACKPOT! +%d 💰",
		luck_jackpot_all = "🎉 %s dapat JACKPOT di roda: +%d 💰!",
		luck_odds = "Setiap putaran menang. Peluangnya ada di roda",
		cal_title = "🔥 HARI BERTURUT-TURUT",
		cal_day = "Hari %d",
		cal_today = "Hari ini ✔",
		cal_tomorrow = "Kembali besok: +%d 💰",
		cal_gift = "🎁 Hari %d: %s",
		cal_rule = "Lewat lebih dari sehari, hitungan mulai dari awal",
	},
	vi = {
		luck_title = "🎡 VÒNG QUAY MAY MẮN",
		luck_spins = "Lượt quay miễn phí: %d",
		luck_next = "Lượt miễn phí tiếp theo: chơi thêm %d vòng hoặc quay lại ngày mai",
		luck_vip = "VIP: ×2 💰 trên vòng quay",
		luck_last = "Giải độc đắc gần nhất: %s",
		luck_none = "🎡 Chưa có lượt quay: chơi thêm %d vòng hoặc quay lại ngày mai",
		luck_busy = "🎡 Vòng quay đang quay, đợi một chút",
		luck_far = "🎡 Lại gần vòng quay hơn",
		luck_earned = "🎡 +1 lượt quay miễn phí! Vòng quay ở sảnh",
		luck_daily = "🎡 Lượt quay miễn phí hôm nay đang chờ bạn ở sảnh!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 QUAY TIẾP!",
		luck_jackpot = "💰 ĐỘC ĐẮC! +%d 💰",
		luck_jackpot_all = "🎉 %s trúng ĐỘC ĐẮC trên vòng quay: +%d 💰!",
		luck_odds = "Lượt nào cũng có quà. Tỉ lệ ghi trên vòng quay",
		cal_title = "🔥 CHUỖI NGÀY",
		cal_day = "Ngày %d",
		cal_today = "Hôm nay ✔",
		cal_tomorrow = "Mai quay lại: +%d 💰",
		cal_gift = "🎁 Ngày %d: %s",
		cal_rule = "Bỏ quá một ngày là chuỗi bắt đầu lại",
	},
	th = {
		luck_title = "🎡 วงล้อนำโชค",
		luck_spins = "หมุนฟรี: %d ครั้ง",
		luck_next = "หมุนฟรีครั้งต่อไป: เล่นอีก %d รอบ หรือกลับมาพรุ่งนี้",
		luck_vip = "VIP: ×2 💰 บนวงล้อ",
		luck_last = "แจ็กพอตล่าสุด: %s",
		luck_none = "🎡 ยังไม่มีสิทธิ์หมุน: เล่นอีก %d รอบ หรือกลับมาพรุ่งนี้",
		luck_busy = "🎡 วงล้อกำลังหมุน รอสักครู่",
		luck_far = "🎡 เข้าไปใกล้วงล้ออีกนิด",
		luck_earned = "🎡 +1 สิทธิ์หมุนฟรี! วงล้ออยู่ในล็อบบี้",
		luck_daily = "🎡 สิทธิ์หมุนฟรีประจำวันรออยู่ในล็อบบี้!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 หมุนอีกครั้ง!",
		luck_jackpot = "💰 แจ็กพอต! +%d 💰",
		luck_jackpot_all = "🎉 %s ได้แจ็กพอตจากวงล้อ: +%d 💰!",
		luck_odds = "หมุนทุกครั้งได้รางวัล โอกาสเขียนไว้บนวงล้อ",
		cal_title = "🔥 เข้าเล่นต่อเนื่อง",
		cal_day = "วันที่ %d",
		cal_today = "วันนี้ ✔",
		cal_tomorrow = "กลับมาพรุ่งนี้: +%d 💰",
		cal_gift = "🎁 วันที่ %d: %s",
		cal_rule = "ขาดเกินหนึ่งวัน จะเริ่มนับใหม่",
	},
	ko = {
		luck_title = "🎡 행운의 룰렛",
		luck_spins = "무료 돌리기: %d",
		luck_next = "다음 무료 돌리기: %d라운드 더 하거나 내일 다시 와요",
		luck_vip = "VIP: 룰렛 💰 ×2",
		luck_last = "최근 잭팟: %s",
		luck_none = "🎡 아직 돌리기가 없어요: %d라운드 더 하거나 내일 다시 와요",
		luck_busy = "🎡 룰렛이 돌고 있어요, 잠깐만요",
		luck_far = "🎡 룰렛 가까이 가요",
		luck_earned = "🎡 무료 돌리기 +1! 룰렛은 로비에 있어요",
		luck_daily = "🎡 오늘의 무료 돌리기가 로비에서 기다려요!",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 한 번 더!",
		luck_jackpot = "💰 잭팟! +%d 💰",
		luck_jackpot_all = "🎉 %s 님이 룰렛 잭팟: +%d 💰!",
		luck_odds = "꽝 없음. 확률은 룰렛에 적혀 있어요",
		cal_title = "🔥 연속 출석",
		cal_day = "%d일차",
		cal_today = "오늘 ✔",
		cal_tomorrow = "내일 오면: +%d 💰",
		cal_gift = "🎁 %d일차: %s",
		cal_rule = "하루 넘게 빠지면 처음부터 다시 시작해요",
	},
	ja = {
		luck_title = "🎡 ラッキールーレット",
		luck_spins = "無料スピン：%d",
		luck_next = "次の無料スピン：あと%dラウンド遊ぶか、明日また来てね",
		luck_vip = "VIP：ルーレットの💰が×2",
		luck_last = "最新のジャックポット：%s",
		luck_none = "🎡 まだスピンがない：あと%dラウンド遊ぶか、明日また来てね",
		luck_busy = "🎡 ルーレットが回っている、少し待ってね",
		luck_far = "🎡 ルーレットに近づいてね",
		luck_earned = "🎡 無料スピン+1！ルーレットはロビーにある",
		luck_daily = "🎡 今日の無料スピンがロビーで待っている！",
		luck_coins = "🎡 +%d 💰",
		luck_parts = "🎡 +%d 🔩",
		luck_food = "🎡 +%d 🍞",
		luck_brains = "🎡 +%d 🧠",
		luck_again = "🎡 もう一回！",
		luck_jackpot = "💰 ジャックポット！+%d 💰",
		luck_jackpot_all = "🎉 %sがルーレットでジャックポット：+%d 💰！",
		luck_odds = "ハズレなし。確率はルーレットに書いてある",
		cal_title = "🔥 連続ログイン",
		cal_day = "%d日目",
		cal_today = "今日 ✔",
		cal_tomorrow = "明日来ると：+%d 💰",
		cal_gift = "🎁 %d日目：%s",
		cal_rule = "1日より長く休むと最初からになる",
	},
}

return function(ctx: any): any
	local Players: Players = ctx.Players
	local sessions: { [Player]: any } = ctx.sessions
	local sv = ctx.survival
	local map = workspace:FindFirstChild("ZombieTagMap")
	if not sv or not map then
		return nil
	end
	local LOBBY_Y: number = ctx.LOBBY_Y
	local RS = game:GetService("ReplicatedStorage")

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
	local warned: { [string]: number } = {}
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok and os.clock() - (warned[what] or -100) > 60 then
			warned[what] = os.clock()
			warn("[Zombie Tag] Luck (" .. what .. "): " .. tostring(err))
		end
	end
	-- прогресс загружен по-настоящему: только тогда вращения выдаются и тратятся
	local function trusted(session: any): boolean
		return session.canSave or not ctx.saveBroken()
	end

	---------------------------------------------------------------------
	-- КОЛЕСО: стоит слева от центра лобби, смотрит на место появления игроков
	---------------------------------------------------------------------
	local R = 5.5                                        -- радиус колеса
	local FLOOR = LOBBY_Y + 0.5
	local BASE = Vector3.new(-25, FLOOR, -8)
	local CENTER = BASE + Vector3.new(0, R + 2.2, 0)
	local face = Vector3.new(25, 0, 34).Unit               -- к месту появления (0, 26)
	local AXIS = CFrame.lookAt(CENTER, CENTER + face)
	local root = Instance.new("Model")
	root.Name = "Luck"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local stand = Instance.new("Model")
	stand.Name = "Stand"
	stand.Parent = root
	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	wheel.Parent = root

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance, kind: string?): any
		local p: BasePart = if kind == "wedge" then Instance.new("WedgePart") else Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- точка на колесе в его плоскости: угол по часовой стрелке от верха (как видит игрок), радиус, отступ к игроку
	local function local2(deg: number, r: number): (number, number)
		local a = math.rad(deg)
		return -math.sin(a) * r, math.cos(a) * r
	end
	-- прямоугольный треугольник (угол в M, катеты к O и к P) из одного клина, в плоскости колеса
	local function wedge(mx: number, my: number, ox: number, oy: number, px: number, py: number, z: number, color: Color3)
		local ux, uy = ox - mx, oy - my
		local h = math.sqrt(ux * ux + uy * uy)
		ux, uy = ux / h, uy / h
		local bx, by = mx - px, my - py
		local d = math.sqrt(bx * bx + by * by)
		bx, by = bx / d, by / d
		local up = Vector3.new(ux, uy, 0)
		local back = Vector3.new(bx, by, 0)
		local rz = ux * by - uy * bx
		-- правая тройка осей: толщина клина смотрит к игроку или от него, сам клин тот же
		local right = Vector3.new(0, 0, if rz >= 0 then 1 else -1)
		local cx, cy = mx + ux * h / 2 - bx * d / 2, my + uy * h / 2 - by * d / 2
		part("Slice", Vector3.new(0.24, h, d), AXIS * CFrame.fromMatrix(Vector3.new(cx, cy, z), right, up, back), color, Enum.Material.SmoothPlastic, wheel, "wedge")
	end

	local hub = part("Hub", Vector3.new(0.9, 1.6, 1.6), AXIS, Color3.fromRGB(255, 214, 90), Enum.Material.Neon, wheel)
	hub.Shape = Enum.PartType.Cylinder
	hub.CFrame = AXIS * CFrame.Angles(0, math.rad(90), 0)
	local pivot = part("Pivot", Vector3.new(0.2, 0.2, 0.2), AXIS, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, wheel)
	pivot.Transparency = 1
	wheel.PrimaryPart = pivot
	-- диск-подложка за долями
	local disc = part("Disc", Vector3.new(0.3, R * 2 + 0.7, R * 2 + 0.7), AXIS * CFrame.new(0, 0, 0.25) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 30, 60), Enum.Material.SmoothPlastic, wheel)
	disc.Shape = Enum.PartType.Cylinder
	local SEG = 360 / #PRIZES
	local SUB = 3 -- каждая доля из трёх кусочков: колесо почти круглое
	for k, prize in ipairs(PRIZES) do
		local a0 = (k - 1) * SEG - SEG / 2
		for s = 0, SUB - 1 do
			local from, to = a0 + s * SEG / SUB, a0 + (s + 1) * SEG / SUB
			local x1, y1 = local2(from, R)
			local x2, y2 = local2(to, R)
			local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
			local c = prize.color
			local tone = if s == 1 then c else Color3.new(c.R * 0.92, c.G * 0.92, c.B * 0.92)
			wedge(mx, my, 0, 0, x1, y1, -0.05, tone)
			wedge(mx, my, 0, 0, x2, y2, -0.05, tone)
		end
		-- колышек на границе доли
		local px, py = local2(a0, R - 0.25)
		local peg = part("Peg", Vector3.new(0.6, 0.35, 0.35), AXIS * CFrame.new(px, py, -0.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, wheel)
		peg.Shape = Enum.PartType.Cylinder
		-- надпись вдоль радиуса: приз и шанс (цифры и значки понятны на любом языке)
		local mid = (k - 1) * SEG
		local lx, ly = local2(mid, R * 0.6)
		local rx, ry = local2(mid, 1)
		-- справа надпись читается от центра наружу, слева - снаружи к центру (так она не вверх ногами)
		local out = if mid > 180 then -1 else 1
		local label = part("Label", Vector3.new(R * 0.8, 1.7, 0.05), AXIS * CFrame.fromMatrix(Vector3.new(lx, ly, -0.22), Vector3.new(rx * out, ry * out, 0), Vector3.new(ry * out, -rx * out, 0), Vector3.new(0, 0, -1)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, wheel)
		label.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		local big = Instance.new("TextLabel")
		big.BackgroundTransparency = 1
		big.Size = UDim2.fromScale(1, 0.68)
		big.Font = Enum.Font.GothamBlack
		big.TextScaled = true
		big.TextColor3 = Color3.new(1, 1, 1)
		big.TextStrokeTransparency = 0.3
		big.Text = prize.text
		big.Parent = gui
		local odds = Instance.new("TextLabel")
		odds.BackgroundTransparency = 1
		odds.Position = UDim2.fromScale(0, 0.66)
		odds.Size = UDim2.fromScale(1, 0.34)
		odds.Font = Enum.Font.GothamBold
		odds.TextScaled = true
		odds.TextColor3 = Color3.fromRGB(255, 245, 210)
		odds.TextStrokeTransparency = 0.5
		odds.Text = prize.w .. "%"
		odds.Parent = gui
		gui.Parent = label
	end
	-- конфетти джекпота (выпускает экран игрока)
	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"
	confetti.Rate = 0
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 160))
	confetti.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	confetti.Lifetime = NumberRange.new(1.5, 2.6)
	confetti.Speed = NumberRange.new(14, 26)
	confetti.SpreadAngle = Vector2.new(70, 70)
	confetti.Acceleration = Vector3.new(0, -25, 0)
	confetti.LightEmission = 0.6
	confetti.Parent = hub

	-- неподвижная часть: стойка, обод с огоньками, стрелка
	part("Base", Vector3.new(7, 0.6, 3.6), CFrame.lookAt(BASE + Vector3.new(0, 0.3, 0), BASE + Vector3.new(0, 0.3, 0) + face), Color3.fromRGB(46, 36, 70), Enum.Material.SmoothPlastic, stand)
	local legTop = CENTER - face * 0.7
	part("Leg", Vector3.new(0.8, CENTER.Y - FLOOR, 0.8), CFrame.lookAt(Vector3.new(legTop.X, (CENTER.Y + FLOOR) / 2, legTop.Z), Vector3.new(legTop.X, (CENTER.Y + FLOOR) / 2, legTop.Z) + face), Color3.fromRGB(80, 66, 110), Enum.Material.Metal, stand)
	local BULBS = 24
	for i = 1, BULBS do
		local x, y = local2((i - 0.5) * 360 / BULBS, R + 0.5)
		local bulb = part("Bulb", Vector3.new(0.5, 0.5, 0.5), AXIS * CFrame.new(x, y, -0.05), if i % 2 == 0 then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(255, 120, 200), Enum.Material.Neon, stand)
		bulb.Shape = Enum.PartType.Ball
	end
	local ring = part("Rim", Vector3.new(0.5, R * 2 + 1.6, R * 2 + 1.6), AXIS * CFrame.new(0, 0, 0.45) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 50, 110), Enum.Material.Metal, stand)
	ring.Shape = Enum.PartType.Cylinder
	local arrow = part("Arrow", Vector3.new(1.3, 1.3, 0.5), AXIS * CFrame.new(0, R + 0.75, -0.55) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 50, 60), Enum.Material.Neon, stand)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Parent = arrow
	-- точка для надписи над колесом и кнопка
	local top = part("Top", Vector3.new(0.4, 0.4, 0.4), CFrame.new(CENTER + Vector3.new(0, R + 3.4, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, stand)
	top.Transparency = 1
	local button = part("Button", Vector3.new(3, 1, 2), CFrame.lookAt(BASE + face * 2.4 + Vector3.new(0, 0.5, 0), BASE + face * 3.4 + Vector3.new(0, 0.5, 0)), Color3.fromRGB(255, 70, 90), Enum.Material.Neon, stand)
	button.CanQuery = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LuckSpin"
	prompt.ActionText = "🎡"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = button
	wheel:SetAttribute("Axis", AXIS)
	wheel:SetAttribute("Segments", #PRIZES)
	root.Parent = map

	---------------------------------------------------------------------
	-- ВРАЩЕНИЯ: хранятся в запасах игрока (ext.items): lk_sp - сколько есть, lk_wd - отметка ежедневного
	---------------------------------------------------------------------
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ZT_Luck"
	remote.Parent = RS
	local angle = 0           -- где колесо остановилось (радианы, по часовой стрелке у игрока)
	local busyUntil = 0
	local lastJackpot = ""
	local rng = Random.new()
	local function items(session: any): { [string]: number }
		return sv.stock(session).items
	end
	local function spins(session: any): number
		return items(session).lk_sp or 0
	end
	local function addSpin(session: any, n: number)
		local list = items(session)
		local have = math.clamp((list.lk_sp or 0) + n, 0, SPIN_CAP)
		local raw: any = list
		raw.lk_sp = if have > 0 then have else nil
	end
	local function roundsLeft(session: any): number
		return ROUNDS_PER_SPIN - session.profile.rounds % ROUNDS_PER_SPIN
	end
	local function pick(): number
		local total = 0
		for _, p in ipairs(PRIZES) do
			total += p.w
		end
		local roll = rng:NextNumber(0, total)
		for k, p in ipairs(PRIZES) do
			roll -= p.w
			if roll <= 0 then
				return k
			end
		end
		return 2
	end
	-- приз попадает в запасы сразу (игрок может выйти, пока колесо крутится); показ - когда колесо встанет
	local function give(player: Player, session: any, prize: any): (string, number)
		local ext = sv.stock(session)
		if prize.kind == "coins" or prize.kind == "jackpot" then
			local n = prize.n * (if session.vip then VIP_COINS else 1)
			session.profile.coins += n
			return if prize.kind == "jackpot" then "luck_jackpot" else "luck_coins", n
		elseif prize.kind == "parts" then
			ext.mats = math.min(9999, ext.mats + prize.n)
			return "luck_parts", prize.n
		elseif prize.kind == "food" then
			ext.food = math.min(99, ext.food + prize.n)
			return "luck_food", prize.n
		elseif prize.kind == "brains" then
			ext.bio = math.min(99999, ext.bio + prize.n)
			return "luck_brains", prize.n
		end
		addSpin(session, prize.n)
		return "luck_again", prize.n
	end
	local function spin(player: Player)
		local session = sessions[player]
		local body = ctx.getAlive(player)
		if not session or not body then
			return
		end
		local flat = Vector3.new(body.Position.X - BASE.X, 0, body.Position.Z - BASE.Z)
		if flat.Magnitude > REACH or math.abs(body.Position.Y - FLOOR) > 8 then
			ctx.toast(player, "luck_far")
			return
		end
		if not trusted(session) then
			ctx.toast(player, "no_save")
			ctx.sound(player, "deny")
			return
		end
		if os.clock() < busyUntil then
			ctx.toast(player, "luck_busy")
			return
		end
		if spins(session) <= 0 then
			ctx.toast(player, "luck_none", roundsLeft(session))
			ctx.sound(player, "deny")
			return
		end
		addSpin(session, -1)
		local k = pick()
		local prize = PRIZES[k]
		-- куда встать: случайное место внутри доли; у соседей джекпота стрелка чаще встаёт у его края
		local u = rng:NextNumber(0.12, 0.88)
		local nextTo = if k == 2 then -1 elseif k == #PRIZES then 1 else 0
		if nextTo ~= 0 and rng:NextNumber() < 0.6 then
			u = if nextTo < 0 then rng:NextNumber(0.04, 0.2) else rng:NextNumber(0.8, 0.96)
		end
		local deg = (k - 1) * SEG - SEG / 2 + u * SEG
		local want = math.rad(-deg) % (2 * math.pi)
		local turns = rng:NextInteger(5, 7)
		local from = angle
		local to = from - (from % (2 * math.pi)) + 2 * math.pi * turns + want
		local dur = SPIN_TIME + rng:NextNumber(0, 0.8)
		angle = to % (2 * math.pi)
		busyUntil = os.clock() + dur + 0.4
		local kind, n = give(player, session, prize)
		local jackpot = prize.kind == "jackpot"
		remote:FireAllClients({ from = from, to = to, dur = dur, t0 = workspace:GetServerTimeNow(), jackpot = jackpot, who = player.UserId })
		task.delay(dur, function()
			safely("stop", function()
				wheel:PivotTo(AXIS * CFrame.Angles(0, 0, angle))
				if player.Parent then
					ctx.big(player, kind, n)
					ctx.sound(player, if jackpot then "win" elseif prize.kind == "coins" then "coin" else "buy")
					ctx.sync(player)
				end
				if jackpot then
					lastJackpot = player.DisplayName
					for _, other in ipairs(Players:GetPlayers()) do
						if other ~= player then
							ctx.toast(other, "luck_jackpot_all", player.DisplayName, n)
						end
					end
				end
			end)
		end)
	end
	prompt.Triggered:Connect(function(player: Player)
		safely("spin", function()
			spin(player)
		end)
	end)

	---------------------------------------------------------------------
	-- НАДПИСИ НА ЯЗЫКЕ ИГРОКА: над колесом и табло серии дней (у каждого свои, в его PlayerGui)
	---------------------------------------------------------------------
	local BOARD_AT = Vector3.new(25, FLOOR, -8)
	local boardFace = Vector3.new(-25, 0, 34).Unit
	local board = part("StreakBoard", Vector3.new(11, 6.6, 0.4), CFrame.lookAt(BOARD_AT + Vector3.new(0, 5.6, 0), BOARD_AT + Vector3.new(0, 5.6, 0) + boardFace), Color3.fromRGB(34, 26, 52), Enum.Material.SmoothPlastic, stand)
	part("BoardTrim", Vector3.new(11.6, 7.2, 0.3), CFrame.lookAt(BOARD_AT + Vector3.new(0, 5.6, 0) - boardFace * 0.15, BOARD_AT + Vector3.new(0, 5.6, 0) - boardFace * 0.15 + boardFace), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, stand)
	for _, side in ipairs({ -4.6, 4.6 }) do
		local right = Vector3.new(boardFace.Z, 0, -boardFace.X)
		local at = BOARD_AT + right * side + Vector3.new(0, 1.15, 0) - boardFace * 0.3
		part("BoardLeg", Vector3.new(0.5, 2.3, 0.5), CFrame.new(at), Color3.fromRGB(80, 66, 110), Enum.Material.Metal, stand)
	end
	local DAYS = 7
	local labels: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
	local function text(parent: Instance, name: string, pos: UDim2, size: UDim2, font: Enum.Font, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = pos
		t.Size = size
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.4
		t.Text = ""
		t.Parent = parent
		return t
	end
	local function makeLabels(player: Player): any
		local holder = player:FindFirstChild("PlayerGui")
		if not holder then
			return nil
		end
		local sign = Instance.new("BillboardGui")
		sign.Name = "ZT_LuckSign"
		sign.Adornee = top
		sign.Size = UDim2.fromScale(13, 4.2)
		sign.MaxDistance = 90
		sign.LightInfluence = 0
		sign.ResetOnSpawn = false
		local title = text(sign, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.4), Enum.Font.GothamBlack, Color3.fromRGB(255, 220, 90))
		local info = text(sign, "Info", UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.24), Enum.Font.GothamBold, Color3.new(1, 1, 1))
		local extra = text(sign, "Extra", UDim2.fromScale(0, 0.64), UDim2.fromScale(1, 0.18), Enum.Font.GothamBold, Color3.fromRGB(255, 200, 120))
		local last = text(sign, "Last", UDim2.fromScale(0, 0.82), UDim2.fromScale(1, 0.18), Enum.Font.Gotham, Color3.fromRGB(200, 220, 255))
		sign.Parent = holder
		local cal = Instance.new("SurfaceGui")
		cal.Name = "ZT_StreakBoard"
		cal.Adornee = board
		cal.Face = Enum.NormalId.Front
		cal.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		cal.PixelsPerStud = 50
		cal.LightInfluence = 0
		cal.ResetOnSpawn = false
		local head = text(cal, "Title", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.17), Enum.Font.GothamBlack, Color3.fromRGB(255, 170, 70))
		local cells = {}
		for d = 1, DAYS do
			local cell = Instance.new("Frame")
			cell.Name = "Day" .. d
			cell.Position = UDim2.fromScale(0.03 + (d - 1) * 0.135, 0.24)
			cell.Size = UDim2.fromScale(0.125, 0.36)
			cell.BackgroundColor3 = Color3.fromRGB(60, 48, 86)
			cell.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.15, 0)
			corner.Parent = cell
			local name = text(cell, "Name", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.3), Enum.Font.GothamBold, Color3.fromRGB(220, 210, 240))
			local coins = text(cell, "Coins", UDim2.fromScale(0.05, 0.38), UDim2.fromScale(0.9, 0.34), Enum.Font.GothamBlack, Color3.fromRGB(255, 225, 120))
			local mark = text(cell, "Mark", UDim2.fromScale(0.05, 0.72), UDim2.fromScale(0.9, 0.26), Enum.Font.GothamBold, Color3.fromRGB(140, 255, 140))
			cell.Parent = cal
			cells[d] = { frame = cell, name = name, coins = coins, mark = mark }
		end
		local line1 = text(cal, "Tomorrow", UDim2.fromScale(0.04, 0.63), UDim2.fromScale(0.92, 0.12), Enum.Font.GothamBold, Color3.new(1, 1, 1))
		local line2 = text(cal, "Gift", UDim2.fromScale(0.04, 0.75), UDim2.fromScale(0.92, 0.11), Enum.Font.GothamBold, Color3.fromRGB(255, 190, 240))
		local line3 = text(cal, "Rule", UDim2.fromScale(0.04, 0.87), UDim2.fromScale(0.92, 0.09), Enum.Font.Gotham, Color3.fromRGB(190, 180, 210))
		cal.Parent = holder
		return { sign = sign, title = title, info = info, extra = extra, last = last, cal = cal, head = head, cells = cells, line1 = line1, line2 = line2, line3 = line3 }
	end
	local function set(label: TextLabel, value: string)
		if label.Text ~= value then
			label.Text = value
		end
	end
	local function nextGift(profile: any): any
		local best: any = nil
		for _, item in ipairs(ctx.items or {}) do
			if item.days and not profile.owned[item.id] and (not best or item.days < best.days) then
				best = item
			end
		end
		return best
	end
	local function refresh(player: Player, session: any)
		local ui = labels[player]
		if not ui or not ui.sign.Parent then
			ui = makeLabels(player)
			labels[player] = ui
			if not ui then
				return
			end
		end
		local have = spins(session)
		set(ui.title, ctx.tr(player, "luck_title"))
		set(ui.info, if have > 0 then ctx.tr(player, "luck_spins", have) else ctx.tr(player, "luck_next", roundsLeft(session)))
		set(ui.extra, ctx.tr(player, "luck_vip") .. (if session.vip then " ✔" else ""))
		set(ui.last, if lastJackpot ~= "" then ctx.tr(player, "luck_last", lastJackpot) else ctx.tr(player, "luck_odds"))
		ui.info.TextColor3 = if have > 0 then Color3.fromRGB(140, 255, 140) else Color3.fromRGB(255, 255, 255)
		-- табло серии дней
		local profile = session.profile
		local streak = math.max(1, profile.streak)
		local today = (streak - 1) % DAYS + 1
		local base = ctx.dailyBase or 25
		local mult = if session.vip then 2 else 1
		set(ui.head, ctx.tr(player, "cal_title"))
		for d = 1, DAYS do
			local cell = ui.cells[d]
			local day = streak - today + d
			set(cell.name, ctx.tr(player, "cal_day", day))
			set(cell.coins, (base * math.min(day, 7) * mult) .. "💰")
			set(cell.mark, if d < today then "✔" elseif d == today then ctx.tr(player, "cal_today") else "")
			cell.frame.BackgroundColor3 = if d == today then Color3.fromRGB(220, 110, 40) elseif d < today then Color3.fromRGB(70, 90, 70) else Color3.fromRGB(60, 48, 86)
		end
		set(ui.line1, ctx.tr(player, "cal_tomorrow", base * math.min(streak + 1, 7) * mult))
		local gift = nextGift(profile)
		set(ui.line2, if gift then ctx.tr(player, "cal_gift", gift.days, if ctx.itemName then ctx.itemName(player, gift) else gift.id) else "")
		set(ui.line3, ctx.tr(player, "cal_rule"))
	end

	---------------------------------------------------------------------
	-- РАЗ В СЕКУНДУ: ежедневное вращение, вращение за раунды, надписи
	---------------------------------------------------------------------
	local seenRounds: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				safely("tick", function()
					local session = sessions[player]
					if not session then
						return
					end
					if not trusted(session) then
						refresh(player, session)
						return
					end
					local profile = session.profile
					local list = items(session)
					-- ежедневное: вместе с ежедневной наградой игры (она меняет lastDaily)
					if profile.lastDaily > 0 then
						local mark = profile.lastDaily % 997 + 1
						if list.lk_wd ~= mark then
							list.lk_wd = mark
							addSpin(session, 1)
							if profile.rounds > 0 then
								task.delay(9, function()
									if player.Parent then
										ctx.toast(player, "luck_daily")
									end
								end)
							end
						end
					end
					-- за раунды
					local rounds = profile.rounds
					local before = seenRounds[player]
					if before and rounds > before and rounds // ROUNDS_PER_SPIN > before // ROUNDS_PER_SPIN then
						addSpin(session, 1)
						task.delay(4, function()
							if player.Parent then
								ctx.toast(player, "luck_earned")
							end
						end)
					end
					seenRounds[player] = rounds
					refresh(player, session)
				end)
			end
		end
	end)

	local api = { prizes = PRIZES, spin = spin, spins = spins, addSpin = addSpin, wheel = wheel, prompt = prompt, board = board, labels = labels,
		angle = function(): number
			return angle
		end,
		pick = pick,
	}
	ctx.luck = api
	return api
end
