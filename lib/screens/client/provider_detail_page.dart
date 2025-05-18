import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/services/image_service.dart';
import 'package:mokaf2/screens/client/service_details_page.dart';
import 'dart:convert';

class ProviderDetailPage extends StatefulWidget {
  final String providerId;
  
  const ProviderDetailPage({super.key, required this.providerId});

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _providerData;
  List<Map<String, dynamic>> _providerServices = [];

  @override
  void initState() {
    super.initState();
    _loadProviderDetails();
  }

  Future<void> _loadProviderDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Load provider profile
      final providerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.providerId)
          .get();
      
      if (!providerDoc.exists) {
        throw Exception('Provider not found');
      }
      
      final providerData = providerDoc.data()!;
      providerData['id'] = providerDoc.id;
      
      // Load provider services
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: widget.providerId)
          .get();
      
      final services = servicesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      setState(() {
        _providerData = providerData;
        _providerServices = List<Map<String, dynamic>>.from(services);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading provider details: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providerData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Provider not found',
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
                      // Provider header with image, name, etc.
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: AppColors.primaryPurple.withOpacity(0.05),
                        child: Column(
                          children: [
                            // Profile image
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _providerData!['profileImageBase64'] != null
                                  ? MemoryImage(base64Decode(_providerData!['profileImageBase64']))
                                  : null,
                              child: _providerData!['profileImageBase64'] == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // Business name
                            Text(
                              _providerData!['businessName'] ?? 
                              _providerData!['displayName'] ?? 
                              'Service Provider',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // Categories
                            if (_providerData!['categories'] != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: (_providerData!['categories'] as List<dynamic>).map((category) {
                                  return Chip(
                                    label: Text(category),
                                    backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                                    labelStyle: TextStyle(color: AppColors.primaryPurple),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // About section
                      if (_providerData!['description'] != null) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'About',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _providerData!['description'],
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                      ],
                      
                      // Contact info
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_providerData!['phone'] != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 20, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    _providerData!['phone'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_providerData!['email'] != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.email, size: 20, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    _providerData!['email'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_providerData!['address'] != null) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _providerData!['address'],
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(),
                      
                      // Provider services
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Services Offered',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _providerServices.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        'No services available at this time',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _providerServices.length,
                                    itemBuilder: (context, index) {
                                      final service = _providerServices[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ServiceDetailsPage(
                                                  serviceId: service['id'],
                                                  serviceData: service,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                // Service image (if available)
                                                if (service['imageBase64'] != null)
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: SizedBox(
                                                      width: 60,
                                                      height: 60,
                                                      child: ImageService.imageFromBase64String(
                                                        service['imageBase64'],
                                                        width: 60,
                                                        height: 60,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryPurple.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.design_services_outlined,
                                                      color: AppColors.primaryPurple,
                                                    ),
                                                  ),
                                                const SizedBox(width: 12),
                                                // Service info
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        service['name'] ?? 'Unnamed Service',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      if (service['category'] != null) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          service['category'],
                                                          style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Price
                                                Text(
                                                  '\$${(service['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: AppColors.primaryPurple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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