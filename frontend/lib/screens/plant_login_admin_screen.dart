import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class PlantLoginAdminScreen extends StatefulWidget {
  const PlantLoginAdminScreen({super.key});

  @override
  State<PlantLoginAdminScreen> createState() => _PlantLoginAdminScreenState();
}

class _PlantLoginAdminScreenState extends State<PlantLoginAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late Future<List<Plant>> _plantsFuture;
  List<Plant> _plants = const [];
  Plant? _selectedPlant;
  List<Map<String, dynamic>> _users = const [];
  bool _loadingUsers = false;
  bool _creating = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _plantsFuture = ApiService.instance.getPlants();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectPlant(Plant plant) async {
    setState(() {
      _selectedPlant = plant;
      _loadingUsers = true;
      _users = const [];
    });

    try {
      final users = await ApiService.instance.getPlantUsers(plant.id);
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _createLogin() async {
    final plant = _selectedPlant;
    if (plant == null) {
      showMessage(context, 'Select a plant first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _creating = true);
    try {
      await ApiService.instance.createPlantLogin(
        plantId: plant.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();

      final users = await ApiService.instance.getPlantUsers(plant.id);
      if (!mounted) return;
      setState(() => _users = users);
      showMessage(context, 'Plant login created successfully.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Login Credentials'),
      ),
      body: FutureBuilder<List<Plant>>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          _plants = snapshot.data ?? const [];
          if (_plants.isEmpty) {
            return const EmptyView(
              icon: Icons.factory_outlined,
              title: 'No plants available',
              message: 'There are no active plants to assign a login.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Plant Sign-in',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose the plant and create credentials. The account is stored directly in the users table and can sign in only for that assigned plant.',
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        value: _selectedPlant?.id,
                        decoration: const InputDecoration(
                          labelText: 'Select Plant',
                          prefixIcon: Icon(Icons.factory_outlined),
                        ),
                        items: _plants
                            .map(
                              (plant) => DropdownMenuItem<int>(
                                value: plant.id,
                                child: Text(
                                  '${plant.companyName} • ${plant.plantName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final plant = _plants.firstWhere((p) => p.id == id);
                          _selectPlant(plant);
                        },
                      ),
                      const SizedBox(height: 18),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'User Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 2
                                      ? 'Enter the user name.'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Login Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (!email.contains('@') || !email.contains('.')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone (optional)',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => value == null || value.length < 8
                                  ? 'Use at least 8 characters.'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _creating ? null : _createLogin,
                                icon: _creating
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.person_add_alt_1),
                                label: Text(
                                  _creating
                                      ? 'Creating Login...'
                                      : 'Create Plant Login',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _selectedPlant == null
                    ? 'Existing Plant Logins'
                    : 'Existing Logins • ${_selectedPlant!.plantName}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (_selectedPlant == null)
                const Text('Select a plant to view its assigned login accounts.')
              else if (_loadingUsers)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_users.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.person_off_outlined),
                    title: Text('No plant login created yet'),
                  ),
                )
              else
                ..._users.map(
                  (user) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (user['name']?.toString().isNotEmpty ?? false)
                              ? user['name'].toString()[0].toUpperCase()
                              : 'U',
                        ),
                      ),
                      title: Text(user['name']?.toString() ?? ''),
                      subtitle: Text(
                        [
                          user['email']?.toString(),
                          if ((user['phone']?.toString() ?? '').isNotEmpty)
                            user['phone'].toString(),
                        ].whereType<String>().join(' • '),
                      ),
                      trailing: StatusBadge(
                        value: user['is_active'] == true ? 'active' : 'inactive',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
