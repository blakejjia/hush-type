import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HistoryItem {
  final int id;
  final DateTime timestamp;
  final String rawText;
  final String processedText;
  final bool llmUsed;

  HistoryItem({
    required this.id,
    required this.timestamp,
    required this.rawText,
    required this.processedText,
    required this.llmUsed,
  });

  factory HistoryItem.fromMap(Map<dynamic, dynamic> map) {
    return HistoryItem(
      id: map['id'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      rawText: map['raw_text'] as String,
      processedText: map['processed_text'] as String,
      llmUsed: (map['llm_used'] as int) == 1,
    );
  }
}

class HistoryService {
  static const _platform = MethodChannel('com.jia_yx.hashtype/ime');

  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  Future<List<HistoryItem>> getHistory({int limit = 100, int offset = 0}) async {
    try {
      final result = await _platform.invokeMethod<List<dynamic>>(
        'getHistory',
        {'limit': limit, 'offset': offset},
      );
      if (result == null) return [];
      return result.map((item) => HistoryItem.fromMap(item as Map)).toList();
    } catch (e) {
      debugPrint('Error getting history: $e');
      return [];
    }
  }

  Future<bool> deleteHistoryItem(int id) async {
    try {
      return await _platform.invokeMethod<bool>('deleteHistoryItem', {'id': id}) ?? false;
    } catch (e) {
      debugPrint('Error deleting history item: $e');
      return false;
    }
  }

  Future<bool> clearHistory() async {
    try {
      return await _platform.invokeMethod<bool>('clearHistory') ?? false;
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return false;
    }
  }

  Future<List<HistoryItem>> searchHistory(String query) async {
    try {
      final result = await _platform.invokeMethod<List<dynamic>>(
        'searchHistory',
        {'query': query},
      );
      if (result == null) return [];
      return result.map((item) => HistoryItem.fromMap(item as Map)).toList();
    } catch (e) {
      debugPrint('Error searching history: $e');
      return [];
    }
  }
}
