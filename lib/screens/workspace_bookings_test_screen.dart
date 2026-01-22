import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkspaceBookingsTestScreen extends StatefulWidget {
  const WorkspaceBookingsTestScreen({super.key});

  @override
  State<WorkspaceBookingsTestScreen> createState() => _WorkspaceBookingsTestScreenState();
}

class _WorkspaceBookingsTestScreenState extends State<WorkspaceBookingsTestScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('workspace_bookings')
          .select('''
            *,
            users!inner(
              full_name,
              email
            )
          ''')
          .order('booking_date', ascending: true);

      setState(() {
        _bookings = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Bookings Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookings,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _bookings.isEmpty
          ? const Center(child: Text('No bookings found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          final user = booking['users'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getWorkspaceColor(booking['workspace_type']),
                child: Icon(
                  _getWorkspaceIcon(booking['workspace_type']),
                  color: Colors.white,
                ),
              ),
              title: Text(
                booking['workspace_type'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: ${user['full_name']} (${user['email']})'),
                  Text('Date: ${booking['booking_date']}'),
                  Text('Time: ${booking['start_time']} - ${booking['end_time']}'),
                  Text('Status: ${booking['status']}'),
                ],
              ),
              trailing: Text(
                '€${booking['total_price']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getWorkspaceColor(String? type) {
    switch (type) {
      case 'desk':
        return Colors.blue;
      case 'meeting_room':
        return Colors.orange;
      case 'private_office':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getWorkspaceIcon(String? type) {
    switch (type) {
      case 'desk':
        return Icons.desk;
      case 'meeting_room':
        return Icons.meeting_room;
      case 'private_office':
        return Icons.business;
      default:
        return Icons.workspace_premium;
    }
  }
}
