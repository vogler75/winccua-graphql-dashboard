import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wincc_provider.dart';

class ChartWidget extends StatefulWidget {
  const ChartWidget({super.key});

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  List<FlSpot> _inputPowerData = [];
  List<FlSpot> _outputPowerData = [];
  List<FlSpot> _pvPowerData = [];
  bool _isLoading = false;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<WinCCProvider>();
      _endTime = DateTime.now();
      _startTime = _endTime!.subtract(const Duration(hours: 3));

      final tagNames = [
        'Meter_Input_Value:LoggingTag_1',
        'Meter_Output_Value:LoggingTag_1',
        'PV_Power_WattAct:LoggingTag_1',
      ];

      final results = await provider.getHistoricalData(
        tagNames,
        _startTime!,
        _endTime!,
      );

      _inputPowerData = [];
      _outputPowerData = [];
      _pvPowerData = [];

      for (final result in results) {
        final spots = <FlSpot>[];
        
        if (result.values != null) {
          for (final loggedValue in result.values!) {
            if (loggedValue.value?.value is num && loggedValue.value?.timestamp != null) {
              final timestamp = DateTime.parse(loggedValue.value!.timestamp!);
              final x = timestamp.millisecondsSinceEpoch.toDouble();
              final y = (loggedValue.value!.value as num).toDouble();
              spots.add(FlSpot(x, y));
            }
          }
        }

        if (result.loggingTagName?.contains('Meter_Input') == true) {
          _inputPowerData = spots;
        } else if (result.loggingTagName?.contains('Meter_Output') == true) {
          _outputPowerData = spots;
        } else if (result.loggingTagName?.contains('PV_Power') == true) {
          _pvPowerData = spots;
        }
      }
    } catch (e) {
      print('Error loading historical data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inputPowerData.isEmpty && _outputPowerData.isEmpty && _pvPowerData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No historical data available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistoricalData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Input Power', Colors.blue),
                const SizedBox(width: 24),
                _buildLegendItem('Output Power', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('PV Power', Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1000,
                    verticalInterval: 3600000, // 1 hour in milliseconds
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 3600000, // 1 hour
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('HH:mm').format(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: 2000,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}W',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: _startTime?.millisecondsSinceEpoch.toDouble() ?? 0,
                  maxX: _endTime?.millisecondsSinceEpoch.toDouble() ?? 0,
                  minY: 0,
                  maxY: 10000,
                  lineBarsData: [
                    if (_inputPowerData.isNotEmpty)
                      LineChartBarData(
                        spots: _inputPowerData,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (_outputPowerData.isNotEmpty)
                      LineChartBarData(
                        spots: _outputPowerData,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (_pvPowerData.isNotEmpty)
                      LineChartBarData(
                        spots: _pvPowerData,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                          String label = '';
                          
                          if (spot.barIndex == 0) {
                            label = 'Input';
                          } else if (spot.barIndex == 1) {
                            label = 'Output';
                          } else if (spot.barIndex == 2) {
                            label = 'PV';
                          }
                          
                          return LineTooltipItem(
                            '$label: ${spot.y.toStringAsFixed(0)}W\n${DateFormat('HH:mm:ss').format(date)}',
                            TextStyle(color: spot.bar.color),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}