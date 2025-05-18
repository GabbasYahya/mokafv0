import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:mokaf2/theme_provider.dart';
import 'package:mokaf2/screens/provider/provider_home_page.dart';
import 'package:mokaf2/screens/provider/become_provider_screen.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/profile_page.dart';
import 'package:mokaf2/screens/client/mybookings_page.dart';
import 'package:mokaf2/screens/client/notifications_page.dart';
import 'package:mokaf2/auth/login.dart';
import 'package:mokaf2/screens/client/provider_detail_page.dart'; // Add this import
import 'package:mokaf2/screens/client/service_details_page.dart'; // Import the service details page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  int _currentIndex = 0;
  List<Map<String, dynamic>> _featuredServices = [];
  List<Map<String, dynamic>> _popularProviders = [];
  bool _isLoading = true;
  String _userName = '';
  bool _userIsProvider = false;
  bool _showAllProviders = false; // Add this boolean

  @override
  void initState() {
    super.initState();
    
    // First check if already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _loadHomeData();
      _checkProviderStatus();
    }
    
    // Then listen for auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // When auth state changes to logged in, reload the data
        _loadHomeData();
        _checkProviderStatus();
      }
    });
  }

  // Add this to ensure provider status is checked when the page becomes visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkProviderStatus();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get user profile data
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = userData['name'] ?? user.email?.split('@')[0] ?? 'User';
          });
        }
      }
      
      // 2. Get featured services
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('featured', isEqualTo: true)
          .limit(6)
          .get();
          
      final services = servicesSnapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .toList();
          
      // 3. Get popular providers
      final providersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isProvider', isEqualTo: true)
          .limit(5)
          .get();
          
      final providers = providersSnapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .toList();
          
      setState(() {
        _featuredServices = List<Map<String, dynamic>>.from(services);
        _popularProviders = List<Map<String, dynamic>>.from(providers);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading home data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Improve the provider status check method:
  Future<void> _checkProviderStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isProvider = userData['isProvider'] ?? false;
          
          if (mounted && _userIsProvider != isProvider) {
            setState(() {
              _userIsProvider = isProvider;
            });
            
            // Always update the theme provider
            try {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.setUserHasProviderRole(isProvider);
            } catch (e) {
              print('Error updating theme provider: $e');
            }
            
            print('User provider status updated: $isProvider'); // Debug info
          }
        }
      }
    } catch (e) {
      print('Error checking provider status: $e');
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _onCategoryTapped(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvidersListPage(categoryFilter: category),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 40,
              width: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 40,
                  width: 40,
                  color: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.image_not_supported, size: 20),
                );
              },
            ),
            const SizedBox(width: 12),
            const Text('Mokaf'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(context),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $_userName! 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'What service are you looking for today?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Search bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search for services',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProvidersListPage(searchQuery: value),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                    // Service categories
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Service Categories',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            children: [
                              _buildCategoryItem(context, 'Cleaning', Icons.cleaning_services, Colors.blue),
                              _buildCategoryItem(context, 'Plumbing', Icons.plumbing, Colors.orange),
                              _buildCategoryItem(context, 'Electric', Icons.electrical_services, Colors.red),
                              _buildCategoryItem(context, 'Moving', Icons.local_shipping, Colors.green),
                              _buildCategoryItem(context, 'Painting', Icons.format_paint, Colors.purple),
                              _buildCategoryItem(context, 'Gardening', Icons.yard, Colors.lightGreen),
                              _buildCategoryItem(context, 'Home Repair', Icons.handyman, Colors.brown),
                              _buildCategoryItem(context, 'More', Icons.more_horiz, Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Featured services
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Featured Services',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: _featuredServices.isEmpty
                                ? const Center(child: Text('No featured services available'))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _featuredServices.length,
                                    itemBuilder: (context, index) {
                                      final service = _featuredServices[index];
                                      return _buildServiceCard(service);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Popular providers
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Top-Rated Providers',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_popularProviders.length > 3 && _showAllProviders)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllProviders = false;
                                    });
                                  },
                                  child: const Text('Show Less'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _popularProviders.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text('No top-rated providers available'),
                                ),
                              )
                            : Column(
                                children: [
                                  ListView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: _showAllProviders 
                                      ? _popularProviders.length 
                                      : _popularProviders.length > 3 ? 3 : _popularProviders.length,
                                    itemBuilder: (context, index) {
                                      final provider = _popularProviders[index];
                                      return _buildProviderCard(provider);
                                    },
                                  ),
                                  if (_popularProviders.length > 3 && !_showAllProviders)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _showAllProviders = true;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.primaryPurple.withOpacity(0.5),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'See More Providers',
                                                  style: TextStyle(
                                                    color: AppColors.primaryPurple,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  size: 16,
                                                  color: AppColors.primaryPurple,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Promotions banner
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryPurple, AppColors.primaryPurple.withBlue(180)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 7,
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Get 20% off your first booking!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Use code: MOKAF20',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primaryPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Book Now'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyBookingsPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? "user@example.com";
    String displayName = user?.displayName ?? _userName;
    if (displayName.isEmpty && userEmail.contains('@')) {
      displayName = userEmail.split('@')[0];
    } else if (displayName.isEmpty) {
      displayName = "Mokaf User";
    }
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                              style: TextStyle(color: Theme.of(context).primaryColor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Image.asset(
                            'assets/images/logo.png',
                            height: 40,
                            width: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 40,
                                width: 40,
                                color: Colors.grey.withOpacity(0.2),
                                child: const Icon(Icons.image_not_supported, size: 20),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        userEmail,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('My Bookings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyBookingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              _userIsProvider ? Icons.swap_horiz : Icons.business_center,
            ),
            title: Text(
              _userIsProvider ? 'Switch to Provider View' : 'Become a Provider',
            ),
            onTap: () {
              Navigator.pop(context); // Close drawer
              
              if (_userIsProvider) {
                // User is already a provider, switch to provider view
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                themeProvider.setTheme(ThemeType.provider);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const ProviderHomePage()),
                  (route) => false,
                );
              } else {
                // Navigate to become provider screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BecomeProviderScreen()),
                ).then((_) => _checkProviderStatus()); // Re-check status when returning
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to help
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryItem(BuildContext context, String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _onCategoryTapped(title),
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
  
  Widget _buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () {
        // Navigate to service details page, not provider details
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
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: () {
            if (service['providerId'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProviderDetailPage(providerId: service['providerId']),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: service['imageUrl'] != null
                        ? NetworkImage(service['imageUrl'])
                        : const AssetImage('assets/images/logo.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['name'] ?? 'Service',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service['description'] ?? 'No description',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${(service['price'] is num) ? (service['price'] as num).toStringAsFixed(2) : '0.00'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            Text(
                              ' ${service['rating']?.toStringAsFixed(1) ?? '0.0'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: provider['profileImage'] != null
                    ? NetworkImage(provider['profileImage'])
                    : null,
                child: provider['profileImage'] == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['name'] ?? provider['businessName'] ?? 'Provider',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider['serviceProvided']?.toString() ?? 'Various Services',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        Text(
                          ' ${provider['rating']?.toStringAsFixed(1) ?? '0.0'} · ',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${provider['completedJobs'] ?? 0} jobs',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Book',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// Move this class outside of _HomePageState
class ProvidersListPage extends StatefulWidget {
  final String? categoryFilter;
  final String? searchQuery;

  const ProvidersListPage({
    super.key, 
    this.categoryFilter,
    this.searchQuery,
  });

  @override
  State<ProvidersListPage> createState() => _ProvidersListPageState();
}

class _ProvidersListPageState extends State<ProvidersListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _providers = [];
  
  @override
  void initState() {
    super.initState();
    _loadProviders();
  }
  
  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = FirebaseFirestore.instance.collection('users').where('isProvider', isEqualTo: true);
      
      // Apply category filter if specified
      if (widget.categoryFilter != null) {
        query = query.where('serviceProvided', isEqualTo: widget.categoryFilter);
      }
      
      // Apply search query if specified
      // Note: This is a simple implementation, Firestore doesn't support direct text search
      // For a real app, consider using Algolia or another search solution
      
      final querySnapshot = await query.get();
      
      final providers = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Filter by search query if needed
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        final lowerCaseQuery = widget.searchQuery!.toLowerCase();
        providers.removeWhere((provider) => 
          !(provider['name']?.toString().toLowerCase().contains(lowerCaseQuery) ?? false) &&
          !(provider['businessName']?.toString().toLowerCase().contains(lowerCaseQuery) ?? false) &&
          !(provider['serviceProvided']?.toString().toLowerCase().contains(lowerCaseQuery) ?? false) &&
          !(provider['bio']?.toString().toLowerCase().contains(lowerCaseQuery) ?? false)
        );
      }
      
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading providers: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.categoryFilter != null 
        ? '${widget.categoryFilter} Providers'
        : widget.searchQuery != null
            ? 'Search Results'
            : 'All Providers';
            
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No providers found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.searchQuery != null
                            ? 'Try a different search term'
                            : widget.categoryFilter != null
                                ? 'No providers available for ${widget.categoryFilter}'
                                : 'No service providers available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _providers.length,
                  itemBuilder: (context, index) {
                    final provider = _providers[index];
                    return _buildProviderListItem(context, provider);
                  },
                ),
    );
  }
  
  Widget _buildProviderListItem(BuildContext context, Map<String, dynamic> provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider header with profile image
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: provider['profileImage'] != null
                        ? NetworkImage(provider['profileImage'])
                        : null,
                    child: provider['profileImage'] == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey.shade700)
                        : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider['name'] ?? provider['businessName'] ?? 'Provider',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider['businessName'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          Text(
                            ' ${provider['rating']?.toStringAsFixed(1) ?? '0.0'} ',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            '(${provider['reviewCount'] ?? 0})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Divider
            const Divider(height: 1),
            // Services and location
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.design_services, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider['serviceProvided']?.toString() ?? 'Various Services',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider['address'] ?? 'Location not specified',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (provider['bio'] != null && provider['bio'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider['bio'],
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed: ${provider['completedJobs'] ?? 0} jobs',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('View Profile'),
                      ),
                    ],
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