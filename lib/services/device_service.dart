import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_adb/flutter_adb.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:network_info_plus/network_info_plus.dart';

class SelfAdbService {
  static final SelfAdbService _instance = SelfAdbService._internal();

  factory SelfAdbService() => _instance;

  SelfAdbService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();
  final _keyName = 'byd_display_switcher@dart';

  String? wifiIp;
  AdbConnection? _connection;
  bool _adbReady = false;
  final _port = 5555;
  String adbError = "No Error";

  AdbCrypto? crypto;

  Future<void> init() async {
    wifiIp = "127.0.0.1";
    crypto = AdbCrypto(adbKeyName: _keyName);
    // crypto = await _loadOrCreateCrypto();
    // log(crypto!.exportKeyPairForStorage().toString());
    await _ensureConnected();
  }

  Future<List<int>> getDisplays() async {
    final out = await run(
      "dumpsys display | grep 'mDisplayId' | grep -o '[0-9]*' | sort -u",
    );
    if (out.isEmpty) return [];
    return out.split('\n').map((e) => int.parse(e)).toList();
  }

  Future<List<AppInfo>> getRunningApps() async {
    final out = await run(
      "ps -A | grep u[0-9999]_a | awk '{print \$NF}' | sort -u | while read p; do dumpsys package \$p 2>/dev/null | grep -q 'android.intent.category.LAUNCHER' && echo \$p; done",
    );
    final packages = out
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final results = await Future.wait(
      packages.map((pkg) => FlutterDeviceApps.getApp(pkg, includeIcon: true)),
    );
    return results.whereType<AppInfo>().toList();
  }

  Future<String> run(String command) async {
    if (!_adbReady) await init();

    try {
      return await _executeCommand(command);
    } catch (_) {
      // Connection dropped — reconnect once and retry
      _adbReady = false;
      await _ensureConnected();
      if (!_adbReady) return '';
      return await _executeCommand(command);
    }
  }

  Future<void> _ensureConnected() async {
    if (_adbReady && _connection != null && _connection!.connected) return;

    _connection = AdbConnection(wifiIp ?? "", _port, crypto!);
    _adbReady = await _connection!.connect();

    if (!_adbReady) {
      if (wifiIp == "127.0.0.1") {
        wifiIp = await _networkInfo.getWifiIP();
        _ensureConnected();
        return;
      } else {
        adbError = "ADB connection failed to ADB";
      }
    }
  }

  Future<String> _executeCommand(String command) async {
    final cmd = '$command;exit\n';
    final stream = await _connection!.openShell();
    await stream.writeString(cmd);
    String output = await stream.onPayload
        .fold('', (prev, el) => prev + utf8.decode(el))
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            stream.close();
            return '';
          },
        );
    output = output.replaceAll('\r', '');
    output = output.split("exit").last;
    if (output.endsWith('\n')) output = output.substring(0, output.length - 1);
    return output.split(cmd).last.trim();
  }

  Future<AdbCrypto> _loadOrCreateCrypto() async {
    final _secureStorage = FlutterSecureStorage();
    final _cryptoStorageKey = "adb_key";
    final stored = await _secureStorage.read(key: _cryptoStorageKey);
    if (stored != null && stored.isNotEmpty) {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final adbKeyName = decoded['adbKeyName'] as String? ?? _keyName;
      final keyPair = AdbCrypto.keyPairFromStorageMap(
        decoded['keyPair'] as Map<String, dynamic>,
      );
      return AdbCrypto(keyPair: keyPair, adbKeyName: adbKeyName);
    }

    final crypto = AdbCrypto(adbKeyName: _keyName);
    await _secureStorage.write(
      key: _cryptoStorageKey,
      value: jsonEncode(<String, dynamic>{
        'adbKeyName': crypto.adbKeyName,
        'keyPair': crypto.exportKeyPairForStorage(),
      }),
    );
    return crypto;
  }
}
