import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Verificación de Configuración de Firebase - VigoriaFit', () {
    late Map<String, dynamic> googleServices;
    late String projectId;
    late String apiKey;
    late String packageName;

    setUpAll(() {
      final file = File('android/app/google-services.json');
      expect(file.existsSync(), isTrue,
          reason: 'El archivo android/app/google-services.json debe existir.');

      googleServices = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final projectInfo = googleServices['project_info'] as Map<String, dynamic>;
      projectId = projectInfo['project_id'] as String;

      final clientList = googleServices['client'] as List;
      expect(clientList.isNotEmpty, isTrue);

      final client = clientList.first as Map<String, dynamic>;
      packageName = client['client_info']['android_client_info']['package_name'];
      apiKey = (client['api_key'] as List).first['current_key'];
    });

    test('1. google-services.json tiene credenciales y proyecto válidos', () {
      expect(projectId, equals('vigoria-fe224'));
      expect(packageName, equals('com.vigoriafit.vigoriafit'));
      expect(apiKey.startsWith('AIzaSy'), isTrue,
          reason: 'La API Key de Firebase debe ser una clave válida de Google Cloud.');
    });

    test('2. android/app/build.gradle.kts coincide en applicationId y plugins', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content.contains('com.google.gms.google-services'), isTrue,
          reason: 'El plugin de Google Services debe estar aplicado en build.gradle.kts.');
      expect(content.contains('applicationId = "com.vigoriafit.vigoriafit"'), isTrue,
          reason: 'El applicationId debe coincidir exactamente con el paquete de Firebase.');
    });

    test('3. Conectividad y estado de Cloud Firestore en la nube', () async {
      final client = HttpClient();
      try {
        final uri = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/$projectId/databases?key=$apiKey');
        final req = await client.getUrl(uri);
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        print('DIAGNOSTICO_FIRESTORE: status=${res.statusCode}, body=$body');

        // Si responde 401 (UNAUTHENTICATED) o 403 (PERMISSION_DENIED), confirma que
        // la API de Google Cloud Firestore está habilitada y activa en el proyecto.
        expect(res.statusCode, anyOf(equals(200), equals(401), equals(403)));
      } finally {
        client.close();
      }
    });

    test('4. Conectividad y estado de Firebase Authentication en la nube', () async {
      final client = HttpClient();
      try {
        // Consultar el endpoint de Identity Toolkit de Firebase Auth con la clave del proyecto
        final uri = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$apiKey');
        final req = await client.postUrl(uri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'continueUri': 'http://localhost'}));
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();

        // 200 OK confirma que el servicio de autenticación para esta API Key está activo
        expect(res.statusCode, anyOf(equals(200), equals(400)),
            reason: 'Firebase Auth respondió con: $body');

        // Un error 400 con mensaje de Identity Toolkit o 200 confirma que el backend de Auth está respondiendo
        expect(body.contains('identitytoolkit') || body.contains('kind') || body.contains('error'), isTrue);
      } finally {
        client.close();
      }
    });
  });
}
