import 'package:flutter/material.dart';

import '../../routes/flux_navigate.dart';
import '../../services/katina_forms_api.dart';
import 'service_form_screen.dart';

class ServiceFormsListScreen extends StatefulWidget {
  const ServiceFormsListScreen({super.key});

  @override
  State<ServiceFormsListScreen> createState() => _ServiceFormsListScreenState();
}

class _ServiceFormsListScreenState extends State<ServiceFormsListScreen> {
  late Future<List<KatinaServiceForm>> _future;

  @override
  void initState() {
    super.initState();
    _future = KatinaFormsApi.listForms();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات كاتينة'),
        backgroundColor: theme.primaryColor,
      ),
      body: FutureBuilder<List<KatinaServiceForm>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _future = KatinaFormsApi.listForms();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }
          final forms = (snap.data ?? [])
              .where((f) => f.id != 'parts' && f.id != 'contact')
              .toList();
          if (forms.isEmpty) {
            return const Center(child: Text('لا توجد خدمات حالياً'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: forms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final form = forms[i];
              return Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    FluxNavigate.push(
                      MaterialPageRoute(
                        builder: (_) => ServiceFormScreen(formId: form.id),
                      ),
                      context: context,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: form.image.isNotEmpty
                              ? Image.network(
                                  form.image,
                                  width: 72,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 56,
                                    color: theme.primaryColor.withOpacity(0.15),
                                    child: Icon(Icons.build,
                                        color: theme.primaryColor),
                                  ),
                                )
                              : Container(
                                  width: 72,
                                  height: 56,
                                  color: theme.primaryColor.withOpacity(0.15),
                                  child: Icon(Icons.build,
                                      color: theme.primaryColor),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            form.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.chevron_left),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
