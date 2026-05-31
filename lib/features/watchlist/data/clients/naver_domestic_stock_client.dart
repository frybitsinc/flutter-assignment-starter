// ignore_for_file: unused_element, unused_field

import 'dart:convert';

import 'package:dio/dio.dart';

import '../dtos/naver_stock_dtos.dart';

abstract interface class NaverStockDataClient {
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query);

  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  );

  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol);

  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  });
}

class NaverDomesticStockClient implements NaverStockDataClient {
  const NaverDomesticStockClient(this._dio);

  final Dio _dio;

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://m.stock.naver.com/',
    'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/123.0.0.0 Safari/537.36',
  };

  static Map<String, dynamic> _decodeJsonObjectBody(
    Object? data,
    String contextLabel,
  ) {
    if (data == null) {
      throw FormatException('$contextLabel response body is empty');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel response body has unsupported shape');
  }

  static Map<String, dynamic> _asStringKeyedMap(
    Object? value,
    String contextLabel,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel is not a JSON object');
  }

  @override
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query) async {
    // Call https://ac.stock.naver.com/ac with Dio.
    // Send q=<query> and target=stock,ipo,index,marketindicator.
    // Use _defaultHeaders and ResponseType.plain because the response body may arrive as a String instead of a decoded JSON map.
    final response = await _dio.get(
      'https://ac.stock.naver.com/ac',
      queryParameters: {
        'q': query,
        'target': 'stock,ipo,index,marketindicator',
      },
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );
    // Decode the response with _decodeJsonObjectBody.
    // Read the "items" array and map each entry with NaverAutocompleteItemDto.fromJson.
    return _decodeJsonObjectBody(
      response.data,
      'searchStocks',
    )['items'].map((e) => NaverAutocompleteItemDto.fromJson(e)).toList();
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // Deduplicate the incoming symbols.
    // Return an empty map when there is nothing to request.
    final uniqueSymbols = symbols.toSet();
    if (uniqueSymbols.isEmpty) {
      return {};
    }
    // Build query=SERVICE_ITEM:005930,000660 style payload.
    final query = 'SERVICE_ITEM:${uniqueSymbols.join(',')}';
    // Call https://polling.finance.naver.com/api/realtime.
    final response = await _dio.get(
      'https://polling.finance.naver.com/api/realtime',
      queryParameters: {'query': query},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );
    // Decode the JSON body,
    final payload = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');
    // then traverse result -> areas -> datas.
    final areas = payload['result']['areas'] as List<dynamic>;
    final quotes = [
      for (final area in areas)
        for (final data in area['datas'] as List<dynamic>)
          // Convert each realtime row with NaverRealtimeQuoteDto.fromJson.
          NaverRealtimeQuoteDto.fromJson(data as Map<String, dynamic>),
    ];
    // Return a map keyed by the six-digit domestic symbol.
    return {for (final quote in quotes) quote.symbol: quote};
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    // Call https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}
    final response = await _dio.get(
      'https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/$symbol',
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );
    // Decode the JSON object with _decodeJsonObjectBody.
    // Convert the payload with NaverChartMetadataDto.fromJson.
    final payload = _decodeJsonObjectBody(response.data, 'fetchChartMetadata');
    return NaverChartMetadataDto.fromJson(payload);
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    // Hint:
    // - The rendered table order is close, change, open, high, low, volume.
    // - You can keep using NaverHistoricalPriceDto.fromJson to build rows.

    // Validate that page >= 1.
    if (page < 1) {
      throw ArgumentError('page must be greater than 0');
    }
    // Request https://finance.naver.com/item/sise_day.naver with code=<symbol> and page=<page>.
    final response = await _dio.get(
      'https://finance.naver.com/item/sise_day.naver',
      queryParameters: {'code': symbol, 'page': page},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.bytes, // Use ResponseType.bytes
      ),
    );
    // and decode the HTML with latin1.
    final html = latin1.decode(response.data);

    // Parse one page of historical rows from the HTML table.
    // For each row, extract: localDate (yyyyMMdd), closePrice, openPrice, highPrice, lowPrice, accumulatedTradingVolume.
    final rowPattern = RegExp(
      r'<tr onMouseOver="mouseOver\(this\)"[^>]*>([\s\S]*?)</tr>',
    );
    final datePattern = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})');
    final numPattern = RegExp(
      r'<td class="num">[\s\S]*?<span class="tah p11[^"]*">\s*([\d,]+)\s*</span>',
    );
    final priceInfos = <NaverHistoricalPriceDto>[];
    for (final row in rowPattern.allMatches(html)) {
      final rowHtml = row.group(1)!;
      final dateMatch = datePattern.firstMatch(rowHtml);
      if (dateMatch == null) continue;
      final nums = numPattern
          .allMatches(rowHtml)
          .map((m) => m.group(1)!)
          .toList();
      if (nums.length < 6) continue;
      final localDate =
          '${dateMatch.group(1)}${dateMatch.group(2)}${dateMatch.group(3)}';
      priceInfos.add(
        NaverHistoricalPriceDto.fromJson({
          'localDate': localDate,
          'closePrice': _parseDouble(nums[0]),
          'openPrice': _parseDouble(nums[2]),
          'highPrice': _parseDouble(nums[3]),
          'lowPrice': _parseDouble(nums[4]),
          'accumulatedTradingVolume': _parseInt(nums[5]),
        }),
      );
    }
    // Also extract lastPage from the pagination area.
    final lastPageMatch = RegExp(
      r'class="pgRR"[\s\S]*?page=(\d+)',
    ).firstMatch(html);
    final lastPage = lastPageMatch != null
        ? int.parse(lastPageMatch.group(1)!)
        : 1;
    return NaverDailyHistoryPageDto(
      symbol: symbol,
      page: page,
      lastPage: lastPage,
      priceInfos: priceInfos,
    );
  }
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
