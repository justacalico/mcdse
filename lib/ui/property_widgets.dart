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
  final List<PropertySubscriber<dynamic>> _subs = [];

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
      _subs.add(sub);
    }
  }

  @override
  void didUpdateWidget(PropertyBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (var i = 0; i < _subs.length; i++) {
      oldWidget.properties[i].unsubscribe(_subs[i]);
    }
    _subs.clear();
    _listenAll();
  }

  @override
  void dispose() {
    for (var i = 0; i < _subs.length; i++) {
      widget.properties[i].unsubscribe(_subs[i]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
