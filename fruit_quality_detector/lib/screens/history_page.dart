import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fruit_quality_detector/theme/app_theme.dart';
import 'package:fruit_quality_detector/widgets/empty_state.dart';
import 'package:fruit_quality_detector/home_page.dart';
import 'package:fruit_quality_detector/screens/results_page.dart';
import 'package:fruit_quality_detector/utils/page_transitions.dart';

class HistoryPage extends StatelessWidget {
  final List<AnalysisHistory> history;

  const HistoryPage({super.key, required this.history});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? EmptyState(
                icon: Icons.history_rounded,
                title: 'No History Yet',
                message:
                    'Your analysis history will appear here.\nStart analyzing fruits to build your history.',
                actionText: 'Start Analyzing',
                onAction: () => Navigator.of(context).pop(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return ListView.builder(
                    padding: AppResponsive.responsivePadding(context),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return _buildHistoryCard(context, item);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, AnalysisHistory item) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final imageFile = File(item.imagePath);
    final imageExists = imageFile.existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: imageExists
            ? () {
                Navigator.of(context).push(
                  ScaleFadePageRoute(
                    page: ResultsPage(
                      image: imageFile,
                      fruitType: item.fruitType,
                      ripeness: item.ripeness,
                      disease: item.disease,
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: EdgeInsets.all(
            AppResponsive.isMobile(context) ? 12.0 : 16.0,
          ),
          child: Row(
            children: [
              // Image Thumbnail
              Hero(
                tag: 'fruit_image_${item.imagePath}',
                child: Container(
                  width: AppResponsive.isMobile(context) ? 80 : 100,
                  height: AppResponsive.isMobile(context) ? 80 : 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surfaceDark,
                    border: Border.all(color: AppColors.borderDark, width: 1),
                  ),
                  child: imageExists
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.textTertiary,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textTertiary,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fruitType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusChip(
                          item.ripeness,
                          _getRipenessColor(item.ripeness),
                        ),
                        _buildStatusChip(
                          item.disease,
                          _getDiseaseColor(item.disease),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateFormat.format(item.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
