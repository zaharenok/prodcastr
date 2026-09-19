# prodcastr — Flutter-клиент для self-hosted Kaneo (iOS/Android)

## Context

У пользователя стоит self-hosted Kaneo (docker, `~/docker/kaneo`, контейнер `kaneo-kaneo-1`, образ `ghcr.io/usekaneo/kaneo:latest`, nginx + postgres) по адресу `http://100.116.28.100:3012` (Tailscale IP). Нужено мобильное приложение **prodcastr** на Flutter: ввод IP инстанса → вход → просмотр проектов и канбан-досок → первая фича: «залогиниться в GitHub» и визардом подтянуть нужные GitHub-репозитории в Kaneo как проекты (с импортом issues в задачи).

Разработка и сборка — на локальной машине пользователя; VPS содержит только git-репо и используется для `flutter analyze`/`flutter test` и smoke-тестов против живого Kaneo (Flutter SDK ставим на VPS, Android SDK — нет).

Ключевой факт разведки: **GitHub-интеграция уже полностью реализована в сервере Kaneo** (GitHub App `kaneo-local-oleg`, APP_ID 4998683, приватный ключ уже в контейнере). Приложение не реализует импорт само — оно управляет готовым серверным API. Вход в Kaneo через GitHub OAuth на инстансе НЕ настроен (`GET /api/config` → `hasGithubSignIn:false`), поэтому вход в prodcastr — email/password, а «GitHub-логин» — это установка GitHub App + выбор репо (решение пользователя).

## Kaneo API contract (проверено curl'ом против живого инстанса)

Base: `<instanceUrl>/api`. Все приватные роуты: `Authorization: Bearer <token>`. OpenAPI-спека доступна: `GET /api/openapi` (сохранена в `/tmp/openapi2.json` на время планирования; при реализации взять живую).

| Что | Запрос | Ответ/заметки |
|---|---|---|
| Health | `GET /api/health` | `{"status":"ok"}`, без auth — проверка URL при онбординге |
| Config | `GET /api/config` | публичный; `hasGithubSignIn:false` здесь |
| Sign in | `POST /api/auth/sign-in/email` `{email,password}` | 200 → better-auth стандарт `{token, user:{id,email,name,...}}`; 401 → `{code:"INVALID_EMAIL_OR_PASSWORD"}` |
| Sign up (для smoke-тестов) | `POST /api/auth/sign-up/email` `{name,email,password}` | регистрация открыта (`disableRegistration:false`) |
| Organizations (=workspaces) | `GET /api/auth/organization/list` | better-auth org plugin: `{organizations:[{id,name,slug,...}], invitations:[...]}`. **Форму проверить в smoke-тесте** (см. Assumptions) |
| Create org (для smoke-тестов) | `POST /api/auth/organization/create` `{name,slug}` | |
| Projects | `GET /api/project?workspaceId=<orgId>` | `[{id,workspaceId,slug,icon,name,description,isPublic,archivedAt,position,lastTaskNumber,statistics:{completionPercentage,totalTasks,dueDate},...}]` |
| Create project | `POST /api/project` `{name,workspaceId,icon,slug}` — ВСЕ поля required | новые проекты получают дефолтные колонки автоматически (DEFAULT_PROJECT_COLUMNS на сервере). icon — emoji-строка |
| Board | `GET /api/task/tasks/{projectId}` | `{data:{id,name,icon,columns:[{id,slug,name,icon,isFinal,tasks:[...]}]},pagination}`; без page/limit — всё одной страницей |
| BoardTask | в `columns[].tasks` | `{id,title,number,description,status,priority(no-priority\|low\|medium\|high\|urgent),startDate,dueDate,position}` |
| Create task | `POST /api/task/{projectId}` `{title,status:<slug колонки>,priority?}` | |
| Смена колонки | `PUT /task/status/{id}` `{status:<slug>}` | внутри проекта |
| Смена приоритета | `PUT /task/priority/{id}` `{priority}` | |
| GH app info | `GET /github-integration/app-info` | `{appName}` или `null` если App не настроен |
| GH repos | `GET /github-integration/repositories/{projectId}` | `{repositories:[{id,name,full_name,private,owner:{login},description,html_url,updated_at,installation_id}],installations,total}`. **Требует существующий projectId** (middleware `workspaceAccess.fromProject`) |
| GH link repo | `POST /github-integration/project/{projectId}` `{repositoryOwner,repositoryName}` | |
| GH verify | `POST /github-integration/verify` `{projectId,repositoryOwner,repositoryName}` | `{isInstalled,missingPermissions[],message,settingsUrl}` |
| GH import issues | `POST /github-integration/import-issues` `{projectId}` | `{imported,skipped,errors[]}`; дубликаты не создаёт (обновляет/пропускает) |
| GH integration get | `GET /github-integration/project/{projectId}` | integration или `null` |
| Delete project | `DELETE /project/{id}` | для cleanup в smoke |

Install URL GitHub App строится на клиенте: `https://github.com/apps/<appName>/installations/new` (appName из app-info).

## Approach

Порядок шагов — дерево зависимостей; каждый шаг оставляет проект анализируемым.

### 1. Flutter SDK на VPS + scaffold
1. Скачать stable Flutter linux tarball в `~/flutter` (без sudo; без Android SDK — он не нужен для analyze/test), добавить `~/flutter/bin` в PATH текущей сессии и `~/.bashrc`.
2. `flutter config --no-analytics`; `flutter doctor` — ожидаемо отсутствие Android toolchain (не блокер).
3. В `/home/oleg/projects/prodcast` (пуста): `flutter create --project-name prodcastr --org app.prodcastr --platforms android,ios .` → applicationId/bundle `app.prodcastr.prodcastr` (не переименовывать).
4. `git init`, первый commit `feat: scaffold prodcastr flutter app` (flutter create уже даёт .gitignore).

### 2. Зависимости (pubspec, версии проверены на pub.dev)
`flutter_riverpod: ^3.4.3`, `go_router: ^18.0.1`, `dio: ^5.11.1`, `flutter_secure_storage: ^11.2.0`, `url_launcher: ^6.3.2`, `markdown_widget: ^2.3.2+8`; dev: `flutter_test`, `flutter_lints` (из scaffold).

### 3. Core-слой
1. `lib/session/session.dart` — Riverpod `Notifier<SessionState>`; `SessionState = {instanceUrl?, token?, user?}`; персист в `flutter_secure_storage` ключами `instance_url`, `token`, `user_json`. Методы: `connect(url)` (GET `/api/health` → `"ok"`), `signIn(email,password)` (сохранить token+user), `signOut()` (очистить).
2. `lib/api/kaneo_client.dart` — dio `BaseOptions(baseUrl: instanceUrl + '/api', validateStatus: все <500 → кидаем сами)`, interceptor: `Authorization: Bearer token`; на 401 → `session.signOut()`.
3. `lib/api/models.dart` — ручные immutable-млассы (без codegen): `KaneoUser`, `Organization{id,name,slug}`, `Project{id,workspaceId,slug,icon,name,description,position,lastTaskNumber,statistics?}`, `ProjectStats{completionPercentage,totalTasks}`, `BoardColumn{id,slug,name,icon,isFinal,tasks}`, `BoardTask{id,title,number,description,status,priority,startDate,dueDate,position}`, `Board{id,name,icon,columns}`, `Repo{id,name,fullName,ownerLogin,private,description,updatedAt,installationId}`, `Integration{repositoryOwner,repositoryName}`, `ImportResult{imported,skipped,errors}`. `fromJson` толерантен к лишним полям.
4. `lib/api/kaneo_api.dart` — типизированные методы по контракту выше: `listOrganizations()`, `listProjects(workspaceId)`, `createProject(workspaceId,name,icon,slug)`, `board(projectId)`, `createTask(projectId,title,status)`, `setTaskStatus(taskId,status)`, `setTaskPriority(taskId,priority)`, `githubAppInfo()`, `githubRepositories(contextProjectId)`, `getGithubIntegration(projectId)`, `linkGithubRepo(projectId,owner,name)`, `importIssues(projectId)`.
5. Cleartext HTTP (инстанс по http на Tailscale): Android — `android:usesCleartextTraffic="true"` в `<application>` AndroidManifest.xml; iOS — `NSAppTransportSecurity` → `NSAllowsArbitraryLoads: true` в Info.plist.

### 4. UI + роутинг
`lib/main.dart` — `ProviderScope` + `MaterialApp.router` (go_router). Роуты с redirect по состоянию сессии: нет URL → `/onboarding`; есть URL нет токена → `/login`; есть токен → `/projects`.

Экраны (UI-текст на русском, хардкодом, без i18n-фреймворка):
1. `lib/ui/onboarding.dart` — поле URL, предзаполнено `http://100.116.28.100:3012`; кнопка «Подключиться» → health-check; ошибка — снекбар.
2. `lib/ui/login.dart` — email+password; 401 → «Неверный email или пароль».
3. `lib/ui/projects.dart` — сверху dropdown организаций (первая по умолчанию; `listOrganizations`), список карточек проектов (icon, name, `slug`, прогресс из `statistics.completionPercentage`); pull-to-refresh; FAB «+» — диалог создания проекта (только name; slug = name.toLowerCase() → `[^a-z0-9]+`→`-`, пусто → `project`; icon `🚀`); кнопка GitHub в app bar → `/github`.
4. `lib/ui/board.dart` — `GET /task/tasks/{projectId}`; горизонтальный `PageView` по колонкам (заголовок: icon+name+count), внутри колонки `ListView` карточек задач (`#number`, title, чип приоритета, dueDate); тап по карточке → bottom sheet: описание через `markdown_widget` (GitHub issues — markdown, в `SingleChildScrollView`), селекторы статуса (`setTaskStatus`) и приоритета (`setTaskPriority`) с optimistic-обновлением и rollback по ошибке; кнопка «+» в заголовке колонки → диалог «Новая задача» → `createTask(projectId, title, status: column.slug)`. Pull-to-refresh. Кросс-колоночный drag-and-drop в v1 НЕ делаем — вне рамок.
5. `lib/ui/github_wizard.dart` — stepper из 3 шагов:
   - **Шаг 1 Установка App**: `githubAppInfo()`; `appName == null` → экран «На инстансе не настроен GitHub App» и стоп. Иначе кнопка «Установить на GitHub» → `url_launcher` на `https://github.com/apps/<appName>/installations/new`; кнопка «Продолжить».
   - **Шаг 2 Выбор репо**: контекст-проект = первый из `listProjects`; если проектов 0 → создать bootstrap `{name:"Imports", icon:"📦", slug:"imports", workspaceId}` и использовать его (не удалять — переиспользуется). `githubRepositories(contextId)`; пусто → экран «App установлен не на один аккаунт/репо» + ссылка установки снова. Параллельно `getGithubIntegration(p.id)` для каждого существующего проекта → репо с уже созданной связкой пометить «подключён → <project.name>» (не выбирается). Список с чекбоксами (multi-select): `ownerLogin/name`, бейдж private, description.
   - **Шаг 3 Импорт**: последовательно по каждому выбранному репо: (а) `createProject(workspaceId, name: full_name, icon:"📦", slug: sanitize(full_name))`; при ошибке конфликта slug — ретрай с суффиксом `-2`,`-3`; (б) `linkGithubRepo(newId, ownerLogin, name)`; при ошибке «не установлен» (сообщение из verify-ответа/ошибки) → пометить репо failed, продолжить остальные; (в) `importIssues(newId)` → `{imported,skipped}`. Прогресс построчно; итог — сводка per-repo (создан проект X, импортировано N, пропущено M / причина ошибки). «Готово» → `/projects` с refresh.
6. `lib/ui/settings.dart` — email пользователя, instance URL, «Выйти».

### 5. Тесты (behavior, запускаются на Dart VM без эмулятора)
1. `test/api_live_test.dart` — интеграционный против живого Kaneo (URL из `String.fromEnvironment('KANEO_URL', defaultValue: 'http://100.116.28.100:3012')`): sign-up случайного юзера (`prodcastr-test-<ts>@test.invalid`) → `organization/create` (slug `prodcastr-test-<ts>`) → `createProject` → `createTask` в первую колонку борды → `setTaskStatus` во вторую колонку → `board()` содержит задачу во второй колонке → `githubAppInfo()` возвращает `appName == "kaneo-local-oleg"` → cleanup `DELETE /project/{id}`. Тест же фиксирует фактическую форму ответа `organization/list` (в Assumptions описан фолбэк).
2. `test/widget_test.dart` (переписать из scaffold): onboarding не пускает дальше при не-`ok` health (fake dio-адаптер), login показывает «Неверный email или пароль» на 401, board рендерит колонки/задачи из фикстуры-JSON.

### 6. Git + передача пользователю
Коммит `feat: prodcastr — Kaneo mobile client with GitHub project import`. Репо остаётся на VPS; пользователь клонирует на локальную машину: `git clone oleg@100.116.28.100:projects/prodcast` (Tailscale), дальше `flutter pub get && flutter run` локально; APK — `flutter build apk`; iOS-сборка — только на Mac пользователя.

## Critical files & anchors

- `/home/oleg/docker/kaneo/` — compose живого инстанса (env с GITHUB_APP_*; не трогать, только контекст).
- `lib/api/kaneo_client.dart` — dio + Bearer + 401→logout; единственная точка сетевых ошибок.
- `lib/api/kaneo_api.dart` — весь контракт из таблицы выше; единственное место, знающее пути.
- `lib/ui/github_wizard.dart` — самая сложная логика (контекст-проект, дедуп связок, последовательный импорт с устойчивостью к ошибкам per-repo).
- `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist` — cleartext HTTP.

## Verification

1. `flutter analyze` — 0 issues (на VPS).
2. `flutter test` — оба файла зелёные; `api_live_test` доказывает контракт end-to-end против живого Kaneo: новый юзер → орга → проект → задача → смена колонки → борда отражает перенос; `app-info` возвращает `kaneo-local-oleg`.
3. Ручной приёмочный шаг пользователя (нельзя автоматизировать — установка GitHub App и вход требуют аккаунтов пользователя; описать в финальном сообщении): на телефоне Tailscale → `flutter run` → подключение к `http://100.116.28.100:3012` → вход своим Kaneo-аккаунтом → видит свои проекты и доски → GitHub-визард: установка App на свои репо → выбор 2–3 репо → в Kaneo (web) появились проекты, задачи = issues.
4. При провале шага 3 из-за расхождения форм ответов (например org list) — чинить модель по фактическому JSON, перегнать `flutter test` (контракт фиксирован тестом).

## Assumptions & contingencies

- **org list shape**: ожидаем better-auth `{organizations:[...]}`; если поле другое — парсер: если `organizations` отсутствует и корень — массив, взять корень (фолбэк закодировать сразу в `listOrganizations`).
- **Срок токена** better-auth ≈ 7 дней, refresh-эндпоинта нет: на 401 — разлогин на `/login` (уже в клиенте). Достаточно для v1.
- **Телефон без Tailscale** до инстанса не достучится (инстанс не проброшен наружу); это ожидаемо, в heлп-тексте онбординга одна строка «Требуется Tailscale».
- **Slug-конфликты** при создании проектов: сервер slug не дедуплицирует → ретрай с суффиксом (заложено в шаге визарда).
- **iOS build** на VPS невозможна (нет Mac) — по решению пользователя сборка локальная; план не включает iOS-специфику кроме ATS-ключа в Info.plist.
- Имя `prodcastr` (пользовательское) vs директория `prodcast` — не переименовывать директорию, проект во flutter зовётся `prodcastr`.
