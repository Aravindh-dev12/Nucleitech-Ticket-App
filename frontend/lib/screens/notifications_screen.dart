import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'ticket_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _timer;

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
    setState(() => _future = ApiService.instance.getNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
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
                    title: 'Unable to load notifications',
                    message: snapshot.error.toString(),
                  ),
                ],
              );
            }

            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return const EmptyView(
                icon: Icons.notifications_none,
                title: 'No notifications',
                message:
                    'Ticket updates and customer replies will appear here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(18),
              children: notifications.map((item) {
                final isRead = item['is_read'] == true;
                final ticketId = item['ticket_id'] == null
                    ? null
                    : int.tryParse(item['ticket_id'].toString());

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                      ),
                    ),
                    title: Text(
                      item['title']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${item['message'] ?? ''}\n'
                        '${formatDate(item['created_at'])}',
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      await ApiService.instance.markNotificationRead(
                        int.parse(item['id'].toString()),
                      );
                      if (ticketId != null && mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TicketDetailScreen(ticketId: ticketId),
                          ),
                        );
                      }
                      _reload();
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
