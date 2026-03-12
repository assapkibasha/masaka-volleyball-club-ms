import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _systemNameController = TextEditingController();
  final _monthlyContributionController = TextEditingController();
  String _currency = 'RWF';
  bool _autoReminders = true;
  bool _paymentNotify = true;
  bool _weeklyReports = false;
  List<dynamic> _admins = const [];
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _systemNameController.dispose();
    _monthlyContributionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);
    final settings = await api.getSettings(token);
    _admins = await api.getAdmins(token);

    final general = settings['general'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final notifications = settings['notifications'] as Map<String, dynamic>? ?? <String, dynamic>{};

    _systemNameController.text = general['systemName'] as String? ?? '';
    _monthlyContributionController.text = '${general['defaultMonthlyContribution'] ?? 0}';
    _currency = general['currency'] as String? ?? 'RWF';
    _autoReminders = notifications['autoReminders'] as bool? ?? true;
    _paymentNotify = notifications['paymentNotify'] as bool? ?? true;
    _weeklyReports = notifications['weeklyReports'] as bool? ?? false;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _save() async {
    try {
      await ref.read(apiClientProvider).updateSettings(
            ref.read(authControllerProvider).token!,
            {
              'general': {
                'systemName': _systemNameController.text.trim(),
                'defaultMonthlyContribution': int.tryParse(_monthlyContributionController.text.trim()) ?? 0,
                'currency': _currency,
              },
              'notifications': {
                'autoReminders': _autoReminders,
                'paymentNotify': _paymentNotify,
                'weeklyReports': _weeklyReports,
              },
            },
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'System Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: AppColors.primaryBlack,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: FutureBuilder<void>(
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.settings, 'General Settings'),
                    const SizedBox(height: 12),
                    _buildSettingsCard(
                      child: Column(
                        children: [
                          _buildTextField('System Name', _systemNameController),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Monthly Contribution', _monthlyContributionController)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _currency,
                                      decoration: _dropdownDecoration(),
                                      items: const [
                                        DropdownMenuItem(value: 'RWF', child: Text('RWF')),
                                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                                        DropdownMenuItem(value: 'KES', child: Text('KES')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _currency = value);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(Icons.notifications, 'Notification Preferences'),
                    const SizedBox(height: 12),
                    _buildSettingsCard(
                      child: Column(
                        children: [
                          _buildToggleTile('Send automatic payment reminders', _autoReminders, (value) => setState(() => _autoReminders = value)),
                          const Divider(color: AppColors.divider, height: 1),
                          _buildToggleTile('Notify on payment received', _paymentNotify, (value) => setState(() => _paymentNotify = value)),
                          const Divider(color: AppColors.divider, height: 1),
                          _buildToggleTile('Weekly summary reports', _weeklyReports, (value) => setState(() => _weeklyReports = value)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(Icons.shield_outlined, 'Admin Management'),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryYellow,
                            foregroundColor: AppColors.primaryBlack,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          label: const Text('Reload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _admins.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No admins found.', style: TextStyle(color: AppColors.textSecondary)),
                            )
                          : Column(
                              children: [
                                for (var index = 0; index < _admins.length; index++) ...[
                                  _buildAdminTile(_admins[index] as Map<String, dynamic>),
                                  if (index < _admins.length - 1) const Divider(height: 1, color: AppColors.divider, indent: 58),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: AppColors.primaryYellow, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
      ],
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(controller: controller, decoration: _dropdownDecoration()),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    );
  }

  Widget _buildToggleTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primaryBlack : Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primaryYellow : const Color(0xFFE2E8F0)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(Map<String, dynamic> admin) {
    final name = admin['fullName'] as String? ?? 'Unknown Admin';
    final role = admin['role'] as String? ?? 'admin';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
            child: Center(child: Text(_initials(name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).take(2);
    final text = parts.map((part) => part[0].toUpperCase()).join();
    return text.isEmpty ? 'MV' : text;
  }
}
