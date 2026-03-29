import 'dart:convert';
import 'package:http/http.dart' as http;

class LlmHelper {
  // Get a free key at https://aistudio.google.com/app/apikey
  static const String _apiKey = 'AIzaSyBku9bnlK6Se7yMJwKO6T2S3TbUiK6SWno';

  static const String _url =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  static Future<String?> suggestCorrection(String rawText) async {
    if (rawText.trim().isEmpty) return null;

    final prompt = '''
You are helping a teacher read braille text scanned by an OCR app.
The OCR output may have errors:
- A dash (-) means a character was not detected
- A space means a word boundary
- Some letters may be wrong due to image quality

Raw OCR output: "$rawText"

Give your best interpretation of what this text is trying to say.
Correct obvious errors and fill in missing characters where context is clear.
Reply with ONLY the corrected text, no explanation.
''';

    try {
      final response = await http.post(
        Uri.parse('$_url?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 256,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text']
            ?.toString()
            .trim();
      } else {
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      return 'Suggestion unavailable: $e';
    }
  }
}
