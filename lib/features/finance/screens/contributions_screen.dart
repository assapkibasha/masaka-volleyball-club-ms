import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class ContributionsScreen extends ConsumerStatefulWidget {
  const ContributionsScreen({super.key});

  @override
  ConsumerState<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends ConsumerState<ContributionsScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _periods = const [];
  String? _selectedPeriod;
  late Future<_ContributionsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ContributionsData> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);

    _periods = await api.getPeriods(token);
    _selectedPeriod ??= _periods.isNotEmpty ? (_periods.first as Map<String, dynamic>)['label'] as String? : null;

    final summary = await api.getContributionSummary(token, period: _selectedPeriod);
    final records = await api.getContributions(
      token,
      period: _selectedPeriod,
      search: _searchController.text.trim(),
    );

    return _ContributionsData(summary: summary, records: records);
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
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Contributions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppColors.primaryBlack),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.primaryBlack),
              label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: FutureBuilder<_ContributionsData>(
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _periods.map((period) {
                        final label = (period as Map<String, dynamic>)['label'] as String? ?? '';
                        final isSelected = label == _selectedPeriod;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = label;
                              _future = _load();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                            margin: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: isSelected ? AppColors.primaryYellow : Colors.transparent, width: 2)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: _buildSummaryCard('Total Expected', _money(data.summary['expectedTotal']), null, false)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('Received Money', _money(data.summary['receivedTotal'] ?? data.summary['collectedTotal']), AppColors.primaryYellow, true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('Outstanding', _money(data.summary['outstandingTotal']), null, false, valueColor: Colors.red.shade600)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _refresh(),
                    decoration: InputDecoration(
                      hintText: 'Search member name...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('RECENT RECORDS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textSecondary)),
                      Text('Showing ${data.records.length} entries', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (data.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No contribution records found.', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  ...data.records.map((record) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _buildRecordCard(record as Map<String, dynamic>),
                      )),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color? leftBorderColor, bool hasLeftAccent, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: leftBorderColor ?? AppColors.border, width: hasLeftAccent ? 4 : 1),
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
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor ?? AppColors.primaryBlack)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    Color statusBg;
    Color statusText;
    switch (record['status']) {
      case 'paid':
        statusBg = Colors.green.shade100;
        statusText = Colors.green.shade700;
        break;
      case 'partial':
        statusBg = Colors.orange.shade100;
        statusText = Colors.orange.shade700;
        break;
      default:
        statusBg = Colors.red.shade100;
        statusText = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(_initials(record['memberName'] as String? ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record['memberName'] as String? ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  _formatDate(record['lastPaymentDate'] as String?),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(record['totalPaid']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                child: Text((record['status'] as String? ?? '').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText)),
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

  String _formatDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) {
      return 'No payment recorded';
    }
    return DateFormat('dd MMM, yyyy • hh:mm a').format(date.toLocal());
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).take(2);
    final text = parts.map((part) => part[0].toUpperCase()).join();
    return text.isEmpty ? 'MV' : text;
  }
}

class _ContributionsData {
  const _ContributionsData({
    required this.summary,
    required this.records,
  });

  final Map<String, dynamic> summary;
  final List<dynamic> records;
}
