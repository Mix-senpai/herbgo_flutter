import 'package:flutter/material.dart';
import 'package:herbgo/ai_services.dart';
import 'package:herbgo/data_manager.dart';
import 'package:herbgo/plant_model.dart';
import 'package:herbgo/camera_screen.dart';
import 'package:herbgo/plant_gallery.dart'; // Add this import
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

// Global variable for cameras
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Error initializing cameras: $e');
  }
  
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
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Image Source',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 20),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: Colors.green[700]),
              ),
              title: Text('Professional Camera'),
              subtitle: Text('Take multiple photos with advanced controls'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _openCamera();
              },
            ),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.blue[700]),
              ),
              title: Text('Photo Library'),
              subtitle: Text('Select existing photos from gallery'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera, color: Colors.orange[700]),
              ),
              title: Text('Quick Camera'),
              subtitle: Text('Take a single photo quickly'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _quickCamera();
              },
            ),
            
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    if (cameras.isEmpty) {
      _showErrorDialog('No cameras available on this device.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          cameras: cameras,
          onImagesCapture: (List<File> capturedImages) {
            setState(() {
              _selectedImages = capturedImages;
            });
          },
        ),
      ),
    );
  }

  Future<void> _quickCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedImages = [File(image.path)];
      });
    }
  }

  Future<void> _pickFromGallery() async {
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
        // Reload learning data to reflect changes
        await _loadLearningData();

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
          'Unable to identify the plant with confidence. Please try again with clearer images or different angles.',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Plant Identified'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Common Name:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(plant.commonName, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                    'Scientific Name:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    plant.scientificName,
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'This plant is not identified as having herbal/medicinal properties.',
                style: TextStyle(color: Colors.orange[800]),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantGalleryScreen(),
      ),
    ).then((_) {
      // Refresh learning data when returning from gallery
      _loadLearningData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Herbal Plant Identifier'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openGallery,
            icon: Icon(Icons.photo_library),
            tooltip: 'View Plant Gallery',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_florist, size: 48, color: Colors.green[700]),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Identify Herbal Plants',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Capture or select photos of plants to identify if they have herbal properties',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            
            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: Icon(Icons.add_a_photo),
                    label: Text('Capture Images'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openGallery,
                  icon: Icon(Icons.collections),
                  label: Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
            
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Images (${_selectedImages.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: Icon(Icons.clear_all, size: 18),
                    label: Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImages[index],
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red[600],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Notes (Optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Any observations about the plant, location, conditions...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green[600]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _selectedImages.isNotEmpty && !_isLoading
                  ? _identifyPlant
                  : null,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.search),
              label: Text(_isLoading ? 'Identifying Plant...' : 'Identify Plant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: _selectedImages.isNotEmpty ? 4 : 1,
              ),
            ),
            
            if (_learningData != null &&
                _learningData!.identifiedPlants.isNotEmpty) ...[
              SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, color: Colors.blue[600], size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Learning Progress',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _openGallery,
                            child: Text('View All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Plants',
                              '${_learningData!.identifiedPlants.length}',
                              Icons.eco,
                              Colors.green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Herbal Found',
                              '${_learningData!.identifiedPlants.where((p) => p.isHerbal).length}',
                              Icons.healing,
                              Colors.purple,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Species',
                              '${_learningData!.plantFrequency.length}',
                              Icons.nature,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (_learningData!.identifiedPlants.where((p) => p.isHerbal).isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          'Recent Herbal Plants:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        ..._learningData!.identifiedPlants
                            .where((p) => p.isHerbal)
                            .take(3)
                            .map((plant) => Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.local_florist, size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      plant.commonName,
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${DateTime.now().difference(plant.identifiedAt).inDays}d ago',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Plant Info Card Screen (keeping your existing implementation)
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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_florist,
                            color: Colors.green[700],
                            size: 32,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plant.commonName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                              ),
                              SizedBox(height: 4),
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
              Text(
                'Images',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.plant.imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  widget.plant.description,
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Preparation
            Text(
              'Herbal Preparation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.healing, color: Colors.green[600]),
                        SizedBox(width: 8),
                        Text(
                          'How to Prepare',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.plant.preparation,
                      style: TextStyle(height: 1.5),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[600], size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Always consult with healthcare professionals before using any herbal remedies.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                height: 1.4,
                              ),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    widget.plant.userNotes!,
                    style: TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],

            SizedBox(height: 20),

            // Feedback Section
            Text(
              'Help Improve Accuracy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Is this identification correct? Your feedback helps the AI learn.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _correctionController,
                      decoration: InputDecoration(
                        labelText: 'Corrections or Additional Info',
                        hintText:
                            'e.g., "This is actually..." or "Also known as..."',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[600]!),
                        ),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_correctionController.text.isNotEmpty) {
                          widget.onCorrection(_correctionController.text);
                          _correctionController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Feedback submitted! Thank you.'),
                                ],
                              ),
                              backgroundColor: Colors.green[600],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.feedback),
                      label: Text('Submit Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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