# Воплощение ролей в VPS-скриптах (текущее состояние)

Соответствие документации реальным скриптам на VPS:

| Роль | Реализация | Статус |
|------|-----------|--------|
| Planner | `agents/planner.md` + GLM-5.3 через omp **[TODO: вклинить перед Builder]** | 📝 спроектировано |
| Writer | `agents/writer.md` + генерация PR title/body в `kaneo-auto-merge.sh` (сейчас `--fill`) **[TODO]** | 📝 спроектировано |
| Builder | `~/bin/kaneo-task-runner.sh` → omp mimo-v2.5 `--auto-approve` | ✅ работает |
| Verifier (код) | `~/bin/kaneo-reviewer.py` (glm-5.3) **[TODO: встроить после omp, до мержа]** | 📝 частично |
| Verifier (визуал) | `~/bin/kaneo-visual-check.py` (Playwright + glm-5.3-flash) **[TODO: после деплоя]** | 📝 частично |
| Поллер | `~/bin/kaneo-poll.sh` (systemd timer 5 мин) | ✅ |
| Очередь | `~/bin/kaneo-queue.sh` (очередь задач, приоритет над To Do) | ✅ |
| Фидбек | `~/bin/kaneo-comment-watch.sh` | ✅ |
| Столл-детектор | `~/bin/kaneo-stall-watch.py` | ✅ |

## Целевой поток (после внедрения TODO)

```
kaneo-tick.sh (5 мин):
  1. poll:
     a. очередь (kaneo-queue.sh process) → готовая задача? Запустить.
     b. иначе: To Do на доске → первая задача в In Progress.
  2. PLANNER: glm-5.3 -> план (в переменную пайплайна)
  3. WRITER: ветка get-N + PR title/body файлы
  4. BUILDER: kaneo-task-runner.sh (omp кодит, пушит)
  5. VERIFIER-code: kaneo-reviewer.py
     FAIL -> комментарий + In Progress, стоп
  6. merge + deploy (kaneo-auto-merge.sh)
  7. VERIFIER-visual: kaneo-visual-check.py (если UI-таск)
     FAIL -> комментарий + In Progress, revert деплоя опционально
  8. Done
```

## Очередь задач

`kaneo-queue.sh` позволяет ставить задачи в очередь с немедленной обработкой или по расписанию.
Очередь имеет приоритет над обычным сканированием «To Do» на доске.

```bash
# Немедленно (следующий тик крона обработает)
kaneo-queue.sh add <taskId>

# По расписанию (обработка в указанное время)
kaneo-queue.sh add <taskId> "2026-09-21 02:00"

# Просмотр очереди
kaneo-queue.sh list

# Убрать из очереди
kaneo-queue.sh remove <taskId>

# Ручная обработка (обычно вызывается кроном)
kaneo-queue.sh process
```

Файл очереди: `~/.kaneo-runner.log.queue`. Записи старше 48ч автоматически удаляются.

## Запуск проекта в пайплайн

`~/bin/kaneo-schedule.sh` — ставит все to-do задачи проекта в очередь.

```
kaneo-schedule.sh <проект> [режим]

Режимы:
  (пусто)             — dry run: показать задачи
  now                 — все в очередь, поллер возьмёт при следующем тике
  run                 — первая задача сразу In Progress + runner, остальные в очередь
  YYYY-MM-DD HH:MM    — все задачи на указанное время
```

Примеры:
```bash
kaneo-schedule.sh prodcastr                    # посмотреть что есть
kaneo-schedule.sh prodcastr now                # поставить всё в очередь
kaneo-schedule.sh prodcastr run                # запустить первую сразу
kaneo-schedule.sh prodcastr "2026-09-21 03:00" # поставить на 3 часа ночи
```

Очередь: `~/.kaneo-runner.log.queue` (поллер `kaneo-poll.sh` проверяет очередь первым делом).
Просмотр очереди: `kaneo-queue.sh list`

## Ручные роли Oleg

- Пишет задачи коротко (GLM обогащает в ТЗ — см. comment-watch)
- Запускает проекты: `kaneo-schedule.sh <slug> now|run|время`
- Смотрит прод после Done
- Комментарий = доработка
- Ставит задачи в очередь через `kaneo-queue.sh add` (немедленно или на ночь)
