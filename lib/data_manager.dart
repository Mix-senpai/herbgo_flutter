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

  Future<PlantData?> addPlantIdentification(
    PlantData plant,
    LearningData currentData,
  ) async {
    // Check if this plant already exists (consolidation logic)
    PlantData? existingPlant = _findExistingPlant(plant, currentData);
    
    if (existingPlant != null) {
      // Consolidate with existing plant
      PlantData consolidatedPlant = await _consolidatePlants(existingPlant, plant);
      
      // Remove old plant and add consolidated one
      currentData.identifiedPlants.removeWhere((p) => p.id == existingPlant.id);
      currentData.identifiedPlants.add(consolidatedPlant);
      
      // Update frequency (increment by 1)
      String plantKey = '${consolidatedPlant.commonName}_${consolidatedPlant.scientificName}';
      currentData.plantFrequency[plantKey] =
          (currentData.plantFrequency[plantKey] ?? 0) + 1;
      
      await saveLearningData(currentData);
      return consolidatedPlant;
    } else {
      // Add as new plant
      currentData.identifiedPlants.add(plant);

      // Update frequency
      String plantKey = '${plant.commonName}_${plant.scientificName}';
      currentData.plantFrequency[plantKey] =
          (currentData.plantFrequency[plantKey] ?? 0) + 1;

      await saveLearningData(currentData);
      return plant;
    }
  }

  PlantData? _findExistingPlant(PlantData newPlant, LearningData learningData) {
    for (PlantData existingPlant in learningData.identifiedPlants) {
      // Check for exact scientific name match (most reliable)
      if (_normalizeScientificName(existingPlant.scientificName) == 
          _normalizeScientificName(newPlant.scientificName)) {
        return existingPlant;
      }
      
      // Check for common name match with similar scientific name
      if (_normalizeCommonName(existingPlant.commonName) == 
          _normalizeCommonName(newPlant.commonName) &&
          _areSimilarScientificNames(existingPlant.scientificName, newPlant.scientificName)) {
        return existingPlant;
      }
    }
    return null;
  }

  Future<PlantData> _consolidatePlants(PlantData existing, PlantData newPlant) async {
    // Combine image paths (avoiding duplicates)
    Set<String> allImagePaths = Set.from(existing.imagePaths);
    allImagePaths.addAll(newPlant.imagePaths);
    
    // Choose the better description (longer and more detailed usually)
    String betterDescription = newPlant.description.length > existing.description.length 
        ? newPlant.description 
        : existing.description;
    
    // Choose the better preparation method
    String betterPreparation = newPlant.preparation.length > existing.preparation.length 
        ? newPlant.preparation 
        : existing.preparation;
    
    // Combine user notes
    String? combinedNotes;
    if (existing.userNotes != null && newPlant.userNotes != null) {
      combinedNotes = '${existing.userNotes}\n\n--- Additional Notes ---\n${newPlant.userNotes}';
    } else {
      combinedNotes = existing.userNotes ?? newPlant.userNotes;
    }
    
    return PlantData(
      id: existing.id, // Keep original ID
      commonName: existing.commonName,
      scientificName: existing.scientificName,
      description: betterDescription,
      preparation: betterPreparation,
      isHerbal: existing.isHerbal || newPlant.isHerbal, // If either is herbal, mark as herbal
      imagePaths: allImagePaths.toList(),
      identifiedAt: newPlant.identifiedAt, // Use new identification time
      userNotes: combinedNotes,
    );
  }

  String _normalizeScientificName(String scientificName) {
    return scientificName.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  String _normalizeCommonName(String commonName) {
    return commonName.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  bool _areSimilarScientificNames(String name1, String name2) {
    String norm1 = _normalizeScientificName(name1);
    String norm2 = _normalizeScientificName(name2);
    
    // Extract genus (first word)
    List<String> parts1 = norm1.split(' ');
    List<String> parts2 = norm2.split(' ');
    
    if (parts1.isEmpty || parts2.isEmpty) return false;
    
    // Same genus is a good indicator of the same plant
    return parts1[0] == parts2[0];
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

  // Helper method to get consolidated plant statistics
  Map<String, dynamic> getConsolidationStats(LearningData learningData) {
    Map<String, List<PlantData>> groupedPlants = {};
    
    for (PlantData plant in learningData.identifiedPlants) {
      String key = '${plant.commonName}_${plant.scientificName}';
      if (!groupedPlants.containsKey(key)) {
        groupedPlants[key] = [];
      }
      groupedPlants[key]!.add(plant);
    }
    
    int totalImages = learningData.identifiedPlants
        .map((p) => p.imagePaths.length)
        .fold(0, (a, b) => a + b);
    
    return {
      'uniqueSpecies': groupedPlants.length,
      'totalIdentifications': learningData.identifiedPlants.length,
      'totalImages': totalImages,
      'averageImagesPerPlant': learningData.identifiedPlants.isNotEmpty 
          ? (totalImages / learningData.identifiedPlants.length).toStringAsFixed(1)
          : '0',
      'mostPhotographedPlant': learningData.plantFrequency.isNotEmpty
          ? learningData.plantFrequency.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null,
    };
  }

  // Method to manually merge two plants (for user-initiated consolidation)
  Future<void> mergePlants(
    String primaryPlantId,
    String secondaryPlantId,
    LearningData currentData,
  ) async {
    PlantData? primaryPlant = currentData.identifiedPlants
        .firstWhere((p) => p.id == primaryPlantId);
    PlantData? secondaryPlant = currentData.identifiedPlants
        .firstWhere((p) => p.id == secondaryPlantId);
    
    if (primaryPlant != null && secondaryPlant != null) {
      PlantData mergedPlant = await _consolidatePlants(primaryPlant, secondaryPlant);
      
      // Remove both plants and add merged one
      currentData.identifiedPlants.removeWhere((p) => 
          p.id == primaryPlantId || p.id == secondaryPlantId);
      currentData.identifiedPlants.add(mergedPlant);
      
      // Update frequency (decrement by 1 since we're combining two entries)
      String plantKey = '${mergedPlant.commonName}_${mergedPlant.scientificName}';
      if (currentData.plantFrequency.containsKey(plantKey) && 
          currentData.plantFrequency[plantKey]! > 0) {
        currentData.plantFrequency[plantKey] = 
            currentData.plantFrequency[plantKey]! - 1;
      }
      
      await saveLearningData(currentData);
    }
  }
}