import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/place.dart';
import '../services/places.dart';

/// Encuentra gimnasios y tiendas de suplementos cerca del usuario, usando
/// datos abiertos de OpenStreetMap. Ninguna otra app de fitness integra esto
/// junto con rutinas, nutrición y coach IA en un solo lugar.
class PlacesPage extends StatefulWidget {
  final PlaceKind initialKind;
  const PlacesPage({super.key, this.initialKind = PlaceKind.gym});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

enum _Status { idle, locating, loading, noPermission, error, ok }

class _PlacesPageState extends State<PlacesPage> {
  late PlaceKind _kind = widget.initialKind;
  _Status _status = _Status.idle;
  List<NearbyPlace> _places = [];
  Position? _pos;
  double _radius = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.locating);
    final pos = await Places.currentPosition();
    if (pos == null) {
      setState(() => _status = _Status.noPermission);
      return;
    }
    _pos = pos;
    await _search();
  }

  Future<void> _search() async {
    if (_pos == null) return;
    setState(() => _status = _Status.loading);
    try {
      final places = await Places.search(
        lat: _pos!.latitude,
        lon: _pos!.longitude,
        kind: _kind,
        radiusKm: _radius,
      );
      if (!mounted) return;
      setState(() {
        _places = places;
        _status = _Status.ok;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  Future<void> _openDirections(NearbyPlace p) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lon}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca de ti',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: _segmented(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _radiusSelector(),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segBtn('🏋️ Gimnasios', PlaceKind.gym),
          _segBtn('💊 Suplementos', PlaceKind.supplementStore),
        ],
      ),
    );
  }

  Widget _segBtn(String label, PlaceKind kind) {
    final active = _kind == kind;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_kind == kind) return;
          setState(() => _kind = kind);
          _search();
        },
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
                  fontSize: 13,
                  color: active ? AppColors.ink : AppColors.muted)),
        ),
      ),
    );
  }

  static const _radiusOptions = [5.0, 10.0, 15.0, 20.0, 30.0];

  Widget _radiusSelector() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _radiusOptions.map((r) {
          final active = _radius == r;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (active) return;
                setState(() => _radius = r);
                _search();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.brand : AppColors.line),
                ),
                alignment: Alignment.center,
                child: Text('${r.round()} km',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.idle:
      case _Status.locating:
        return _center(
            spinner: true, text: 'Buscando tu ubicación…');
      case _Status.loading:
        return _center(spinner: true, text: 'Buscando cerca de ti…');
      case _Status.noPermission:
        return _center(
          icon: Icons.location_off_rounded,
          text: 'Necesito tu ubicación para mostrarte lugares cerca. '
              'Actívala y vuelve a intentar.',
          action: ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
        );
      case _Status.error:
        return _center(
          icon: Icons.error_outline_rounded,
          text: 'Ocurrió un problema al buscar. Inténtalo de nuevo.',
          action: ElevatedButton(onPressed: _search, child: const Text('Reintentar')),
        );
      case _Status.ok:
        if (_places.isEmpty) {
          return _center(
            icon: Icons.search_off_rounded,
            text: 'No encontré ${_kind == PlaceKind.gym ? 'gimnasios' : 'tiendas de suplementos'} '
                'a ${_radius.round()} km.\nProbá un rango más amplio arriba.',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '${_places.length} ${_kind == PlaceKind.gym ? 'gimnasios' : 'lugares'} a ${_radius.round()} km o menos',
                    style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: _places.length,
                itemBuilder: (_, i) => _placeCard(_places[i]),
              ),
            ),
          ],
        );
    }
  }

  Widget _center({bool spinner = false, IconData? icon, required String text, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const SizedBox(
                width: 30, height: 30,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brand),
              )
            else if (icon != null)
              Icon(icon, size: 42, color: AppColors.faint),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.35)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeCard(NearbyPlace p) {
    final isGym = p.kind == PlaceKind.gym;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isGym ? AppColors.brandSoft : AppColors.mintSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
                isGym ? Icons.fitness_center_rounded : Icons.medication_rounded,
                color: isGym ? AppColors.brand : AppColors.mint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (p.address != null)
                  Text(p.address!,
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text('${p.distanceKm.toStringAsFixed(1)} km',
                    style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openDirections(p),
            icon: const Icon(Icons.directions_rounded, color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}
