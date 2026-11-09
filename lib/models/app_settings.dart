import 'package:flutter/material.dart';
import 'background_scene.dart';
import 'place.dart';

enum TemperatureUnit {
  celsius('°C', 'Celsius'),
  fahrenheit('°F', 'Fahrenheit');

  const TemperatureUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  double convert(double celsius) => switch (this) {
    TemperatureUnit.celsius => celsius,
    TemperatureUnit.fahrenheit => (celsius * 9 / 5) + 32,
  };

  String format(double celsius, {bool showSymbol = true}) {
    final val = convert(celsius).round();
    return showSymbol ? '$val$symbol' : '$val°';
  }
}

enum WindSpeedUnit {
  kmh('km/h', 'Kilometers per hour'),
  mph('mph', 'Miles per hour'),
  ms('m/s', 'Meters per second');

  const WindSpeedUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  double convert(double kmh) => switch (this) {
    WindSpeedUnit.kmh => kmh,
    WindSpeedUnit.mph => kmh * 0.621371,
    WindSpeedUnit.ms => kmh / 3.6,
  };

  String format(double kmh) {
    final val = convert(kmh);
    final formatted = this == WindSpeedUnit.ms ? val.toStringAsFixed(1) : val.round().toString();
    return '$formatted $symbol';
  }
}

enum PressureUnit {
  hPa('hPa', 'Hectopascal'),
  inHg('inHg', 'Inches of Mercury'),
  mmHg('mmHg', 'Millimeters of Mercury');

  const PressureUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  double convert(double hpa) => switch (this) {
    PressureUnit.hPa => hpa,
    PressureUnit.inHg => hpa * 0.02953,
    PressureUnit.mmHg => hpa * 0.750062,
  };

  String format(double hpa) {
    final val = convert(hpa);
    final formatted = this == PressureUnit.inHg ? val.toStringAsFixed(2) : val.round().toString();
    return '$formatted $symbol';
  }
}

enum TimeFormatSetting {
  h24('24-Hour', '14:30'),
  h12('12-Hour', '2:30 PM');

  const TimeFormatSetting(this.label, this.example);
  final String label;
  final String example;
}

class AppSettings {
  const AppSettings({
    this.temperatureUnit = TemperatureUnit.celsius,
    this.windSpeedUnit = WindSpeedUnit.kmh,
    this.pressureUnit = PressureUnit.hPa,
    this.timeFormat = TimeFormatSetting.h24,
    this.backgroundMode = BackgroundMode.automatic,
    this.reducedMotion = false,
    this.highContrast = false,
    this.defaultPlace,
  });

  final TemperatureUnit temperatureUnit;
  final WindSpeedUnit windSpeedUnit;
  final PressureUnit pressureUnit;
  final TimeFormatSetting timeFormat;
  final BackgroundMode backgroundMode;
  final bool reducedMotion;
  final bool highContrast;
  final Place? defaultPlace;

  AppSettings copyWith({
    TemperatureUnit? temperatureUnit,
    WindSpeedUnit? windSpeedUnit,
    PressureUnit? pressureUnit,
    TimeFormatSetting? timeFormat,
    BackgroundMode? backgroundMode,
    bool? reducedMotion,
    bool? highContrast,
    Place? defaultPlace,
  }) {
    return AppSettings(
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      windSpeedUnit: windSpeedUnit ?? this.windSpeedUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      highContrast: highContrast ?? this.highContrast,
      defaultPlace: defaultPlace ?? this.defaultPlace,
    );
  }
}
