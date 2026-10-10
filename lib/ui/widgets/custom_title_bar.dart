import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/constants.dart';
import '../../services/string_library.dart';

/// Frameless-window title bar — replaces the OS title bar. Drag anywhere on
/// the background to move the window; double-click toggles maximize. Hosts
/// the app icon, current window title, and min/max/close buttons.
class CustomTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key, required this.title});

  final String title;

  static const double barHeight = 32;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar>
    with WindowListener {
  bool _isMaximized = false;

  bool get _isDesktop =>
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _isMaximized = v);
      });
    }
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Widget _captionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? hoverColor,
  }) {
    return _CaptionButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      hoverColor: hoverColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHigh;
    final fg = scheme.onSurface.withValues(alpha: 0.85);

    return SizedBox(
      height: CustomTitleBar.barHeight,
      child: Material(
        color: bg,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Image.asset('assets/images/app_icon.png',
                width: 16, height: 16,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
            const SizedBox(width: 8),
            // Drag area fills the rest of the bar.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _isDesktop ? _toggleMaximize : null,
                child: _isDesktop
                    ? DragToMoveArea(
                        child: _TitleText(title: widget.title, color: fg),
                      )
                    : _TitleText(title: widget.title, color: fg),
              ),
            ),
            _captionButton(
              icon: Icons.minimize,
              tooltip: 'Minimize',
              onPressed: () =>
                  _isDesktop ? windowManager.minimize() : null,
            ),
            _captionButton(
              icon: _isMaximized
                  ? Icons.filter_none
                  : Icons.crop_square,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              onPressed: () {
                if (_isDesktop) _toggleMaximize();
              },
            ),
            _captionButton(
              icon: Icons.close,
              tooltip: 'Close',
              hoverColor: const Color(0xFFE81123),
              onPressed: () =>
                  _isDesktop ? windowManager.close() : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.isEmpty ? Constants.applicationTitle : title,
        style: TextStyle(fontSize: 12, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Windows-style caption button — square hover highlight; red hover is used
/// for the close button.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hovered = _hovering;
    final hoverBg = widget.hoverColor ??
        scheme.onSurface.withValues(alpha: 0.08);
    final iconColor = hovered && widget.hoverColor != null
        ? Colors.white
        : scheme.onSurface.withValues(alpha: 0.7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 46,
            height: CustomTitleBar.barHeight,
            color: hovered ? hoverBg : Colors.transparent,
            child: Icon(widget.icon, size: 15, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Updates the title shown in the custom bar (the OS title is still set via
/// [windowManager.setTitle] for taskbar/alt-tab).
abstract final class WindowTitle {
  static final ValueNotifier<String> notifier =
      ValueNotifier(R.applicationTitle);

  static String get title => notifier.value;
  static set title(String v) => notifier.value = v;
}
