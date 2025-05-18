import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/provider/booking_request_detail_page.dart';
import 'package:intl/intl.dart';

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({super.key});

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _pastRequests = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookingRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingRequests() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get pending requests
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      final pendingRequests = pendingSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Get past requests
      final pastSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: user.uid)
          .where('status', whereIn: ['confirmed', 'declined', 'completed', 'canceled'])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final pastRequests = pastSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _pendingRequests = List<Map<String, dynamic>>.from(pendingRequests);
        _pastRequests = List<Map<String, dynamic>>.from(pastRequests);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking requests: $e');
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
      appBar: AppBar(
        title: const Text('Booking Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending (${_pendingRequests.length})',
            ),
            const Tab(
              text: 'History',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookingRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending requests tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pendingRequests.isEmpty
                  ? _buildEmptyState('No pending booking requests')
                  : RefreshIndicator(
                      onRefresh: _loadBookingRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, index) {
                          return _buildBookingRequestCard(_pendingRequests[index]);
                        },
                      ),
                    ),

          // History tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pastRequests.isEmpty
                  ? _buildEmptyState('No past booking requests')
                  : RefreshIndicator(
                      onRefresh: _loadBookingRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _pastRequests.length,
                        itemBuilder: (context, index) {
                          return _buildBookingRequestCard(_pastRequests[index]);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _loadBookingRequests,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingRequestCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final createdAt = (booking['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final requestedDate = (booking['startTime'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: status == 'pending'
            ? BorderSide(color: AppColors.primaryPurple.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      elevation: status == 'pending' ? 2 : 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingRequestDetailPage(bookingId: booking['id']),
            ),
          ).then((_) => _loadBookingRequests());
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: booking['clientImage'] != null
                        ? NetworkImage(booking['clientImage'])
                        : null,
                    child: booking['clientImage'] == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Booking details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking['serviceName'] ?? 'Service Request',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'From: ${booking['clientName'] ?? 'Client'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        if (requestedDate != null) ...[
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('EEE, MMM d, yyyy • h:mm a').format(requestedDate),
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking['location'] != null && booking['location'].toString().isNotEmpty
                                    ? booking['location'].toString()
                                    : 'No address provided',
                                style: TextStyle(color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (booking['price'] != null) ...[
                              Text(
                                '\$${(booking['price'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
                            Text(
                              'Requested ${DateFormat.yMd().add_jm().format(createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (status == 'pending') ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showDeclineDialog(booking['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[700]!),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAcceptDialog(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    late Color color;
    late IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'declined':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.done_all;
        break;
      case 'canceled':
        color = Colors.grey;
        icon = Icons.remove_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.capitalizeFirstLetter(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );  // Added missing closing bracket here
  }

  Future<void> _showAcceptDialog(Map<String, dynamic> booking) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Accept Booking Request'),
          content: const Text('Are you sure you want to accept this booking request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateBookingStatus(booking['id'], 'confirmed');
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeclineDialog(String bookingId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decline Booking Request'),
          content: const Text('Are you sure you want to decline this booking request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateBookingStatus(bookingId, 'declined');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(bookingId)
          .update({'status': status});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking request $status')),
        );
      }

      // Reload booking requests
      _loadBookingRequests();
    } catch (e) {
      print('Error updating booking status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

extension StringCasingExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}