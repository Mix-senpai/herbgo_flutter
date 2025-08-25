import 'dart:convert';
import 'dart:io';

import 'package:herbgo/plant_model.dart';
import 'package:path_provider/path_provider.dart';

class DataManager {
  static const String _fileName = 'plant_learning_data.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<LearningData> loadLearningData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        String contents = await file.readAsString();
        Map<String, dynamic> jsonData = jsonDecode(contents);
        return LearningData.fromJson(jsonData);
      }
    } catch (e) {
      print('Error loading learning data: $e');
    }

    // Return empty learning data if file doesn't exist or error
    return LearningData(
      identifiedPlants: [],
      plantFrequency: {},
      userCorrections: {},
    );
  }

  Future<void> saveLearningData(LearningData data) async {
    try {
      final file = await _localFile;
      await file.writeAsString(jsonEncode(data.toJson()));
    } catch (e) {
      print('Error saving learning data: $e');
    }
  }

  Future<void> addPlantIdentification(
    PlantData plant,
    LearningData currentData,
  ) async {
    currentData.identifiedPlants.add(plant);

    // Update frequency
    String plantKey = '${plant.commonName}_${plant.scientificName}';
    currentData.plantFrequency[plantKey] =
        (currentData.plantFrequency[plantKey] ?? 0) + 1;

    await saveLearningData(currentData);
  }

  Future<void> addUserCorrection(
    String plantId,
    String correction,
    LearningData currentData,
  ) async {
    if (!currentData.userCorrections.containsKey(plantId)) {
      currentData.userCorrections[plantId] = [];
    }
    currentData.userCorrections[plantId]!.add(correction);

    await saveLearningData(currentData);
  }
}
