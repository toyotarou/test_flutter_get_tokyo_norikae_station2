import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calculated_route_model.dart';
import '../models/line_model.dart';
import '../models/route_segment_model.dart';
import '../models/station_model.dart';
import '../models/transfer_step_model.dart';

// ///
// Future<List<LineModel>> fetchLines() async {
//   const String url = 'http://toyohide.work/BrainLog/api/getTokyoTrainStation';
//   final http.Response resp = await http.post(
//     Uri.parse(url),
//     headers: <String, String>{'Content-Type': 'application/json'},
//   );
//
//   if (resp.statusCode != 200) {
//     throw Exception('APIエラー: ${resp.statusCode}');
//   }
//
//   final Map<String, dynamic> root = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
//   // ignore: always_specify_types
//   final List<Map<String, dynamic>> list = (root['data'] as List).cast<Map<String, dynamic>>();
//
//   return list.map((Map<String, dynamic> m) {
//     final int trainNumber = (m['train_number'] as num).toInt();
//     final String name = m['train_name'] as String;
//     // ignore: always_specify_types
//     final List<Map<String, dynamic>> stationsJson = (m['station'] as List).cast<Map<String, dynamic>>();
//     final List<StationModel> stations = stationsJson.map((Map<String, dynamic> s) {
//       return StationModel(
//         id: s['id'] as String,
//         name: s['station_name'] as String,
//         lat: (s['lat'] as num).toDouble(),
//         lng: (s['lng'] as num).toDouble(),
//       );
//     }).toList();
//     return LineModel(trainNumber: trainNumber, name: name, stations: stations);
//   }).toList();
// }
//
//
//





/// ===========================
/// 経路計算ロジック
/// ===========================

///
String _norm(String s) => s.replaceAll('　', ' ').trim().toLowerCase();

///
bool _isJRLine(String lineName) {
  // 全角/半角・大文字小文字・空白を無視して "JR" or "ＪＲ" を検出
  final String n = _norm(lineName).replaceAll(' ', '').replaceAll('jr', 'jr').replaceAll('ｊｒ', 'jr'); // ざっくり全角→半角
  return n.contains('jr');
}

///
class NetworkIndex {
  NetworkIndex(this.lines) {
    for (final LineModel line in lines) {
      final Map<String, int> idxMap = <String, int>{};
      for (int i = 0; i < line.stations.length; i++) {
        final String norm = _norm(line.stations[i].name);
        idxMap[norm] = i;
        stationToLineAndIdx.putIfAbsent(norm, () => <(String, int)>{}).add((line.name, i));
      }
      lineToStationIndex[line.name] = idxMap;
    }

    for (final LineModel a in lines) {
      final Set<String> aSet = a.stations.map((StationModel s) => _norm(s.name)).toSet();
      for (final LineModel b in lines) {
        if (identical(a, b)) {
          continue;
        }
        final Set<String> shared = <String>{};
        for (final StationModel st in b.stations) {
          if (aSet.contains(_norm(st.name))) {
            shared.add(st.name);
          }
        }
        if (shared.isNotEmpty) {
          lineGraph.putIfAbsent(a.name, () => <String, Set<String>>{});
          lineGraph[a.name]![b.name] = shared;
        }
      }
    }
  }

  final List<LineModel> lines;
  final Map<String, Set<(String, int)>> stationToLineAndIdx = <String, Set<(String, int)>>{};
  final Map<String, Map<String, Set<String>>> lineGraph = <String, Map<String, Set<String>>>{};
  final Map<String, Map<String, int>> lineToStationIndex = <String, Map<String, int>>{};

  Set<(String lineName, int idx)> candidateLinesByStation(String name) =>
      stationToLineAndIdx[_norm(name)] ?? <(String, int)>{};
}

///
List<String>? _bfsLines(NetworkIndex idx, Set<String> start, Set<String> goal) {
  if (start.any(goal.contains)) {
    return <String>[start.firstWhere(goal.contains)];
  }
  final List<String> queue = <String>[];
  final Map<String, String?> prev = <String, String?>{};
  final Set<String> visited = <String>{};
  for (final String s in start) {
    queue.add(s);
    prev[s] = null;
    visited.add(s);
  }

  while (queue.isNotEmpty) {
    final String u = queue.removeAt(0);
    final Map<String, Set<String>> neigh = idx.lineGraph[u] ?? <String, Set<String>>{};
    for (final String v in neigh.keys) {
      if (visited.contains(v)) {
        continue;
      }
      visited.add(v);
      prev[v] = u;
      if (goal.contains(v)) {
        final List<String> path = <String>[];
        String? cur = v;
        while (cur != null) {
          path.add(cur);
          cur = prev[cur];
        }
        return path.reversed.toList();
      }
      queue.add(v);
    }
  }
  return null;
}

///
List<String> _sliceStations(List<StationModel> list, int a, int b) {
  if (a <= b) {
    return list.sublist(a, b + 1).map((StationModel s) => s.name).toList();
  }
  return list.sublist(b, a + 1).reversed.map((StationModel s) => s.name).toList();
}

///
String _pickSharedStation(NetworkIndex idx, String lineA, String lineB, (String, int)? nearA, (String, int)? nearB) {
  final Set<String> shared = idx.lineGraph[lineA]![lineB]!;
  String best = shared.first;
  int bestScore = 1 << 30;
  for (final String s in shared) {
    final String n = _norm(s);
    final int ai = idx.lineToStationIndex[lineA]![n]!;
    final int bi = idx.lineToStationIndex[lineB]![n]!;
    final int da = nearA == null ? 0 : (ai - nearA.$2).abs();
    final int db = nearB == null ? 0 : (bi - nearB.$2).abs();
    if (da + db < bestScore) {
      bestScore = da + db;
      best = s;
    }
  }
  return best;
}

///
CalculatedRouteModel? findRoute({
  required List<LineModel> allLines,
  required String origin,
  required String destination,
  required bool allowJR,
}) {
  // JR利用可否で路線をフィルタ
  final List<LineModel> lines = allowJR ? allLines : allLines.where((LineModel l) => !_isJRLine(l.name)).toList();

  final NetworkIndex idx = NetworkIndex(lines);
  final Set<(String, int)> fromC = idx.candidateLinesByStation(origin);
  final Set<(String, int)> toC = idx.candidateLinesByStation(destination);
  if (fromC.isEmpty || toC.isEmpty) {
    return null;
  }

  final Set<String> start = fromC.map(((String, int) e) => e.$1).toSet();
  final Set<String> goal = toC.map(((String, int) e) => e.$1).toSet();
  final List<String>? linePath = _bfsLines(idx, start, goal);
  if (linePath == null) {
    return null;
  }

  final List<RouteSegmentModel> seg = <RouteSegmentModel>[];
  final List<TransferStepModel> trans = <TransferStepModel>[];

  // 出発駅の最初の候補を採用（必要なら選好ロジックを追加可）
  (String, int)? cur = fromC.first;

  for (int i = 0; i < linePath.length; i++) {
    final String lineName = linePath[i];
    final LineModel line = lines.firstWhere((LineModel l) => l.name == lineName);

    // 乗換なし完結
    if (i == 0 && linePath.length == 1) {
      final List<int> destIdx = toC.where(((String, int) e) => e.$1 == lineName).map(((String, int) e) => e.$2).toList()
        ..sort();
      final List<String> pass = _sliceStations(line.stations, cur!.$2, destIdx.first);
      seg.add(RouteSegmentModel(lineName: lineName, fromStation: pass.first, toStation: pass.last, passStations: pass));
      break;
    }

    if (i < linePath.length - 1) {
      final String nextLine = linePath[i + 1];
      final LineModel nextL = lines.firstWhere((LineModel l) => l.name == nextLine);

      final String transAt = _pickSharedStation(idx, lineName, nextLine, cur, null);

      final int tIdxA = idx.lineToStationIndex[lineName]![_norm(transAt)]!;
      final List<String> passA = _sliceStations(line.stations, cur!.$2, tIdxA);
      seg.add(
        RouteSegmentModel(lineName: lineName, fromStation: passA.first, toStation: passA.last, passStations: passA),
      );
      trans.add(TransferStepModel(atStation: transAt, fromLine: lineName, toLine: nextLine));

      final int tIdxB = idx.lineToStationIndex[nextLine]![_norm(transAt)]!;
      cur = (nextLine, tIdxB);

      if (i + 1 == linePath.length - 1) {
        final List<int> destIdx =
            toC.where(((String, int) e) => e.$1 == nextLine).map(((String, int) e) => e.$2).toList()..sort();
        final List<String> passB = _sliceStations(nextL.stations, cur.$2, destIdx.first);
        seg.add(
          RouteSegmentModel(lineName: nextLine, fromStation: passB.first, toStation: passB.last, passStations: passB),
        );
      }
    }
  }

  return CalculatedRouteModel(
    origin: origin,
    destination: destination,
    segments: seg,
    transfers: trans,
    transferCount: trans.length,
  );
}
