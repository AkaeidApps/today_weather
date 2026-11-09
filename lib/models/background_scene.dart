/// The three signature atmospheric backgrounds required by Aether Weather.
enum BackgroundScene {
  sunrise,
  sunset,
  moonlight;

  String get displayName => switch (this) {
    BackgroundScene.sunrise => 'Sunrise',
    BackgroundScene.sunset => 'Sunset',
    BackgroundScene.moonlight => 'Moonlight',
  };

  String get description => switch (this) {
    BackgroundScene.sunrise => 'Golden dawn sky & soft rays',
    BackgroundScene.sunset => 'Coral horizon glow & dusk twilight',
    BackgroundScene.moonlight => 'Luminous moon, stars & midnight sky',
  };
}

/// Mode for selecting atmospheric backgrounds.
enum BackgroundMode {
  automatic,
  sunrise,
  sunset,
  moonlight;

  String get label => switch (this) {
    BackgroundMode.automatic => 'Automatic',
    BackgroundMode.sunrise => 'Sunrise Preview',
    BackgroundMode.sunset => 'Sunset Preview',
    BackgroundMode.moonlight => 'Moonlight Preview',
  };

  BackgroundScene? get previewScene => switch (this) {
    BackgroundMode.automatic => null,
    BackgroundMode.sunrise => BackgroundScene.sunrise,
    BackgroundMode.sunset => BackgroundScene.sunset,
    BackgroundMode.moonlight => BackgroundScene.moonlight,
  };
}
