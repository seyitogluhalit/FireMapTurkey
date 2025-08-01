import 'package:flutter/material.dart';
import 'dart:math' as math;

@immutable
class FirePoint {
  final double latitude;
  final double longitude;
  final String confidence;
  final double brightness;
  final double frp;
  final String date;
  final String time;
  final String satellite;
  final String daynight;

  const FirePoint({
    required this.latitude,
    required this.longitude,
    required this.confidence,
    required this.brightness,
    required this.frp,
    required this.date,
    required this.time,
    required this.satellite,
    required this.daynight,
  });

  factory FirePoint.fromCsv(List<String> parts) {
    if (parts.length < 14) {
      throw ArgumentError('Invalid CSV data: insufficient columns');
    }

    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    final bright = double.tryParse(parts[2].trim());
    final frp = double.tryParse(parts[12].trim());

    if (lat == null || lon == null || bright == null || frp == null) {
      throw ArgumentError('Invalid numeric data in CSV');
    }

    return FirePoint(
      latitude: lat,
      longitude: lon,
      brightness: bright,
      frp: frp,
      date: parts[5].trim(),
      time: parts[6].trim(),
      satellite: parts[7].trim(),
      confidence: parts[9].trim(),
      daynight: parts[13].trim(),
    );
  }

  // Optimized confidence color calculation
  Color get confidenceColor {
    final cleaned = confidence.toLowerCase();

    // Fast string matching
    switch (cleaned) {
      case 'h':
      case 'high':
        return Colors.red;
      case 'n':
      case 'nominal':
        return Colors.orange;
      case 'l':
      case 'low':
        return Colors.yellow;
      default:
        // Try numeric parsing
        final numeric = int.tryParse(cleaned);
        if (numeric != null) {
          if (numeric >= 80) return Colors.red;
          if (numeric >= 50) return Colors.orange;
          return Colors.yellow;
        }
        return Colors.grey;
    }
  }

  // Distance calculation to another fire point
  double distanceTo(FirePoint other) {
    const double earthRadius = 6371; // km
    final lat1 = latitude * (math.pi / 180);
    final lat2 = other.latitude * (math.pi / 180);
    final deltaLat = (other.latitude - latitude) * (math.pi / 180);
    final deltaLon = (other.longitude - longitude) * (math.pi / 180);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan(math.sqrt(a) / math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Check if this fire is within a certain distance of another
  bool isNear(FirePoint other, double maxDistanceKm) {
    return distanceTo(other) <= maxDistanceKm;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirePoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.date == date &&
        other.time == time;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, date, time);
  }

  @override
  String toString() {
    return 'FirePoint(lat: $latitude, lon: $longitude, brightness: $brightness)';
  }
}
