import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/screens/provider/myservices_page.dart';
import 'package:mokaf2/screens/provider/schedule_page.dart';
import 'package:mokaf2/screens/provider/bookingrequest_page.dart';
import 'package:mokaf2/screens/provider/provider_profile_page.dart';
import 'package:mokaf2/screens/provider/provider_notifications_page.dart';
import 'package:mokaf2/screens/client/home_page.dart'; // Added missing import
import 'package:provider/provider.dart';
import 'package:mokaf2/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mokaf2/auth/login.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  bool _isLoading = true;
  String _providerName = '';
  String _businessName = '';
  String _profileImage = '';
  double _rating = 0.0;
  int _upcomingBookings = 0;
  int _pendingRequests = 0;
  double _totalEarnings = 0;
  double _monthlyEarnings = 0;
  List<Map<String, dynamic>> _recentBookings = [];
  List<FlSpot> _weeklyEarningsData = [];
  Map<String, double> _serviceDistribution = {};
  Map<String, dynamic>? _nextAppointment; // Added for next appointment
  
  final List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load provider profile
        final providerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (providerDoc.exists) {
          final providerData = providerDoc.data() as Map<String, dynamic>;
          
          // Load upcoming bookings count
          final now = DateTime.now();
          final upcomingQuery = await FirebaseFirestore.instance
              .collection('appointments')
              .where('providerId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'confirmed')
              .where('startTime', isGreaterThan: Timestamp.fromDate(now))
              .count()
              .get();
              
          // Load pending requests count
          final pendingQuery = await FirebaseFirestore.instance
              .collection('appointments')
              .where('providerId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending')
              .count()
              .get();
          
          // Load recent bookings
          final recentQuery = await FirebaseFirestore.instance
              .collection('appointments')
              .where('providerId', isEqualTo: user.uid)
              .orderBy('startTime', descending: true)
              .limit(5)
              .get();
          
          final recentBookings = recentQuery.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Check for next appointment
          Map<String, dynamic>? nextAppointment;
          if (recentBookings.isNotEmpty) {
            for (var booking in recentBookings) {
              if ((booking['status'] == 'confirmed' || booking['status'] == 'pending') && 
                  (booking['startTime'] as Timestamp).toDate().isAfter(now)) {
                nextAppointment = booking;
                break;
              }
            }
          }
          
          // Calculate total earnings
          final earningsQuery = await FirebaseFirestore.instance
              .collection('payments')
              .where('providerId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'completed')
              .get();
              
          double totalEarnings = 0;
          double monthlyEarnings = 0;
          final currentMonth = DateTime.now().month;
          final currentYear = DateTime.now().year;
          
          // Weekly earnings data
          Map<int, double> weeklyData = {};
          for (int i = 0; i < 7; i++) {
            weeklyData[i] = 0;
          }
          
          // Service distribution
          Map<String, double> serviceDistribution = {};
          
          for (var doc in earningsQuery.docs) {
            final paymentData = doc.data();
            final amount = (paymentData['amount'] as num).toDouble();
            totalEarnings += amount;
            
            final paymentDate = (paymentData['timestamp'] as Timestamp).toDate();
            
            // Calculate monthly earnings
            if (paymentDate.month == currentMonth && paymentDate.year == currentYear) {
              monthlyEarnings += amount;
            }
            
            // Calculate weekly earnings (last 7 days)
            final difference = DateTime.now().difference(paymentDate).inDays;
            if (difference < 7) {
              final weekday = paymentDate.weekday - 1; // 0 = Monday, 6 = Sunday
              weeklyData[weekday] = (weeklyData[weekday] ?? 0) + amount;
            }
            
            // Track service distribution
            final serviceType = paymentData['serviceType'] as String?;
            if (serviceType != null) {
              serviceDistribution[serviceType] = (serviceDistribution[serviceType] ?? 0) + amount;
            }
          }
          
          // Convert weekly data to chart points
          List<FlSpot> weeklyChartData = [];
          weeklyData.forEach((day, amount) {
            weeklyChartData.add(FlSpot(day.toDouble(), amount));
          });
          
          setState(() {
            _providerName = providerData['name'] ?? user.email?.split('@')[0] ?? 'Provider';
            _businessName = providerData['businessName'] ?? '';
            _profileImage = providerData['profileImage'] ?? '';
            _rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
            _upcomingBookings = upcomingQuery.count ?? 0;
            _pendingRequests = pendingQuery.count ?? 0;
            _totalEarnings = totalEarnings;
            _monthlyEarnings = monthlyEarnings;
            _recentBookings = List<Map<String, dynamic>>.from(recentBookings);
            _weeklyEarningsData = weeklyChartData;
            _serviceDistribution = serviceDistribution;
            _nextAppointment = nextAppointment;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context); // Define theme correctly

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
            const Text('Provider Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProviderNotificationsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProviderProfilePage(),
                ),
              ).then((_) => _loadDashboardData());
            },
          ),
        ],
      ),
      drawer: _buildProviderDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider profile header
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: _profileImage.isNotEmpty
                                    ? NetworkImage(_profileImage)
                                    : null,
                                child: _profileImage.isEmpty
                                    ? const Icon(Icons.person, size: 30, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _providerName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_businessName.isNotEmpty)
                                      Text(
                                        _businessName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber.shade300,
                                        ),
                                        Text(
                                          ' $_rating',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          ' • Provider',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProviderProfilePage(),
                                    ),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Upcoming', _upcomingBookings.toString(), Icons.calendar_today),
                              _buildStatItem('Pending', _pendingRequests.toString(), Icons.hourglass_empty),
                              _buildStatItem('Rating', _rating.toStringAsFixed(1), Icons.star),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Key metrics / stats cards
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Earnings Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEarningsCard(
                                  'Total Earnings',
                                  '\$${_totalEarnings.toStringAsFixed(2)}',
                                  Colors.blue,
                                  Icons.account_balance_wallet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEarningsCard(
                                  'This Month',
                                  '\$${_monthlyEarnings.toStringAsFixed(2)}',
                                  Colors.green,
                                  Icons.date_range,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quick actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Quick Actions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildQuickActionButton(
                            context,
                            Icons.calendar_today_outlined,
                            'Schedule',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SchedulePage()),
                              );
                            },
                          ),
                          _buildQuickActionButton(
                            context,
                            Icons.list_alt_outlined,
                            'Services',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyServicesPage()),
                              );
                            },
                          ),
                          _buildQuickActionButton(
                            context,
                            Icons.pending_actions,
                            'Requests',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BookingRequestsPage()),
                              );
                            },
                          ),
                          _buildQuickActionButton(
                            context,
                            Icons.swap_horiz,
                            'Switch View',
                            () {
                              themeProvider.setTheme(ThemeType.client);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const HomePage()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Next appointment card
                    if (_nextAppointment != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Next Appointment',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildNextAppointmentCard(context, _nextAppointment!),
                      ),
                    ],

                    // Weekly Earnings Chart
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'Weekly Earnings',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(16.0),
                      child: _buildWeeklyEarningsChart(),
                    ),

                    // Recent Bookings
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Bookings',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SchedulePage()),
                              );
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    _recentBookings.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_note_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No recent bookings',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _recentBookings.length,
                            itemBuilder: (context, index) {
                              final booking = _recentBookings[index];
                              final bookingDate = (booking['startTime'] as Timestamp).toDate();
                              
                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 12.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16.0),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    child: Text(
                                      booking['clientName'] != null && booking['clientName'].toString().isNotEmpty
                                          ? booking['clientName'].toString().substring(0, 1).toUpperCase()
                                          : 'C',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    booking['serviceName'] ?? 'Unnamed Service',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Client: ${booking['clientName'] ?? 'Unknown'}'),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Date: ${DateFormat('MMM d, yyyy').format(bookingDate)}, ${booking['time'] ?? ''}',
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(booking['status'] ?? 'Pending').withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              booking['status'] ?? 'Pending',
                                              style: TextStyle(
                                                color: _getStatusColor(booking['status'] ?? 'Pending'),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (booking['price'] != null) 
                                            Text('\$${(booking['price'] as num).toStringAsFixed(2)}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    // Navigate to booking detail
                                  },
                                ),
                              );
                            },
                          ),
                        
                    // Tips for Service Providers
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'Provider Tips',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: theme.primaryColor.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, color: theme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Did you know?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Providers who respond to booking requests within 30 minutes are 70% more likely to get positive reviews!',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {
                                  // Navigate to provider tips
                                },
                                child: const Text('View More Tips'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Update this based on the selected index
        onTap: (index) {
          // Handle navigation based on the selected index
          switch (index) {
            case 0:
              // Home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProviderHomePage()),
              );
              break;
            case 1:
              // Requests
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookingRequestsPage()),
              );
              break;
            case 2:
              // Schedule
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SchedulePage()),
              );
              break;
            case 3:
              // Profile
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProviderProfilePage()),
              );
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(Icons.notifications),
                if (_pendingRequests > 0) // Add a notification indicator
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: const Text(
                        '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.2),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildNextAppointmentCard(BuildContext context, Map<String, dynamic> appointment) {
    final appointmentTime = (appointment['startTime'] as Timestamp).toDate();
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(appointmentTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(appointmentTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  appointment['clientName'] ?? 'Unknown Client',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            Container(height: 8),
            Row(
              children: [
                Icon(Icons.design_services, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment['serviceName'] ?? 'Unnamed Service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Navigate to appointment details
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Details'),
                ),
                TextButton(
                  onPressed: () {
                    // Handle contact client
                  },
                  child: const Text('Contact Client'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyEarningsChart() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _weeklyEarningsData.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No earnings data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: 1,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= _weekdays.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(_weekdays[value.toInt()]);
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('\$${value.toInt()}');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: _findMaxY() + 20,
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklyEarningsData,
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    ),
                  )
                ],
              ),
            ),
      ),
    );
  }
  
  double _findMaxY() {
    double max = 0;
    for (var spot in _weeklyEarningsData) {
      if (spot.y > max) {
        max = spot.y;
      }
    }
    return max;
  }

  Widget _buildProviderDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Provider Menu',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _providerName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (_businessName.isNotEmpty)
                  Text(
                    _businessName,
                    style: const TextStyle(color: Colors.white70, fontSize: 14.0),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.design_services_outlined), // Changed icon
            title: const Text('My Services'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('My Schedule'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.mark_email_read_outlined), // Changed icon
            title: const Text('Booking Requests'),
            onTap: () {
              Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingRequestsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderProfilePage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Switch to Client View'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              themeProvider.setTheme(ThemeType.client);
              // Use pushAndRemoveUntil to clear the navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
              );
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

  Widget _buildEarningsCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}