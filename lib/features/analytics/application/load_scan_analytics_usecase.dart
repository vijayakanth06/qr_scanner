import 'package:qr_scanner/features/analytics/data/scan_analytics_service.dart';

class LoadScanAnalyticsUseCase {
  LoadScanAnalyticsUseCase(this.analyticsService);

  final ScanAnalyticsService analyticsService;

  Future<ScanAnalytics> call() {
    return analyticsService.load();
  }
}
