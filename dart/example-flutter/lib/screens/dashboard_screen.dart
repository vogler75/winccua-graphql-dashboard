import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:winccua_graphql_client/winccua_graphql_client.dart';
import '../providers/wincc_provider.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/chart_widget.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<String> _tagNames = [
    'HMI_Tag_1',
    'HMI_Tag_2',
    'Meter_Input_WattAct',
    'Meter_Output_WattAct',
    'PV_Power_WattAct',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToTags();
  }

  Future<void> _subscribeToTags() async {
    final provider = context.read<WinCCProvider>();
    await provider.subscribeToTags(_tagNames);
  }

  Future<void> _logout() async {
    final provider = context.read<WinCCProvider>();
    await provider.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WinCC Monitor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Consumer<WinCCProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _subscribeToTags,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection status
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.circle,
                        color: provider.isConnected ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        provider.isConnected ? 'Connected' : 'Disconnected',
                      ),
                      subtitle: Text(provider.serverUrl ?? 'No server'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Demo tag values
                  Text(
                    'Demo Tags',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTagCard(
                          'HMI_Tag_1',
                          provider.tagValues['HMI_Tag_1'],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTagCard(
                          'HMI_Tag_2',
                          provider.tagValues['HMI_Tag_2'],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Power gauges
                  Text(
                    'Power Meters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: GaugeWidget(
                            title: 'Input Power',
                            value: provider.getTagValue('Meter_Input_WattAct') ?? 0,
                            unit: 'W',
                            minValue: 0,
                            maxValue: 10000,
                          ),
                        ),
                        Expanded(
                          child: GaugeWidget(
                            title: 'Output Power',
                            value: provider.getTagValue('Meter_Output_WattAct') ?? 0,
                            unit: 'W',
                            minValue: 0,
                            maxValue: 10000,
                          ),
                        ),
                        Expanded(
                          child: GaugeWidget(
                            title: 'PV Power',
                            value: provider.getTagValue('PV_Power_WattAct') ?? 0,
                            unit: 'W',
                            minValue: 0,
                            maxValue: 10000,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Historical chart
                  Text(
                    'Power History (3 Hours)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 300,
                    child: ChartWidget(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagCard(String tagName, Value? value) {
    final displayValue = value?.value?.toString() ?? 'N/A';
    final quality = value?.quality?.quality ?? 'UNKNOWN';
    final timestamp = value?.timestamp != null
        ? DateTime.parse(value!.timestamp!).toLocal()
        : null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tagName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: quality == 'GOOD' || quality == 'GOOD_CASCADE'
                      ? Colors.green
                      : quality == 'UNCERTAIN'
                          ? Colors.orange
                          : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  quality.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                'Updated: ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}