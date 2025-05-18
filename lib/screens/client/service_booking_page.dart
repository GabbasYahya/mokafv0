import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/mybookings_page.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ServiceBookingPage extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  
  const ServiceBookingPage({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
  });

  @override
  State<ServiceBookingPage> createState() => _ServiceBookingPageState();
}

class _ServiceBookingPageState extends State<ServiceBookingPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  
  // List of unavailable time slots for the selected date
  List<TimeOfDay> _unavailableSlots = [];
  
  // Calendar format
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now().add(const Duration(days: 1));
  
  @override
  void initState() {
    super.initState();
    _checkAvailability(_selectedDate);
  }
  
  // Function to check provider's availability for the selected date
  Future<void> _checkAvailability(DateTime date) async {
    try {
      // Get the provider's appointments for the selected date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: widget.providerId)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      final unavailable = appointmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        return TimeOfDay(hour: startTime.hour, minute: startTime.minute);
      }).toList();
      
      setState(() {
        _unavailableSlots = unavailable;
      });
    } catch (e) {
      print('Error checking availability: $e');
    }
  }
  
  // Check if a time slot is available
  bool _isTimeAvailable(TimeOfDay time) {
    for (var unavailableTime in _unavailableSlots) {
      if (unavailableTime.hour == time.hour && unavailableTime.minute == time.minute) {
        return false;
      }
    }
    return true;
  }
  
  // Submit booking request
  Future<void> _submitBookingRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to book a service')),
        );
        setState(() => _isSubmitting = false);
        return;
      }
      
      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found')),
        );
        setState(() => _isSubmitting = false);
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Create the datetime for the selected date and time
      final bookingDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      // Create the appointment in Firestore
      await FirebaseFirestore.instance.collection('appointments').add({
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'clientId': user.uid,
        'clientName': userData['name'] ?? user.email,
        'clientPhone': userData['phone'] ?? '',
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,
        'price': widget.servicePrice,
        'startTime': Timestamp.fromDate(bookingDateTime),
        'location': _locationController.text,
        'notes': _notesController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Create notification for provider
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.providerId,
        'title': 'New Booking Request',
        'message': 'You have a new booking request for ${widget.serviceName} on ${DateFormat('MMM d, yyyy').format(_selectedDate)} at ${_selectedTime.format(context)}',
        'type': 'booking',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'type': 'booking_request',
        },
      });
      
      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyBookingsPage()),
        );
      }
    } catch (e) {
      print('Error submitting booking request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isSubmitting = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Information
              Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 24.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildInfoRow('Service:', widget.serviceName),
                      const SizedBox(height: 8),
                      _buildInfoRow('Provider:', widget.providerName),
                      const SizedBox(height: 8),
                      _buildInfoRow('Price:', '\$${widget.servicePrice.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              
              // Calendar selection
              Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 24.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 90)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDate, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDate, selectedDay)) {
                        setState(() {
                          _selectedDate = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _checkAvailability(selectedDay);
                      }
                    },
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
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
                      formatButtonVisible: true,
                      titleCentered: true,
                    ),
                  ),
                ),
              ),
              
              // Time selection
              Text(
                'Select Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 16, // 8AM to 8PM, every hour
                itemBuilder: (context, index) {
                  final hour = 8 + (index ~/ 2);
                  final minute = (index % 2) * 30;
                  final time = TimeOfDay(hour: hour, minute: minute);
                  final isAvailable = _isTimeAvailable(time);
                  final isSelected = _selectedTime.hour == time.hour && _selectedTime.minute == time.minute;
                  
                  return GestureDetector(
                    onTap: isAvailable ? () {
                      setState(() {
                        _selectedTime = time;
                      });
                    } : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : isAvailable
                                ? AppColors.primaryPurple.withOpacity(0.1)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : isAvailable
                                  ? AppColors.primaryPurple.withOpacity(0.5)
                                  : Colors.grey[400]!,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        DateFormat('h:mm a').format(DateTime(2023, 1, 1, time.hour, time.minute)),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? Colors.black
                                  : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Service Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a service location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              
              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBookingRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send Booking Request',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}