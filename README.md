# VigoriaFit

App móvil (Flutter) de acompañamiento en salud y bienestar con inteligencia
artificial: rutinas con progresión automática de cargas, nutrición y
suplementos filtrados por condiciones de salud y alergias, un coach
conversacional (Gemini), buscador de gimnasios/farmacias cercanos y un rol de
entrenador con grupos y seguimiento de adherencia.

Proyecto de Título — Ingeniería en Informática, INACAP.

## Cómo correrlo

La instalación, el modelo de datos, las pruebas y los pendientes del entorno están en [la guía del Sprint 1](docs/SPRINT_1.md).

1. Usar Flutter 3.41.9 / Dart 3.11.5 e instalar el SDK Android.
2. Ejecutar `flutter pub get`.
3. Copiar `lib/core/secrets.example.dart` a `lib/core/secrets.dart` si no existe. La clave puede quedar vacía para probar autenticación y perfiles.
4. Ejecutar `flutter test --no-pub` y `flutter analyze --no-pub`.
5. Con un Android conectado o emulador iniciado, ejecutar `flutter run`.

La app utiliza Firebase Authentication para las cuentas y Firestore para perfiles y grupos. El proyecto configurado es **vigoria-fe224**. El acceso remoto, los proveedores habilitados y las reglas desplegadas deben comprobarse según la guía antes de considerar operativa la integración. Los registros diarios continúan siendo locales, separados por UID.
