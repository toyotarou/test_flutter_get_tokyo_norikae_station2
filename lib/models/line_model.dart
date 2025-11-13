import 'station_model.dart';

class LineModel {
  LineModel({required this.trainNumber, required this.name, required this.stations});

  // ignore: unreachable_from_main
  final int trainNumber;
  final String name; // train_name
  final List<StationModel> stations;
}
