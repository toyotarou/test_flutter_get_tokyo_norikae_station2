import 'route_segment_model.dart';
import 'transfer_step_model.dart';

class CalculatedRouteModel {
  CalculatedRouteModel({
    required this.origin,
    required this.destination,
    required this.segments,
    required this.transfers,
    required this.transferCount,
  });

  final String origin;
  final String destination;
  final List<RouteSegmentModel> segments;
  final List<TransferStepModel> transfers;
  final int transferCount;
}
