# VigoriaFit

App móvil (Flutter) de acompañamiento en salud y bienestar con inteligencia
artificial: rutinas con progresión automática de cargas, nutrición y
suplementos filtrados por condiciones de salud y alergias, un coach
conversacional (Gemini), buscador de gimnasios/farmacias cercanos y un rol de
entrenador con grupos y seguimiento de adherencia.

Proyecto de Título — Ingeniería en Informática, INACAP.

## Cómo correrlo

1. Instala Flutter y `flutter pub get`.
2. Copia `lib/core/secrets.example.dart` a `lib/core/secrets.dart` y pon ahí
   tu propia API key de Gemini (gratis en https://aistudio.google.com/apikey).
   Sin ella, el coach sigue funcionando con su motor por reglas (offline).
3. `flutter run` (Android) o `flutter build apk --release` para generar el APK.

Este proyecto usa Firebase (Cloud Firestore) para el rol de entrenador y
grupos; `android/app/google-services.json` ya está incluido y configurado.
