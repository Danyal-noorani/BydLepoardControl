import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_adb/flutter_adb.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class SelfAdbEndpoint {
  final String host;
  final int port;
  const SelfAdbEndpoint(this.host, this.port);
  @override
  String toString() => '$host:$port';
}

class SelfAdbService {
  SelfAdbService._();
  static final SelfAdbService instance = SelfAdbService._();

  final NetworkInfo _networkInfo = NetworkInfo();

  AdbCrypto? _crypto;
  String? _wifiIp;
  SelfAdbEndpoint? _endpoint;
  AdbConnection? _connection;
  bool _adbReady = false;

  static const _keyName = 'flutter@car';

  Future<void> init() async {
    _wifiIp = await _networkInfo.getWifiIP();
    _crypto ??= await _loadOrCreateCrypto();
    if (_wifiIp != null) {
      log(_wifiIp!);
      _endpoint = SelfAdbEndpoint(_wifiIp!, 5555);
    }

    if (_endpoint == null) {
      throw StateError('No ADB endpoint found. Enable wireless debugging.');
    }

    await _ensureConnected();
  }

  Future<String> run(String command) async {
    if (!_adbReady) await init();

    try {
      return await _executeCommand(command);
    } catch (_) {
      // Connection dropped — reconnect once and retry
      _adbReady = false;
      await _ensureConnected();
      return await _executeCommand(command);
    }
  }

  Future<void> _ensureConnected() async {
    if (_adbReady && _connection != null && _connection!.connected) return;

    _connection = AdbConnection(_endpoint!.host, _endpoint!.port, _crypto!);
    _adbReady = await _connection!.connect();

    if (!_adbReady) {
      throw StateError('ADB connection failed to $_endpoint');
    }
  }

  Future<String> _executeCommand(String command) async {
    final cmd = '$command;exit\n';
    final stream = await _connection!.openShell();
    await stream.writeString(cmd);
    String output = await stream.onPayload
        .fold('', (prev, el) => prev + utf8.decode(el))
        .timeout(
          const Duration(minutes: 1),
          onTimeout: () {
            stream.close();
            return '';
          },
        );
    output = output.replaceAll('\r', '');
    if (output.endsWith('\n')) output = output.substring(0, output.length - 1);
    return output.split(cmd).last.trim();
  }

  Future<AdbCrypto> _loadOrCreateCrypto() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/adb_key.json');
    if (await file.exists()) {
      try {
        final map = Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()),
        );
        final keyPair = AdbCrypto.keyPairFromStorageMap(map);
        return AdbCrypto(keyPair: keyPair, adbKeyName: _keyName);
      } catch (_) {
        // Corrupted key file — regenerate below
      }
    }
    final crypto = AdbCrypto(adbKeyName: _keyName);
    await file.writeAsString(jsonEncode(crypto.exportKeyPairForStorage()));
    return crypto;
  }
}
