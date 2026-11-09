/// Signature atmospheric backgrounds required by ATMOS Weather.
enum BackgroundScene {
  sunrise,
  sunset,
  moonlight,
  rainy;

  String get displayName => switch (this) {
    BackgroundScene.sunrise => 'Sunrise',
    BackgroundScene.sunset => 'Sunset',
    BackgroundScene.moonlight => 'Moonlight',
    BackgroundScene.rainy => 'Rainy Day',
  };

  String get description => switch (this) {
    BackgroundScene.sunrise => 'Golden dawn sky & soft rays',
    BackgroundScene.sunset => 'Coral horizon glow & dusk twilight',
    BackgroundScene.moonlight => 'Luminous moon, stars & midnight sky',
    BackgroundScene.rainy => 'Stormy rain sky & falling showers',
  };
}

/// Mode for selecting atmospheric backgrounds.
enum BackgroundMode {
  automatic,
  sunrise,
  sunset,
  moonlight,
  rainy;

  String get label => switch (this) {
    BackgroundMode.automatic => 'Automatic',
    BackgroundMode.sunrise => 'Sunrise Preview',
    BackgroundMode.sunset => 'Sunset Preview',
    BackgroundMode.moonlight => 'Moonlight Preview',
    BackgroundMode.rainy => 'Rainy Day Preview',
  };

  BackgroundScene? get previewScene => switch (this) {
    BackgroundMode.automatic => null,
    BackgroundMode.sunrise => BackgroundScene.sunrise,
    BackgroundMode.sunset => BackgroundScene.sunset,
    BackgroundMode.moonlight => BackgroundScene.moonlight,
    BackgroundMode.rainy => BackgroundScene.rainy,
  };
}
