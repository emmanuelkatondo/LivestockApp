class UserModel {
  final int id;
  final String phoneNumber;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? email;
  final String role;
  final String? location;
  final String? profilePicture;
  final DateTime dateJoined;
  final int animalCount;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.email,
    required this.role,
    this.location,
    this.profilePicture,
    required this.dateJoined,
    this.animalCount = 0,
  });

  String get fullName {
    String full = firstName;
    if (middleName != null && middleName!.isNotEmpty) {
      full += ' $middleName';
    }
    full += ' $lastName';
    return full;
  }

  String get displayName => '$firstName $lastName';

  bool get isFarmer => role == 'FARMER';

  bool get isAgOfficer => role == 'AG_OFFICER';

  bool get isPolice => role == 'POLICE';

  String get formattedPhoneNumber {
    String number = phoneNumber.trim().replaceAll(' ', '');
    if (number.startsWith('255')) {
      return '0${number.substring(3)}';
    }
    if (number.startsWith('0')) {
      return number;
    }
    return number;
  }

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      phoneNumber: json['phone'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'] ?? json['middleName'],
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'FARMER',
      location: json['location'],
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      dateJoined: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'])
          : DateTime.now(),
      animalCount: json['animal_count'] ?? 0, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phoneNumber,
      'first_name': firstName,
      if (middleName != null && middleName!.isNotEmpty)
        'middle_name': middleName,
      'last_name': lastName,
      if (email != null) 'email': email,
      'role': role,
      if (location != null) 'location': location,
      if (profilePicture != null) 'profile_picture': profilePicture,
      'date_joined': dateJoined.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? phoneNumber,
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? role,
    String? location,
    String? profilePicture,
    DateTime? dateJoined,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      location: location ?? this.location,
      profilePicture: profilePicture ?? this.profilePicture,
      dateJoined: dateJoined ?? this.dateJoined,
    );
  }


  @override
  String toString() {
    return 'UserModel(id: $id, phone: $phoneNumber, name: $fullName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
