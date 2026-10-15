import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/form.dart';

// Step 6 Your workers · Step 7 Financial projection (Annex D 5C) · Step 8 Your loan (last step).
// Requirement PDFs are uploaded once, at the end, on the Upload requirements screen.

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});
  @override
  Widget build(BuildContext context) => StepPage(
        step: 6,
        title: 'Your workers',
        onNext: () => Navigator.pushNamed(context, '/projection'),
        children: [
          ListQ.bound(
            context,
            'workers',
            label: 'Who works for you? Do not include yourself.',
            addLabel: 'Add a worker',
            fields: const [
              FieldSpec('name', 'Name', hint: 'Example: Ana Reyes', required: true),
              FieldSpec('sex', 'Male or female', type: FieldType.select, options: ['Female', 'Male'], half: true),
              FieldSpec('status', 'Kind of work', type: FieldType.select, options: ['Regular', 'Contract', 'Part-time', 'Seasonal', 'Other'], half: true),
              FieldSpec('work', 'What do they do?', hint: 'Example: Baker', required: true),
              FieldSpec('years', 'Years with you', type: FieldType.number, half: true),
              FieldSpec('iloilo', 'Lives in Iloilo?', type: FieldType.select, options: ['Yes', 'No'], half: true),
            ],
            detail: (r) => '${r['work'] ?? ''} · ${r['status'] ?? ''} · ${r['years'] ?? '—'} years',
          ),
        ],
      );
}

class ProjectionScreen extends StatelessWidget {
  const ProjectionScreen({super.key});
  @override
  Widget build(BuildContext context) => StepPage(
        step: 7,
        title: 'Financial projection',
        onNext: () => Navigator.pushNamed(context, '/loan'),
        children: const [
          SectionHead('For the next 12 months', sub: 'For the business plan (Annex D)'),
          PesoQ('es', 'Expected annual sales', eg: 'All the money you expect from selling in one year.'),
          PesoQ('ex', 'Expected annual expenses', eg: 'All the money you expect to spend to run the business in one year.'),
          PesoQ('gi', 'Expected annual gross income', eg: 'Sales minus the cost of the goods you sell.'),
          PesoQ('ni', 'Expected annual net income', eg: 'What is left after all expenses.'),
        ],
      );
}

/// Step 8 · only the amount. A LIDEP officer audits how the loan was used
/// about 3 months after release, so the app does not ask for a spending list.
class LoanScreen extends StatelessWidget {
  const LoanScreen({super.key});
  @override
  Widget build(BuildContext context) => StepPage(
        step: 8,
        title: 'Your loan',
        nextLabel: 'Finish',
        onNext: () => Navigator.pushNamed(context, '/check'),
        children: const [
          SectionHead('Your loan', sub: 'For the application form'),
          PesoQ('la', 'How much do you want to borrow?'),
          NoteBox('You do not need to list what you will buy. About 3 months after you get the money, a LIDEP officer will visit to check how the loan was used.'),
        ],
      );
}
