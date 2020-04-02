import "dart:convert";

import "package:dio/dio.dart";
import "package:dio_flutter_transformer/dio_flutter_transformer.dart";
import "package:flutter_rave/flutter_rave.dart" show CreditCardInfo;
import "package:tripledes/tripledes.dart";

class RaveApiService {
  static RaveApiService get instance => RaveApiService();

  final _sandboxProductionUrl = "https://ravesandboxapi.flutterwave.com";
  final _liveProductionUrl = "https://api.ravepay.co";

  final _validationEndpoint = "/flwv3-pug/getpaidx/api/validatecharge";
  final _chargeEndpoint = "/flwv3-pug/getpaidx/api/charge";

  Dio _dio;
  Dio _productionDio;

  RaveApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _sandboxProductionUrl,
        connectTimeout: 30000,
        receiveTimeout: 30000,
        responseType: ResponseType.json,
        headers: {
          "Accept": "application/json",
        },
      ),
    );

    _productionDio = Dio(
      BaseOptions(
        baseUrl: _liveProductionUrl,
        connectTimeout: 30000,
        receiveTimeout: 30000,
        responseType: ResponseType.json,
        headers: {
          "Accept": "application/json",
        },
      ),
    );

    _dio.transformer = FlutterTransformer();
    _productionDio.transformer = FlutterTransformer();

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options) {
          print(options.uri.toString());
          print(options.data.toString());
          return options;
        },
        onResponse: (Response response) {
          print(response.headers.toString());
          print(response.data.toString());
          return response;
        },
        onError: (DioError e) {
          print(e.type.toString());
          print(e.response.headers.toString());
          print(e.response.data.toString());
          return e; //continue
        },
      ),
    );

    _productionDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options) {
          print(options.uri.toString());
          print(options.data.toString());
          return options;
        },
        onResponse: (Response response) {
          print(response.headers.toString());
          print(response.data.toString());
          return response;
        },
        onError: (DioError e) {
          print(e.type.toString());
          print(e.response.headers.toString());
          print(e.response.data.toString());
          return e; //continue
        },
      ),
    );
  }

  Future<Map<String, dynamic>> startChargeCard(
    CreditCardInfo card,
    String ravePublicKey,
    String raveEncryptionKey, {
    bool isProduction = true,
    String email,
    String firstName,
    String lastName,
    String phoneNumber,
    String transactionReference,
    double amount,
    String suggestedAuth = "pin",
    String suggestedAuthValue,
    Map<String, String> billingAddressInfo,
    List<Map<String, dynamic>> subaccounts,
    String redirectUrl = "http://localhost:8184",
  }) async {
    final payload = {
      "PBFPubKey": ravePublicKey,
      "cardno": card.cardNumber,
      "currency": "KES",
      "country": "KE",
      "cvv": card.cvv,
      "amount": amount,
      "expiryyear": card.expirationYear,
      "expirymonth": card.expirationMonth,
      "suggested_auth": suggestedAuth,
      "email": email,
      "firstname": firstName,
      "lastname": lastName,
      "phonenumber": phoneNumber,
      "redirect_url": redirectUrl,
      "txRef": transactionReference,
    };

    print(payload);
    print("isProduction $isProduction");

    if (suggestedAuthValue != null) {
      payload[suggestedAuth.toLowerCase()] = suggestedAuthValue;
    }
    if (subaccounts != null) {
      payload["subaccounts"] = subaccounts;
    }

    if (billingAddressInfo != null) {
      billingAddressInfo.forEach((key, value) {
        payload[key] = value;
      });
    }

    return await _chargeCard(
      ravePublicKey,
      raveEncryptionKey,
      payload,
      isProduction,
    );
  }

  _chargeCard(String ravePublicKey, String raveEncryptionKey,
      Map<String, dynamic> chargeDataGlobal,
      [bool isProduction = true]) async {
    final encoded = json.encode(chargeDataGlobal);
    final encryped = encrypt(raveEncryptionKey, encoded);
    final newData = {
      "PBFPubKey": ravePublicKey,
      "client": encryped,
      "alg": "3DES-24"
    };

    var response;

    if (isProduction) {
      response = await _productionDio.post(
        _chargeEndpoint,
        data: newData,
      );
    } else {
      response = await _dio.post(
        _chargeEndpoint,
        data: newData,
      );
    }

    return response.data;
  }

  encrypt(key, text) {
    var blockCipher = BlockCipher(TripleDESEngine(), key);
    var i = blockCipher.encodeB64(text);
    return i;
  }

  validateTransaction(String txRef, String otp, String publicKey,
      [bool isProduction = true]) async {
    final newData = {
      "PBFPubKey": publicKey,
      "transaction_reference": txRef,
      "otp": otp,
    };

    final dio = isProduction ? _productionDio : _dio;

    final response = await dio.post(
      _validationEndpoint,
      data: newData,
    );

    return response.data;
  }

  fetchTransactionDetails(txRef, String publicKey) async {
    final newData = {
      "PBFPubKey": publicKey,
      "transaction_reference": txRef,
    };
    final response = await _dio.post(
      _validationEndpoint,
      data: newData,
    );

    return response.data;
  }
}
