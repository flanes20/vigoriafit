import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/food_record.dart';
import '../models/logs.dart';
import 'account_preferences.dart';

/// CRUD de registros de comida, con persistencia local (SharedPreferences)
/// y sincronización a Firestore users/{uid}/food_records/{id}.
///
/// La fuente de verdad local es la lista completa serializada. Los totales
/// se derivan siempre de los registros vigentes, nunca de acumuladores.
class FoodService extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _kRecords = 'food_records_v1';

  String? _uid;
  AccountPreferences? _prefs;
  final List<FoodRecord> _records = [];
  String? _syncError;
  final Set<String> _pendingSyncIds = {};
  final Set<String> _pendingDeleteIds = {};

  List<FoodRecord> get records => List.unmodifiable(_records);
  String? get syncError => _syncError;
  bool get hasPendingSync => _pendingSyncIds.isNotEmpty || _pendingDeleteIds.isNotEmpty;

  // ── Carga / limpieza por cuenta ───────────────────────────────────────────

  Future<void> loadForUser(AccountPreferences prefs, String uid) async {
    _prefs = prefs;
    _uid   = uid;
    _records.clear();
    final raw = prefs.getStringList(_kRecords) ?? [];
    for (final s in raw) {
      try {
        final r = FoodRecord.fromJson(s);
        if (r.uid == uid) _records.add(r);
      } catch (_) {}
    }
    notifyListeners();
    if (uid != 'local_user') {
      _pullRemote(uid);
    }
  }

  void clearForUser() {
    _uid    = null;
    _prefs  = null;
    _records.clear();
    _syncError = null;
    _pendingSyncIds.clear();
    _pendingDeleteIds.clear();
    notifyListeners();
  }

  // ── Consultas ─────────────────────────────────────────────────────────────

  List<FoodRecord> forDay(DateTime date) {
    final k = dayKey(date);
    return _records.where((r) => dayKey(r.consumedAt.toLocal()) == k).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
  }

  double kcalForDay(DateTime date)    => forDay(date).fold(0, (s, r) => s + r.kcal);
  double proteinForDay(DateTime date) => forDay(date).fold(0, (s, r) => s + r.proteinG);
  double carbsForDay(DateTime date)   => forDay(date).fold(0, (s, r) => s + r.carbsG);
  double fatForDay(DateTime date)     => forDay(date).fold(0, (s, r) => s + r.fatG);

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Añade un registro. El [id] se genera en cliente; reintentos con el mismo
  /// ID actualizan en vez de duplicar.
  Future<FoodRecord> add(FoodRecord r) async {
    await _ensureSession();
    final effectiveUid = _uid ?? (r.uid.isNotEmpty ? r.uid : 'local_user');
    final record = r.id.isEmpty
        ? FoodRecord(
            id:         _uuid.v4(),
            uid:        effectiveUid,
            foodId:     r.foodId,
            foodName:   r.foodName,
            refQty:     r.refQty,
            refUnit:    r.refUnit,
            kcalRef:    r.kcalRef,
            proteinRef: r.proteinRef,
            carbsRef:   r.carbsRef,
            fatRef:     r.fatRef,
            quantity:   r.quantity,
            unit:       r.unit,
            mealType:   r.mealType,
            consumedAt: r.consumedAt,
            createdAt:  r.createdAt,
            updatedAt:  r.updatedAt,
          )
        : (r.uid.isEmpty ? r.copyWith(uid: effectiveUid) : r);
    final idx = _records.indexWhere((x) => x.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }
    notifyListeners();
    await _persist();
    try {
      _syncRecord(record);
    } catch (_) {}
    return record;
  }

  /// Actualiza un registro existente (conserva su ID y createdAt).
  Future<void> update(FoodRecord updated) async {
    await _ensureSession();
    final idx = _records.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;
    _records[idx] = updated;
    notifyListeners();
    await _persist();
    _syncRecord(updated);
  }

  /// Elimina un registro. La operación se persiste localmente de inmediato;
  /// si la sync remota falla, el registro ya no reaparecerá al reabrir.
  Future<void> delete(String id) async {
    await _ensureSession();
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persist();
    _deleteRemote(id);
  }

  // ── Persistencia local ────────────────────────────────────────────────────

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setStringList(_kRecords, _records.map((r) => r.toJson()).toList());
  }

  // ── Sync remota con reporte de error y reintento ────────────────────────────

  void _syncRecord(FoodRecord r) {
    final uid = _uid;
    if (uid == null || uid == 'local_user') return;
    _pendingSyncIds.add(r.id);
    _pendingDeleteIds.remove(r.id);
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('food_records')
        .doc(r.id)
        .set(_toFirestore(r))
        .then((_) {
          _pendingSyncIds.remove(r.id);
          if (_pendingSyncIds.isEmpty && _pendingDeleteIds.isEmpty) {
            _syncError = null;
          }
          notifyListeners();
        })
        .catchError((e) {
          _syncError = 'No se pudo sincronizar comida con la nube ($e).';
          notifyListeners();
        });
  }

  void _deleteRemote(String id) {
    final uid = _uid;
    if (uid == null || uid == 'local_user') return;
    _pendingDeleteIds.add(id);
    _pendingSyncIds.remove(id);
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('food_records')
        .doc(id)
        .delete()
        .then((_) {
          _pendingDeleteIds.remove(id);
          if (_pendingSyncIds.isEmpty && _pendingDeleteIds.isEmpty) {
            _syncError = null;
          }
          notifyListeners();
        })
        .catchError((e) {
          _syncError = 'No se pudo eliminar comida en la nube ($e).';
          notifyListeners();
        });
  }

  Future<void> retrySync() async {
    final uid = _uid;
    if (uid == null || uid == 'local_user') return;
    _syncError = null;
    notifyListeners();
    final toSync = _pendingSyncIds.toList();
    for (final id in toSync) {
      final idx = _records.indexWhere((r) => r.id == id);
      if (idx >= 0) _syncRecord(_records[idx]);
    }
    final toDelete = _pendingDeleteIds.toList();
    for (final id in toDelete) {
      _deleteRemote(id);
    }
  }

  Future<void> _pullRemote(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('food_records')
          .get();
      if (_uid != uid) return;
      var changed = false;
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        for (final k in const ['consumedAt', 'createdAt', 'updatedAt']) {
          final v = data[k];
          if (v is Timestamp) data[k] = v.toDate().toIso8601String();
        }
        try {
          final remote = FoodRecord.fromMap(data);
          if (_pendingDeleteIds.contains(remote.id)) continue;
          final idx = _records.indexWhere((r) => r.id == remote.id);
          if (idx < 0) {
            _records.add(remote);
            changed = true;
          } else if (!_pendingSyncIds.contains(remote.id) &&
              remote.updatedAt.isAfter(_records[idx].updatedAt)) {
            _records[idx] = remote;
            changed = true;
          }
        } catch (_) {}
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
    } catch (_) {}
  }

  Map<String, dynamic> _toFirestore(FoodRecord r) => {
    ...r.toMap(),
    'consumedAt': Timestamp.fromDate(r.consumedAt),
    'createdAt':  Timestamp.fromDate(r.createdAt),
    'updatedAt':  Timestamp.fromDate(r.updatedAt),
  };

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _ensureSession() async {
    if (_uid != null && _prefs != null) return;
    try {
      final storage = await SharedPreferences.getInstance();
      final uid = _uid ?? 'local_user';
      _uid = uid;
      _prefs = AccountPreferences(storage, uid);
      final raw = _prefs!.getStringList(_kRecords) ?? [];
      for (final s in raw) {
        try {
          final r = FoodRecord.fromJson(s);
          if (r.uid == uid && !_records.any((x) => x.id == r.id)) {
            _records.add(r);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
