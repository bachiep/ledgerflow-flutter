import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';

abstract interface class AnalyticsRepository {
  Stream<MonthlyAnalyticsSnapshot> watchMonthlyAnalytics(DateTime month);
}
