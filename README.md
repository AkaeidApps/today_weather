# ATMOS – Ultimate Smart Weather

A responsive Flutter weather application for mobile, web, and desktop. Current weather and air quality are fetched from Open-Meteo; city search uses Open-Meteo geocoding; the interactive map uses OpenStreetMap tiles with attribution. The existing experience is being migrated in phases toward the architecture described in [lib/ARCHITECTURE.md](lib/ARCHITECTURE.md).

## Run

The project requires the Flutter SDK. From the project root:

```sh
flutter pub get
flutter run -d chrome
```

For a production web build:

```sh
flutter build web --release
```

GPS on web requires a secure context (HTTPS or localhost) and browser permission. If location access is unavailable, use the city search. Preferences and favorite locations are stored locally on the device.

## Data and map notes

- Forecast: Open-Meteo Forecast API.
- Air quality: Open-Meteo Air Quality API. Values may be unavailable for some coordinates.
- Geocoding: Open-Meteo Geocoding API.
- Map: OpenStreetMap standard tiles, with visible attribution. Standard map tiles do not contain weather overlays; the map identifies this clearly rather than presenting geographic tiles as radar.

Open-Meteo API usage is subject to its current terms. OpenStreetMap tile usage is subject to the tile usage policy and attribution requirements.
