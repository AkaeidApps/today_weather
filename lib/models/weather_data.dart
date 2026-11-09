import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'background_scene.dart';
import 'place.dart';

class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.apparentTemperature,
    required this.relativeHumidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.uvIndex,
    required this.precipitation,
    required this.pressure,
    required this.cloudCover,
    required this.visibilityKm,
    required this.dewPoint,
    required this.isDay,
    required this.localTime,
  });

  final double temperature;
  final double apparentTemperature;
  final int relativeHumidity;
  final int weatherCode;
  final double windSpeed;
  final int windDirection;
  final double windGusts;
  final double uvIndex;
  final double precipitation;
  final double pressure;
  final double cloudCover;
  final double visibilityKm;
  final double dewPoint;
  final bool isDay;
  final DateTime localTime;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final temp = (json['temperature_2m'] as num?)?.toDouble() ?? 0.0;
    final apparent = (json['apparent_temperature'] as num?)?.toDouble() ?? temp;
    final humidity = (json['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final code = (json['weather_code'] as num?)?.toInt() ?? 0;
    final wind = (json['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
    final bearing = (json['wind_direction_10m'] as num?)?.toInt() ?? 0;
    final gusts = (json['wind_gusts_10m'] as num?)?.toDouble() ?? wind;
    final uv = (json['uv_index'] as num?)?.toDouble() ?? 0.0;
    final rain = (json['precipitation'] as num?)?.toDouble() ?? 0.0;
    final pressureMsl = (json['pressure_msl'] as num?)?.toDouble() ??
        (json['surface_pressure'] as num?)?.toDouble() ?? 1013.25;
    final clouds = (json['cloud_cover'] as num?)?.toDouble() ?? 0.0;
    final vis = ((json['visibility'] as num?)?.toDouble() ?? 10000.0) / 1000.0;
    final dew = (json['dew_point_2m'] as num?)?.toDouble() ?? (temp - ((100 - humidity) / 5.0));
    final dayInt = (json['is_day'] as num?)?.toInt() ?? 1;
    final timeStr = json['time'] as String? ?? '';
    final time = DateTime.tryParse(timeStr) ?? DateTime.now();

    return CurrentWeather(
      temperature: temp,
      apparentTemperature: apparent,
      relativeHumidity: humidity,
      weatherCode: code,
      windSpeed: wind,
      windDirection: bearing,
      windGusts: gusts,
      uvIndex: uv,
      precipitation: rain,
      pressure: pressureMsl,
      cloudCover: clouds,
      visibilityKm: vis,
      dewPoint: dew,
      isDay: dayInt == 1,
      localTime: time,
    );
  }
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.relativeHumidity,
    required this.uvIndex,
    required this.cloudCover,
    required this.pressure,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int weatherCode;
  final int precipitationProbability;
  final double precipitation;
  final double windSpeed;
  final int windDirection;
  final int relativeHumidity;
  final double uvIndex;
  final double cloudCover;
  final double pressure;
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.apparentMax,
    required this.apparentMin,
    required this.sunrise,
    required this.sunset,
    required this.uvIndexMax,
    required this.precipitationProbabilityMax,
    required this.precipitationSum,
    required this.maxWindSpeed,
    required this.dominantWindDirection,
  });

  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final double apparentMax;
  final double apparentMin;
  final DateTime sunrise;
  final DateTime sunset;
  final double uvIndexMax;
  final int precipitationProbabilityMax;
  final double precipitationSum;
  final double maxWindSpeed;
  final int dominantWindDirection;
}

class WeatherData {
  const WeatherData({
    required this.place,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.utcOffsetSeconds,
    required this.fetchedAt,
    required this.rawJson,
  });

  final Place place;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final String timezone;
  final String timezoneAbbreviation;
  final int utcOffsetSeconds;
  final DateTime fetchedAt;
  final Map<String, dynamic> rawJson;

  factory WeatherData.fromJson(Map<String, dynamic> json, Place place) {
    final curMap = Map<String, dynamic>.from(json['current'] ?? {});
    final current = CurrentWeather.fromJson(curMap);

    final hourlyMap = Map<String, dynamic>.from(json['hourly'] ?? {});
    final hTimes = hourlyMap['time'] as List? ?? [];
    final hTemps = hourlyMap['temperature_2m'] as List? ?? [];
    final hApparent = hourlyMap['apparent_temperature'] as List? ?? [];
    final hCodes = hourlyMap['weather_code'] as List? ?? [];
    final hProb = hourlyMap['precipitation_probability'] as List? ?? [];
    final hPrecip = hourlyMap['precipitation'] as List? ?? [];
    final hWind = hourlyMap['wind_speed_10m'] as List? ?? [];
    final hBearing = hourlyMap['wind_direction_10m'] as List? ?? [];
    final hHumid = hourlyMap['relative_humidity_2m'] as List? ?? [];
    final hUv = hourlyMap['uv_index'] as List? ?? [];
    final hClouds = hourlyMap['cloud_cover'] as List? ?? [];
    final hPressure = hourlyMap['pressure_msl'] as List? ?? [];

    final hourly = <HourlyForecast>[];
    for (int i = 0; i < hTimes.length; i++) {
      final t = DateTime.tryParse('${hTimes[i]}');
      if (t == null) continue;
      final temp = (i < hTemps.length ? hTemps[i] as num? : null)?.toDouble() ?? 0.0;
      hourly.add(
        HourlyForecast(
          time: t,
          temperature: temp,
          apparentTemperature: (i < hApparent.length ? hApparent[i] as num? : null)?.toDouble() ?? temp,
          weatherCode: (i < hCodes.length ? hCodes[i] as num? : null)?.toInt() ?? 0,
          precipitationProbability: (i < hProb.length ? hProb[i] as num? : null)?.toInt() ?? 0,
          precipitation: (i < hPrecip.length ? hPrecip[i] as num? : null)?.toDouble() ?? 0.0,
          windSpeed: (i < hWind.length ? hWind[i] as num? : null)?.toDouble() ?? 0.0,
          windDirection: (i < hBearing.length ? hBearing[i] as num? : null)?.toInt() ?? 0,
          relativeHumidity: (i < hHumid.length ? hHumid[i] as num? : null)?.toInt() ?? 0,
          uvIndex: (i < hUv.length ? hUv[i] as num? : null)?.toDouble() ?? 0.0,
          cloudCover: (i < hClouds.length ? hClouds[i] as num? : null)?.toDouble() ?? 0.0,
          pressure: (i < hPressure.length ? hPressure[i] as num? : null)?.toDouble() ?? 1013.25,
        ),
      );
    }

    final dailyMap = Map<String, dynamic>.from(json['daily'] ?? {});
    final dTimes = dailyMap['time'] as List? ?? [];
    final dCodes = dailyMap['weather_code'] as List? ?? [];
    final dMax = dailyMap['temperature_2m_max'] as List? ?? [];
    final dMin = dailyMap['temperature_2m_min'] as List? ?? [];
    final dAppMax = dailyMap['apparent_temperature_max'] as List? ?? [];
    final dAppMin = dailyMap['apparent_temperature_min'] as List? ?? [];
    final dSunrise = dailyMap['sunrise'] as List? ?? [];
    final dSunset = dailyMap['sunset'] as List? ?? [];
    final dUv = dailyMap['uv_index_max'] as List? ?? [];
    final dProb = dailyMap['precipitation_probability_max'] as List? ?? [];
    final dPrecipSum = dailyMap['precipitation_sum'] as List? ?? [];
    final dWindMax = dailyMap['wind_speed_10m_max'] as List? ?? [];
    final dWindDir = dailyMap['wind_direction_10m_dominant'] as List? ?? [];

    final daily = <DailyForecast>[];
    for (int i = 0; i < dTimes.length; i++) {
      final date = DateTime.tryParse('${dTimes[i]}');
      if (date == null) continue;
      final maxT = (i < dMax.length ? dMax[i] as num? : null)?.toDouble() ?? 0.0;
      final minT = (i < dMin.length ? dMin[i] as num? : null)?.toDouble() ?? 0.0;
      final sr = i < dSunrise.length ? DateTime.tryParse('${dSunrise[i]}') : null;
      final ss = i < dSunset.length ? DateTime.tryParse('${dSunset[i]}') : null;

      daily.add(
        DailyForecast(
          date: date,
          weatherCode: (i < dCodes.length ? dCodes[i] as num? : null)?.toInt() ?? 0,
          maxTemp: maxT,
          minTemp: minT,
          apparentMax: (i < dAppMax.length ? dAppMax[i] as num? : null)?.toDouble() ?? maxT,
          apparentMin: (i < dAppMin.length ? dAppMin[i] as num? : null)?.toDouble() ?? minT,
          sunrise: sr ?? DateTime(date.year, date.month, date.day, 6, 0),
          sunset: ss ?? DateTime(date.year, date.month, date.day, 18, 0),
          uvIndexMax: (i < dUv.length ? dUv[i] as num? : null)?.toDouble() ?? 0.0,
          precipitationProbabilityMax: (i < dProb.length ? dProb[i] as num? : null)?.toInt() ?? 0,
          precipitationSum: (i < dPrecipSum.length ? dPrecipSum[i] as num? : null)?.toDouble() ?? 0.0,
          maxWindSpeed: (i < dWindMax.length ? dWindMax[i] as num? : null)?.toDouble() ?? 0.0,
          dominantWindDirection: (i < dWindDir.length ? dWindDir[i] as num? : null)?.toInt() ?? 0,
        ),
      );
    }

    return WeatherData(
      place: place,
      current: current,
      hourly: hourly,
      daily: daily,
      timezone: json['timezone'] as String? ?? 'UTC',
      timezoneAbbreviation: json['timezone_abbreviation'] as String? ?? '',
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
      fetchedAt: DateTime.now(),
      rawJson: json,
    );
  }

  /// Automatically choose one of the three backgrounds based on the selected location's
  /// local sunrise, sunset and timezone data.
  /// Rules:
  /// - Daytime: SUNRISE background.
  /// - Evening transition around sunset: SUNSET background.
  /// - Nighttime: MOONLIGHT background.
  BackgroundScene get automaticScene {
    if (daily.isEmpty) {
      return current.isDay ? BackgroundScene.sunrise : BackgroundScene.moonlight;
    }

    final today = daily.first;
    final localTime = current.localTime;
    final sunrise = today.sunrise;
    final sunset = today.sunset;

    // Transition around sunset: from 45 minutes before sunset until 45 minutes after sunset
    final sunsetStart = sunset.subtract(const Duration(minutes: 45));
    final sunsetEnd = sunset.add(const Duration(minutes: 45));

    if (localTime.isAfter(sunsetStart) && localTime.isBefore(sunsetEnd)) {
      return BackgroundScene.sunset;
    }

    // Daytime: between sunrise and sunset transition start
    if (localTime.isAfter(sunrise) && localTime.isBefore(sunsetStart)) {
      return BackgroundScene.sunrise;
    }

    // Nighttime: before sunrise or after sunset transition end
    return BackgroundScene.moonlight;
  }

  String get conditionText => getWeatherDescription(current.weatherCode);

  static String getWeatherDescription(int code) => switch (code) {
    0 => 'Clear Sky',
    1 => 'Mainly Clear',
    2 => 'Partly Cloudy',
    3 => 'Overcast',
    45 => 'Fog',
    48 => 'Depositing Rime Fog',
    51 => 'Light Drizzle',
    53 => 'Moderate Drizzle',
    55 => 'Dense Drizzle',
    56 => 'Light Freezing Drizzle',
    57 => 'Dense Freezing Drizzle',
    61 => 'Slight Rain',
    63 => 'Moderate Rain',
    65 => 'Heavy Rain',
    66 => 'Light Freezing Rain',
    67 => 'Heavy Freezing Rain',
    71 => 'Slight Snow Fall',
    73 => 'Moderate Snow Fall',
    75 => 'Heavy Snow Fall',
    77 => 'Snow Grains',
    80 => 'Slight Rain Showers',
    81 => 'Moderate Rain Showers',
    82 => 'Violent Rain Showers',
    85 => 'Slight Snow Showers',
    86 => 'Heavy Snow Showers',
    95 => 'Thunderstorm',
    96 => 'Thunderstorm with Slight Hail',
    99 => 'Thunderstorm with Heavy Hail',
    _ => 'Clear Sky',
  };

  static IconData getWeatherIcon(int code, {bool isNight = false}) => switch (code) {
    0 => isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
    1 || 2 => isNight ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded,
    3 => Icons.cloud_rounded,
    45 || 48 => Icons.blur_on_rounded,
    51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
    61 || 63 || 65 || 66 || 67 => Icons.water_drop_rounded,
    71 || 73 || 75 || 77 => Icons.ac_unit_rounded,
    80 || 81 || 82 => Icons.shower_rounded,
    85 || 86 => Icons.snowshoeing_rounded,
    95 || 96 || 99 => Icons.thunderstorm_rounded,
    _ => isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
  };

  static String getCompassDirection(int degrees) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW',
    ];
    final normalized = (degrees % 360 + 360) % 360;
    final index = ((normalized + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  static ({int scale, String label, String description}) getBeaufortScale(double kmh) {
    if (kmh < 1.0) return (scale: 0, label: 'Calm', description: 'Smoke rises vertically');
    if (kmh <= 5.0) return (scale: 1, label: 'Light Air', description: 'Smoke drift indicates wind');
    if (kmh <= 11.0) return (scale: 2, label: 'Light Breeze', description: 'Wind felt on exposed skin');
    if (kmh <= 19.0) return (scale: 3, label: 'Gentle Breeze', description: 'Leaves & small twigs in motion');
    if (kmh <= 28.0) return (scale: 4, label: 'Moderate Breeze', description: 'Dust & loose paper raised');
    if (kmh <= 38.0) return (scale: 5, label: 'Fresh Breeze', description: 'Small trees in leaf begin to sway');
    if (kmh <= 49.0) return (scale: 6, label: 'Strong Breeze', description: 'Large branches in motion; umbrellas hard to use');
    if (kmh <= 61.0) return (scale: 7, label: 'High Wind / Near Gale', description: 'Whole trees in motion; resistance walking against wind');
    if (kmh <= 74.0) return (scale: 8, label: 'Gale', description: 'Twigs break off trees; generally impedes progress');
    if (kmh <= 88.0) return (scale: 9, label: 'Strong Gale', description: 'Slight structural damage occurs');
    if (kmh <= 102.0) return (scale: 10, label: 'Storm', description: 'Seldom experienced inland; trees uprooted');
    if (kmh <= 117.0) return (scale: 11, label: 'Violent Storm', description: 'Widespread damage very rarely experienced');
    return (scale: 12, label: 'Hurricane Force', description: 'Devastation occurs');
  }

  static ({String label, Color color}) getUvRating(double uv) {
    if (uv < 3.0) return (label: 'Low', color: const Color(0xff55b778));
    if (uv < 6.0) return (label: 'Moderate', color: const Color(0xfff3a536));
    if (uv < 8.0) return (label: 'High', color: const Color(0xfff06f36));
    if (uv < 11.0) return (label: 'Very High', color: const Color(0xffd83c3c));
    return (label: 'Extreme', color: const Color(0xff9940c6));
  }
}
