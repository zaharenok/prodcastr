# prodcastr

Flutter mobile client for [Kaneo](https://github.com/usekaneo/kaneo) — a self-hosted project management platform.

Connects to any Kaneo instance over HTTP, lets you browse projects and kanban boards, and provides a GitHub integration wizard that pulls repositories into Kaneo as projects with imported issues.

## Features

- **Instance connection** — point the app at any Kaneo URL (e.g. over Tailscale)
- **Email/password authentication** — sign in with your Kaneo credentials
- **Project browser** — list projects across workspaces, create new ones
- **Kanban board** — horizontal column swiping, task cards with priority/due dates
- **Task details** — markdown descriptions, inline status and priority editing
- **GitHub wizard** — install the GitHub App on your instance, select repos, import issues as Kaneo tasks (with per-repo error handling and progress reporting)
- **Settings** — view connected account, sign out

## Tech stack

| Layer | Package |
|---|---|
| State management | Riverpod |
| Routing | go_router |
| HTTP | Dio |
| Secure storage | flutter_secure_storage |
| Markdown rendering | markdown_widget |
| Link opening | url_launcher |

## Requirements

- Flutter SDK (stable channel)
- Android or iOS device/emulator
- A running Kaneo instance (self-hosted or otherwise)

## Getting started

```bash
# Clone
git clone https://github.com/zaharenok/prodcastr.git
cd prodcastr

# Install dependencies
flutter pub get

# Run (connected device or emulator)
flutter run

# Build APK
flutter build apk
```

## Project structure

```
lib/
  main.dart              # App entry, ProviderScope, router
  session/
    session.dart         # Riverpod session state (URL, token, user)
  api/
    kaneo_client.dart     # Dio setup, auth interceptor, 401 handling
    kaneo_api.dart        # Typed Kaneo API methods
    models.dart           # Immutable data models (fromJson parsing)
  ui/
    onboarding.dart       # Instance URL entry + health check
    login.dart            # Email/password sign-in
    projects.dart         # Project list, org picker, create dialog
    board.dart            # Kanban board with column pages
    github_wizard.dart    # 3-step GitHub integration wizard
    settings.dart         # Account info, sign-out
test/
  api_live_test.dart      # Integration tests against live Kaneo
  widget_test.dart        # Unit tests for screens
```

## Kaneo API

The app uses the Kaneo REST API (`/api/*`). The full OpenAPI spec is available at `GET /api/openapi` on any running instance.

Key endpoints consumed:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/health` | Instance health check |
| `POST` | `/api/auth/sign-in/email` | Email/password sign-in |
| `GET` | `/api/auth/organization/list` | List workspaces |
| `GET` | `/api/project` | List projects |
| `POST` | `/api/project` | Create project |
| `GET` | `/api/task/tasks/{projectId}` | Board with columns and tasks |
| `POST` | `/api/task/{projectId}` | Create task |
| `PUT` | `/api/task/status/{id}` | Move task between columns |
| `PUT` | `/api/task/priority/{id}` | Change task priority |
| `GET` | `/github-integration/app-info` | GitHub App name |
| `GET` | `/github-integration/repositories/{projectId}` | Available repos |
| `POST` | `/github-integration/project/{projectId}` | Link repo to project |
| `POST` | `/github-integration/import-issues` | Import GitHub issues |

## GitHub integration

The app does not implement GitHub integration itself — Kaneo's server already includes a GitHub App. The wizard:

1. Checks if the GitHub App is configured on the instance
2. Opens the App installation page on GitHub
3. Lists available repositories
4. Creates a Kaneo project per selected repo, links it, and imports issues

The GitHub App must be installed on the Kaneo instance (see Kaneo docs for `GITHUB_APP_*` environment variables).

## Development

```bash
# Analyze
flutter analyze

# Run tests (Dart VM, no emulator needed)
flutter test

# Run live integration tests against a Kaneo instance
flutter test test/api_live_test.dart --dart-define=KANEO_URL=http://your-instance:3012
```

## License

MIT
