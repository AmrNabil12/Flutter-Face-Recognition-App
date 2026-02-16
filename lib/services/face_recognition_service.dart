import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for handling face recognition operations
class FaceRecognitionService {
  final String projectPath;

  static bool get supportsLocalProcessing => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  FaceRecognitionService({required this.projectPath});

  /// Runs the Python face recognition script
  Future<Map<String, dynamic>> runFaceRecognition({
    String threshold = '1.0',
    String? device,
    Function(String)? onProgress,
  }) async {
    try {
      if (!supportsLocalProcessing) {
        return {
          'success': false,
          'error': 'Local processing is only supported on desktop platforms.',
        };
      }

      onProgress?.call('Starting face recognition process...');
      
      // Command to run the Python script
      final result = await Process.run(
        'python',
        [
          'Face_Recognition_System.py',
          if (device != null) ...['--device', device],
          '--threshold',
          threshold,
          '--results-file',
          'results.txt',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      onProgress?.call('Python script completed');

      if (result.exitCode != 0) {
        return {
          'success': false,
          'error': result.stderr.toString(),
          'output': result.stdout.toString(),
        };
      }

      onProgress?.call('Reading results...');
      
      // Read results from results.txt
      final resultsFile = File('$projectPath${Platform.pathSeparator}results.txt');
      
      if (!await resultsFile.exists()) {
        return {
          'success': false,
          'error': 'Results file not found',
        };
      }

      final resultsContent = await resultsFile.readAsString();
      
      return {
        'success': true,
        'output': result.stdout.toString(),
        'results': resultsContent,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Saves an image to the RawImages folder
  Future<bool> saveImageToRawImages(File imageFile) async {
    if (!supportsLocalProcessing) {
      return false;
    }

    try {
      final rawImagesDir = Directory('$projectPath${Platform.pathSeparator}RawImages');
      
      if (!await rawImagesDir.exists()) {
        await rawImagesDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.uri.pathSegments.last}';
      final destinationPath = '${rawImagesDir.path}${Platform.pathSeparator}$fileName';
      
      await imageFile.copy(destinationPath);
      
      return true;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return false;
    }
  }

  /// Gets all images from RawImages folder
  Future<List<File>> getImagesFromRawFolder() async {
    if (!supportsLocalProcessing) {
      return [];
    }

    try {
      final rawImagesDir = Directory('$projectPath${Platform.pathSeparator}RawImages');
      
      if (!await rawImagesDir.exists()) {
        return [];
      }

      final entities = await rawImagesDir.list().toList();
      final imageFiles = entities
          .whereType<File>()
          .where((file) {
            final extension = file.path.toLowerCase();
            return extension.endsWith('.jpg') ||
                   extension.endsWith('.jpeg') ||
                   extension.endsWith('.png');
          })
          .toList();

      return imageFiles;
    } catch (e) {
      debugPrint('Error getting images: $e');
      return [];
    }
  }

  /// Clears all images from RawImages folder
  Future<bool> clearRawImages() async {
    if (!supportsLocalProcessing) {
      return false;
    }

    try {
      final rawImagesDir = Directory('$projectPath${Platform.pathSeparator}RawImages');
      
      if (!await rawImagesDir.exists()) {
        return true;
      }

      final entities = await rawImagesDir.list().toList();
      
      for (var entity in entities) {
        if (entity is File) {
          await entity.delete();
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error clearing images: $e');
      return false;
    }
  }

  /// Parses the results.txt file into structured data
  static List<ComparisonResult> parseResults(String resultsContent) {
    final results = <ComparisonResult>[];
    final lines = resultsContent.split('\n');
    
    for (var line in lines) {
      // Match pattern: "1.jpg vs 2.jpg -> 0.7141 (SAME)"
      final regex = RegExp(r'(\S+\.jpg)\s+vs\s+(\S+\.jpg)\s+->\s+(\d+\.\d+)\s+\((\w+)\)');
      final match = regex.firstMatch(line);
      
      if (match != null) {
        results.add(ComparisonResult(
          image1: match.group(1)!,
          image2: match.group(2)!,
          distance: double.parse(match.group(3)!),
          isSame: match.group(4)! == 'SAME',
        ));
      }
    }
    
    return results;
  }

  Future<Map<String, dynamic>> runRemoteFaceRecognition({
    required List<File> images,
    String threshold = '1.0',
    Function(String)? onProgress,
  }) async {
    if (images.length < 2) {
      return {
        'success': false,
        'error': 'Please upload at least two images.',
      };
    }

    try {
      onProgress?.call('Uploading images to server...');

      final uri = Uri.parse('$apiBaseUrl/compare');
      final request = http.MultipartRequest('POST', uri)
        ..fields['threshold'] = threshold;

      for (final image in images) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Server error (${response.statusCode}): ${response.body}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true) {
        return {
          'success': false,
          'error': data['error'] ?? 'Unknown server error',
          'output': data['output'] ?? '',
        };
      }

      return {
        'success': true,
        'results': data['results'] ?? '',
        'output': data['output'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<bool> clearRemoteImages() async {
    try {
      final uri = Uri.parse('$apiBaseUrl/clear');
      final response = await http.post(uri);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Model for comparison results
class ComparisonResult {
  final String image1;
  final String image2;
  final double distance;
  final bool isSame;

  ComparisonResult({
    required this.image1,
    required this.image2,
    required this.distance,
    required this.isSame,
  });
}
