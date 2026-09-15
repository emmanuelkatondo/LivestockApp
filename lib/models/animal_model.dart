import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AnimalModel {
  final int id;
  final String animalId;
  final String name;
  final String type;
  final String? color;
  final String? photo;
  final int owner;
  final String ownerfullName;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnimalModel({
    required this.id,
    required this.animalId,
    required this.name,
    required this.type,
    this.color,
    this.photo,
    required this.owner,
    required this.ownerfullName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    print('Creating AnimalModel from JSON: $json');
    return AnimalModel(
      id: json['id'],
      animalId: json['animal_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'OTHER',
      color: json['color'],
      photo: json['photo'],
      owner: _parseOwnerId(json),
      ownerfullName: _parseOwnerName(json),
      status: json['status'] ?? 'ACTIVE',
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  static int _parseOwnerId(Map<String, dynamic> json) {
    return _readId(
          json,
          [
            'owner',
            'owner_id',
            'owner_details',
            'owner_detail',
            'farmer',
            'farmer_id',
            'farmer_details',
            'farmer_detail',
            'user',
            'user_id',
            'created_by',
          ],
        ) ??
        0;
  }

  static String _parseOwnerName(Map<String, dynamic> json) {
    for (final key in [
      'owner',
      'owner_details',
      'owner_detail',
      'farmer',
      'farmer_details',
      'farmer_detail',
      'user',
      'created_by',
    ]) {
      final value = json[key];
      if (value is Map) {
        final name = value['full_name'] ??
            value['first_name'] ??
            value['name'] ??
            value['username'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    }

    return (json['owner_full_name'] ??
            json['owner_first_name'] ??
            json['owner_name'] ??
            json['farmer_full_name'] ??
            json['farmer_first_name'] ??
            json['farmer_name'] ??
            '')
        .toString();
  }

  static int? _readId(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final id = _parseIdValue(json[key]);
      if (id != null) return id;
    }
    return null;
  }

  static int? _parseIdValue(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      for (final key in ['id', 'pk', 'user_id', 'owner_id', 'farmer_id']) {
        final id = _parseIdValue(value[key]);
        if (id != null) return id;
      }
    }
    return null;
  }

  String get photoUrl {
    if (photo != null && photo!.isNotEmpty) {
      if (photo!.startsWith('http')) {
        return photo!;
      }
      String path = photo!;
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      return '${AppConstants.mediaUrl}$path';
    }
    return '';
  }

  bool get isActive => status == 'ACTIVE';
  bool get isStolen => status == 'STOLEN';

  String get statusText {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'SOLD':
        return 'Sold';
      case 'SLAUGHTERED':
        return 'Slaughtered';
      case 'DEAD':
        return 'Dead';
      case 'STOLEN':
        return 'Stolen';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'SOLD':
        return Colors.blue;
      case 'SLAUGHTERED':
        return Colors.orange;
      case 'DEAD':
        return Colors.red;
      case 'STOLEN':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}
