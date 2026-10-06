enum PlaceKind { gym, supplementStore }

/// Un lugar cercano (gimnasio o tienda de suplementos) encontrado en
/// OpenStreetMap, con su distancia al usuario.
class NearbyPlace {
  final String name;
  final PlaceKind kind;
  final double lat;
  final double lon;
  final String? address;
  double distanceKm;

  NearbyPlace({
    required this.name,
    required this.kind,
    required this.lat,
    required this.lon,
    this.address,
    this.distanceKm = 0,
  });
}
