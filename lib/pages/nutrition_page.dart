import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/theme.dart';
import '../data/food_catalog.dart';
import '../data/nutrition.dart';
import '../data/supplements.dart';
import '../models/food_record.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../models/water_record.dart';
import '../services/places.dart';
import '../services/store.dart';
import 'food_scanner_page.dart';
import 'places_page.dart';

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  int _tab = 0; // 0=comidas, 1=agua, 2=suplementos
  int _menuSeed = 0;
  List<NearbyPlace>? _nearbyStores;
  DateTime _selectedDate = DateTime.now();
  bool _showRemainingKcal = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyStores();
  }

  Future<void> _loadNearbyStores() async {
    final pos = await Places.currentPosition();
    if (pos == null || !mounted) return;
    final places = await Places.search(
      lat: pos.latitude, lon: pos.longitude,
      kind: PlaceKind.supplementStore, radiusKm: 5,
    );
    if (mounted) setState(() => _nearbyStores = places);
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _CalendarPickerSheet(initialDate: _selectedDate),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showEditGoalsSheet(Profile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _EditGoalsSheet(
        profile: profile,
        showRemaining: _showRemainingKcal,
        onToggleRemaining: (val) {
          setState(() => _showRemainingKcal = val);
        },
      ),
    );
  }

  void _showMacroHistorySheet(MacroKind kind, Profile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _MacroHistorySheet(
        kind: kind,
        profile: profile,
        selectedDate: _selectedDate,
      ),
    );
  }

  Future<void> _confirmDeleteDayFoods() async {
    final s = AppStore.instance;
    final records = s.foods.forDay(_selectedDate);
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay alimentos registrados en esta fecha.')),
      );
      return;
    }

    // Doble confirmación: Primera confirmación
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar registro del día'),
        content: Text(
          '¿Deseas eliminar las ${records.length} comidas registradas para este día?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warn),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    // Segunda confirmación (doble confirmación estricta)
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmación final'),
        content: const Text(
          'Esta acción es definitiva y eliminará permanentemente todas las comidas registradas para esta fecha. ¿Seguro que deseas eliminarlas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sí, borrar todo'),
          ),
        ],
      ),
    );

    if (second != true || !mounted) return;

    for (final r in records) {
      await s.foods.delete(r.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se eliminaron los registros de comida del día.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppStore.instance,
        AppStore.instance.foods,
        AppStore.instance.waters,
      ]),
      builder: (context, _) {
        final p = AppStore.instance.profile;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _weekSelector(),
                if (AppStore.instance.foods.syncError != null ||
                    AppStore.instance.waters.syncError != null) ...[
                  const SizedBox(height: 12),
                  _syncErrorBanner(),
                ],
                const SizedBox(height: 16),
                _scannerCard(context),
                const SizedBox(height: 14),
                _segmented(),
                const SizedBox(height: 16),
                if (_tab == 0) ..._foodTab(p)
                else if (_tab == 1) ..._waterTab()
                else ..._supplements(p.goal),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _syncErrorBanner() {
    final msg = AppStore.instance.foods.syncError ??
        AppStore.instance.waters.syncError ??
        'Error al sincronizar con la nube.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Guardado localmente. $msg',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              AppStore.instance.foods.retrySync();
              AppStore.instance.waters.retrySync();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ── Selector de días de la semana ──────────────────────────────────────────

  Widget _weekSelector() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final dayName = isToday
        ? 'Hoy'
        : DateFormat('EEEE d', 'es').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final d = days[i];
            final selected = d.year == _selectedDate.year &&
                d.month == _selectedDate.month &&
                d.day == _selectedDate.day;
            final isCurrent = d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = d),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? (AppColors.dark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? (AppColors.dark ? Colors.black : Colors.white)
                              : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.brand
                            : (isCurrent ? AppColors.brand.withValues(alpha: 0.5) : Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Pestañas ─────────────────────────────────────────────────────────────

  List<Widget> _foodTab(Profile p) {
    final s = AppStore.instance;
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final records = s.foods.forDay(_selectedDate);
    final kcal    = s.foods.kcalForDay(_selectedDate);
    final prot    = s.foods.proteinForDay(_selectedDate);
    final carbs   = s.foods.carbsForDay(_selectedDate);
    final fat     = s.foods.fatForDay(_selectedDate);

    return [
      if (!isToday) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Visualizando día histórico (${DateFormat('d MMM yyyy', 'es').format(_selectedDate)}). No se pueden registrar ni modificar comidas fuera del día de hoy.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // Resumen del día con tarjeta y barras de progreso
      _dailySummaryCard(
        kcal: kcal,
        prot: prot,
        carbs: carbs,
        fat: fat,
        profile: p,
        isEditable: isToday,
        onAddFood: isToday ? () => _openFoodSheet(context) : null,
      ),
      const SizedBox(height: 14),

      // Barras de kcal por horario (Desayuno, Almuerzo, Cena, Snack)
      _mealDistributionCard(records, p, isToday),
      const SizedBox(height: 16),

      // Lista de registros divididos por horario
      if (records.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              'Aún no registraste nada para este día.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        )
      else ...[
        Row(
          children: [
            Text(
              'Registros por horario (${records.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const Spacer(),
            if (isToday)
              TextButton.icon(
                onPressed: () => _openFoodSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.brand,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final meal in [MealType.desayuno, MealType.almuerzo, MealType.cena, MealType.snack])
          if (records.any((r) => r.mealType == meal)) ...[
            Builder(
              builder: (context) {
                final mealRecs = records.where((r) => r.mealType == meal).toList();
                final mealKcal = mealRecs.fold<double>(0.0, (acc, r) => acc + r.kcal);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              '${meal.emoji} ${meal.label}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${mealKcal.toStringAsFixed(0)} kcal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...mealRecs.map((r) => _foodRecordTile(r, isEditable: isToday)),
                    ],
                  ),
                );
              },
            ),
          ],
      ],
      const SizedBox(height: 24),

      // Menú sugerido
      Row(children: [
        Text('Menú sugerido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _menuSeed++),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Cambiar'),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
        ),
      ]),
      const SizedBox(height: 6),
      ..._meals(p.goal),
    ];
  }

  List<Widget> _waterTab() {
    final s     = AppStore.instance;
    final today = DateTime.now();
    final totalMl = s.waters.totalMlForDay(today);
    final goalMl  = s.waterGoalMl;
    final records = s.waters.forDay(today);

    return [
      _waterSummaryCard(totalMl: totalMl, goalMl: goalMl),
      const SizedBox(height: 12),

      // Botones rápidos con padding compacto y FittedBox para no desbordar ni separar texto
      Row(children: [
        for (final ml in [200, 250, 500]) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _addWater(ml),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
                side: const BorderSide(color: AppColors.water),
                foregroundColor: AppColors.water,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('+$ml ml',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: () => _customWaterDialog(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
              backgroundColor: AppColors.water,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Otro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Spacer(),
        TextButton.icon(
          onPressed: () => _adjustGoalDialog(context, goalMl),
          icon: const Icon(Icons.tune_rounded, size: 15),
          label: const Text('Ajustar meta'),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
        ),
      ]),
      const SizedBox(height: 8),

      if (records.isEmpty)
        Text('No hay registros de agua hoy.',
            style: TextStyle(fontSize: 13, color: AppColors.muted))
      else ...[
        Text('Registros de hoy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        ...records.map((r) => _waterRecordTile(r)),
      ],
    ];
  }

  // ── Widgets de resumen ────────────────────────────────────────────────────

  Widget _dailySummaryCard({
    required double kcal,
    required double prot,
    required double carbs,
    required double fat,
    required Profile profile,
    required bool isEditable,
    VoidCallback? onAddFood,
  }) {
    final goalKcal = profile.dailyKcal;
    final goalProt = profile.proteinGrams;
    final goalCarbs = profile.carbsGrams;
    final goalFat = profile.fatGrams;

    final kcalPct = (kcal / (goalKcal > 0 ? goalKcal : 2000)).clamp(0.0, 1.0);
    final protPct = (prot / (goalProt > 0 ? goalProt : 100)).clamp(0.0, 1.0);
    final carbsPct = (carbs / (goalCarbs > 0 ? goalCarbs : 200)).clamp(0.0, 1.0);
    final fatPct = (fat / (goalFat > 0 ? goalFat : 60)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.dark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: kcal > con icono editar y opciones
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: AppColors.muted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Ajustar metas de nutrición',
                onPressed: () => _showEditGoalsSheet(profile),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showMacroHistorySheet(MacroKind.kcal, profile),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'delete_day') {
                    _confirmDeleteDayFoods();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'delete_day',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Text('Borrar registro del día', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Calorías: número grande (consumidas o restantes)
          Center(
            child: InkWell(
              onTap: () => _showMacroHistorySheet(MacroKind.kcal, profile),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  children: [
                    if (_showRemainingKcal) ...[
                      if (kcal > goalKcal)
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(
                                text: '+${(kcal - goalKcal).toStringAsFixed(0)}',
                                style: const TextStyle(color: AppColors.danger),
                              ),
                              TextSpan(
                                text: ' kcal de exceso',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(
                                text: (goalKcal - kcal).clamp(0, 99999).toStringAsFixed(0),
                                style: const TextStyle(color: AppColors.brand),
                              ),
                              TextSpan(
                                text: ' restantes',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: kcal > goalKcal ? AppColors.danger : AppColors.ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(text: kcal.toStringAsFixed(0)),
                            TextSpan(
                              text: ' / $goalKcal',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Barra de progreso de calorías (con zona visual de sobreconsumo si excede la meta)
          LayoutBuilder(
            builder: (context, constraints) {
              final safeGoal = goalKcal > 0 ? goalKcal : 2000;
              final isOver = kcal > safeGoal;
              final excessKcal = isOver ? (kcal - safeGoal) : 0.0;

              if (isOver) {
                final maxScale = kcal > safeGoal * 1.25 ? kcal : safeGoal * 1.25;
                final goalRatio = (safeGoal / maxScale).clamp(0.0, 1.0);
                final totalRatio = (kcal / maxScale).clamp(0.0, 1.0);
                final w = constraints.maxWidth;
                final goalX = w <= 16.0 ? w / 2 : (w * goalRatio).clamp(8.0, w - 8.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 14,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.line,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          // Barra total incluyendo zona de sobreconsumo
                          Container(
                            width: w * totalRatio,
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), AppColors.danger],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.danger.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          // Tramo hasta la meta diaria
                          Container(
                            width: goalX,
                            height: 10,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEAB308), AppColors.brand],
                              ),
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(5),
                              ),
                            ),
                          ),
                          // Marcador vertical de meta alcanzada
                          Positioned(
                            left: goalX - 1.5,
                            child: Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: AppColors.ink.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        Text(
                          '+${excessKcal.toStringAsFixed(0)} kcal extra (${(kcal / safeGoal * 100).toInt()}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                        Text(
                          '$goalKcal meta',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                );
              }

              final remKcal = (safeGoal - kcal).clamp(0.0, 99999.0);
              final remKcalPct = (remKcal / safeGoal).clamp(0.0, 1.0);
              final barFactor = _showRemainingKcal ? remKcalPct : kcalPct;
              final pctText = _showRemainingKcal
                  ? '${(remKcalPct * 100).toInt()}% restante'
                  : '${(kcalPct * 100).toInt()}%';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barFactor,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAB308), AppColors.brand],
                            ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      Text(
                        pctText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      Text(
                        '$goalKcal',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3 Columnas de macronutrientes: Proteínas, Carbs, Grasas
          Row(
            children: [
              // Proteínas
              Expanded(
                child: _macroColumn(
                  title: 'Proteínas',
                  current: prot,
                  goal: goalProt.toDouble(),
                  pct: protPct,
                  color: const Color(0xFF10B981), // Verde
                  showRemaining: _showRemainingKcal,
                  onTap: () => _showMacroHistorySheet(MacroKind.protein, profile),
                ),
              ),
              const SizedBox(width: 14),
              // Carbs
              Expanded(
                child: _macroColumn(
                  title: 'Carbs',
                  current: carbs,
                  goal: goalCarbs.toDouble(),
                  pct: carbsPct,
                  color: const Color(0xFFF59E0B), // Amarillo / ámbar
                  showRemaining: _showRemainingKcal,
                  onTap: () => _showMacroHistorySheet(MacroKind.carbs, profile),
                ),
              ),
              const SizedBox(width: 14),
              // Grasas
              Expanded(
                child: _macroColumn(
                  title: 'Grasas',
                  current: fat,
                  goal: goalFat.toDouble(),
                  pct: fatPct,
                  color: const Color(0xFF14B8A6), // Menta / teal
                  showRemaining: _showRemainingKcal,
                  onTap: () => _showMacroHistorySheet(MacroKind.fat, profile),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón inferior: Registrar comida estilo píldora
          ElevatedButton(
            onPressed: isEditable ? onAddFood : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEditable ? AppColors.surfaceAlt : AppColors.line.withValues(alpha: 0.5),
              foregroundColor: isEditable ? AppColors.ink : AppColors.muted,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.line),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isEditable ? Icons.add_circle_outline_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: isEditable ? AppColors.brand : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditable ? 'Registrar comida' : 'Solo lectura (día histórico)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isEditable ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroColumn({
    required String title,
    required double current,
    required double goal,
    required double pct,
    required Color color,
    required bool showRemaining,
    required VoidCallback onTap,
  }) {
    final safeGoal = goal > 0 ? goal : 1.0;
    final isOver = current > safeGoal;
    final excess = isOver ? (current - safeGoal) : 0.0;
    final rem = (safeGoal - current).clamp(0.0, 999999.0);
    final remPct = (rem / safeGoal).clamp(0.0, 1.0);
    final barVal = showRemaining ? remPct : pct;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
                Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: showRemaining
                  ? (isOver
                      ? RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(
                                text: '+${excess.toStringAsFixed(0)}',
                                style: const TextStyle(color: AppColors.danger),
                              ),
                              TextSpan(
                                text: ' g exc.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(text: rem.toStringAsFixed(0)),
                              TextSpan(
                                text: ' g rest.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ))
                  : RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isOver ? AppColors.danger : AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(text: current.toStringAsFixed(0)),
                          TextSpan(
                            text: ' / ${goal.toStringAsFixed(0)} g',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (isOver)
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxScale = current > safeGoal * 1.25 ? current : safeGoal * 1.25;
                  final goalRatio = (safeGoal / maxScale).clamp(0.0, 1.0);
                  final totalRatio = (current / maxScale).clamp(0.0, 1.0);
                  final w = constraints.maxWidth;
                  final goalX = w <= 10.0 ? w / 2 : (w * goalRatio).clamp(4.0, w - 4.0);

                  return SizedBox(
                    height: 9,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: w * totalRatio,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: goalX,
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          left: goalX - 1,
                          child: Container(
                            width: 2,
                            height: 9,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(1),
                              border: Border.all(
                                color: AppColors.ink.withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: barVal,
                  minHeight: 5,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mealDistributionCard(
    List<FoodRecord> records,
    Profile profile,
    bool isEditable,
  ) {
    final s = AppStore.instance;
    const meals = [
      MealType.desayuno,
      MealType.almuerzo,
      MealType.cena,
      MealType.snack,
    ];
    const mealColors = {
      MealType.desayuno: Color(0xFFF59E0B),
      MealType.almuerzo: AppColors.brand,
      MealType.cena: Color(0xFF6366F1),
      MealType.snack: Color(0xFF10B981),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Calorías por horario',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (isEditable)
                TextButton.icon(
                  onPressed: () => _openFoodSheet(context, initialSlide: 1),
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text('Dividir kcal'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < meals.length; i++) ...[
            Builder(
              builder: (context) {
                final meal = meals[i];
                final mealKcal = records
                    .where((r) => r.mealType == meal)
                    .fold<double>(0.0, (acc, r) => acc + r.kcal);
                final goal = s.mealKcalGoal(meal);
                final safeGoal = goal > 0 ? goal : 1;
                final isOver = mealKcal > safeGoal;
                final color = mealColors[meal] ?? AppColors.brand;
                final rem = (safeGoal - mealKcal).clamp(0.0, 999999.0);
                final excess = isOver ? (mealKcal - safeGoal) : 0.0;

                return Padding(
                  padding: EdgeInsets.only(bottom: i == meals.length - 1 ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${meal.emoji} ${meal.label}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          if (_showRemainingKcal)
                            Text(
                              isOver
                                  ? '+${excess.toStringAsFixed(0)} kcal exc.'
                                  : '${rem.toStringAsFixed(0)} / $goal kcal rest.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isOver ? AppColors.danger : AppColors.muted,
                              ),
                            )
                          else
                            Text(
                              '${mealKcal.toStringAsFixed(0)} / $goal kcal',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isOver ? AppColors.danger : AppColors.muted,
                              ),
                            ),
                          if (isEditable) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _openFoodSheet(context, initialMealType: meal),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.add_rounded, size: 14, color: color),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (isOver)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final maxScale = mealKcal > safeGoal * 1.25
                                ? mealKcal
                                : safeGoal * 1.25;
                            final goalRatio = (safeGoal / maxScale).clamp(0.0, 1.0);
                            final totalRatio = (mealKcal / maxScale).clamp(0.0, 1.0);
                            final w = constraints.maxWidth;
                            final goalX = w <= 10.0
                                ? w / 2
                                : (w * goalRatio).clamp(4.0, w - 4.0);

                            return SizedBox(
                              height: 10,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.line,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Container(
                                    width: w * totalRatio,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Container(
                                    width: goalX,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: goalX - 1,
                                    child: Container(
                                      width: 2,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(1),
                                        border: Border.all(
                                          color: AppColors.ink.withValues(alpha: 0.45),
                                          width: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _showRemainingKcal
                                ? (rem / safeGoal).clamp(0.0, 1.0)
                                : (mealKcal / safeGoal).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.line,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _waterSummaryCard({required int totalMl, required int goalMl}) {
    final pct = (totalMl / goalMl).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.water_drop_rounded, color: AppColors.water),
          const SizedBox(width: 10),
          Expanded(child: Text('$totalMl ml de $goalMl ml',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink))),
          if (totalMl >= goalMl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('¡Meta alcanzada!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 9,
            backgroundColor: AppColors.line,
            color: AppColors.water,
          ),
        ),
      ]),
    );
  }

  // ── Tiles de registros ────────────────────────────────────────────────────

  Widget _foodRecordTile(FoodRecord r, {bool isEditable = true}) {
    return Dismissible(
      key: Key(r.id),
      direction: isEditable ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (!isEditable) return false;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar registro'),
            content: Text('¿Eliminar "${r.foodName}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => AppStore.instance.foods.delete(r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(r.mealType.emoji,
                style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.foodName,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
            Text('${r.quantity.toStringAsFixed(0)} ${r.unit} · '
                '${r.kcal.toStringAsFixed(0)} kcal · '
                'P ${r.proteinG.toStringAsFixed(1)} g',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ])),
          if (isEditable) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 16),
              color: AppColors.muted,
              visualDensity: VisualDensity.compact,
              tooltip: 'Editar',
              onPressed: () => _openFoodSheet(context, editing: r),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              color: AppColors.danger,
              visualDensity: VisualDensity.compact,
              tooltip: 'Eliminar',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar alimento'),
                    content: Text('¿Deseas eliminar "${r.foodName}"?'),
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
                if (ok == true) {
                  await AppStore.instance.foods.delete(r.id);
                }
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _waterRecordTile(WaterRecord r) {
    final fmt = DateFormat('HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        const Icon(Icons.water_drop_rounded, size: 16, color: AppColors.water),
        const SizedBox(width: 8),
        Expanded(child: Text('${r.amountMl} ml · ${fmt.format(r.recordedAt)}',
            style: TextStyle(fontSize: 13, color: AppColors.ink))),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 16),
          color: AppColors.muted,
          visualDensity: VisualDensity.compact,
          onPressed: () => _editWaterDialog(context, r),
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded, size: 16),
          color: AppColors.danger,
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Eliminar'),
                content: Text('¿Eliminar el registro de ${r.amountMl} ml?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (ok == true) AppStore.instance.waters.delete(r.id);
          },
        ),
      ]),
    );
  }

  // ── Acciones de agua ──────────────────────────────────────────────────────

  Future<void> _addWater(int ml) async {
    try {
      await AppStore.instance.waters.add(ml);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _customWaterDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cantidad personalizada'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mililitros', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true) return;
    final ml = int.tryParse(ctrl.text.trim());
    if (ml == null || ml <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa una cantidad válida en ml.')));
      }
      return;
    }
    await _addWater(ml);
  }

  Future<void> _editWaterDialog(BuildContext context, WaterRecord r) async {
    final ctrl = TextEditingController(text: '${r.amountMl}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar registro de agua'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mililitros', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final ml = int.tryParse(ctrl.text.trim());
    if (ml == null || ml <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa una cantidad válida en ml.')));
      }
      return;
    }
    try {
      await AppStore.instance.waters.update(r.id, amountMl: ml);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _adjustGoalDialog(BuildContext context, int currentGoal) async {
    final ctrl = TextEditingController(text: '$currentGoal');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meta diaria de agua'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mililitros', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final ml = int.tryParse(ctrl.text.trim());
    if (ml == null || ml <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa una cantidad válida.')));
      }
      return;
    }
    try {
      await AppStore.instance.setWaterGoalMl(ml);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── Sheet de registro de comida ───────────────────────────────────────────

  Future<void> _openFoodSheet(
    BuildContext context, {
    FoodRecord? editing,
    MealType? initialMealType,
    int initialSlide = 0,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _FoodLogSheet(
        editing: editing,
        initialMealType: initialMealType,
        initialSlide: initialSlide,
      ),
    );
  }

  // ── Scanner card ──────────────────────────────────────────────────────────

  Widget _scannerCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FoodScannerPage())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brand, AppColors.brandDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Escanear comida',
                  style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('IA',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('Foto a tu plato → calorías al instante',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }

  // ── Segmented ─────────────────────────────────────────────────────────────

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _segBtn('🍽️ Comidas', 0),
        _segBtn('💧 Agua', 1),
        _segBtn('💊 Suplementos', 2),
      ]),
    );
  }

  Widget _segBtn(String label, int i) {
    final active = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: active ? Border.all(color: AppColors.line) : null,
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: active ? AppColors.ink : AppColors.muted,
              )),
        ),
      ),
    );
  }

  // ── Menús sugeridos ───────────────────────────────────────────────────────

  List<Widget> _meals(Goal goal) {
    final menu = Nutrition.dayMenu(goal, seed: _menuSeed, profile: AppStore.instance.profile);
    final types = MealType.values.where((t) => menu.containsKey(t)).toList();
    if (types.isEmpty) return [_emptyFilterResult()];
    return [
      ...types.map((t) => _mealCard(t, menu[t]!)),
      if (types.length < MealType.values.length)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            'Algunas comidas no tienen alternativas con tus restricciones actuales.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
    ];
  }

  Widget _emptyFilterResult() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: [
        const Text('🚫', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Sin alternativas disponibles',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        Text('Ninguna comida del catálogo es compatible con tus restricciones actuales. '
            'Revisa tus alergias y condiciones en Ajustes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ]),
    );
  }

  Widget _mealCard(MealType t, MealIdea m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset('assets/food/${m.image}.jpg',
                width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t.emoji} ${t.label}',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(m.name,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 6),
            Row(children: [
              _tag('${m.kcal} kcal', AppColors.brand),
              const SizedBox(width: 6),
              _tag('${m.protein} g prot', AppColors.protein),
            ]),
          ])),
        ]),
      ),
    );
  }

  // ── Suplementos ───────────────────────────────────────────────────────────

  List<Widget> _supplements(Goal goal) {
    final list = Supplements.forGoal(goal);
    return [
      Row(children: [
        Expanded(child: Text('Suplementos para tu objetivo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink))),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PlacesPage(initialKind: PlaceKind.supplementStore))),
          icon: const Icon(Icons.storefront_rounded, size: 16),
          label: const Text('Dónde comprar'),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Primero la comida real; los suplementos solo complementan.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
      const SizedBox(height: 14),
      _nearbyStoresCard(),
      const SizedBox(height: 14),
      ...list.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Image.asset('assets/supplements/${s.image}.jpg',
                height: 130, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink))),
                ]),
                const SizedBox(height: 10),
                Text(s.benefit,
                    style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.35)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 14, color: AppColors.mint),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.timing,
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500))),
                ]),
                if (s.cautionNote != null &&
                    s.cautionFor.any(AppStore.instance.profile.conditions.contains)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warn.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warn),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.cautionNote!,
                          style: TextStyle(fontSize: 11.5, color: AppColors.ink, height: 1.3))),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      )),
    ];
  }

  Widget _nearbyStoresCard() {
    if (_nearbyStores == null) return const SizedBox.shrink();
    final nearest = _nearbyStores!.take(3).toList();
    if (nearest.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.storefront_rounded, size: 16, color: AppColors.mint),
          const SizedBox(width: 6),
          Text('Cerca de ti ahora',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ]),
        const SizedBox(height: 8),
        ...nearest.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lon}'),
              mode: LaunchMode.externalApplication,
            ),
            child: Row(children: [
              Expanded(child: Text(p.name, style: TextStyle(fontSize: 12.5, color: AppColors.ink))),
              Text('${p.distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
              Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.faint),
            ]),
          ),
        )),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Sheet para registrar o editar una comida
// ════════════════════════════════════════════════════════════════════════════

class _FoodLogSheet extends StatefulWidget {
  const _FoodLogSheet({
    this.editing,
    this.initialMealType,
    this.initialSlide = 0,
  });
  final FoodRecord? editing;
  final MealType? initialMealType;
  final int initialSlide;

  @override
  State<_FoodLogSheet> createState() => _FoodLogSheetState();
}

class _FoodLogSheetState extends State<_FoodLogSheet> {
  static const _uuid = Uuid();

  final _searchCtrl = TextEditingController();
  final _qtyCtrl    = TextEditingController();

  FoodCatalogItem? _selected;
  MealType _mealType = MealType.almuerzo;
  bool _saving = false;
  String? _error;

  late int _slide;
  late Map<MealType, double> _mealBudgets;
  bool _savingBudgets = false;

  @override
  void initState() {
    super.initState();
    _slide = widget.editing != null ? 0 : widget.initialSlide.clamp(0, 1);
    final e = widget.editing;
    if (e != null) {
      _selected = FoodCatalog.byId(e.foodId);
      _qtyCtrl.text = e.quantity.toStringAsFixed(
          e.quantity == e.quantity.roundToDouble() ? 0 : 1);
      _mealType = e.mealType;
    } else if (widget.initialMealType != null) {
      _mealType = widget.initialMealType!;
    }
    final store = AppStore.instance;
    _mealBudgets = {
      for (final m in MealType.values) m: store.mealKcalGoal(m).toDouble(),
    };
    _searchCtrl.addListener(() => setState(() {}));
    _qtyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  double? get _qty {
    final v = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || !v.isFinite) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppStore.instance.profile;
    final results = _selected == null
        ? FoodCatalog.search(_searchCtrl.text, profile: profile)
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  widget.editing != null
                      ? 'Editar registro'
                      : (_slide == 0 ? 'Registrar comida' : 'Dividir calorías del día'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 12),

                if (widget.editing == null) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _slide = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _slide == 0 ? AppColors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                border: _slide == 0 ? Border.all(color: AppColors.line) : null,
                              ),
                              child: Text(
                                '🍽️ Registrar alimento',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _slide == 0 ? AppColors.ink : AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _slide = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _slide == 1 ? AppColors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                border: _slide == 1 ? Border.all(color: AppColors.line) : null,
                              ),
                              child: Text(
                                '⚖️ Dividir calorías',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _slide == 1 ? AppColors.ink : AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_slide == 1 && widget.editing == null)
                  _buildMealDivisionSlide(profile)
                else ...[
                  // Búsqueda o alimento seleccionado
                  if (_selected == null) ...[
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar alimento...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            })
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (results != null && results.isEmpty)
                    Text('Sin resultados para "${_searchCtrl.text}".',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  if (results != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final item = results[i];
                          return ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text('${item.preparation} · ${item.refQty.toStringAsFixed(0)} ${item.refUnit} → ${item.kcal.toStringAsFixed(0)} kcal'),
                            onTap: () {
                              setState(() => _selected = item);
                              _searchCtrl.clear();
                            },
                          );
                        },
                      ),
                    ),
                ] else ...[
                  _selectedCard(_selected!),
                  const SizedBox(height: 12),

                  // Cantidad
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Cantidad',
                          suffixText: _selected!.refUnit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<MealType>(
                        initialValue: _mealType,
                        decoration: const InputDecoration(labelText: 'Momento'),
                        items: MealType.values.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text('${t.emoji} ${t.label}'),
                        )).toList(),
                        onChanged: (v) { if (v != null) setState(() => _mealType = v); },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Preview de nutrientes
                  if (_qty != null) _nutrientPreview(_selected!, _qty!),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _selected = null),
                    child: const Text('Cambiar alimento'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Guardar'),
                    ),
                  ),
                ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealDivisionSlide(Profile profile) {
    final dailyKcal = profile.dailyKcal > 0 ? profile.dailyKcal : 2000;
    const meals = [
      MealType.desayuno,
      MealType.almuerzo,
      MealType.cena,
      MealType.snack,
    ];
    const mealColors = {
      MealType.desayuno: Color(0xFFF59E0B),
      MealType.almuerzo: AppColors.brand,
      MealType.cena: Color(0xFF6366F1),
      MealType.snack: Color(0xFF10B981),
    };

    final assignedSum = meals.fold<int>(
      0,
      (acc, m) => acc + (_mealBudgets[m]?.round() ?? 0),
    );
    final diff = dailyKcal - assignedSum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta diaria: $dailyKcal kcal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      diff == 0
                          ? 'Distribución exacta (100%)'
                          : (diff > 0
                              ? 'Faltan $diff kcal por asignar'
                              : 'Excedido por ${-diff} kcal'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: diff == 0
                            ? const Color(0xFF10B981)
                            : (diff > 0 ? AppColors.warn : AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  final b = (dailyKcal * 0.25).round().toDouble();
                  final l = (dailyKcal * 0.35).round().toDouble();
                  final d = (dailyKcal * 0.30).round().toDouble();
                  final s = (dailyKcal - b - l - d).clamp(0, dailyKcal).toDouble();
                  setState(() {
                    _mealBudgets[MealType.desayuno] = b;
                    _mealBudgets[MealType.almuerzo] = l;
                    _mealBudgets[MealType.cena] = d;
                    _mealBudgets[MealType.snack] = s;
                  });
                },
                child: const Text('Automático', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final meal in meals) ...[
          Builder(
            builder: (context) {
              final val = (_mealBudgets[meal] ?? 0).clamp(0.0, dailyKcal.toDouble());
              final pct = dailyKcal > 0 ? ((val / dailyKcal) * 100).round() : 0;
              final color = mealColors[meal] ?? AppColors.brand;
              final stepDivs = (dailyKcal / 25).round().clamp(1, 200);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${meal.emoji} ${meal.label}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${val.round()} kcal ($pct%)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: val,
                        min: 0,
                        max: dailyKcal.toDouble(),
                        divisions: stepDivs,
                        activeColor: color,
                        inactiveColor: AppColors.line,
                        onChanged: (v) {
                          setState(() => _mealBudgets[meal] = (v / 25).round() * 25.0);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _savingBudgets
                ? null
                : () async {
                    setState(() => _savingBudgets = true);
                    try {
                      await AppStore.instance.saveMealKcalBudgets({
                        for (final e in _mealBudgets.entries) e.key: e.value.round(),
                      });
                      if (!context.mounted) return;
                      if (widget.initialSlide == 1) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _slide = 0);
                      }
                    } finally {
                      if (mounted) setState(() => _savingBudgets = false);
                    }
                  },
            child: _savingBudgets
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Guardar distribución'),
          ),
        ),
      ],
    );
  }

  Widget _selectedCard(FoodCatalogItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandDark)),
        Text('${item.preparation} · ref: ${item.refQty.toStringAsFixed(0)} ${item.refUnit}',
            style: TextStyle(fontSize: 12, color: AppColors.brandDark)),
        const SizedBox(height: 4),
        Text('${item.kcal.toStringAsFixed(0)} kcal · '
            'P ${item.proteinG.toStringAsFixed(1)} g · '
            'C ${item.carbsG.toStringAsFixed(1)} g · '
            'G ${item.fatG.toStringAsFixed(1)} g',
            style: TextStyle(fontSize: 11.5, color: AppColors.brandDark)),
        Text('Fuente: ${item.source}',
            style: TextStyle(fontSize: 10.5, color: AppColors.brandDark.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _nutrientPreview(FoodCatalogItem item, double qty) {
    final foodKcal  = item.kcal    * qty / item.refQty;
    final foodProt  = item.proteinG * qty / item.refQty;
    final foodCarbs = item.carbsG  * qty / item.refQty;
    final foodFat   = item.fatG    * qty / item.refQty;

    final profile = AppStore.instance.profile;
    final today = DateTime.now();
    final currentKcal  = AppStore.instance.foods.kcalForDay(today);
    final currentProt  = AppStore.instance.foods.proteinForDay(today);
    final currentCarbs = AppStore.instance.foods.carbsForDay(today);
    final currentFat   = AppStore.instance.foods.fatForDay(today);

    final edit = widget.editing;
    final baseKcal  = (edit != null ? currentKcal - edit.kcal : currentKcal).clamp(0.0, 99999.0);
    final baseProt  = (edit != null ? currentProt - edit.proteinG : currentProt).clamp(0.0, 9999.0);
    final baseCarbs = (edit != null ? currentCarbs - edit.carbsG : currentCarbs).clamp(0.0, 9999.0);
    final baseFat   = (edit != null ? currentFat - edit.fatG : currentFat).clamp(0.0, 9999.0);

    final goalKcal  = profile.dailyKcal > 0 ? profile.dailyKcal : 2000;
    final goalProt  = profile.proteinGrams > 0 ? profile.proteinGrams : 120;
    final goalCarbs = profile.carbsGrams > 0 ? profile.carbsGrams : 200;
    final goalFat   = profile.fatGrams > 0 ? profile.fatGrams : 60;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'Progreso diario proyectado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${foodKcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra Calorías
          _sheetMacroBar(
            label: 'Calorías',
            current: baseKcal,
            added: foodKcal,
            goal: goalKcal.toDouble(),
            unit: 'kcal',
            color: AppColors.brand,
          ),
          const SizedBox(height: 10),

          // Barra Proteínas
          _sheetMacroBar(
            label: 'Proteínas',
            current: baseProt,
            added: foodProt,
            goal: goalProt.toDouble(),
            unit: 'g',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),

          // Barra Carbohidratos
          _sheetMacroBar(
            label: 'Carbohidratos',
            current: baseCarbs,
            added: foodCarbs,
            goal: goalCarbs.toDouble(),
            unit: 'g',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),

          // Barra Grasas
          _sheetMacroBar(
            label: 'Grasas',
            current: baseFat,
            added: foodFat,
            goal: goalFat.toDouble(),
            unit: 'g',
            color: const Color(0xFF14B8A6),
          ),
          const SizedBox(height: 10),

          // Barra del horario seleccionado
          Builder(
            builder: (context) {
              final mealRecords = AppStore.instance.foods
                  .forDay(today)
                  .where((r) => r.mealType == _mealType);
              final currentMealKcal = mealRecords.fold<double>(0.0, (acc, r) => acc + r.kcal);
              final baseMealKcal = (edit != null && edit.mealType == _mealType
                      ? currentMealKcal - edit.kcal
                      : currentMealKcal)
                  .clamp(0.0, 99999.0);
              final mealGoal = AppStore.instance.mealKcalGoal(_mealType).toDouble();

              return _sheetMacroBar(
                label: '${_mealType.emoji} ${_mealType.label}',
                current: baseMealKcal,
                added: foodKcal,
                goal: mealGoal,
                unit: 'kcal',
                color: const Color(0xFF6366F1),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sheetMacroBar({
    required String label,
    required double current,
    required double added,
    required double goal,
    required String unit,
    required Color color,
  }) {
    final safeGoal = goal > 0 ? goal : 1.0;
    final total = current + added;
    final currentRatio = (current / safeGoal).clamp(0.0, 1.0);
    final maxAdded = (1.0 - currentRatio).clamp(0.0, 1.0);
    final addedRatio   = (added / safeGoal).clamp(0.0, maxAdded);
    final remainRatio  = (1.0 - (currentRatio + addedRatio)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontFamily: 'Inter'),
                children: [
                  TextSpan(
                    text: total.toStringAsFixed(unit == 'kcal' ? 0 : 1),
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                  TextSpan(text: ' / ${goal.toStringAsFixed(0)} $unit '),
                  TextSpan(
                    text: '(+${added.toStringAsFixed(unit == 'kcal' ? 0 : 1)})',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 7,
            color: AppColors.line,
            child: Row(
              children: [
                if (currentRatio > 0)
                  Expanded(
                    flex: (currentRatio * 1000).toInt(),
                    child: Container(color: color.withValues(alpha: 0.35)),
                  ),
                if (addedRatio > 0)
                  Expanded(
                    flex: (addedRatio * 1000).toInt(),
                    child: Container(color: color),
                  ),
                if (remainRatio > 0)
                  Expanded(
                    flex: (remainRatio * 1000).toInt(),
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final item = _selected;
    if (item == null) return;
    final qty = _qty;
    if (qty == null) {
      setState(() => _error = 'Ingresa una cantidad válida mayor que 0.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final now  = DateTime.now();
      final currentUid = AppStore.instance.currentUid;
      final uid  = (currentUid != null && currentUid.isNotEmpty) ? currentUid : 'local_user';
      final s    = AppStore.instance.foods;
      final edit = widget.editing;
      if (edit != null) {
        final updated = edit.copyWith(
          quantity:   qty,
          mealType:   _mealType,
          updatedAt:  now,
        );
        await s.update(updated);
      } else {
        final record = FoodRecord(
          id:         _uuid.v4(),
          uid:        uid,
          foodId:     item.id,
          foodName:   item.name,
          refQty:     item.refQty,
          refUnit:    item.refUnit,
          kcalRef:    item.kcal,
          proteinRef: item.proteinG,
          carbsRef:   item.carbsG,
          fatRef:     item.fatG,
          quantity:   qty,
          unit:       item.refUnit,
          mealType:   _mealType,
          consumedAt: now,
          createdAt:  now,
          updatedAt:  now,
        );
        await s.add(record);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MacroKind, _EditGoalsSheet y _MacroHistorySheet
// ════════════════════════════════════════════════════════════════════════════

enum MacroKind {
  kcal(title: 'Calorías', unit: 'kcal', color: AppColors.brand),
  protein(title: 'Proteínas', unit: 'g', color: Color(0xFF10B981)),
  carbs(title: 'Carbohidratos', unit: 'g', color: Color(0xFFF59E0B)),
  fat(title: 'Grasas', unit: 'g', color: Color(0xFF14B8A6));

  const MacroKind({required this.title, required this.unit, required this.color});
  final String title;
  final String unit;
  final Color color;
}

class _EditGoalsSheet extends StatefulWidget {
  const _EditGoalsSheet({
    required this.profile,
    required this.showRemaining,
    required this.onToggleRemaining,
  });

  final Profile profile;
  final bool showRemaining;
  final ValueChanged<bool> onToggleRemaining;

  @override
  State<_EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<_EditGoalsSheet> {
  late bool _remaining;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _protCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.showRemaining;
    final p = widget.profile;
    _kcalCtrl  = TextEditingController(text: '${p.dailyKcal}');
    _protCtrl  = TextEditingController(text: '${p.proteinGrams}');
    _carbsCtrl = TextEditingController(text: '${p.carbsGrams}');
    _fatCtrl   = TextEditingController(text: '${p.fatGrams}');
  }

  @override
  void dispose() {
    _kcalCtrl.dispose();
    _protCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kcal  = int.tryParse(_kcalCtrl.text.trim());
    final prot  = int.tryParse(_protCtrl.text.trim());
    final carbs = int.tryParse(_carbsCtrl.text.trim());
    final fat   = int.tryParse(_fatCtrl.text.trim());

    if (kcal == null || kcal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una meta calórica válida')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AppStore.instance.saveCustomNutritionGoals(
        kcal: kcal,
        protein: prot,
        carbs: carbs,
        fat: fat,
      );
      widget.onToggleRemaining(_remaining);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar metas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetAuto() async {
    setState(() => _saving = true);
    try {
      await AppStore.instance.saveCustomNutritionGoals(
        kcal: null,
        protein: null,
        carbs: null,
        fat: null,
      );
      widget.onToggleRemaining(_remaining);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restablecer metas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ajustar metas de nutrición',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),

            // Toggle consumidas vs restantes
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _remaining = false);
                        widget.onToggleRemaining(false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_remaining ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: !_remaining ? Border.all(color: AppColors.line) : null,
                        ),
                        child: Text(
                          'Calorías consumidas',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: !_remaining ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _remaining = true);
                        widget.onToggleRemaining(true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _remaining ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _remaining ? Border.all(color: AppColors.line) : null,
                        ),
                        child: Text(
                          'Calorías restantes',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _remaining ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Metas diarias personalizadas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),

            _inputField(controller: _kcalCtrl, label: 'Calorías objetivo', unit: 'kcal'),
            const SizedBox(height: 10),
            _inputField(controller: _protCtrl, label: 'Proteínas objetivo', unit: 'g'),
            const SizedBox(height: 10),
            _inputField(controller: _carbsCtrl, label: 'Carbohidratos objetivo', unit: 'g'),
            const SizedBox(height: 10),
            _inputField(controller: _fatCtrl, label: 'Grasas objetivo', unit: 'g'),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar metas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed: _saving ? null : _resetAuto,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Restablecer a cálculo automático'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String unit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.brand)),
      ),
    );
  }
}

class _MacroHistorySheet extends StatelessWidget {
  const _MacroHistorySheet({
    required this.kind,
    required this.profile,
    required this.selectedDate,
  });

  final MacroKind kind;
  final Profile profile;
  final DateTime selectedDate;

  double _valueOf(FoodRecord r) {
    switch (kind) {
      case MacroKind.kcal: return r.kcal;
      case MacroKind.protein: return r.proteinG;
      case MacroKind.carbs: return r.carbsG;
      case MacroKind.fat: return r.fatG;
    }
  }

  double _goalOf(Profile p) {
    switch (kind) {
      case MacroKind.kcal: return p.dailyKcal.toDouble();
      case MacroKind.protein: return p.proteinGrams.toDouble();
      case MacroKind.carbs: return p.carbsGrams.toDouble();
      case MacroKind.fat: return p.fatGrams.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goalOf(profile);
    final allFoods = AppStore.instance.foods.records;

    return DefaultTabController(
      length: 4,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: kind.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Historial de ${kind.title}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kind.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Meta: ${goal.toStringAsFixed(0)} ${kind.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kind.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TabBar(
              indicatorColor: kind.color,
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Hoy'),
                Tab(text: 'Semanal'),
                Tab(text: 'Mensual'),
                Tab(text: 'Anual'),
              ],
            ),
            Divider(height: 1, color: AppColors.line),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDayTab(allFoods, goal),
                  _buildWeekTab(allFoods, goal),
                  _buildMonthTab(allFoods, goal),
                  _buildYearTab(allFoods, goal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pestaña Hoy
  Widget _buildDayTab(List<FoodRecord> allFoods, double goal) {
    final dayRecords = allFoods.where((r) =>
      r.consumedAt.year == selectedDate.year &&
      r.consumedAt.month == selectedDate.month &&
      r.consumedAt.day == selectedDate.day
    ).toList();

    final dayTotal = dayRecords.fold<double>(0.0, (acc, r) => acc + _valueOf(r));
    final pct = (dayTotal / (goal > 0 ? goal : 1)).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _summaryHeader(
          title: DateFormat('EEEE d MMMM', 'es').format(selectedDate),
          total: dayTotal,
          goal: goal,
          pct: pct,
        ),
        const SizedBox(height: 16),
        Text(
          'Desglose por alimento (${dayRecords.length})',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        if (dayRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No hay alimentos registrados en esta fecha.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          )
        else
          ...dayRecords.map((r) {
            final val = _valueOf(r);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Text(r.mealType.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.foodName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                        ),
                        Text(
                          '${r.quantity.toStringAsFixed(0)} ${r.unit}',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${val.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} ${kind.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kind.color,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // Pestaña Semanal
  Widget _buildWeekTab(List<FoodRecord> allFoods, double goal) {
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final days = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

    final dayTotals = days.map((d) {
      final records = allFoods.where((r) =>
        r.consumedAt.year == d.year &&
        r.consumedAt.month == d.month &&
        r.consumedAt.day == d.day
      );
      return records.fold<double>(0.0, (acc, r) => acc + _valueOf(r));
    }).toList();

    final weekTotal = dayTotals.fold<double>(0.0, (acc, v) => acc + v);
    final daysWithData = dayTotals.where((v) => v > 0).length;
    final weekAvg = daysWithData > 0 ? weekTotal / daysWithData : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _averageCard(
          title: 'Promedio diario semanal',
          avgValue: weekAvg,
          totalValue: weekTotal,
          goal: goal,
        ),
        const SizedBox(height: 16),
        Text('Días de la semana', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        ...List.generate(7, (i) {
          final d = days[i];
          final val = dayTotals[i];
          final p = (val / (goal > 0 ? goal : 1)).clamp(0.0, 1.0);
          final isSelected = d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? kind.color.withValues(alpha: 0.08) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? kind.color : AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${dayNames[i]} ${d.day}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? kind.color : AppColors.ink,
                      ),
                    ),
                    Text(
                      '${val.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} / ${goal.toStringAsFixed(0)} ${kind.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: val > 0 ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 5,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation<Color>(kind.color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Pestaña Mensual
  Widget _buildMonthTab(List<FoodRecord> allFoods, double goal) {
    final year = selectedDate.year;
    final month = selectedDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final monthRecords = allFoods.where((r) =>
      r.consumedAt.year == year && r.consumedAt.month == month
    ).toList();

    final monthTotal = monthRecords.fold<double>(0.0, (acc, r) => acc + _valueOf(r));
    final activeDays = <int>{for (final r in monthRecords) r.consumedAt.day}.length;
    final dailyAvg = activeDays > 0 ? monthTotal / activeDays : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _averageCard(
          title: 'Promedio diario en ${DateFormat('MMMM yyyy', 'es').format(selectedDate)}',
          avgValue: dailyAvg,
          totalValue: monthTotal,
          goal: goal,
        ),
        const SizedBox(height: 16),
        Text('Resumen mensual', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              _metricRow('Días con registro', '$activeDays de $daysInMonth días'),
              const Divider(height: 18),
              _metricRow('Consumo total del mes', '${monthTotal.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} ${kind.unit}'),
              const Divider(height: 18),
              _metricRow('Meta mensual estimada', '${(goal * daysInMonth).toStringAsFixed(0)} ${kind.unit}'),
            ],
          ),
        ),
      ],
    );
  }

  // Pestaña Anual
  Widget _buildYearTab(List<FoodRecord> allFoods, double goal) {
    final year = selectedDate.year;
    final yearRecords = allFoods.where((r) => r.consumedAt.year == year).toList();
    final yearTotal = yearRecords.fold<double>(0.0, (acc, r) => acc + _valueOf(r));
    final activeDays = <String>{for (final r in yearRecords) '${r.consumedAt.month}-${r.consumedAt.day}'}.length;
    final dailyAvg = activeDays > 0 ? yearTotal / activeDays : 0.0;

    final monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _averageCard(
          title: 'Promedio diario en $year',
          avgValue: dailyAvg,
          totalValue: yearTotal,
          goal: goal,
        ),
        const SizedBox(height: 16),
        Text('Meses de $year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
          ),
          itemCount: 12,
          itemBuilder: (ctx, i) {
            final m = i + 1;
            final mRecs = yearRecords.where((r) => r.consumedAt.month == m);
            final mTotal = mRecs.fold<double>(0.0, (acc, r) => acc + _valueOf(r));
            final isCurrent = m == selectedDate.month;

            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent ? kind.color.withValues(alpha: 0.1) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isCurrent ? kind.color : AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthNames[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: isCurrent ? kind.color : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mTotal > 0
                        ? '${mTotal.toStringAsFixed(kind == MacroKind.kcal ? 0 : 0)} ${kind.unit}'
                        : '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: mTotal > 0 ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _summaryHeader({
    required String title,
    required double total,
    required double goal,
    required double pct,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${total.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} ${kind.unit}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kind.color,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}% de la meta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(kind.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _averageCard({
    required String title,
    required double avgValue,
    required double totalValue,
    required double goal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${avgValue.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} ${kind.unit}/día',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kind.color,
                ),
              ),
              Text(
                'Total: ${totalValue.toStringAsFixed(kind == MacroKind.kcal ? 0 : 1)} ${kind.unit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Calendario mensual con días registrados resaltados (meses pasados y futuros)
// ════════════════════════════════════════════════════════════════════════════

class _CalendarPickerSheet extends StatefulWidget {
  const _CalendarPickerSheet({required this.initialDate});
  final DateTime initialDate;

  @override
  State<_CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<_CalendarPickerSheet> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );

    final daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    // weekday: 1=Lunes .. 7=Domingo
    final leadingBlanks = _displayMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final foods = AppStore.instance.foods;
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(_displayMonth);
    final formattedMonth = monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: Icon(Icons.chevron_left_rounded, color: AppColors.ink),
                tooltip: 'Mes anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    formattedMonth,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: Icon(Icons.chevron_right_rounded, color: AppColors.ink),
                tooltip: 'Mes siguiente',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (c) {
                  final cellIndex = r * 7 + c;
                  final dayNum = cellIndex - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 42));
                  }
                  final cellDate = DateTime(_displayMonth.year, _displayMonth.month, dayNum);
                  final isToday = cellDate == today;
                  final isSelected = cellDate == selected;
                  final hasRecords = foods.forDay(cellDate).isNotEmpty;

                  return Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, cellDate),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 44,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brand
                                    : (isToday
                                        ? AppColors.brand.withValues(alpha: 0.14)
                                        : Colors.transparent),
                                shape: BoxShape.circle,
                                border: isToday && !isSelected
                                    ? Border.all(color: AppColors.brand, width: 1.5)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: (isSelected || isToday)
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasRecords
                                    ? (isSelected ? AppColors.brand : const Color(0xFF10B981))
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Día con alimentos registrados',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context, today),
                child: const Text(
                  'Ir a Hoy',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
