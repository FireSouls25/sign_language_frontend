import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class LSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showConnectionIndicator;
  final bool? isConnected;
  final bool? isConnecting;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool showThemeToggle;

  const LSAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showConnectionIndicator = false,
    this.isConnected,
    this.isConnecting,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showThemeToggle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    Widget? titleWidget;
    if (showConnectionIndicator && isConnected != null) {
      titleWidget = Row(
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
                  ? Colors.greenAccent
                  : (isConnecting == true ? Colors.orange : Colors.red),
            ),
          ),
        ],
      );
    }

    List<Widget>? allActions = actions != null
        ? List<Widget>.from(actions!)
        : null;

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
        allActions!.insert(0, toggleButton);
      }
    }

    return AppBar(
      title: titleWidget ?? Text(title),
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
