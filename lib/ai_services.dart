import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:herbgo/plant_model.dart';

class PlantAIService {
  late final GenerativeModel _model;
  final String _apiKey;

  PlantAIService(this._apiKey) {
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  Future<PlantData?> identifyPlant(
    List<File> images,
    String? userNotes,
    LearningData learningData,
  ) async {
    try {
      // Prepare context from learning data (including images)
      String learningContext = await _buildLearningContext(learningData);

      // Convert current images to bytes
      List<DataPart> imageParts = [];
      for (File image in images) {
        Uint8List imageBytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', imageBytes));
      }

      // Add reference images from learning data
      List<DataPart> referenceImageParts = await _buildReferenceImages(learningData);

      String prompt = '''
$learningContext

CRITICAL INSTRUCTIONS:
1. ONLY analyze if the images contain actual living plants, herbs, or botanical specimens
2. DO NOT identify non-plant objects like rocks, animals, people, food items, manufactured objects, etc.
3. If the images do not contain plants, respond with: {"isPlant": false, "reason": "No plant detected"}

If the images DO contain plants, analyze them to determine if they are herbal plants with medicinal properties.

User notes: ${userNotes ?? 'None provided'}

The first ${images.length} images are the current specimens to identify.
${referenceImageParts.isNotEmpty ? 'The following images are reference examples from previous identifications for learning context.' : ''}

Please respond in the following JSON format:
{
  "isPlant": true/false,
  "reason": "Brief explanation if not a plant, or empty string if it is a plant",
  "isHerbal": true/false,
  "commonName": "Common name of the plant in the Philippines (only if isPlant is true)",
  "scientificName": "Scientific name (Genus species) (only if isPlant is true)",
  "description": "Brief description of the plant and its characteristics (only if isPlant is true)",
  "preparation": "Step-by-step preparation for herbal use, or 'Not applicable' if non-herbal (only if isPlant is true)",
  "confidence": 0.0-1.0
}

IMPORTANT VALIDATION RULES:
- If the image shows any non-plant object (rocks, animals, people, food, manufactured items, etc.), set "isPlant": false
- Only proceed with plant identification if you're confident the image contains actual botanical specimens
- Be conservative: if uncertain whether it's a plant, mark as "isPlant": false
- For plant identification, focus on:
  1. Accurate visual plant characteristics (leaves, stems, flowers, etc.)
  2. Compare with reference images if available
  3. Whether it has documented medicinal/herbal uses in the Philippines
  4. Safe preparation methods if applicable
- If the plant might be dangerous or you're unsure about safety, mark as non-herbal
- Confidence should reflect both plant identification accuracy AND herbal properties certainty
''';

      final content = [
        Content.multi([
          TextPart(prompt), 
          ...imageParts,
          ...referenceImageParts,
        ]),
      ];

      final response = await _model.generateContent(content);

      if (response.text != null) {
        // Extract JSON from response
        String jsonString = _extractJsonFromResponse(response.text!);
        Map<String, dynamic> plantInfo = jsonDecode(jsonString);

        // First check if it's actually a plant
        if (plantInfo['isPlant'] == false) {
          print('Not a plant detected: ${plantInfo['reason']}');
          return null; // Return null for non-plant objects
        }

        // Only proceed if confidence is reasonable for actual plants
        if (plantInfo['confidence'] < 0.7) { // Increased threshold for better accuracy
          print('Low confidence plant identification: ${plantInfo['confidence']}');
          return null;
        }

        // Validate required fields for plant data
        if (plantInfo['commonName'] == null || 
            plantInfo['scientificName'] == null ||
            plantInfo['description'] == null ||
            plantInfo['commonName'].toString().trim().isEmpty ||
            plantInfo['scientificName'].toString().trim().isEmpty) {
          print('Incomplete plant identification data');
          return null;
        }

        return PlantData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          commonName: plantInfo['commonName'],
          scientificName: plantInfo['scientificName'],
          description: plantInfo['description'],
          preparation: plantInfo['preparation'] ?? 'Not applicable',
          isHerbal: plantInfo['isHerbal'] ?? false,
          imagePaths: images.map((f) => f.path).toList(),
          identifiedAt: DateTime.now(),
          userNotes: userNotes,
        );
      }
    } catch (e) {
      print('Error identifying plant: $e');
    }
    return null;
  }

  Future<String> _buildLearningContext(LearningData learningData) async {
    StringBuffer context = StringBuffer();
    context.writeln('Learning Context from Previous Identifications:');

    if (learningData.identifiedPlants.isNotEmpty) {
      context.writeln('Previously identified plants:');
      for (var plant in learningData.identifiedPlants.take(10)) {
        context.writeln(
          '- ${plant.commonName} (${plant.scientificName}): ${plant.isHerbal ? 'Herbal' : 'Non-herbal'}',
        );
        context.writeln('  Description: ${plant.description.substring(0, plant.description.length > 100 ? 100 : plant.description.length)}...');
        if (plant.isHerbal) {
          context.writeln('  Preparation: ${plant.preparation.substring(0, plant.preparation.length > 80 ? 80 : plant.preparation.length)}...');
        }
        context.writeln('  Images available: ${plant.imagePaths.length}');
        context.writeln('');
      }
    }

    if (learningData.userCorrections.isNotEmpty) {
      context.writeln('User corrections to consider:');
      learningData.userCorrections.forEach((plant, corrections) {
        context.writeln('- $plant: ${corrections.join(', ')}');
      });
    }

    // Add frequency information for better context
    if (learningData.plantFrequency.isNotEmpty) {
      context.writeln('Most frequently identified plant types:');
      var sortedFrequency = learningData.plantFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (var entry in sortedFrequency.take(5)) {
        context.writeln('- ${entry.key}: ${entry.value} times');
      }
    }

    return context.toString();
  }

  Future<List<DataPart>> _buildReferenceImages(LearningData learningData) async {
    List<DataPart> referenceImages = [];
    
    try {
      // Get a diverse set of reference images from learning data
      // Prioritize herbal plants and recent identifications
      List<PlantData> referencePlants = [];
      
      // Add herbal plants first (more important for learning)
      var herbalPlants = learningData.identifiedPlants
          .where((p) => p.isHerbal && p.imagePaths.isNotEmpty)
          .toList();
      referencePlants.addAll(herbalPlants.take(3));
      
      // Add some non-herbal plants for comparison
      var nonHerbalPlants = learningData.identifiedPlants
          .where((p) => !p.isHerbal && p.imagePaths.isNotEmpty)
          .toList();
      referencePlants.addAll(nonHerbalPlants.take(2));
      
      // Limit total reference images to avoid overwhelming the context
      for (var plant in referencePlants.take(5)) {
        // Use the first image from each reference plant
        if (plant.imagePaths.isNotEmpty) {
          try {
            File imageFile = File(plant.imagePaths.first);
            if (await imageFile.exists()) {
              Uint8List imageBytes = await imageFile.readAsBytes();
              referenceImages.add(DataPart('image/jpeg', imageBytes));
              
              // Limit to prevent context overflow
              if (referenceImages.length >= 5) break;
            }
          } catch (e) {
            print('Error loading reference image for ${plant.commonName}: $e');
            // Continue with next image if this one fails
          }
        }
      }
    } catch (e) {
      print('Error building reference images: $e');
      // Return empty list if there's an error
    }
    
    return referenceImages;
  }

  String _extractJsonFromResponse(String response) {
    // Find JSON in the response
    int startIndex = response.indexOf('{');
    int endIndex = response.lastIndexOf('}');

    if (startIndex != -1 && endIndex != -1) {
      return response.substring(startIndex, endIndex + 1);
    }

    throw Exception('No valid JSON found in response');
  }

  // Additional method to get learning statistics
  Map<String, dynamic> getLearningStats(LearningData learningData) {
    return {
      'totalPlants': learningData.identifiedPlants.length,
      'herbalPlants': learningData.identifiedPlants.where((p) => p.isHerbal).length,
      'uniqueSpecies': learningData.plantFrequency.length,
      'totalImages': learningData.identifiedPlants
          .map((p) => p.imagePaths.length)
          .fold(0, (a, b) => a + b),
      'userCorrections': learningData.userCorrections.length,
      'mostCommonPlant': learningData.plantFrequency.isNotEmpty
          ? learningData.plantFrequency.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null,
    };
  }
}