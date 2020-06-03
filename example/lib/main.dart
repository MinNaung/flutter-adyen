import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adyen/flutter_adyen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'api.dart' as api;
import 'mock_data.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _debugInfo = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  String dropInResponse;

  Future<void> initPlatformState() async {
    if (!mounted) return;

    FlutterAdyen.registerCallBackHandler();

    //Step (4) (Optional) POST /payments/details request
    FlutterAdyen.registerPaymentDetailsCallBack((requestBody) async {
      var response = await api.detailsRequest(requestBody);
      return jsonDecode(response.body);
    });

    setState(() {
      _debugInfo = dropInResponse;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        floatingActionButton: SpeedDial(
          // both default to 16
          marginRight: 18,
          marginBottom: 20,
          animatedIcon: AnimatedIcons.menu_close,
          animatedIconTheme: IconThemeData(size: 22.0),
          closeManually: false,
          curve: Curves.bounceIn,
          overlayColor: Colors.black,
          overlayOpacity: 0.5,
          //onOpen: () => print('OPENING DIAL'),
          //onClose: () => print('DIAL CLOSED'),
          tooltip: 'Speed Dial',
          heroTag: 'speed-dial-hero-tag',
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 8.0,
          shape: CircleBorder(),
          children: [
            SpeedDialChild(
              child: Icon(Icons.delete),
              backgroundColor: Colors.red,
              label: 'clear',
              labelStyle: TextStyle(fontSize: 18.0),
              onTap: () => FlutterAdyen.clearStorage(),
            ),
            SpeedDialChild(
                child: Icon(Icons.directions_run),
                backgroundColor: Colors.blue,
                label: 'try flow',
                labelStyle: TextStyle(fontSize: 18.0),
                onTap: tryFlow),
          ],
        ),
        appBar: AppBar(
          title: const Text('Flutter Adyen'),
        ),
        body: Center(
          child:
              SingleChildScrollView(child: Text('Result : $_debugInfo\n')),
        ),
      ),
    );
  }

  void tryFlow() async {
    var scheme = 'myflutteradyen://';//URL to where the shopper should be taken back to after a redirection. This URL can have a maximum of 1024 characters. For more information on setting a custom URL scheme for your app, read the Apple Developer documentation. https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app
    var ref = 'flutter-test_${DateTime.now().millisecondsSinceEpoch}';

    // Step (1) POST /paymentMethods request
    var paymentMethodResponse =
        await api.getPaymentMethods(jsonEncode(paymentMethodsRequestJson));
    var paymentMethodsPayload = paymentMethodResponse.body;

    // Step (2) Start Drop-in
    try {
      dropInResponse = await FlutterAdyen.choosePaymentMethod(
          paymentMethodsPayload: paymentMethodsPayload,
          merchantAccount: MERCHANT_ACCOUNT,
          publicKey: PUBLIC_KEY,
          amount: amount_value,
          currency: amount_currency,
          countryCode: countryCode,
          shopperLocale: shopperLocale,
          iosReturnUrl: scheme,
          reference: ref,
          shopperReference: SHOPPER_REFERENCE,          
          allow3DS2: true,
          executeThreeD: true,
          testEnvironment: true,
          storePaymentMethod: true,
          shopperInteraction: ShopperInteraction.Ecommerce,
          recurringProcessingModel: RecurringProcessingModels.CardOnFile
          );
    } on PlatformException catch (e) {
      dropInResponse = 'PlatformException. ${e.message}';
    } on Exception {
      dropInResponse = 'Exception.';
    }

    setState(() {
      _debugInfo = dropInResponse;
    });

    // Step (3) POST /payments request
    var paymentsResponse = await api.paymentsRequest(dropInResponse);
    var res;
    try {
      res = await FlutterAdyen.sendResponse(jsonDecode(paymentsResponse.body)
          // {
          //   "pspReference":"883577097894825J",
          //   "resultCode":"Refused",
          //   "merchantReference":"e13e71f7-c9b7-406a-a800-18fce8204173"
          // }

          /*
        {
          "resultCode": "RedirectShopper",
          "action": {
            "data": {
              "MD": "OEVudmZVMUlkWjd0MDNwUWs2bmhSdz09...",
              "PaReq": "eNpVUttygjAQ/RXbDyAXBYRZ00HpTH3wUosPfe...",
              "TermUrl": "adyencheckout://your.package.name"
            },
            "method": "POST",
            "paymentData": "Ab02b4c0!BQABAgA4e3wGkhVah4CJL19qdegdmm9E...",
            "paymentMethodType": "scheme",
            "type": "redirect",
            "url": "https://test.adyen.com/hpp/3d/validate.shtml"
          },
          "details": [
            {"key": "MD", "type": "text"},
            {"key": "PaRes", "type": "text"}
          ],
        }*/
          );
    } on PlatformException catch (e) {
      res = 'PlatformException. ${e.message}';
    } on Exception {
      res = 'Exception.';
    }

    setState(() {
      _debugInfo = res + "||||" + dropInResponse;
    });
  }
}
