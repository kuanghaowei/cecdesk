import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _autoStart = false;
  bool _minimizeToTray = true;
  bool _enableNotifications = true;
  bool _hardwareAcceleration = true;
  String _videoQuality = 'High';
  String _audioQuality = 'High';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'General',
            [
              SwitchListTile(
                title: const Text('Auto-start on boot'),
                subtitle: const Text('Start the application when system boots'),
                value: _autoStart,
                onChanged: (value) {
                  setState(() {
                    _autoStart = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Minimize to system tray'),
                subtitle: const Text('Keep running in background when closed'),
                value: _minimizeToTray,
                onChanged: (value) {
                  setState(() {
                    _minimizeToTray = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Enable notifications'),
                subtitle: const Text('Show connection and transfer notifications'),
                value: _enableNotifications,
                onChanged: (value) {
                  setState(() {
                    _enableNotifications = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Performance',
            [
              SwitchListTile(
                title: const Text('Hardware acceleration'),
                subtitle: const Text('Use GPU for video encoding/decoding'),
                value: _hardwareAcceleration,
                onChanged: (value) {
                  setState(() {
                    _hardwareAcceleration = value;
                  });
                },
              ),
              ListTile(
                title: const Text('Video quality'),
                subtitle: Text(_videoQuality),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  _showQualityDialog('Video Quality', _videoQuality, (value) {
                    setState(() {
                      _videoQuality = value;
                    });
                  });
                },
              ),
              ListTile(
                title: const Text('Audio quality'),
                subtitle: Text(_audioQuality),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  _showQualityDialog('Audio Quality', _audioQuality, (value) {
                    setState(() {
                      _audioQuality = value;
                    });
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'About',
            [
              ListTile(
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                title: const Text('Build'),
                subtitle: const Text('2024.01.01'),
              ),
              ListTile(
                title: const Text('Licenses'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  showLicensePage(context: context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showQualityDialog(String title, String currentValue, Function(String) onChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Low'),
              value: 'Low',
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Medium'),
              value: 'Medium',
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('High'),
              value: 'High',
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}