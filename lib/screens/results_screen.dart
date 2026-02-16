import 'dart:io';
import 'package:flutter/material.dart';
import '../services/face_recognition_service.dart';

class ResultsScreen extends StatelessWidget {
  final String resultsContent;
  final String pairsDirPath;
  final int cacheBuster;

  ResultsScreen({
    super.key,
    required this.resultsContent,
    String? pairsDirPath,
    int? cacheBuster,
  })  : pairsDirPath = pairsDirPath ??
            '${Directory.current.path}${Platform.pathSeparator}pairs',
        cacheBuster = cacheBuster ?? DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final results = FaceRecognitionService.parseResults(resultsContent);
    final lines = resultsContent.split('\n');
    
    // Extract summary info
    int totalComparisons = 0;
    int samePerson = 0;
    int differentPersons = 0;

    for (var line in lines) {
      if (line.contains('Total comparisons:')) {
        totalComparisons = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      } else if (line.contains('Same person:')) {
        samePerson = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      } else if (line.contains('Different persons:')) {
        differentPersons = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recognition Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Results'),
                  content: const Text(
                    'The distance value indicates how similar two faces are.\n\n'
                    '• Lower values = More similar\n'
                    '• Values < 1.0 = Same person\n'
                    '• Values ≥ 1.0 = Different persons\n\n'
                    'The threshold can be adjusted based on your requirements.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total',
                      totalComparisons.toString(),
                      Icons.compare_arrows,
                    ),
                    _buildSummaryItem(
                      'Same',
                      samePerson.toString(),
                      Icons.check_circle,
                    ),
                    _buildSummaryItem(
                      'Different',
                      differentPersons.toString(),
                      Icons.cancel,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('No comparison results found'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return _buildResultCard(result);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ComparisonResult result) {
    final color = result.isSame ? Colors.green : Colors.red;
    final icon = result.isSame ? Icons.check_circle : Icons.cancel;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.image1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.compare_arrows, size: 16),
                      ),
                      Expanded(
                        child: Text(
                          result.image2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPairImage(result.image1),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.compare_arrows, size: 16),
                      ),
                      _buildPairImage(result.image2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distance: ${result.distance.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          result.isSame ? 'SAME' : 'DIFFERENT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildPairImage(String imageName) {
    final directFile = File(imageName);
    final imageFile = directFile.existsSync()
        ? directFile
        : File('$pairsDirPath${Platform.pathSeparator}$imageName');
    final useNetwork = !FaceRecognitionService.supportsLocalProcessing;

    return Tooltip(
      message: imageName,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: useNetwork
            ? Image.network(
                '${FaceRecognitionService.apiBaseUrl}/pairs/$imageName?v=$cacheBuster',
                key: ValueKey('$imageName-$cacheBuster'),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildMissingImage();
                },
              )
            : _buildLocalImage(imageFile),
      ),
    );
  }

  Widget _buildLocalImage(File imageFile) {
    final fileImage = FileImage(imageFile);
    if (imageFile.existsSync()) {
      fileImage.evict();
    }

    return Image(
      key: ValueKey('${imageFile.path}-$cacheBuster'),
      image: fileImage,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildMissingImage();
      },
    );
  }

  Widget _buildMissingImage() {
    return Container(
      width: 64,
      height: 64,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey.shade500,
      ),
    );
  }
}
