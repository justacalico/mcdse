import 'package:flutter/widgets.dart';

import '../core/property.dart';

/// Rebuilds whenever any of the listened [IReadProperty]s pushes a new value.
/// Bridges the ported observable-property layer into Flutter's widget tree.
class PropertyBuilder extends StatefulWidget {
  const PropertyBuilder({super.key, required this.properties, required this.builder});

  final List<IReadProperty<dynamic>> properties;
  final WidgetBuilder builder;

  @override
  State<PropertyBuilder> createState() => _PropertyBuilderState();
}

class _PropertyBuilderState extends State<PropertyBuilder> {
  /// (property, subscriber) pairs — unsubscribed from the exact property
  /// they were registered on even if the watched list changes shape.
  final List<(IReadProperty<dynamic>, PropertySubscriber<dynamic>)> _subs =
      [];

  @override
  void initState() {
    super.initState();
    _listenAll();
  }

  void _listenAll() {
    for (final p in widget.properties) {
      void sub(dynamic _) {
        if (mounted) setState(() {});
      }

      p.subscribe(sub);
      _subs.add((p, sub));
    }
  }

  void _unsubAll() {
    for (final (property, sub) in _subs) {
      property.unsubscribe(sub);
    }
    _subs.clear();
  }

  @override
  void didUpdateWidget(PropertyBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubAll();
    _listenAll();
  }

  @override
  void dispose() {
    _unsubAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
