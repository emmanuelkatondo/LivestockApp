class UserModel {
  final int id;
  final String phoneNumber;
  final String fullName;
  final String? email;
  final String role;
  final String? location;
  final String? profilePicture;
  final DateTime dateJoined;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.email,
    required this.role,
    this.location,
    this.profilePicture,
    required this.dateJoined,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      phoneNumber: json['phone'],
      fullName: json['first_name'],
      email: json['email'],
      role: json['role'],
      location: json['location'],
      profilePicture: json['profile_picture'],
      dateJoined: DateTime.parse(json['date_joined']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'first_name': fullName,
      'email': email,
      'role': role,
      'location': location,
    
      'profile_picture': profilePicture,
      'date_joined': dateJoined.toIso8601String(),
    };
  }

  bool get isFarmer => role == 'FARMER';
  bool get isAgOfficer => role == 'AG_OFFICER';
  bool get isPolice => role == 'POLICE';

String get formattedPhoneNumber {
    String number = phoneNumber.trim();
    number = number.replaceAll(' ', '');
    if (number.startsWith('255')) {
      return '0${number.substring(3)}';
    }
    if (number.startsWith('255')) {
      return '0${number.substring(3)}';
    }
    if (number.startsWith('0')) {
      return number;
    }
    return number;
  }
  String get initials {
    List<String> nameParts = fullName.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  String? get profilePictureUrl {
    if (profilePicture != null && profilePicture!.isNotEmpty) {
      return profilePicture;
    }
    return null;
  }

  String get formattedDateJoined {
    return '${dateJoined.day}/${dateJoined.month}/${dateJoined.year}';
  }
}
