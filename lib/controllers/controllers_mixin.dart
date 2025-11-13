import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_get_data/tokyo_train_station/tokyo_train_station.dart';

mixin ControllersMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  //==========================================//

  //==========================================//

  TokyoTrainStationState get tokyoTrainStationState => ref.watch(tokyoTrainStationProvider);

  TokyoTrainStation get tokyoTrainStationNotifier => ref.read(tokyoTrainStationProvider.notifier);

  //==========================================//
}
