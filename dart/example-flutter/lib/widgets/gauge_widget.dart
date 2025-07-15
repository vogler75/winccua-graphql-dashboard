import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class GaugeWidget extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final double minValue;
  final double maxValue;

  const GaugeWidget({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.minValue = 0,
    this.maxValue = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: minValue,
                    maximum: maxValue,
                    ranges: <GaugeRange>[
                      GaugeRange(
                        startValue: minValue,
                        endValue: maxValue * 0.3,
                        color: Colors.green,
                        startWidth: 10,
                        endWidth: 10,
                      ),
                      GaugeRange(
                        startValue: maxValue * 0.3,
                        endValue: maxValue * 0.7,
                        color: Colors.orange,
                        startWidth: 10,
                        endWidth: 10,
                      ),
                      GaugeRange(
                        startValue: maxValue * 0.7,
                        endValue: maxValue,
                        color: Colors.red,
                        startWidth: 10,
                        endWidth: 10,
                      ),
                    ],
                    pointers: <GaugePointer>[
                      NeedlePointer(
                        value: value,
                        needleLength: 0.8,
                        needleColor: Theme.of(context).primaryColor,
                        knobStyle: KnobStyle(
                          color: Theme.of(context).primaryColor,
                          borderColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderWidth: 0.1,
                        ),
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        widget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              unit,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        angle: 90,
                        positionFactor: 0.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}