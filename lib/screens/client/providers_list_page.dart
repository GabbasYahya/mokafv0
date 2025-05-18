import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/provider_detail_page.dart';

class ProvidersListPage extends StatefulWidget {
  final String? categoryFilter;
  
  const ProvidersListPage({super.key, this.categoryFilter});

  @override
  State<ProvidersListPage> createState() => _ProvidersListPageState();
}

class _ProvidersListPageState extends State<ProvidersListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  final _searchController = TextEditingController();
  String? _selectedCategory;
  
  final List<String> _categories = [
    'All Categories',
    'Home Cleaning',
    'Plumbing',
    'Electrical Repair',
    'Lawn Mowing',
    'Tutoring',
    'Moving',
    'Painting',
    'Home Repair'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoryFilter ?? 'All Categories';
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isProvider', isEqualTo: true)
          .get();
          
      final providers = await Future.wait(querySnapshot.docs.map((doc) async {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get provider's average rating and count from reviews
        final reviewsQuery = await FirebaseFirestore.instance
            .collection('reviews')
            .where('providerId', isEqualTo: doc.id)
            .get();
        
        if (reviewsQuery.docs.isNotEmpty) {
          double totalRating = 0;
          for (var review in reviewsQuery.docs) {
            totalRating += (review.data()['rating'] as num).toDouble();
          }
          data['rating'] = totalRating / reviewsQuery.docs.length;
          data['reviewsCount'] = reviewsQuery.docs.length;
        } else {
          data['rating'] = 0.0;
          data['reviewsCount'] = 0;
        }
        
        // Get completed jobs count
        final completedJobsQuery = await FirebaseFirestore.instance
            .collection('appointments')
            .where('providerId', isEqualTo: doc.id)
            .where('status', isEqualTo: 'completed')
            .count()
            .get();
        
        data['completedJobs'] = completedJobsQuery.count;
        
        // Get services offered by this provider
        final servicesQuery = await FirebaseFirestore.instance
            .collection('services')
            .where('providerId', isEqualTo: doc.id)
            .get();
            
        data['services'] = servicesQuery.docs.map((service) {
          final serviceData = service.data();
          serviceData['id'] = service.id;
          return serviceData;
        }).toList();
        
        return data;
      }));
      
      setState(() {
        _providers = List<Map<String, dynamic>>.from(providers);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading providers: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      if (_selectedCategory == 'All Categories') {
        _filteredProviders = _providers;
      } else {
        _filteredProviders = _providers.where((provider) {
          if (provider['serviceProvided'] == _selectedCategory) {
            return true;
          }
          
          final services = provider['services'] as List<dynamic>?;
          if (services != null) {
            return services.any((service) => 
                service['category'] == _selectedCategory);
          }
          
          return false;
        }).toList();
      }
      
      // Apply search filter if text is entered
      if (_searchController.text.isNotEmpty) {
        final searchText = _searchController.text.toLowerCase();
        _filteredProviders = _filteredProviders.where((provider) {
          final String name = (provider['name'] ?? '').toLowerCase();
          final String businessName = (provider['businessName'] ?? '').toLowerCase();
          final String serviceProvided = (provider['serviceProvided'] ?? '').toLowerCase();
          
          return name.contains(searchText) || 
                 businessName.contains(searchText) || 
                 serviceProvided.contains(searchText);
        }).toList();
      }
    });
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
            const Text('Service Providers'),
          ],
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search providers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                _applyFilters();
              },
            ),
          ),
          
          // Categories filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                          _applyFilters();
                        });
                      }
                    },
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: AppColors.primaryPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const Divider(height: 1),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredProviders.length} provider${_filteredProviders.length == 1 ? '' : 's'} found',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          
          // Provider list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProviders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No providers found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProviders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredProviders.length,
                          itemBuilder: (context, index) {
                            return _buildProviderCard(_filteredProviders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProviderDetailPage(providerId: provider['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Provider info section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: provider['profileImage'] != null
                        ? NetworkImage(provider['profileImage'])
                        : null,
                    child: provider['profileImage'] == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // Provider details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider['businessName'] ?? provider['name'] ?? 'Provider',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider['serviceProvided'] ?? 'Service Provider',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Rating and jobs
                        Row(
                          children: [
                            Icon(Icons.star, size: 18, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${provider['rating']?.toStringAsFixed(1) ?? '0.0'} · ',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${provider['completedJobs'] ?? 0} jobs',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Services offered
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...((provider['services'] as List<dynamic>?) ?? [])
                                .take(3)
                                .map<Widget>((service) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primaryPurple.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  service['name'] ?? 'Service',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              );
                            }),
                            
                            if (((provider['services'] as List<dynamic>?)?.length ?? 0) > 3)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '+${((provider['services'] as List<dynamic>?)?.length ?? 0) - 3} more',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions section
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider['address'] ?? 'No address provided',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProviderDetailPage(providerId: provider['id']),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('View Profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Add to the category item click handler in home_page.dart
void _onCategoryTapped(BuildContext context, String category) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProvidersListPage(categoryFilter: category),
    ),
  );
}

// Then use this in your _buildCategoryItem method:
Widget _buildCategoryItem(BuildContext context, String title, IconData icon, Color color) {
  return GestureDetector(
    onTap: () => _onCategoryTapped(context, title),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}