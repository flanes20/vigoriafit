/// Configuración de la IA de VigoriaFit.
///
/// El coach usa **Google Gemini** (IA conversacional real) cuando hay una API
/// key configurada. Si está vacía, el coach funciona con su motor por reglas
/// (offline), así la app nunca deja de responder.
///
/// Cómo usarlo:
/// 1. Copia este archivo como `secrets.dart` en la misma carpeta
///    (`lib/core/secrets.dart`) — ese archivo está en .gitignore y no se sube.
/// 2. Consigue una API key gratis en https://aistudio.google.com/apikey
/// 3. Pégala abajo, reemplazando el texto entre comillas.
///
/// ⚠️ Para el MVP/demo la key va aquí. En producción debería ir en un backend
/// (no incrustada en el APK). Se documenta como trabajo futuro.
const String kGeminiApiKey = '';

/// Modelo de Gemini a usar (rápido y con nivel gratuito, sin "pensamiento").
const String kGeminiModel = 'gemini-3.5-flash-lite';

/// True si hay una key configurada → el coach usa IA real.
bool get kUseGeminiAI => kGeminiApiKey.trim().isNotEmpty;
