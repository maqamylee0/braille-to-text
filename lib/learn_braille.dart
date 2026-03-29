import 'package:flutter/material.dart';

class LearnBraillePage extends StatelessWidget {
  const LearnBraillePage({super.key});

  static const Map<String, List<int>> _patterns = {
    'A': [1],         'B': [1,2],       'C': [1,4],     'D': [1,4,5],
    'E': [1,5],       'F': [1,2,4],     'G': [1,2,4,5], 'H': [1,2,5],
    'I': [2,4],       'J': [2,4,5],     'K': [1,3],     'L': [1,2,3],
    'M': [1,3,4],     'N': [1,3,4,5],   'O': [1,3,5],   'P': [1,2,3,4],
    'Q': [1,2,3,4,5], 'R': [1,2,3,5],   'S': [2,3,4],   'T': [2,3,4,5],
    'U': [1,3,6],     'V': [1,2,3,6],   'W': [2,4,5,6], 'X': [1,3,4,6],
    'Y': [1,3,4,5,6], 'Z': [1,3,5,6],
  };

  // Dot position layout explanation
  static const String _dotGuide =
      'Braille dots are numbered 1–6:\n'
      '1 • 4\n'
      '2 • 5\n'
      '3 • 6';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final letters = _patterns.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Braille Alphabet'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Dot numbering guide banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colorScheme.primaryContainer,
            child: Row(
              children: [
                const _StaticBrailleCell(activeDots: [1, 2, 3, 4, 5, 6]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to read braille dots',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Each cell has 6 positions arranged in 2 columns of 3.\n'
                        'Left col: 1 (top), 2 (mid), 3 (bottom)\n'
                        'Right col: 4 (top), 5 (mid), 6 (bottom)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Alphabet grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: letters.length,
              itemBuilder: (context, index) {
                final letter = letters[index];
                final dots = _patterns[letter]!;
                return _BrailleCard(
                  letter: letter,
                  activeDots: dots,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BrailleCard extends StatelessWidget {
  final String letter;
  final List<int> activeDots;

  const _BrailleCard({required this.letter, required this.activeDots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large letter
          Text(
            letter,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),

          // Braille cell
          _StaticBrailleCell(activeDots: activeDots),

          const SizedBox(height: 8),

          // Dot numbers
          Text(
            activeDots.join('  '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A static (non-animated) braille cell widget for use in the learn page.
class _StaticBrailleCell extends StatelessWidget {
  final List<int> activeDots;
  final double dotSize;

  const _StaticBrailleCell({
    required this.activeDots,
    this.dotSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget dot(int number) {
      final bool active = activeDots.contains(number);
      return Container(
        width: dotSize,
        height: dotSize,
        margin: EdgeInsets.all(dotSize * 0.3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? colorScheme.primary : colorScheme.outlineVariant,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 4,
                  )
                ]
              : null,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(children: [dot(1), dot(2), dot(3)]),
        Column(children: [dot(4), dot(5), dot(6)]),
      ],
    );
  }
}
