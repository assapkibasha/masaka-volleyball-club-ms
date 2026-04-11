import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late Future<List<dynamic>> _membersFuture;
  final Set<String> _selectedIds = {};
  bool _isSending = false;

  // Compose fields
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Monthly Contribution Reminder');
    _messageController = TextEditingController(
      text: 'Dear member, this is a reminder to pay your monthly contribution. Please make your payment as soon as possible.',
    );
    _membersFuture = _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadMembers() {
    final token = ref.read(authControllerProvider).token!;
    return ref.read(apiClientProvider).getMembers(token);
  }

  bool _selectAll(List<dynamic> members) =>
      members.isNotEmpty && members.every((m) => _selectedIds.contains(m['id'] as String?));

  void _toggleAll(List<dynamic> members, bool? value) {
    setState(() {
      if (value == true) {
        for (final m in members) {
          final id = m['id'] as String?;
          if (id != null) _selectedIds.add(id);
        }
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  bool get _canSend =>
      _selectedIds.isNotEmpty &&
      _titleController.text.trim().isNotEmpty &&
      _messageController.text.trim().isNotEmpty;

  Future<void> _sendReminder() async {
    if (!_canSend) return;
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    try {
      final token = ref.read(authControllerProvider).token!;
      final result = await ref.read(apiClientProvider).sendReminder(
            token: token,
            memberIds: _selectedIds.toList(),
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            channel: 'sms',
          );

      if (!mounted) return;
      final sent   = result['sent']   as int? ?? 0;
      final failed = result['failed'] as int? ?? 0;
      final errors = (result['errors'] as List<dynamic>?)?.cast<String>() ?? [];
      final errorDetail = errors.isNotEmpty ? '\n${errors.join('; ')}' : '';

      final msg = failed == 0
          ? 'SMS sent to $sent player${sent > 1 ? 's' : ''} ✓'
          : 'Sent: $sent  •  Failed: $failed$errorDetail';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: failed == 0 ? Colors.green.shade700 : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() => _selectedIds.clear());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Send Message',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primaryBlack,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _membersFuture,
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
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          final members = snapshot.data ?? const [];

          return Column(
            children: [
              // ── Compose section ────────────────────────────────────────
              _buildComposeSection(),

              // ── Players label row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SELECT RECIPIENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlack,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedIds.length} selected',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Players table ──────────────────────────────────────────
              Expanded(
                child: members.isEmpty
                    ? const Center(
                        child: Text(
                          'No members found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(40),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(2),
                                3: FixedColumnWidth(48),
                              },
                              children: [
                                // Header
                                TableRow(
                                  decoration: const BoxDecoration(color: AppColors.primaryBlack),
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                      child: Text('#',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryYellow, letterSpacing: 0.5)),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                      child: Text('PLAYER NAME',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                      child: Text('POSITION',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      child: Checkbox(
                                        value: _selectAll(members),
                                        onChanged: (v) => _toggleAll(members, v),
                                        activeColor: AppColors.primaryYellow,
                                        checkColor: AppColors.primaryBlack,
                                        side: const BorderSide(color: Colors.white60, width: 1.5),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                                // Data rows
                                ...List.generate(members.length, (index) {
                                  final member = members[index] as Map<String, dynamic>;
                                  final id = member['id'] as String? ?? '';
                                  final name = member['fullName'] as String? ?? '—';
                                  final role = member['role'] as String? ?? '—';
                                  final isChecked = _selectedIds.contains(id);
                                  final isEven = index.isEven;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isEven ? AppColors.white : AppColors.backgroundLight,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                                        child: Text('${index + 1}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
                                        child: Text(name,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlack),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryYellow.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(role,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        child: Checkbox(
                                          value: isChecked,
                                          onChanged: id.isEmpty ? null : (_) => _toggle(id),
                                          activeColor: AppColors.primaryBlack,
                                          checkColor: AppColors.primaryYellow,
                                          side: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              // ── Send button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ValueListenableBuilder(
                    valueListenable: _titleController,
                    builder: (_, __, ___) => ValueListenableBuilder(
                      valueListenable: _messageController,
                      builder: (_, __, ___) {
                        final enabled = _canSend && !_isSending;
                        return ElevatedButton.icon(
                          onPressed: enabled ? _sendReminder : null,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryYellow),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSending
                                ? 'Sending...'
                                : _selectedIds.isEmpty
                                    ? 'Select players to send'
                                    : _titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty
                                        ? 'Compose a message first'
                                        : 'Send to ${_selectedIds.length} Player${_selectedIds.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: enabled ? AppColors.primaryBlack : const Color(0xFFE2E8F0),
                            foregroundColor: enabled ? AppColors.primaryYellow : AppColors.textSecondary,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: AppColors.textSecondary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildComposeSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlack,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.primaryYellow, size: 18),
                SizedBox(width: 8),
                Text(
                  'COMPOSE MESSAGE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                ),
              ],
            ),
          ),

          // Title field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlack),
              decoration: InputDecoration(
                labelText: 'Subject / Title',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.subject_rounded, size: 18, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryBlack, width: 1.5),
                ),
              ),
            ),
          ),

          // Message body field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: TextField(
              controller: _messageController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: AppColors.primaryBlack, height: 1.5),
              decoration: InputDecoration(
                labelText: 'Message body',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.message_outlined, size: 18, color: AppColors.textSecondary),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryBlack, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
