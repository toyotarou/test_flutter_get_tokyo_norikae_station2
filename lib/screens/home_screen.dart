import 'package:flutter/material.dart';

import '../models/calculated_route_model.dart';
import '../models/line_model.dart';
import '../models/route_segment_model.dart';
import '../models/station_model.dart';
import '../models/transfer_step_model.dart';
import '../utility/functions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.lineModelList});

  final List<LineModel> lineModelList;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<LineModel> _allLines;
  late List<String> _stationNames;

  final TextEditingController fromCtl = TextEditingController();
  final TextEditingController toCtl = TextEditingController();

  bool _allowJR = true;

  CalculatedRouteModel? result;
  String? error;

  ///
  @override
  void initState() {
    super.initState();

    _allLines = widget.lineModelList;
    _stationNames = <String>{
      for (final LineModel ln in _allLines) ...ln.stations.map((StationModel s) => s.name),
    }.toList()..sort();
  }

  ///
  void _search() {
    setState(() {
      error = null;
      result = null;
    });

    final String from = fromCtl.text.trim();
    final String to = toCtl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      setState(() => error = '出発駅と到着駅を入力してください');
      return;
    }

    final CalculatedRouteModel? r = findRoute(allLines: _allLines, origin: from, destination: to, allowJR: _allowJR);

    if (r == null) {
      final String jrMsg = _allowJR ? '' : '（JR除外中のため経路が無い可能性があります）';
      setState(() => error = '経路が見つかりませんでした $jrMsg');
    } else {
      setState(() => result = r);
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('東京 乗換ルート検索（JR除外スイッチ付）')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _autocomplete('出発駅', fromCtl, _stationNames)),
                const SizedBox(width: 8),
                Expanded(child: _autocomplete('到着駅', toCtl, _stationNames)),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('JRを使う'),
              value: _allowJR,
              onChanged: (bool v) => setState(() => _allowJR = v),
              subtitle: Text(_allowJR ? 'JRを経路に含めます' : 'JRを除外して検索します'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(icon: const Icon(Icons.search), label: const Text('検索する'), onPressed: _search),
            const SizedBox(height: 12),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (result != null) _buildResult(result!),
          ],
        ),
      ),
    );
  }

  ///
  Widget _autocomplete(String label, TextEditingController ctl, List<String> opts) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue t) {
        if (t.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final String q = t.text.toLowerCase();
        return opts.where((String o) => o.toLowerCase().contains(q)).take(50);
      },
      onSelected: (String s) => ctl.text = s,
      fieldViewBuilder:
          (BuildContext context, TextEditingController textCtl, FocusNode node, void Function() onFieldSubmitted) {
            textCtl.text = ctl.text;
            textCtl.selection = ctl.selection;
            textCtl.addListener(() => ctl.value = textCtl.value);
            return TextField(
              controller: textCtl,
              focusNode: node,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
    );
  }

  ///
  Widget _buildResult(CalculatedRouteModel r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '結果: ${r.origin} → ${r.destination}（乗換${r.transferCount}回）',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final RouteSegmentModel seg in r.segments) ...<Widget>[
              Text('■ ${seg.lineName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('　${seg.fromStation} → ${seg.toStation}'),
              Text('　(${seg.passStations.join(" → ")})'),
              const SizedBox(height: 8),
            ],
            if (r.transfers.isNotEmpty) ...<Widget>[
              const Divider(),
              const Text('乗換詳細:'),
              for (final TransferStepModel t in r.transfers) Text('・${t.fromLine} → ${t.toLine} @ ${t.atStation}'),
            ],
          ],
        ),
      ),
    );
  }
}
