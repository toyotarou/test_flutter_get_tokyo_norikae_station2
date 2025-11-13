class TokyoStationModel {
  TokyoStationModel({
    required this.id,
    required this.stationName,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory TokyoStationModel.fromJson(Map<String, dynamic> json) {
    return TokyoStationModel(
      id: json['id'] as String,
      stationName: json['station_name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  final String id;
  final String stationName;
  final String address;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'station_name': stationName, 'address': address, 'lat': lat, 'lng': lng};
  }
}

class TokyoTrainModel {
  TokyoTrainModel({required this.trainNumber, required this.trainName, required this.station});

  factory TokyoTrainModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = (json['station'] ?? <dynamic>[]) as List<dynamic>;
    return TokyoTrainModel(
      trainNumber: json['train_number'] as int,
      trainName: json['train_name'] as String,
      // ignore: always_specify_types
      station: list.map((e) => TokyoStationModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final int trainNumber;
  final String trainName;
  final List<TokyoStationModel> station;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'train_number': trainNumber,
      'train_name': trainName,
      'station': station.map((TokyoStationModel e) => e.toJson()).toList(),
    };
  }
}
