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
      // Prepare context from learning data
      String learningContext = _buildLearningContext(learningData);

      // Convert images to bytes
      List<DataPart> imageParts = [];
      for (File image in images) {
        Uint8List imageBytes = await image.readAsBytes();
        imageParts.add(DataPart('image/jpeg', imageBytes));
      }

      String prompt = '''
$learningContext

Analyze the provided plant images and determine if this is a herbal plant with medicinal properties.

User notes: ${userNotes ?? 'None provided'}

Please respond in the following JSON format:
{
  "isHerbal": true/false,
  "commonName": "Common name of the plant",
  "scientificName": "Scientific name (Genus species)",
  "description": "Brief description of the plant and its characteristics",
  "preparation": "How to prepare this plant for herbal use on a step by step basis (if herbal), or 'Not applicable' if non-herbal",
  "confidence": 0.0-1.0
}

Focus on:
1. Accurate plant identification
2. Whether it has documented medicinal/herbal uses
3. Safe preparation methods if applicable
4. Clear warnings if the plant might be dangerous

Be conservative - if uncertain about herbal properties or safety, mark as non-herbal.
''';

      final content = [
        Content.multi([TextPart(prompt), ...imageParts]),
      ];

      final response = await _model.generateContent(content);

      if (response.text != null) {
        // Extract JSON from response
        String jsonString = _extractJsonFromResponse(response.text!);
        Map<String, dynamic> plantInfo = jsonDecode(jsonString);

        // Only proceed if confidence is reasonable
        if (plantInfo['confidence'] < 0.6) {
          return null; // Low confidence, don't identify
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
      print('Error identifying plant: $e');
    }
    return null;
  }

  String _buildLearningContext(LearningData learningData) {
    StringBuffer context = StringBuffer();
    context.writeln('Learning Context from Previous Identifications:');

    if (learningData.identifiedPlants.isNotEmpty) {
      context.writeln('Previously identified plants:');
      for (var plant in learningData.identifiedPlants.take(10)) {
        context.writeln(
          '- ${plant.commonName} (${plant.scientificName}): ${plant.isHerbal ? 'Herbal' : 'Non-herbal'}',
        );
      }
    }

    if (learningData.userCorrections.isNotEmpty) {
      context.writeln('User corrections to consider:');
      learningData.userCorrections.forEach((plant, corrections) {
        context.writeln('- $plant: ${corrections.join(', ')}');
      });
    }

    return context.toString();
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
}
