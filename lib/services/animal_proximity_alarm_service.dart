import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/animal_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AnimalProximityBreach {
  final AnimalModel animal;
  final AnimalModel? otherAnimal;
  final LocationModel location;
  final double distanceMeters;

  const AnimalProximityBreach({
    required this.animal,
    this.otherAnimal,
    required this.location,
    required this.distanceMeters,
  });

  String get key {
    final otherId = otherAnimal?.id;
    if (otherId == null) return animal.id.toString();
    final ids = [animal.id, otherId]..sort();
    return '${ids[0]}:${ids[1]}';
  }
}

class AnimalProximityAlarmState {
  final bool isMonitoring;
  final bool isAlarmPlaying;
  final bool hasLocationProblem;
  final String? message;
  final List<AnimalProximityBreach> breaches;
  final DateTime? checkedAt;

  const AnimalProximityAlarmState({
    this.isMonitoring = false,
    this.isAlarmPlaying = false,
    this.hasLocationProblem = false,
    this.message,
    this.breaches = const [],
    this.checkedAt,
  });

  bool get hasBreaches => breaches.isNotEmpty;

  AnimalProximityAlarmState copyWith({
    bool? isMonitoring,
    bool? isAlarmPlaying,
    bool? hasLocationProblem,
    String? message,
    bool clearMessage = false,
    List<AnimalProximityBreach>? breaches,
    DateTime? checkedAt,
  }) {
    return AnimalProximityAlarmState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isAlarmPlaying: isAlarmPlaying ?? this.isAlarmPlaying,
      hasLocationProblem: hasLocationProblem ?? this.hasLocationProblem,
      message: clearMessage ? null : message ?? this.message,
      breaches: breaches ?? this.breaches,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

class AnimalProximityAlarmService {
  AnimalProximityAlarmService._();

  static final AnimalProximityAlarmService instance =
      AnimalProximityAlarmService._();

  static const MethodChannel _channel = MethodChannel('lstp/proximity_alarm');

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;

  final ValueNotifier<AnimalProximityAlarmState> state =
      ValueNotifier<AnimalProximityAlarmState>(
    const AnimalProximityAlarmState(),
  );

  Timer? _timer;
  bool _isChecking = false;
  bool _mutedCurrentBreach = false;
  Set<String> _lastBreachKeys = {};
  DateTime? _lastAlarmTime;

  Future<void> start() async {
    if (_timer != null) return;

    _currentUser ??= await _authService.getCurrentUser();
    if (_currentUser?.role != 'FARMER') {
      print('Proximity alarm only for farmers');
      return;
    }

    state.value = state.value.copyWith(
      isMonitoring: true,
      hasLocationProblem: false,
      clearMessage: true,
    );

    await _requestNotificationPermission();
    await _startBackgroundMonitoring();
    await checkNow();
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.proximityAlarmCheckIntervalSeconds),
      (_) => checkNow(),
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _mutedCurrentBreach = false;
    _lastBreachKeys = {};
    _lastAlarmTime = null;
    await _stopAlarmSound();
    await _stopBackgroundMonitoring();
    state.value = const AnimalProximityAlarmState();
  }

  Future<void> stopCurrentAlarm() async {
    _mutedCurrentBreach = true;
    _lastAlarmTime = null;
    await _stopAlarmSound();
    state.value = state.value.copyWith(isAlarmPlaying: false);
  }

  Future<void> checkNow() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      _currentUser ??= await _authService.getCurrentUser();
      final currentUser = _currentUser;
      if (currentUser == null) {
        throw Exception('Current user not available');
      }

      final animalsResponse = await _apiService.get(AppConstants.animals);
      final List<dynamic> animalsData =
          animalsResponse.data['results'] as List<dynamic>? ?? [];

      final activeAnimals = animalsData
          .map((json) => AnimalModel.fromJson(json))
          .where((animal) => animal.isActive)
          .toList();

      final ownedAnimals = activeAnimals.where((animal) {
        if (currentUser.role == 'FARMER') {
          return animal.owner == currentUser.id;
        }
        return true;
      }).toList();

      final animals = ownedAnimals.isNotEmpty ? ownedAnimals : activeAnimals;

      final Map<int, LocationModel> latestLocations = {};
      for (final animal in animals) {
        final latestLocation = await _getLatestLocation(animal);
        if (latestLocation == null || !latestLocation.isValid) continue;
        latestLocations[animal.id] = latestLocation;
      }

      final breaches = <AnimalProximityBreach>[];
      var maxDistance = 0.0;
      final ids = latestLocations.keys.toList();

      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final locA = latestLocations[ids[i]]!;
          final locB = latestLocations[ids[j]]!;

          debugPrint('Proximity check pair ${ids[i]} vs ${ids[j]}: '
              '${locA.formattedCoordinates} (acc=${locA.accuracy}) '
              'vs ${locB.formattedCoordinates} (acc=${locB.accuracy})');

          if ((locA.accuracy != null &&
                  locA.accuracy! >
                      AppConstants.proximityAlarmIgnoreAccuracyMeters) ||
              (locB.accuracy != null &&
                  locB.accuracy! >
                      AppConstants.proximityAlarmIgnoreAccuracyMeters)) {
            debugPrint('Skipping pair due to poor accuracy');
            continue;
          }


          double round6(double v) => double.parse(v.toStringAsFixed(6));
          final rLatA = round6(locA.latitude);
          final rLngA = round6(locA.longitude);
          final rLatB = round6(locB.latitude);
          final rLngB = round6(locB.longitude);

          final distance =
              (rLatA == rLatB && rLngA == rLngB) ? 0.0 : locA.distanceTo(locB);

          if (distance > maxDistance) {
            maxDistance = distance;
          }

          if (distance > AppConstants.proximityAlarmDistanceMeters) {
            final animalA = animals.firstWhere((a) => a.id == ids[i]);
            final animalB = animals.firstWhere((a) => a.id == ids[j]);

            breaches.add(AnimalProximityBreach(
              animal: animalA,
              otherAnimal: animalB,
              location: locA,
              distanceMeters: distance,
            ));
          }
   
        }
      }

      debugPrint(
        'Animal alarm checked ${animals.length} animals, '
        '${latestLocations.length} GPS points, max distance '
        '${maxDistance.toStringAsFixed(1)}m, breaches ${breaches.length}.',
      );

      breaches.sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
      await _handleBreaches(breaches);
    } catch (e) {
      state.value = state.value.copyWith(
        isMonitoring: true,
        hasLocationProblem: true,
        message: e.toString(),
      );
    } finally {
      _isChecking = false;
    }
  }

  Future<LocationModel?> _getLatestLocation(AnimalModel animal) async {
    try {
      final response = await _apiService
          .get('${AppConstants.animals}${animal.id}/locations/');
      final locations = _readLocationsList(response.data);
      if (locations.isEmpty) return null;
      return LocationModel.fromJson(
        Map<String, dynamic>.from(locations.first as Map),
      );
    } catch (e) {
      debugPrint('Could not load latest location for ${animal.name}: $e');
      return null;
    }
  }

  List<dynamic> _readLocationsList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) {
      return data['results'] as List;
    }
    return const [];
  }

  Future<void> _handleBreaches(List<AnimalProximityBreach> breaches) async {
    final currentBreachKeys = breaches.map((breach) => breach.key).toSet();
    if (!_sameBreachSet(_lastBreachKeys, currentBreachKeys)) {
      _mutedCurrentBreach = false;
    }
    _lastBreachKeys = currentBreachKeys;

    if (breaches.isEmpty) {
      _mutedCurrentBreach = false;
      _lastAlarmTime = null;
      await _stopAlarmSound();
      state.value = state.value.copyWith(
        isMonitoring: true,
        isAlarmPlaying: false,
        hasLocationProblem: false,
        clearMessage: true,
        breaches: const [],
        checkedAt: DateTime.now(),
      );
      return;
    }

    if (_lastAlarmTime != null) {
      final elapsed = DateTime.now().difference(_lastAlarmTime!);
      if (elapsed.inSeconds < 15) {
        print('⏳ Alarm cooldown: ${elapsed.inSeconds}s, skipping...');
        return;
      }
    }

    final breachMessages = breaches.map((b) {
      final otherName = b.otherAnimal?.name ?? 'unknown';
      return '${b.animal.name} & $otherName (${b.distanceMeters.toStringAsFixed(1)}m apart)';
    }).join(', ');

    final message = '🚨 Animals too far apart: $breachMessages';

    if (!_mutedCurrentBreach) {
      _lastAlarmTime = DateTime.now();
      await _startAlarmSound();
    }

    state.value = state.value.copyWith(
      isMonitoring: true,
      isAlarmPlaying: !_mutedCurrentBreach,
      hasLocationProblem: false,
      message: message,
      breaches: breaches,
      checkedAt: DateTime.now(),
    );
  }

  bool _sameBreachSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  Future<void> _startAlarmSound() async {
    try {
      await _channel.invokeMethod<void>('startAlarm');
    } catch (e) {
      state.value = state.value.copyWith(
        hasLocationProblem: true,
        message: 'Could not start phone alarm',
      );
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _channel.invokeMethod<void>('stopAlarm');
    } catch (e) {

    }
  }

  Future<void> _startBackgroundMonitoring() async {
    try {
      await _channel.invokeMethod<void>('startBackgroundMonitoring');
    } catch (e) {

    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await Permission.notification.request();
    } catch (e) {

    }
  }

  Future<void> _stopBackgroundMonitoring() async {
    try {
      await _channel.invokeMethod<void>('stopBackgroundMonitoring');
    } catch (e) {

    }
  }
}
