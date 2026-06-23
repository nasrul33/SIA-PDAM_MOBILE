import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/token_store.dart';
import 'data/app_database.dart';
import 'data/auth_repository.dart';
import 'data/connectivity_service.dart';
import 'data/field_repository.dart';
import 'data/sync_service.dart';
import 'state/auth_provider.dart';
import 'state/field_provider.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = TokenStore();
  final db = AppDatabase.instance;

  late AuthProvider
      authProvider; // diisi tepat di bawah; closure baca saat dipanggil.
  final api = ApiClient(
    tokens,
    onUnauthorized: () async => authProvider.forceSignOut(),
  );

  final authRepo = AuthRepository(api, tokens);
  final fieldRepo = FieldRepository(api, db);
  final syncService = SyncService(api, db);

  authProvider = AuthProvider(authRepo, tokens);
  await tokens.readToken(); // hangatkan cache token sebelum request pertama.
  await authProvider.bootstrap();

  runApp(SiaPdamFieldApp(
    authProvider: authProvider,
    fieldProvider:
        FieldProvider(fieldRepo, db, syncService, ConnectivityService()),
  ));
}

class SiaPdamFieldApp extends StatelessWidget {
  const SiaPdamFieldApp({
    super.key,
    required this.authProvider,
    required this.fieldProvider,
  });

  final AuthProvider authProvider;
  final FieldProvider fieldProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: fieldProvider),
      ],
      child: MaterialApp(
        title: 'SIA-PDAM Lapangan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0277BD),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeScreen();
    }
  }
}
