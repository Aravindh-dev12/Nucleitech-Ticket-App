import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticketId,
  });

  final int ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  final _commentController = TextEditingController();
  Timer? _timer;
  bool _posting = false;

  static const _statuses = [
    'open',
    'assigned',
    'in_progress',
    'waiting_for_user',
    'on_hold',
    'resolved',
    'closed',
    'reopened',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(AppConfig.refreshInterval, (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = ApiService.instance.getTicket(widget.ticketId);
    });
  }

  Future<void> _postComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _posting = true);
    try {
      await ApiService.instance.addComment(
        ticketId: widget.ticketId,
        comment: comment,
      );
      _commentController.clear();
      _reload();
    } on ApiException catch (error) {
      showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _changeStatus(String currentStatus) async {
    var selected = currentStatus;
    final notesController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Ticket Status'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(prettyLabel(status)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'NUCLEI TECH update / resolution notes',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update & Notify Customer'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true) {
      try {
        await ApiService.instance.updateStatus(
          ticketId: widget.ticketId,
          status: selected,
          resolutionNotes: notesController.text.trim(),
        );
        _reload();
        if (mounted) {
          showMessage(
            context,
            'Status updated. The customer notification and email were sent.',
          );
        }
      } on ApiException catch (error) {
        showMessage(context, error.message);
      }
    }

    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Details')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 130),
                  EmptyView(
                    icon: Icons.error_outline,
                    title: 'Unable to load ticket',
                    message: snapshot.error.toString(),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final ticket = data['ticket'] as Map<String, dynamic>;
            final attachments = data['attachments'] as List<dynamic>? ?? [];
            final comments = data['comments'] as List<dynamic>? ?? [];
            final history = data['history'] as List<dynamic>? ?? [];

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SelectableText(
                              ticket['ticket_number']?.toString() ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            StatusBadge(
                              value: ticket['status']?.toString() ?? '',
                            ),
                            StatusBadge(
                              value: ticket['priority']?.toString() ?? '',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ticket['subject']?.toString() ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${ticket['company_name']} • ${ticket['plant_name']}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Raised by ${ticket['raised_by_name']} • '
                          '${formatDate(ticket['created_at'])}',
                        ),
                        if (ticket['assigned_to_name'] != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Assigned to ${ticket['assigned_to_name']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                        const Divider(height: 30),
                        Text(
                          ticket['description']?.toString() ?? '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if ((ticket['resolution_notes']?.toString() ?? '')
                            .isNotEmpty) ...[
                          const Divider(height: 30),
                          Text(
                            'Latest Resolution / Update',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(ticket['resolution_notes'].toString()),
                        ],
                        if (user.isSupport) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _changeStatus(
                              ticket['status']?.toString() ?? 'open',
                            ),
                            icon: const Icon(Icons.sync_alt),
                            label: const Text('Update Status'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionTitle('Issue Images'),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: attachments.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisExtent: 165,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (_, index) {
                      final attachment =
                          attachments[index] as Map<String, dynamic>;
                      final url = attachment['file_url']?.toString() ?? '';

                      return InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Colors.black12,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                const SectionTitle('Ticket History'),
                const SizedBox(height: 10),
                if (history.isEmpty)
                  const Text('No history entries.')
                else
                  ...history.reversed.map((item) {
                    final row = item as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: const Icon(Icons.history_toggle_off),
                        title: Text(
                          prettyLabel(row['action']?.toString() ?? ''),
                        ),
                        subtitle: Text(
                          [
                            if (row['new_value'] != null)
                              prettyLabel(row['new_value'].toString()),
                            row['changed_by_name']?.toString(),
                            formatDate(row['created_at']),
                            if ((row['notes']?.toString() ?? '').isNotEmpty)
                              row['notes'].toString(),
                          ].whereType<String>().join(' • '),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                const SectionTitle('Messages'),
                const SizedBox(height: 10),
                if (comments.isEmpty)
                  const Text('No messages yet.')
                else
                  ...comments.map((item) {
                    final comment = item as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(
                          comment['user_name']?.toString() ?? '',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(comment['comment']?.toString() ?? ''),
                            const SizedBox(height: 5),
                            Text(formatDate(comment['created_at'])),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Add a message',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _posting ? null : _postComment,
                      icon: _posting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}
