import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mokaf2/constants/app_colors.dart';

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  bool _isLoading = true;
  Map<String, dynamic> _schedule = {};
  
  final List<String> _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  
  final List<String> _displayWeekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }
  
  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get existing schedule
        final scheduleDoc = await FirebaseFirestore.instance
            .collection('providerSchedules')
            .doc(user.uid)
            .get();
            
        if (scheduleDoc.exists) {
          setState(() {
            _schedule = scheduleDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          // Create default schedule
          Map<String, dynamic> defaultSchedule = {};
          
          for (final day in _weekdays) {
            defaultSchedule[day] = {
              'isWorkingDay': day != 'saturday' && day != 'sunday',
              'startTime': '09:00',
              'endTime': '17:00',
            };
          }
          
          setState(() {
            _schedule = defaultSchedule;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading schedule: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('providerSchedules')
            .doc(user.uid)
            .set(_schedule);
            
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _updateDayStatus(String day, bool value) {
    setState(() {
      if (_schedule[day] == null) {
        _schedule[day] = {
          'isWorkingDay': value,
          'startTime': '09:00',
          'endTime': '17:00',
        };
      } else {
        _schedule[day]['isWorkingDay'] = value;
      }
    });
  }
  
  void _updateDayTimes(String day, String startTime, String endTime) {
    setState(() {
      if (_schedule[day] == null) {
        _schedule[day] = {
          'isWorkingDay': true,
          'startTime': startTime,
          'endTime': endTime,
        };
      } else {
        _schedule[day]['startTime'] = startTime;
        _schedule[day]['endTime'] = endTime;
      }
    });
  }
  
  Future<TimeOfDay?> _selectTime(BuildContext context, TimeOfDay initialTime) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
            tooltip: 'Save Schedule',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _weekdays.length,
              itemBuilder: (context, index) {
                final day = _weekdays[index];
                final dayName = _displayWeekdays[index];
                
                final dayData = _schedule[day] ?? {
                  'isWorkingDay': false,
                  'startTime': '09:00',
                  'endTime': '17:00',
                };
                
                final isWorkingDay = dayData['isWorkingDay'] ?? false;
                final startTime = dayData['startTime'] ?? '09:00';
                final endTime = dayData['endTime'] ?? '17:00';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: isWorkingDay,
                              onChanged: (value) => _updateDayStatus(day, value),
                              activeColor: AppColors.primaryPurple,
                            ),
                          ],
                        ),
                        if (isWorkingDay) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Start Time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        final currentTime = _parseTimeString(startTime);
                                        final TimeOfDay? newTime = await _selectTime(
                                          context,
                                          currentTime,
                                        );
                                        
                                        if (newTime != null) {
                                          _updateDayTimes(
                                            day,
                                            _formatTimeOfDay(newTime),
                                            endTime,
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(startTime),
                                            const Icon(
                                              Icons.access_time,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'End Time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        final currentTime = _parseTimeString(endTime);
                                        final TimeOfDay? newTime = await _selectTime(
                                          context,
                                          currentTime,
                                        );
                                        
                                        if (newTime != null) {
                                          _updateDayTimes(
                                            day,
                                            startTime,
                                            _formatTimeOfDay(newTime),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(endTime),
                                            const Icon(
                                              Icons.access_time,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}