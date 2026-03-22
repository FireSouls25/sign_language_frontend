import 'package:flutter/material.dart';

class LSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showConnectionIndicator;
  final bool? isConnected;
  final bool? isConnecting;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const LSAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showConnectionIndicator = false,
    this.isConnected,
    this.isConnecting,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    return AppBar(
      title: titleWidget ?? Text(title),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: true,
      elevation: 0,
      backgroundColor: isDark ? null : Colors.deepPurple,
      foregroundColor: Colors.white,
      actions: actions,
    );
  }
}
