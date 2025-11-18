import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'services/database_service_test.dart' as database_tests;
import 'services/session_service_test.dart' as session_tests;
import 'services/admin_auth_service_test.dart' as admin_auth_tests;
import 'integration/auth_integration_test.dart' as integration_tests;
import 'widget_test.dart' as widget_tests;
import 'pages/edit_circonscription_page_test.dart' as edit_circonscription_tests;
import 'pages/account_page_test.dart' as account_page_tests;
import 'pages/home_page_test.dart' as home_page_tests;

void main() {
  group('All AgoraPush Tests', () {
    // Services Tests
    group('📡 Services', () {
      group('Database Service Tests', database_tests.main);
      group('Session Service Tests', session_tests.main);
      group('Admin Auth Service Tests', admin_auth_tests.main);
    });

    // Pages Tests
    group('📱 Pages', () {
      group('Home Page Tests', home_page_tests.main);
      group('Account Page Tests', account_page_tests.main);
      group('Edit Circonscription Page Tests', edit_circonscription_tests.main);
    });

    // Widget Tests
    group('🧩 Widgets', () {
      group('Widget Tests', widget_tests.main);
    });

    // Integration Tests
    group('🔗 Integration', () {
      group('Authentication Integration Tests', integration_tests.main);
    });
  });
}