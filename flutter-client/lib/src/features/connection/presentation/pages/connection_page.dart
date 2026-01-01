import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final _deviceIdController = TextEditingController();
  final _accessCodeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Desktop Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to Remote Device',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'Enter the remote device ID',
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _accessCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Access Code (Optional)',
                        hintText: 'Enter access code if required',
                        prefixIcon: Icon(Icons.key),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isConnecting ? null : _connectToDevice,
                        child: _isConnecting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Connecting...'),
                                ],
                              )
                            : const Text('Connect'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Device',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.smartphone),
                      title: const Text('Device ID'),
                      subtitle: const Text('Loading...'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          // Copy device ID to clipboard
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wifi),
                      title: const Text('Status'),
                      subtitle: const Text('Online'),
                      trailing: const Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _generateAccessCode();
                        },
                        child: const Text('Generate Access Code'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Connections',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No recent connections',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToDevice() async {
    if (_deviceIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device ID')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Simulate connection attempt
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection established!')),
        );
        // Navigate to remote desktop view
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _generateAccessCode() {
    // Generate a temporary access code
    const accessCode = '123456'; // Placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access code generated: $accessCode'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Copy to clipboard
          },
        ),
      ),
    );
  }
}