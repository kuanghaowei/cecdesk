import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteDesktopPage extends ConsumerStatefulWidget {
  final String sessionId;

  const RemoteDesktopPage({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<RemoteDesktopPage> createState() => _RemoteDesktopPageState();
}

class _RemoteDesktopPageState extends ConsumerState<RemoteDesktopPage> {
  bool _isFullscreen = false;
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showControls
          ? AppBar(
              title: Text('Remote Desktop - ${widget.sessionId}'),
              actions: [
                IconButton(
                  icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                ),
                IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () {
                    // Open file transfer
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    _showSessionSettings();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _disconnectSession();
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          children: [
            // Remote desktop display area
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.computer,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Remote Desktop Display',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to show/hide controls',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Connection status overlay
            if (_showControls)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 12,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Network quality indicator
            if (_showControls)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.signal_wifi_4_bar,
                        color: Colors.green,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '50ms • 1080p',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _showControls
          ? Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    onPressed: () {
                      _showVirtualKeyboard();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.mouse, color: Colors.white),
                    onPressed: () {
                      _toggleMouseMode();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.screenshot, color: Colors.white),
                    onPressed: () {
                      _takeScreenshot();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white),
                    onPressed: () {
                      _toggleAudio();
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    // Implement fullscreen toggle
  }

  void _showSessionSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Quality'),
              subtitle: const Text('High (1080p)'),
              onTap: () {
                // Show quality settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Network Stats'),
              subtitle: const Text('RTT: 50ms, Loss: 0.1%'),
              onTap: () {
                // Show detailed network stats
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Security'),
              subtitle: const Text('Encrypted connection'),
              onTap: () {
                // Show security info
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _disconnectSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Session'),
        content: const Text('Are you sure you want to disconnect from the remote desktop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to connection page
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _showVirtualKeyboard() {
    // Show virtual keyboard overlay
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Virtual keyboard activated')),
    );
  }

  void _toggleMouseMode() {
    // Toggle mouse mode
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mouse mode toggled')),
    );
  }

  void _takeScreenshot() {
    // Take screenshot of remote desktop
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Screenshot saved')),
    );
  }

  void _toggleAudio() {
    // Toggle audio capture/playback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio toggled')),
    );
  }
}