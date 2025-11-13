import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/http/client.dart';
import '../../../models/tokyo_train_model.dart';
import '../../../utility/utility.dart';

part 'tokyo_train_station.freezed.dart';

part 'tokyo_train_station.g.dart';

@freezed
class TokyoTrainStationState with _$TokyoTrainStationState {
  const factory TokyoTrainStationState({
    @Default(<TokyoTrainModel>[]) List<TokyoTrainModel> tokyoTrainModelList,
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
      final List<TokyoTrainModel> list = <TokyoTrainModel>[];

      final dynamic value = await client.postByPath(
        path: 'http://toyohide.work/BrainLog/api/getTokyoTrainStation',
        body: const <String, dynamic>{},
      );

      // ignore: avoid_dynamic_calls
      final List<dynamic> data = value['data'] as List<dynamic>;

      for (final dynamic e in data) {
        final TokyoTrainModel val = TokyoTrainModel.fromJson(e as Map<String, dynamic>);

        final List<TokyoStationModel> stations = <TokyoStationModel>[];
        for (final TokyoStationModel s in val.station) {
          stations.add(TokyoStationModel(id: s.id, stationName: s.stationName, lat: s.lat, lng: s.lng, address: ''));
        }

        list.add(TokyoTrainModel(trainNumber: val.trainNumber, trainName: val.trainName, station: stations));
      }

      state = state.copyWith(tokyoTrainModelList: list, isLoading: false);
    } catch (e) {
      utility.showError('予期せぬエラーが発生しました');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
