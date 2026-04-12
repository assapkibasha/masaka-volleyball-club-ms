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
  static const _defaultMessage =
      "Muraho neza!, Masaka Volleyball club  irakwibutsa gutanga umusanzu w'ukwezi kwa kane\ncode 1620626 francois. ibihe byiza.";
  static const _recipientFilters = ['All', 'Not Sent', 'Sent'];

  late Future<_MessagesData> _future;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
  bool _isSending = false;
  int _selectedFilterIndex = 0;

  late final TextEditingController _titleController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: 'Monthly Contribution Reminder',
    );
    _messageController = TextEditingController(text: _defaultMessage);
    _future = _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<_MessagesData> _loadMembers() async {
    final token = ref.read(authControllerProvider).token!;
    final api = ref.read(apiClientProvider);
    final results = await Future.wait<dynamic>([
      api.getMembers(token, pageSize: 1000),
      api.getNotifications(token, pageSize: 1000),
    ]);

    final members = results[0] as List<dynamic>;
    final sentMemberIds = (results[1] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => item['memberId'] as String?)
        .whereType<String>()
        .toSet();

    return _MessagesData(members: members, sentMemberIds: sentMemberIds);
  }

  bool _selectAll(List<dynamic> members) =>
      members.isNotEmpty &&
      members.every((m) => _selectedIds.contains(m['id'] as String?));

  void _toggleAll(List<dynamic> members, bool? value) {
    setState(() {
      if (value == true) {
        for (final member in members.whereType<Map<String, dynamic>>()) {
          final id = member['id'] as String?;
          if (id != null) {
            _selectedIds.add(id);
          }
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
    if (!_canSend) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    try {
      final token = ref.read(authControllerProvider).token!;
      final result = await ref
          .read(apiClientProvider)
          .sendReminder(
            token: token,
            memberIds: _selectedIds.toList(),
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            channel: 'sms',
          );

      if (!mounted) {
        return;
      }

      final sent = result['sent'] as int? ?? 0;
      final pending = result['pending'] as int? ?? 0;
      final failed = result['failed'] as int? ?? 0;
      final errors = (result['errors'] as List<dynamic>?)?.cast<String>() ?? [];
      final recipients = (result['recipients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final errorDetail = errors.isNotEmpty ? '\n${errors.join('; ')}' : '';

      final msg = failed == 0
          ? 'Submitted: $pending  Delivered: $sent'
          : 'Submitted: $pending  Delivered: $sent  Failed: $failed$errorDetail';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: failed == 0
              ? Colors.green.shade700
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      await _showRecipientsSheet(recipients);
      final future = _loadMembers();
      setState(() {
        _selectedIds.clear();
        _future = future;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
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
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: FutureBuilder<_MessagesData>(
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
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          final data = snapshot.data ?? const _MessagesData();
          final members = _filterMembers(data.members, data.sentMemberIds);

          return Column(
            children: [
              _buildComposeSection(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: List.generate(_recipientFilters.length, (index) {
                    final isActive = index == _selectedFilterIndex;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _recipientFilters.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = index;
                            _selectedIds.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryYellow
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primaryYellow
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _recipientFilters[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppColors.primaryBlack
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
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
              Expanded(
                child: members.isEmpty
                    ? const Center(
                        child: Text(
                          'No members match this filter.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _buildMembersTable(members, data.sentMemberIds),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _titleController,
                    builder: (_, _, _) => ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (_, _, _) {
                        final enabled = _canSend && !_isSending;
                        return ElevatedButton.icon(
                          onPressed: enabled ? _sendReminder : null,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryYellow,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSending
                                ? 'Sending...'
                                : _selectedIds.isEmpty
                                ? 'Select players to send'
                                : _titleController.text.trim().isEmpty ||
                                      _messageController.text.trim().isEmpty
                                ? 'Compose a message first'
                                : 'Send to ${_selectedIds.length} Player${_selectedIds.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: enabled
                                ? AppColors.primaryBlack
                                : const Color(0xFFE2E8F0),
                            foregroundColor: enabled
                                ? AppColors.primaryYellow
                                : AppColors.textSecondary,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: AppColors.textSecondary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildMembersTable(List<dynamic> members, Set<String> sentMemberIds) {
    return Container(
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
              3: FlexColumnWidth(2),
              4: FixedColumnWidth(48),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppColors.primaryBlack),
                children: [
                  _buildHeaderCell('#'),
                  _buildHeaderCell('PLAYER NAME'),
                  _buildHeaderCell('POSITION'),
                  _buildHeaderCell('STATUS'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: Checkbox(
                      value: _selectAll(members),
                      onChanged: (value) => _toggleAll(members, value),
                      activeColor: AppColors.primaryYellow,
                      checkColor: AppColors.primaryBlack,
                      side: const BorderSide(color: Colors.white60, width: 1.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              ...List.generate(members.length, (index) {
                final member = members[index] as Map<String, dynamic>;
                final id = member['id'] as String? ?? '';
                final hasBeenSent = sentMemberIds.contains(id);
                return TableRow(
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? AppColors.white
                        : AppColors.backgroundLight,
                  ),
                  children: [
                    _buildBodyCell('${index + 1}'),
                    _buildBodyCell(
                      member['fullName'] as String? ?? '-',
                      isBold: true,
                    ),
                    _buildRoleCell(member['role'] as String? ?? '-'),
                    _buildStatusCell(hasBeenSent),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Checkbox(
                        value: _selectedIds.contains(id),
                        onChanged: id.isEmpty ? null : (_) => _toggle(id),
                        activeColor: AppColors.primaryBlack,
                        checkColor: AppColors.primaryYellow,
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
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
    );
  }

  List<dynamic> _filterMembers(
    List<dynamic> members,
    Set<String> sentMemberIds,
  ) {
    final search = _searchController.text.trim().toLowerCase();
    return members.where((item) {
      if (item is! Map<String, dynamic>) {
        return false;
      }
      final memberId = item['id'] as String?;
      final hasBeenSent = memberId != null && sentMemberIds.contains(memberId);
      final matchesFilter = switch (_selectedFilterIndex) {
        1 => !hasBeenSent,
        2 => hasBeenSent,
        _ => true,
      };
      if (!matchesFilter) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }

      final searchFields = [
        item['fullName'] as String? ?? '',
        item['email'] as String? ?? '',
        item['phone'] as String? ?? '',
        item['memberNumber'] as String? ?? '',
      ];

      return searchFields.any((field) => field.toLowerCase().contains(search));
    }).toList();
  }

  Widget _buildHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBodyCell(String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
          color: isBold ? AppColors.primaryBlack : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRoleCell(String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          role,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlack,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildStatusCell(bool hasBeenSent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hasBeenSent
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          hasBeenSent ? 'SENT' : 'NOT SENT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: hasBeenSent ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _showRecipientsSheet(List<Map<String, dynamic>> recipients) {
    if (recipients.isEmpty) {
      return Future.value();
    }

    final delivered = recipients
        .where((item) => item['status'] == 'delivered')
        .toList();
    final failed = recipients
        .where((item) => item['status'] == 'failed')
        .toList();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message Recipients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${delivered.length} delivered, ${failed.length} failed, ${recipients.length - delivered.length - failed.length} pending',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: recipients.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final item = recipients[index];
                      final status = item['status'] as String? ?? 'pending';
                      final isDelivered = status == 'delivered';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isDelivered
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          child: Icon(
                            isDelivered ? Icons.check : Icons.error_outline,
                            color: isDelivered
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        title: Text(
                          item['memberName'] as String? ?? 'Unknown member',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                        subtitle: Text(
                          [
                            item['memberPhone'] as String? ?? 'No phone number',
                            if ((item['errorMessage'] as String?)?.isNotEmpty ??
                                false)
                              item['errorMessage'] as String,
                          ].join('\n'),
                        ),
                        trailing: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDelivered
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlack,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primaryYellow,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'COMPOSE MESSAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlack,
              ),
              decoration: InputDecoration(
                labelText: 'Subject / Title',
                labelStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.subject_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.primaryBlack,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: TextField(
              controller: _messageController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryBlack,
                height: 1.5,
              ),
              decoration: InputDecoration(
                labelText: 'Message body',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(
                    Icons.message_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.primaryBlack,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesData {
  const _MessagesData({
    this.members = const [],
    this.sentMemberIds = const <String>{},
  });

  final List<dynamic> members;
  final Set<String> sentMemberIds;
}
