import 'dart:async';

import 'package:flutter/material.dart';

/// Ported from `UserControls/Stepper.xaml` — a narrow up/down repeat button
/// pair. Repeats while held, like WPF's RepeatButton.
class StepperControl extends StatefulWidget {
  const StepperControl({super.key, this.onUp, this.onDown, this.width = 26, this.height});

  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final double width;
  final double? height;

  @override
  State<StepperControl> createState() => _StepperControlState();
}

class _StepperControlState extends State<StepperControl> {
  Timer? _repeatTimer;

  void _startRepeat(VoidCallback? action) {
    if (action == null) return;
    action();
    _repeatTimer?.cancel();
    _repeatTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        action();
      });
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  Widget _button(IconData icon, VoidCallback? action, String label) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _startRepeat(action),
        onTapUp: (_) => _stopRepeat(),
        onTapCancel: _stopRepeat,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Icon(icon, size: 10, semanticLabel: label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.arrow_drop_up, widget.onUp, 'Up'),
          _button(Icons.arrow_drop_down, widget.onDown, 'Down'),
        ],
      ),
    );
  }
}
