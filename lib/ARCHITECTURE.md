# ATMOS application architecture

The existing `WeatherShell` remains the working application entry point while
features are migrated in small, verified steps. New code follows a feature-first
Clean Architecture boundary:

```text
lib/
  app.dart
  core/       shared configuration, theme, routing, networking, errors, utilities
  data/       provider clients, DTOs, local/remote data sources, repository adapters
  domain/     provider-independent entities, repository contracts, use cases
  features/   feature UI and state, grouped by product capability
  shared/     reusable presentation widgets
```

Feature UI depends on domain contracts. Data implementations depend on external
providers and map their responses into domain values. Provider credentials and
provider-specific response models stay outside feature widgets. Riverpod will
own feature state and dependency wiring; GoRouter will own screen navigation.
Those integrations are introduced alongside the relevant feature work so the
current working screen is not replaced by an empty scaffold.

## Phase 2 foundations

- `core/theme/atmos_theme.dart` defines the Material 3 palette and application
  theme.
- `shared/widgets/atmos_card.dart` provides a consistent content surface.
- Riverpod, GoRouter, Freezed/JSON annotations, and secure storage are declared
  for the upcoming architecture and data phases.

Current weather providers remain Open-Meteo. Optional paid or credentialed
providers must be enabled through configuration after coverage, licensing,
limits, and attribution have been reviewed. No private API key belongs in the
Flutter bundle.
