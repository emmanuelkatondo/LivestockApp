class AlertModel {
  final int id;
  final String title;
  final String message;
  final String alertType;
  final int? animal;
  final String? animalName;
  final int? user;
  final String? userName;
  bool isRead;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.title,
    required this.message,
    required this.alertType,
    this.animal,
    this.animalName,
    this.user,
    this.userName,
    required this.isRead,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      alertType: json['alert_type'],
      animal: json['animal'],
      animalName: json['animal_name'],
      user: json['user'],
      userName: json['user_name'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'alert_type': alertType,
      'animal': animal,
      'animal_name': animalName,
      'user': user,
      'user_name': userName,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
