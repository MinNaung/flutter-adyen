import 'dart:io';

// User Data
const String amount_currency = "EUR";
const String amount_value = "1337";
const String countryCode = "NL";
const String shopperLocale = "en_US";
const String telephoneNumber = "0612345678";
const String dateOfBirth = "1983-12-31";
const String shopperEmail = "shopper@myflutterdemo.io";
var shopperName = const {"firstName": "Jan", "lastName": "Jansen", "gender": "MALE"};
var address = const {
    "country": "NL",
    "city": "Capital",
    "houseNumberOrName": "1",
    "postalCode": "1012 DJ",
    "stateOrProvince": "DC",
    "street": "Main St"
  };

var paymentMethodsRequestJson = {
  "merchantAccount": MERCHANT_ACCOUNT,
  "shopperReference": SHOPPER_REFERENCE,
  "amount": {"currency": amount_currency, "value": amount_value},
  "countryCode": countryCode,
  "shopperLocale": shopperLocale,
  "channel": Platform.isAndroid ? "android" : "ios",
  "telephoneNumber": telephoneNumber,
  "dateOfBirth": dateOfBirth,
  "shopperEmail": shopperEmail,
  "shopperName": shopperName,
  "billingAddress": address,
  "deliveryAddress": address
};

// Adyen
// replace the values in <PLACEHOLDER> with the configuration to connect to the Server.
const String API_KEY_HEADER_NAME = "x-API-key";
const String CHECKOUT_API_KEY = "<CHECKOUT_API_KEY>";
const String MERCHANT_ACCOUNT = "<MERCHANT_ACCOUNT>";
const String MERCHANT_SERVER_URL = "<YOUR_SERVER_URL>"; //"https://checkout-test.adyen.com/v52/";
const String PUBLIC_KEY = "<PUBLIC_KEY>";
const String SHOPPER_REFERENCE = "<SHOPPER_REFERENCE>";
