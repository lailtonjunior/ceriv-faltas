import 'dart:convert';

class Patient {
  final int id;
  final String? externalId;
  final String? supabaseId;
  final String name;
  final String email;
  final String? phone;
  final DateTime birthDate;
  final String cpf;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final bool isMinor;
  final bool isActive;
  final String? fcmToken;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Guardian> guardians;

  Patient({
    required this.id,
    this.externalId,
    this.supabaseId,
    required this.name,
    required this.email,
    this.phone,
    required this.birthDate,
    required this.cpf,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.isMinor = false,
    this.isActive = true,
    this.fcmToken,
    this.profileCompleted = false,
    required this.createdAt,
    this.updatedAt,
    this.guardians = const [],
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int,
      externalId: map['external_id'] as String?,
      supabaseId: map['supabase_id'] as String?,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      birthDate: DateTime.parse(map['birth_date'] as String),
      cpf: map['cpf'] as String,
      address: map['address'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      zipCode: map['zip_code'] as String?,
      isMinor: map['is_minor'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      fcmToken: map['fcm_token'] as String?,
      profileCompleted: map['profile_completed'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      guardians: map['guardians'] != null
          ? List<Guardian>.from(
              (map['guardians'] as List).map(
                (x) => Guardian.fromMap(x as Map<String, dynamic>),
              ),
            )
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'external_id': externalId,
      'supabase_id': supabaseId,
      'name': name,
      'email': email,
      'phone': phone,
      'birth_date': birthDate.toIso8601String(),
      'cpf': cpf,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'is_minor': isMinor,
      'is_active': isActive,
      'fcm_token': fcmToken,
      'profile_completed': profileCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'guardians': guardians.map((x) => x.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  factory Patient.fromJson(String source) =>
      Patient.fromMap(json.decode(source) as Map<String, dynamic>);

  Patient copyWith({
    int? id,
    String? externalId,
    String? supabaseId,
    String? name,
    String? email,
    String? phone,
    DateTime? birthDate,
    String? cpf,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    bool? isMinor,
    bool? isActive,
    String? fcmToken,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Guardian>? guardians,
  }) {
    return Patient(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      cpf: cpf ?? this.cpf,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      isMinor: isMinor ?? this.isMinor,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      guardians: guardians ?? this.guardians,
    );
  }

  @override
  String toString() {
    return 'Patient(id: $id, name: $name, email: $email, cpf: $cpf)';
  }

  /// Verifica se a data de nascimento é válida.
  bool get isBirthDateValid {
    final now = DateTime.now();
    final age = now.year - birthDate.year;
    return age >= 0 && age <= 120;
  }

  /// Calcula a idade do paciente.
  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  /// Verifica se o paciente é menor de idade.
  bool get needsGuardian => age < 18;

  /// Formata o CPF para exibição (XXX.XXX.XXX-XX).
  String get formattedCpf {
    if (cpf.length != 11) return cpf;
    
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  /// Formata o telefone para exibição ((XX) XXXXX-XXXX).
  String? get formattedPhone {
    if (phone == null || phone!.isEmpty) return null;
    
    final digits = phone!.replaceAll(RegExp(r'\D'), '');
    
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    
    return phone;
  }

  /// Retorna o nome do responsável principal, se houver.
  String? get guardianName {
    if (guardians.isEmpty) return null;
    return guardians.first.name;
  }
}

class Guardian {
  final int id;
  final String name;
  final String? email;
  final String phone;
  final String cpf;
  final String relationship;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Guardian({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.cpf,
    required this.relationship,
    required this.createdAt,
    this.updatedAt,
  });

  factory Guardian.fromMap(Map<String, dynamic> map) {
    return Guardian(
      id: map['id'] as int,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String,
      cpf: map['cpf'] as String,
      relationship: map['relationship'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'cpf': cpf,
      'relationship': relationship,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory Guardian.fromJson(String source) =>
      Guardian.fromMap(json.decode(source) as Map<String, dynamic>);

  Guardian copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? cpf,
    String? relationship,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Guardian(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cpf: cpf ?? this.cpf,
      relationship: relationship ?? this.relationship,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Guardian(id: $id, name: $name, relationship: $relationship)';
  }

  /// Formata o CPF para exibição (XXX.XXX.XXX-XX).
  String get formattedCpf {
    if (cpf.length != 11) return cpf;
    
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  /// Formata o telefone para exibição ((XX) XXXXX-XXXX).
  String get formattedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    
    return phone;
  }
}