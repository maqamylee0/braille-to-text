import 'package:flutter/services.dart' show rootBundle;

class CorrectionHelper {
  static Set<String>? _dictionary;
  static List<String>? _orderedDictionary;

  static Future<void> _loadDictionary() async {
    if (_dictionary != null) return;
    try {
      final String data = await rootBundle.loadString('assets/english.txt');
      _orderedDictionary = data
          .split('\n')
          .map((w) => w.trim().toLowerCase())
          .where((w) => w.isNotEmpty)
          .toList();
      _dictionary = _orderedDictionary!.toSet();
    } catch (e) {
      _dictionary = {};
      _orderedDictionary = [];
    }
  }

  static Future<String?> suggestCorrection(String rawText) async {
    if (rawText.trim().isEmpty) return null;
    await _loadDictionary();

    final lines = rawText.split('\n');
    final correctedLines = <String>[];

    for (var line in lines) {
      final words = line.split(' ');
      final correctedWords = <String>[];

      for (var word in words) {
        if (word.isEmpty) {
          correctedWords.add('');
          continue;
        }

        final lowerWord = word.toLowerCase();

        // 1. Exact match
        if (_dictionary!.contains(lowerWord)) {
          correctedWords.add(word);
          continue;
        }

        // 2. Handle missing characters (-) using Regex
        // if (word.contains('-')) {
        //   // If dash is at the end, allow it to match 1 or more characters (suffix)
        //   String patternString;
        //   if (word.endsWith('-')) {
        //      patternString = '^${word.replaceAll('-', '.')}.*\$';
        //   } else {
        //      patternString = '^${word.replaceAll('-', '.')}\$';
        //   }
        //
        //   final regex = RegExp(patternString, caseSensitive: false);
        //   String? match;
        //   try {
        //     // Check ordered dictionary to get most frequent match first
        //     match = _orderedDictionary!.firstWhere((w) => regex.hasMatch(w));
        //   } catch (_) {}
        //
        //   if (match != null) {
        //     correctedWords.add(match);
        //     continue;
        //   }
        // }

        // 3. Typo/Suffix Correction
        if (word.length > 2) {
          final closest = _findClosestWord(lowerWord);
          if (closest != null) {
            correctedWords.add(closest.toUpperCase());
            continue;
          }
        }

        correctedWords.add(word);
      }
      correctedLines.add(correctedWords.join(' '));
    }

    return correctedLines.join('\n');
  }

  static String? _findClosestWord(String word) {
    String? bestMatch;
    double bestScore = double.infinity;

    for (final dictWord in _dictionary!) {
      int lenDiff = (dictWord.length - word.length).abs();

      // Skip extremely different lengths
      if (lenDiff > 3) continue;

      final dist = _levenshtein(word, dictWord);

      // 🔥 Normalize distance (VERY IMPORTANT)
      double score = dist / dictWord.length;

      // 🔥 Slightly prefer longer words (fixes "endow" -> "endowed")
      if (dictWord.length > word.length) {
        score -= 0.05;
      }

      if (score < bestScore) {
        bestScore = score;
        bestMatch = dictWord;
      }
    }

    // 🔥 Threshold to avoid garbage matches
    if (bestScore < 0.4) {
      return bestMatch;
    }

    return null;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  static int _min3(int a, int b, int c) {
    if (a < b) return a < c ? a : c;
    return b < c ? b : c;
  }
}
