import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/checks.dart';
import '../../logic/format.dart';
import '../../state/app_state.dart';
import '../../widgets/form.dart';

// Step 1 About you · Step 2 Your business · Step 3 What you sell · Step 4 Costs
// Questions follow the OLEDIPO forms (Annex A application, Annex C barangay
// certificate, Annex D business plan) in plain words.

class AboutYouScreen extends StatelessWidget {
  const AboutYouScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = app.data.mobile;
    return StepPage(
      step: 1,
      title: 'About you',
      onNext: () => Navigator.pushNamed(context, '/business'),
      children: [
        const SectionHead('Your name and home', sub: 'For the application form. We filled in your name from your account.'),
        const TextQ('ln', 'Surname', hint: 'Example: Santos'),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 13, child: TextQ('fn', 'First name', hint: 'Example: Maria')),
          SizedBox(width: 10),
          Expanded(flex: 10, child: TextQ('mn', 'Middle name', hint: 'Example: Lopez')),
        ]),
        const TextQ('a1', 'House number and street', hint: 'Example: 12 Rizal St.'),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextQ('a2', 'Barangay', hint: 'Tabuc Suba')),
          SizedBox(width: 10),
          Expanded(child: TextQ('a3', 'Town or city', hint: 'Iloilo City')),
        ]),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 14, child: TextQ('a4', 'Province', hint: 'Iloilo')),
          SizedBox(width: 10),
          Expanded(flex: 10, child: TextQ('a5', 'Zip code', hint: '5000', keyboard: TextInputType.number)),
        ]),
        const ChipsQ('dist', 'Congressional district of Iloilo', ['1st', '2nd', '3rd', '4th', '5th'], eg: 'Not sure? Ask your barangay hall.'),
        const DateQ('dob', 'Birthday'),
        const ChipsQ('sex', 'Are you male or female?', ['Male', 'Female']),
        const ChipsQ('civ', 'Civil status', ['Single', 'Married', 'Widowed', 'Separated']),
        const SectionHead('How to reach you', sub: 'For the application form and business plan'),
        ReadOnlyQ('Mobile number', m.isEmpty ? '—' : m, note: 'From your account'),
        const TextQ('em', 'Email (if you have one)', hint: 'name@example.com', keyboard: TextInputType.emailAddress),
        const TextQ('fb', 'Facebook name (if you have one)', hint: 'The name on your Facebook account'),
        const TextQ('tin', 'TIN (tax ID number)', hint: '000-000-000-000', keyboard: TextInputType.number, eg: 'Leave blank if you do not have one yet.'),
        const TextQ('bank', 'Which bank do you use?', hint: 'Example: Landbank', eg: 'Leave blank if none.'),
        const SectionHead('Your barangay', sub: 'For the barangay certificate'),
        const TextQ('since', 'What year did you start living in your barangay?', hint: 'Example: 2012', keyboard: TextInputType.number, eg: 'Your barangay captain will confirm this.'),
        const SectionHead('Your experience', sub: 'For the business plan'),
        const TextQ('exp', 'How long have you done this work, and what did you learn?', hint: 'Example: 6 years baking piaya. Joined a DTI food safety seminar.', maxLines: 4),
      ],
    );
  }
}

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final elsewhere = app.one('loc') == 'Somewhere else';
    return StepPage(
      step: 2,
      title: 'Your business',
      onNext: () => Navigator.pushNamed(context, '/products'),
      children: [
        const SectionHead('About the business', sub: 'For the application form and business plan'),
        const TextQ('bn', 'Business name', hint: 'Example: Lola Nena’s Piaya'),
        const TextQ('pj', 'What will the loan help you do?', hint: 'Example: Make more piaya each week', eg: 'A short title for your plan.'),
        const ChipsQ('loc', 'Where is the business?', ['At my home', 'Somewhere else'], eg: 'If it is at home, we use the address you gave in Step 1.'),
        if (elsewhere) ...[
          const TextQ('b1', 'House number and street', hint: 'Example: 12 Rizal St.'),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextQ('b2', 'Barangay', hint: 'Tabuc Suba')),
            SizedBox(width: 10),
            Expanded(child: TextQ('b3', 'Town or city', hint: 'Iloilo City')),
          ]),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 14, child: TextQ('b4', 'Province', hint: 'Iloilo')),
            SizedBox(width: 10),
            Expanded(flex: 10, child: TextQ('b5', 'Zip code', hint: '5000', keyboard: TextInputType.number)),
          ]),
        ],
        const DateQ('os', 'When did the business start?', monthOnly: true, eg: 'Your financial statements start from this year.'),
        const ChipsQ('own', 'Who owns the business?', ['Only me', 'Me and partners', 'Other']),
        const TextQ('bd', 'Describe your business in one or two sentences', hint: 'Example: I bake piaya at home and sell to stores in Jaro.', maxLines: 4),
        const SectionHead('Hard times', sub: 'For the barangay certificate'),
        const ChipsQ('cr', 'During a pandemic, typhoon or other crisis, did your business…',
            ['Close for 1 month or more', 'Lose at least 1/5 of sales for 2 months', 'Neither'],
            eg: 'Your barangay captain will check this with your ITR or records.'),
      ],
    );
  }
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return StepPage(
      step: 3,
      title: 'What you sell',
      onNext: () => Navigator.pushNamed(context, app.costRoute),
      children: [
        const SectionHead('What you do', sub: 'For the application form'),
        const ChipsQ('bt', 'What kind of business is it?', ['I make products', 'I buy and resell', 'I offer a service']),
        const SectionHead('What you sell', sub: 'For the application form and business plan'),
        ListQ.bound(
          context,
          'products',
          label: 'What do you sell? (up to 5)',
          addLabel: 'Add something you sell',
          max: 5,
          fields: const [
            FieldSpec('name', 'Name', hint: 'Example: Piaya', required: true),
            FieldSpec('unit', 'Sold by', hint: 'Pack, piece, kilo', half: true),
            FieldSpec('price', 'Price', type: FieldType.peso, required: true, half: true),
          ],
          detail: (r) => (r['unit'] ?? '').isEmpty ? '' : 'Per ${r['unit']}',
          amount: (r) => amt(r['price']) ?? 0,
        ),
        const TextQ('pd', 'Tell us about it. What makes it good?', hint: 'Example: Fresh piaya with muscovado filling, baked daily.', maxLines: 4),
        const SectionHead('Your customers', sub: 'For the business plan'),
        const ChipsQ('tm', 'Who buys from you? Tap all that apply.', ['Sari-sari stores', 'Pasalubong shops', 'Households', 'Offices', 'Tourists', 'Walk-in'], multi: true),
        const ChipsQ('ma', 'Where are your customers? Tap all that apply.', ['My barangay', 'My town or city', 'Other towns in Iloilo', 'Outside Iloilo'], multi: true),
        const ChipsQ('md', 'How do people hear about you? Tap all that apply.',
            ['Friends and neighbors', 'Facebook', 'Flyers or tarpaulin', 'Store sign', 'Radio', 'Market stall'],
            multi: true),
      ],
    );
  }
}

/// Step 4, one of three versions depending on the kind of business:
/// prod (Making your product), resell (Buying your goods), service (Your service supplies).
class CostsScreen extends StatelessWidget {
  final String kind;
  const CostsScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (kind) {
      'resell' => (
          title: 'Buying your goods',
          period: 'One week of buying',
          sub: 'For the business plan. Think of one normal week.',
          listLabel: 'What do you buy to resell?',
          item: 'Item',
          itemHint: 'Example: Rice',
          add: 'Add item',
          tools: false,
          other: 'Other costs for one week',
          units: 'How much quantity can you make?',
        ),
      'service' => (
          title: 'Your service supplies',
          period: 'One week of work',
          sub: 'For the business plan. Think of one normal week.',
          listLabel: 'What supplies do you use?',
          item: 'Supply',
          itemHint: 'Example: Shampoo',
          add: 'Add supply',
          tools: true,
          other: 'Other costs for one week',
          units: 'How many customers do you serve with this?',
        ),
      _ => (
          title: 'Making your product',
          period: 'One batch',
          sub: 'For the business plan. Think of one normal batch.',
          listLabel: 'What do you buy to make it?',
          item: 'Material',
          itemHint: 'Example: Flour',
          add: 'Add material',
          tools: true,
          other: 'Other costs for one batch',
          units: 'How many do you make from this?',
        ),
    };
    return StepPage(
      step: 4,
      title: cfg.title,
      onNext: () => Navigator.pushNamed(context, '/financials'),
      children: [
        SectionHead(cfg.period, sub: cfg.sub),
        ListQ.bound(
          context,
          'raw_$kind',
          label: cfg.listLabel,
          addLabel: cfg.add,
          fields: [
            FieldSpec('name', cfg.item, hint: cfg.itemHint, required: true),
            const FieldSpec('source', 'Where do you buy it?', hint: 'Example: Iloilo Terminal Market'),
            const FieldSpec('qty', 'How many?', type: FieldType.number, required: true, half: true),
            const FieldSpec('unit', 'Counted in', hint: 'kilo, piece', half: true),
            const FieldSpec('price', 'Price for each one', type: FieldType.peso, required: true),
          ],
          detail: (r) => '${r['qty'] ?? '—'} ${r['unit'] ?? ''} × ${peso(amt(r['price']))}${(r['source'] ?? '').isEmpty ? '' : ' · ${r['source']}'}',
          amount: qtyTimesPrice,
        ),
        if (cfg.tools) ...[
          const SectionHead('Your tools', sub: 'For the business plan'),
          ListQ.bound(
            context,
            'tools_$kind',
            label: 'What tools and equipment do you use?',
            addLabel: 'Add a tool',
            fields: const [FieldSpec('name', 'Tool or equipment', hint: 'Example: Oven', required: true)],
          ),
        ],
        const SectionHead('Other costs', sub: 'For the business plan'),
        PesoQ('lab_$kind', 'How much do you pay workers for this?'),
        ListQ.bound(
          context,
          'ovh_$kind',
          label: cfg.other,
          eg: 'Put each bill on its own line.',
          addLabel: 'Add another cost',
          fields: const [
            FieldSpec('name', 'What is the cost?', hint: 'Example: Electricity', required: true),
            FieldSpec('cost', 'How much?', type: FieldType.peso, required: true),
          ],
          amount: costOf,
        ),
        TextQ('units_$kind', cfg.units, hint: 'Example: 50', keyboard: TextInputType.number),
      ],
    );
  }
}
