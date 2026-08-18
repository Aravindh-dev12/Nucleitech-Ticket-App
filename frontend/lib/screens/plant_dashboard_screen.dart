import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'raise_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class PlantDashboardScreen extends StatefulWidget {
  const PlantDashboardScreen({
    super.key,
    required this.plant,
  });

  final Plant plant;

  @override
  State<PlantDashboardScreen> createState() => _PlantDashboardScreenState();
}

class _PlantDashboardScreenState extends State<PlantDashboardScreen> {
  late Future<List<TicketSummary>> _ticketsFuture;
  Timer? _ticketTimer;

  AppUser get user => ApiService.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _reloadTickets();
    _ticketTimer = Timer.periodic(
      AppConfig.refreshInterval,
      (_) => _reloadTickets(),
    );
  }

  @override
  void dispose() {
    _ticketTimer?.cancel();
    super.dispose();
  }

  void _reloadTickets() {
    if (!mounted) return;
    setState(() {
      _ticketsFuture = ApiService.instance.getTickets(
        plantId: widget.plant.id,
      );
    });
  }

  Future<void> _raiseTicket() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RaiseTicketScreen(plant: widget.plant),
      ),
    );
    if (created == true) {
      _reloadTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant.plantName),
      ),
      floatingActionButton: user.canRaise
          ? FloatingActionButton.extended(
              onPressed: _raiseTicket,
              icon: const Icon(Icons.add),
              label: const Text('Raise Ticket'),
            )
          : null,
      body: Column(
        children: [
          _PlantHeader(plant: widget.plant),
          Expanded(
            child: _TicketsView(
              future: _ticketsFuture,
              canRaise: user.canRaise,
              onRaise: _raiseTicket,
              onRefresh: _reloadTickets,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  const _PlantHeader({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD8E6FA)),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            plant.companyName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          _HeaderChip(
            icon: Icons.bolt,
            text: plant.capacityLabel,
          ),
          _HeaderChip(
            icon: Icons.confirmation_number_outlined,
            text: '${plant.totalTickets} total tickets',
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E6FA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0B5ED7)),
          const SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }
}

class _TicketsView extends StatelessWidget {
  const _TicketsView({
    required this.future,
    required this.canRaise,
    required this.onRaise,
    required this.onRefresh,
  });

  final Future<List<TicketSummary>> future;
  final bool canRaise;
  final VoidCallback onRaise;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<TicketSummary>>(
        future: future,
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

          final tickets = snapshot.data ?? const <TicketSummary>[];
          if (tickets.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 70),
                const EmptyView(
                  icon: Icons.inbox_outlined,
                  title: 'No tickets yet',
                  message: 'Tickets raised for this plant will appear here.',
                ),
                if (canRaise)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: FilledButton.icon(
                      onPressed: onRaise,
                      icon: const Icon(Icons.add),
                      label: const Text('Raise First Ticket'),
                    ),
                  ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Tickets (${tickets.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final ticket in tickets)
                TicketCard(
                  ticket: ticket,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(ticketId: ticket.id),
                      ),
                    );
                    onRefresh();
                  },
                ),
              const SizedBox(height: 90),
            ],
          );
        },
      ),
    );
  }
}
