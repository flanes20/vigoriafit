import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../models/logs.dart';
import '../services/coach.dart';
import '../services/store.dart';

/// Escáner de comida con IA: el usuario saca/elige una foto de su plato y la IA
/// (Gemini vision) estima nombre, calorías y proteína, y la registra en el día.
class FoodScannerPage extends StatefulWidget {
  const FoodScannerPage({super.key});

  @override
  State<FoodScannerPage> createState() => _FoodScannerPageState();
}

class _FoodScannerPageState extends State<FoodScannerPage> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  bool _analyzing = false;
  FoodEntry? _result;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
          source: source, imageQuality: 70, maxWidth: 1024);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _bytes = bytes;
        _result = null;
        _error = null;
      });
      _analyze();
    } catch (e) {
      setState(() => _error = 'No pude abrir la imagen.');
    }
  }

  Future<void> _analyze() async {
    if (_bytes == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final res = await Coach.analyzeFood(_bytes!);
      if (!mounted) return;
      setState(() {
        _result = res;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = 'No pude analizar la foto. Revisa tu internet e inténtalo de nuevo.';
      });
    }
  }

  void _save() {
    if (_result == null) return;
    AppStore.instance.addFood(_result!);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registrado: ${_result!.name} 🍽️')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de comida',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                const Text('📸', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Saca una foto a tu plato y la IA estima sus calorías y '
                      'proteína.',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.muted,
                          height: 1.35)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Zona de imagen
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                  image: _bytes != null
                      ? DecorationImage(
                          image: MemoryImage(_bytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _bytes == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_rounded,
                                size: 44, color: AppColors.faint),
                            const SizedBox(height: 10),
                            Text('Aún no hay foto',
                                style: TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Botones cámara / galería
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analyzing ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzing ? null : () => _pick(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.line),
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_analyzing) _analyzingCard(),
            if (_error != null) _errorCard(),
            if (_result != null && !_analyzing) _resultCard(),
          ],
        ),
      ),
    );
  }

  Widget _analyzingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppColors.brand),
          ),
          const SizedBox(width: 14),
          Text('Analizando con IA…',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.brandDark)),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warn.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.warn),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!,
                style: TextStyle(fontSize: 13, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final r = _result!;
    final isFood = r.kcal > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.brand),
              const SizedBox(width: 8),
              Text('Resultado de la IA',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(r.name,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 14),
          if (isFood)
            Row(
              children: [
                _macro('🔥', '${r.kcal}', 'kcal', AppColors.brand),
                const SizedBox(width: 12),
                _macro('🥩', '${r.protein} g', 'proteína', AppColors.protein),
              ],
            )
          else
            Text('No parece comida. Prueba con otra foto.',
                style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Text('Estimación aproximada de la IA.',
              style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
          if (isFood) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Registrar en mi día'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macro(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
