class RouteSegmentModel {
  RouteSegmentModel({
    required this.lineName,
    required this.fromStation,
    required this.toStation,
    required this.passStations,
  });

  final String lineName;
  final String fromStation;
  final String toStation;
  final List<String> passStations;
}
