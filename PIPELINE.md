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
| Фидбек | `~/bin/kaneo-comment-watch.sh` | ✅ |
| Столл-детектор | `~/bin/kaneo-stall-watch.py` | ✅ |

## Целевой поток (после внедрения TODO)

```
kaneo-tick.sh (5 мин):
  1. poll: In Progress задача без ветки?
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

## Ручные роли Oleg

- Пишет задачи коротко (GLM обогащает в ТЗ — см. comment-watch)
- Смотрит прод после Done
- Комментарий = доработка
