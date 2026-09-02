import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/secrets.dart';
import '../data/nutrition.dart';
import '../data/supplements.dart';
import '../data/workouts.dart';
import '../models/logs.dart';
import '../models/profile.dart';
import '../models/week_plan.dart';
import 'store.dart';

/// Coach de vida saludable de VigoriaFit.
///
/// Con API key de Gemini responde con **IA real**, usando el perfil y los datos
/// del usuario como contexto. Sin key o si falla, usa un **motor por reglas**
/// (offline), así nunca deja de responder. No reemplaza a un profesional.
class Coach {
  Coach._();

  static Future<String> reply(String question) async {
    if (kUseGeminiAI) {
      try {
        return await _askGemini(question);
      } catch (_) {
        // Sin red o error de la API: caemos al motor por reglas.
      }
    }
    return answer(question);
  }

  static Future<String> _askGemini(String question) async {
    final model = GenerativeModel(
      model: kGeminiModel,
      apiKey: kGeminiApiKey,
      systemInstruction: Content.system(
        'Eres el coach de vida saludable de la app VigoriaFit, para jóvenes chilenos. '
        'Hablas cercano, motivador y en chileno neutro, con respuestas BREVES '
        '(2 a 4 frases). Das consejos de entrenamiento, alimentación y hábitos '
        'usando SOLO los datos del usuario que te entrego; no inventes cifras. '
        'Sugiere comida chilena y accesible. Si el usuario tiene condiciones de '
        'salud o alergias marcadas en sus datos, tenlas en cuenta en tus '
        'sugerencias (ej: evita recomendar cafeína si es hipertenso). No eres '
        'médico: nunca uses las palabras "diagnóstico" ni "tratamiento", y ante '
        'temas de salud delicados recomienda ver a un profesional. Puedes usar '
        '1 emoji como máximo.',
      ),
      generationConfig: GenerationConfig(maxOutputTokens: 500, temperature: 0.7),
    );

    final prompt = 'Datos del usuario:\n${_context()}\n\n'
        'Pregunta del usuario: "$question"';
    final res = await model.generateContent([Content.text(prompt)]);
    final text = res.text?.trim();
    if (text == null || text.isEmpty) return answer(question);
    return text;
  }

  /// Analiza la foto de un plato con IA (Gemini vision) y estima nombre,
  /// calorías y proteína. Lanza excepción si no hay IA o falla.
  static Future<FoodEntry> analyzeFood(Uint8List bytes) async {
    if (!kUseGeminiAI) {
      throw Exception('Necesitas configurar la IA para usar el escáner.');
    }
    final model = GenerativeModel(
      model: kGeminiModel,
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(maxOutputTokens: 300, temperature: 0.2),
    );
    const prompt =
        'Eres un nutricionista. Mira la foto de comida y estima los valores de '
        'una porción típica. Responde SOLO con un JSON válido, sin texto extra ni '
        'markdown, con este formato exacto: '
        '{"nombre": "nombre corto del plato", "kcal": number, "proteina": number}. '
        'Si la imagen NO es comida, responde {"nombre": "No es comida", "kcal": 0, "proteina": 0}.';
    final res = await model.generateContent([
      Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)]),
    ]);
    final text = res.text ?? '';
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) throw Exception('No pude leer la respuesta de la IA.');
    final j = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    final name = (j['nombre'] ?? 'Comida').toString();
    final kcal = ((j['kcal'] ?? 0) as num).round();
    final protein = ((j['proteina'] ?? 0) as num).round();
    return FoodEntry(name, kcal, protein);
  }

  /// Genera un plan semanal (7 días) personalizado con IA: enfoque de
  /// entrenamiento y tip de alimentación para cada día. Si no hay IA o falla,
  /// arma un plan sencillo por reglas para que la función nunca se rompa.
  static Future<WeekPlan> generateWeekPlan() async {
    if (kUseGeminiAI) {
      try {
        return await _askGeminiWeekPlan();
      } catch (_) {
        // Sigue al plan por reglas.
      }
    }
    return _ruleWeekPlan();
  }

  static Future<WeekPlan> _askGeminiWeekPlan() async {
    final model = GenerativeModel(
      model: kGeminiModel,
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(maxOutputTokens: 900, temperature: 0.8),
    );
    final prompt =
        'Eres un coach de vida saludable. Arma un plan de 7 días (Lunes a '
        'Domingo) para este usuario:\n${_context()}\n\n'
        'Responde SOLO con un JSON válido (sin markdown, sin texto extra) con '
        'este formato exacto: {"dias": [ {"dia": "Lunes", "enfoque": string '
        'corto (ej: "Tren superior" o "Descanso activo"), "entreno": consejo '
        'breve de 1 frase, "comida": consejo breve de 1 frase con comida '
        'chilena}, ... 7 objetos, uno por día]}. Incluye al menos 1 día de '
        'descanso. Sé variado y motivador, sin inventar datos que no te di.';
    final res = await model.generateContent([Content.text(prompt)]);
    final text = res.text ?? '';
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) throw Exception('Respuesta de IA no válida.');
    final j = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    final list = (j['dias'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return DayPlan(
        (m['dia'] ?? '').toString(),
        (m['enfoque'] ?? '').toString(),
        (m['entreno'] ?? '').toString(),
        (m['comida'] ?? '').toString(),
      );
    }).toList();
    if (list.length != 7) throw Exception('Plan incompleto.');
    return WeekPlan(DateTime.now(), list);
  }

  /// Plan de respaldo (sin IA): alterna enfoques usando el catálogo local.
  static WeekPlan _ruleWeekPlan() {
    final p = AppStore.instance.profile;
    const dayNames = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final focuses = p.hasGym
        ? ['Tren superior', 'Cardio', 'Tren inferior', 'Descanso activo',
            'Full body', 'Core', 'Descanso']
        : ['Full body', 'HIIT', 'Movilidad', 'Descanso activo', 'Full body',
            'Core', 'Descanso'];
    final days = List.generate(7, (i) {
      final rest = focuses[i].toLowerCase().contains('descanso');
      return DayPlan(
        dayNames[i],
        focuses[i],
        rest
            ? 'Camina o estira suave, tu cuerpo también necesita recuperarse.'
            : 'Sigue la rutina sugerida en la pestaña Entreno para hoy.',
        'Prioriza proteína (~${p.proteinGrams} g) y verduras en tus comidas.',
      );
    });
    return WeekPlan(DateTime.now(), days);
  }

  static String _context() {
    final s = AppStore.instance;
    final p = s.profile;
    final foods = s.today.foods;
    return [
      'Nombre: ${p.name}',
      'Objetivo: ${p.goal.label}',
      'Nivel: ${p.level.label}',
      'Edad: ${p.age} años',
      'Estatura: ${p.heightCm.round()} cm',
      'Peso actual: ${p.weightKg.round()} kg (meta: ${p.targetWeightKg.round()} kg)',
      'IMC: ${p.bmi.toStringAsFixed(1)} (${p.bmiLabel})',
      'Entrena: ${p.daysPerWeek} días/semana, ${p.hasGym ? "con gimnasio" : "en casa sin equipo"}',
      if (p.conditions.isNotEmpty)
        'Condiciones de salud: ${p.conditions.map((c) => c.label).join(", ")}',
      if (p.allergies.isNotEmpty)
        'Alergias/intolerancias: ${p.allergies.map((a) => a.label).join(", ")}',
      'Calorías diarias estimadas: ${p.dailyKcal} kcal',
      'Proteína diaria sugerida: ${p.proteinGrams} g',
      'Agua hoy: ${s.waterToday}/${p.waterGoal} vasos',
      'Comidas registradas hoy: ${foods.isEmpty ? "ninguna todavía" : foods.map((f) => '${f.name} (${f.kcal} kcal)').join(", ")}',
      'Calorías consumidas hoy: ${s.kcalToday} kcal · Proteína consumida hoy: ${s.proteinToday} g',
      'Racha actual: ${s.streak} días',
      'Entrenamientos últimos 7 días: ${s.workoutsThisWeek}',
    ].join('\n');
  }

  // ── Motor por reglas (fallback offline) ──────────────────────────────────
  static String answer(String question) {
    final s = AppStore.instance;
    final p = s.profile;
    final q = _norm(question);

    if (q.isEmpty) return _help();

    if (_any(q, ['hola', 'ola', 'holi', 'buenas', 'buenos dias', 'hey'])) {
      return '¡Hola ${p.name}! 👋 ${_help()}';
    }
    if (_any(q, ['gracias', 'grax', 'thanks'])) {
      return '¡De nada! 💪 Tú puedes, sigue así.';
    }
    if (_any(q, ['como estas', 'que tal', 'que haces', 'todo bien'])) {
      return '¡Con toda la energía! 😄 ¿En qué te ayudo con tu ${p.goal.label.toLowerCase()}?';
    }

    // Proteína
    if (_any(q, ['proteina', 'proteinas'])) {
      return 'Para tu objetivo (${p.goal.label.toLowerCase()}) te sugiero unos '
          '${p.proteinGrams} g de proteína al día. Reparte en tus comidas: '
          'huevos, pollo, atún, legumbres o un batido. 💪';
    }
    // Calorías
    if (_any(q, ['caloria', 'calorias', 'kcal', 'cuanto comer'])) {
      return 'Tu estimación es ~${p.dailyKcal} kcal al día para '
          '${p.goal.label.toLowerCase()}. Es orientativa; ajústala según cómo '
          'te sientas y tu progreso.';
    }
    // Agua
    if (_any(q, ['agua', 'hidrat', 'tomar agua'])) {
      return 'Apunta a ${p.waterGoal} vasos de agua al día. Hoy llevas '
          '${s.waterToday}. ¡Un vaso antes de cada comida y listo! 💧';
    }
    // Qué comer
    if (_any(q, ['que como', 'que comer', 'comida', 'almuerzo', 'desayuno',
        'cena', 'menu', 'dieta'])) {
      final menu = Nutrition.dayMenu(p.goal);
      final lines = menu.entries
          .map((e) => '${e.key.emoji} ${e.key.label}: ${e.value.name}')
          .join('\n');
      return 'Un menú simple para hoy (${p.goal.label.toLowerCase()}):\n$lines';
    }
    // Suplementos
    if (_any(q, ['suplemento', 'suplementos', 'creatina', 'proteina en polvo',
        'whey', 'que tomar'])) {
      final sup = Supplements.forGoal(p.goal).take(3);
      final lines = sup.map((x) => '${x.emoji} ${x.name}: ${x.benefit}').join('\n');
      return 'Para tu objetivo, lo más útil suele ser:\n$lines\n\n'
          'Recuerda: primero la comida real, los suplementos solo complementan.';
    }
    // Rutina / ejercicio
    if (_any(q, ['rutina', 'entren', 'ejercicio', 'que hago hoy', 'workout'])) {
      final w = Workouts.todayFor(p);
      return 'Hoy te recomiendo: "${w.title}" (${w.minutes} min, ${w.focus}). '
          'Ábrela en la pestaña Entreno y ve marcando. ¡A darle! 🔥';
    }
    // Bajar de peso / grasa
    if (_any(q, ['bajar de peso', 'bajar peso', 'adelgazar', 'quemar grasa',
        'perder grasa'])) {
      return 'Para bajar grasa: leve déficit (~${p.dailyKcal} kcal), harta '
          'proteína (${p.proteinGrams} g), fuerza + algo de cardio, y dormir '
          'bien. Sin apuros: 0,5 kg por semana es un ritmo sano. 🔥';
    }
    // Subir masa
    if (_any(q, ['subir masa', 'ganar musculo', 'masa muscular', 'aumentar musculo'])) {
      return 'Para ganar músculo: come un poco por sobre tu gasto (~${p.dailyKcal} '
          'kcal), ${p.proteinGrams} g de proteína, entrena fuerza 3-4 veces y '
          'sube la carga de a poco. La constancia es la clave. 💪';
    }
    // Motivación
    if (_any(q, ['no tengo ganas', 'flojera', 'desmotiv', 'me cuesta', 'paja'])) {
      return 'Te entiendo. Parte chico: 10 minutos hoy ya es ganar. Llevas '
          '${s.streak} días de racha, no la cortes. Tu yo de mañana te lo va a '
          'agradecer. 🙌';
    }

    return 'Buena pregunta 🤔. Te cuento cómo vas: objetivo ${p.goal.label}, '
        '${s.workoutsThisWeek} entrenos esta semana y ${s.waterToday}/${p.waterGoal} '
        'vasos de agua hoy.\n\nPrueba preguntarme "¿qué como hoy?", "¿qué '
        'suplemento me sirve?", "¿cuánta proteína necesito?" o "¿qué rutina hago?".';
  }

  static String _help() =>
      'Soy tu coach 💪. Pregúntame cosas como:\n'
      '• "¿Qué como hoy?"\n'
      '• "¿Qué suplemento me sirve?"\n'
      '• "¿Cuánta proteína necesito?"\n'
      '• "¿Qué rutina hago hoy?"\n'
      '• "No tengo ganas de entrenar"';

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _any(String text, List<String> needles) =>
      needles.any((n) => text.contains(n));
}
