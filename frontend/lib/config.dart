class AppConfig {
  static const appName = 'NUCLEI TECH';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://161.97.87.75/ticket/api.php',
  );

  // Android emulator build example:
  // flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:8080/api.php

  // Physical phone build example:
  // flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8080/api.php

  // Live server build example:
  // flutter build apk --dart-define=API_BASE_URL=http://161.97.87.75/ticket/api.php

  static const refreshInterval = Duration(seconds: 15);
  static const socketReconnectMax = Duration(seconds: 30);
}
