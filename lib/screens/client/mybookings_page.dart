import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/booking_detail_page.dart';
import 'package:table_calendar/table_calendar.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  bool _isLoading = false;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  List<Map<String, dynamic>> _todayBookings = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  
  @override
  void initState() {
    super.initState();
    _loadBookings();
  }
  
  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get all bookings for the current user
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clientId', isEqualTo: user.uid)
          .get();
          
      final events = <DateTime, List<Map<String, dynamic>>>{};
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final bookingTime = (data['startTime'] as Timestamp).toDate();
        final dateKey = DateTime(bookingTime.year, bookingTime.month, bookingTime.day);
        
        if (events[dateKey] == null) {
          events[dateKey] = [];
        }
        events[dateKey]!.add(data);
      }
      
      // Sort bookings for each day by time
      events.forEach((date, bookings) {
        bookings.sort((a, b) {
          final aTime = (a['startTime'] as Timestamp).toDate();
          final bTime = (b['startTime'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });
      });
      
      // Get today's bookings
      final todayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final todayBookings = events[todayKey] ?? [];
      
      setState(() {
        _events = events;
        _todayBookings = todayBookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }
  
  void _updateSelectedDayBookings() {
    final selectedDateBookings = _getEventsForDay(_selectedDay);
    setState(() => _todayBookings = selectedDateBookings);
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'canceled':
      case 'declined': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar view
                Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      eventLoader: _getEventsForDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      calendarStyle: CalendarStyle(
                        markersMaxCount: 3,
                        markerDecoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonShowsNext: false,
                        titleCentered: true,
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _updateSelectedDayBookings();
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                  ),
                ),
                
                // Date heading
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_todayBookings.length} Bookings',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bookings for selected day
                Expanded(
                  child: _todayBookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No bookings for this day',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _todayBookings.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final booking = _todayBookings[index];
                            final startTime = (booking['startTime'] as Timestamp).toDate();
                            final endTime = (booking['endTime'] as Timestamp?)?.toDate() ?? 
                                startTime.add(Duration(hours: booking['duration'] ?? 1));
                            final status = booking['status'] as String;
                            final statusColor = _getStatusColor(status);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: statusColor.withOpacity(0.5),
                                  width: status == 'pending' ? 2 : 0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Navigate to booking details
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingDetailPage(bookingId: booking['id']),
                                    ),
                                  ).then((_) => _loadBookings());
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time and status
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status.substring(0, 1).toUpperCase() + status.substring(1),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Service and provider info
                                      Text(
                                        booking['serviceName'] ?? 'Service',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Provider: ${booking['providerName'] ?? 'Service Provider'}',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontSize: 14,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Location
                                      if (booking['location'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                booking['location'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Price
                                      Text(
                                        '\$${(booking['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primaryPurple,
                                        ),
                                      ),
                                      
                                      // Cancel button (for pending or confirmed)
                                      if (status == 'pending' || status == 'confirmed') ...[
                                        const Divider(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => _confirmCancelBooking(booking['id']),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text('Cancel Booking'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
  
  void _confirmCancelBooking(String bookingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Booking'),
          content: const Text('Are you sure you want to cancel this booking?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(bookingId);
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _cancelBooking(String bookingId) async {
    setState(() => _isLoading = true);
    
    try {
      // Update the booking status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(bookingId)
          .update({
            'status': 'canceled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          
      // Get the booking details for the notification
      final bookingDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(bookingId)
          .get();
          
      if (bookingDoc.exists) {
        final bookingData = bookingDoc.data()!;
        
        // Create notification for provider
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
              'userId': bookingData['providerId'],
              'title': 'Booking Canceled',
              'message': 'A booking for ${bookingData['serviceName']} has been canceled by the client.',
              'type': 'booking_update',
              'relatedId': bookingId,
              'read': false,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking canceled successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadBookings();
    } catch (e) {
      print('Error canceling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }
}
