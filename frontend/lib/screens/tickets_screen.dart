import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'ticket_detail_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _status = '';
  late Future<List<TicketSummary>> _future;
  Timer? _timer;

  static const _statuses = [
    '',
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
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = ApiService.instance.getTickets(
        status: _status.isEmpty ? null : _status,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.isSupport ? 'All Customer Tickets' : 'My Tickets'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: _statuses
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item.isEmpty ? 'All statuses' : prettyLabel(item),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                _status = value ?? '';
                _reload();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<TicketSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView();
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        EmptyView(
                          icon: Icons.error_outline,
                          title: 'Unable to load tickets',
                          message: snapshot.error.toString(),
                        ),
                      ],
                    );
                  }

                  final tickets = snapshot.data ?? [];
                  if (tickets.isEmpty) {
                    return const EmptyView(
                      icon: Icons.inbox_outlined,
                      title: 'No matching tickets',
                      message: 'Tickets matching this status will appear here.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      for (final ticket in tickets)
                        TicketCard(
                          ticket: ticket,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TicketDetailScreen(
                                  ticketId: ticket.id,
                                ),
                              ),
                            );
                            _reload();
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
