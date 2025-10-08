import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:herbgo/plant_model.dart';

class PlantAIService {
  late final GenerativeModel _model;
  final String _apiKey;

  PlantAIService(this._apiKey) {
    _model = GenerativeModel(model: 'gemini-2.0-flash-lite', apiKey: _apiKey);
  }

  /// First checks the gallery (local knowledge), then queries Gemini if not found
  Future<PlantData?> identifyPlant(
    List<File> images,
    String? userNotes,
    LearningData learningData,
  ) async {
    try {
      // Step 1: Check if this plant exists in our gallery (local knowledge base)
      PlantData? knownPlant = await _checkAgainstGallery(images, learningData);

      if (knownPlant != null) {
        print('Plant found in gallery: ${knownPlant.commonName}');
        // Return a new instance with updated images and notes
        return PlantData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          commonName: knownPlant.commonName,
          scientificName: knownPlant.scientificName,
          description: knownPlant.description,
          preparation: knownPlant.preparation,
          isHerbal: knownPlant.isHerbal,
          imagePaths: images.map((f) => f.path).toList(),
          identifiedAt: DateTime.now(),
          userNotes: userNotes,
        );
      }

      // Step 2: Plant not in gallery, query Gemini
      print('Plant not in gallery, querying Gemini...');
      return await _queryGeminiForPlant(images, userNotes, learningData);
    } catch (e) {
      print('Error identifying plant: $e');
    }
    return null;
  }

  /// Check if the plant exists in the gallery by asking Gemini to compare
  Future<PlantData?> _checkAgainstGallery(
    List<File> images,
    LearningData learningData,
  ) async {
    if (learningData.identifiedPlants.isEmpty) {
      return null; // No plants in gallery yet
    }

    try {
      // Build a concise list of plants in the gallery
      String galleryContext = _buildGalleryContext(learningData);

      // Convert images to bytes
      List<DataPart> imageParts = [];
      for (File image in images) {
        Uint8List imageBytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', imageBytes));
      }

      String prompt = '''
You are comparing a plant in these images against a gallery of known plants.

GALLERY OF KNOWN PLANTS:
$galleryContext

Task: Determine if the plant in the images matches ANY plant in the gallery above.

Respond in JSON format:
{
  "matchFound": true/false,
  "matchedPlantId": "id of matched plant or null",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation"
}

Be conservative - only return matchFound: true if you're confident (>0.6) it's the same species.
Consider leaf shape, arrangement, stem characteristics, flowers, and overall morphology.
''';

      final content = [
        Content.multi([TextPart(prompt), ...imageParts]),
      ];

      final response = await _model.generateContent(content);

      if (response.text != null) {
        String jsonString = _extractJsonFromResponse(response.text!);
        Map<String, dynamic> result = jsonDecode(jsonString);

        if (result['matchFound'] == true && result['confidence'] >= 0.6) {
          // Find the matched plant
          String matchedId = result['matchedPlantId'];
          PlantData? matchedPlant = learningData.identifiedPlants.firstWhere(
              (p) => p.id == matchedId,
              orElse: () => null as PlantData);

          return matchedPlant;
        }
      }
    } catch (e) {
      print('Error checking gallery: $e');
    }

    return null;
  }

  /// Query Gemini for a new plant identification
  Future<PlantData?> _queryGeminiForPlant(
    List<File> images,
    String? userNotes,
    LearningData learningData,
  ) async {
    try {
      // Convert images to bytes
      List<DataPart> imageParts = [];
      for (File image in images) {
        Uint8List imageBytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', imageBytes));
      }

      String prompt = '''
Analyze the provided plant images and determine if this is a herbal plant with medicinal properties.

User notes: ${userNotes ?? 'None provided'}

Please respond in the following JSON format:
{
  "isHerbal": true/false,
  "commonName": "Most common Filipino name of the plant",
  "scientificName": "Scientific name (Genus species)",
  "description": "Brief description of the plant and its characteristics",
  "preparation": "How to prepare this plant for herbal use on a step by step basis (if herbal), or 'Not applicable' if non-herbal",
  "confidence": 0.0-1.0
}

Focus on:
1. Accurate plant identification.
2. Whether it has documented medicinal/herbal uses.
3. Safe preparation methods if applicable, in a step-by-step numbered format.
4. Clear warnings if the plant might be dangerous.

Be conservative - if uncertain about herbal properties or safety, mark as non-herbal.
''';

      final content = [
        Content.multi([TextPart(prompt), ...imageParts]),
      ];

      final response = await _model.generateContent(content);

      if (response.text != null) {
        String jsonString = _extractJsonFromResponse(response.text!);
        Map<String, dynamic> plantInfo = jsonDecode(jsonString);

        // Only proceed if confidence is reasonable
        if (plantInfo['confidence'] < 0.6) {
          return null;
        }

        return PlantData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          commonName: plantInfo['commonName'],
          scientificName: plantInfo['scientificName'],
          description: plantInfo['description'],
          preparation: plantInfo['preparation'],
          isHerbal: plantInfo['isHerbal'],
          imagePaths: images.map((f) => f.path).toList(),
          identifiedAt: DateTime.now(),
          userNotes: userNotes,
        );
      }
    } catch (e) {
      print('Error querying Gemini: $e');
    }
    return null;
  }

  String _buildGalleryContext(LearningData learningData) {
    StringBuffer context = StringBuffer();

    for (var plant in learningData.identifiedPlants) {
      context.writeln('ID: ${plant.id}');
      context.writeln('Common Name: ${plant.commonName}');
      context.writeln('Scientific Name: ${plant.scientificName}');
      context.writeln('Type: ${plant.isHerbal ? 'Herbal' : 'Non-herbal'}');
      context.writeln(
          'Description: ${plant.description.substring(0, plant.description.length > 150 ? 150 : plant.description.length)}...');
      context.writeln('---');
    }

    return context.toString();
  }

  String _extractJsonFromResponse(String response) {
    int startIndex = response.indexOf('{');
    int endIndex = response.lastIndexOf('}');

    if (startIndex != -1 && endIndex != -1) {
      return response.substring(startIndex, endIndex + 1);
    }

    throw Exception('No valid JSON found in response');
  }

  /// Update an existing plant's information
  Future<PlantData?> updatePlant(
    PlantData existingPlant,
    List<File> newImages,
    String? newNotes,
    String? updatedDescription,
    String? updatedPreparation,
  ) async {
    return PlantData(
      id: existingPlant.id, // Keep same ID
      commonName: existingPlant.commonName,
      scientificName: existingPlant.scientificName,
      description: updatedDescription ?? existingPlant.description,
      preparation: updatedPreparation ?? existingPlant.preparation,
      isHerbal: existingPlant.isHerbal,
      imagePaths: newImages.isNotEmpty
          ? newImages.map((f) => f.path).toList()
          : existingPlant.imagePaths,
      identifiedAt: DateTime.now(),
      userNotes: newNotes ?? existingPlant.userNotes,
    );
  }
}
