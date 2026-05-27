import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/language_select_screen.dart';

class LSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showConnectionIndicator;
  final bool? isConnected;
  final bool? isConnecting;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool showThemeToggle;
  final bool showLanguageSelector;
  final double toolbarHeight;

  const LSAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.showConnectionIndicator = false,
    this.isConnected,
    this.isConnecting,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showThemeToggle = true,
    this.showLanguageSelector = false,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();

    Widget? resolvedTitle;
    if (titleWidget != null) {
      resolvedTitle = titleWidget;
    } else if (showConnectionIndicator && isConnected != null) {
      resolvedTitle = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected!
                  ? AppTheme.getConnectionActive()
                  : (isConnecting == true ? AppTheme.getConnectionWarning() : AppTheme.getConnectionOffline()),
            ),
          ),
        ],
      );
    }

    List<Widget>? allActions = actions != null
        ? List<Widget>.from(actions!)
        : null;

    if (showLanguageSelector) {
      final languageButton = IconButton(
        icon: Icon(Icons.translate, color: theme.colorScheme.onPrimary),
        tooltip: 'Cambiar idioma',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
          );
        },
      );

      if (allActions == null) {
        allActions = [languageButton];
      } else {
        allActions.insert(0, languageButton);
      }
    }

    if (themeProvider.showAppBarToggle) {
      final toggleButton = IconButton(
        icon: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
        ),
        tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
        onPressed: () {
          themeProvider.toggleTheme(!isDark);
        },
      );

      if (allActions == null) {
        allActions = [toggleButton];
      } else {
        allActions.insert(0, toggleButton);
      }
    }

    return AppBar(
      title: resolvedTitle ?? Text(title),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      actions: allActions,
    );
  }
}
