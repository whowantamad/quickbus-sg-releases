import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

Future<({
  List<Map<String, Object?>> meta,
  List<Map<String, Object?>> stops,
  List<Map<String, Object?>> services,
  List<Map<String, Object?>> routes,
})> loadLtaSqliteTables() async {
  final assetData = await rootBundle.load('assets/sg_transit.db');
  final bytes = assetData.buffer.asUint8List(
    assetData.offsetInBytes,
    assetData.lengthInBytes,
  );
  final reader = _SqliteBTreeReader(bytes);

  final schemaRows = reader.scanTable(1);
  final rootPages = <String, int>{};
  for (final r in schemaRows) {
    if (r.length >= 4 && r[0] == 'table' && r[1] is String && r[3] is int) {
      rootPages[r[1] as String] = r[3] as int;
    }
  }

  final metaRaw = rootPages['meta'] != null
      ? reader.scanTable(rootPages['meta']!)
      : const <List<Object?>>[];
  final stopsRaw = rootPages['BusStops'] != null
      ? reader.scanTable(rootPages['BusStops']!)
      : const <List<Object?>>[];
  final servicesRaw = rootPages['BusServices'] != null
      ? reader.scanTable(rootPages['BusServices']!)
      : const <List<Object?>>[];
  final routesRaw = rootPages['BusRoutes'] != null
      ? reader.scanTable(rootPages['BusRoutes']!)
      : const <List<Object?>>[];

  final meta = metaRaw
      .where((r) => r.length >= 2)
      .map((r) => <String, Object?>{'key': r[0], 'value': r[1]})
      .toList();

  final stops = stopsRaw
      .where((r) => r.length >= 5)
      .map((r) => <String, Object?>{
            'BusStopCode': r[0],
            'RoadName': r[1],
            'Description': r[2],
            'Latitude': r[3],
            'Longitude': r[4],
          })
      .toList()
    ..sort((a, b) =>
        (a['BusStopCode'] as String).compareTo(b['BusStopCode'] as String));

  final services = servicesRaw
      .where((r) => r.length >= 11)
      .map((r) => <String, Object?>{
            'ServiceNo': r[0],
            'Operator': r[1],
            'Direction': r[2],
            'Category': r[3],
            'OriginCode': r[4],
            'DestinationCode': r[5],
            'AM_Peak_Freq': r[6],
            'AM_OffPeak_Freq': r[7],
            'PM_Peak_Freq': r[8],
            'PM_OffPeak_Freq': r[9],
            'LoopDesc': r[10],
          })
      .toList()
    ..sort((a, b) {
      final sa = a['ServiceNo'] as String;
      final sb = b['ServiceNo'] as String;
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      return (a['Direction'] as int).compareTo(b['Direction'] as int);
    });

  final routes = routesRaw
      .where((r) => r.length >= 12)
      .map((r) => <String, Object?>{
            'ServiceNo': r[0],
            'Operator': r[1],
            'Direction': r[2],
            'StopSequence': r[3],
            'BusStopCode': r[4],
            'Distance': r[5],
            'WD_FirstBus': r[6],
            'WD_LastBus': r[7],
            'SAT_FirstBus': r[8],
            'SAT_LastBus': r[9],
            'SUN_FirstBus': r[10],
            'SUN_LastBus': r[11],
          })
      .toList()
    ..sort((a, b) {
      final sa = a['ServiceNo'] as String;
      final sb = b['ServiceNo'] as String;
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      final da = a['Direction'] as int;
      final db = b['Direction'] as int;
      if (da != db) return da.compareTo(db);
      return (a['StopSequence'] as int).compareTo(b['StopSequence'] as int);
    });

  return (
    meta: meta,
    stops: stops,
    services: services,
    routes: routes,
  );
}

class _SqliteBTreeReader {
  final Uint8List bytes;
  final ByteData view;
  late final int pageSize;

  _SqliteBTreeReader(this.bytes) : view = ByteData.sublistView(bytes) {
    final rawSize = view.getUint16(16, Endian.big);
    pageSize = rawSize == 1 ? 65536 : rawSize;
  }

  List<List<Object?>> scanTable(int rootPage) {
    final rows = <List<Object?>>[];
    _visitPage(rootPage, rows);
    return rows;
  }

  void _visitPage(int pageNumber, List<List<Object?>> out) {
    if (pageNumber <= 0) return;
    final pageStart = (pageNumber - 1) * pageSize;
    if (pageStart >= bytes.length) return;
    final hdrOffset = pageNumber == 1 ? 100 : 0;
    final hdrPos = pageStart + hdrOffset;
    final pageType = bytes[hdrPos];
    final cellCount = view.getUint16(hdrPos + 3, Endian.big);

    if (pageType == 0x05) {
      // Interior table B-tree page
      final rightMostPage = view.getUint32(hdrPos + 8, Endian.big);
      final ptrTablePos = hdrPos + 12;
      for (var i = 0; i < cellCount; i++) {
        final cellOffset = view.getUint16(ptrTablePos + i * 2, Endian.big);
        final leftChild = view.getUint32(pageStart + cellOffset, Endian.big);
        _visitPage(leftChild, out);
      }
      _visitPage(rightMostPage, out);
    } else if (pageType == 0x0d) {
      // Leaf table B-tree page
      final ptrTablePos = hdrPos + 8;
      for (var i = 0; i < cellCount; i++) {
        final cellOffset = view.getUint16(ptrTablePos + i * 2, Endian.big);
        var pos = pageStart + cellOffset;
        final payloadVar = _readVarint(pos);
        pos = payloadVar.nextPos;
        final rowidVar = _readVarint(pos);
        pos = rowidVar.nextPos;
        out.add(_decodeRecord(pos, payloadVar.value));
      }
    }
  }

  List<Object?> _decodeRecord(int recordStart, int payloadLen) {
    final hdrVar = _readVarint(recordStart);
    final hdrEnd = recordStart + hdrVar.value;
    var hdrPos = hdrVar.nextPos;
    final serialTypes = <int>[];
    while (hdrPos < hdrEnd) {
      final st = _readVarint(hdrPos);
      serialTypes.add(st.value);
      hdrPos = st.nextPos;
    }

    var bodyPos = hdrEnd;
    final values = <Object?>[];
    for (final st in serialTypes) {
      if (st == 0) {
        values.add(null);
      } else if (st == 1) {
        values.add(view.getInt8(bodyPos));
        bodyPos += 1;
      } else if (st == 2) {
        values.add(view.getInt16(bodyPos, Endian.big));
        bodyPos += 2;
      } else if (st == 3) {
        var v = (bytes[bodyPos] << 16) |
            (bytes[bodyPos + 1] << 8) |
            bytes[bodyPos + 2];
        if ((v & 0x800000) != 0) v -= 0x1000000;
        values.add(v);
        bodyPos += 3;
      } else if (st == 4) {
        values.add(view.getInt32(bodyPos, Endian.big));
        bodyPos += 4;
      } else if (st == 5) {
        var hi = view.getInt16(bodyPos, Endian.big);
        var lo = view.getUint32(bodyPos + 2, Endian.big);
        values.add((hi * 4294967296) + lo);
        bodyPos += 6;
      } else if (st == 6) {
        final hi = view.getInt32(bodyPos, Endian.big);
        final lo = view.getUint32(bodyPos + 4, Endian.big);
        values.add((hi * 4294967296) + lo);
        bodyPos += 8;
      } else if (st == 7) {
        values.add(view.getFloat64(bodyPos, Endian.big));
        bodyPos += 8;
      } else if (st == 8) {
        values.add(0);
      } else if (st == 9) {
        values.add(1);
      } else if (st >= 12 && st.isEven) {
        final len = (st - 12) ~/ 2;
        values.add(bytes.sublist(bodyPos, bodyPos + len));
        bodyPos += len;
      } else if (st >= 13 && st.isOdd) {
        final len = (st - 13) ~/ 2;
        values.add(
          utf8.decode(
            bytes.sublist(bodyPos, bodyPos + len),
            allowMalformed: true,
          ),
        );
        bodyPos += len;
      }
    }
    return values;
  }

  ({int value, int nextPos}) _readVarint(int start) {
    var result = 0;
    for (var i = 0; i < 8; i++) {
      final b = bytes[start + i];
      result = (result << 7) | (b & 0x7f);
      if ((b & 0x80) == 0) {
        return (value: result, nextPos: start + i + 1);
      }
    }
    final b8 = bytes[start + 8];
    result = (result << 8) | b8;
    return (value: result, nextPos: start + 9);
  }
}

