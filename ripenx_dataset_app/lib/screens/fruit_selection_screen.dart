import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ripenx_app_bar.dart';
import 'variety_screen.dart';

// ── Fruit data ──────────────────────────────────────────────────────────────

class _FruitItem {
  const _FruitItem({required this.name, required this.icon});
  final String name;
  final IconData icon;
}

const List<_FruitItem> _fruits = [
  _FruitItem(name: 'Mango',  icon: Icons.spa_rounded),
  _FruitItem(name: 'Banana', icon: Icons.spa_outlined),
  _FruitItem(name: 'Apple',  icon: Icons.spa),
  _FruitItem(name: 'Orange', icon: Icons.circle_outlined),
  _FruitItem(name: 'Papaya', icon: Icons.local_florist_rounded),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class FruitSelectionScreen extends StatelessWidget {
  const FruitSelectionScreen({super.key});

  void _onFruitSelected(BuildContext context, String fruit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VarietyScreen(fruit: fruit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const RipenxAppBar(title: 'Select Fruit'),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          itemCount: _fruits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _fruits[index];
            return _FruitCard(
              item: item,
              onTap: () => _onFruitSelected(context, item.name),
            );
          },
        ),
      ),
    );
  }
}

// ── Fruit card ──────────────────────────────────────────────────────────────

class _FruitCard extends StatelessWidget {
  const _FruitCard({required this.item, required this.onTap});
  final _FruitItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        splashColor: AppTheme.accent.withValues(alpha: 0.12),
        highlightColor: AppTheme.accent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(item.icon, color: AppTheme.accent, size: 24),
              ),
              const SizedBox(width: 18),
              // Name
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
