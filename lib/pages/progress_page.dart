import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/logs.dart';
import '../services/progression_engine.dart';
import '../services/store.dart';
import '../services/unit_system.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  String? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        final p = s.profile;
        final imperial = s.units == UnitSystem.imperial;
        final weightUnit = imperial ? 'lb' : 'kg';
        final start = s.startWeight ?? p.weightKg;
        final last = s.lastWeight ?? p.weightKg;
        final change = last - start;
        final displayLast =
            imperial ? last * 2.20462 : last;
        final displayChange =
            imperial ? change * 2.20462 : change;
        final exerciseNames = _exerciseNames(s);

        if (_selectedExercise == null && exerciseNames.isNotEmpty) {
          _selectedExercise = exerciseNames.first;
        }

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
                    _stat(
                      'Peso actual',
                      '${displayLast.toStringAsFixed(1)} $weightUnit',
                      AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      'Cambio',
                      '${displayChange > 0 ? '+' : ''}${displayChange.toStringAsFixed(1)} $weightUnit',
                      displayChange == 0
                          ? AppColors.muted
                          : (displayChange < 0
                              ? AppColors.success
                              : AppColors.warn),
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
                      '${imperial ? (p.targetWeightKg * 2.20462).toStringAsFixed(1) : p.targetWeightKg.round()} $weightUnit',
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
                      child: s.weights.length < 2
                          ? _emptyChart()
                          : _weightChart(s, imperial),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _logWeightDialog(context, last, imperial, weightUnit),
                    icon: const Icon(Icons.monitor_weight_rounded),
                    label: const Text('Registrar peso de hoy'),
                  ),
                ),

                // Lista de mediciones con editar/eliminar
                if (s.weights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Historial de peso',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...s.weights.reversed.take(10).map(
                    (w) => _weightTile(context, w, s, imperial, weightUnit),
                  ),
                ],

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
                        _weekStat(
                          '💧',
                          '${s.waters.totalMlForDay(DateTime.now())} ml',
                          'agua hoy',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Evolución de cargas
                Text(
                  'Evolución de cargas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                if (exerciseNames.isEmpty)
                  _emptyLoadsCard()
                else ...[
                  _exerciseSelector(exerciseNames),
                  const SizedBox(height: 10),
                  if (_selectedExercise != null) ...[
                    _progressionCard(s, _selectedExercise!, imperial),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 20, 18, 10),
                        child: SizedBox(
                          height: 200,
                          child: _loadsChart(s, _selectedExercise!, imperial),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _exerciseNames(AppStore s) {
    final allNames = <String>[];
    for (final name in _knownExerciseNames(s)) {
      if (s.exerciseWeightHistory(name).isNotEmpty) allNames.add(name);
    }
    return allNames;
  }

  List<String> _knownExerciseNames(AppStore s) {
    final names = <String>{};
    for (final session in s.sessions.history) {
      for (final ex in session.exercises) {
        names.add(ex.exerciseName);
      }
    }
    return names.toList()..sort();
  }

  Widget _exerciseSelector(List<String> names) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: names
            .map(
              (n) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    n,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _selectedExercise == n,
                  onSelected: (v) {
                    if (v) setState(() => _selectedExercise = n);
                  },
                  selectedColor: AppColors.brandSoft,
                  labelStyle: TextStyle(
                    color: _selectedExercise == n
                        ? AppColors.brandDark
                        : AppColors.muted,
                    fontWeight: _selectedExercise == n
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _loadsChart(AppStore s, String exercise, bool imperial) {
    final history = s
        .exerciseWeightHistory(exercise)
        .reversed
        .where((e) => e.kg > 0)
        .toList();
    if (history.length < 2) return _emptyChart();
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final kg = imperial ? history[i].kg * 2.20462 : history[i].kg;
      spots.add(FlSpot(i.toDouble(), kg));
    }
    final values = spots.map((s) => s.y).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 2).clamp(0, 9999).toDouble();
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;
    final unit = imperial ? 'lb' : 'kg';
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: ((maxY - minY) / 3).clamp(1, 200),
              getTitlesWidget: (v, _) => Text(
                '${v.round()} $unit',
                style: TextStyle(fontSize: 9, color: AppColors.faint),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.protein,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.protein,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.protein.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressionCard(AppStore s, String exercise, bool imperial) {
    final history = s
        .exerciseWeightHistory(exercise)
        .reversed
        .where((e) => e.kg > 0)
        .toList();
    final suggestion = ProgressionEngine.suggest(
      history,
      units: imperial ? UnitSystem.imperial : UnitSystem.metric,
    );
    final unit = imperial ? 'lb' : 'kg';

    Color cardColor;
    IconData cardIcon;
    String headline;
    switch (suggestion.kind) {
      case ProgressionKind.increase:
        cardColor = AppColors.success;
        cardIcon = Icons.arrow_upward_rounded;
        final disp = imperial
            ? (suggestion.suggestedKg! * 2.20462).toStringAsFixed(1)
            : suggestion.suggestedKg!.toStringAsFixed(1);
        headline = '↑ Sube a $disp $unit';
      case ProgressionKind.maintain:
        cardColor = AppColors.brand;
        cardIcon = Icons.horizontal_rule_rounded;
        final disp = imperial
            ? (suggestion.suggestedKg! * 2.20462).toStringAsFixed(1)
            : suggestion.suggestedKg!.toStringAsFixed(1);
        headline = '→ Mantén $disp $unit';
      case ProgressionKind.decrease:
        cardColor = AppColors.warn;
        cardIcon = Icons.arrow_downward_rounded;
        headline = '↓ Carga menor registrada';
      case ProgressionKind.insufficient:
        cardColor = AppColors.muted;
        cardIcon = Icons.hourglass_empty_rounded;
        headline = 'Historial insuficiente';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cardIcon, color: cardColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cardColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Motivo: ${suggestion.reason}',
            style: TextStyle(fontSize: 12, color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Datos: ${suggestion.dataUsed}',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Sugerencia orientativa, no una prescripción clínica.',
            style: TextStyle(fontSize: 10.5, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _emptyLoadsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        'Registra entrenamientos con carga para ver tu evolución aquí.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }

  Widget _weightChart(AppStore s, bool imperial) {
    final weights = s.weights;
    final spots = <FlSpot>[];
    for (int i = 0; i < weights.length; i++) {
      final v = imperial ? weights[i].kg * 2.20462 : weights[i].kg;
      spots.add(FlSpot(i.toDouble(), v));
    }
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;
    final unit = imperial ? 'lb' : 'kg';
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: ((maxY - minY) / 3).clamp(1, 100),
              getTitlesWidget: (v, _) => Text(
                '${v.round()} $unit',
                style: TextStyle(fontSize: 9, color: AppColors.faint),
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
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
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

  Widget _weightTile(
    BuildContext context,
    WeightEntry w,
    AppStore s,
    bool imperial,
    String unit,
  ) {
    final dk = dayKey(w.date);
    final display = imperial
        ? '${(w.kg * 2.20462).toStringAsFixed(1)} $unit'
        : '${w.kg.toStringAsFixed(1)} $unit';
    final dateFmt = DateFormat('d MMM yyyy', 'es').format(w.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontSize: 15,
                  ),
                ),
                Text(
                  dateFmt,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: AppColors.brand,
            visualDensity: VisualDensity.compact,
            tooltip: 'Editar',
            onPressed: () =>
                _editWeightDialog(context, w, dk, s, imperial, unit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.danger,
            visualDensity: VisualDensity.compact,
            tooltip: 'Eliminar',
            onPressed: () => _deleteWeightDialog(context, w, dk, s, dateFmt),
          ),
        ],
      ),
    );
  }

  Future<void> _logWeightDialog(
    BuildContext context,
    double currentKg,
    bool imperial,
    String unit,
  ) async {
    final kg = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _LogWeightSheet(
        currentKg: currentKg,
        imperial: imperial,
        unit: unit,
      ),
    );
    if (kg != null) {
      try {
        await AppStore.instance.addWeight(kg);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar el peso.')),
          );
        }
      }
    }
  }

  Future<void> _editWeightDialog(
    BuildContext context,
    WeightEntry w,
    String dk,
    AppStore s,
    bool imperial,
    String unit,
  ) async {
    final updatedKg = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _EditWeightSheet(
        entry: w,
        imperial: imperial,
        unit: unit,
      ),
    );
    if (updatedKg != null) {
      try {
        await s.updateWeight(dk, updatedKg);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo editar el peso.')),
          );
        }
      }
    }
  }

  Future<void> _deleteWeightDialog(
    BuildContext context,
    WeightEntry w,
    String dk,
    AppStore s,
    String dateFmt,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar medición'),
        content: Text('¿Eliminar el peso del $dateFmt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) await s.deleteWeight(dk);
  }

  Widget _emptyChart() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: AppColors.faint),
            const SizedBox(height: 8),
            Text(
              'Registra datos unos días\npara ver tu evolución',
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
                fontSize: 18,
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _div() => Container(width: 1, height: 40, color: AppColors.line);
}

class _LogWeightSheet extends StatefulWidget {
  final double currentKg;
  final bool imperial;
  final String unit;

  const _LogWeightSheet({
    required this.currentKg,
    required this.imperial,
    required this.unit,
  });

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initVal = widget.imperial
        ? widget.currentKg * 2.20462
        : widget.currentKg;
    _ctrl = TextEditingController(
      text: initVal > 0 ? initVal.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null || v < 20 || v > 350) {
      setState(() => _error = 'Ingresa un peso válido');
      return;
    }
    final kg = widget.imperial ? v / 2.20462 : v;
    Navigator.of(context).pop(kg);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text(
              'Registrar peso de hoy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa tu peso actual en ${widget.unit}:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                suffixText: widget.unit,
                errorText: _error,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.brand, width: 1.8),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EditWeightSheet extends StatefulWidget {
  final WeightEntry entry;
  final bool imperial;
  final String unit;

  const _EditWeightSheet({
    required this.entry,
    required this.imperial,
    required this.unit,
  });

  @override
  State<_EditWeightSheet> createState() => _EditWeightSheetState();
}

class _EditWeightSheetState extends State<_EditWeightSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initVal = widget.imperial
        ? widget.entry.kg * 2.20462
        : widget.entry.kg;
    _ctrl = TextEditingController(text: initVal.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null || v < 20 || v > 350) {
      setState(() => _error = 'Ingresa un peso válido');
      return;
    }
    final kg = widget.imperial ? v / 2.20462 : v;
    Navigator.of(context).pop(kg);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text(
              'Editar peso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fecha: ${DateFormat('d MMM yyyy', 'es').format(widget.entry.date)}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                suffixText: widget.unit,
                errorText: _error,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.brand, width: 1.8),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

