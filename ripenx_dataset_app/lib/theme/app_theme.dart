import 'package:flutter/material.dart';

/// Central design tokens for the RIPENX app.
/// All screens import from here so the visual identity stays consistent.
abstract final class AppTheme {
  // ── Colours ─────────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0D1117);
  static const Color surface      = Color(0xFF161B22);
  static const Color surfaceAlt   = Color(0xFF1C2128);
  static const Color border       = Color(0xFF30363D);
  static const Color accent       = Color(0xFF2ECC71);
  static const Color accentDark   = Color(0xFF27AE60);
  static const Color error        = Color(0xFFE74C3C);
  static const Color textPrimary  = Colors.white;
  static const Color textMuted    = Color(0xFF8B949E);
  static const Color textDisabled = Color(0xFF484F58);

  // ── Radii ────────────────────────────────────────────────────────────────
  static const double radiusCard   = 14.0;
  static const double radiusButton = 14.0;
  static const double radiusDialog = 16.0;

  // ── Shared button style ──────────────────────────────────────────────────
  static ButtonStyle primaryButton() => ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );
}
