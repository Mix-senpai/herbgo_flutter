import 'package:flutter/material.dart';
import 'package:herbgo/plant_model.dart';
import 'package:herbgo/data_manager.dart';
import 'dart:io';

class PlantGalleryScreen extends StatefulWidget {
  @override
  _PlantGalleryScreenState createState() => _PlantGalleryScreenState();
}

class _PlantGalleryScreenState extends State<PlantGalleryScreen> {
  final DataManager _dataManager = DataManager();
  List<PlantData> _allPlants = [];
  List<PlantData> _filteredPlants = [];
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'herbal', 'non-herbal'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LearningData learningData = await _dataManager.loadLearningData();
      _allPlants =
          learningData.identifiedPlants.reversed.toList(); // Most recent first
      _applyFilters();
    } catch (e) {
      print('Error loading plants: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredPlants = _allPlants.where((plant) {
      // Search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          plant.commonName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          plant.scientificName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      // Type filter
      bool matchesType = _filterType == 'all' ||
          (_filterType == 'herbal' && plant.isHerbal) ||
          (_filterType == 'non-herbal' && !plant.isHerbal);

      return matchesSearch && matchesType;
    }).toList();

    setState(() {});
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      _filterType = newFilter;
      _applyFilters();
    }
  }

  Future<void> _deletePlant(PlantData plant) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Delete Plant')),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${plant.commonName}" from your collection? This will also remove all associated images.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        LearningData learningData = await _dataManager.loadLearningData();

        // Remove plant from the database
        learningData.identifiedPlants.removeWhere((p) => p.id == plant.id);

        // Update frequency map - decrement the count for this species
        String plantKey = '${plant.commonName}_${plant.scientificName}';
        if (learningData.plantFrequency.containsKey(plantKey)) {
          if (learningData.plantFrequency[plantKey]! <= 1) {
            // This was the last plant of this species, remove the entry entirely
            learningData.plantFrequency.remove(plantKey);
            print('Removed species entirely from frequency map: $plantKey');
          } else {
            // Decrement the count as there are other plants of this species
            learningData.plantFrequency[plantKey] =
                learningData.plantFrequency[plantKey]! - 1;
            print(
                'Decremented frequency count for $plantKey to ${learningData.plantFrequency[plantKey]}');
          }
        } else {
          print('Warning: Plant key $plantKey not found in frequency map');
        }

        // DELETE THE PHYSICAL IMAGE FILES - ADD THIS SECTION
        for (String imagePath in plant.imagePaths) {
          try {
            File imageFile = File(imagePath);
            if (await imageFile.exists()) {
              await imageFile.delete();
              print('Deleted image file: $imagePath');
            }
          } catch (e) {
            print('Error deleting image file $imagePath: $e');
            // Continue with other files even if one fails
          }
        }

        // Save the updated learning data
        await _dataManager.saveLearningData(learningData);
        await _loadPlants();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Plant and images deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting plant: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showPlantDetails(PlantData plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailsScreen(
          plant: plant,
          onPlantUpdated: _loadPlants,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant Gallery'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPlants,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search plants...',
                    prefixIcon: Icon(Icons.search, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onChanged: _onSearchChanged,
                ),
                SizedBox(height: 12),

                // Filter Chips
                Row(
                  children: [
                    Text(
                      'Filter: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            SizedBox(width: 8),
                            _buildFilterChip('Herbal', 'herbal'),
                            SizedBox(width: 8),
                            _buildFilterChip('Non-Herbal', 'non-herbal'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Summary
          if (!_isLoading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${_filteredPlants.length} plant${_filteredPlants.length != 1 ? 's' : ''} found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_allPlants.isNotEmpty)
                    Text(
                      '${_allPlants.where((p) => p.isHerbal).length} herbal',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

          // Plant Grid
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.green[600]),
                        SizedBox(height: 16),
                        Text(
                          'Loading your plant collection...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredPlants.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPlants,
                        color: Colors.green[600],
                        child: GridView.builder(
                          padding: EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio:
                                0.75, // Adjusted to prevent overflow
                          ),
                          itemCount: _filteredPlants.length,
                          itemBuilder: (context, index) {
                            return _buildPlantCard(_filteredPlants[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(value),
      backgroundColor: Colors.white,
      selectedColor: Colors.green[600],
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.green[600]! : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.eco,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No plants match your search'
                  : _allPlants.isEmpty
                      ? 'No plants identified yet'
                      : 'No plants match the selected filter',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms or filters'
                  : _allPlants.isEmpty
                      ? 'Start identifying plants to build your collection!'
                      : 'Try changing the filter or search terms',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            if (_allPlants.isEmpty) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.add_a_photo),
                label: Text('Start Identifying Plants'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlantCard(PlantData plant) {
    return GestureDetector(
      onTap: () => _showPlantDetails(plant),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plant Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                    child: plant.imagePaths.isNotEmpty
                        ? Image.file(
                            File(plant.imagePaths.first),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.eco,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                            ),
                          ),
                  ),

                  // Herbal Badge
                  if (plant.isHerbal)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.healing, color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'Herbal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Multiple Images Indicator
                  if (plant.imagePaths.length > 1)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library,
                                color: Colors.white, size: 9),
                            SizedBox(width: 2),
                            Text(
                              '${plant.imagePaths.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Delete Button
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deletePlant(plant),
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Plant Info - Fixed height to prevent overflow
            Container(
              height: 70, // Fixed height to prevent overflow
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.commonName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          plant.scientificName,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 10, color: Colors.grey[500]),
                      SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _formatDate(plant.identifiedAt),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Plant Details Screen
class PlantDetailsScreen extends StatelessWidget {
  final PlantData plant;
  final VoidCallback onPlantUpdated;

  const PlantDetailsScreen({
    Key? key,
    required this.plant,
    required this.onPlantUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant Details'),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Section
            Container(
              height: 250,
              child: plant.imagePaths.isNotEmpty
                  ? PageView.builder(
                      itemCount: plant.imagePaths.length,
                      itemBuilder: (context, index) {
                        return Image.file(
                          File(plant.imagePaths[index]),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[400],
                                size: 80,
                              ),
                            );
                          },
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.eco,
                        color: Colors.grey[400],
                        size: 80,
                      ),
                    ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plant Name Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plant.commonName,
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
                              plant.scientificName,
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
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: plant.isHerbal
                              ? Colors.green[100]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: plant.isHerbal
                                ? Colors.green[300]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              plant.isHerbal
                                  ? Icons.healing
                                  : Icons.info_outline,
                              size: 16,
                              color: plant.isHerbal
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                            ),
                            SizedBox(width: 6),
                            Text(
                              plant.isHerbal ? 'Herbal' : 'Non-Herbal',
                              style: TextStyle(
                                color: plant.isHerbal
                                    ? Colors.green[700]
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Description
                  _buildSection(
                    context,
                    'Description',
                    plant.description,
                    Icons.description,
                  ),

                  if (plant.isHerbal) ...[
                    SizedBox(height: 20),
                    _buildSection(
                      context,
                      'Herbal Preparation',
                      plant.preparation,
                      Icons.healing,
                      showWarning: true,
                    ),
                  ],

                  if (plant.userNotes != null) ...[
                    SizedBox(height: 20),
                    _buildSection(
                      context,
                      'Your Notes',
                      plant.userNotes!,
                      Icons.note,
                    ),
                  ],

                  SizedBox(height: 20),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon, {
    bool showWarning = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green[600]),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
            if (showWarning) ...[
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
