import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'http://10.92.220.153:8000';
  static const String apiUrl = '$baseUrl/api';

  static const String mediaUrl = '$baseUrl/media/';
  static const String login = '$apiUrl/login/';
  static const String register = '$apiUrl/register/';
  static const String refresh = '$apiUrl/token/refresh/';

  static const String users = '$apiUrl/users/';
  static const String farmers = '$apiUrl/users/farmers/';
  static const String police = '$apiUrl/users/police/';
  static const String me = '$apiUrl/users/me/';

  static const String searchByPhone = '$apiUrl/users/search_by_phone/';
  static const String owners = '$apiUrl/owners/';
  static String getFamilyMembers(int ownerId) =>
      '$apiUrl/owners/$ownerId/members/';
  static String getAddMember(int ownerId) =>
      '$apiUrl/owners/$ownerId/add_member/';
  static String getRemoveMember(int ownerId) =>
      '$apiUrl/owners/$ownerId/remove_member/';
  static const String ownerMe = '$apiUrl/owners/me/';
  static String getRegisterFamilyMember(int ownerId) =>
      '$apiUrl/owners/$ownerId/register_family_member/';

  static const String animals = '$apiUrl/animals/';
  static const String devices = '$apiUrl/devices/';
  static const String locations = '$apiUrl/locations/';
  static const String transfers = '$apiUrl/transfers/';
  static const String alerts = '$apiUrl/alerts/';
  static const String broadcasts = '$apiUrl/broadcasts/';
  static const String reports = '$apiUrl/reports/';
  static const String activityLogs = '$apiUrl/activity-logs/';

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String languageKey = 'language';
  static const String rememberMeKey = 'remember_me';

  static const int locationUpdateInterval = 30;
  static const int lostAnimalThresholdMinutes = 30;
  static const double lostAnimalThresholdDistance = 200.0;
  static const double proximityAlarmDistanceMeters = 30.0;
  static const double proximityAlarmIgnoreAccuracyMeters = 20.0;
  static const int proximityAlarmCheckIntervalSeconds = 15;
  static const int transferExpiryDays = 7;
  static const int maxLocationHistoryDays = 30;
  static const int maxAnimalsPerPage = 20;

  static const Map<String, String> animalTypeIcons = {
    'CATTLE': 'assets/images/ngombe.jpg',
    'GOAT': 'assets/images/goat.png',
    'SHEEP': 'assets/images/sheep.png',
    'CHICKEN': 'assets/images/chicken.png',
    'OTHER': 'assets/images/other.png',
  };

  static const Map<String, String> animalTypeNames = {
    'CATTLE': 'Cattle',
    'GOAT': 'Goat',
    'SHEEP': 'Sheep',
    'CHICKEN': 'Kuku',
    'OTHER': 'Other',
  };

  static const Map<String, String> animalStatusNames = {
    'ACTIVE': 'Active',
    'SOLD': 'Sold',
    'SLAUGHTERED': 'Slaughtered',
    'DEAD': 'Dead',
    'STOLEN': 'Stolen',
  };

  static const Map<String, Color> animalStatusColors = {
    'ACTIVE': Color(0xFF4CAF50),
    'SOLD': Color(0xFF2196F3),
    'SLAUGHTERED': Color(0xFFFF9800),
    'DEAD': Color(0xFFF44336),
    'STOLEN': Color(0xFFD32F2F),
  };

  static const Map<String, String> alertTypeIcons = {
    'LOST': '',
    'THEFT': '',
    'GENERAL': '',
    'LOW_BATTERY': '',
    'OFFLINE': '',
  };

  static const Map<String, Color> alertTypeColors = {
    'LOST': Color(0xFFFF9800),
    'THEFT': Color(0xFFF44336),
    'GENERAL': Color(0xFF2196F3),
    'LOW_BATTERY': Color(0xFF9C27B0),
    'OFFLINE': Color(0xFF607D8B),
  };

  static const int minPasswordLength = 6;
  static const int maxPhoneLength = 13;
  static const String phoneRegex = r'^(0\+?255)\d{9}$';
  static const int maxImageSizeMB = 5;
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif'
  ];
  static const int cacheDurationMinutes = 5;


  static const String errorNetwork = 'network error';
  static const String errorServer = 'server error';
  static const String errorUnauthorized = 'unauthorized';
  static const String errorNotFound = 'not found';
  static const String errorUnknown = 'unknown error';
}
