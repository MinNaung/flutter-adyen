import 'package:http/http.dart' as http;
import 'mock_data.dart';

Future<http.Response> getPaymentMethods(String paymentsMethodRequest) {
  return http.post(
    MERCHANT_SERVER_URL + "paymentMethods",
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      API_KEY_HEADER_NAME: CHECKOUT_API_KEY,
    },
    body: paymentsMethodRequest,
  );
}

Future<http.Response> paymentsRequest(String paymentsRequestBodyJson) {
  return http.post(
    MERCHANT_SERVER_URL + "payments",
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      API_KEY_HEADER_NAME: CHECKOUT_API_KEY,
    },
    body: paymentsRequestBodyJson,
  );
}

Future<http.Response> detailsRequest(String requestBody) {
  return http.post(
    MERCHANT_SERVER_URL + "payments/details",
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      API_KEY_HEADER_NAME: CHECKOUT_API_KEY,
    },
    body: requestBody,
  );
}
