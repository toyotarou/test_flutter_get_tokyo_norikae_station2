import '../models/calculated_route_model.dart';
import '../models/route_segment_model.dart';
import '../models/tokyo_train_model.dart';
import '../models/transfer_step_model.dart';

/// 駅名などの文字列を正規化する関数。
/// - 全角スペースを半角スペースに揃え
/// - 前後のスペースを削除
/// - 小文字化
/// して、「駅名の表記ゆれ」をできるだけ吸収している。
String stringModifier({required String name}) {
  return name.replaceAll('　', ' ').trim().toLowerCase();
}

/// 路線名が JR 系かどうかを判定する関数。
/// - normalize した文字列からスペースを除去
/// - "ｊｒ" も "jr" とみなす簡易変換
/// - "jr" を含んでいたら JR とみなす
///
/// ここで true になった路線は、allowJR=false のときに除外される。
bool _isJRLine({required String lineName}) {
  // ざっくり全角→半角に寄せて "jr" を検出する
  final String n = stringModifier(name: lineName).replaceAll(' ', '').replaceAll('jr', 'jr').replaceAll('ｊｒ', 'jr');
  return n.contains('jr');
}

/// 路線・駅の検索を高速化するためのインデックスクラス。
///
/// 内部的には：
/// - stationToLineAndIdx: 駅名(正規化) → (路線名, その路線内のインデックス) のセット
/// - lineGraph: 路線名 → (隣接路線名 → 共通駅の集合)
/// - lineToStationIndex: 路線名 → (駅名(正規化) → その路線内のインデックス)
///
/// という3種類のインデックスを持っている。
class NetworkIndex {
  NetworkIndex(this.tokyoTrainModelList) {
    // 1) 各路線ごとに、駅のインデックス情報を構築
    for (final TokyoTrainModel line in tokyoTrainModelList) {
      final Map<String, int> idxMap = <String, int>{};

      for (int i = 0; i < line.station.length; i++) {
        final String norm = stringModifier(name: line.station[i].stationName);

        // 路線内インデックスを保存
        idxMap[norm] = i;

        // 駅名(正規化) → (路線名, インデックス) のセットを構築
        stationToLineAndIdx.putIfAbsent(norm, () => <(String, int)>{}).add((line.trainName, i));
      }

      // 路線名 → (駅名(正規化) → インデックス) のマップを保存
      lineToStationIndex[line.trainName] = idxMap;
    }

    // 2) 路線同士の「乗り換え可能関係」のグラフを構築
    //    ＝ 共通駅を持つ路線同士を隣接とみなし、その共通駅名の集合を持たせる
    for (final TokyoTrainModel a in tokyoTrainModelList) {
      // 路線aに含まれる駅名(正規化)のセット
      final Set<String> aSet = a.station.map((TokyoStationModel s) => stringModifier(name: s.stationName)).toSet();

      for (final TokyoTrainModel b in tokyoTrainModelList) {
        if (identical(a, b)) {
          continue; // 同一路線同士はスキップ
        }

        final Set<String> shared = <String>{};

        // 路線bの各駅が路線aにも存在するかどうかチェックし、
        // 共通している駅名を shared に追加
        for (final TokyoStationModel st in b.station) {
          if (aSet.contains(stringModifier(name: st.stationName))) {
            shared.add(st.stationName);
          }
        }

        // 共通駅が1つでもあれば「乗り換え可能な路線同士」として lineGraph に登録
        if (shared.isNotEmpty) {
          lineGraph.putIfAbsent(a.trainName, () => <String, Set<String>>{});
          lineGraph[a.trainName]![b.trainName] = shared;
        }
      }
    }
  }

  /// このインデックスが対象としている路線一覧
  final List<TokyoTrainModel> tokyoTrainModelList;

  /// 駅名(正規化) → その駅が存在する (路線名, 路線内インデックス) のセット
  /// 例: "四ツ谷" → { ("JR中央線", 5), ("東京メトロ丸ノ内線", 3), ... }
  final Map<String, Set<(String, int)>> stationToLineAndIdx = <String, Set<(String, int)>>{};

  /// 路線名 → (隣接路線名 → 共通駅の集合)
  /// 例: "東京メトロ南北線" → { "東京メトロ丸ノ内線" : {"四ツ谷"}, ... }
  final Map<String, Map<String, Set<String>>> lineGraph = <String, Map<String, Set<String>>>{};

  /// 路線名 → (駅名(正規化) → 路線内インデックス)
  /// 例: "東京メトロ丸ノ内線" → { "荻窪":0, "南阿佐ケ谷":1, ... }
  final Map<String, Map<String, int>> lineToStationIndex = <String, Map<String, int>>{};

  /// 指定した駅名（生文字列）に対して、
  /// その駅を含む路線とインデックスの候補セットを返す。
  ///
  /// 例: "四ツ谷" → { ("JR中央線", 10), ("東京メトロ丸ノ内線", 5), ... }
  Set<(String lineName, int idx)> candidateLinesByStation({required String name}) =>
      stationToLineAndIdx[stringModifier(name: name)] ?? <(String, int)>{};
}

/// 路線グラフに対して BFS（幅優先探索）を行い、
/// 「スタート路線集合 → ゴール路線集合」までの **最小乗り換え数** の路線パスを求める。
///
/// - start: 出発駅が属している路線たち
/// - goal:  到着駅が属している路線たち
/// 戻り値:
/// - 例: ["東京メトロ南北線", "東京メトロ丸ノ内線"] のような路線名リスト
List<String>? bfsLines({required NetworkIndex idx, required Set<String> start, required Set<String> goal}) {
  // もし「スタートの時点でゴール路線に含まれている」なら、乗り換え0本で OK
  if (start.any(goal.contains)) {
    return <String>[start.firstWhere(goal.contains)];
  }

  // 通常の BFS 用ワーク変数
  final List<String> queue = <String>[]; // 探索キュー
  final Map<String, String?> prev = <String, String?>{}; // 経路復元用：各路線の直前の路線
  final Set<String> visited = <String>{}; // 訪問済路線

  // スタート路線を BFS の起点として登録
  for (final String s in start) {
    queue.add(s);
    prev[s] = null;
    visited.add(s);
  }

  while (queue.isNotEmpty) {
    final String u = queue.removeAt(0); // 先頭を取り出し
    final Map<String, Set<String>> neigh = idx.lineGraph[u] ?? <String, Set<String>>{};

    // u から乗り換え可能な隣接路線 v を1本ずつ見る
    for (final String v in neigh.keys) {
      if (visited.contains(v)) {
        continue;
      }
      visited.add(v);
      prev[v] = u;

      // ゴール路線集合に含まれていたら経路確定
      if (goal.contains(v)) {
        final List<String> path = <String>[];
        String? cur = v;
        while (cur != null) {
          path.add(cur);
          cur = prev[cur];
        }
        // 復元した経路は「ゴール→スタート」の逆順なので、反転して返す
        return path.reversed.toList();
      }

      // まだゴールでなければ BFS 続行
      queue.add(v);
    }
  }

  // 探索してもゴール路線にたどり着けなかった場合は null
  return null;
}

/// 路線内での駅リストの切り出し。
/// fromIndex と toIndex の間の駅を順番にリストとして返す。
///
/// - a <= b の場合 : [a, a+1, ..., b]
/// - a >  b の場合 : [a, a-1, ..., b]（駅の順も反転して返す）
List<String> sliceStations({required List<TokyoStationModel> list, required int a, required int b}) {
  if (a <= b) {
    return list.sublist(a, b + 1).map((TokyoStationModel s) => s.stationName).toList();
  }
  return list.sublist(b, a + 1).reversed.map((TokyoStationModel s) => s.stationName).toList();
}

/// 2つの路線 lineA / lineB の間で「共通駅」が複数あるときに、
/// どの駅で乗り換えるのが「都合が良さそうか」を評価して1つ選ぶ関数。
///
/// nearA / nearB には「その路線上で近くにありそうなインデックス」が入る想定で、
/// そこからの距離（インデックス差）をスコアとして、
/// 合計距離が最小となる駅を best として返す。
String pickSharedStation({
  required NetworkIndex idx,
  required String lineA,
  required String lineB,
  (String, int)? nearA,
  (String, int)? nearB,
}) {
  // lineA と lineB の共通駅の集合
  final Set<String> shared = idx.lineGraph[lineA]![lineB]!;

  // 探索用のベスト候補
  String best = shared.first;
  int bestScore = 1 << 30; // 十分大きい数で初期化

  for (final String s in shared) {
    final String n = stringModifier(name: s);

    // lineA / lineB の中でのインデックス
    final int ai = idx.lineToStationIndex[lineA]![n]!;
    final int bi = idx.lineToStationIndex[lineB]![n]!;

    // nearA / nearB から何駅離れているか（インデックス差の絶対値）
    final int da = nearA == null ? 0 : (ai - nearA.$2).abs();
    final int db = nearB == null ? 0 : (bi - nearB.$2).abs();

    // 合計距離が一番小さい駅を採用
    if (da + db < bestScore) {
      bestScore = da + db;
      best = s;
    }
  }
  return best;
}

/// 乗り換え経路を計算するメイン関数。
///
/// - allLines : すべての路線データ（APIから取得したもの）
/// - origin   : 出発駅名
/// - destination : 到着駅名
/// - allowJR  : JR を使うかどうか（false のときは JR 路線を完全に除外）
///
/// 戻り値:
/// - 見つかった場合 : CalculatedRouteModel（経路全体＋乗り換え情報）
/// - 見つからない場合: null
CalculatedRouteModel? routeFinder({
  required List<TokyoTrainModel> tokyoTrainModelList,
  required String origin,
  required String destination,
  required bool allowJR,
}) {
  // 1) JR 利用可否に応じて路線一覧をフィルタリング
  final List<TokyoTrainModel> lines = allowJR
      ? tokyoTrainModelList
      : tokyoTrainModelList.where((TokyoTrainModel l) => !_isJRLine(lineName: l.trainName)).toList();

  // 2) インデックス構築
  final NetworkIndex idx = NetworkIndex(lines);

  // 出発駅 / 到着駅 が属する (路線名, 路線内インデックス) の候補を取得
  final Set<(String, int)> fromC = idx.candidateLinesByStation(name: origin);
  final Set<(String, int)> toC = idx.candidateLinesByStation(name: destination);

  // どちらかの駅が1本もヒットしなければ経路なし
  if (fromC.isEmpty || toC.isEmpty) {
    return null;
  }

  // 出発駅が属する「路線の集合」
  final Set<String> start = fromC.map(((String, int) e) => e.$1).toSet();

  // 到着駅が属する「路線の集合」
  final Set<String> goal = toC.map(((String, int) e) => e.$1).toSet();

  // 3) 路線グラフ上で「最小乗り換えの路線列」を BFS で探索
  final List<String>? linePath = bfsLines(idx: idx, start: start, goal: goal);
  if (linePath == null) {
    return null; // どの路線の組み合わせでも目的地に届かなかった
  }

  // 4) 路線列 linePath に沿って、実際の駅区間（RouteSegment）と乗り換え情報(TransferStep) を組み立てる
  final List<RouteSegmentModel> seg = <RouteSegmentModel>[];
  final List<TransferStepModel> trans = <TransferStepModel>[];

  // 現在位置: (路線名, 路線内インデックス)
  (String, int)? cur = fromC.first; // とりあえず最初の候補を採用（必要なら優先規則を追加可）

  for (int i = 0; i < linePath.length; i++) {
    final String lineName = linePath[i];
    final TokyoTrainModel line = lines.firstWhere((TokyoTrainModel l) => l.trainName == lineName);

    // ■ ケース1: 乗り換えなしで完結する場合（linePathが1本だけ）
    if (i == 0 && linePath.length == 1) {
      // 到着駅がこの路線上のどこにあるかを取得（複数候補があればインデックスが小さいものを使用）
      final List<int> destIdx = toC.where(((String, int) e) => e.$1 == lineName).map(((String, int) e) => e.$2).toList()
        ..sort();

      // 出発駅から到着駅までの駅リストを切り出す
      final List<String> pass = sliceStations(list: line.station, a: cur!.$2, b: destIdx.first);

      seg.add(RouteSegmentModel(lineName: lineName, fromStation: pass.first, toStation: pass.last, passStations: pass));
      break;
    }

    // ■ ケース2: まだ次の路線がある（＝この路線からどこかで乗り換える必要がある）
    if (i < linePath.length - 1) {
      final String nextLine = linePath[i + 1];
      final TokyoTrainModel nextL = lines.firstWhere((TokyoTrainModel l) => l.trainName == nextLine);

      // lineName → nextLine の間で、どの共通駅で乗り換えるかを決める
      final String transAt = pickSharedStation(idx: idx, lineA: lineName, lineB: nextLine, nearA: cur);

      // 「今の路線(lineName)上での乗換駅のインデックス」を取得
      final int tIdxA = idx.lineToStationIndex[lineName]![stringModifier(name: transAt)]!;

      // 出発側の区間: 現在位置(cur) から 乗換駅(transAt) までの駅リスト
      final List<String> passA = sliceStations(list: line.station, a: cur!.$2, b: tIdxA);

      seg.add(
        RouteSegmentModel(lineName: lineName, fromStation: passA.first, toStation: passA.last, passStations: passA),
      );

      // 乗り換え情報を追加
      trans.add(TransferStepModel(atStation: transAt, fromLine: lineName, toLine: nextLine));

      // 次の路線(nextLine)上での「乗換駅のインデックス」へ位置を移動
      final int tIdxB = idx.lineToStationIndex[nextLine]![stringModifier(name: transAt)]!;
      cur = (nextLine, tIdxB);

      // ■ linePath の最後の路線に乗り換えた直後なら、
      //    そこから最終目的地までの区間もまとめて作る。
      if (i + 1 == linePath.length - 1) {
        final List<int> destIdx =
            toC.where(((String, int) e) => e.$1 == nextLine).map(((String, int) e) => e.$2).toList()..sort();

        // 乗換駅から到着駅までの駅リスト
        final List<String> passB = sliceStations(list: nextL.station, a: cur.$2, b: destIdx.first);

        seg.add(
          RouteSegmentModel(lineName: nextLine, fromStation: passB.first, toStation: passB.last, passStations: passB),
        );
      }
    }
  }

  // 5) 最終的なルートモデルを組み立てて返す
  return CalculatedRouteModel(
    origin: origin,
    destination: destination,
    segments: seg,
    transfers: trans,
    transferCount: trans.length,
  );
}
