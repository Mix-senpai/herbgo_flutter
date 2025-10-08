import 'package:flutter/material.dart';
import 'package:herbgo/plant_model.dart';
import 'package:herbgo/data_manager.dart';
import 'dart:io';

class PlantGalleryScreen extends StatefulWidget {
  const PlantGalleryScreen({super.key});

  @override
  _PlantGalleryScreenState createState() => _PlantGalleryScreenState();
}

class _PlantGalleryScreenState extends State<PlantGalleryScreen> {
  final DataManager _dataManager = DataManager();
  List<PlantData> _allPlants = [];
  List<PlantData> _filteredPlants = [];
  String _searchQuery = '';
  String _filterType = 'all';
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
      _allPlants = learningData.identifiedPlants.reversed.toList();
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
      bool matchesSearch = _searchQuery.isEmpty ||
          plant.commonName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          plant.scientificName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

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
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Delete Plant')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${plant.commonName}" from your collection?',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will remove the plant from the AI\'s knowledge base.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        LearningData learningData = await _dataManager.loadLearningData();
        await _dataManager.deletePlant(plant.id, learningData);
        await _loadPlants();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Plant deleted from knowledge base'),
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
        title: const Text('Plant Gallery'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlants,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Filter: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Herbal', 'herbal'),
                            const SizedBox(width: 8),
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
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${_filteredPlants.length} plant${_filteredPlants.length != 1 ? 's' : ''} in knowledge base',
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
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.green[600]),
                        const SizedBox(height: 16),
                        Text(
                          'Loading knowledge base...',
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
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No plants match your search'
                  : _allPlants.isEmpty
                      ? 'Knowledge base is empty'
                      : 'No plants match the selected filter',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : _allPlants.isEmpty
                      ? 'Start identifying plants to build the knowledge base'
                      : 'Try changing the filter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            if (_allPlants.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Start Identifying Plants'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
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
                  if (plant.isHerbal)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
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
                  if (plant.imagePaths.length > 1)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library,
                                color: Colors.white, size: 9),
                            const SizedBox(width: 2),
                            Text(
                              '${plant.imagePaths.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deletePlant(plant),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
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
            Container(
              height: 70,
              padding: const EdgeInsets.all(8),
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
                        const SizedBox(height: 2),
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
                      const SizedBox(width: 3),
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

// Plant Details Screen with Edit/Update options
class PlantDetailsScreen extends StatefulWidget {
  final PlantData plant;
  final VoidCallback onPlantUpdated;

  const PlantDetailsScreen({
    super.key,
    required this.plant,
    required this.onPlantUpdated,
  });

  @override
  _PlantDetailsScreenState createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  final DataManager _dataManager = DataManager();
  bool _isEditing = false;
  late TextEditingController _descriptionController;
  late TextEditingController _preparationController;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.plant.description);
    _preparationController =
        TextEditingController(text: widget.plant.preparation);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _preparationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    try {
      LearningData learningData = await _dataManager.loadLearningData();

      PlantData updatedPlant = PlantData(
        id: widget.plant.id,
        commonName: widget.plant.commonName,
        scientificName: widget.plant.scientificName,
        description: _descriptionController.text,
        preparation: _preparationController.text,
        isHerbal: widget.plant.isHerbal,
        imagePaths: widget.plant.imagePaths,
        identifiedAt: DateTime.now(),
        userNotes: widget.plant.userNotes,
      );

      await _dataManager.updatePlantIdentification(updatedPlant, learningData);

      setState(() {
        _isEditing = false;
      });

      widget.onPlantUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check, color: Colors.white),
              SizedBox(width: 8),
              Text('Plant information updated'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating plant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Details'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit Plant Info',
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _descriptionController.text = widget.plant.description;
                      _preparationController.text = widget.plant.preparation;
                    });
                  },
                  tooltip: 'Cancel',
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveChanges,
                  tooltip: 'Save Changes',
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 250,
              child: widget.plant.imagePaths.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.plant.imagePaths.length,
                      itemBuilder: (context, index) {
                        return Image.file(
                          File(widget.plant.imagePaths[index]),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                            const SizedBox(height: 4),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.plant.isHerbal
                              ? Colors.green[100]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.plant.isHerbal
                                ? Colors.green[300]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.plant.isHerbal
                                  ? Icons.healing
                                  : Icons.info_outline,
                              size: 16,
                              color: widget.plant.isHerbal
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.plant.isHerbal ? 'Herbal' : 'Non-Herbal',
                              style: TextStyle(
                                color: widget.plant.isHerbal
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
                  const SizedBox(height: 24),
                  _buildEditableSection(
                    context,
                    'Description',
                    _descriptionController,
                    Icons.description,
                    maxLines: 5,
                  ),
                  if (widget.plant.isHerbal) ...[
                    const SizedBox(height: 20),
                    _buildEditableSection(
                      context,
                      'Herbal Preparation',
                      _preparationController,
                      Icons.healing,
                      showWarning: true,
                      maxLines: 8,
                    ),
                  ],
                  if (widget.plant.userNotes != null) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      'Your Notes',
                      widget.plant.userNotes!,
                      Icons.note,
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableSection(
    BuildContext context,
    String title,
    TextEditingController controller,
    IconData icon, {
    bool showWarning = false,
    int maxLines = 3,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isEditing
                ? TextField(
                    controller: controller,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green[600]!),
                      ),
                    ),
                  )
                : Text(
                    controller.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
            if (showWarning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 12),
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

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
