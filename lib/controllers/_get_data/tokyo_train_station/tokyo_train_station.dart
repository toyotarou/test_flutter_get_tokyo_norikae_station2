import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/http/client.dart';
import '../../../models/line_model.dart';
import '../../../models/station_model.dart';
import '../../../models/tokyo_train_model.dart';
import '../../../utility/utility.dart';

part 'tokyo_train_station.freezed.dart';

part 'tokyo_train_station.g.dart';

@freezed
class TokyoTrainStationState with _$TokyoTrainStationState {
  const factory TokyoTrainStationState({
    @Default(<LineModel>[]) List<LineModel> lineModelList,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _TokyoTrainStationState;
}

@riverpod
class TokyoTrainStation extends _$TokyoTrainStation {
  final Utility utility = Utility();

  @override
  TokyoTrainStationState build() => const TokyoTrainStationState();

  ///
  Future<void> getAllTokyoTrainStation() async {
    final HttpClient client = ref.read(httpClientProvider);

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final List<LineModel> list = <LineModel>[];

      final dynamic value = await client.postByPath(
        path: 'http://toyohide.work/BrainLog/api/getTokyoTrainStation',
        body: const <String, dynamic>{},
      );

      // ignore: avoid_dynamic_calls
      final List<dynamic> data = value['data'] as List<dynamic>;

      for (final dynamic e in data) {
        final TokyoTrainModel val = TokyoTrainModel.fromJson(e as Map<String, dynamic>);

        final List<StationModel> stations = <StationModel>[];
        for (final TokyoStationModel s in val.station) {
          stations.add(StationModel(id: s.id, name: s.stationName, lat: s.lat, lng: s.lng));
        }

        list.add(LineModel(trainNumber: val.trainNumber, name: val.trainName, stations: stations));
      }

      state = state.copyWith(lineModelList: list, isLoading: false);
    } catch (e) {
      utility.showError('予期せぬエラーが発生しました');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
