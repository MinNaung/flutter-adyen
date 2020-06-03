package app.petleo.flutter_adyen

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import com.adyen.checkout.base.model.PaymentMethodsApiResponse
import com.adyen.checkout.base.model.payments.Amount
import com.adyen.checkout.base.model.payments.request.PaymentComponentData
import com.adyen.checkout.bcmc.BcmcConfiguration
import com.adyen.checkout.card.CardConfiguration
import com.adyen.checkout.core.api.Environment
import com.adyen.checkout.core.exception.CheckoutException
import com.adyen.checkout.core.util.LocaleUtil
import com.adyen.checkout.dropin.DropIn
import com.adyen.checkout.dropin.DropInConfiguration
import com.adyen.checkout.dropin.service.CallResult
import com.adyen.checkout.dropin.service.DropInService
import com.adyen.checkout.googlepay.GooglePayConfiguration
import com.adyen.checkout.redirect.RedirectComponent
import com.google.gson.Gson
import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.json.JSONObject
import java.util.*

var result: Result? = null
var mActivity: Activity? = null

const val sharedPrefsKey: String = "ADYEN"

const val enableLogging = false;

const val CHANNEL = "flutter_adyen"

class FlutterAdyenPlugin(private val activity: Activity) : MethodCallHandler {

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), CHANNEL)
            mActivity = registrar.activity()
            channel.setMethodCallHandler(FlutterAdyenPlugin(registrar.activity()))
        }
    }

    override fun onMethodCall(call: MethodCall, res: Result) {
        when (call.method) {
            "choosePaymentMethod" -> choosePaymentMethod(call, res)
            "onResponse" -> onResponse(call, res)
            "clearStorage" -> onClearStorageRequested(call, res)
            else -> res.notImplemented()
        }
    }

    private fun onClearStorageRequested(call: MethodCall, res: Result) {
        val sharedPref = activity.getSharedPreferences(sharedPrefsKey, Context.MODE_PRIVATE)
        sharedPref.edit().clear().apply()
        activity?.runOnUiThread { res?.success("SUCCESS") }
    }

    private fun choosePaymentMethod(call: MethodCall, res: Result) {
        log("choosePaymentMethod")
        val paymentMethodsPayload = call.argument<String>("paymentMethodsPayload")

        val merchantAccount = call.argument<String>("merchantAccount")
        val pubKey = call.argument<String>("pubKey")
        val amountValue = call.argument<String>("amount")
        val currency = call.argument<String>("currency")
        val countryCode = call.argument<String>("countryCode")
        val shopperLocaleString = call.argument<String>("shopperLocale")
        val reference = call.argument<String>("reference")
        val shopperReference = call.argument<String>("shopperReference")
        val storePaymentMethod = call.argument<Boolean>("storePaymentMethod") ?: false
        val shopperInteraction = call.argument<String>("shopperInteraction")
        val recurringProcessingModel = call.argument<String>("recurringProcessingModel")
        val allow3DS2 = call.argument<Boolean>("allow3DS2") ?: false
        val executeThreeD = call.argument<Boolean>("executeThreeD") ?: false
        val testEnvironment = call.argument<Boolean>("testEnvironment") ?: false

        val shopperLocale = LocaleUtil.fromLanguageTag(shopperLocaleString ?: "en_US")

        try {
            val jsonObject = JSONObject(paymentMethodsPayload ?: "")
            val paymentMethodsPayloadString = PaymentMethodsApiResponse.SERIALIZER.deserialize(jsonObject)
            log("paymentMethodsPayloadString $paymentMethodsPayloadString")
            val googlePayConfig = GooglePayConfiguration.Builder(activity, merchantAccount
                    ?: "").build()
            val cardConfiguration = CardConfiguration.Builder(activity, pubKey
                    ?: "").setShopperReference(shopperReference!!)
                    .setShopperLocale(shopperLocale).build()
            val bcmcConfiguration = BcmcConfiguration.Builder(activity, pubKey ?: "").build()

            val resultIntent = Intent(activity, activity::class.java)
            resultIntent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP

            //TODO : don't store all this, dart version already has all of them
            val sharedPref = activity.getSharedPreferences(sharedPrefsKey, Context.MODE_PRIVATE)
            with(sharedPref.edit()) {
                putString("merchantAccount", merchantAccount)
                putString("amount", amountValue)
                putString("currency", currency)
                putString("countryCode", countryCode)
                putString("shopperLocale", shopperLocaleString)
                putString("channel", "Android")
                putString("reference", reference)
                putString("shopperReference", shopperReference)
                putBoolean("storePaymentMethod", storePaymentMethod)
                putString("shopperInteraction", shopperInteraction)
                putString("recurringProcessingModel", recurringProcessingModel)
                putBoolean("allow3DS2", allow3DS2)
                putBoolean("executeThreeD", executeThreeD)
                commit()
            }

            val dropInConfig = DropInConfiguration.Builder(activity, resultIntent, MyDropInService::class.java)
                    .setShopperLocale(shopperLocale)
                    .addCardConfiguration(cardConfiguration)
                    .addGooglePayConfiguration(googlePayConfig)
                    .addBcmcConfiguration(bcmcConfiguration)

            if (testEnvironment)
                dropInConfig.setEnvironment(Environment.TEST)
            else
                dropInConfig.setEnvironment(Environment.EUROPE)

            try {
                dropInConfig.setAmount(getAmount(amountValue!!, currency!!))
            } catch (e: CheckoutException) {
                Log.e(sharedPrefsKey, "Amount $amountValue not valid", e)
            }

            val dropInConfiguration = dropInConfig.build()

            log("opening dropin")

            DropIn.startPayment(activity, paymentMethodsPayloadString, dropInConfiguration)

            result = res
            mActivity = activity
        } catch (e: Throwable) {
            log("dropin startpayment error")
            res.error("Error", "Adyen:: Failed with this error: ${e.printStackTrace()}", null)
        }
    }

    private fun onResponse(call: MethodCall, res: Result) {
        result = res

        log("onresponse")

        val payload = call.argument<String>("payload")
        val data = JSONObject(payload!!)

        log("dropin finish")

        MyDropInService.instance.finish(data)

        log("dropin finished")
    }

}


class MyDropInService : DropInService() {

    companion object {
        lateinit var instance: MyDropInService
        //private val TAG = LogUtil.getTag()
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun makePaymentsCall(paymentComponentData: JSONObject): CallResult {
        log("make payments call")

        val sharedPref = getSharedPreferences(sharedPrefsKey, Context.MODE_PRIVATE)

        val merchantAccount = sharedPref.getString("merchantAccount", "UNDEFINED_STR")
        val amount = sharedPref.getString("amount", "UNDEFINED_STR")
        val currency = sharedPref.getString("currency", "UNDEFINED_STR")
        val countryCode = sharedPref.getString("countryCode", "UNDEFINED_STR")
        val reference = sharedPref.getString("reference", "UNDEFINED_STR")
        val shopperReference = sharedPref.getString("shopperReference", "UNDEFINED_STR")
        val shopperInteraction = sharedPref.getString("shopperInteraction", "UNDEFINED_STR")
        val storePaymentMethod = sharedPref.getBoolean("storePaymentMethod", false)
        val recurringProcessingModel = sharedPref.getString("recurringProcessingModel", "UNDEFINED_STR")
        val allow3DS2 = sharedPref.getBoolean("allow3DS2", false)
        val executeThreeD = sharedPref.getBoolean("executeThreeD", false)

        val serializedPaymentComponentData = PaymentComponentData.SERIALIZER.deserialize(paymentComponentData)

        if (serializedPaymentComponentData.paymentMethod == null)
            return CallResult(CallResult.ResultType.ERROR, "Empty payment data")

        log("before create payment request")
        val paymentRequest = createPaymentRequest(
                paymentComponentData,
                reference ?: "",
                shopperReference ?: "",
                getAmount(amount?:"", currency?:""),
                countryCode ?: "",
                merchantAccount?:"",
                RedirectComponent.getReturnUrl(applicationContext),
                AdditionalData(
                        allow3DS2 = allow3DS2.toString(),
                        executeThreeD = executeThreeD.toString()
                )
        )

        val paymentsRequestBodyJson = paymentRequest.toString()

        log("payment request : ${paymentsRequestBodyJson}")

        val resp = paymentsRequestBodyJson

        mActivity?.runOnUiThread { result?.success(resp) }

        return CallResult(CallResult.ResultType.WAIT, resp, true)
    }

    override fun makeDetailsCall(actionComponentData: JSONObject): CallResult {
        val callback = object : MethodChannel.Result {
            override fun notImplemented() {
                throw Exception("'payments/details' request is not implemented!")
            }
            override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
                throw Exception("Error calling 'payments/details' request. error code : $errorCode, message : $errorMessage")
            }
            override fun success(result: Any?) {
                finish(JSONObject(result as String))
            }
        }
        val channel = MethodChannel((mActivity as FlutterActivity).flutterView, CHANNEL)
        mActivity?.runOnUiThread { channel.invokeMethod("detailsRequest", actionComponentData.toString(), callback) }
        return CallResult(CallResult.ResultType.WAIT, "")
    }

    //TODO move this logic to the dart side, it's the same on ios
    fun finish(paymentsResponse: JSONObject): CallResult {
        if (paymentsResponse.has("action")) {
            log("finish : action")
            val action = paymentsResponse.getString("action").toString()
            asyncCallback(CallResult(CallResult.ResultType.ACTION, /*Action.SERIALIZER.serialize(*/action/*).toString()*/))
            return CallResult(CallResult.ResultType.ACTION, /*Action.SERIALIZER.serialize(*/action/*).toString()*/)
        } else {
            log("finish : no action")
            if (paymentsResponse.has("resultCode")) {
                val code = paymentsResponse.getString("resultCode")
                log("finish : code:$code")
                if (code == "Authorised" ||
                        code == "Received" ||
                        code == "Pending"
                ) {
                    log("finish : result code ${code}")
                    mActivity?.runOnUiThread { result?.success("SUCCESS") }
                    asyncCallback(CallResult(CallResult.ResultType.FINISHED, code))
                    return CallResult(CallResult.ResultType.FINISHED, code)
                } else {
                    log("finish : error")
                    mActivity?.runOnUiThread { result?.error(code, "Payment not Authorised", null) }
                    asyncCallback(CallResult(CallResult.ResultType.FINISHED, code ?: "EMPTY"))
                    return CallResult(CallResult.ResultType.FINISHED, code ?: "EMPTY")
                }
            } else if (paymentsResponse.has("errorCode")) {
                val code = paymentsResponse.getString("errorCode")
                log("finish with error code:$code")
                mActivity?.runOnUiThread { result?.error(code, "Payment not Authorised", null) }
                asyncCallback(CallResult(CallResult.ResultType.FINISHED, code ?: "EMPTY"))
                return CallResult(CallResult.ResultType.FINISHED, code ?: "EMPTY")
            } else {
                mActivity?.runOnUiThread { result?.error("Unexpected", "Payment not Authorised", null) }
                asyncCallback(CallResult(CallResult.ResultType.FINISHED, "EMPTY"))
                return CallResult(CallResult.ResultType.FINISHED, "EMPTY")
            }
        }
    }
}

@Suppress("LongParameterList")
fun createPaymentRequest(
        paymentComponentData: JSONObject,
        reference: String,
        shopperReference: String,
        amount: Amount,
        countryCode: String,
        merchantAccount: String,
        redirectUrl: String,
        additionalData: AdditionalData
): JSONObject {

    val request = JSONObject(paymentComponentData.toString())

    request.put("shopperReference", shopperReference)
    request.put("amount", JSONObject(Gson().toJson(amount)))
    request.put("merchantAccount", merchantAccount)
    request.put("returnUrl", redirectUrl)
    request.put("countryCode", countryCode)
    request.put("reference", reference)
    request.put("channel", "android")
    request.put("additionalData", JSONObject(Gson().toJson(additionalData)))
    //TODO : To read shopperIP & lineItems from Flutter app
//    request.put("shopperIP", "142.12.31.22")
//    request.put("lineItems", JSONArray(Gson().toJson(listOf(Item()))))

    return request
}

private fun getAmount(amount: String, currency: String) = createAmount(amount, currency)

fun createAmount(value: String, currency: String): Amount {
    log("createAmount < $value $currency")
    val amount = Amount()
    amount.currency = currency
    amount.value = value.toInt()
    log("createAmount > ${amount.value} ${amount.currency}")
    return amount
}

data class AdditionalData(
        val allow3DS2: String = "false",
        val executeThreeD: String = "false"
)

//TODO : (Optional) Read from Flutter
data class Item(
        val quantity: Int = 2,
        val amountExcludingTax: Int = 100,
        val taxPercentage: Int = 0,
        val description: String = "Coffee",
        // item id should be unique
        val id: String = Date().time.toString(),
        val amountIncludingTax: Int = 100,
        val taxCategory: String = "Low"
)

private fun log(toLog: String) {
    if (enableLogging)
        Log.d(sharedPrefsKey, "ADYEN (native) : $toLog")
}
