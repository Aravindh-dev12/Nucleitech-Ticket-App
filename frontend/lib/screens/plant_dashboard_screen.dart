import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/scada_service.dart';
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

class _PlantDashboardScreenState extends State<PlantDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScadaService _scada;
  late Future<List<TicketSummary>> _ticketsFuture;
  Timer? _ticketTimer;

  AppUser get user => ApiService.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scada = ScadaService(
      plantId: widget.plant.id,
      expectedSiteId: widget.plant.scadaSiteId,
    )..start();
    _reloadTickets();
    _ticketTimer = Timer.periodic(
      AppConfig.refreshInterval,
      (_) => _reloadTickets(),
    );
  }

  @override
  void dispose() {
    _ticketTimer?.cancel();
    _tabController.dispose();
    _scada.dispose();
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
      _tabController.animateTo(3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant.plantName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.electrical_services), text: 'Inverters'),
            Tab(icon: Icon(Icons.power_settings_new), text: 'VCB'),
            Tab(
                icon: Icon(Icons.confirmation_number_outlined),
                text: 'Tickets'),
          ],
        ),
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
          _PlantHeader(plant: widget.plant, scada: _scada),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(scada: _scada),
                _DevicesTab(
                  scada: _scada,
                  type: 'inverters',
                  emptyTitle: 'No inverter data yet',
                  emptyMessage:
                      'The inverter list will appear when the WebSocket sends inverter records.',
                ),
                _DevicesTab(
                  scada: _scada,
                  type: 'vcb',
                  emptyTitle: 'No VCB data yet',
                  emptyMessage:
                      'The VCB list will appear when the WebSocket sends breaker records.',
                ),
                _TicketsTab(
                  future: _ticketsFuture,
                  canRaise: user.canRaise,
                  onRaise: _raiseTicket,
                  onRefresh: _reloadTickets,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  const _PlantHeader({required this.plant, required this.scada});

  final Plant plant;
  final ScadaService scada;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scada,
      builder: (context, _) {
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
              _HeaderChip(icon: Icons.bolt, text: plant.capacityLabel),
              StatusBadge(value: _stateName(scada.state)),
              if (scada.lastUpdated != null)
                Text(
                  'Updated ${formatDate(scada.lastUpdated!.toIso8601String())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        );
      },
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.scada});

  final ScadaService scada;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scada,
      builder: (context, _) {
        final data = scada.data;

        return RefreshIndicator(
          onRefresh: scada.retryNow,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (scada.errorMessage != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: 12),
                        Expanded(child: Text(scada.errorMessage!)),
                        TextButton(
                          onPressed: scada.retryNow,
                          child: const Text('Reconnect'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data == null) ...[
                const SizedBox(height: 70),
                EmptyView(
                  icon: scada.state == ScadaConnectionState.connecting ||
                          scada.state == ScadaConnectionState.reconnecting
                      ? Icons.sync
                      : Icons.cloud_off_outlined,
                  title: scada.state == ScadaConnectionState.connecting ||
                          scada.state == ScadaConnectionState.reconnecting
                      ? 'Connecting to live SCADA'
                      : 'Waiting for SCADA data',
                  message:
                      'The app is connecting to the configured WebSocket and subscribing with this plant’s SCADA ID.',
                ),
              ] else ...[
                SectionTitle(
                  'Live Plant Overview',
                  trailing: TextButton.icon(
                    onPressed: () => _showRaw(context, data.raw),
                    icon: const Icon(Icons.data_object),
                    label: const Text('Raw JSON'),
                  ),
                ),
                const SizedBox(height: 12),
                if (data.overview.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Live data arrived, but the field names do not match the common aliases yet. Use Raw JSON to inspect the payload and update the alias list in scada_service.dart.',
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 650
                              ? 2
                              : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.overview.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 135,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (_, index) {
                          final metric = data.overview[index];
                          return _MetricCard(metric: metric);
                        },
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        title: 'Inverters',
                        value: data.inverters.length,
                        icon: Icons.electrical_services,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountCard(
                        title: 'VCB / Breakers',
                        value: data.vcbs.length,
                        icon: Icons.power_settings_new,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  void _showRaw(BuildContext context, Map<String, dynamic> raw) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(raw);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Latest SCADA JSON'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(
              prettyJson,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ScadaMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metric.label),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                metric.value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (metric.unit.isNotEmpty)
              Text(metric.unit, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(child: Text(title)),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({
    required this.scada,
    required this.type,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final ScadaService scada;
  final String type;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scada,
      builder: (context, _) {
        final data = scada.data;
        final devices = type == 'inverters'
            ? data?.inverters ?? const <ScadaDevice>[]
            : data?.vcbs ?? const <ScadaDevice>[];

        if (devices.isEmpty) {
          return EmptyView(
            icon: type == 'inverters'
                ? Icons.electrical_services
                : Icons.power_settings_new,
            title: emptyTitle,
            message: emptyMessage,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: devices.length,
          itemBuilder: (_, index) {
            final device = devices[index];
            return _DeviceCard(device: device);
          },
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final ScadaDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F0FF),
          foregroundColor: const Color(0xFF0B5ED7),
          child: Icon(
            device.name.toLowerCase().contains('vcb')
                ? Icons.power_settings_new
                : Icons.electrical_services,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(value: device.status.toLowerCase()),
          ),
        ),
        children: [
          if (device.values.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text('No additional device values were supplied.'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: device.values.entries
                    .map(
                      (entry) => Container(
                        width: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD8E6FA),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({
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

          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 70),
                const EmptyView(
                  icon: Icons.inbox_outlined,
                  title: 'No tickets yet',
                  message: 'Plant issues raised here will appear in this list.',
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

String _stateName(ScadaConnectionState state) {
  return switch (state) {
    ScadaConnectionState.idle => 'offline',
    ScadaConnectionState.connecting => 'connecting',
    ScadaConnectionState.live => 'live',
    ScadaConnectionState.reconnecting => 'reconnecting',
    ScadaConnectionState.disconnected => 'offline',
    ScadaConnectionState.error => 'error',
  };
}
