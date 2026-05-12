import 'dart:developer';

import 'package:byd_display_switcher/services/device_service.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _expanded = false;
  bool _showDisplays = false;
  String packageNameWithService = "";

  static const _btnSize = 60.0;
  static const _panelWidth = 400.0;
  static const _tileHeight = 60.0;
  // 3 tiles + 8dp gap between button and panel — same for both panels
  static const _panelHeight = 600.0;

  SelfAdbService? adb;
  List<ApplicationWithIcon> _availableApps = const [];
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    adb = SelfAdbService.instance;
    adb!.run("ls");
  }

  Future<void> _loadApps(String adbOut) async {
    final packages = adbOut
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final results = await Future.wait(
      packages.map((pkg) => DeviceApps.getApp(pkg, true)),
    );

    setState(() {
      _availableApps = results.whereType<ApplicationWithIcon>().toList();
    });
  }

  Future<void> _toggleOverlay() async {
    if (_expanded) {
      setState(() {
        _expanded = false;
        _showDisplays = false;
      });
      await FlutterOverlayWindow.resizeOverlay(
        _btnSize.toInt(),
        _btnSize.toInt(),
        true,
      );
    } else {
      await FlutterOverlayWindow.resizeOverlay(
        _panelWidth.toInt(),
        _panelHeight.toInt(),
        false,
      );
      setState(() => _expanded = true);
    }
  }

  Future<void> _getRunningApps() async {
    final out = await adb!.run(
      "ps -A | grep u[0-9999]_a | awk '{print \$NF}' | sort -u | while read p; do dumpsys package \$p 2>/dev/null | grep -q 'android.intent.category.LAUNCHER' && echo \$p; done",
    );
    await _loadApps(out);
    await _toggleOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              if (_expanded) {
                await _toggleOverlay();
              } else {
                await _getRunningApps();
              }
            },
            child: Container(
              width: _btnSize,
              height: _btnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _expanded ? Icons.close : Icons.display_settings,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: _panelWidth,
              margin: const EdgeInsets.only(top: 0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8),
                ],
              ),
              child: _showDisplays
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _displayTiles(),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) {
                        final offset = (_scrollController.offset - d.delta.dy)
                            .clamp(
                              0.0,
                              _scrollController.position.maxScrollExtent,
                            );
                        _scrollController.jumpTo(offset);
                      },
                      child: SizedBox(
                        height: _panelHeight,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _appTiles(_availableApps),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<Widget> _displayTiles() => [
    _displayTile('Driver\'s Display', Icons.looks_one_rounded, 5),
    const Divider(color: Colors.white12, height: 1),
    _displayTile('Main Display', Icons.looks_two_rounded, 0),
    const Divider(color: Colors.white12, height: 1),
    _displayTile('Passenger\'s Display', Icons.looks_3_rounded, 2),
  ];

  String? extractActivity(String raw) {
    final match = RegExp(r'[\w.]+\/[\w.]+').firstMatch(raw);
    return match?.group(0);
  }

  Widget _displayTile(String label, IconData icon, int displayId) {
    return GestureDetector(
      onTap: () async {
        log(packageNameWithService);
        if (adb != null) {
          final out = await adb!.run(
            "dumpsys package $packageNameWithService | grep -A 1 'android.intent.action.MAIN'",
          );
          final activity = extractActivity(out);
          if (activity != null) {
            final out = await adb!.run(
              "am start --display $displayId -n $activity",
            );
            log(out);
          }
        }
      },
      child: SizedBox(
        height: _tileHeight,
        width: _panelWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App list ──────────────────────────────────────────────────────────────

  List<Widget> _appTiles(List<ApplicationWithIcon> apps) {
    final tiles = <Widget>[];
    for (int i = 0; i < apps.length; i++) {
      tiles.add(_appTile(apps[i]));
      if (i < apps.length - 1) {
        tiles.add(const Divider(color: Colors.white12, height: 1));
      }
    }
    return tiles;
  }

  Widget _appTile(ApplicationWithIcon app) {
    return GestureDetector(
      onTap: () {
        setState(() {
          packageNameWithService = app.packageName;
          _showDisplays = true;
        });
      },
      child: SizedBox(
        height: _tileHeight,
        width: _panelWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  app.icon,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
