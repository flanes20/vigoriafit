import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/store.dart';

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        final p = s.profile;
        final start = s.startWeight ?? p.weightKg;
        final last = s.lastWeight ?? p.weightKg;
        final change = last - start;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Tu progreso',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),

                // Métricas
                Row(
                  children: [
                    _stat('Peso actual', '${last.round()} kg', AppColors.brand),
                    const SizedBox(width: 10),
                    _stat(
                      'Cambio',
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                      change == 0
                          ? AppColors.muted
                          : (change < 0 ? AppColors.success : AppColors.warn),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat('IMC', p.bmi.toStringAsFixed(1), AppColors.protein),
                    const SizedBox(width: 10),
                    _stat(
                      'Meta',
                      '${p.targetWeightKg.round()} kg',
                      AppColors.mint,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Gráfico de peso
                Text(
                  'Evolución del peso',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 20, 18, 10),
                    child: SizedBox(
                      height: 200,
                      child: s.weights.length < 2 ? _emptyChart() : _chart(s),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _logWeight(context, last),
                    icon: const Icon(Icons.monitor_weight_rounded),
                    label: const Text('Registrar peso de hoy'),
                  ),
                ),
                const SizedBox(height: 24),

                // Resumen semanal
                Text(
                  'Esta semana',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _weekStat('🔥', '${s.streak}', 'racha'),
                        _div(),
                        _weekStat('💪', '${s.workoutsThisWeek}', 'entrenos'),
                        _div(),
                        _weekStat('💧', '${s.waterToday}', 'agua hoy'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chart(AppStore s) {
    final weights = s.weights;
    final spots = <FlSpot>[];
    for (int i = 0; i < weights.length; i++) {
      spots.add(FlSpot(i.toDouble(), weights[i].kg));
    }
    final values = weights.map((e) => e.kg).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 2);
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 2);
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: ((maxY - minY) / 3).clamp(1, 100),
              getTitlesWidget: (v, _) => Text(
                '${v.round()}',
                style: TextStyle(fontSize: 10, color: AppColors.faint),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.brand,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.brand,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.show_chart_rounded, size: 40, color: AppColors.faint),
        const SizedBox(height: 8),
        Text(
          'Registra tu peso unos días\npara ver tu evolución',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _div() => Container(width: 1, height: 40, color: AppColors.line);

  Future<void> _logWeight(BuildContext context, double current) async {
    double val = current.clamp(35, 200);
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Peso de hoy (kg)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${val.round()}',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
                Slider(
                  value: val,
                  min: 35,
                  max: 200,
                  divisions: 165,
                  activeColor: AppColors.brand,
                  onChanged: (v) => setSheet(() => val = v),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      AppStore.instance.addWeight(val);
                      Navigator.pop(context);
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
