import 'dart:developer';

import 'package:byd_display_switcher/services/device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_widget.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Material(color: Colors.transparent, child: OverlayWidget()),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomeScreen());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _overlayActive = false;
  final _portController = TextEditingController();
  int _selectedDisplay = 0;
  int _currentDensity = 0;
  SelfAdbService? adb;
  // int zoom =
  @override
  void initState() {
    super.initState();
    adb = SelfAdbService.instance;
    adb!
        .run("wm density | grep 'Physical' | awk '{print \$3 }'")
        .then(
          (value) => setState(() {
            _currentDensity = int.parse(value);
          }),
        );
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _toggleOverlay() async {
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }
    if (_overlayActive) {
      await FlutterOverlayWindow.closeOverlay();
      setState(() => _overlayActive = false);
    } else {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Floating Button',
        overlayContent: 'Running',
        flag: OverlayFlag.defaultFlag,
        height: 200,
        width: 200,
        positionGravity: PositionGravity.auto,
        alignment: OverlayAlignment.topLeft,
        startPosition: const OverlayPosition(20, 120),
      );
      setState(() => _overlayActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display Switcher')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text("Change Display Zoom")),
            Center(
              child: DropdownButton<int>(
                value: _selectedDisplay,
                items: [0, 2, 3, 4, 5]
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (val) async {
                  final out = await adb!.run(
                    "wm density | grep 'Physical' | awk '{print \$3 }'",
                  );
                  log(out);
                  setState(() {
                    _currentDensity = int.parse(out);
                    _selectedDisplay = val!;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Cuurent Density: $_currentDensity",
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (adb == null) return;
                      setState(() => _currentDensity += 15);
                      adb!.run(
                        "wm density $_currentDensity -d $_selectedDisplay ",
                      );
                    },
                    child: const Text('+ ZOOM'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (adb == null) return;
                      setState(() => _currentDensity -= 15);
                      adb!.run(
                        "wm density $_currentDensity -d $_selectedDisplay ",
                      );
                    },
                    child: const Text('- ZOOM'),
                  ),
                ],
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  if (adb == null) return;
                  final out = await adb!.run(
                    "wm density | grep 'Physical' | awk '{print \$3 }'",
                  );
                  setState(() {
                    _currentDensity = int.parse(out);
                  });
                  await adb!.run("wm density reset -d $_selectedDisplay");
                },
                child: const Text('Reset ZOOM'),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _toggleOverlay,
                icon: Icon(_overlayActive ? Icons.stop : Icons.play_arrow),
                label: Text(_overlayActive ? 'Stop Overlay' : 'Start Overlay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
