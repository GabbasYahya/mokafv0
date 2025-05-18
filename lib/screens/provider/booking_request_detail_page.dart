import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class BookingRequestDetailPage extends StatefulWidget {
  final String bookingId;
  
  const BookingRequestDetailPage({super.key, required this.bookingId});

  @override
  State<BookingRequestDetailPage> createState() => _BookingRequestDetailPageState();
}

class _BookingRequestDetailPageState extends State<BookingRequestDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _clientData;
  Map<String, dynamic>? _serviceData;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Get booking details
      final bookingDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.bookingId)
          .get();
          
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }
      
      final bookingData = bookingDoc.data()!;
      bookingData['id'] = bookingDoc.id;
      
      // Load client details
      Map<String, dynamic>? clientData;
      if (bookingData['clientId'] != null) {
        final clientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(bookingData['clientId'])
            .get();
            
        if (clientDoc.exists) {
          clientData = clientDoc.data();
          clientData!['id'] = clientDoc.id;
        }
      }
      
      // Load service details
      Map<String, dynamic>? serviceData;
      if (bookingData['serviceId'] != null) {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(bookingData['serviceId'])
            .get();
            
        if (serviceDoc.exists) {
          serviceData = serviceDoc.data();
          serviceData!['id'] = serviceDoc.id;
        }
      }
      
      setState(() {
        _bookingData = bookingData;
        _clientData = clientData;
        _serviceData = serviceData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking details: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateBookingStatus(String status) async {
    setState(() => _isLoading = true);
    
    try {
      // Update booking status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.bookingId)
          .update({
            'status': status,
            'respondedAt': FieldValue.serverTimestamp(),
          });
      
      // Create notification for client
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'userId': _bookingData!['clientId'],
            'title': _getNotificationTitle(status),
            'message': _getNotificationMessage(status),
            'type': 'booking_update',
            'relatedId': widget.bookingId,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking request ${status.toLowerCase()}'),
          backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
        ),
      );
      
      // Reload booking details
      _loadBookingDetails();
    } catch (e) {
      print('Error updating booking status: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _getNotificationTitle(String status) {
    switch (status) {
      case 'confirmed':
        return 'Booking Confirmed';
      case 'declined':
        return 'Booking Declined';
      case 'completed':
        return 'Service Completed';
      default:
        return 'Booking Status Updated';
    }
  }

  String _getNotificationMessage(String status) {
    final serviceName = _serviceData?['name'] ?? _bookingData!['serviceName'] ?? 'service';
    
    switch (status) {
      case 'confirmed':
        return 'Your booking for $serviceName has been confirmed.';
      case 'declined':
        return 'Your booking request for $serviceName has been declined.';
      case 'completed':
        return 'Your service for $serviceName has been marked as completed.';
      default:
        return 'Your booking status has been updated to $status.';
    }
  }

  Widget _getStatusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            _capitalizeFirstLetter(status),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    await launchUrl(launchUri);
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookingDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookingData == null
              ? const Center(child: Text('Booking not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              _getStatusBadge(_bookingData!['status']),
                            ],
                          ),
                        ),
                      ),
                      
                      // Client Card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Client Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_clientData != null && _clientData!['phone'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: Colors.green),
                                      onPressed: () => _makePhoneCall(_clientData!['phone']),
                                      tooltip: 'Call Client',
                                    ),
                                  if (_clientData != null && _clientData!['email'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.email, color: Colors.blue),
                                      onPressed: () => _sendEmail(_clientData!['email']),
                                      tooltip: 'Email Client',
                                    ),
                                ],
                              ),
                              const Divider(),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _clientData?['profileImage'] != null
                                      ? NetworkImage(_clientData!['profileImage'])
                                      : null,
                                  child: _clientData?['profileImage'] == null
                                      ? const Icon(Icons.person, color: Colors.grey)
                                      : null,
                                ),
                                title: Text(
                                  _bookingData!['clientName'] ?? 'Client',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_clientData != null && _clientData!['email'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(_clientData!['email']),
                                      ),
                                    if (_clientData != null && _clientData!['phone'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(_clientData!['phone']),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Service Details Card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Service Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const Divider(),
                              _buildInfoRow(
                                'Service:',
                                _bookingData!['serviceName'] ?? 'Service',
                              ),
                              if (_serviceData != null && _serviceData!['description'] != null)
                                _buildInfoRow(
                                  'Description:',
                                  _serviceData!['description'],
                                ),
                              _buildInfoRow(
                                'Price:',
                                '\$${(_bookingData!['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                AppColors.primaryPurple,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Date:',
                                (_bookingData!['startTime'] as Timestamp?)?.toDate() != null
                                  ? DateFormat('EEEE, MMMM d, yyyy').format((_bookingData!['startTime'] as Timestamp).toDate())
                                  : 'Not specified',
                              ),
                              _buildInfoRow(
                                'Time:',
                                (_bookingData!['startTime'] as Timestamp?)?.toDate() != null
                                  ? DateFormat('h:mm a').format((_bookingData!['startTime'] as Timestamp).toDate())
                                  : 'Not specified',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Location:',
                                _bookingData!['location'] ?? 'Not provided',
                              ),
                              if (_bookingData!['notes'] != null && _bookingData!['notes'].toString().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Additional Notes:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  width: double.infinity,
                                  child: Text(
                                    _bookingData!['notes'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Actions
                      if (_bookingData!['status'] == 'pending') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateBookingStatus('declined'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateBookingStatus('confirmed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Mark as completed button (for confirmed bookings)
                      if (_bookingData!['status'] == 'confirmed') ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _updateBookingStatus('completed'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}