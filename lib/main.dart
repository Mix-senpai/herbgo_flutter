import 'package:flutter/material.dart';
import 'package:herbgo/ai_services.dart';
import 'package:herbgo/data_manager.dart';
import 'package:herbgo/plant_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(HerbalPlantApp());
}

class HerbalPlantApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herbal Plant Identifier',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PlantIdentifierScreen(),
    );
  }
}

//SCREEN
class PlantIdentifierScreen extends StatefulWidget {
  @override
  _PlantIdentifierScreenState createState() => _PlantIdentifierScreenState();
}

class _PlantIdentifierScreenState extends State<PlantIdentifierScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final DataManager _dataManager = DataManager();
  late PlantAIService _aiService;

  List<File> _selectedImages = [];
  bool _isLoading = false;
  LearningData? _learningData;
  PlantData? _identifiedPlant;

  @override
  void initState() {
    super.initState();
    _aiService = PlantAIService(
        "AIzaSyBW3fgT21pjhjoMW6r39Y3Ouv8VFfjzztA"); // Replace with your API key
    _loadLearningData();
  }

  Future<void> _loadLearningData() async {
    _learningData = await _dataManager.loadLearningData();
    setState(() {});
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();

    setState(() {
      _selectedImages = images.map((xFile) => File(xFile.path)).toList();
    });
  }

  Future<void> _identifyPlant() async {
    if (_selectedImages.isEmpty || _learningData == null) return;

    setState(() {
      _isLoading = true;
      _identifiedPlant = null;
    });

    try {
      PlantData? result = await _aiService.identifyPlant(
        _selectedImages,
        _notesController.text.isEmpty ? null : _notesController.text,
        _learningData!,
      );

      if (result != null) {
        await _dataManager.addPlantIdentification(result, _learningData!);

        setState(() {
          _identifiedPlant = result;
        });

        if (result.isHerbal) {
          _showPlantInfoCard(result);
        } else {
          _showNonHerbalDialog(result);
        }
      } else {
        _showErrorDialog(
          'Unable to identify the plant with confidence. Please try again with clearer images.',
        );
      }
    } catch (e) {
      _showErrorDialog('Error identifying plant: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPlantInfoCard(PlantData plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantInfoCard(
          plant: plant,
          onCorrection: (correction) async {
            await _dataManager.addUserCorrection(
              plant.id,
              correction,
              _learningData!,
            );
          },
        ),
      ),
    );
  }

  void _showNonHerbalDialog(PlantData plant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Plant Identified'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Common Name: ${plant.commonName}'),
            Text('Scientific Name: ${plant.scientificName}'),
            SizedBox(height: 8),
            Text(
              'This plant is not identified as having herbal/medicinal properties.',
            ),
            SizedBox(height: 8),
            Text(plant.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedImages.clear();
      _identifiedPlant = null;
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Herbal Plant Identifier'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.local_florist, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'Identify Herbal Plants',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Take or select photos of plants to identify if they have herbal properties',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: Icon(Icons.photo_camera),
              label: Text('Select Plant Images'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(height: 16),
              Text('Selected Images (${_selectedImages.length}):'),
              SizedBox(height: 8),
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Additional Notes (Optional)',
                hintText: 'Any observations about the plant...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _selectedImages.isNotEmpty && !_isLoading
                  ? _identifyPlant
                  : null,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.search),
              label: Text(_isLoading ? 'Identifying...' : 'Identify Plant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_selectedImages.isNotEmpty || _identifiedPlant != null) ...[
              SizedBox(height: 12),
              TextButton(onPressed: _clearSelection, child: Text('Clear All')),
            ],
            if (_learningData != null &&
                _learningData!.identifiedPlants.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'Learning Progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total plants identified: ${_learningData!.identifiedPlants.length}',
                      ),
                      Text(
                        'Herbal plants found: ${_learningData!.identifiedPlants.where((p) => p.isHerbal).length}',
                      ),
                      Text(
                        'Unique species: ${_learningData!.plantFrequency.length}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Plant Info Card Screen
class PlantInfoCard extends StatefulWidget {
  final PlantData plant;
  final Function(String) onCorrection;

  PlantInfoCard({required this.plant, required this.onCorrection});

  @override
  _PlantInfoCardState createState() => _PlantInfoCardState();
}

class _PlantInfoCardState extends State<PlantInfoCard> {
  final TextEditingController _correctionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Herbal Plant Info'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_florist,
                          color: Colors.green,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plant.commonName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.plant.scientificName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Plant Images
            if (widget.plant.imagePaths.isNotEmpty) ...[
              Text('Images', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.plant.imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(widget.plant.imagePaths[index]),
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
            ],

            // Description
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(widget.plant.description),
              ),
            ),

            SizedBox(height: 16),

            // Preparation
            Text(
              'Herbal Preparation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.healing, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'How to Prepare',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(widget.plant.preparation),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Always consult with healthcare professionals before using any herbal remedies.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.plant.userNotes != null) ...[
              SizedBox(height: 16),
              Text(
                'Your Notes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(widget.plant.userNotes!),
                ),
              ),
            ],

            SizedBox(height: 20),

            // Feedback Section
            Text(
              'Help Improve Accuracy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Is this identification correct? Your feedback helps the AI learn.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _correctionController,
                      decoration: InputDecoration(
                        labelText: 'Corrections or Additional Info',
                        hintText:
                            'e.g., "This is actually..." or "Also known as..."',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_correctionController.text.isNotEmpty) {
                          widget.onCorrection(_correctionController.text);
                          _correctionController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Feedback submitted! Thank you.'),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.feedback),
                      label: Text('Submit Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
