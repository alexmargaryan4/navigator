import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';

/// Raw call to Groq's OpenAI-compatible chat completions endpoint,
/// constrained to return strict JSON.
///
/// This datasource returns the *raw* decoded JSON object the model
/// produced — validation into a safe [AiNavigationCommand] happens one
/// layer up in `AiNavigationService`, which is the only place allowed to
/// decide the command is safe to act on.
class GroqAiDataSource {
  GroqAiDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const String _systemPrompt = '''
You are a navigation intent parser. You NEVER invent coordinates, ETAs,
distances, traffic conditions, road names, or parking availability —
you only extract structured intent from the user's natural-language
request. Respond with ONLY a single JSON object, no prose, no markdown
fences, matching exactly this schema:

{
  "action": "calculate_route" | "find_parking" | "clarification_needed" | "unsupported",
  "destination_query": string | null,
  "mode": "driving" | "walking" | "cycling" | null,
  "avoid_tolls": boolean,
  "avoid_highways": boolean,
  "arrive_by_time": string | null,
  "clarification_question": string | null
}

Rules:
- "destination_query" is free text to be geocoded later (e.g. "Zvartnots Airport", "Republic Square") — never coordinates.
- If the user's request is about public transit, taxis, buses, or trains, respond with action "unsupported".
- If the request is ambiguous (e.g. missing a destination), respond with action "clarification_needed" and a short "clarification_question".
- "arrive_by_time" should be a 24-hour "HH:mm" string if a specific time was mentioned, otherwise null.
- Default "mode" to "driving" only if the user clearly wants to travel and didn't specify a mode; otherwise null.
- Output strict JSON only. No commentary.
''';

  Future<Result<Map<String, dynamic>>> parseIntent(String userText) async {
    if (!AppConfig.hasGroqKey) {
      return const Result.err(ConfigurationFailure());
    }

    final uri = Uri.parse('${AppConfig.groqBaseUrl}/chat/completions');
    final result = await _client.postJson(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
      },
      body: {
        'model': AppConfig.groqModel,
        'temperature': 0,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userText},
        ],
      },
    );

    return result.when(
      ok: (json) => _extractContentJson(json),
      err: (f) => Result.err(f),
    );
  }

  Result<Map<String, dynamic>> _extractContentJson(Map<String, dynamic> json) {
    try {
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return const Result.err(AiNavigationFailure());
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        return const Result.err(AiNavigationFailure());
      }

      final trimmed = content.trim();
      if (!trimmed.startsWith('{')) {
        return const Result.err(AiNavigationFailure());
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return const Result.err(AiNavigationFailure());
      }
      return Result.ok(decoded);
    } catch (e) {
      return Result.err(AiNavigationFailure(technicalDetail: e.toString()));
    }
  }
}
