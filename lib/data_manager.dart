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

    String plantKey = '${plant.commonName}_${plant.scientificName}';
    currentData.plantFrequency[plantKey] =
        (currentData.plantFrequency[plantKey] ?? 0) + 1;

    await saveLearningData(currentData);
  }

  /// Update an existing plant in the gallery
  Future<void> updatePlantIdentification(
    PlantData updatedPlant,
    LearningData currentData,
  ) async {
    // Find and replace the plant with the same ID
    int index =
        currentData.identifiedPlants.indexWhere((p) => p.id == updatedPlant.id);

    if (index != -1) {
      // Delete old images if they're different
      PlantData oldPlant = currentData.identifiedPlants[index];
      for (String oldImagePath in oldPlant.imagePaths) {
        if (!updatedPlant.imagePaths.contains(oldImagePath)) {
          try {
            File imageFile = File(oldImagePath);
            if (await imageFile.exists()) {
              await imageFile.delete();
              print('Deleted old image: $oldImagePath');
            }
          } catch (e) {
            print('Error deleting old image $oldImagePath: $e');
          }
        }
      }

      // Replace with updated plant
      currentData.identifiedPlants[index] = updatedPlant;
      await saveLearningData(currentData);
      print('Plant updated: ${updatedPlant.commonName}');
    }
  }

  /// Overwrite/replace a plant entry completely
  Future<void> overwritePlant(
    String plantId,
    PlantData newPlantData,
    LearningData currentData,
  ) async {
    int index = currentData.identifiedPlants.indexWhere((p) => p.id == plantId);

    if (index != -1) {
      PlantData oldPlant = currentData.identifiedPlants[index];

      // Delete all old images
      for (String imagePath in oldPlant.imagePaths) {
        try {
          File imageFile = File(imagePath);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      // Update frequency maps
      String oldKey = '${oldPlant.commonName}_${oldPlant.scientificName}';
      String newKey =
          '${newPlantData.commonName}_${newPlantData.scientificName}';

      if (currentData.plantFrequency.containsKey(oldKey)) {
        currentData.plantFrequency[oldKey] =
            currentData.plantFrequency[oldKey]! - 1;
        if (currentData.plantFrequency[oldKey]! <= 0) {
          currentData.plantFrequency.remove(oldKey);
        }
      }

      currentData.plantFrequency[newKey] =
          (currentData.plantFrequency[newKey] ?? 0) + 1;

      // Replace with new data
      currentData.identifiedPlants[index] = newPlantData;
      await saveLearningData(currentData);
      print(
          'Plant overwritten: ${oldPlant.commonName} -> ${newPlantData.commonName}');
    }
  }

  /// Delete a plant and remove it from the model's knowledge
  Future<void> deletePlant(
    String plantId,
    LearningData currentData,
  ) async {
    PlantData? plant = currentData.identifiedPlants.firstWhere(
      (p) => p.id == plantId,
      orElse: () => null as PlantData,
    );

    // Remove from list
    currentData.identifiedPlants.removeWhere((p) => p.id == plantId);

    // Update frequency
    String plantKey = '${plant.commonName}_${plant.scientificName}';
    if (currentData.plantFrequency.containsKey(plantKey)) {
      if (currentData.plantFrequency[plantKey]! <= 1) {
        currentData.plantFrequency.remove(plantKey);
      } else {
        currentData.plantFrequency[plantKey] =
            currentData.plantFrequency[plantKey]! - 1;
      }
    }

    // Delete image files
    for (String imagePath in plant.imagePaths) {
      try {
        File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        print('Error deleting image: $e');
      }
    }

    // Remove corrections related to this plant
    currentData.userCorrections.remove(plantId);

    await saveLearningData(currentData);
    print('Plant deleted from knowledge base: ${plant.commonName}');
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
