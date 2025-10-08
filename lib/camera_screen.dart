import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final Function(List<File>) onImagesCapture;
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.onImagesCapture,
    required this.cameras,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isRearCamera = true;
  final List<File> _capturedImages = [];
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized || _cameraController == null) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'This app needs camera access to identify plants. Please grant camera permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    final camera = _isRearCamera ? widget.cameras.first : widget.cameras.last;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _cameraController == null || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      setState(() {
        _capturedImages.add(imageFile);
        _isCapturing = false;
      });

      // Show capture feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Photo captured! ${_capturedImages.length} image(s) taken'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      print('Error capturing image: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;

    setState(() {
      _isRearCamera = !_isRearCamera;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    await _initializeCamera();
  }

  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  void _finishCapture() {
    if (_capturedImages.isNotEmpty) {
      widget.onImagesCapture(_capturedImages);
      Navigator.pop(context);
    }
  }

  Future<void> _addFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _capturedImages.addAll(
          images.map((xFile) => File(xFile.path)).toList(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  // Flash Button
                  GestureDetector(
                    onTap: _toggleFlash,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Camera Switch Button
                  if (widget.cameras.length > 1)
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flip_camera_ios,
                            color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Captured Images Counter
          if (_capturedImages.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_capturedImages.length} captured',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Captured Images Thumbnails
                  if (_capturedImages.isNotEmpty) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _capturedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _capturedImages[index],
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
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
                    const SizedBox(height: 20),
                  ],

                  // Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery Button
                      GestureDetector(
                        onTap: _addFromGallery,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library,
                              color: Colors.white, size: 30),
                        ),
                      ),

                      // Capture Button
                      GestureDetector(
                        onTap: _captureImage,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: 4),
                          ),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isCapturing ? Colors.red : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                                ? const Icon(Icons.stop,
                                    color: Colors.white, size: 30)
                                : null,
                          ),
                        ),
                      ),

                      // Done Button
                      GestureDetector(
                        onTap:
                            _capturedImages.isNotEmpty ? _finishCapture : null,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _capturedImages.isNotEmpty
                                ? Colors.green
                                : Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Instructions
                  Text(
                    _capturedImages.isEmpty
                        ? 'Capture multiple angles of the plant'
                        : 'Tap ✓ to identify or capture more photos',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Focus indicator
          if (_isCapturing)
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
