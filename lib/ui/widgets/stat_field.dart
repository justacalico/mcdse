import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stepper.dart';

/// Ported from `UserControls/StatField.xaml(.cs)` — label + numeric textbox +
/// stepper, clamped between [minValue] and [maxValue].
class StatField extends StatefulWidget {
  const StatField({
    super.key,
    required this.title,
    required this.value,
    this.minValue = -9223372036854775808,
    this.maxValue = 9223372036854775807,
    this.onChanged,
  });

  final String title;
  final int? value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int>? onChanged;

  @override
  State<StatField> createState() => _StatFieldState();
}

class _StatFieldState extends State<StatField> {
  late final TextEditingController _controller;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(StatField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    widget.onChanged?.call(parsed);
  }

  int? get _numberValue => int.tryParse(_controller.text);

  void _increment() {
    final v = _numberValue;
    if (v != null) {
      _controller.text = min(v + 1, widget.maxValue).toString();
      _commit(_controller.text);
    }
  }

  void _decrement() {
    final v = _numberValue;
    if (v != null) {
      _controller.text = max(v - 1, widget.minValue).toString();
      _commit(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 330,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(widget.title, style: const TextStyle(fontSize: 14)),
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _invalid ? Colors.red : Colors.grey)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _invalid ? Colors.red : Colors.grey)),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
              onChanged: _commit,
            ),
          ),
          StepperControl(
              width: 12,
              height: 30,
              onUp: _increment,
              onDown: _decrement),
        ],
      ),
    );
  }
}
