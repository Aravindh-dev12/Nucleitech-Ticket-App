import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common_widgets.dart';

class RaiseTicketScreen extends StatefulWidget {
  const RaiseTicketScreen({
    super.key,
    required this.plant,
  });

  final Plant plant;

  @override
  State<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends State<RaiseTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  static const _categories = [
    'Inverter',
    'VCB / Breaker',
    'SCADA Communication',
    'Electrical',
    'Mechanical',
    'Network',
    'Sensor',
    'Production',
    'Safety',
    'General',
  ];

  static const _priorities = ['low', 'medium', 'high', 'critical'];

  String _category = 'General';
  String _priority = 'medium';
  List<XFile> _images = [];
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await _picker.pickMultiImage(
      imageQuality: 82,
      limit: 6,
    );
    if (selected.isNotEmpty) {
      setState(() {
        _images = [..._images, ...selected].take(6).toList();
      });
    }
  }

  Future<void> _takePhoto() async {
    final selected = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (selected != null && _images.length < 6) {
      setState(() => _images = [..._images, selected]);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final result = await ApiService.instance.createTicket(
        plantId: widget.plant.id,
        category: _category,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        images: _images,
      );

      if (!mounted) return;
      final ticket = result['ticket'] as Map<String, dynamic>;
      final ticketNumber = ticket['ticket_number']?.toString() ?? '';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 56,
          ),
          title: const Text('Ticket Raised Successfully'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your plant issue has been recorded and the complete ticket details have been sent to info@orikscare.com. NUCLEI TECH support will review the issue and resolve it manually.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SelectableText(
                  ticketNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF084298),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      showMessage(context, error.message);
    } catch (_) {
      showMessage(context, 'Unable to send the ticket.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raise Plant Ticket'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  const Center(child: BrandLogo(width: 230, height: 74)),
                  const SizedBox(height: 16),
                  Text(
                    'Report a Plant Issue',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF084298),
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Submit the issue with clear plant and fault details. Support receives the ticket by email and will update the resolution manually.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5B6B82), height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(0xFFE7F0FF),
                                foregroundColor: Color(0xFF0B5ED7),
                                child: Icon(Icons.solar_power_outlined),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.plant.plantName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(widget.plant.companyName),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        StatusBadge(
                                          value: widget.plant.capacityLabel,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FBFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD8E6FA),
                              ),
                            ),
                            child: const Text(
                              'This plant is attached automatically to the ticket. The email sent to support includes the ticket number, company, plant name, issue category, priority, user details and description.',
                              style: TextStyle(
                                color: Color(0xFF41536D),
                                height: 1.45,
                              ),
                            ),
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
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Issue Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _categories
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _subjectController,
                            maxLength: 255,
                            decoration: const InputDecoration(
                              labelText: 'Issue Title',
                              hintText: 'Example: Inverter 1 data is not coming',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 5
                                    ? 'Enter a clear issue title.'
                                    : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            minLines: 5,
                            maxLines: 10,
                            decoration: const InputDecoration(
                              labelText: 'Issue Description',
                              hintText:
                                  'Mention the inverter/VCB/device name, observed fault, error code if any, when the issue started, and checks already completed.',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 10
                                    ? 'Describe the issue in more detail.'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              prefixIcon: Icon(Icons.priority_high),
                            ),
                            items: _priorities
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(prettyLabel(item)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _priority = value);
                              }
                            },
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
                            'Issue Images',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Attach up to six images to help support understand the issue.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _images.length >= 6 ? null : _takePhoto,
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Camera'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _images.length >= 6 ? null : _pickImages,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Gallery'),
                              ),
                            ],
                          ),
                          if (_images.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (var index = 0;
                                    index < _images.length;
                                    index++)
                                  _ImagePreview(
                                    file: _images[index],
                                    onRemove: () {
                                      setState(() => _images.removeAt(index));
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _submitting
                          ? 'Submitting Ticket...'
                          : 'Submit Ticket to NUCLEI TECH',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.file,
    required this.onRemove,
  });

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 110,
                height: 110,
                child: snapshot.hasData
                    ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 17),
              ),
            ),
          ],
        );
      },
    );
  }
}
