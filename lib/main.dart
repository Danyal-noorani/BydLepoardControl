import 'dart:developer';

import 'package:byd_display_switcher/services/device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_widget.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: OverlayWidget(),
        ),
      ),
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
  Widget build(BuildContext context) =>
      MaterialApp(home: HomeScreen(), theme: ThemeData.dark());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _overlayActive = false;
  final _portController = TextEditingController();
  final adb = SelfAdbService();
  int _selectedDisplay = 0;
  int _currentDensity = 0;
  List<int> _displayIds = const [];
  // int zoom =
  @override
  void initState() {
    super.initState();
    adb.getDisplays().then(
      (value) => setState(() {
        _displayIds = value;
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
      setState(() => _overlayActive = false);
      await FlutterOverlayWindow.closeOverlay();
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
            Center(
              child: Text("ADB IP: ${adb.wifiIp}", textAlign: TextAlign.center),
            ),
            const SizedBox(height: 25),
            Center(
              child: Text(
                "ADB Error: ${adb.adbError}",
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 25),
            Center(child: Text("Change Display Zoom")),
            Center(
              child: DropdownButton<int>(
                value: _selectedDisplay,
                items: _displayIds
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (val) async {
                  final out = await adb.run(
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
                "Current Density: $_currentDensity",
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
                      setState(() => _currentDensity += 15);
                      adb.run(
                        "wm density $_currentDensity -d $_selectedDisplay ",
                      );
                    },
                    child: const Text('+ ZOOM'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _currentDensity -= 15);
                      adb.run(
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
                  final out = await adb.run(
                    "wm density | grep 'Physical' | awk '{print \$3 }'",
                  );
                  setState(() {
                    _currentDensity = int.parse(out);
                  });
                  await adb.run("wm density reset -d $_selectedDisplay");
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
