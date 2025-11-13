import 'package:flutter/material.dart';

import '../models/calculated_route_model.dart';
import '../models/route_segment_model.dart';
import '../models/tokyo_train_model.dart';
import '../models/transfer_step_model.dart';
import '../utility/functions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.tokyoTrainModelList});

  final List<TokyoTrainModel> tokyoTrainModelList;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<String> forAutoCompleteStationNamesList;

  final TextEditingController startEditingController = TextEditingController();
  final TextEditingController goalEditingController = TextEditingController();

  bool _allowJR = true;

  CalculatedRouteModel? calculateRouteModel;
  String? error;

  ///
  @override
  void initState() {
    super.initState();

    forAutoCompleteStationNamesList = <String>{
      for (final TokyoTrainModel tokyoTrainModel in widget.tokyoTrainModelList)
        ...tokyoTrainModel.station.map((TokyoStationModel tokyoStationModel) => tokyoStationModel.stationName),
    }.toList()..sort();
  }

  ///
  void doNorikaeSearch() {
    setState(() {
      error = null;
      calculateRouteModel = null;
    });

    final String start = startEditingController.text.trim();
    final String goal = goalEditingController.text.trim();
    if (start.isEmpty || goal.isEmpty) {
      setState(() => error = '出発駅と到着駅を入力してください');
      return;
    }

    final CalculatedRouteModel? calculatedRouteModel = routeFinder(
      tokyoTrainModelList: widget.tokyoTrainModelList,
      origin: start,
      destination: goal,
      allowJR: _allowJR,
    );

    if (calculatedRouteModel == null) {
      final String jrMsg = _allowJR ? '' : '（JR除外中のため経路が無い可能性があります）';
      setState(() => error = '経路が見つかりませんでした $jrMsg');
    } else {
      setState(() => calculateRouteModel = calculatedRouteModel);
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
                Expanded(
                  child: stationNameAutoComplete(
                    label: '出発駅',
                    textEditingController: startEditingController,
                    stationNamesList: forAutoCompleteStationNamesList,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: stationNameAutoComplete(
                    label: '到着駅',
                    textEditingController: goalEditingController,
                    stationNamesList: forAutoCompleteStationNamesList,
                  ),
                ),
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

            FilledButton.icon(icon: const Icon(Icons.search), label: const Text('検索する'), onPressed: doNorikaeSearch),
            const SizedBox(height: 12),

            if (error != null) ...<Widget>[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],

            if (calculateRouteModel != null) ...<Widget>[buildResultCard(calculateRouteModel: calculateRouteModel!)],
          ],
        ),
      ),
    );
  }

  ///
  Widget stationNameAutoComplete({
    required String label,
    required TextEditingController textEditingController,
    required List<String> stationNamesList,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue t) {
        if (t.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final String q = t.text.toLowerCase();
        return stationNamesList.where((String o) => o.toLowerCase().contains(q)).take(50);
      },
      onSelected: (String s) => textEditingController.text = s,
      fieldViewBuilder:
          (BuildContext context, TextEditingController textCtl, FocusNode node, void Function() onFieldSubmitted) {
            textCtl.text = textEditingController.text;
            textCtl.selection = textEditingController.selection;
            textCtl.addListener(() => textEditingController.value = textCtl.value);
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
  Widget buildResultCard({required CalculatedRouteModel calculateRouteModel}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '結果: ${calculateRouteModel.origin} → ${calculateRouteModel.destination}（乗換${calculateRouteModel.transferCount}回）',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final RouteSegmentModel seg in calculateRouteModel.segments) ...<Widget>[
              Text('■ ${seg.lineName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('　${seg.fromStation} → ${seg.toStation}'),
              Text('　(${seg.passStations.join(" → ")})'),
              const SizedBox(height: 8),
            ],
            if (calculateRouteModel.transfers.isNotEmpty) ...<Widget>[
              const Divider(),
              const Text('乗換詳細:'),
              for (final TransferStepModel t in calculateRouteModel.transfers)
                Text('・${t.fromLine} → ${t.toLine} @ ${t.atStation}'),
            ],
          ],
        ),
      ),
    );
  }
}
