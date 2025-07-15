import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wincc_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshAlerts();
  }

  Future<void> _refreshAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<WinCCProvider>();
      await provider.fetchActiveAlarms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alerts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getPriorityColor(int? priority) {
    if (priority == null) return Colors.grey;
    if (priority >= 0 && priority <= 4) return Colors.blue;
    if (priority >= 5 && priority <= 7) return Colors.orange;
    return Colors.red;
  }

  String _getStateText(dynamic state) {
    final stateString = state.toString();
    switch (stateString) {
      case 'ALARM_STATE_ACTIVE':
        return 'Active';
      case 'ALARM_STATE_INACTIVE':
        return 'Inactive';
      case 'ALARM_STATE_ACKNOWLEDGED':
        return 'Acknowledged';
      default:
        return stateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAlerts,
          ),
        ],
      ),
      body: Consumer<WinCCProvider>(
        builder: (context, provider, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final alarms = provider.activeAlarms;

          if (alarms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active alerts',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshAlerts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshAlerts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                final alarm = alarms[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPriorityColor(alarm.priority),
                      child: Text(
                        alarm.priority?.toString() ?? '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      alarm.eventText?.isNotEmpty == true 
                          ? alarm.eventText!.first 
                          : 'No description',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'State: ${_getStateText(alarm.state)}',
                          style: TextStyle(
                            color: _getStateText(alarm.state) == 'Acknowledged'
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                        if (alarm.raiseTime != null)
                          Text(
                            'Raised: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(alarm.raiseTime!).toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (alarm.infoText != null && alarm.infoText!.isNotEmpty) ...[
                              Text(
                                'Info:',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(alarm.infoText!.first),
                              const SizedBox(height: 12),
                            ],
                            if (alarm.stateText != null && alarm.stateText!.isNotEmpty) ...[
                              Text(
                                'State Text:',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(alarm.stateText!.first),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Icon(
                                  Icons.label,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Name: ${alarm.name ?? 'Unknown'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'ID: ${alarm.instanceID ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (alarm.acknowledgmentTime != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Acknowledged: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(alarm.acknowledgmentTime!).toLocal())}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}