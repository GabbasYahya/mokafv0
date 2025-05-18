import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String providerId;
  final String name;
  final String description;
  final double price;
  final String category;
  final int duration; // in minutes
  final bool active;
  final double rating;
  final int reviewCount;
  final String? imageUrl;
  final Timestamp createdAt;

  ServiceModel({
    required this.id,
    required this.providerId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.duration,
    required this.active,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrl,
    required this.createdAt,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ServiceModel(
      id: doc.id,
      providerId: data['providerId'] ?? '',
      name: data['name'] ?? 'Unnamed Service',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'General',
      duration: (data['duration'] as num?)?.toInt() ?? 60,
      active: data['active'] ?? true,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'duration': duration,
      'active': active,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }
}