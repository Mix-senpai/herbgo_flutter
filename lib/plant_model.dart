class PlantData {
  final String id;
  final String commonName;
  final String scientificName;
  final String description;
  final String preparation;
  final bool isHerbal;
  final List<String> imagePaths;
  final DateTime identifiedAt;
  final String? userNotes;

  PlantData({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.description,
    required this.preparation,
    required this.isHerbal,
    required this.imagePaths,
    required this.identifiedAt,
    this.userNotes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'commonName': commonName,
    'scientificName': scientificName,
    'description': description,
    'preparation': preparation,
    'isHerbal': isHerbal,
    'imagePaths': imagePaths,
    'identifiedAt': identifiedAt.toIso8601String(),
    'userNotes': userNotes,
  };

  factory PlantData.fromJson(Map<String, dynamic> json) => PlantData(
    id: json['id'],
    commonName: json['commonName'],
    scientificName: json['scientificName'],
    description: json['description'],
    preparation: json['preparation'],
    isHerbal: json['isHerbal'],
    imagePaths: List<String>.from(json['imagePaths']),
    identifiedAt: DateTime.parse(json['identifiedAt']),
    userNotes: json['userNotes'],
  );
}

class LearningData {
  final List<PlantData> identifiedPlants;
  final Map<String, int> plantFrequency;
  final Map<String, List<String>> userCorrections;

  LearningData({
    required this.identifiedPlants,
    required this.plantFrequency,
    required this.userCorrections,
  });

  Map<String, dynamic> toJson() => {
    'identifiedPlants': identifiedPlants.map((p) => p.toJson()).toList(),
    'plantFrequency': plantFrequency,
    'userCorrections': userCorrections,
  };

  factory LearningData.fromJson(Map<String, dynamic> json) => LearningData(
    identifiedPlants: (json['identifiedPlants'] as List)
        .map((p) => PlantData.fromJson(p))
        .toList(),
    plantFrequency: Map<String, int>.from(json['plantFrequency'] ?? {}),
    userCorrections: Map<String, List<String>>.from(
      (json['userCorrections'] ?? {}).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
    ),
  );
}
