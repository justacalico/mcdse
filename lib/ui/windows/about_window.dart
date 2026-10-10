import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/constants.dart';
import '../../services/config.dart';
import '../../services/string_library.dart';

/// Ported from `UI/Windows/AboutWindow.xaml(.cs)`.
class AboutWindow extends StatelessWidget {
  const AboutWindow({super.key, this.debug = false});

  final bool debug;

  static Future<void> show(BuildContext context, {bool debug = false}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(R.aboutWindowTitle),
        content: const SizedBox(width: 500, child: AboutWindow()),
      ),
    );
  }

  static Widget _link(BuildContext context, String text, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: copyright + version.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(children: [
                      const Text(
                          'Copyright © 2020-2022 Michael Holt ('),
                      _link(context, 'CutFlame',
                          'https://github.com/CutFlame'),
                      const Text(')'),
                    ]),
                    Wrap(children: [
                      const Text('Source code: '),
                      _link(context, 'GitHub',
                          'https://github.com/CutFlame/MCDSaveEdit'),
                    ]),
                    Wrap(children: [
                      const Text('License: '),
                      _link(context, 'MIT',
                          'https://github.com/CutFlame/MCDSaveEdit/blob/master/LICENSE'),
                    ]),
                  ],
                ),
              ),
              Text(
                R.formatVersion(Config.instance.versionLabel(),
                    Constants.currentVersionNumber),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Donation buttons.
          Wrap(
            spacing: 5,
            children: [
              TextButton(
                  onPressed: () => launchUrl(
                      Uri.parse('https://www.buymeacoffee.com/cutflame')),
                  child: const Text('BuyMeACoffee!')),
              TextButton(
                  onPressed: () =>
                      launchUrl(Uri.parse('https://ko-fi.com/cutflame')),
                  child: const Text('Donate on Ko-Fi!')),
              TextButton(
                  onPressed: () =>
                      launchUrl(Uri.parse('https://www.patreon.com/cutflame')),
                  child: const Text('Beta versions on Patreon!')),
            ],
          ),
          const SizedBox(height: 12),
          // Credits.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Images imported from Minecraft: Dungeons are Copyright © Mojang',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('External Credits and Licenses',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _creditLine(context, 'DungeonTools', 'Diego Russi', 'AGPL 3.0',
                  'https://github.com/HellPie/DungeonTools'),
              _creditLine(context, 'Microsoft.Bcl.AsyncInterfaces',
                  'Microsoft', 'MIT', 'https://github.com/dotnet/corefx'),
              _creditLine(context, 'Fody', 'Simon Cropp', 'MIT',
                  'https://github.com/Fody/Fody'),
              _creditLine(context, 'Costura.Fody',
                  'Simon Cropp and contributors', 'MIT',
                  'https://github.com/Fody/Costura'),
              _creditLine(context, 'FModel',
                  'Free Software Foundation, Inc.', 'GPL 3.0',
                  'https://github.com/iAmAsval/FModel'),
              _creditLine(context, 'PakReader', 'Aleks Margarian', 'MIT',
                  'https://github.com/WorkingRobot/PakReader'),
              _creditLine(context, 'Game-icons.net',
                  'Lorc, Delapouite and contributors', 'CC BY 3.0',
                  'https://game-icons.net/'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditLine(BuildContext context, String name, String author,
      String license, String url) {
    return Wrap(children: [
      _link(context, name, url),
      Text(' © $author ($license)'),
    ]);
  }
}
