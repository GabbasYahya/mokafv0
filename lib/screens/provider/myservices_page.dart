import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/services/image_service.dart';
import 'dart:io';

class MyServicesPage extends StatefulWidget {
  const MyServicesPage({super.key});

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];
  
  @override
  void initState() {
    super.initState();
    _loadServices();
  }
  
  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final servicesQuery = await FirebaseFirestore.instance
            .collection('services')
            .where('providerId', isEqualTo: user.uid)
            .get();
            
        final services = servicesQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        setState(() {
          _services = List<Map<String, dynamic>>.from(services);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading services: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _deleteService(String serviceId) async {
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .delete();
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadServices();
    } catch (e) {
      print('Error deleting service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting service: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.design_services_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No services added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Service'),
                        onPressed: () => _navigateToAddService(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    
                    return _buildServiceCard(service);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddService(context),
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Service image
          if (service['imageBase64'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: ImageService.imageFromBase64String(
                  service['imageBase64'],
                  width: double.infinity,
                  height: 150,
                ),
              ),
            )
          else
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.design_services_outlined,
                color: AppColors.primaryPurple,
                size: 50,
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'] ?? 'Unnamed Service',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(service['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${service['duration'] ?? 1} hour',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                if (service['description'] != null) ...[
                  Text(
                    service['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () => _navigateToEditService(context, service),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteService(service['id']),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteService(String serviceId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this service? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteService(serviceId);
              },
            ),
          ],
        );
      },
    );
  }
  
  void _navigateToAddService(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ServiceFormPage(isEditing: false),
      ),
    ).then((value) {
      if (value == true) {
        _loadServices();
      }
    });
  }
  
  void _navigateToEditService(BuildContext context, Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceFormPage(
          isEditing: true,
          service: service,
        ),
      ),
    ).then((value) {
      if (value == true) {
        _loadServices();
      }
    });
  }
}

class ServiceFormPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? service;
  
  const ServiceFormPage({
    super.key,
    required this.isEditing,
    this.service,
  });

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isFeatured = false;
  int _durationHours = 1;
  String? _category;
  bool _isSubmitting = false;
  
  final List<String> _categories = [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Home Repair',
    'Landscaping',
    'Moving',
    'Tutoring',
    'Personal Training',
    'Beauty & Wellness',
    'Other',
  ];
  
  File? _serviceImageFile;
  String? _base64Image;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.isEditing && widget.service != null) {
      _nameController.text = widget.service!['name'] ?? '';
      _priceController.text = (widget.service!['price'] ?? 0).toString();
      _descriptionController.text = widget.service!['description'] ?? '';
      _isFeatured = widget.service!['featured'] ?? false;
      _durationHours = widget.service!['duration'] ?? 1;
      _category = widget.service!['category'];
      _base64Image = widget.service!['imageBase64'];
    }
  }
  
  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create a service');
      }
      
      // Get provider information
      final providerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!providerDoc.exists) {
        throw Exception('Provider profile not found');
      }
      
      final providerData = providerDoc.data()!;
      
      // Create service data
      final serviceData = {
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'description': _descriptionController.text.trim(),
        'featured': _isFeatured,
        'duration': _durationHours,
        'category': _category,
        'providerId': user.uid,
        'providerName': providerData['name'] ?? providerData['businessName'] ?? 'Provider',
        'updatedAt': Timestamp.now(),
        'imageBase64': _base64Image,
      };
      
      if (widget.isEditing && widget.service != null) {
        // Update existing service
        await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.service!['id'])
            .update(serviceData);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new service
        serviceData['createdAt'] = Timestamp.now();
        
        await FirebaseFirestore.instance
            .collection('services')
            .add(serviceData);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // Return to services page
      if (mounted) {
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('Error saving service: $e');
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
  }
  
  Widget _buildServiceImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Service Image',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _serviceImageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _serviceImageFile!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _base64Image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageService.imageFromBase64String(
                            _base64Image,
                            width: double.infinity,
                            height: 200,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 60,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add a service image',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_camera),
            label: Text(_serviceImageFile != null || _base64Image != null 
                ? 'Change Image' 
                : 'Add Image'),
          ),
        ),
      ],
    );
  }
  
  Future<void> _pickImage() async {
    final imageFile = await ImageService.pickImage(context);
    if (imageFile != null) {
      setState(() {
        _serviceImageFile = imageFile;
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
        title: Text(widget.isEditing ? 'Edit Service' : 'Add Service'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Service Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a service name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (\$)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price';
                }
                try {
                  double.parse(value);
                  return null;
                } catch (e) {
                  return 'Please enter a valid number';
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _category = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Duration (hours)'),
            Slider(
              value: _durationHours.toDouble(),
              min: 0.5,
              max: 8,
              divisions: 15,
              label: _durationHours.toString(),
              onChanged: (value) {
                setState(() {
                  _durationHours = value.toInt();
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Feature toggle switch
            SwitchListTile(
              title: const Text('Featured Service'),
              subtitle: const Text('Featured services appear on the home page'),
              value: _isFeatured,
              activeColor: AppColors.primaryPurple,
              onChanged: (bool value) {
                setState(() {
                  _isFeatured = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Image picker
            _buildServiceImagePicker(),
            
            const SizedBox(height: 32),
            
            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.isEditing ? 'Update Service' : 'Create Service',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            if (widget.isEditing) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _confirmDeleteService(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete Service',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _confirmDeleteService(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this service? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteService();
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _deleteService() async {
    setState(() => _isSubmitting = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.service!['id'])
          .delete();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error deleting service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}