import 'dart:math' as math;
import 'package:flutter/material.dart';

class LocationModel {
  final int id;
  final int animal;
  final String animalName;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationModel({
    required this.id,
    required this.animal,
    required this.animalName,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.altitude,
    this.accuracy,
    required this.timestamp,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      animal: json['animal'],
      animalName: json['animal_name'] ?? 'Unknown',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      speed: json['speed'] != null ? _parseDouble(json['speed']) : null,
      altitude:
          json['altitude'] != null ? _parseDouble(json['altitude']) : null,
      accuracy:
          json['accuracy'] != null ? _parseDouble(json['accuracy']) : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is String) return double.parse(value);
    if (value is int) return value.toDouble();
    return value;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animal': animal,
      'animal_name': animalName,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  double distanceTo(LocationModel other) {
    const double earthRadius = 6371000; 

    double lat1 = latitude * math.pi / 180;
    double lat2 = other.latitude * math.pi / 180;
    double deltaLat = (other.latitude - latitude) * math.pi / 180;
    double deltaLng = (other.longitude - longitude) * math.pi / 180;

    double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String get googleMapsUrl {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  bool get isValid {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
