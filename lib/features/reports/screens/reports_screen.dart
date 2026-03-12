import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.toString();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return ref.read(apiClientProvider).getYearlyReport(
          ref.read(authControllerProvider).token!,
          int.parse(_selectedYear),
        );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
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
        title: Row(
          children: [
            const Text(
              'Yearly Reports ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.primaryBlack),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(4)),
              child: Text(_selectedYear, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryYellow)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedYear,
              underline: const SizedBox(),
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack, fontFamily: 'Inter'),
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
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }

          final data = snapshot.data!;
          final monthlySeries = (data['monthlySeries'] as List<dynamic>? ?? const []);
          final topMonths = (data['topMonths'] as List<dynamic>? ?? const []);

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
                        Expanded(child: _buildSummaryCard(label: 'Total Expected', value: _money(data['expectedTotal']), leftBorder: AppColors.primaryYellow)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDarkCard(data)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            label: 'Outstanding',
                            value: _money(data['outstandingTotal']),
                            leftBorder: Colors.red,
                            badge: '${data['efficiencyRate'] ?? 0}% Efficiency',
                            badgeColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTrendsChart(monthlySeries),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTopMonths(topMonths)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildEfficiencyCard(data)),
                      ],
                    ),
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

  Widget _buildSummaryCard({required String label, required String value, Color? leftBorder, String? badge, Color? badgeColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: leftBorder ?? AppColors.border, width: 4),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor ?? AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildDarkCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlack,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL COLLECTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(_money(data['collectedTotal']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primaryYellow)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 14, color: Colors.greenAccent),
              const SizedBox(width: 2),
              Text('${data['efficiencyRate'] ?? 0}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade400)),
            ],
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONTRIBUTION TRENDS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)),
                  SizedBox(height: 2),
                  Text('Expected vs Collected (Monthly)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Expected', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Collected', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (series.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No data available for this year.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: series.map((entry) {
                  final item = entry as Map<String, dynamic>;
                  final expected = (item['expected'] as num?)?.toDouble() ?? 0;
                  final collected = (item['collected'] as num?)?.toDouble() ?? 0;
                  final maxValue = series.fold<double>(1, (max, raw) {
                    final data = raw as Map<String, dynamic>;
                    return [max, (data['expected'] as num?)?.toDouble() ?? 0, (data['collected'] as num?)?.toDouble() ?? 0].reduce((a, b) => a > b ? a : b);
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
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: collected / maxValue,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryYellow,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(item['label'] as String? ?? '-', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
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

  Widget _buildTopMonths(List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.primaryYellow, size: 18),
              SizedBox(width: 6),
              Text('TOP MONTHS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('No ranked months yet.', style: TextStyle(color: AppColors.textSecondary))
          else
            ...items.map((entry) {
              final item = entry as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMonthRank(
                  '${item['rank']}',
                  item['month'] as String? ?? '-',
                  _money(item['collected']),
                  highlight: (item['rank'] as int? ?? 0) == 1,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMonthRank(String rank, String month, String amount, {bool highlight = false}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: highlight ? AppColors.primaryYellow : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(child: Text(rank, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlack))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(month, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildEfficiencyCard(Map<String, dynamic> data) {
    final efficiency = (data['efficiencyRate'] as int? ?? 0).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: AppColors.primaryYellow, size: 18),
              SizedBox(width: 6),
              Text('EFFICIENCY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: efficiency / 100,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Center(
                      child: Text('$efficiency%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Collection rate is derived from total collected versus total expected for the selected year.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4, fontFamily: 'Inter'),
                ),
              ),
            ],
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
