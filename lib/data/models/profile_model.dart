class ProfileResponse {
  final bool success;
  final String message;
  final UserData? data;

  ProfileResponse({required this.success, required this.message, this.data});

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? UserData.fromJson(json['data']) : null,
    );
  }
}

class UserData {
  final UserModel user;

  UserData({required this.user});

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(user: UserModel.fromJson(json['user']));
  }
}

class UserModel {
  final String id;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String name;
  final String bio;
  final String address;
  final String role;
  final String? profileImage;
  final DateTime createdAt;
  final LibraryModel? library;
  final dynamic staffOfLibrary;

  UserModel({
    required this.id,
    required this.phone,
    required this.whatsappNumber,
    required this.email,
    required this.name,
    required this.bio,
    required this.address,
    required this.role,
    required this.createdAt,
    this.profileImage,
    this.library,
    this.staffOfLibrary,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      whatsappNumber: json['whatsappNumber'] ?? json['whatsapp'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      bio: json['bio'] ?? '',
      address: json['address'] ?? '',
      role: json['role'] ?? '',
      profileImage: json['profileImage'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      library: json['library'] != null
          ? LibraryModel.fromJson(json['library'])
          : null,
      staffOfLibrary: json['staffOfLibrary'],
    );
  }

  // Helper getter for formatted role
  String get roleDisplay => role
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join(' ');
}

class LibraryModel {
  final String id;
  final String name;
  final String address;
  final String code;
  final String phone;
  final PlanModel? plan;
  final TrialModel? trial;
  final List<LibrarySubscriptionModel>? librarySubscriptions;

  LibraryModel({
    required this.id,
    required this.name,
    required this.address,
    required this.code,
    required this.phone,
    this.plan,
    this.trial,
    this.librarySubscriptions,
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    return LibraryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      code: json['code'] ?? '',
      phone: json['phone'] ?? '',
      plan: json['plan'] != null ? PlanModel.fromJson(json['plan']) : null,
      trial: json['trial'] != null ? TrialModel.fromJson(json['trial']) : null,
      librarySubscriptions: json['librarySubscriptions'] != null
          ? (json['librarySubscriptions'] as List)
                .map((e) => LibrarySubscriptionModel.fromJson(e))
                .toList()
          : null,
    );
  }

  // Active subscription helper
  LibrarySubscriptionModel? get activeSubscription {
    if (librarySubscriptions == null || librarySubscriptions!.isEmpty) {
      return null;
    }
    try {
      return librarySubscriptions!.firstWhere((s) => s.status == 'active');
    } catch (e) {
      return null;
    }
  }
}

class PlanModel {
  final String id;
  final String name;

  PlanModel({required this.id, required this.name});

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(id: json['id'] ?? '', name: json['name'] ?? '');
  }
}

class TrialModel {
  final String id;
  final String status;
  final DateTime endDate;

  TrialModel({required this.id, required this.status, required this.endDate});

  factory TrialModel.fromJson(Map<String, dynamic> json) {
    return TrialModel(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      endDate: DateTime.parse(
        json['endDate'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class LibrarySubscriptionModel {
  final String id;
  final String status;
  final DateTime endDate;
  final String planId;

  LibrarySubscriptionModel({
    required this.id,
    required this.status,
    required this.endDate,
    required this.planId,
  });

  factory LibrarySubscriptionModel.fromJson(Map<String, dynamic> json) {
    return LibrarySubscriptionModel(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      endDate: DateTime.parse(
        json['endDate'] ?? DateTime.now().toIso8601String(),
      ),
      planId: json['planId'] ?? '',
    );
  }
}
