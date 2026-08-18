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
  List<Map<String, dynamic>> _allUsers = const [];
  bool _loadingUsers = true;
  bool _creating = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _plantsFuture = ApiService.instance.getPlants();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await ApiService.instance.getAllPlantUsers();
      if (!mounted) return;
      setState(() => _allUsers = users);
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
      await _loadAllUsers();
      if (mounted) showMessage(context, 'Plant login created successfully.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']?.toString() ?? '');
    final emailController = TextEditingController(text: user['email']?.toString() ?? '');
    final phoneController = TextEditingController(text: user['phone']?.toString() ?? '');
    final passwordController = TextEditingController();
    var plantId = int.tryParse(user['plant_id'].toString()) ?? 0;
    var isActive = user['is_active'] == true;
    var obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Plant Login'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: plantId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Plant',
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
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => plantId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'User Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Login Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password (optional)',
                        helperText: 'Leave blank to keep the existing password.',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      title: const Text('Account active'),
                      subtitle: const Text('Turn off to block this user from signing in.'),
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (nameController.text.trim().length < 2) {
                    showMessage(context, 'Enter the user name.');
                    return;
                  }
                  final email = emailController.text.trim();
                  if (!email.contains('@') || !email.contains('.')) {
                    showMessage(context, 'Enter a valid email address.');
                    return;
                  }
                  if (passwordController.text.isNotEmpty &&
                      passwordController.text.length < 8) {
                    showMessage(context, 'New password must use at least 8 characters.');
                    return;
                  }

                  try {
                    await ApiService.instance.updatePlantLogin(
                      userId: int.parse(user['id'].toString()),
                      plantId: plantId,
                      name: nameController.text.trim(),
                      email: email,
                      phone: phoneController.text.trim(),
                      password: passwordController.text,
                      isActive: isActive,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } on ApiException catch (error) {
                    if (context.mounted) showMessage(context, error.message);
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();

    if (saved == true) {
      await _loadAllUsers();
      if (mounted) showMessage(context, 'Plant login updated successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Login Credentials'),
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: _loadAllUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
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

          return RefreshIndicator(
            onRefresh: _loadAllUsers,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created Plant Users: ${_allUsers.length}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All plant users stored in the database are shown below. You can create new credentials or edit an existing account.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
                        const SizedBox(height: 16),
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
                            setState(() {
                              _selectedPlant = _plants.firstWhere((p) => p.id == id);
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
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
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Login Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  return !email.contains('@') || !email.contains('.')
                                      ? 'Enter a valid email address.'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
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
                  'All Created Users (${_allUsers.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (_loadingUsers)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_allUsers.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.person_off_outlined),
                      title: Text('No plant users created yet'),
                    ),
                  )
                else
                  ..._allUsers.map(
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
                            user['email']?.toString() ?? '',
                            user['company_name']?.toString() ?? '',
                            user['plant_name']?.toString() ?? '',
                            if ((user['phone']?.toString() ?? '').isNotEmpty)
                              user['phone'].toString(),
                          ].where((value) => value.isNotEmpty).join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(
                              value: user['is_active'] == true ? 'active' : 'inactive',
                            ),
                            IconButton(
                              tooltip: 'Edit credentials',
                              onPressed: () => _editUser(user),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
