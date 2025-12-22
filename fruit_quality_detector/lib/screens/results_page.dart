import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fruit_quality_detector/theme/app_theme.dart';
import 'package:fruit_quality_detector/widgets/gradient_button.dart';

class ResultsPage extends StatelessWidget {
  final File image;
  final String fruitType;
  final String ripeness;
  final String disease;

  const ResultsPage({
    super.key,
    required this.image,
    required this.fruitType,
    required this.ripeness,
    required this.disease,
  });

  String _getFruitDescription(String fruit) {
    final fruitLower = fruit.toLowerCase().trim();
    final descriptions = {
      'apple':
          'Apples are rich in fiber, vitamin C, and antioxidants that support heart health and aid digestion.',
      'banana':
          'Bananas provide potassium, vitamin B6, and quick energy, perfect for maintaining healthy blood pressure.',
      'orange':
          'Oranges are packed with vitamin C, boosting immune function and promoting healthy skin.',
      'mango':
          'Mangoes are tropical fruits rich in vitamins A and C, supporting immune function and eye health.',
      'strawberry':
          'Strawberries are loaded with vitamin C and antioxidants that may improve heart health.',
      'grape':
          'Grapes contain resveratrol and antioxidants that benefit heart health and brain function.',
      'watermelon':
          'Watermelon hydrates and provides vitamins A and C, plus the antioxidant lycopene.',
      'pineapple':
          'Pineapples contain bromelain, supporting digestion and reducing inflammation.',
      'pear':
          'Pears are rich in fiber and vitamin C, supporting digestive health.',
      'peach':
          'Peaches provide vitamins A and C, supporting skin health and immune function.',
      'plum':
          'Plums are packed with antioxidants, supporting bone and digestive health.',
      'cherry':
          'Cherries may improve sleep quality and reduce muscle pain with their antioxidants.',
      'kiwi':
          'Kiwis have more vitamin C than oranges, supporting immunity and digestion.',
      'tomato':
          'Tomatoes are rich in lycopene, vitamin C, and potassium for heart health.',
    };

    for (var key in descriptions.keys) {
      if (fruitLower.contains(key)) {
        return descriptions[key]!;
      }
    }

    return 'This nutritious fruit provides essential vitamins and minerals that support overall health.';
  }

  String _getRipenessExplanation(String ripeness) {
    final ripenessLower = ripeness.toLowerCase().trim();

    if (ripenessLower.contains('ripe') &&
        !ripenessLower.contains('unripe') &&
        !ripenessLower.contains('over')) {
      return 'Perfect for consumption! Optimal ripeness with the best flavor and nutritional value. Enjoy within 1-2 days.';
    } else if (ripenessLower.contains('unripe')) {
      return 'Not yet ready. Store at room temperature for a few days to allow natural ripening.';
    } else if (ripenessLower.contains('over')) {
      return 'Past its prime. Best used quickly in smoothies or baking where texture is less important.';
    }

    return 'Ripeness level analyzed. Check firmness, color, and smell before consuming.';
  }

  String _getDiseaseExplanation(String disease) {
    final diseaseLower = disease.toLowerCase().trim();

    if (diseaseLower.contains('healthy') ||
        diseaseLower.contains('no disease') ||
        diseaseLower == '0') {
      return 'Excellent! No signs of disease detected. The fruit appears healthy and safe for consumption.';
    } else if (diseaseLower.contains('scab')) {
      return 'Scab detected. While it affects appearance, the fruit is generally safe if affected areas are removed.';
    } else if (diseaseLower.contains('rot')) {
      return 'Signs of rot detected. Remove affected areas or discard if extensive.';
    } else if (diseaseLower.contains('rust') || diseaseLower.contains('spot')) {
      return 'Disease detected. Remove affected spots and consume the rest promptly.';
    }

    return 'Disease analysis complete. Examine carefully for discoloration or unusual odors.';
  }

  Color _getRipenessColor(String ripeness) {
    final ripenessLower = ripeness.toLowerCase().trim();
    if (ripenessLower.contains('ripe') &&
        !ripenessLower.contains('unripe') &&
        !ripenessLower.contains('over')) {
      return AppColors.success;
    } else if (ripenessLower.contains('unripe')) {
      return AppColors.warning;
    } else if (ripenessLower.contains('over')) {
      return AppColors.error;
    }
    return AppColors.info;
  }

  Color _getDiseaseColor(String disease) {
    final diseaseLower = disease.toLowerCase().trim();
    if (diseaseLower.contains('healthy') ||
        diseaseLower.contains('no disease') ||
        diseaseLower == '0') {
      return AppColors.success;
    }
    return AppColors.error;
  }

  IconData _getResultIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fruit':
        return Icons.apple_rounded;
      case 'ripeness':
        return Icons.eco_rounded;
      case 'disease':
        return Icons.health_and_safety_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: AppResponsive.responsivePadding(context),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppResponsive.maxContentWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Preview
                      Hero(
                        tag: 'fruit_image_${image.path}',
                        child: Container(
                          height: AppResponsive.isMobile(context) ? 250 : 350,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Fruit Type Card
                      _buildResultCard(
                        context,
                        category: 'Fruit',
                        title: 'Fruit Identification',
                        result: fruitType.trim(),
                        description: _getFruitDescription(fruitType),
                        icon: _getResultIcon('fruit'),
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 16),

                      // Ripeness Card
                      _buildResultCard(
                        context,
                        category: 'Ripeness',
                        title: 'Ripeness Analysis',
                        result: ripeness.trim(),
                        description: _getRipenessExplanation(ripeness),
                        icon: _getResultIcon('ripeness'),
                        color: _getRipenessColor(ripeness),
                      ),
                      const SizedBox(height: 16),

                      // Disease Card
                      _buildResultCard(
                        context,
                        category: 'Disease',
                        title: 'Health Status',
                        result: disease.trim(),
                        description: _getDiseaseExplanation(disease),
                        icon: _getResultIcon('disease'),
                        color: _getDiseaseColor(disease),
                      ),
                      const SizedBox(height: 32),

                      // Action Button
                      GradientButton(
                        text: 'Analyze Another Fruit',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                        height: 56,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context, {
    required String category,
    required String title,
    required String result,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.isMobile(context) ? 20.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
