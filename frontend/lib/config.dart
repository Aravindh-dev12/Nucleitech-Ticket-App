class AppConfig {
  static const appName = 'NUCLEI TECH';

  // Web / Windows development:
  static const apiBaseUrl = 'http://localhost:8080/api.php';

  // Android emulator example:
  // static const apiBaseUrl = 'http://10.0.2.2:8080/api.php';

  // Physical phone example:
  // static const apiBaseUrl = 'http://192.168.1.10:8080/api.php';

  static const refreshInterval = Duration(seconds: 15);
  static const socketReconnectMax = Duration(seconds: 30);
}
