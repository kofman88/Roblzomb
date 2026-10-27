--!strict
--[[
	ТЫКВЕННАЯ НОЧЬ (модуль Halloween): хэллоуинский ивент до 9 ноября

	КУДА ВСТАВИТЬ: это ModuleScript с именем Halloween. Он лежит ВНУТРИ главного скрипта
	(ServerScriptService -> Script -> Halloween, рядом с Extras). Запускает его модуль Extras.

	Что здесь (всё работает только в дни ивента, даты ниже):
	- в каждом раунде по городу спрятаны тыквы: на улицах, на крышах и у ящиков; одна золотая;
	- тыквы дают и за заражение, и за выживание; с другом на сервере - вдвое больше;
	- за тыквы в меню стройки продаётся ограниченный декор двора и ведьмина шляпа на персонажа.
	  После конца ивента купить нельзя, купленное остаётся навсегда;
	- все зомби ходят с горящими головами-тыквами;
	- в лобби стенд ивента: сколько дней осталось и сколько у тебя тыкв; каждый день подарок.
	Тыквы хранятся в запасах игрока (ext.items.hw_pk).
]]

local EVENT_FROM = 1792540800   -- 21.10.2026 00:00 UTC: с этого момента ивент идёт
local EVENT_TO = 1794268800     -- 10.11.2026 00:00 UTC: ивент закончился (последний день - 9 ноября)
local PER_ROUND = 11            -- сколько обычных тыкв прячется в городе за раунд
local GOLD = 5                  -- сколько тыкв даёт золотая
local FOR_CATCH = 1             -- тыкв за каждого заражённого
local FOR_WIN = 2               -- тыкв за выживание в раунде
local DAILY = 3                 -- подарок за вход раз в день
local FRIEND_MULT = 2           -- во сколько раз больше тыкв, если на сервере есть друг
local NIGHT_FROM = 1793394000   -- 31.10.2026 00:00 МСК: Хэллоуинская ночь (событие в Roblox), все тыквы ×2
local NIGHT_TO = 1793566800     -- 02.11.2026 00:00 МСК: конец Хэллоуинской ночи
local NIGHT_MULT = 2
local REACH = 5                 -- с какого расстояния тыква подбирается
local MAX = 999

-- товары ивента в меню стройки: id, цена в тыквах, как построить (координаты двора, вход смотрит на +Z)
local GOODS = { { id = "hw_lantern", cost = 12 }, { id = "hw_grave", cost = 24 }, { id = "hw_scare", cost = 36 }, { id = "hw_ghost", cost = 54 }, { id = "hw_hat", cost = 75 } } -- x3 (audit 27 Oct): the event lasts 20 days
local ICONS = { hw_lantern = "🎃", hw_grave = "💀", hw_scare = "🌽", hw_ghost = "👻", hw_hat = "🎩" }

local TEXT: { [string]: { [string]: string } } = {
	en = {
		hw_night = "🎃 HALLOWEEN NIGHT: %d pumpkins in the city, all pumpkins ×2!",
		hw_title = "🎃 PUMPKIN NIGHT",
		hw_left = "Halloween event · days left: %d",
		hw_have = "Your pumpkins: %d 🎃",
		hw_how = "Find 🎃 in the city during rounds: on roofs and streets",
		hw_board_shop = "Spend them at your house board: limited decor!",
		hw_friend = "👥 Play with a friend: ×2 🎃",
		hw_over = "The event is over. Thanks for playing!",
		hw_round = "🎃 %d pumpkins are hidden in the city!",
		hw_got = "🎃 +%d (you have %d)",
		hw_gold = "🌟 GOLDEN PUMPKIN! +%d 🎃",
		hw_gold_all = "🌟 %s found the golden pumpkin!",
		hw_catch = "🎃 +%d for the infection",
		hw_win = "🎃 +%d for surviving (you have %d)",
		hw_daily = "🎃 Halloween gift: +%d pumpkins (you have %d)",
		hw_shop = "🎃 HALLOWEEN · %d days left",
		hw_need = "🎃 You need %d more pumpkins",
		bd_hw_lantern = "Pumpkin lanterns",
		bd_hw_lanternb = "Glowing faces by the gate",
		bd_hw_grave = "Graveyard",
		bd_hw_graveb = "Three old gravestones",
		bd_hw_scare = "Scarecrow",
		bd_hw_scareb = "Guards your yard",
		bd_hw_ghost = "Ghost",
		bd_hw_ghostb = "Floats over your yard",
		bd_hw_hat = "Witch hat",
		bd_hw_hatb = "You wear it in every round",
	},
	ru = {
		hw_night = "🎃 ХЭЛЛОУИНСКАЯ НОЧЬ: в городе тыкв: %d, все тыквы ×2!",
		hw_title = "🎃 ТЫКВЕННАЯ НОЧЬ",
		hw_left = "Хэллоуин · осталось дней: %d",
		hw_have = "Твои тыквы: %d 🎃",
		hw_how = "Ищи 🎃 в городе во время раундов: на крышах и улицах",
		hw_board_shop = "Трать их у доски своего дома: декор только до 9 ноября!",
		hw_friend = "👥 С другом на сервере: ×2 🎃",
		hw_over = "Ивент закончился. Спасибо, что играл!",
		hw_round = "🎃 В городе спрятано тыкв: %d!",
		hw_got = "🎃 +%d (всего %d)",
		hw_gold = "🌟 ЗОЛОТАЯ ТЫКВА! +%d 🎃",
		hw_gold_all = "🌟 %s нашёл золотую тыкву!",
		hw_catch = "🎃 +%d за заражение",
		hw_win = "🎃 +%d за выживание (всего %d)",
		hw_daily = "🎃 Подарок Хэллоуина: +%d тыквы (всего %d)",
		hw_shop = "🎃 ХЭЛЛОУИН · осталось дней: %d",
		hw_need = "🎃 Не хватает тыкв: %d",
		bd_hw_lantern = "Тыквы-фонари",
		bd_hw_lanternb = "Светящиеся лица у ворот",
		bd_hw_grave = "Кладбище",
		bd_hw_graveb = "Три старых надгробия",
		bd_hw_scare = "Пугало",
		bd_hw_scareb = "Сторожит твой двор",
		bd_hw_ghost = "Призрак",
		bd_hw_ghostb = "Парит над двором",
		bd_hw_hat = "Шляпа ведьмы",
		bd_hw_hatb = "Носишь её в каждом раунде",
	},
	es = {
		hw_night = "🎃 NOCHE DE HALLOWEEN: %d calabazas en la ciudad, ¡todas ×2!",
		hw_title = "🎃 NOCHE DE CALABAZAS",
		hw_left = "Evento de Halloween · días restantes: %d",
		hw_have = "Tus calabazas: %d 🎃",
		hw_how = "Busca 🎃 en la ciudad durante las rondas: en techos y calles",
		hw_board_shop = "Gástalas en el tablero de tu casa: ¡decoración limitada!",
		hw_friend = "👥 Juega con un amigo: ×2 🎃",
		hw_over = "El evento terminó. ¡Gracias por jugar!",
		hw_round = "🎃 ¡Hay %d calabazas escondidas en la ciudad!",
		hw_got = "🎃 +%d (tienes %d)",
		hw_gold = "🌟 ¡CALABAZA DORADA! +%d 🎃",
		hw_gold_all = "🌟 ¡%s encontró la calabaza dorada!",
		hw_catch = "🎃 +%d por infectar",
		hw_win = "🎃 +%d por sobrevivir (tienes %d)",
		hw_daily = "🎃 Regalo de Halloween: +%d calabazas (tienes %d)",
		hw_shop = "🎃 HALLOWEEN · quedan %d días",
		hw_need = "🎃 Te faltan %d calabazas",
		bd_hw_lantern = "Linternas de calabaza",
		bd_hw_lanternb = "Caras brillantes en la entrada",
		bd_hw_grave = "Cementerio",
		bd_hw_graveb = "Tres lápidas viejas",
		bd_hw_scare = "Espantapájaros",
		bd_hw_scareb = "Vigila tu patio",
		bd_hw_ghost = "Fantasma",
		bd_hw_ghostb = "Flota sobre tu patio",
		bd_hw_hat = "Sombrero de bruja",
		bd_hw_hatb = "Lo llevas en cada ronda",
	},
	pt = {
		hw_night = "🎃 NOITE DE HALLOWEEN: %d abóboras na cidade, todas ×2!",
		hw_title = "🎃 NOITE DAS ABÓBORAS",
		hw_left = "Evento de Halloween · dias restantes: %d",
		hw_have = "Suas abóboras: %d 🎃",
		hw_how = "Procure 🎃 na cidade durante as rodadas: em telhados e ruas",
		hw_board_shop = "Gaste no quadro da sua casa: decoração limitada!",
		hw_friend = "👥 Jogue com um amigo: ×2 🎃",
		hw_over = "O evento acabou. Obrigado por jogar!",
		hw_round = "🎃 Há %d abóboras escondidas na cidade!",
		hw_got = "🎃 +%d (você tem %d)",
		hw_gold = "🌟 ABÓBORA DOURADA! +%d 🎃",
		hw_gold_all = "🌟 %s achou a abóbora dourada!",
		hw_catch = "🎃 +%d pela infecção",
		hw_win = "🎃 +%d por sobreviver (você tem %d)",
		hw_daily = "🎃 Presente de Halloween: +%d abóboras (você tem %d)",
		hw_shop = "🎃 HALLOWEEN · faltam %d dias",
		hw_need = "🎃 Faltam %d abóboras",
		bd_hw_lantern = "Lanternas de abóbora",
		bd_hw_lanternb = "Rostos brilhantes no portão",
		bd_hw_grave = "Cemitério",
		bd_hw_graveb = "Três lápides antigas",
		bd_hw_scare = "Espantalho",
		bd_hw_scareb = "Vigia o seu quintal",
		bd_hw_ghost = "Fantasma",
		bd_hw_ghostb = "Flutua sobre o quintal",
		bd_hw_hat = "Chapéu de bruxa",
		bd_hw_hatb = "Você usa em todas as rodadas",
	},
	fr = {
		hw_night = "🎃 NUIT D'HALLOWEEN : %d citrouilles en ville, toutes ×2 !",
		hw_title = "🎃 NUIT DES CITROUILLES",
		hw_left = "Événement Halloween · jours restants : %d",
		hw_have = "Tes citrouilles : %d 🎃",
		hw_how = "Trouve des 🎃 en ville pendant les manches : sur les toits et dans les rues",
		hw_board_shop = "Dépense-les au panneau de ta maison : déco limitée !",
		hw_friend = "👥 Joue avec un ami : ×2 🎃",
		hw_over = "L'événement est terminé. Merci d'avoir joué !",
		hw_round = "🎃 %d citrouilles sont cachées en ville !",
		hw_got = "🎃 +%d (tu en as %d)",
		hw_gold = "🌟 CITROUILLE DORÉE ! +%d 🎃",
		hw_gold_all = "🌟 %s a trouvé la citrouille dorée !",
		hw_catch = "🎃 +%d pour l'infection",
		hw_win = "🎃 +%d pour avoir survécu (tu en as %d)",
		hw_daily = "🎃 Cadeau d'Halloween : +%d citrouilles (tu en as %d)",
		hw_shop = "🎃 HALLOWEEN · encore %d jours",
		hw_need = "🎃 Il te manque %d citrouilles",
		bd_hw_lantern = "Citrouilles lumineuses",
		bd_hw_lanternb = "Visages brillants au portail",
		bd_hw_grave = "Cimetière",
		bd_hw_graveb = "Trois vieilles tombes",
		bd_hw_scare = "Épouvantail",
		bd_hw_scareb = "Garde ton jardin",
		bd_hw_ghost = "Fantôme",
		bd_hw_ghostb = "Flotte au-dessus du jardin",
		bd_hw_hat = "Chapeau de sorcière",
		bd_hw_hatb = "Tu le portes à chaque manche",
	},
	de = {
		hw_night = "🎃 HALLOWEEN-NACHT: %d Kürbisse in der Stadt, alle ×2!",
		hw_title = "🎃 KÜRBISNACHT",
		hw_left = "Halloween-Event · noch %d Tage",
		hw_have = "Deine Kürbisse: %d 🎃",
		hw_how = "Finde 🎃 in der Stadt während der Runden: auf Dächern und Straßen",
		hw_board_shop = "Gib sie an deiner Hausbautafel aus: limitierte Deko!",
		hw_friend = "👥 Spiel mit einem Freund: ×2 🎃",
		hw_over = "Das Event ist vorbei. Danke fürs Spielen!",
		hw_round = "🎃 In der Stadt sind %d Kürbisse versteckt!",
		hw_got = "🎃 +%d (du hast %d)",
		hw_gold = "🌟 GOLDENER KÜRBIS! +%d 🎃",
		hw_gold_all = "🌟 %s hat den goldenen Kürbis gefunden!",
		hw_catch = "🎃 +%d für die Infektion",
		hw_win = "🎃 +%d fürs Überleben (du hast %d)",
		hw_daily = "🎃 Halloween-Geschenk: +%d Kürbisse (du hast %d)",
		hw_shop = "🎃 HALLOWEEN · noch %d Tage",
		hw_need = "🎃 Dir fehlen %d Kürbisse",
		bd_hw_lantern = "Kürbislaternen",
		bd_hw_lanternb = "Leuchtende Gesichter am Tor",
		bd_hw_grave = "Friedhof",
		bd_hw_graveb = "Drei alte Grabsteine",
		bd_hw_scare = "Vogelscheuche",
		bd_hw_scareb = "Bewacht deinen Hof",
		bd_hw_ghost = "Geist",
		bd_hw_ghostb = "Schwebt über deinem Hof",
		bd_hw_hat = "Hexenhut",
		bd_hw_hatb = "Du trägst ihn in jeder Runde",
	},
	it = {
		hw_night = "🎃 NOTTE DI HALLOWEEN: %d zucche in città, tutte ×2!",
		hw_title = "🎃 NOTTE DELLE ZUCCHE",
		hw_left = "Evento di Halloween · giorni rimasti: %d",
		hw_have = "Le tue zucche: %d 🎃",
		hw_how = "Trova le 🎃 in città durante i round: sui tetti e per strada",
		hw_board_shop = "Spendile alla bacheca di casa: decorazioni limitate!",
		hw_friend = "👥 Gioca con un amico: ×2 🎃",
		hw_over = "L'evento è finito. Grazie per aver giocato!",
		hw_round = "🎃 In città ci sono %d zucche nascoste!",
		hw_got = "🎃 +%d (ne hai %d)",
		hw_gold = "🌟 ZUCCA D'ORO! +%d 🎃",
		hw_gold_all = "🌟 %s ha trovato la zucca d'oro!",
		hw_catch = "🎃 +%d per il contagio",
		hw_win = "🎃 +%d per essere sopravvissuto (ne hai %d)",
		hw_daily = "🎃 Regalo di Halloween: +%d zucche (ne hai %d)",
		hw_shop = "🎃 HALLOWEEN · ancora %d giorni",
		hw_need = "🎃 Ti mancano %d zucche",
		bd_hw_lantern = "Lanterne di zucca",
		bd_hw_lanternb = "Volti luminosi al cancello",
		bd_hw_grave = "Cimitero",
		bd_hw_graveb = "Tre vecchie lapidi",
		bd_hw_scare = "Spaventapasseri",
		bd_hw_scareb = "Sorveglia il tuo cortile",
		bd_hw_ghost = "Fantasma",
		bd_hw_ghostb = "Fluttua sul cortile",
		bd_hw_hat = "Cappello da strega",
		bd_hw_hatb = "Lo indossi in ogni round",
	},
	pl = {
		hw_night = "🎃 NOC HALLOWEEN: dyń w mieście: %d, wszystkie ×2!",
		hw_title = "🎃 NOC DYŃ",
		hw_left = "Wydarzenie Halloween · zostało dni: %d",
		hw_have = "Twoje dynie: %d 🎃",
		hw_how = "Szukaj 🎃 w mieście podczas rund: na dachach i ulicach",
		hw_board_shop = "Wydaj je przy tablicy swojego domu: limitowane ozdoby!",
		hw_friend = "👥 Graj z przyjacielem: ×2 🎃",
		hw_over = "Wydarzenie się skończyło. Dzięki za grę!",
		hw_round = "🎃 W mieście ukryto dyń: %d!",
		hw_got = "🎃 +%d (masz %d)",
		hw_gold = "🌟 ZŁOTA DYNIA! +%d 🎃",
		hw_gold_all = "🌟 %s znalazł złotą dynię!",
		hw_catch = "🎃 +%d za zarażenie",
		hw_win = "🎃 +%d za przetrwanie (masz %d)",
		hw_daily = "🎃 Prezent na Halloween: dynie +%d (masz %d)",
		hw_shop = "🎃 HALLOWEEN · zostało dni: %d",
		hw_need = "🎃 Brakuje dyń: %d",
		bd_hw_lantern = "Dyniowe lampiony",
		bd_hw_lanternb = "Świecące twarze przy bramie",
		bd_hw_grave = "Cmentarz",
		bd_hw_graveb = "Trzy stare nagrobki",
		bd_hw_scare = "Strach na wróble",
		bd_hw_scareb = "Pilnuje twojego podwórka",
		bd_hw_ghost = "Duch",
		bd_hw_ghostb = "Unosi się nad podwórkiem",
		bd_hw_hat = "Kapelusz czarownicy",
		bd_hw_hatb = "Nosisz go w każdej rundzie",
	},
	tr = {
		hw_night = "🎃 CADILAR BAYRAMI GECESİ: şehirde %d bal kabağı, hepsi ×2!",
		hw_title = "🎃 BAL KABAĞI GECESİ",
		hw_left = "Cadılar Bayramı etkinliği · kalan gün: %d",
		hw_have = "Bal kabakların: %d 🎃",
		hw_how = "Turlarda şehirde 🎃 bul: çatılarda ve sokaklarda",
		hw_board_shop = "Evinin panosunda harca: sınırlı süreli süsler!",
		hw_friend = "👥 Bir arkadaşla oyna: ×2 🎃",
		hw_over = "Etkinlik bitti. Oynadığın için teşekkürler!",
		hw_round = "🎃 Şehirde %d bal kabağı saklı!",
		hw_got = "🎃 +%d (toplam %d)",
		hw_gold = "🌟 ALTIN BAL KABAĞI! +%d 🎃",
		hw_gold_all = "🌟 %s altın bal kabağını buldu!",
		hw_catch = "🎃 Enfekte ettiğin için +%d",
		hw_win = "🎃 Hayatta kaldığın için +%d (toplam %d)",
		hw_daily = "🎃 Cadılar Bayramı hediyesi: +%d bal kabağı (toplam %d)",
		hw_shop = "🎃 CADILAR BAYRAMI · %d gün kaldı",
		hw_need = "🎃 %d bal kabağı daha lazım",
		bd_hw_lantern = "Bal kabağı fenerleri",
		bd_hw_lanternb = "Kapıda parlayan yüzler",
		bd_hw_grave = "Mezarlık",
		bd_hw_graveb = "Üç eski mezar taşı",
		bd_hw_scare = "Korkuluk",
		bd_hw_scareb = "Bahçeni korur",
		bd_hw_ghost = "Hayalet",
		bd_hw_ghostb = "Bahçenin üstünde süzülür",
		bd_hw_hat = "Cadı şapkası",
		bd_hw_hatb = "Her turda takarsın",
	},
	id = {
		hw_night = "🎃 MALAM HALLOWEEN: %d labu di kota, semua ×2!",
		hw_title = "🎃 MALAM LABU",
		hw_left = "Event Halloween · sisa hari: %d",
		hw_have = "Labumu: %d 🎃",
		hw_how = "Cari 🎃 di kota saat ronde: di atap dan jalan",
		hw_board_shop = "Belanjakan di papan rumahmu: dekorasi terbatas!",
		hw_friend = "👥 Main bareng teman: ×2 🎃",
		hw_over = "Event sudah selesai. Terima kasih sudah bermain!",
		hw_round = "🎃 Ada %d labu tersembunyi di kota!",
		hw_got = "🎃 +%d (punya %d)",
		hw_gold = "🌟 LABU EMAS! +%d 🎃",
		hw_gold_all = "🌟 %s menemukan labu emas!",
		hw_catch = "🎃 +%d karena menulari",
		hw_win = "🎃 +%d karena bertahan (punya %d)",
		hw_daily = "🎃 Hadiah Halloween: +%d labu (punya %d)",
		hw_shop = "🎃 HALLOWEEN · sisa %d hari",
		hw_need = "🎃 Kurang %d labu lagi",
		bd_hw_lantern = "Lentera labu",
		bd_hw_lanternb = "Wajah menyala di gerbang",
		bd_hw_grave = "Kuburan",
		bd_hw_graveb = "Tiga batu nisan tua",
		bd_hw_scare = "Orang-orangan sawah",
		bd_hw_scareb = "Menjaga halamanmu",
		bd_hw_ghost = "Hantu",
		bd_hw_ghostb = "Melayang di atas halaman",
		bd_hw_hat = "Topi penyihir",
		bd_hw_hatb = "Kamu pakai di setiap ronde",
	},
	vi = {
		hw_night = "🎃 ĐÊM HALLOWEEN: %d quả bí ngô trong thành phố, tất cả ×2!",
		hw_title = "🎃 ĐÊM BÍ NGÔ",
		hw_left = "Sự kiện Halloween · còn %d ngày",
		hw_have = "Bí ngô của bạn: %d 🎃",
		hw_how = "Tìm 🎃 trong thành phố khi chơi: trên mái nhà và đường phố",
		hw_board_shop = "Dùng ở bảng nhà bạn: đồ trang trí giới hạn!",
		hw_friend = "👥 Chơi cùng bạn bè: ×2 🎃",
		hw_over = "Sự kiện đã kết thúc. Cảm ơn bạn đã chơi!",
		hw_round = "🎃 Có %d quả bí ngô giấu trong thành phố!",
		hw_got = "🎃 +%d (có %d)",
		hw_gold = "🌟 BÍ NGÔ VÀNG! +%d 🎃",
		hw_gold_all = "🌟 %s đã tìm thấy bí ngô vàng!",
		hw_catch = "🎃 +%d vì lây nhiễm",
		hw_win = "🎃 +%d vì sống sót (có %d)",
		hw_daily = "🎃 Quà Halloween: +%d bí ngô (có %d)",
		hw_shop = "🎃 HALLOWEEN · còn %d ngày",
		hw_need = "🎃 Cần thêm %d bí ngô",
		bd_hw_lantern = "Đèn bí ngô",
		bd_hw_lanternb = "Khuôn mặt sáng ở cổng",
		bd_hw_grave = "Nghĩa địa",
		bd_hw_graveb = "Ba bia mộ cũ",
		bd_hw_scare = "Bù nhìn",
		bd_hw_scareb = "Canh giữ sân nhà",
		bd_hw_ghost = "Hồn ma",
		bd_hw_ghostb = "Bay lơ lửng trên sân",
		bd_hw_hat = "Mũ phù thủy",
		bd_hw_hatb = "Đội trong mọi vòng chơi",
	},
	th = {
		hw_night = "🎃 คืนฮาโลวีน: ฟักทองในเมือง %d ลูก ทุกลูก ×2!",
		hw_title = "🎃 คืนฟักทอง",
		hw_left = "อีเวนต์ฮาโลวีน · เหลืออีก %d วัน",
		hw_have = "ฟักทองของคุณ: %d 🎃",
		hw_how = "หา 🎃 ในเมืองระหว่างรอบ: บนหลังคาและถนน",
		hw_board_shop = "ใช้ที่ป้ายบ้านของคุณ: ของตกแต่งจำนวนจำกัด!",
		hw_friend = "👥 เล่นกับเพื่อน: ×2 🎃",
		hw_over = "อีเวนต์จบแล้ว ขอบคุณที่มาเล่น!",
		hw_round = "🎃 มีฟักทองซ่อนอยู่ในเมือง %d ลูก!",
		hw_got = "🎃 +%d (มี %d)",
		hw_gold = "🌟 ฟักทองทองคำ! +%d 🎃",
		hw_gold_all = "🌟 %s เจอฟักทองทองคำแล้ว!",
		hw_catch = "🎃 +%d จากการแพร่เชื้อ",
		hw_win = "🎃 +%d จากการรอดชีวิต (มี %d)",
		hw_daily = "🎃 ของขวัญฮาโลวีน: ฟักทอง +%d (มี %d)",
		hw_shop = "🎃 ฮาโลวีน · เหลือ %d วัน",
		hw_need = "🎃 ขาดฟักทองอีก %d ลูก",
		bd_hw_lantern = "โคมฟักทอง",
		bd_hw_lanternb = "หน้าเรืองแสงที่ประตู",
		bd_hw_grave = "สุสาน",
		bd_hw_graveb = "ป้ายหลุมศพเก่าสามป้าย",
		bd_hw_scare = "หุ่นไล่กา",
		bd_hw_scareb = "เฝ้าลานบ้านของคุณ",
		bd_hw_ghost = "ผี",
		bd_hw_ghostb = "ลอยอยู่เหนือลานบ้าน",
		bd_hw_hat = "หมวกแม่มด",
		bd_hw_hatb = "สวมได้ทุกรอบ",
	},
	ko = {
		hw_night = "🎃 할로윈의 밤: 도시에 호박 %d개, 모든 호박 ×2!",
		hw_title = "🎃 호박의 밤",
		hw_left = "할로윈 이벤트 · 남은 날: %d일",
		hw_have = "내 호박: %d 🎃",
		hw_how = "라운드 중 도시에서 🎃를 찾아요: 지붕과 거리에 있어요",
		hw_board_shop = "집 게시판에서 써요: 한정 장식!",
		hw_friend = "👥 친구와 함께: ×2 🎃",
		hw_over = "이벤트가 끝났어요. 플레이해 줘서 고마워요!",
		hw_round = "🎃 도시에 호박 %d개가 숨어 있어요!",
		hw_got = "🎃 +%d (보유 %d)",
		hw_gold = "🌟 황금 호박! +%d 🎃",
		hw_gold_all = "🌟 %s님이 황금 호박을 찾았어요!",
		hw_catch = "🎃 감염시켜서 +%d",
		hw_win = "🎃 살아남아서 +%d (보유 %d)",
		hw_daily = "🎃 할로윈 선물: 호박 +%d (보유 %d)",
		hw_shop = "🎃 할로윈 · %d일 남음",
		hw_need = "🎃 호박이 %d개 더 필요해요",
		bd_hw_lantern = "호박 등불",
		bd_hw_lanternb = "대문 옆에서 빛나는 얼굴",
		bd_hw_grave = "묘지",
		bd_hw_graveb = "오래된 묘비 세 개",
		bd_hw_scare = "허수아비",
		bd_hw_scareb = "마당을 지켜요",
		bd_hw_ghost = "유령",
		bd_hw_ghostb = "마당 위를 떠다녀요",
		bd_hw_hat = "마녀 모자",
		bd_hw_hatb = "모든 라운드에서 써요",
	},
	ja = {
		hw_night = "🎃 ハロウィンの夜: 街にカボチャ %d こ、ぜんぶ ×2!",
		hw_title = "🎃 カボチャの夜",
		hw_left = "ハロウィンイベント · のこり %d 日",
		hw_have = "カボチャ: %d 🎃",
		hw_how = "ラウンド中に街で🎃を探そう: 屋根の上や道にあるよ",
		hw_board_shop = "家の看板で使おう: 期間限定のかざり!",
		hw_friend = "👥 フレンドと遊ぶと ×2 🎃",
		hw_over = "イベントは終わりました。遊んでくれてありがとう!",
		hw_round = "🎃 街にカボチャが %d こかくれているよ!",
		hw_got = "🎃 +%d (いま %d)",
		hw_gold = "🌟 金のカボチャ! +%d 🎃",
		hw_gold_all = "🌟 %s が金のカボチャを見つけた!",
		hw_catch = "🎃 感染させて +%d",
		hw_win = "🎃 生きのこって +%d (いま %d)",
		hw_daily = "🎃 ハロウィンのプレゼント: カボチャ +%d (いま %d)",
		hw_shop = "🎃 ハロウィン · のこり %d 日",
		hw_need = "🎃 カボチャがあと %d こ必要",
		bd_hw_lantern = "カボチャのランタン",
		bd_hw_lanternb = "門のそばで光る顔",
		bd_hw_grave = "お墓",
		bd_hw_graveb = "古いお墓が三つ",
		bd_hw_scare = "かかし",
		bd_hw_scareb = "庭を見はってくれる",
		bd_hw_ghost = "おばけ",
		bd_hw_ghostb = "庭の上をふわふわ",
		bd_hw_hat = "魔女のぼうし",
		bd_hw_hatb = "毎ラウンドかぶれるよ",
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
	local homes = sv.homes
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
	local warned: { [string]: number } = {}
	local function safely(what: string, action: () -> ())
		local ok, err = (pcall :: any)(action)
		if not ok and os.clock() - (warned[what] or -100) > 60 then
			warned[what] = os.clock()
			warn("[Zombie Tag] Halloween (" .. what .. "): " .. tostring(err))
		end
	end
	local function active(): boolean
		local now = os.time()
		return now >= EVENT_FROM and now < EVENT_TO
	end
	local function daysLeft(): number
		return math.max(0, math.ceil((EVENT_TO - os.time()) / 86400))
	end
	local function trusted(session: any): boolean
		return session.canSave or not ctx.saveBroken()
	end
	local function items(session: any): { [string]: number }
		return sv.stock(session).items
	end
	local function pumpkins(session: any): number
		return items(session).hw_pk or 0
	end
	local function addPumpkins(session: any, n: number): number
		local raw: any = items(session)
		local have = math.clamp((raw.hw_pk or 0) + n, 0, MAX)
		raw.hw_pk = if have > 0 then have else nil
		return have
	end

	---------------------------------------------------------------------
	-- ТЫКВА: одна заготовка для улиц, двора, лобби и голов зомби
	---------------------------------------------------------------------
	local ORANGE = Color3.fromRGB(255, 124, 26)
	local GOLDEN = Color3.fromRGB(255, 205, 50)
	local FIRE = Color3.fromRGB(255, 220, 90)
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		return p
	end
	-- cf - центр тыквы, лицо смотрит по cf.LookVector; k - размер (1 = 2.4 студа в ширину)
	local function pumpkin(cf: CFrame, k: number, parent: Instance, color: Color3?, lit: boolean?): Model
		local model = Instance.new("Model")
		model.Name = "Pumpkin"
		local tone = color or ORANGE
		local dark = Color3.new(tone.R * 0.86, tone.G * 0.8, tone.B * 0.8)
		local core = piece("Core", Vector3.new(2.0 * k, 1.9 * k, 2.2 * k), cf, tone, Enum.Material.SmoothPlastic, model, Enum.PartType.Ball)
		piece("Lobe", Vector3.new(1.5 * k, 1.8 * k, 2.1 * k), cf * CFrame.new(-0.55 * k, -0.02 * k, 0), dark, Enum.Material.SmoothPlastic, model, Enum.PartType.Ball)
		piece("Lobe", Vector3.new(1.5 * k, 1.8 * k, 2.1 * k), cf * CFrame.new(0.55 * k, -0.02 * k, 0), dark, Enum.Material.SmoothPlastic, model, Enum.PartType.Ball)
		piece("Stem", Vector3.new(0.6 * k, 0.28 * k, 0.28 * k), cf * CFrame.new(0, 1.05 * k, 0) * CFrame.Angles(0, 0, math.rad(80)), Color3.fromRGB(70, 110, 40), Enum.Material.Wood, model, Enum.PartType.Cylinder)
		-- лицо: глаза-ромбы и улыбка светятся изнутри
		local front = -1.04 * k
		for _, x in ipairs({ -0.42, 0.42 }) do
			piece("Eye", Vector3.new(0.34 * k, 0.34 * k, 0.12 * k), cf * CFrame.new(x * k, 0.22 * k, front) * CFrame.Angles(0, 0, math.rad(45)), FIRE, Enum.Material.Neon, model)
		end
		piece("Mouth", Vector3.new(0.95 * k, 0.2 * k, 0.12 * k), cf * CFrame.new(0, -0.32 * k, front + 0.02 * k), FIRE, Enum.Material.Neon, model)
		for _, x in ipairs({ -0.3, 0.3 }) do
			piece("Tooth", Vector3.new(0.18 * k, 0.18 * k, 0.12 * k), cf * CFrame.new(x * k, -0.2 * k, front) * CFrame.Angles(0, 0, math.rad(45)), FIRE, Enum.Material.Neon, model)
		end
		if lit then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 60)
			light.Range = 10 * math.max(1, k)
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = core
		end
		model.PrimaryPart = core
		model.Parent = parent
		return model
	end

	---------------------------------------------------------------------
	-- ДЕКОР ДВОРА (меню стройки, модуль Homes) и ведьмина шляпа
	---------------------------------------------------------------------
	local kit = homes and homes.kit
	local function goodShown(id: string): (any) -> boolean
		return function(ext: any): boolean
			return active() or (ext ~= nil and (ext.items["d_" .. id] or 0) > 0)
		end
	end
	local builders: { [string]: (any, Instance) -> () } = {}
	if kit then
		local at, point = kit.at, kit.point
		local STONE = Color3.fromRGB(128, 128, 136)
		local DIRT = Color3.fromRGB(72, 56, 42)
		builders.hw_lantern = function(site: any, parent: Instance)
			-- у дома - по сторонам дорожки (их видно и из-за стены крепости), в логове - у края ниши
			local house = site.kind == "house"
			local sx, sz = if house then 3.7 else 7.6, if house then 7.6 else 11.2
			for _, x in ipairs({ -sx, sx }) do
				local spot = point(site, x, 0.8, sz)
				pumpkin(CFrame.lookAt(spot, spot + Vector3.new(0, 0, site.f)), 0.8, parent, nil, x < 0)
			end
			local small = if house then point(site, 4.9, 0.5, 8.7) else point(site, 6.3, 0.5, 11.9)
			pumpkin(CFrame.lookAt(small, small + Vector3.new(0.4, 0, site.f)), 0.5, parent)
		end
		builders.hw_grave = function(site: any, parent: Instance)
			for _, z in ipairs({ -6, -2.6, 0.8 }) do
				local stone = kit.solid("Grave", Vector3.new(2.2, 2.2, 0.6), at(site, -12.2, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), STONE, Enum.Material.Slate, parent)
				stone.CanQuery = false
				piece("GraveTop", Vector3.new(0.6, 2.2, 2.2), at(site, -12.2, 2.2, z), STONE, Enum.Material.Slate, parent, Enum.PartType.Cylinder)
				piece("Mound", Vector3.new(1.8, 0.5, 3), at(site, -10.6, 0.25, z), DIRT, Enum.Material.Ground, parent)
			end
			local glow = piece("GraveGlow", Vector3.new(0.5, 0.5, 0.5), at(site, -11, 0.6, -2.6), Color3.fromRGB(140, 255, 160), Enum.Material.Neon, parent, Enum.PartType.Ball)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(140, 255, 160)
			light.Range = 9
			light.Brightness = 1
			light.Parent = glow
		end
		builders.hw_scare = function(site: any, parent: Instance)
			local wood = Color3.fromRGB(120, 88, 56)
			kit.solid("ScarePost", Vector3.new(0.45, 6.4, 0.45), at(site, 12.4, 3.2, -2.6), wood, Enum.Material.Wood, parent)
			piece("ScareArms", Vector3.new(5, 0.4, 0.4), at(site, 12.4, 4.6, -2.6), wood, Enum.Material.Wood, parent)
			piece("ScareShirt", Vector3.new(2.2, 2.4, 1.1), at(site, 12.4, 4.2, -2.6), Color3.fromRGB(170, 60, 50), Enum.Material.Fabric, parent)
			for _, x in ipairs({ -2.6, 2.6 }) do
				piece("Straw", Vector3.new(0.5, 0.8, 0.5), at(site, 12.4 + x, 4.3, -2.6), Color3.fromRGB(230, 196, 90), Enum.Material.Grass, parent)
			end
			local head = point(site, 12.4, 6.3, -2.6)
			pumpkin(CFrame.lookAt(head, head + Vector3.new(0, 0, site.f)), 0.62, parent)
			piece("HatBrim", Vector3.new(0.15, 2.4, 2.4), CFrame.new(head + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 170, 90), Enum.Material.Fabric, parent, Enum.PartType.Cylinder)
			piece("HatTop", Vector3.new(0.7, 1.3, 1.3), CFrame.new(head + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 170, 90), Enum.Material.Fabric, parent, Enum.PartType.Cylinder)
		end
		builders.hw_ghost = function(site: any, parent: Instance)
			local base = point(site, 6.5, 7.2, 8.5)
			local ghost = Instance.new("Model")
			ghost.Name = "Ghost"
			local body = piece("GhostBody", Vector3.new(2.2, 2.6, 2.2), CFrame.new(base), Color3.fromRGB(240, 246, 255), Enum.Material.Neon, ghost, Enum.PartType.Ball)
			body.Transparency = 0.3
			local tail = piece("GhostTail", Vector3.new(1.6, 1.6, 1.6), CFrame.new(base + Vector3.new(0, -1.4, 0.3 * site.f)), Color3.fromRGB(240, 246, 255), Enum.Material.Neon, ghost, Enum.PartType.Ball)
			tail.Transparency = 0.45
			for _, x in ipairs({ -0.45, 0.45 }) do
				piece("GhostEye", Vector3.new(0.38, 0.55, 0.2), CFrame.new(base + Vector3.new(x * site.f, 0.3, 1.05 * site.f)), Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic, ghost)
			end
			piece("GhostMouth", Vector3.new(0.5, 0.4, 0.2), CFrame.new(base + Vector3.new(0, -0.35, 1.05 * site.f)), Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic, ghost)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(190, 210, 255)
			light.Range = 10
			light.Brightness = 0.8
			light.Parent = body
			ghost.PrimaryPart = body
			ghost.Parent = parent
			-- призрак медленно парит вверх-вниз
			task.spawn(function()
				local t = math.random() * 6
				while ghost.Parent do
					t += 0.1
					safely("ghost", function()
						ghost:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 0.9) * 0.7, 0)) * CFrame.Angles(0, math.sin(t * 0.4) * 0.5, 0))
					end)
					task.wait(0.1)
				end
			end)
		end
		builders.hw_hat = function(_site: any, _parent: Instance) end -- шляпа на персонаже, во дворе её нет
		local function header(player: Player): string
			return ctx.tr(player, "hw_shop", daysLeft())
		end
		for _, good in ipairs(GOODS) do
			for _, list in ipairs({ homes.decor, homes.nestDecor }) do
				table.insert(list, {
					id = good.id, cost = good.cost, kind = "event", build = builders[good.id],
					cur = "hw_pk", icon = ICONS[good.id], need = "hw_need", head = header,
					shown = goodShown(good.id), open = active,
				})
			end
		end
	end
	-- ведьмина шляпа: чёрный конус с оранжевой лентой; держится на голове
	local function hat(head: BasePart): Model
		local model = Instance.new("Model")
		model.Name = "ZT_WitchHat"
		local k = math.max(head.Size.X, head.Size.Y) / 1.2
		local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.05 * k, 0)
		local black = Color3.fromRGB(34, 26, 44)
		piece("Brim", Vector3.new(0.12 * k, 2.4 * k, 2.4 * k), top * CFrame.Angles(0, 0, math.rad(90)), black, Enum.Material.Fabric, model, Enum.PartType.Cylinder)
		piece("Band", Vector3.new(0.3 * k, 1.38 * k, 1.38 * k), top * CFrame.new(0, 0.2 * k, 0) * CFrame.Angles(0, 0, math.rad(90)), ORANGE, Enum.Material.Fabric, model, Enum.PartType.Cylinder)
		local sizes = { { 0.55, 1.3 }, { 0.5, 1.0 }, { 0.45, 0.7 }, { 0.45, 0.42 } }
		local y = 0.1
		for i, s in ipairs(sizes) do
			y += s[1] / 2
			piece("Cone" .. i, Vector3.new(s[1] * k, s[2] * k, s[2] * k), top * CFrame.new(-0.06 * i * k, y * k, 0.05 * i * k) * CFrame.Angles(0, 0, math.rad(90 + i * 4)), black, Enum.Material.Fabric, model, Enum.PartType.Cylinder)
			y += s[1] / 2
		end
		return model
	end
	-- прикрепить модель к голове: части без массы и столкновений, держатся сваркой
	local function wear(model: Model, head: BasePart, character: Instance)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = head
				weld.Part1 = d
				weld.Parent = d
			end
		end
		model.Parent = character
	end

	---------------------------------------------------------------------
	-- ТЫКВЫ В ГОРОДЕ: появляются с началом раунда, исчезают с его концом
	---------------------------------------------------------------------
	local folder = Instance.new("Model")
	folder.Name = "Pumpkins"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Parent = map
	local rng = Random.new()
	local placed: { { model: Model, at: Vector3, gold: boolean } } = {}
	local roundOf = -1
	local function clear()
		for _, p in ipairs(placed) do
			p.model:Destroy()
		end
		table.clear(placed)
	end
	local function free(at: Vector3): boolean
		for _, p in ipairs(placed) do
			if (p.at - at).Magnitude < 14 then
				return false
			end
		end
		return true
	end
	local function put(at: Vector3, gold: boolean)
		local center = at + Vector3.new(0, 0.95 * (if gold then 1.15 else 1), 0)
		local turn = rng:NextNumber(0, math.pi * 2)
		local model = pumpkin(CFrame.new(center) * CFrame.Angles(0, turn, 0), if gold then 1.15 else 1, folder, if gold then GOLDEN else nil, true)
		if gold then
			local beam = sv.ray(model, at, 70, 1.2, GOLDEN)
			beam.Transparency = 0.55
			local sparkle = Instance.new("Sparkles")
			sparkle.SparkleColor = GOLDEN
			sparkle.Parent = model.PrimaryPart
		end
		table.insert(placed, { model = model, at = center, gold = gold })
	end
	local function spawnAll()
		clear()
		local spots = {}
		for _, s in ipairs(sv.spots or {}) do
			table.insert(spots, s)
		end
		-- перемешать места ящиков: крыши, прилавки, контейнеры
		for i = #spots, 2, -1 do
			local j = rng:NextInteger(1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		-- золотая - на самой высокой свободной крыше из первых попавшихся
		local goldAt: Vector3? = nil
		for _, s in ipairs(spots) do
			if s.level >= 2 and not s.busy then
				goldAt = s.at
				break
			end
		end
		if goldAt then
			put(goldAt, true)
		end
		local want = PER_ROUND
		local onRoofs = math.ceil(want * 0.6)
		for _, s in ipairs(spots) do
			if #placed - (if goldAt then 1 else 0) >= onRoofs then
				break
			end
			-- рядом с ящиком, а не в нём: на 2.6 студа в сторону, если там есть место
			local at = s.at + Vector3.new(0, 0, 2.6)
			if not s.busy and free(at) then
				put(at, false)
			end
		end
		-- остальные - на улицах: недалеко от перекрёстков, вдоль дороги
		local tries = 0
		while #placed - (if goldAt then 1 else 0) < want and tries < 60 do
			tries += 1
			local cross: Vector3 = ctx.randomSpawn()
			local shift = rng:NextNumber(11, 20) * (if rng:NextNumber() < 0.5 then -1 else 1)
			local along = if rng:NextNumber() < 0.5 then Vector3.new(shift, 0, 0) else Vector3.new(0, 0, shift)
			local at = Vector3.new(cross.X, cross.Y - 3, cross.Z) + along + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, 0)
			if free(at) then
				put(at, false)
			end
		end
	end
	local function burst(at: Vector3, color: Color3)
		local p = piece("PumpkinPop", Vector3.new(0.5, 0.5, 0.5), CFrame.new(at), color, Enum.Material.Neon, folder)
		p.Transparency = 1
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(color)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
		fx.Lifetime = NumberRange.new(0.6, 1.1)
		fx.Speed = NumberRange.new(8, 16)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Rate = 0
		fx.Parent = p
		fx:Emit(24)
		task.delay(1.5, function()
			p:Destroy()
		end)
	end
	-- сколько тыкв даёт награда: вдвое больше, если на сервере есть друг
	local function night(): boolean
		local now = os.time()
		return now >= NIGHT_FROM and now < NIGHT_TO
	end
	local function gain(session: any, n: number): number
		return n * (if session.friendBoost then FRIEND_MULT else 1) * (if night() then NIGHT_MULT else 1)
	end
	local function collect(player: Player, session: any, index: number)
		local p = placed[index]
		table.remove(placed, index)
		local n = gain(session, if p.gold then GOLD else 1)
		local have = addPumpkins(session, n)
		burst(p.at, if p.gold then GOLDEN else ORANGE)
		p.model:Destroy()
		if p.gold then
			ctx.big(player, "hw_gold", n)
			ctx.sound(player, "win")
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player and ctx.inRound[other] then
					ctx.toast(other, "hw_gold_all", player.DisplayName)
				end
			end
		else
			ctx.toast(player, "hw_got", n, have)
			ctx.sound(player, "coin")
		end
	end

	---------------------------------------------------------------------
	-- ГОЛОВЫ-ТЫКВЫ У ЗОМБИ И ШЛЯПЫ У ВЛАДЕЛЬЦЕВ
	---------------------------------------------------------------------
	local function headOf(character: Instance?): BasePart?
		if not character then
			return nil
		end
		local head = character:FindFirstChild("Head")
		return if head and head:IsA("BasePart") then head else nil
	end
	-- голова-тыква лежит не в персонаже, а в своей папке (держится сваркой): зелёная подсветка зомби её не красит
	local headsFolder = Instance.new("Folder")
	headsFolder.Name = "PumpkinHeads"
	headsFolder.Parent = map
	local worn: { [Instance]: Model } = {}
	local function setPumpkinHead(character: Instance?, on: boolean)
		if not character then
			return
		end
		local old: Model? = worn[character]
		if old and old.Parent == nil then
			worn[character] = nil
			old = nil
		end
		if on and not old then
			local head = headOf(character)
			if not head then
				return
			end
			local k = math.max(head.Size.X, head.Size.Y) / 1.2 * 0.9
			local model = pumpkin(head.CFrame * CFrame.new(0, 0.12 * k, 0), k, headsFolder, nil, false)
			model.Name = "ZT_PumpkinHead"
			wear(model, head, headsFolder)
			worn[character] = model
		elseif not on and old then
			old:Destroy()
			worn[character] = nil
		end
	end
	local function pumpkinHeadOf(character: Instance?): Model?
		local model = if character then worn[character] else nil
		return if model and model.Parent then model else nil
	end
	local function setHat(character: Instance?, on: boolean)
		local head = headOf(character)
		if not head or not character then
			return
		end
		local old = character:FindFirstChild("ZT_WitchHat")
		if on and not old then
			wear(hat(head), head, character)
		elseif not on and old then
			old:Destroy()
		end
	end
	local function dressAll()
		local on = active()
		-- персонаж исчез (вышел, переродился): его тыква тоже
		for character, model in pairs(worn) do
			if character.Parent == nil or not headOf(character) then
				model:Destroy()
				worn[character] = nil
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessions[player]
			local zombie = ctx.isZombie[player] == true and ctx.inRound[player] == true
			local character = player.Character
			setPumpkinHead(character, on and zombie)
			local owns = session ~= nil and (items(session).d_hw_hat or 0) > 0
			-- шляпа видна, пока не тыква на голове (у зомби её заменяет тыква)
			setHat(character, owns and not (on and zombie))
		end
		for _, bot in ipairs(ctx.bots or {}) do
			if bot.model and bot.model.Parent then
				setPumpkinHead(bot.model, on and bot.alive and bot.zombie)
			end
		end
	end

	---------------------------------------------------------------------
	-- СТЕНД ИВЕНТА В ЛОББИ
	---------------------------------------------------------------------
	local FLOOR = LOBBY_Y + 0.5
	local STAND = Vector3.new(24, FLOOR, 10)
	local face = Vector3.new(0 - STAND.X, 0, 26 - STAND.Z).Unit
	local lobby = Instance.new("Model")
	lobby.Name = "HalloweenLobby"
	lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local boardCF = CFrame.lookAt(STAND + Vector3.new(0, 5.4, 0), STAND + Vector3.new(0, 5.4, 0) + face)
	local board = piece("HalloweenBoard", Vector3.new(10, 6, 0.4), boardCF, Color3.fromRGB(16, 10, 24), Enum.Material.SmoothPlastic, lobby)
	piece("HalloweenTrim", Vector3.new(10.6, 6.6, 0.3), boardCF * CFrame.new(0, 0, 0.15), ORANGE, Enum.Material.Neon, lobby)
	local right = Vector3.new(-face.Z, 0, face.X) -- правая сторона доски (как RightVector)
	for _, side in ipairs({ -4.3, 4.3 }) do
		local leg = STAND + right * side + Vector3.new(0, 1.2, 0) - face * 0.3
		piece("HalloweenLeg", Vector3.new(0.5, 2.4, 0.5), CFrame.new(leg), Color3.fromRGB(60, 40, 70), Enum.Material.Wood, lobby)
	end
	-- горка тыкв у стенда и по углам макета города
	for i, spot in ipairs({ { -3.4, 1.1 }, { 3.6, 1.0 }, { -2.2, 0.75 } }) do
		local at = STAND + right * spot[1] + face * (2.2 + i * 0.4) + Vector3.new(0, spot[2] * 0.95, 0)
		pumpkin(CFrame.lookAt(at, at + face), spot[2], lobby)
	end
	for _, corner in ipairs({ { -17, -15 }, { 17, -15 }, { -17, 19 }, { 17, 19 } }) do
		local at = Vector3.new(corner[1], FLOOR + 0.9, corner[2])
		pumpkin(CFrame.lookAt(at, Vector3.new(0, at.Y, 26)), 0.95, lobby, nil, true)
	end
	local labels: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
	local function text(parent: Instance, name: string, y: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.04, y)
		t.Size = UDim2.fromScale(0.92, h)
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.4
		t.Text = ""
		t.Parent = parent
		return t
	end
	local function set(label: TextLabel, value: string)
		if label.Text ~= value then
			label.Text = value
		end
	end
	local function refresh(player: Player, session: any)
		local ui = labels[player]
		if not ui or not ui.gui.Parent then
			local holder = player:FindFirstChild("PlayerGui")
			if not holder then
				return
			end
			local gui = Instance.new("SurfaceGui")
			gui.Name = "ZT_HalloweenBoard"
			gui.Adornee = board
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.LightInfluence = 0
			gui.ResetOnSpawn = false
			ui = {
				gui = gui,
				title = text(gui, "Title", 0.04, 0.2, Enum.Font.GothamBlack, Color3.fromRGB(255, 150, 40)),
				left = text(gui, "Left", 0.26, 0.12, Enum.Font.GothamBold, Color3.fromRGB(230, 210, 255)),
				have = text(gui, "Have", 0.41, 0.17, Enum.Font.GothamBlack, Color3.fromRGB(255, 225, 120)),
				how = text(gui, "How", 0.61, 0.11, Enum.Font.GothamBold, Color3.new(1, 1, 1)),
				shop = text(gui, "Shop", 0.74, 0.1, Enum.Font.GothamBold, Color3.fromRGB(255, 190, 120)),
				friend = text(gui, "Friend", 0.86, 0.09, Enum.Font.Gotham, Color3.fromRGB(160, 255, 170)),
			}
			gui.Parent = holder
			labels[player] = ui
		end
		set(ui.title, ctx.tr(player, "hw_title"))
		if active() then
			set(ui.left, ctx.tr(player, "hw_left", daysLeft()))
			set(ui.how, ctx.tr(player, "hw_how"))
			set(ui.shop, ctx.tr(player, "hw_board_shop"))
			set(ui.friend, ctx.tr(player, "hw_friend") .. (if session.friendBoost then " ✔" else ""))
		else
			set(ui.left, ctx.tr(player, "hw_over"))
			set(ui.how, "")
			set(ui.shop, "")
			set(ui.friend, "")
		end
		set(ui.have, ctx.tr(player, "hw_have", pumpkins(session)))
	end

	---------------------------------------------------------------------
	-- ЦИКЛЫ: тыквы в раунде (часто), награды и надписи (раз в секунду)
	---------------------------------------------------------------------
	task.spawn(function()
		while true do
			task.wait(0.25)
			safely("round", function()
				local roundActive, _, roundId = ctx.state()
				if roundActive and active() then
					if roundOf ~= roundId then
						roundOf = roundId
						spawnAll()
						local count = #placed
						for _, player in ipairs(Players:GetPlayers()) do
							local session = sessions[player]
							if session and ctx.inRound[player] and session.profile.rounds > 0 then
								task.delay(7, function()
									if player.Parent and ctx.inRound[player] then
										ctx.toast(player, if night() then "hw_night" else "hw_round", count)
									end
								end)
							end
						end
					end
					for _, player in ipairs(Players:GetPlayers()) do
						local session = sessions[player]
						local root = ctx.getAlive(player)
						if session and root and ctx.inRound[player] and trusted(session) then
							for i = #placed, 1, -1 do
								local p = placed[i]
								local d = p.at - root.Position
								if Vector3.new(d.X, 0, d.Z).Magnitude <= REACH and math.abs(d.Y) <= 6 then
									collect(player, session, i)
								end
							end
						end
					end
				elseif #placed > 0 then
					clear()
					roundOf = if roundActive then roundId else -1
				end
			end)
		end
	end)
	local seen: { [Player]: { rounds: number, catches: number, wins: number } } = setmetatable({}, { __mode = "k" }) :: any
	task.spawn(function()
		while true do
			task.wait(1)
			safely("dress", dressAll)
			for _, player in ipairs(Players:GetPlayers()) do
				safely("tick", function()
					local session = sessions[player]
					if not session then
						return
					end
					local profile = session.profile
					local was = seen[player]
					local now = { rounds = profile.rounds, catches = profile.infections, wins = profile.wins }
					seen[player] = now
					if active() and trusted(session) then
						local list = items(session)
						-- подарок дня: вместе с ежедневной наградой игры (она меняет lastDaily)
						if profile.lastDaily > 0 then
							local mark = profile.lastDaily % 997 + 1
							if list.hw_d ~= mark then
								list.hw_d = mark
								local n = addPumpkins(session, DAILY)
								task.delay(if profile.rounds > 0 then 14 else 60, function()
									if player.Parent then
										ctx.toast(player, "hw_daily", DAILY, n)
									end
								end)
							end
						end
						if was then
							local caught = now.catches - was.catches
							if caught > 0 and caught < 20 then
								local n = gain(session, caught * FOR_CATCH)
								addPumpkins(session, n)
								task.delay(1.5, function()
									if player.Parent then
										ctx.toast(player, "hw_catch", n)
									end
								end)
							end
							local won = now.wins - was.wins
							if won > 0 and won < 5 then
								local n = gain(session, won * FOR_WIN)
								local have = addPumpkins(session, n)
								task.delay(3, function()
									if player.Parent then
										ctx.toast(player, "hw_win", n, have)
									end
								end)
							end
						end
					end
					refresh(player, session)
				end)
			end
		end
	end)
	lobby.Parent = if active() then map else nil

	local api = {
		active = active, daysLeft = daysLeft, placed = placed, pumpkins = pumpkins, addPumpkins = addPumpkins,
		spawnAll = spawnAll, clear = clear, dress = dressAll, board = board, labels = labels, lobby = lobby, goods = GOODS,
		builders = builders, pumpkin = pumpkin, headOf = pumpkinHeadOf, night = night, from = EVENT_FROM, to = EVENT_TO,
		show = function(on: boolean)
			lobby.Parent = if on then map else nil
		end,
	}
	ctx.halloween = api
	return api
end
