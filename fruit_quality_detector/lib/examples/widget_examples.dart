import 'package:flutter/material.dart';
import 'package:fruit_quality_detector/theme/app_theme.dart';
import 'package:fruit_quality_detector/widgets/gradient_button.dart';
import 'package:fruit_quality_detector/widgets/loading_overlay.dart';
import 'package:fruit_quality_detector/widgets/empty_state.dart';
import 'package:fruit_quality_detector/widgets/modern_text_field.dart';
import 'package:fruit_quality_detector/utils/page_transitions.dart';

/// Widget Examples and Usage Reference
///
/// This file demonstrates how to use all the custom widgets
/// and utilities created for the modern UI/UX design.
///
/// DO NOT include this file in production builds.
/// It's for reference and testing only.

class WidgetExamplesPage extends StatefulWidget {
  const WidgetExamplesPage({super.key});

  @override
  State<WidgetExamplesPage> createState() => _WidgetExamplesPageState();
}

class _WidgetExamplesPageState extends State<WidgetExamplesPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showLoadingOverlay = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Examples')),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: AppResponsive.responsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Gradient Buttons
                  _buildSectionTitle('Gradient Buttons'),
                  const SizedBox(height: 16),

                  GradientButton(
                    text: 'Primary Button',
                    onPressed: () {},
                    height: 56,
                  ),
                  const SizedBox(height: 12),

                  GradientButton(
                    text: 'With Icon',
                    icon: Icons.check_circle_rounded,
                    onPressed: () {},
                    height: 56,
                  ),
                  const SizedBox(height: 12),

                  GradientButton(
                    text: 'Loading State',
                    onPressed: () {},
                    isLoading: true,
                    height: 56,
                  ),
                  const SizedBox(height: 12),

                  GradientButton(
                    text: 'Disabled',
                    onPressed: null, // Disabled when null
                    height: 56,
                  ),
                  const SizedBox(height: 12),

                  GradientButton(
                    text: 'Outlined Style',
                    outlined: true,
                    onPressed: () {},
                    height: 56,
                  ),
                  const SizedBox(height: 32),

                  // Section: Modern Text Fields
                  _buildSectionTitle('Modern Text Fields'),
                  const SizedBox(height: 16),

                  ModernTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  ModernTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: PasswordVisibilityToggle(
                      isVisible: !_obscurePassword,
                      onToggle: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section: Color Palette
                  _buildSectionTitle('Color Palette'),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildColorChip('Primary', AppColors.primary),
                      _buildColorChip('Accent', AppColors.accent),
                      _buildColorChip('Success', AppColors.success),
                      _buildColorChip('Warning', AppColors.warning),
                      _buildColorChip('Error', AppColors.error),
                      _buildColorChip('Info', AppColors.info),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Section: Cards
                  _buildSectionTitle('Cards'),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Card Title',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Subtitle text',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                              'This is a modern card with gradient icon and description area.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section: Loading & Empty States
                  _buildSectionTitle('Loading & Empty States'),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      setState(() => _showLoadingOverlay = true);
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          setState(() => _showLoadingOverlay = false);
                        }
                      });
                    },
                    child: const Text('Show Loading Overlay'),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        ScaleFadePageRoute(
                          page: Scaffold(
                            appBar: AppBar(title: const Text('Empty State')),
                            body: EmptyState(
                              icon: Icons.inbox_rounded,
                              title: 'No Data',
                              message: 'This is an example empty state widget.',
                              actionText: 'Retry',
                              onAction: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Show Empty State'),
                  ),
                  const SizedBox(height: 32),

                  // Section: Page Transitions
                  _buildSectionTitle('Page Transitions'),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        FadePageRoute(page: _buildDemoPage('Fade')),
                      );
                    },
                    child: const Text('Fade Transition'),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(page: _buildDemoPage('Slide')),
                      );
                    },
                    child: const Text('Slide Transition'),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        ScaleFadePageRoute(page: _buildDemoPage('Scale Fade')),
                      );
                    },
                    child: const Text('Scale Fade Transition'),
                  ),
                  const SizedBox(height: 32),

                  // Section: Responsive Utilities
                  _buildSectionTitle('Responsive Utilities'),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Device Type', _getDeviceType(context)),
                          const Divider(height: 24),
                          _buildInfoRow(
                            'Screen Width',
                            '${MediaQuery.of(context).size.width.toInt()}px',
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            'Max Content Width',
                            '${AppResponsive.maxContentWidth(context).toInt()}px',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Loading Overlay Demo
          LoadingOverlay(
            message: 'Processing...',
            isVisible: _showLoadingOverlay,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget _buildColorChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getDeviceType(BuildContext context) {
    if (AppResponsive.isDesktop(context)) return 'Desktop (≥900px)';
    if (AppResponsive.isTablet(context)) return 'Tablet (600-900px)';
    return 'Mobile (<600px)';
  }

  Widget _buildDemoPage(String transitionType) {
    return Scaffold(
      appBar: AppBar(title: Text('$transitionType Transition')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: AppColors.success,
            ),
            const SizedBox(height: 24),
            Text(
              'Page Loaded!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Using $transitionType transition',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
