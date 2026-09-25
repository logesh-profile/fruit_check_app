import 'package:flutter/material.dart';
import '../services/dataset_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ripenx_app_bar.dart';
import 'variety_screen.dart';

// ── Fruit data ──────────────────────────────────────────────────────────────

class _FruitItem {
  const _FruitItem({required this.name, required this.icon});
  final String name;
  final IconData icon;
}

const List<_FruitItem> _defaultFruits = [
  _FruitItem(name: 'Mango',  icon: Icons.spa_rounded),
  _FruitItem(name: 'Banana', icon: Icons.spa_outlined),
  _FruitItem(name: 'Apple',  icon: Icons.spa),
  _FruitItem(name: 'Orange', icon: Icons.circle_outlined),
  _FruitItem(name: 'Papaya', icon: Icons.local_florist_rounded),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class FruitSelectionScreen extends StatefulWidget {
  const FruitSelectionScreen({super.key});

  @override
  State<FruitSelectionScreen> createState() => _FruitSelectionScreenState();
}

class _FruitSelectionScreenState extends State<FruitSelectionScreen> {
  final List<_FruitItem> _fruits = [];
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFruits();
  }

  Future<void> _loadFruits() async {
    final custom = await StorageService.loadCustomFruits();
    final list = List<_FruitItem>.from(_defaultFruits);

    for (final name in custom) {
      if (!list.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
        list.add(_FruitItem(name: name, icon: Icons.eco_rounded));
      }
    }

    if (mounted) {
      setState(() {
        _fruits
          ..clear()
          ..addAll(list);
      });
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _onFruitSelected(BuildContext context, String fruit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VarietyScreen(fruit: fruit)),
    );
  }

  Future<void> _showAddFruitDialog() async {
    _addController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddFruitDialog(
        controller: _addController,
        onAdd: (name) async {
          final trimmed = name.trim();
          if (trimmed.isNotEmpty &&
              !_fruits.any((f) => f.name.toLowerCase() == trimmed.toLowerCase())) {
            setState(() {
              _fruits.add(_FruitItem(name: trimmed, icon: Icons.eco_rounded));
            });

            // Persist custom fruits
            final customOnly = _fruits
                .where((f) => !_defaultFruits.any((d) => d.name.toLowerCase() == f.name.toLowerCase()))
                .map((f) => f.name)
                .toList();
            await StorageService.saveCustomFruits(customOnly);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const RipenxAppBar(title: 'Select Fruit'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            ..._fruits.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FruitCard(
                  item: item,
                  onTap: () => _onFruitSelected(context, item.name),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _AddFruitButton(onTap: _showAddFruitDialog),
          ],
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

// ── Add fruit button ────────────────────────────────────────────────────────

class _AddFruitButton extends StatelessWidget {
  const _AddFruitButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppTheme.accent, size: 22),
              SizedBox(width: 10),
              Text(
                'Add New Fruit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add fruit dialog ────────────────────────────────────────────────────────

class _AddFruitDialog extends StatefulWidget {
  const _AddFruitDialog({
    required this.controller,
    required this.onAdd,
  });
  final TextEditingController controller;
  final ValueChanged<String> onAdd;

  @override
  State<_AddFruitDialog> createState() => _AddFruitDialogState();
}

class _AddFruitDialogState extends State<_AddFruitDialog> {
  bool _isEmpty = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    final empty = text.isEmpty;
    String? err;

    if (!empty) {
      try {
        DatasetService.validateSegmentName(text, 'Fruit');
      } catch (e) {
        if (e is ArgumentError) {
          err = e.message.toString();
        } else {
          err = 'Invalid name';
        }
      }
    }

    if (empty != _isEmpty || err != _errorText) {
      setState(() {
        _isEmpty = empty;
        _errorText = err;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _submit() {
    final name = widget.controller.text.trim();
    if (name.isNotEmpty && _errorText == null) {
      widget.onAdd(name);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isEmpty && _errorText == null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            const Text(
              'Add New Fruit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 20),

            // Text field
            TextField(
              controller: widget.controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                hintText: 'Fruit name (e.g. Guava)',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                errorText: _errorText,
                errorMaxLines: 2,
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 24),

            // Action row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      disabledBackgroundColor:
                          AppTheme.accent.withValues(alpha: 0.3),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
