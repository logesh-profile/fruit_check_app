import 'package:flutter/material.dart';
import '../services/dataset_service.dart';
import '../theme/app_theme.dart';
import 'dataset_setup_screen.dart';
import 'fruit_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _datasetName;

  @override
  void initState() {
    super.initState();
    _checkAndLoadDataset();
  }

  Future<void> _checkAndLoadDataset() async {
    final hasAccess = await DatasetService.hasDatasetRoot();
    if (!hasAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Dataset folder access expired. Please select FRUIT_DATASET again.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DatasetSetupScreen()),
        (_) => false,
      );
      return;
    }

    final name = await DatasetService.getDatasetRootName();
    if (mounted) setState(() => _datasetName = name);
  }

  // ── Change dataset folder ─────────────────────────────────────────────────

  Future<void> _changeDatasetFolder() async {
    await DatasetService.resetDatasetRoot();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DatasetSetupScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Logo icon ─────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.25),
                        AppTheme.accentDark.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 48,
                    color: AppTheme.accent,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Title ─────────────────────────────────────────────────
                const Text(
                  'RIPENX',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Subtitle ──────────────────────────────────────────────
                const Text(
                  'Fruit Dataset Collection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                    color: AppTheme.textMuted,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Dataset status indicator ──────────────────────────────
                _DatasetBadge(name: _datasetName),

                const SizedBox(height: 44),

                // ── Accent rule ───────────────────────────────────────────
                Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 44),

                // ── Start Collection button ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FruitSelectionScreen(),
                      ),
                    ),
                    style: AppTheme.primaryButton(),
                    child: const Text('Start Collection'),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Change dataset folder ─────────────────────────────────
                TextButton.icon(
                  onPressed: _changeDatasetFolder,
                  icon: const Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  label: const Text(
                    'Change Dataset Folder',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Version ───────────────────────────────────────────────
                const Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDisabled,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dataset badge ────────────────────────────────────────────────────────────

class _DatasetBadge extends StatelessWidget {
  const _DatasetBadge({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 6),
          Text(
            name!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
