import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mokaf2/constants/app_colors.dart';
import 'package:mokaf2/screens/client/provider_detail_page.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.bookingId)
          .get();
          
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }
      
      final bookingData = bookingDoc.data()!;
      bookingData['id'] = bookingDoc.id;
      
      setState(() {
        _bookingData = bookingData;
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Booking not found',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    final status = _bookingData!['status'] as String;
    final startTime = (_bookingData!['startTime'] as Timestamp).toDate();
    final endTime = (_bookingData!['endTime'] as Timestamp?)?.toDate() ?? 
        startTime.add(const Duration(hours: 1));
        
    final statusColor = _getStatusColor(status);
    
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      status.substring(0, 1).toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Service',
                        _bookingData!['serviceName'] ?? 'Service',
                        isBold: true
                      ),
                      _buildInfoRow(
                        'Date',
                        DateFormat('EEEE, MMMM d, yyyy').format(startTime),
                      ),
                      _buildInfoRow(
                        'Time',
                        '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                      ),
                      _buildInfoRow(
                        'Provider',
                        _bookingData!['providerName'] ?? 'Service Provider',
                      ),
                      _buildInfoRow(
                        'Price',
                        '\$${(_bookingData!['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        valueColor: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Location Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bookingData!['location'] ?? 'No location specified',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Notes Card (if any)
          if (_bookingData!['notes'] != null && _bookingData!['notes'].toString().isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bookingData!['notes'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // View provider details button
          if (_bookingData!['providerId'] != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProviderDetailPage(
                      providerId: _bookingData!['providerId'],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.business),
              label: const Text('View Provider Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryPurple,
                elevation: 1,
                side: BorderSide(color: AppColors.primaryPurple),
              ),
            ),
          ],
          
          // Cancel button (if booking is pending or confirmed)
          if (status == 'pending' || status == 'confirmed') ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _confirmCancelBooking,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Booking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmCancelBooking() {
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
                _cancelBooking();
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _cancelBooking() async {
    setState(() => _isLoading = true);
    
    try {
      // Update the booking status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.bookingId)
          .update({
            'status': 'canceled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          
      // Create notification for provider
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'userId': _bookingData!['providerId'],
            'title': 'Booking Canceled',
            'message': 'A booking for ${_bookingData!['serviceName']} has been canceled by the client.',
            'type': 'booking_update',
            'relatedId': widget.bookingId,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking canceled successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadBookingDetails();
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