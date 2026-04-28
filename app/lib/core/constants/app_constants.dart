class AppConstants {
  static const String appName = 'Invoice & POS';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // API — your live deployed backend URL
  // Replace with your Koyeb/Render/Railway URL after deployment
  static const String baseUrl = 'https://invoicepos-production.up.railway.app/api';

  // Local DB
  static const String dbName = 'invoice_pos.db';
  static const int dbVersion = 1;

  // Hive boxes
  static const String syncQueueBox = 'sync_queue';
  static const String settingsBox = 'settings';
  static const String authBox = 'auth';

  // Secure storage keys
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
  static const String serverUrlKey = 'server_url';

  // Pagination
  static const int pageSize = 20;

  // Invoice prefix
  static const String invoicePrefix = 'INV';

  // Currency
  static String currency = '₹';
}
