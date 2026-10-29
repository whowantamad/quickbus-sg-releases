import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<({
  List<Map<String, Object?>> meta,
  List<Map<String, Object?>> stops,
  List<Map<String, Object?>> services,
  List<Map<String, Object?>> routes,
})> loadLtaSqliteTables() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  }

  final dbDir = await getDatabasesPath();
  final dbPath = p.join(dbDir, 'sg_transit.db');
  final assetData = await rootBundle.load('assets/sg_transit.db');
  final assetBytes = assetData.buffer.asUint8List(
    assetData.offsetInBytes,
    assetData.lengthInBytes,
  );
  final assetUserVersion = assetBytes.length >= 64
      ? ByteData.sublistView(assetBytes, 60, 64).getInt32(0, Endian.big)
      : 0;

  final dbFile = File(dbPath);
  var needsCopy = !dbFile.existsSync();
  if (!needsCopy && assetUserVersion > 0) {
    try {
      final raf = dbFile.openSync(mode: FileMode.read);
      final header = raf.readSync(64);
      raf.closeSync();
      final localUserVersion = header.length >= 64
          ? ByteData.sublistView(header, 60, 64).getInt32(0, Endian.big)
          : -1;
      needsCopy = localUserVersion != assetUserVersion;
    } catch (_) {
      needsCopy = true;
    }
  }

  if (needsCopy) {
    Directory(dbDir).createSync(recursive: true);
    dbFile.writeAsBytesSync(assetBytes, flush: true);
  }

  final db = await openDatabase(dbPath, readOnly: true);
  try {
    final metaRows = await db.query('meta');
    final stopRows = await db.query('BusStops', orderBy: 'BusStopCode ASC');
    final svcRows = await db.query(
      'BusServices',
      orderBy: 'ServiceNo ASC, Direction ASC',
    );
    final routeRows = await db.query(
      'BusRoutes',
      orderBy: 'ServiceNo ASC, Direction ASC, StopSequence ASC',
    );
    return (
      meta: metaRows,
      stops: stopRows,
      services: svcRows,
      routes: routeRows,
    );
  } finally {
    await db.close();
  }
}

