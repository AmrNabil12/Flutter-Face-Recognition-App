import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_recognition_service.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FaceRecognitionService _service = FaceRecognitionService(
    projectPath: Directory.current.path,
  );
  final ImagePicker _imagePicker = ImagePicker();

  List<File> _selectedImages = [];
  List<File> _mobileImages = [];
  bool _isProcessing = false;
  String _statusMessage = '';

  bool get _supportsCameraCapture =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (FaceRecognitionService.supportsLocalProcessing) {
      _loadExistingImages();
    }
  }

  Future<void> _loadExistingImages() async {
    final images = await _service.getImagesFromRawFolder();
    setState(() {
      _selectedImages = images;
    });
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _statusMessage = 'Saving images...';
        });

        for (var image in images) {
          final imageFile = File(image.path);
          if (FaceRecognitionService.supportsLocalProcessing) {
            await _service.saveImageToRawImages(imageFile);
          } else {
            _mobileImages.add(imageFile);
          }
        }

        if (FaceRecognitionService.supportsLocalProcessing) {
          await _loadExistingImages();
        }

        setState(() {
          _statusMessage = 'Images saved successfully!';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = '';
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking images: $e';
      });
    }
  }

  Future<void> _captureImageFromCamera() async {
    try {
      if (!_supportsCameraCapture) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Camera capture is supported on Android/iOS only.';
        });
        return;
      }

      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Camera permission is required to capture images.';
        });
        return;
      }

      final image = await _imagePicker.pickImage(source: ImageSource.camera);

      if (image == null) {
        return;
      }

      setState(() {
        _statusMessage = 'Saving captured image...';
      });

      final imageFile = File(image.path);

      if (FaceRecognitionService.supportsLocalProcessing) {
        await _service.saveImageToRawImages(imageFile);
        await _loadExistingImages();
      } else {
        setState(() {
          _mobileImages.add(imageFile);
        });
      }

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Image captured successfully!';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error capturing image: $e';
      });
    }
  }

  Future<void> _runFaceRecognition() async {
    final images = FaceRecognitionService.supportsLocalProcessing
        ? _selectedImages
        : _mobileImages;

    if (images.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 images for comparison'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Initializing...';
    });

    final result = FaceRecognitionService.supportsLocalProcessing
        ? await _service.runFaceRecognition(
            threshold: '1.0',
            onProgress: (message) {
              setState(() {
                _statusMessage = message;
              });
            },
          )
        : await _service.runRemoteFaceRecognition(
            images: images,
            threshold: '1.0',
            onProgress: (message) {
              setState(() {
                _statusMessage = message;
              });
            },
          );

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true) {
      // Navigate to results screen
      if (mounted) {
        final cacheBuster = DateTime.now().millisecondsSinceEpoch;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              resultsContent: result['results'],
              pairsDirPath:
                  '${_service.projectPath}${Platform.pathSeparator}pairs',
              cacheBuster: cacheBuster,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(result['error'] ?? 'Unknown error occurred'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }

    setState(() {
      _statusMessage = '';
    });
  }

  Future<void> _clearImages() async {
    if (!FaceRecognitionService.supportsLocalProcessing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Images'),
          content: const Text('Clear all images and reset the upload list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() {
          _statusMessage = 'Clearing images...';
          _mobileImages = [];
        });

        await _service.clearRemoteImages();

        setState(() {
          _statusMessage = 'Images cleared successfully!';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = '';
            });
          }
        });
      }

      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Images'),
        content: const Text('Are you sure you want to delete all images from RawImages folder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _statusMessage = 'Clearing images...';
      });

      final success = await _service.clearRawImages();

      if (success) {
        await _loadExistingImages();
        setState(() {
          _statusMessage = 'Images cleared successfully!';
        });
      } else {
        setState(() {
          _statusMessage = 'Error clearing images';
        });
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition System'),
        actions: [
          if ((FaceRecognitionService.supportsLocalProcessing && _selectedImages.isNotEmpty) ||
              (!FaceRecognitionService.supportsLocalProcessing && _mobileImages.isNotEmpty))
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all images',
              onPressed: _isProcessing ? null : _clearImages,
            ),
        ],
      ),
      body: Column(
        children: [
          if (!FaceRecognitionService.supportsLocalProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mobile mode: images are uploaded to the local FastAPI server for processing.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          // Status card
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_isProcessing) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Images grid
          Expanded(
            child: (FaceRecognitionService.supportsLocalProcessing
                    ? _selectedImages.isEmpty
                    : _mobileImages.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No images selected',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the buttons below to add images',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FaceRecognitionService.supportsLocalProcessing
                              ? '${_selectedImages.length} image(s) in RawImages folder'
                              : '${_mobileImages.length} image(s) selected for upload',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: FaceRecognitionService.supportsLocalProcessing
                                ? _selectedImages.length
                                : _mobileImages.length,
                            itemBuilder: (context, index) {
                              final imageFile = FaceRecognitionService.supportsLocalProcessing
                                  ? _selectedImages[index]
                                  : _mobileImages[index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  imageFile,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing || !_supportsCameraCapture
                            ? null
                            : _captureImageFromCamera,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ||
                            (FaceRecognitionService.supportsLocalProcessing
                                ? _selectedImages.length < 2
                                : _mobileImages.length < 2)
                        ? null
                        : _runFaceRecognition,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run Recognition'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
