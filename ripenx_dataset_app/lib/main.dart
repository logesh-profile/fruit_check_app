import 'package:flutter/material.dart';
import 'screens/dataset_setup_screen.dart';
import 'screens/home_screen.dart';
import 'services/dataset_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RipenxApp());
}

class RipenxApp extends StatelessWidget {
  const RipenxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIPENX Dataset',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.accent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _AppLoader(),
    );
  }
}

/// Resolves the initial route asynchronously:
///   - No saved dataset root  →  [DatasetSetupScreen]
///   - Saved dataset root     →  [HomeScreen]
class _AppLoader extends StatelessWidget {
  const _AppLoader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: DatasetService.hasDatasetRoot(),
      builder: (context, snapshot) {
        // Loading
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }
        // Route based on stored root
        return snapshot.data! ? const HomeScreen() : const DatasetSetupScreen();
      },
    );
  }
}
