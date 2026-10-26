# ZOMBLOCK — код игры

Скрипты игры в виде проекта Rojo: код хранится в файлах и в Git, а не только внутри Studio.

## Как подключить
1. Установи Rojo (плагин Studio + `rojo` через Aftman: `aftman install`).
2. В этой папке: `rojo serve`.
3. В Studio: плагин Rojo -> Connect. Скрипты из `src/` синхронизируются в игру.

Карта, модели, материалы и звуки живут в самом месте (.rbxl) — Rojo управляет только скриптами
(`$ignoreUnknownInstances` оставляет всё остальное как есть).

## Где что
| Папка | Что внутри |
| --- | --- |
| `src/server/Main/` | главный серверный скрипт (`init.server.luau`) и его модули |
| `src/server/*.server.luau` | отдельные серверные скрипты: Looks, Toxic, Ideas, ArtBible, ZT_Analytics |
| `src/client/` | клиентские скрипты (StarterPlayerScripts) |
| `src/character/` | Animate-заглушка (свои анимации — в ZT_Art) |

Линтер: `selene src`, форматтер: `stylua src`.
