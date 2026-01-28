import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../ai/domain/entities/ai_settings.dart';
import '../../../ai/presentation/providers/ai_settings_provider.dart';

/// Section for AI settings in the Settings screen
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  late TextEditingController _customPromptController;

  @override
  void initState() {
    super.initState();
    _customPromptController = TextEditingController();
  }

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);

    // Update controller when settings change
    if (settings.customPromptTemplate != null &&
        _customPromptController.text != settings.customPromptTemplate) {
      _customPromptController.text = settings.customPromptTemplate!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language dropdown
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Lingua riassunti'),
            subtitle: Text(settings.languageDisplayName),
            trailing: DropdownButton<String>(
              value: settings.language,
              underline: const SizedBox(),
              items: SupportedLanguages.options.map((lang) {
                return DropdownMenuItem(
                  value: lang.code,
                  child: Text(lang.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(aiSettingsProvider.notifier).setLanguage(value);
                }
              },
            ),
          ),
          const Divider(height: 1),
          // Template dropdown
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Stile riassunto'),
            subtitle: Text(_getTemplateName(settings.promptTemplateId)),
            trailing: DropdownButton<String>(
              value: settings.promptTemplateId,
              underline: const SizedBox(),
              items: PromptTemplates.options.map((template) {
                return DropdownMenuItem(
                  value: template.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(template.name),
                      Text(
                        template.description,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(aiSettingsProvider.notifier).setPromptTemplate(value);
                }
              },
            ),
          ),
          // Custom prompt field (only visible when "custom" is selected)
          if (settings.promptTemplateId == 'custom') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Template personalizzato',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customPromptController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Inserisci il tuo prompt personalizzato...',
                      border: OutlineInputBorder(),
                      helperText: 'Variabili: {{text}}, {{language}}, {{unit_type}}, {{unit_number}}',
                      helperMaxLines: 2,
                    ),
                    onChanged: (value) {
                      ref.read(aiSettingsProvider.notifier).setCustomPrompt(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    children: [
                      _VariableChip(label: '{{text}}', description: 'Testo della pagina'),
                      _VariableChip(label: '{{language}}', description: 'Lingua'),
                      _VariableChip(label: '{{unit_type}}', description: 'pagina/capitolo'),
                      _VariableChip(label: '{{unit_number}}', description: 'Numero'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTemplateName(String templateId) {
    return PromptTemplates.options
        .firstWhere(
          (t) => t.id == templateId,
          orElse: () => PromptTemplates.options.first,
        )
        .name;
  }
}

class _VariableChip extends StatelessWidget {
  const _VariableChip({
    required this.label,
    required this.description,
  }) : super(key: null);

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description,
      child: Chip(
        label: Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
