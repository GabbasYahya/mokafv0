import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderModel {
  final String uid; // Firebase Auth User ID
  final String name; // Could be from Auth or a separate business name
  final String email; // From Auth
  final String phoneNumber;
  final String serviceProvided; // The main service category
  final String idCardNumber;
  final String? profilePictureUrl; // URL of the uploaded picture

  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final double averageRating;
  final int totalRatings;
  final String? bio; // A short description about the provider or their service
  // Add any other fields relevant to a provider, e.g.:
  // final List<String> specificServicesOffered; // More granular services
  // final String address;
  // final GeoPoint location;

  ProviderModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.serviceProvided,
    required this.idCardNumber,
    this.profilePictureUrl,
    required this.createdAt,
    this.updatedAt,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.bio,
  });

  // Factory constructor to create a ProviderModel from a Firestore document
  factory ProviderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      serviceProvided: data['serviceProvided'] ?? '',
      idCardNumber: data['idCardNumber'] ?? '',
      profilePictureUrl: data['profilePictureUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      bio: data['bio'],
    );
  }

  // Method to convert a ProviderModel instance to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'serviceProvided': serviceProvided,
      'idCardNumber': idCardNumber,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
    
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      if (bio != null) 'bio': bio,
    };
  }
}