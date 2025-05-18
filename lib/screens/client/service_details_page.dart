import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/book_service_page.dart';
import 'package:mokaf2/screens/client/provider_detail_page.dart';
import 'package:mokaf2/services/image_service.dart';

class ServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  final Map<String, dynamic>? serviceData;

  const ServiceDetailsPage({
    super.key,
    required this.serviceId,
    this.serviceData,
  });

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _serviceData;
  Map<String, dynamic>? _providerData;

  @override
  void initState() {
    super.initState();
    _loadServiceDetails();
  }

  Future<void> _loadServiceDetails() async {
    setState(() => _isLoading = true);

    try {
      // If serviceData was provided, use it initially
      if (widget.serviceData != null) {
        _serviceData = Map<String, dynamic>.from(widget.serviceData!);
      }

      // Always fetch fresh data from Firestore
      final serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();

      if (!serviceDoc.exists) {
        throw Exception('Service not found');
      }

      final serviceData = serviceDoc.data()!;
      serviceData['id'] = serviceDoc.id;

      // Get provider details
      if (serviceData['providerId'] != null) {
        final providerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(serviceData['providerId'])
            .get();

        if (providerDoc.exists) {
          _providerData = providerDoc.data();
          _providerData!['id'] = providerDoc.id;
          
          // Add provider name to service data for booking
          if (_providerData!['businessName'] != null) {
            serviceData['providerName'] = _providerData!['businessName'];
          } else if (_providerData!['displayName'] != null) {
            serviceData['providerName'] = _providerData!['displayName'];
          } else if (_providerData!['name'] != null) {
            serviceData['providerName'] = _providerData!['name'];
          } else {
            serviceData['providerName'] = 'Service Provider';
          }
        }
      }

      setState(() {
        _serviceData = serviceData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading service details: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _navigateToBookService() {
    if (_serviceData == null) return;

    // Make sure service has the required fields for booking
    final serviceData = Map<String, dynamic>.from(_serviceData!);
    
    // Navigate to the booking page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookServicePage(
          service: serviceData,
        ),
      ),
    );
  }

  void _navigateToProviderDetails() {
    if (_providerData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderDetailPage(
          providerId: _providerData!['id'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _serviceData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Service not found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service image
                      if (_serviceData!['imageBase64'] != null)
                        SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: ImageService.imageFromBase64String(
                            _serviceData!['imageBase64'],
                            width: double.infinity,
                            height: 200,
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          height: 200,
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          child: const Icon(
                            Icons.design_services_outlined,
                            size: 64,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        
                      // Service details
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Service name and price
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _serviceData!['name'] ?? 'Unnamed Service',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '\$${(_serviceData!['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Category badge
                            if (_serviceData!['category'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _serviceData!['category'],
                                  style: TextStyle(
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            // Provider info
                            if (_providerData != null) ...[
                              GestureDetector(
                                onTap: _navigateToProviderDetails,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage: _providerData!['profileImageBase64'] != null
                                            ? MemoryImage(
                                                base64Decode(_providerData!['profileImageBase64']),
                                              )
                                            : null,
                                        child: _providerData!['profileImageBase64'] == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _providerData!['businessName'] ?? 
                                              _providerData!['displayName'] ?? 
                                              _providerData!['name'] ??
                                              'Service Provider',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'View Provider Profile',
                                              style: TextStyle(
                                                color: AppColors.primaryPurple,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                            ],
                            
                            // Description
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _serviceData!['description'] ?? 'No description available.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.grey[800],
                              ),
                            ),
                            
                            // Duration
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.access_time, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Duration: ${_serviceData!['duration'] ?? 1} hour(s)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Book button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _navigateToBookService,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Book This Service',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}