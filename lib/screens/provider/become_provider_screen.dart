import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/services/image_service.dart';
import 'package:mokaf2/screens/provider/provider_home_page.dart';
import 'package:mokaf2/theme_provider.dart';
import 'package:provider/provider.dart';

class BecomeProviderScreen extends StatefulWidget {
  const BecomeProviderScreen({super.key});

  @override
  State<BecomeProviderScreen> createState() => _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends State<BecomeProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedService;
  // Service categories matching the Add Services page
  final List<String> _availableServices = [
    'Home Cleaning',
    'House Keeping',
    'Plumbing',
    'Electrical Repair',
    'Carpentry', 
    'Painting',
    'Lawn Mowing',
    'Gardening',
    'Appliance Repair',
    'Pet Care',
    'Tutoring',
    'Personal Training',
    'Massage Therapy',
    'Hair Styling',
    'Makeup Artist',
  ];
  final TextEditingController _businessNameController = TextEditingController();
  bool _isSubmitting = false;

  File? _profileImageFile;
  String? _base64Image;
  bool _isUploading = false;

  static const Color providerPrimaryColor = Color(0xFF00BFA6); // Teal
  static const Color providerAccentColor = Color(0xFF00E5B9); // Bright Teal

  void _submitApplication() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Check if the document exists first
          DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
              
          Map<String, dynamic> providerData = {
            'isProvider': true,
            'serviceProvided': _selectedService,
            'businessName': _businessNameController.text.trim(),
            'providerSince': Timestamp.now(),
            'email': user.email, // Store email for reference
            'lastUpdated': Timestamp.now(),
            // Add the base64 image
            'profileImageBase64': _base64Image,
          };
          
          if (docSnapshot.exists) {
            // Update existing document
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update(providerData);
          } else {
            // Create new document if it doesn't exist
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(providerData);
          }
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Application submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          // Update the ThemeProvider
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
          themeProvider.setUserHasProviderRole(true);
          themeProvider.setTheme(ThemeType.provider);
          
          // Navigate to provider dashboard with a slight delay to allow for the snackbar
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 800), () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ProviderHomePage()),
                (route) => false, // Clear navigation stack
              );
            });
          }
        } else {
          // User is not authenticated
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: You must be logged in'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error saving provider data: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      // Form validation failed - show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Picture',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _profileImageFile != null
                  ? ClipOval(
                      child: Image.file(
                        _profileImageFile!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _base64Image != null
                      ? ClipOval(
                          child: ImageService.imageFromBase64String(
                            _base64Image,
                            width: 120,
                            height: 120,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_camera),
            label: Text(_profileImageFile != null || _base64Image != null 
                ? 'Change Photo' 
                : 'Add Photo'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final imageFile = await ImageService.pickImage(context);
    if (imageFile != null) {
      setState(() {
        _profileImageFile = imageFile;
      });
      
      // Convert to base64
      final base64 = await ImageService.imageToBase64(imageFile);
      if (base64 != null) {
        setState(() {
          _base64Image = base64;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Row(
    children: [
      Image.asset(
        'assets/images/logo.png',
        height: 40,
        width: 40,
        fit: BoxFit.contain,
      ),
      const SizedBox(width: 12),
      const Text('Become a Provider'),
    ],
  ),
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Provider Application',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: providerPrimaryColor),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Service You Provide',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline, color: providerPrimaryColor),
                ),
                value: _selectedService,
                hint: const Text('Select a service'),
                isExpanded: true,
                items: _availableServices.map((String service) {
                  return DropdownMenuItem<String>(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedService = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a service' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business, color: providerPrimaryColor),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your business name';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'ID Card Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined, color: providerPrimaryColor),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your ID card number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: providerAccentColor,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.black87, strokeWidth: 2.0)
                  : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}