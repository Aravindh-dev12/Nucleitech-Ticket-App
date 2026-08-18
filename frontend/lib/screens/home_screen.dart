import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'plant_dashboard_screen.dart';
import 'plant_login_admin_screen.dart';
import 'tickets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Plant>> _future;
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  Timer? _timer;

  AppUser get user => ApiService.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getPlants();
    _notificationsFuture = ApiService.instance.getNotifications();
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
      _future = ApiService.instance.getPlants();
      _notificationsFuture = ApiService.instance.getNotifications();
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
    _reload();
  }

  Future<void> _openPlantLogins() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PlantLoginAdminScreen(),
      ),
    );
    _reload();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Do you want to sign out of NUCLEI TECH?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B5ED7),
        surfaceTintColor: Colors.white,
        titleSpacing: 16,
        title: const BrandLogo(
          width: 170,
          height: 42,
          fit: BoxFit.contain,
        ),
        actions: [
          if (user.role == 'nuclei_admin')
            IconButton(
              tooltip: 'Create plant login',
              onPressed: _openPlantLogins,
              icon: const Icon(
                Icons.manage_accounts_outlined,
                color: Color(0xFF0B5ED7),
              ),
            ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: FutureBuilder<List<Map<String, dynamic>>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                final notifications =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                final unreadCount = notifications
                    .where((item) => item['is_read'] != true)
                    .length;

                return _NotificationBell(count: unreadCount);
              },
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _WelcomeCard(user: user),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.isSupport
                        ? 'All Customer Plants'
                        : '${user.companyName ?? 'Company'} Plants',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TicketsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: Text(user.isSupport ? 'All Tickets' : 'My Tickets'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Plant>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 250, child: LoadingView());
                }
                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }

                final plants = snapshot.data ?? [];
                if (plants.isEmpty) {
                  return const SizedBox(
                    height: 260,
                    child: EmptyView(
                      icon: Icons.factory_outlined,
                      title: 'No plants available',
                      message: 'No active plants are assigned to this account.',
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1150
                        ? 4
                        : constraints.maxWidth >= 760
                            ? 2
                            : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: plants.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 255,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (_, index) {
                        final plant = plants[index];
                        return _PlantCard(
                          plant: plant,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PlantDashboardScreen(plant: plant),
                              ),
                            );
                            _reload();
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            count > 0
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined,
            color: Colors.black,
            size: 24,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B5ED7),
            Color(0xFF084298),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'N',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 23,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    user.roleLabel,
                    if (user.companyName != null) user.companyName!,
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.solar_power, color: Colors.white, size: 34),
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.onTap,
  });

  final Plant plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE7F0FF),
                    foregroundColor: Color(0xFF0B5ED7),
                    child: Icon(Icons.solar_power_outlined),
                  ),
                  const Spacer(),
                  StatusBadge(
                    value: plant.scadaEnabled ? 'live' : 'offline',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                plant.plantName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(plant.companyName),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(icon: Icons.bolt, text: plant.capacityLabel),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _Metric(label: 'Active', value: plant.activeTickets),
                  ),
                  Expanded(
                    child: _Metric(label: 'Solved', value: plant.solvedTickets),
                  ),
                  Expanded(
                    child: _Metric(label: 'Total', value: plant.totalTickets),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF0B5ED7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
