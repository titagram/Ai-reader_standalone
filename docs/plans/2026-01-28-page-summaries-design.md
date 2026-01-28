# Design: Riassunti Pagina per Pagina con Personalizzazione Prompt

**Data:** 2026-01-28
**Stato:** Approvato

## Obiettivo

Ottimizzare l'app AI Reader per generare riassunti/spiegazioni pagina per pagina (o capitolo per capitolo per EPUB), con persistenza, UI intuitiva, supporto multilingua e personalizzazione del prompt.

## Requisiti Funzionali

1. **Riassunti on-demand per pagina/capitolo** - L'utente tocca un'icona per generare il riassunto della singola pagina (PDF) o capitolo (EPUB)
2. **Persistenza** - I riassunti generati vengono salvati nel database e riutilizzati
3. **Indicatore visivo** - Icona overlay su ogni pagina che cambia stato (grigio=non generato, verde=salvato, spinner=in corso)
4. **Selezione lingua** - Dropdown nelle impostazioni per scegliere Italiano o English
5. **Personalizzazione prompt** - Preset predefiniti + possibilità di creare template personalizzati
6. **Tono esplicativo** - Il prompt di default sarà orientato a spiegazioni didattiche

## Architettura

### Database

Nuova tabella `page_summaries`:

```sql
CREATE TABLE page_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_path TEXT NOT NULL,
  unit_number INTEGER NOT NULL,      -- page number (PDF) or chapter index (EPUB)
  unit_type TEXT NOT NULL,           -- 'page' or 'chapter'
  summary_text TEXT NOT NULL,
  prompt_template_id TEXT,           -- which template was used
  language TEXT DEFAULT 'it',
  created_at TEXT NOT NULL,
  UNIQUE(document_path, unit_number, unit_type)
);

CREATE INDEX idx_page_summaries_doc ON page_summaries(document_path);
```

La tabella `summaries` esistente (riassunti documento intero) rimane per retrocompatibilità ma non verrà più utilizzata per nuove generazioni.

### Impostazioni (SharedPreferences)

```dart
class AiSettings {
  final String language;              // 'it' | 'en'
  final String promptTemplateId;      // 'concise' | 'detailed' | 'keypoints' | 'custom'
  final String? customPromptTemplate; // template personalizzato (se promptTemplateId == 'custom')
}
```

### Prompt Templates Predefiniti

```dart
const promptTemplates = {
  'concise': '''
Riassumi brevemente in 2-3 frasi il contenuto di questa {{unit_type}} in {{language}}.
Sii conciso e vai dritto al punto.

Testo:
{{text}}
''',

  'detailed': '''
Spiega in modo chiaro e didattico il contenuto di questa {{unit_type}} in {{language}}.
Evidenzia i concetti chiave, fornisci contesto dove necessario, e usa un tono educativo
che aiuti a comprendere anche argomenti complessi.

Testo:
{{text}}
''',

  'keypoints': '''
Elenca i punti principali di questa {{unit_type}} in {{language}}.
Usa un formato a bullet point, con massimo 5-7 punti.
Ogni punto deve essere una frase completa e autosufficiente.

Testo:
{{text}}
''',
};
```

Variabili disponibili: `{{text}}`, `{{language}}`, `{{unit_type}}`, `{{unit_number}}`

### Provider Riverpod

```dart
// Impostazioni AI (persistite in SharedPreferences)
final aiSettingsProvider = StateNotifierProvider<AiSettingsNotifier, AiSettings>

// Cache riassunti per documento (evita query ripetute)
final documentSummariesProvider = FutureProvider.family<Map<int, PageSummary>, String>

// Singolo riassunto (usa cache sopra)
final pageSummaryProvider = Provider.family<PageSummary?, (String docPath, int unitNumber)>

// Stato generazione in corso
final summaryGenerationStateProvider = StateProvider<SummaryGenerationState>
```

### UI Components

#### 1. PageSummaryOverlay (PDF)

Widget `Stack` sovrapposto al `SfPdfViewer`:

```dart
class PageSummaryOverlay extends ConsumerWidget {
  // Posiziona icona in basso a destra della pagina visibile
  // Stati: pending (grigio), exists (verde), generating (spinner)
  // Tap: genera o mostra riassunto
  // Long press: menu opzioni (rigenera, elimina)
}
```

#### 2. ChapterSummaryOverlay (EPUB)

Simile ma per capitoli EPUB, posizionato nell'header del capitolo o come FAB contestuale.

#### 3. SummaryBottomSheet

```dart
class SummaryBottomSheet extends StatelessWidget {
  // Header: "Pagina X" o "Capitolo X"
  // Body: testo riassunto (scrollabile)
  // Footer: [Rigenera] [Copia] [Elimina]
}
```

#### 4. AiSettingsSection (in Settings)

```dart
class AiSettingsSection extends ConsumerWidget {
  // Dropdown lingua: Italiano / English
  // Dropdown stile: Conciso / Dettagliato / Punti chiave / Personalizzato
  // TextField per template custom (visibile solo se "Personalizzato")
  // Info sulle variabili disponibili
}
```

## Flusso Generazione

```
1. Utente tocca icona pagina/capitolo
   │
2. Controlla se esiste in DB (via pageSummaryProvider)
   │
   ├─ Esiste → Mostra SummaryBottomSheet
   │
   └─ Non esiste →
      │
      3. Estrai testo unità (extractTextFromPages o extractChapterText)
      │
      4. Carica template da AiSettings
      │
      5. Sostituisci variabili: {{text}}, {{language}}, {{unit_type}}, {{unit_number}}
      │
      6. Invia a Gemma (via summarizationProvider)
      │
      7. Salva in page_summaries
      │
      8. Aggiorna cache (invalidate documentSummariesProvider)
      │
      9. Mostra SummaryBottomSheet
```

## Migrazione

- La tabella `summaries` esistente NON viene eliminata
- I riassunti esistenti rimangono accessibili (eventuale sezione "Cronologia" legacy)
- Nuove generazioni usano esclusivamente `page_summaries`
- Il pulsante FAB attuale nella toolbar viene rimosso (sostituito dagli overlay)

## Predisposizione Futura: Chat con il Testo

L'architettura supporta una futura funzionalità "Parla con il testo":

1. I riassunti per pagina/capitolo fungono da knowledge base pre-indicizzata
2. Una query utente può cercare nei riassunti salvati per trovare contesto rilevante
3. Il contesto viene passato a Gemma insieme alla domanda per una risposta contestuale
4. Gemma supporta già conversazioni multi-turno

**Non in scope per questa implementazione**, ma il design non lo preclude.

## File da Modificare/Creare

### Nuovi File
- `lib/features/ai/domain/entities/ai_settings.dart`
- `lib/features/ai/domain/entities/page_summary.dart`
- `lib/features/ai/data/repositories/ai_settings_repository.dart`
- `lib/features/ai/data/repositories/page_summaries_repository.dart`
- `lib/features/ai/presentation/providers/ai_settings_provider.dart`
- `lib/features/ai/presentation/providers/page_summaries_provider.dart`
- `lib/features/ai/presentation/widgets/page_summary_overlay.dart`
- `lib/features/ai/presentation/widgets/summary_bottom_sheet.dart`
- `lib/features/settings/presentation/widgets/ai_settings_section.dart`

### File da Modificare
- `lib/features/storage/data/datasources/database_helper.dart` - aggiungere tabella
- `lib/features/reader/presentation/screens/reader_screen.dart` - aggiungere overlay
- `lib/features/reader/presentation/widgets/epub_viewer.dart` - aggiungere overlay capitoli
- `lib/features/settings/presentation/screens/settings_screen.dart` - aggiungere sezione AI
- `lib/features/ai/data/repositories/ai_model_repository_impl.dart` - usare template dinamico

## Decisioni di Design

| Decisione | Scelta | Motivazione |
|-----------|--------|-------------|
| Granularità | Pagina (PDF) / Capitolo (EPUB) | Unità naturali per ogni formato |
| Trigger | On-demand | Risparmia risorse, l'utente controlla |
| Storage lingua | Globale in Settings | Semplicità, coerenza |
| Prompt | Preset + Custom | Flessibilità senza complessità |
| UI riassunto | Bottom Sheet | Modale ma non invasivo |
| Overlay position | Angolo pagina | Discreto, sempre accessibile |
