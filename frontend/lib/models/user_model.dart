// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Companion {
  final String name;
  final DateTime birthDate;
  final String cpf;
  final String phone;

  Companion({
    required this.name,
    required this.birthDate,
    required this.cpf,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'cpf': cpf,
      'phone': phone,
    };
  }

  factory Companion.fromMap(Map<String, dynamic> map) {
    return Companion(
      name: map['name'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      cpf: map['cpf'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Companion copyWith({
    String? name,
    DateTime? birthDate,
    String? cpf,
    String? phone,
  }) {
    return Companion(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      cpf: cpf ?? this.cpf,
      phone: phone ?? this.phone,
    );
  }
}

class Address {
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String zipCode;

  Address({
    required this.street,
    required this.number,
    this.complement = '',
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zipCode': zipCode,
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      street: map['street'] ?? '',
      number: map['number'] ?? '',
      complement: map['complement'] ?? '',
      neighborhood: map['neighborhood'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zipCode'] ?? '',
    );
  }

  Address copyWith({
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
  }) {
    return Address(
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final DateTime birthDate;
  final String cpf;
  final String email;
  final String phone;
  final Address address;
  final Companion? companion;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    this.id = '',
    required this.name,
    required this.birthDate,
    required this.cpf,
    required this.email,
    required this.phone,
    required this.address,
    this.companion,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get needsCompanion {
    final now = DateTime.now();
    final age = now.year - birthDate.year -
        (now.month > birthDate.month ||
                (now.month == birthDate.month && now.day >= birthDate.day)
            ? 0
            : 1);
    
    // Menor de idade ou idoso (65+)
    return age < 18 || age >= 65;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'cpf': cpf,
      'email': email,
      'phone': phone,
      'address': address.toMap(),
      'companion': companion?.toMap(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      cpf: map['cpf'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: Address.fromMap(map['address'] ?? {}),
      companion: map['companion'] != null
          ? Companion.fromMap(map['companion'])
          : null,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    String? cpf,
    String? email,
    String? phone,
    Address? address,
    Companion? companion,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      companion: companion ?? this.companion,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}