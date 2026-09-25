import 'package:flutter/material.dart';
import '../services/dataset_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ripenx_app_bar.dart';
import 'camera_screen.dart';

// ── Default variety sets ────────────────────────────────────────────────────

const Map<String, List<String>> _defaultVarieties = {
  'mango':  ['Banganapalli', 'Totapuri', 'Alphonso'],
  'banana': ['Robusta', 'Cavendish', 'Red Banana'],
  'apple':  ['Fuji', 'Gala', 'Granny Smith'],
  'orange': ['Valencia', 'Navel', 'Blood Orange'],
  'papaya': ['Solo', 'Maradol', 'Thai Papaya'],
};

// ── Screen ──────────────────────────────────────────────────────────────────

class VarietyScreen extends StatefulWidget {
  const VarietyScreen({super.key, required this.fruit});
  final String fruit;

  @override
  State<VarietyScreen> createState() => _VarietyScreenState();
}

class _VarietyScreenState extends State<VarietyScreen> {
  final List<String> _varieties = [];
  final TextEditingController _addController = TextEditingController();
  bool _isCreatingFolder = false;

  @override
  void initState() {
    super.initState();
    _loadVarieties();
  }

  Future<void> _loadVarieties() async {
    final defaults = _defaultVarieties[widget.fruit.toLowerCase()] ?? [];
    final custom = await StorageService.loadCustomVarieties(widget.fruit);

    final merged = <String>[];
    for (final v in defaults) {
      if (!merged.any((item) => item.toLowerCase() == v.toLowerCase())) {
        merged.add(v);
      }
    }
    for (final v in custom) {
      if (!merged.any((item) => item.toLowerCase() == v.toLowerCase())) {
        merged.add(v);
      }
    }

    if (mounted) {
      setState(() {
        _varieties
          ..clear()
          ..addAll(merged);
      });
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _onVarietySelected(String variety) async {
    if (_isCreatingFolder) return;
    setState(() => _isCreatingFolder = true);

    try {
      await DatasetService.prepareVarietyFolder(
        widget.fruit,
        variety,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraScreen(
            fruit: widget.fruit,
            variety: variety,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to prepare variety folder: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingFolder = false);
      }
    }
  }

  Future<void> _showAddVarietyDialog() async {
    _addController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddVarietyDialog(
        controller: _addController,
        onAdd: (name) async {
          final trimmed = name.trim();
          if (trimmed.isNotEmpty &&
              !_varieties.any((v) => v.toLowerCase() == trimmed.toLowerCase())) {
            setState(() => _varieties.add(trimmed));

            // Persist custom varieties
            final defaults = _defaultVarieties[widget.fruit.toLowerCase()] ?? [];
            final customOnly = _varieties
                .where((v) => !defaults.any((d) => d.toLowerCase() == v.toLowerCase()))
                .toList();
            await StorageService.saveCustomVarieties(widget.fruit, customOnly);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: RipenxAppBar(title: widget.fruit),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            ..._varieties.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VarietyCard(
                  name: e.value,
                  index: e.key,
                  onTap: () => _onVarietySelected(e.value),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _AddVarietyButton(onTap: _showAddVarietyDialog),
          ],
        ),
      ),
    );
  }
}

// ── Variety card ────────────────────────────────────────────────────────────

class _VarietyCard extends StatelessWidget {
  const _VarietyCard({
    required this.name,
    required this.index,
    required this.onTap,
  });
  final String name;
  final int index;
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
              // Index badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
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

// ── Add variety button ──────────────────────────────────────────────────────

class _AddVarietyButton extends StatelessWidget {
  const _AddVarietyButton({required this.onTap});
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
                'Add New Variety',
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

// ── Add variety dialog ──────────────────────────────────────────────────────

class _AddVarietyDialog extends StatefulWidget {
  const _AddVarietyDialog({
    required this.controller,
    required this.onAdd,
  });
  final TextEditingController controller;
  final ValueChanged<String> onAdd;

  @override
  State<_AddVarietyDialog> createState() => _AddVarietyDialogState();
}

class _AddVarietyDialogState extends State<_AddVarietyDialog> {
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
        DatasetService.validateSegmentName(text, 'Variety');
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
              'Add New Variety',
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
                hintText: 'Variety name',
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
