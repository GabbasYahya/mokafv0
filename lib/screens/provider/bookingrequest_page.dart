import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/constants/app_colors.dart';

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({super.key});

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _confirmedBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get current date without time for comparison
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // Query all bookings for this provider
        final bookingSnapshot = await FirebaseFirestore.instance
            .collection('appointments')
            .where('providerId', isEqualTo: user.uid)
            .orderBy('startTime', descending: true)
            .get();
        
        final pendingBookings = <Map<String, dynamic>>[];
        final confirmedBookings = <Map<String, dynamic>>[];
        final pastBookings = <Map<String, dynamic>>[];
        
        for (var doc in bookingSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          
          final bookingDate = (data['startTime'] as Timestamp).toDate();
          final status = data['status'] as String;
          
          // Sort bookings into categories
          if (status == 'pending') {
            pendingBookings.add(data);
          } else if (status == 'confirmed' && bookingDate.isAfter(now)) {
            confirmedBookings.add(data);
          } else if (status == 'confirmed' && bookingDate.isBefore(now) || 
                     status == 'completed' || 
                     status == 'canceled' || 
                     status == 'declined') {
            pastBookings.add(data);
          }
        }
        
        setState(() {
          _pendingBookings = pendingBookings;
          _confirmedBookings = confirmedBookings;
          _pastBookings = pastBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bookings: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(bookingId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Create notification for client
      final bookingDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(bookingId)
          .get();
      
      if (bookingDoc.exists) {
        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        
        String title, message;
        if (status == 'confirmed') {
          title = 'Booking Confirmed';
          message = 'Your booking for ${bookingData['serviceName']} has been confirmed.';
        } else if (status == 'declined') {
          title = 'Booking Declined';
          message = 'Unfortunately, your booking for ${bookingData['serviceName']} was declined.';
        } else if (status == 'completed') {
          title = 'Service Completed';
          message = 'Your booking for ${bookingData['serviceName']} has been marked as completed.';
        } else {
          title = 'Booking Update';
          message = 'Your booking for ${bookingData['serviceName']} status has been updated to $status.';
        }
        
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
              'userId': bookingData['clientId'],
              'title': title,
              'message': message,
              'type': 'booking',
              'relatedId': bookingId,
              'read': false,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $status successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload bookings
      _loadBookings();
      
    } catch (e) {
      print('Error updating booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(
              text: 'Pending',
              icon: Badge(
                label: Text(_pendingBookings.length.toString()),
                isLabelVisible: _pendingBookings.isNotEmpty,
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Upcoming',
              icon: Badge(
                label: Text(_confirmedBookings.length.toString()),
                isLabelVisible: _confirmedBookings.isNotEmpty,
                child: const Icon(Icons.calendar_today),
              ),
            ),
            Tab(
              text: 'Past',
              icon: const Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Pending bookings
                _buildBookingList(_pendingBookings, isPending: true),
                
                // Confirmed/upcoming bookings
                _buildBookingList(_confirmedBookings, isPending: false),
                
                // Past bookings
                _buildBookingList(_pastBookings, isPending: false, showStatus: false),
              ],
            ),
    );
  }
  
  Widget _buildBookingList(List<Map<String, dynamic>> bookings, {required bool isPending, bool showStatus = true}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.pending_actions : Icons.event_available,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending booking requests' : 'No confirmed or past bookings',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final bookingDate = (booking['startTime'] as Timestamp).toDate();
        final endDate = booking['endTime'] != null 
            ? (booking['endTime'] as Timestamp).toDate() 
            : bookingDate.add(const Duration(hours: 1));
        
        final duration = endDate.difference(bookingDate).inHours;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                      child: Text(
                        booking['clientName'] != null && booking['clientName'].toString().isNotEmpty
                            ? booking['clientName'].toString().substring(0, 1).toUpperCase()
                            : 'C',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['clientName'] ?? 'Client',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (booking['clientPhone'] != null && booking['clientPhone'].toString().isNotEmpty)
                            Text(
                              booking['clientPhone'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    if (showStatus) ...{
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending 
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPending ? 'Pending' : 'Confirmed',
                          style: TextStyle(
                            color: isPending ? Colors.orange : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    },
                  ],
                ),
                const Divider(height: 24),
                _infoRow('Service', booking['serviceName'] ?? 'Service'),
                _infoRow('Price', '\$${(booking['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                _infoRow('Date', DateFormat('EEEE, MMM d, yyyy').format(bookingDate)),
                _infoRow('Time', '${DateFormat('h:mm a').format(bookingDate)} (${duration}h)'),
                if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking['notes'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isPending)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _updateBookingStatus(
                          booking['id'], 
                          'cancelled',
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _updateBookingStatus(
                          booking['id'],
                          'confirmed',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  )
                else if (showStatus)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _updateBookingStatus(
                          booking['id'],
                          'cancelled',
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          // TODO: Implement messaging or contact client
                        },
                        child: const Text('Contact Client'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}