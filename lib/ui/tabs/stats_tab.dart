import 'package:flutter/material.dart';

import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../../viewmodels/profile_view_model.dart';
import '../property_widgets.dart';
import '../widgets/stat_field.dart';

/// Ported from `Tabs/StatsTab.xaml(.cs)` — two columns of stat fields for
/// ProgressStatCounters and MobKills.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.model});

  final ProfileViewModel model;

  @override
  Widget build(BuildContext context) {
    return PropertyBuilder(
      properties: [model.profile],
      builder: (context) {
        final profile = model.profile.value;
        final counters = profile?.progressStatCounters ?? const {};
        final mobKills = profile?.mobKills ?? const {};
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statColumn(context, R.progressStatCounters, counters,
                (key, v) => profile?.progressStatCounters?[key] = v),
            _statColumn(context, R.mobKills, mobKills,
                (key, v) => profile?.mobKills?[key] = v),
          ],
        );
      },
    );
  }

  Widget _statColumn(BuildContext context, String title,
      Map<String, int> stats, void Function(String, int) setter) {
    return SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child:
                    Text(title, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final pair in stats.entries)
                  StatField(
                    key: ValueKey('${title}/${pair.key}'),
                    title: pair.key,
                    value: pair.value,
                    minValue: 0,
                    onChanged: (v) {
                      EventLogger.logEvent('statTextbox_TextChanged');
                      setter(pair.key, v);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
