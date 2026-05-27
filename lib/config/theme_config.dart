import 'package:flutter/material.dart';

class AppTheme {
  static Color getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black87;
  }

  static Color getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[400]! : Colors.grey[600]!;
  }

  static Color getTextTertiary(BuildContext context) {
    return Colors.grey[500]!;
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[900]! : Colors.grey[100]!;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getIconPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getIconSecondary(BuildContext context) {
    return getTextSecondary(context);
  }

  static Color getDividerColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[700]! : Colors.grey[300]!;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getOnPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  static Color getPrimaryContainer(BuildContext context) {
    return Theme.of(context).colorScheme.primaryContainer;
  }

  static Color getOnPrimaryContainer(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimaryContainer;
  }

  static Color getOnSurfaceVariant(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color getSurfaceContainerHighest(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color getOutline(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color getOutlineVariant(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static Color getSuccessColor(BuildContext context) {
    return Colors.green;
  }

  static Color getWarningColor(BuildContext context) {
    return Colors.orange;
  }

  static Color getDangerColor(BuildContext context) {
    return Colors.red;
  }

  static Color getOverlayDark() {
    return Colors.black54;
  }

  static Color getFullScreenDark() {
    return Colors.black;
  }

  static Color getConnectionActive() {
    return Colors.greenAccent;
  }

  static Color getConnectionWarning() {
    return Colors.orange;
  }

  static Color getConnectionOffline() {
    return Colors.red;
  }

  static Color getGrey() {
    return Colors.grey;
  }

  static Color getWhite() {
    return Colors.white;
  }

  static List<Color> availableSeedColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
  ];

  static String getSeedColorName(Color color) {
    if (color == Colors.deepPurple) return 'Morado';
    if (color == Colors.blue) return 'Azul';
    if (color == Colors.teal) return 'Verde';
    return 'Custom';
  }
}
