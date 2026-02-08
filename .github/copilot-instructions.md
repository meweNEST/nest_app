# Project Guidelines — NEST Hamburg App

## Architecture

Feature-based Flutter app (`lib/features/`) for a coworking + childcare community. Backend is **Supabase** (auth, Postgres DB, Edge Functions, realtime). Payments via **Stripe**.

- **State management:** Pure `setState()` in `StatefulWidget` — no Provider/BLoC/Riverpod.
- **Data access:** Direct `Supabase.instance.client` calls inside widget state. No repository/service abstraction (except `StripeService`). Responses are raw `Map<String, dynamic>` — no typed models with `fromJson`/`toJson`.
- **Routing:** Imperative `Navigator.push` / `pushReplacement`. A few named routes exist in `main.dart` but are not the primary pattern.
- **App shell:** `MainScreen` uses `IndexedStack` + `BottomNavigationBar` (5 tabs: Home, Schedule, Café, Profile, Membership).

Key directories:
- `lib/core/config/` — Supabase credentials (`supabase_config.dart`)
- `lib/core/theme/` — Brand theme, colors, fonts (`app_theme.dart`)
- `lib/features/` — Feature folders with screens, widgets, models, services
- `lib/widgets/` — Shared widgets prefixed `Nest` (e.g., `NestAppBar`, `NestPrimaryButton`)
- `lib/screens/` — Legacy/debug screens (not actively used from `main.dart`)

## Code Style

- **Linting:** `package:flutter_lints/flutter.yaml` defaults, no custom rules.
- **Files:** `snake_case.dart`. **Classes:** `PascalCase`. Shared widgets: `Nest` prefix.
- **Fonts:** Two brand families (`SweetAndSalty` for headings, `CharlevoixPro` for body) applied inline via `TextStyle(fontFamily: ...)`, not through `ThemeData.textTheme`.
- **Colors:** Canonical palette in `AppTheme` (`app_theme.dart`). Some screens duplicate colors locally — prefer referencing `AppTheme` when adding new code.
- **Comments/UI strings:** MVP is English-only. Some German comments and UI text exist from earlier work — leave them unless editing that code. All new UI strings, comments, and code should be in English. Localization (German + English) is planned post-MVP.

## Build and Test

```bash
flutter pub get                # Install dependencies
flutter run                    # Run on default device
flutter run -d chrome          # Run on web
flutter build apk              # Android release build
flutter build ios              # iOS release build
```

- A `.env` file at project root is required for mobile (contains `STRIPE_PUBLISHABLE_KEY`).
- Supabase credentials are in `lib/core/config/supabase_config.dart`.
- **No automated tests** — `test/widget_test.dart` is the default Flutter scaffold and will fail. Do not rely on it.
- Web platform uses `kIsWeb` guards in `main()` and elsewhere for conditional behavior (e.g., Stripe init skipped on web).

## User Context

The project owner is a **beginner, not a professional developer**. When making changes:
- Prefer simple, clear code over clever abstractions.
- Add brief comments explaining non-obvious logic.
- Avoid introducing new patterns, libraries, or architectural layers unless explicitly requested.
- When something could break, explain the risk in plain language.

## Project Conventions

- **Supabase patterns:** Fetch data with `supabase.from('table').select()...`, use `supabase.rpc('function_name', params: {...})` for server logic, and `supabase.functions.invoke('edge-fn')` for Edge Functions.
- **Auth flow** (`AuthRedirect` in `main.dart`): checks onboarding → listens to `Supabase.auth.onAuthStateChange` → routes to `MainScreen` or `LoginScreen`. Guest mode allows unauthenticated browsing with booking gated behind login.
- **Screen files are large** (200–2200+ lines). When modifying, keep changes scoped and avoid splitting unless explicitly asked.
- **No code generation** — no `build_runner`, `freezed`, or `json_serializable`.
- **Duplicate code exists:** `NestAppBar` in both `lib/widgets/` and `lib/features/booking/widgets/`. Legacy login screen at `lib/features/login/` (active one is `lib/features/auth/`).

## Legacy Code — Do Not Use

- `lib/screens/` — Old debug/test screens. Not wired into the app. Ignore when adding features; do not import from here.
- `lib/features/login/` — Superseded by `lib/features/auth/login_screen.dart`. The auth version is the active one.
- `lib/features/splash/` — Unused splash screen. The app launches via `AuthRedirect` in `main.dart`.
- When in doubt whether code is active, trace it from `main.dart` → `AuthRedirect` → `MainScreen`.

## Integration Points

- **Supabase:** Auth, Postgres DB (tables: `users`, `cafe_categories`, `cafe_items`, `memberships`, `promo_codes`, `welcoming_party_waitlist`), Edge Functions (`create-payment-intent`), RPCs (`can_user_book`).
- **Stripe:** `flutter_stripe` for card input + payment confirmation; `StripeService` calls Supabase Edge Function to create payment intents (secret key stays server-side).
- **Hamburg-specific logic:** Hardcoded 2026 Hamburg public holidays and opening hours in schedule/booking features.
