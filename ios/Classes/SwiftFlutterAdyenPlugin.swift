import Flutter
import UIKit
import Adyen
import Adyen3DS2
import Foundation

public class SwiftFlutterAdyenPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_adyen", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterAdyenPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    var dropInComponent: DropInComponent?
    
    var merchantAccount: String = ""
    var pubKey: String = ""
    var amount: String = ""
    var currency: String = ""
    var countryCode: String = ""
    var shopperLocaleString: String = ""
    var returnUrl: String?
    var shopperReference: String = ""
    var reference: String = ""
    var allow3DS2: Bool = false
    var executeThreeD: Bool = false
    var testEnvironment: Bool = false
    var shopperInteraction:String = ""
    var storePaymentMethod: Bool = false
    var recurringProcessingModel:String = ""
    var mResult: FlutterResult?
    var topController: UIViewController?
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "choosePaymentMethod":
            choosePaymentMethod(call, result: result)
        case "onResponse":
            onResponse(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
        
    private func choosePaymentMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        mResult = result
        
        let arguments = call.arguments as? [String: Any]
        let paymentMethodsPayload = arguments?["paymentMethodsPayload"] as? String
        
        merchantAccount = arguments?["merchantAccount"] as! String
        pubKey = arguments?["pubKey"] as! String
        amount = arguments?["amount"] as! String
        currency = arguments?["currency"] as! String

        if  let country = arguments?["countryCode"],
            let cc = country as? String {
            countryCode = cc
        }
        if  let locale = arguments?["shopperLocale"],
            let loc = locale as? String {
            shopperLocaleString = loc
        }
        guard let return_url = arguments?["iosReturnUrl"],
        let url = return_url as? String else { return }
        returnUrl = url
        
        shopperReference = arguments?["shopperReference"] as! String
        
        if  let shopper_interaction = arguments?["shopperInteraction"],
            let interaction = shopper_interaction as? String {
            shopperInteraction = interaction
        }
        if  let recurringModel = arguments?["recurringProcessingModel"],
            let recurring = recurringModel as? String {
            recurringProcessingModel = recurring
        }
        if  let storePayment = arguments?["storePaymentMethod"],
            let store = storePayment as? Bool {
            storePaymentMethod = store
        }
        reference = arguments?["reference"] as! String
        allow3DS2 = arguments?["allow3DS2"] as! Bool
        executeThreeD = arguments?["executeThreeD"] as! Bool
        testEnvironment = arguments?["testEnvironment"] as? Bool ?? false
        
        guard let paymentData = paymentMethodsPayload?.data(using: .utf8),
            let paymentMethods = try? JSONDecoder().decode(PaymentMethods.self, from: paymentData) else {
                return
        }
        
        let configuration = DropInComponent.PaymentMethodsConfiguration()
        configuration.card.publicKey = pubKey
        
        dropInComponent = DropInComponent(paymentMethods: paymentMethods, paymentMethodsConfiguration: configuration)
        dropInComponent?.delegate = self
        dropInComponent?.payment = Payment(amount: Payment.Amount(value: Int(amount)!, currencyCode: currency))
        dropInComponent?.environment = testEnvironment ? .test : .live
        
        //        topController = UIApplication.shared.keyWindow?.rootViewController
        //        while let presentedViewController = topController?.presentedViewController {
        //            topController = presentedViewController
        //        }
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            self.topController = topController
            while let presentedViewController = topController.presentedViewController{
                topController = presentedViewController
            }
            
            if #available(iOS 13.0, *) {
                dropInComponent!.viewController.overrideUserInterfaceStyle = .light
            }
            
            topController.present(dropInComponent!.viewController, animated: true)
        }
    }
    
    private func onResponse(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        mResult = result
        
        let arguments = call.arguments as? [String: Any]
        let payload = arguments?["payload"] as! String
        let data = payload.data(using: .utf8)!

        finish(data: data, component: dropInComponent!)
    }
}

//MARK: - DropInComponentDelegate
extension SwiftFlutterAdyenPlugin: DropInComponentDelegate {
    // back from the ui, for payment call
    public func didSubmit(_ data: PaymentComponentData, from component: DropInComponent) {
        //guard let url = URL(string: urlPayments) else { return }
        
        let paymentMethod = try? data.paymentMethod.encodable.toDictionary()

        // prepare json data
        let json: [String: Any] = [
            "paymentMethod": paymentMethod!,
           "amount": [
            "currency": currency,
            "value": amount
           ],
           "countryCode":countryCode,
           "shopperLocale":shopperLocaleString,
           "channel": "iOS",
           "merchantAccount": merchantAccount,
           "reference": reference,
           "returnUrl": returnUrl!,
           "shopperReference": shopperReference,
           "storePaymentMethod": data.storePaymentMethod,
           "shopperInteraction": shopperInteraction,
           "recurringProcessingModel": recurringProcessingModel,
           "additionalData": [
                "allow3DS2": allow3DS2,
                "executeThreeD": executeThreeD
           ]
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
        
        let convertedString = String(data: jsonData!, encoding: String.Encoding.utf8)
        print(convertedString ?? "defaultvalue")
        self.mResult!(convertedString)

        return
    }
    
    // called when details are needed (3DSecure?)
    public func didProvide(_ data: ActionComponentData, from component: DropInComponent) {
        let details = try? data.details.encodable.toDictionary()
        let json: [String: Any] = ["details": details!,"paymentData": data.paymentData]
        let jsonString:String = jsonToString(json: json as AnyObject)!

        let controller : FlutterViewController = self.topController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "flutter_adyen", binaryMessenger: controller.binaryMessenger)
        channel.invokeMethod("detailsRequest", arguments: jsonString) { (result:Any?) in
            if(result != nil){
                do{
                    let dict = self.stringToDictionary(text: result as! String)
                    let data =  try JSONSerialization.data(withJSONObject: dict!, options: JSONSerialization.WritingOptions.prettyPrinted)
                    self.finish(data: data, component: component)
                } catch let jsonError {
                    print(jsonError)
                }
            }
        }
    }
    
    public func didFail(with error: Error, from component: DropInComponent) {
       self.mResult!("CANCELLED")
       dismissAdyenController()
    }
    
    fileprivate func dismissAdyenController() {
        DispatchQueue.global(qos: .background).async {
            // Background Thread
            DispatchQueue.main.async {
                self.topController?.dismiss(animated: false, completion: nil)
            }
        }
    }
    
    private func finish(data: Data, component: DropInComponent) {
        let paymentResponseJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String,Any>
        if (paymentResponseJson != nil) {
            let action = paymentResponseJson!.keys.contains("action") ? paymentResponseJson?["action"] : nil
            if(action != nil) {
                let act = try? JSONDecoder().decode(Action.self, from: JSONSerialization.data(withJSONObject: action!))
                if(act != nil){
                    component.handle(act!)
                }
            } else {
                let resultCode = paymentResponseJson?["resultCode"] as? String
                let success = resultCode == "Authorised" || resultCode == "Received" || resultCode == "Pending"
                component.stopLoading()
                if (success) {
                    self.mResult!("SUCCESS")
                    dismissAdyenController()
                } else {
                    let err = FlutterError(code: resultCode ?? "", message: "Failed with result code \(String(describing: resultCode ?? "-none-"))", details: nil)
                    self.mResult!(err)
                    dismissAdyenController()
                }
            }
        }
    }

}

extension UIViewController: PaymentComponentDelegate {
    
    public func didSubmit(_ data: PaymentComponentData, from component: PaymentComponent) {
        //performPayment(with: public  }
    }
    
    public func didFail(with error: Error, from component: PaymentComponent) {
        //performPayment(with: public  }
    }
    
}

extension UIViewController: ActionComponentDelegate {
    
    public func didFail(with error: Error, from component: ActionComponent) {
        //performPayment(with: public  }
    }
    
    public func didProvide(_ data: ActionComponentData, from component: ActionComponent) {
        //performPayment(with: public  }
    }
    
}

//MARK: - Json Utils
extension SwiftFlutterAdyenPlugin {
    func jsonToString(json: AnyObject) -> String?{
        do {
            let data1 =  try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
            let convertedString = String(data: data1, encoding: String.Encoding.utf8)
            print(convertedString ?? "defaultvalue")
            return convertedString
        } catch let myJSONError {
            print(myJSONError)
        }
        return nil
    }
    
    func stringToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}

//MARK: - Extension
extension Encodable {
    
    /// Converting object to postable dictionary
    func toDictionary(_ encoder: JSONEncoder = JSONEncoder()) throws -> [String: String] {
        let data = try encoder.encode(self)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: String] else {
            let context = DecodingError.Context(codingPath: [], debugDescription: "Deserialized object is not a dictionary")
            throw DecodingError.typeMismatch(type(of: object), context)
        }
        return json
    }
}
