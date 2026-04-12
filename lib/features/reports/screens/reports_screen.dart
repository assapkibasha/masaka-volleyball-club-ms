import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/printing/report_printer.dart';
import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late String _selectedYear;
  String? _selectedPeriod;
  late Future<_ReportsData> _future;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.toString();
    _future = _load();
  }

  Future<_ReportsData> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);

    final periods = await api.getPeriods(token);
    _selectedPeriod ??= periods.isNotEmpty
        ? (periods.first as Map<String, dynamic>)['label'] as String?
        : null;

    final yearly = await api.getYearlyReport(token, int.parse(_selectedYear));
    final monthly = await api.getMonthlyReport(token, period: _selectedPeriod);

    return _ReportsData(periods: periods, yearly: yearly, monthly: monthly);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _printMonthlyReport(Map<String, dynamic> report) async {
    try {
      await printMonthlyReport(report);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Reports',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primaryBlack,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedYear,
              underline: const SizedBox(),
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlack,
              ),
              items: List.generate(5, (index) {
                final year = (DateTime.now().year - index).toString();
                return DropdownMenuItem(value: year, child: Text(year));
              }),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedYear = value;
                  _future = _load();
                });
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: FutureBuilder<_ReportsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final yearly = data.yearly;
          final monthly = data.monthly;
          final monthlySeries =
              (yearly['monthlySeries'] as List<dynamic>? ?? const []);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            label: 'Total Expected',
                            value: _money(yearly['expectedTotal']),
                            leftBorder: AppColors.primaryYellow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            label: 'Total Collected',
                            value: _money(yearly['collectedTotal']),
                            leftBorder: Colors.green.shade600,
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.06,
                            ),
                            valueColor: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            label: 'Outstanding',
                            value: _money(yearly['outstandingTotal']),
                            leftBorder: Colors.red,
                            badge:
                                '${yearly['efficiencyRate'] ?? 0}% Efficiency',
                            badgeColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildPrintableReportCard(data.periods, monthly),
                    const SizedBox(height: 20),
                    _buildTrendsChart(monthlySeries),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildPrintableReportCard(
    List<dynamic> periods,
    Map<String, dynamic> monthly,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRINTABLE MONTHLY REPORT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Paid people, people to pay, expected and available amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _printMonthlyReport(monthly),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlack,
                  foregroundColor: AppColors.primaryYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _selectedPeriod,
            items: periods.map((period) {
              final label =
                  (period as Map<String, dynamic>)['label'] as String? ?? '';
              return DropdownMenuItem(value: label, child: Text(label));
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedPeriod = value;
                _future = _load();
              });
            },
            decoration: InputDecoration(
              labelText: 'Period',
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  label: 'Expected',
                  value: _money(monthly['expectedTotal']),
                  leftBorder: AppColors.primaryYellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  label: 'Available',
                  value: _money(monthly['collectedTotal']),
                  leftBorder: Colors.green.shade600,
                  backgroundColor: Colors.green.withValues(alpha: 0.06),
                  valueColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  label: 'Paid People',
                  value: '${monthly['paidPeopleCount'] ?? 0}',
                  leftBorder: Colors.green.shade600,
                  valueColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  label: 'People To Pay',
                  value: '${monthly['peopleToPayCount'] ?? 0}',
                  leftBorder: Colors.red.shade600,
                  valueColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Footer that will appear on the printout:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generated by MVCS, a product of Higura Ventures',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    Color? leftBorder,
    String? badge,
    Color? badgeColor,
    Color? backgroundColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: leftBorder ?? AppColors.border, width: 4),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppColors.primaryBlack,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendsChart(List<dynamic> series) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YEARLY CONTRIBUTION TRENDS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Expected vs Collected (Monthly)',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (series.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No data available for this year.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: series.map((entry) {
                  final item = entry as Map<String, dynamic>;
                  final expected = (item['expected'] as num?)?.toDouble() ?? 0;
                  final collected =
                      (item['collected'] as num?)?.toDouble() ?? 0;
                  final maxValue = series.fold<double>(1, (max, raw) {
                    final data = raw as Map<String, dynamic>;
                    return [
                      max,
                      (data['expected'] as num?)?.toDouble() ?? 0,
                      (data['collected'] as num?)?.toDouble() ?? 0,
                    ].reduce((a, b) => a > b ? a : b);
                  });

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: expected / maxValue,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: collected / maxValue,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryYellow,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['label'] as String? ?? '-',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _money(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['formatted'] as String? ?? 'RWF 0';
    }
    return 'RWF 0';
  }
}

class _ReportsData {
  const _ReportsData({
    required this.periods,
    required this.yearly,
    required this.monthly,
  });

  final List<dynamic> periods;
  final Map<String, dynamic> yearly;
  final Map<String, dynamic> monthly;
}
