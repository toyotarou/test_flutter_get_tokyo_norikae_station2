import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';

///////////////////////////////////////////////////////////////////
final Provider<HttpClient> httpClientProvider = Provider<HttpClient>((ProviderRef<HttpClient> ref) => HttpClient());

////////////////////
class HttpClient {
  HttpClient() {
    _client = Client();
  }

  late Client _client;

  //------------------------------------------
  /// GET
  //------------------------------------------
  Future<dynamic> getByPath({required String path, Map<String, dynamic>? queryParameters}) async {
    final Response response = await _client.get(Uri.parse(path), headers: await _headers);

    final String bodyString = utf8.decode(response.bodyBytes);

    try {
      if (bodyString.isEmpty) {
        throw Exception();
      }
      return jsonDecode(bodyString);
    } on Exception catch (_) {
      throw Exception('json parse error');
    }
  }

  //------------------------------------------
  /// ★ POST
  //------------------------------------------
  Future<dynamic> postByPath({required String path, Map<String, dynamic>? body}) async {
    final String bodyString = jsonEncode(body ?? <String, dynamic>{});

    final Response response = await _client.post(Uri.parse(path), headers: await _headers, body: bodyString);

    final String result = utf8.decode(response.bodyBytes);

    try {
      if (result.isEmpty) {
        throw Exception();
      }
      return jsonDecode(result);
    } on Exception catch (_) {
      throw Exception('json parse error');
    }
  }

  //------------------------------------------
  /// Headers
  //------------------------------------------
  Future<Map<String, String>> get _headers async {
    return <String, String>{'content-type': 'application/json'};
  }
}
