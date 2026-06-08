import 'package:flutter/material.dart';

class ScriptVaultStyle {
  static const appBackground = Color(0xFF08111D);
  static const panel = Color(0xFF0D1724);
  static const panelRaised = Color(0xFF111D2B);
  static const panelSoft = Color(0xFF142238);
  static const editor = Color(0xFF07111C);
  static const border = Color(0xFF233246);
  static const borderStrong = Color(0xFF2E64A9);
  static const primary = Color(0xFF4B97FF);
  static const primaryStrong = Color(0xFF2578F6);
  static const text = Color(0xFFE6EEF8);
  static const muted = Color(0xFF94A3B8);
  static const subtle = Color(0xFF64748B);
  static const success = Color(0xFF35D06E);
  static const warning = Color(0xFFFFA33D);
  static const danger = Color(0xFFE11D48);
  static const folder = Color(0xFFF6C75E);

  static BorderSide get divider => const BorderSide(color: border);

  static BoxDecoration panelDecoration({bool selected = false}) {
    return BoxDecoration(
      color: selected ? panelSoft : panel,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: selected ? primary : border),
      boxShadow: selected
          ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static ButtonStyle toolbarButtonStyle({bool emphasized = false}) {
    return FilledButton.styleFrom(
      backgroundColor: emphasized ? primaryStrong : panelRaised,
      foregroundColor: text,
      disabledBackgroundColor: panelRaised.withValues(alpha: 0.45),
      disabledForegroundColor: muted,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: emphasized ? primary : border),
      ),
    );
  }

  static InputDecoration inputDecoration({
    required String label,
    String? helperText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: divider,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
    );
  }
}
