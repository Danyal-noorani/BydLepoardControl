import 'dart:async';
import 'package:byd_display_switcher/services/device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _expanded = false;
  String packageNameWithService = "";

  static const _btnSize = 60.0;
  static const _panelWidth = 600.0;
  double _panelHeight = 250.0;
  List<AppInfo> _availableApps = const [];
  List<int> displayIds = const [];
  final _scrollController = ScrollController();

  final Map<int, AppInfo> _displayApps = {};
  final adb = SelfAdbService();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    adb.getDisplays().then(
      (value) => setState(() {
        displayIds = value;
      }),
    );
  }

  void _moveAppToDisplay(AppInfo app, int displayId) async {
    final out = await _sendAdbCommand(
      "dumpsys package ${app.packageName} | grep -A 1 'android.intent.action.MAIN'",
    );
    final activity = extractActivity(out);
    if (activity != null) {
      await _sendAdbCommand("am start --display $displayId -n $activity");
    }
  }

  String? extractActivity(String raw) {
    final match = RegExp(r'[\w.]+\/[\w.]+').firstMatch(raw);
    return match?.group(0);
  }

  Future<void> _toggleOverlay() async {
    if (_expanded) {
      setState(() {
        _expanded = false;
      });
      await FlutterOverlayWindow.resizeOverlay(
        _btnSize.toInt(),
        _btnSize.toInt(),
        true,
      );
    } else {
      await adb.getRunningApps().then(
        (value) => setState(() {
          _availableApps = value;
          _panelHeight = value.length <= 4 ? 480 : 630;
        }),
      );
      await FlutterOverlayWindow.resizeOverlay(
        _panelWidth.toInt(),
        _panelHeight.toInt(),
        false,
      );
      setState(() => _expanded = true);
    }
  }

  Future<String> _sendAdbCommand(String command) async {
    return await adb.run(command);
  }

  @override
  Widget build(BuildContext context) {
    final overlaySize = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleOverlay,
            child: Container(
              width: _btnSize,
              height: _btnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal,
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
              margin: const EdgeInsets.only(top: 0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 24,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: List.generate(displayIds.length, (index) {
                        return _displays(overlaySize, displayIds[index]);
                      }),
                    ),
                    SizedBox(
                      width: overlaySize.width,
                      height: _availableApps.length <= 4 ? 150 : 300,
                      child: GridView(
                        shrinkWrap: true,
                        physics: _availableApps.length <= 8
                            ? NeverScrollableScrollPhysics()
                            : BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 1,
                            ),
                        children: List.generate(_availableApps.length, (index) {
                          return _appTile(_availableApps[index], overlaySize);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _appTile(AppInfo app, Size overlaySize) {
    return LongPressDraggable(
      delay: Duration(milliseconds: 100),
      data: app,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.translate(
          offset: Offset(52, 52),
          child: Image.memory(app.iconBytes!, width: 52, height: 52),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.memory(app.iconBytes!, width: 52, height: 52),
          Text(
            app.appName!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _displays(Size overlaySize, int displayId) {
    return DragTarget<AppInfo>(
      onAcceptWithDetails: (details) {
        setState(() {
          _displayApps[displayId] = details.data;
        });
        _moveAppToDisplay(details.data, displayId);
      },
      builder: (context, candidateData, rejectedData) {
        final hovered = candidateData.isNotEmpty;
        return Container(
          height: 230,
          width: overlaySize.width / 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal, width: 4),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                if (hovered)
                  Image.memory(
                    candidateData[0]!.iconBytes!,
                    width: 52,
                    height: 52,
                  ),
                if (_displayApps[displayId] != null && !hovered)
                  Image.memory(
                    _displayApps[displayId]!.iconBytes!,
                    width: 52,
                    height: 52,
                  ),

                Text(
                  "Display $displayId",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
