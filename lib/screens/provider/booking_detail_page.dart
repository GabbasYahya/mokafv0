import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  
  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
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
      // Get booking request details
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookingRequests')
          .doc(widget.bookingId)
          .get();
          
      if (!bookingDoc.exists) {
        throw 'Booking request not found';
      }
      
      final bookingData = bookingDoc.data()!;
      bookingData['id'] = bookingDoc.id;
      
      // Get client details
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
      
      // Get service details
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String status, [String? message, double? newPrice]) async {
    setState(() => _isLoading = true);
    
    try {
      final updates = <String, dynamic>{
        'status': status,
        'respondedAt': FieldValue.serverTimestamp(),
      };
      
      if (message != null) {
        updates['responseMessage'] = message;
      }
      
      if (newPrice != null) {
        updates['counterOfferPrice'] = newPrice;
      }
      
      await FirebaseFirestore.instance
          .collection('bookingRequests')
          .doc(widget.bookingId)
          .update(updates);
          
      // Add notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _bookingData!['clientId'],
        'title': _getNotificationTitle(status),
        'message': message ?? _getDefaultMessage(status),
        'type': 'booking',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': widget.bookingId,
      });
      
      // If accepted, add to schedule
      if (status == 'accepted') {
        await FirebaseFirestore.instance.collection('appointments').add({
          'providerId': _bookingData!['providerId'],
          'clientId': _bookingData!['clientId'],
          'serviceId': _bookingData!['serviceId'],
          'serviceName': _serviceData?['name'] ?? 'Service',
          'date': _bookingData!['requestedDate'],
          'startTime': _bookingData!['requestedTime'],
          'duration': _bookingData!['duration'] ?? 60,
          'status': 'confirmed',
          'price': newPrice ?? _bookingData!['offerPrice'] ?? _serviceData?['price'] ?? 0,
          'location': _bookingData!['location'],
          'notes': _bookingData!['notes'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${_getResponseMessage(status)}')),
      );
      
      _loadBookingDetails();
    } catch (e) {
      print('Error updating request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  String _getNotificationTitle(String status) {
    switch (status) {
      case 'accepted':
        return 'Booking Accepted!';
      case 'declined':
        return 'Booking Request Declined';
      case 'counterOffer':
        return 'Counter Offer Received';
      default:
        return 'Booking Update';
    }
  }

  String _getDefaultMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'Your booking request has been accepted.';
      case 'declined':
        return 'Your booking request was declined by the provider.';
      case 'counterOffer':
        return 'The provider has sent you a counter offer.';
      default:
        return 'Your booking request status has been updated.';
    }
  }

  String _getResponseMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'accepted';
      case 'declined':
        return 'declined';
      case 'counterOffer':
        return 'counter offer sent';
      default:
        return 'updated';
    }
  }

  void _showActionDialog(String action) {
    final messageController = TextEditingController();
    final priceController = TextEditingController();
    
    if (action == 'counter') {
      priceController.text = (_bookingData!['offerPrice'] ?? _serviceData?['price'] ?? 0).toString();
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'counter' ? 'Send Counter Offer' : 'Decline Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (action == 'counter') ...[
              const Text(
                'New Price:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (\$)',
                  hintText: 'Enter your counter offer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Message to Client',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: action == 'counter' ? 'Explain Your Offer' : 'Reason for Declining',
                hintText: action == 'counter' 
                    ? 'Let the client know why you\'re suggesting this price'
                    : 'Let the client know why you\'re declining',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (action == 'counter' && priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a price')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              if (action == 'counter') {
                final newPrice = double.tryParse(priceController.text);
                if (newPrice != null) {
                  _updateStatus('counterOffer', messageController.text, newPrice);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid price')),
                  );
                }
              } else {
                _updateStatus('declined', messageController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'counter' ? Colors.blue : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'counter' ? 'Send Offer' : 'Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Request Details'),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              _getStatusIcon(_bookingData!['status']),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getStatusText(_bookingData!['status']),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_bookingData!['respondedAt'] != null)
                                      Text(
                                        'Responded ${DateFormat('MMM d, yyyy • h:mm a').format((_bookingData!['respondedAt'] as Timestamp).toDate())}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_bookingData!['status'] == 'pending')
                                OutlinedButton(
                                  onPressed: () => _updateStatus('accepted'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green,
                                  ),
                                  child: const Text('Accept'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Client Card
                      if (_clientData != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Client Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundImage: _clientData!['profileImage'] != null
                                        ? NetworkImage(_clientData!['profileImage'])
                                        : null,
                                    child: _clientData!['profileImage'] == null
                                        ? Icon(Icons.person, color: Theme.of(context).primaryColor)
                                        : null,
                                  ),
                                  title: Text(
                                    _clientData!['name'] ?? 'Client',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: _clientData!['email'] != null
                                      ? Text(_clientData!['email'])
                                      : null,
                                  trailing: _clientData!['phone'] != null
                                      ? IconButton(
                                          icon: const Icon(Icons.phone),
                                          color: Colors.green,
                                          onPressed: () async {
                                            final url = 'tel:${_clientData!['phone']}';
                                            if (await canLaunch(url)) {
                                              await launch(url);
                                            }
                                          },
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Service details
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Service Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Service',
                                _serviceData?['name'] ?? _bookingData!['serviceName'] ?? 'Service',
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                'Date',
                                _bookingData!['requestedDate'] != null
                                    ? DateFormat('EEEE, MMMM d, yyyy').format(
                                        (_bookingData!['requestedDate'] as Timestamp).toDate(),
                                      )
                                    : 'Not specified',
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                'Time',
                                _bookingData!['requestedTime'] ?? 'Not specified',
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                'Duration',
                                '${_bookingData!['duration'] ?? _serviceData?['duration'] ?? 60} minutes',
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                'Location',
                                _bookingData!['location'] ?? 'Not specified',
                              ),
                              if (_bookingData!['notes'] != null && _bookingData!['notes'].toString().isNotEmpty) ...[
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Notes',
                                  _bookingData!['notes'],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Payment details
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pricing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Service Price',
                                '\$${(_serviceData?['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                Colors.green[700],
                              ),
                              if (_bookingData!['counterOfferPrice'] != null) ...[
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Your Counter Offer',
                                  '\$${(_bookingData!['counterOfferPrice'] as num).toStringAsFixed(2)}',
                                  Colors.blue[700],
                                ),
                              ],
                              if (_bookingData!['status'] == 'counterOffer' && _bookingData!['responseMessage'] != null) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Your Response:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_bookingData!['responseMessage']),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Actions
                      if (_bookingData!['status'] == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateStatus('accepted'),
                                icon: const Icon(Icons.check),
                                label: const Text('Accept Request'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                      if (_bookingData!['status'] == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showActionDialog('counter'),
                                icon: const Icon(Icons.currency_exchange),
                                label: const Text('Send Counter Offer'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showActionDialog('decline'),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _getStatusIcon(String? status) {
    late IconData icon;
    late Color color;
    
    switch (status?.toLowerCase()) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case 'accepted':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'declined':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'counteroffer':
        icon = Icons.currency_exchange;
        color = Colors.blue;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      radius: 24,
      child: Icon(icon, color: color, size: 28),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'counteroffer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pending Response';
      case 'accepted':
        return 'Booking Accepted';
      case 'declined':
        return 'Booking Declined';
      case 'counteroffer':
        return 'Counter Offer Sent';
      default:
        return 'Unknown Status';
    }
  }
}
