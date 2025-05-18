import 'package:flutter/material.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/screens/client/booking_confirmation_page.dart';
import 'package:table_calendar/table_calendar.dart';

class RequestBookingPage extends StatefulWidget {
  final String serviceId;
  final String providerId;
  
  const RequestBookingPage({
    super.key, 
    required this.serviceId, 
    required this.providerId,
  });

  @override
  State<RequestBookingPage> createState() => _RequestBookingPageState();
}

class _RequestBookingPageState extends State<RequestBookingPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _serviceData;
  Map<String, dynamic>? _providerData;
  Map<String, dynamic>? _providerSchedule;
  
  final _formKey = GlobalKey<FormState>();
  
  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now().add(const Duration(days: 1));
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Available time slots
  Map<DateTime, List<String>> _unavailableSlots = {};
  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load service data
      final serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();
          
      if (!serviceDoc.exists) {
        throw 'Service not found';
      }
      
      final serviceData = serviceDoc.data()!;
      serviceData['id'] = serviceDoc.id;
      
      // Load provider data
      final providerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.providerId)
          .get();
          
      if (!providerDoc.exists) {
        throw 'Provider not found';
      }
      
      final providerData = providerDoc.data()!;
      providerData['id'] = providerDoc.id;

      // Load provider schedule
      final scheduleDoc = await FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.providerId)
          .get();
          
      Map<String, dynamic>? providerSchedule;
      if (scheduleDoc.exists) {
        providerSchedule = scheduleDoc.data();
      } else {
        // Default schedule if none exists
        providerSchedule = {
          'monday': {'isWorkingDay': true, 'startTime': '09:00', 'endTime': '17:00'},
          'tuesday': {'isWorkingDay': true, 'startTime': '09:00', 'endTime': '17:00'},
          'wednesday': {'isWorkingDay': true, 'startTime': '09:00', 'endTime': '17:00'},
          'thursday': {'isWorkingDay': true, 'startTime': '09:00', 'endTime': '17:00'},
          'friday': {'isWorkingDay': true, 'startTime': '09:00', 'endTime': '17:00'},
          'saturday': {'isWorkingDay': false},
          'sunday': {'isWorkingDay': false},
        };
      }
      
      setState(() {
        _serviceData = serviceData;
        _providerData = providerData;
        _providerSchedule = providerSchedule;
        _isLoading = false;
      });
      
      // Load unavailable time slots
      await _loadUnavailableSlots();
      
      // Update available time slots for selected day
      _updateAvailableTimeSlots();
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      
      // Navigate back on error
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }
  
  Future<void> _loadUnavailableSlots() async {
    try {
      // Load bookings for next 90 days
      final startDate = DateTime.now();
      final endDate = DateTime.now().add(const Duration(days: 90));
      
      final bookedSlotsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: widget.providerId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();
      
      final unavailableSlots = <DateTime, List<String>>{};
      
      for (var doc in bookedSlotsSnapshot.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final date = DateTime(startTime.year, startTime.month, startTime.day);
        final timeSlot = DateFormat('HH:mm').format(startTime);
        
        if (unavailableSlots[date] == null) {
          unavailableSlots[date] = [];
        }
        
        unavailableSlots[date]!.add(timeSlot);
      }
      
      setState(() {
        _unavailableSlots = unavailableSlots;
      });
    } catch (e) {
      print('Error loading unavailable slots: $e');
    }
  }
  
  void _updateAvailableTimeSlots() {
    if (_providerSchedule == null) return;
    
    final List<String> timeSlots = [];
    final weekday = DateFormat('EEEE').format(_selectedDate).toLowerCase();
    
    // Check if the selected day is a working day
    if (_providerSchedule![weekday] != null && 
        _providerSchedule![weekday]['isWorkingDay'] == true) {
      
      final startTimeStr = _providerSchedule![weekday]['startTime'] ?? '09:00';
      final endTimeStr = _providerSchedule![weekday]['endTime'] ?? '17:00';
      
      // Parse hours and minutes
      final startHour = int.parse(startTimeStr.split(':')[0]);
      final startMinute = int.parse(startTimeStr.split(':')[1]);
      final endHour = int.parse(endTimeStr.split(':')[0]);
      final endMinute = int.parse(endTimeStr.split(':')[1]);
      
      // Create time slots at 1-hour intervals
      var currentTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, startHour, startMinute);
      final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, endHour, endMinute);
      
      final serviceDuration = _serviceData!['duration'] ?? 1;
      
      while (currentTime.add(Duration(hours: serviceDuration)).isBefore(endTime) || 
             currentTime.add(Duration(hours: serviceDuration)).isAtSameMomentAs(endTime)) {
        
        // Format as HH:MM
        final timeSlot = DateFormat('HH:mm').format(currentTime);
        
        // Check if this slot is available (not in unavailable slots)
        final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        if (!(_unavailableSlots[selectedDate]?.contains(timeSlot) ?? false)) {
          timeSlots.add(timeSlot);
        }
        
        // Move to next slot (1 hour increment)
        currentTime = currentTime.add(const Duration(hours: 1));
      }
    }
    
    setState(() {
      _availableTimeSlots = timeSlots;
      // Clear selected time if it's no longer available
      if (!timeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = null;
      }
    });
  }
  
  bool _isDayAvailable(DateTime day) {
    if (day.isBefore(DateTime.now())) {
      return false;  // Past dates are not available
    }
    
    if (_providerSchedule == null) return false;
    
    final weekday = DateFormat('EEEE').format(day).toLowerCase();
    return _providerSchedule![weekday]?['isWorkingDay'] == true;
  }
  
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedTimeSlot == null) {
      // Show error message if time slot is not selected
      if (_selectedTimeSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a time slot'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() => _isSubmitting = true);
    String bookingId = '';
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to submit a booking request.');
      }
      
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!userDoc.exists) {
        throw Exception('User profile not found.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Parse selected time
      final timeParts = _selectedTimeSlot!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Create DateTime from date and time
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );
      
      // Calculate end time based on service duration
      final duration = _serviceData!['duration'] ?? 1;
      final endTime = startTime.add(Duration(hours: duration));
      
      // Create booking
      final bookingRef = await FirebaseFirestore.instance.collection('appointments').add({
        'serviceId': widget.serviceId,
        'serviceName': _serviceData!['name'],
        'providerId': widget.providerId,
        'providerName': _providerData!['businessName'] ?? 
                       _providerData!['displayName'] ??
                       _providerData!['name'] ?? 
                       'Service Provider',
        'clientId': user.uid,
        'clientName': userData['name'] ?? user.email?.split('@')[0],
        'clientImage': userData['profileImageBase64'],
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'location': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        'price': _serviceData!['price'],
        'duration': duration,
        'status': 'pending',  // Requires provider approval
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      bookingId = bookingRef.id;
      
      // Create notification for provider
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.providerId,
        'title': 'New Booking Request',
        'message': 'You have a new booking request for ${_serviceData!['name']} on ${DateFormat('MMM d, yyyy').format(_selectedDate)} at $_selectedTimeSlot.',
        'type': 'booking_request',
        'relatedId': bookingId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Navigate to confirmation page
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationPage(bookingId: bookingId),
        ),
      );
    } catch (e) {
      print('Error submitting booking request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Booking'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Service details card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _serviceData!['name'] ?? 'Service',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Provider: ${_providerData!['businessName'] ?? 
                                         _providerData!['displayName'] ?? 
                                         _providerData!['name'] ?? 'Provider'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '\$${(_serviceData!['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Duration: ${_serviceData!['duration'] ?? 1} hour(s)',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Select date
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 16),
                          TableCalendar(
                            firstDay: DateTime.now(),
                            lastDay: DateTime.now().add(const Duration(days: 90)),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                            calendarFormat: _calendarFormat,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            calendarStyle: CalendarStyle(
                              selectedDecoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              // Disable non-working days
                              disabledTextStyle: const TextStyle(color: Colors.grey),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonShowsNext: false,
                              titleCentered: true,
                            ),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDate = selectedDay;
                                _focusedDay = focusedDay;
                                _selectedTimeSlot = null; // Clear selected time
                                _updateAvailableTimeSlots();
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
                            enabledDayPredicate: _isDayAvailable,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Select Time:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  
                  // Time slots
                  _availableTimeSlots.isEmpty
                      ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Icon(Icons.access_time, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No available time slots for this day',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTimeSlots.map((timeSlot) {
                            final isSelected = timeSlot == _selectedTimeSlot;
                            
                            return ChoiceChip(
                              label: Text(timeSlot),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTimeSlot = selected ? timeSlot : null;
                                });
                              },
                              backgroundColor: Colors.grey[100],
                              selectedColor: AppColors.primaryPurple,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            );
                          }).toList(),
                        ),
                  
                  const SizedBox(height: 24),
                  
                  // Location
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Service Location',
                      hintText: 'Enter the address for the service',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      hintText: 'Any special requests or instructions',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Book button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text('Book Now', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}