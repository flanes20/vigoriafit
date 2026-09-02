import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/store.dart';
import 'coach_page.dart';
import 'nutrition_page.dart';
import 'progress_page.dart';
import 'today_page.dart';
import 'workout_page.dart';

/// Shell principal con navegación inferior: Hoy · Entreno · Nutrición · Coach ·
/// Progreso.
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  static const _tabs = [
    TodayTab(),
    WorkoutTab(),
    NutritionTab(),
    CoachTab(),
    ProgressTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Escucha AppStore para refrescar el color de la barra inferior si el
    // tema cambia en Ajustes y se vuelve a esta pantalla.
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) => _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandSoft,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded, color: AppColors.brand),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon:
                Icon(Icons.fitness_center_rounded, color: AppColors.brand),
            label: 'Entreno',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded, color: AppColors.brand),
            label: 'Nutrición',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon:
                Icon(Icons.auto_awesome_rounded, color: AppColors.brand),
            label: 'Coach',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded, color: AppColors.brand),
            label: 'Progreso',
          ),
        ],
      ),
    );
  }
}
