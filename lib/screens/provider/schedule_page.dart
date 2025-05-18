import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mokaf2/screens/provider/booking_detail_page.dart';
import 'dart:convert';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  
  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Filter options
  String _statusFilter = 'all'; // 'all', 'pending', 'confirmed', 'completed', 'canceled'

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: user.uid)
          .get();
          
      final appointments = appointmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Group appointments by day for the calendar
      final events = <DateTime, List<Map<String, dynamic>>>{};
      
      for (var appointment in appointments) {
        final startTime = (appointment['startTime'] as Timestamp).toDate();
        final dateKey = DateTime(startTime.year, startTime.month, startTime.day);
        
        if (events[dateKey] == null) {
          events[dateKey] = [];
        }
        
        events[dateKey]!.add(appointment);
      }
      
      // Sort appointments by time
      events.forEach((date, events) {
        events.sort((a, b) {
          final aTime = (a['startTime'] as Timestamp).toDate();
          final bTime = (b['startTime'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });
      });
      
      setState(() {
        _events = events;
        _isLoading = false;
        
        // Update selected day's appointments
        _updateSelectedDayAppointments();
      });
    } catch (e) {
      print('Error loading appointments: $e');
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
  
  void _updateSelectedDayAppointments() {
    var selectedDateAppointments = _getEventsForDay(_selectedDay);
    
    // Apply status filter if not "all"
    if (_statusFilter != 'all') {
      selectedDateAppointments = selectedDateAppointments
        .where((appointment) => appointment['status'] == _statusFilter)
        .toList();
    }
    
    setState(() => _appointments = selectedDateAppointments);
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
  
  Widget _buildEventMarker(DateTime date, List<Map<String, dynamic>> events) {
    // Count different status types
    int confirmed = 0;
    int pending = 0;
    int other = 0;
    
    for (var event in events) {
      switch (event['status']) {
        case 'confirmed': confirmed++; break;
        case 'pending': pending++; break;
        default: other++;
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pending > 0)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange,
            ),
          ),
        if (pending > 0 && confirmed > 0)
          SizedBox(width: 2),
        if (confirmed > 0)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
          ),
        if ((pending > 0 || confirmed > 0) && other > 0)
          SizedBox(width: 2),
        if (other > 0)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                        markersMaxCount: 1,
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
                        cellMargin: const EdgeInsets.all(4),
                        todayTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonShowsNext: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 18
                        ),
                        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primaryPurple),
                        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primaryPurple),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return _buildEventMarker(date, events.cast<Map<String, dynamic>>());
                          }
                          return null;
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _updateSelectedDayAppointments();
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
                
                // Filter buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM d, yyyy').format(_selectedDay),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.filter_list, size: 18),
                              style: const TextStyle(color: Colors.black87, fontSize: 14),
                              onChanged: (String? value) {
                                if (value != null) {
                                  setState(() {
                                    _statusFilter = value;
                                    _updateSelectedDayAppointments();
                                  });
                                }
                              },
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All bookings'),
                                ),
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Pending'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'confirmed',
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Confirmed'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'completed',
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Completed'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'canceled',
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Canceled'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_appointments.length} appointment(s)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                Expanded(
                  child: _appointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No appointments on ${DateFormat('MMMM d').format(_selectedDay)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_statusFilter != 'all') ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _statusFilter = 'all';
                                      _updateSelectedDayAppointments();
                                    });
                                  },
                                  icon: const Icon(Icons.filter_list_off),
                                  label: const Text('Clear filter'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = _appointments[index];
                            final startTime = (appointment['startTime'] as Timestamp).toDate();
                            final endTime = appointment['endTime'] != null 
                                ? (appointment['endTime'] as Timestamp).toDate()
                                : startTime.add(Duration(hours: appointment['duration'] ?? 1));
                                
                            final status = appointment['status'] as String;
                            final statusColor = _getStatusColor(status);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: statusColor.withOpacity(0.3),
                                  width: status == 'pending' ? 1.5 : 0.5,
                                ),
                              ),
                              elevation: status == 'pending' ? 2 : 1,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingDetailPage(
                                        bookingId: appointment['id'],
                                      ),
                                    ),
                                  ).then((_) => _loadAppointments());
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time and Status
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10, 
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status[0].toUpperCase() + status.substring(1),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      
                                      // Service and Client info
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Client Avatar
                                          if (appointment['clientImage'] != null)
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundImage: MemoryImage(
                                                base64Decode(appointment['clientImage']),
                                              ),
                                            )
                                          else
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.grey[200],
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          
                                          const SizedBox(width: 12),
                                          
                                          // Service and Client details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  appointment['serviceName'] ?? 'Service',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Client: ${appointment['clientName'] ?? 'Unknown'}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                if (appointment['price'] != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Price: \$${(appointment['price'] as num).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          
                                          // Action indicator
                                          if (status == 'pending')
                                            Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: statusColor.withOpacity(0.1),
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              child: Icon(
                                                Icons.notifications_active,
                                                size: 16,
                                                color: statusColor,
                                              ),
                                            ),
                                        ],
                                      ),

                                      if (appointment['location'] != null) ...[
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                appointment['location'],
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
                                      
                                      // Quick actions for pending requests
                                      if (status == 'pending') ...[
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('appointments')
                                                    .doc(appointment['id'])
                                                    .update({'status': 'declined'});
                                                    
                                                // Notify client
                                                _sendNotificationToClient(
                                                  appointment['clientId'],
                                                  appointment['id'],
                                                  'Booking Declined', 
                                                  'Your booking request for ${appointment['serviceName']} has been declined.',
                                                );
                                                
                                                _loadAppointments();
                                              },
                                              child: const Text('Decline'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('appointments')
                                                    .doc(appointment['id'])
                                                    .update({'status': 'confirmed'});
                                                    
                                                // Notify client
                                                _sendNotificationToClient(
                                                  appointment['clientId'],
                                                  appointment['id'],
                                                  'Booking Confirmed', 
                                                  'Your booking for ${appointment['serviceName']} on ${DateFormat('MMM d').format(startTime)} at ${DateFormat('h:mm a').format(startTime)} has been confirmed!',
                                                );
                                                
                                                _loadAppointments();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Accept'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ));
                          },
                        ),
                ),
              ],
            ),
    );
  }
  
  Future<void> _sendNotificationToClient(
    String clientId, 
    String bookingId, 
    String title, 
    String message
  ) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': clientId,
      'title': title,
      'message': message,
      'type': 'booking_update',
      'relatedId': bookingId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}