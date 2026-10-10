import 'package:flutter/material.dart';

import '../widgets/busy_indicator.dart';

/// Ported from `UI/Windows/SplashWindow.xaml` — the startup progress window
/// with a scrolling console log.
class SplashWindow extends StatefulWidget {
  const SplashWindow({super.key});

  @override
  State<SplashWindow> createState() => SplashWindowState();
}

class SplashWindowState extends State<SplashWindow> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();

  void log(String line) {
    if (!mounted) return;
    setState(() {
      _lines.add(line);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 480,
        height: 300,
        child: Card(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: BusyIndicator(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      for (final line in _lines)
                        Text(line,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
