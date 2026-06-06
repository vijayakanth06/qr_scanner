import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner/app/di.dart';
import 'package:qr_scanner/core/config/college_config.dart';

class CollegePickerScreen extends StatefulWidget {
  const CollegePickerScreen({super.key});

  @override
  State<CollegePickerScreen> createState() => _CollegePickerScreenState();
}

class _CollegePickerScreenState extends State<CollegePickerScreen> {
  List<CollegeConfig> _colleges = <CollegeConfig>[];
  bool _loading = true;
  String? _error;
  String? _hoveredCollegeId;

  String _subtitleFor(String collegeId) {
    switch (collegeId.toLowerCase()) {
      case 'kec':
        return 'Erode, Tamil Nadu';
      case 'psg':
        return 'Coimbatore, Tamil Nadu';
      case 'cbe':
        return 'Coimbatore, Tamil Nadu';
      default:
        return 'Tamil Nadu';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final colleges = await CollegeConfig.loadAll();
      if (!mounted) return;
      setState(() {
        _colleges = colleges;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load colleges. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _selectCollege(CollegeConfig config) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use ${config.collegeName}?'),
        content: Text(
          'This device will be set up for ${config.collegeName}.\nYou can change this later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) return;

    final prefs = sl<SharedPreferences>();
    await prefs.setString('selectedCollegeId', config.collegeId);

    if (getIt.isRegistered<CollegeConfig>()) {
      getIt.unregister<CollegeConfig>();
    }
    getIt.registerSingleton<CollegeConfig>(config);

    await setupCollegeDependencies();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundColor = Color(0xFFF5F7FA);
    const cardColor = Colors.white;
    const cardBorder = Color(0xFFE0E0E0);
    const titleColor = Color(0xFF0D0D0D);
    const subtitleColor = Color(0xFF666666);
    const bodySubtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/app_logo.png',
                width: 80,
                height: 80,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Your College',
                style: const TextStyle(
                  color: titleColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the college this device belongs to.',
                style: const TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator()
              else if (_error != null)
                Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadColleges,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _colleges.length,
                    itemBuilder: (context, index) {
                      final config = _colleges[index];
                      final isHovered = _hoveredCollegeId == config.collegeId;

                      return MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _hoveredCollegeId = config.collegeId;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            if (_hoveredCollegeId == config.collegeId) {
                              _hoveredCollegeId = null;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
                          decoration: BoxDecoration(
                            color: isHovered ? const Color(0xFFF0F4FF) : cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHovered ? accentColor : cardBorder,
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0xFFF0F4FF),
                              highlightColor: const Color(0xFFF0F4FF),
                              onTap: () => _selectCollege(config),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 88),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.school,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              config.collegeName,
                                              style: const TextStyle(
                                                color: titleColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _subtitleFor(config.collegeId),
                                              style: const TextStyle(
                                                color: bodySubtitleColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: accentColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
