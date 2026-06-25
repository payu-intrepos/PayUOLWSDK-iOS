import 'package:flutter/material.dart';
import 'package:olw_sdk_flutter/olw_sdk_flutter.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'HashService.dart';

void main() {
  runApp(const MyApp());
}

String referenceId() {
  final now = DateTime.now();

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  // Keep the random numeric portion compact: ddHHmmss.
  final timestamp = [
    twoDigits(now.day),
    twoDigits(now.hour),
    twoDigits(now.minute),
    twoDigits(now.second),
  ].join();

  final txnId = "olw_refID_$timestamp";
  debugPrint("Generated PayU reference ID: $txnId");
  return txnId;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WalletPage(),
    );
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  _WalletPageState createState() => _WalletPageState();
}

/// Tracks which SDK initiated the current payment flow for hash callback routing.
enum _ActivePaymentFlow { olw, checkoutPro }

class _WalletPageState extends State<WalletPage> implements PayUOLWProtocol, PayUCheckoutProProtocol {
  late PayUOLWFlutter _payUOLW;
  late PayUCheckoutProFlutter _checkoutPro;

  /// Set when user taps Launch OLW SDK or Open CheckOutPro so generateHash routes correctly.
  _ActivePaymentFlow? _activePaymentFlow;

  /// Controllers for all SDK params
  final olwMerchantKeyController =
  TextEditingController(text: "YourMerchantKit");
  final olwMerchantSaltController =
  TextEditingController(text: "yoursalt");

  final checkOutProMerchantKeyController =
  TextEditingController(text: "Your merchant key");
  final checkOutProMerchantSaltController =
  TextEditingController(text: "yoursalt");

  final customerMobileController =
  TextEditingController(text: "yourMobileNumber");
  final supportEmailController =
  TextEditingController(text: "support@merchant.com");
  final primaryColorController =
  TextEditingController(text: "#3E1C64");
  final termsUrlController =
  TextEditingController(text: "https://payu.in");
  final merchantLogoController =
  TextEditingController(text: "merchant_logo");
  final redirectionUrl =
  TextEditingController(text: "redrect url/.com");
  final payuReferenceId =
  TextEditingController(text: referenceId());


  bool isProduction = false;

  @override
  void initState() {
    super.initState();
    _payUOLW = PayUOLWFlutter(this);
    _checkoutPro = PayUCheckoutProFlutter(this);
  }

  /// Launch OLW SDK
  void launchOLWSDK() {
    // Mark OLW as active so shared generateHash callback returns hash to OLW SDK.
    _activePaymentFlow = _ActivePaymentFlow.olw;
    debugPrint("Active payment flow set to OLW");

    try {
      final params = PayUOLWParamsBuilder()
          .setPayUReferenceId(payuReferenceId.text)
          .setMerchantKey(olwMerchantKeyController.text)
          .setIsProduction(isProduction)
          .setCustomerMobile(customerMobileController.text)
          .setMerchantSupportEmail(supportEmailController.text)
          .setTermsAndConditionsURL(termsUrlController.text)
          .setPrimaryColor(primaryColorController.text)
          .setKycRedirectionUrl(redirectionUrl.text)
          .setMerchantLogoName(merchantLogoController.text)
          .build();

      print("paramObject$params");
      _payUOLW.openPayUOLWSDK(payUOLWParams: params);

    } on ArgumentError catch (e) {
      onError({
        PayUOLWConstants.errorCode: PayUOLWErrorCodes.merchantKeyError.toString(),
        PayUOLWConstants.errorMessage: e.message.toString(),
      });
    }
  }

  /// Hash generation callback — shared by OLW and CheckOutPro (different native channels).
  @override
  generateHash(Map response) {
    debugPrint("generateHash called (flow: $_activePaymentFlow) response: $response");

    var salt = _activePaymentFlow == _ActivePaymentFlow.olw ? olwMerchantSaltController.text : checkOutProMerchantSaltController.text;
    final generatedHashMap =
        HashService.generateHash(response, salt);
    final String hashName = response["hashName"] ?? "";
    final String hashValue = generatedHashMap[hashName] ?? "";

    if (_activePaymentFlow == _ActivePaymentFlow.olw) {
      // OLW native bridge expects {hashString, hashName}.
      final Map<String, dynamic> hashResult = {
        PayUOLWHashKeys.hashString: hashValue,
        "hashName": hashName,
      };
      debugPrint("generateHash: OLW hash = $generatedHashMap)");
      _payUOLW.hashGenerated(hashResult: hashResult);
    } else {
      debugPrint(
          "generateHash: CheckOutPro hash = $generatedHashMap");
      _checkoutPro.hashGenerated(hash: generatedHashMap);
    }
  }

  @override
  onClose() {
    debugPrint("OLW SDK closed");
  }

  @override
  onError(Map? response) {
    debugPrint("onError callback (flow: $_activePaymentFlow): $response");

    // CheckOutPro uses errorMsg; OLW uses errorMessage — handle both keys.
    if (_activePaymentFlow == _ActivePaymentFlow.checkoutPro) {
      showAlertDialog(context, "onError", response.toString());
      _activePaymentFlow = null;
      return;
    }

    final errorMessage = response?[PayUOLWConstants.errorMessage] ??
        response?["errorMsg"] ??
        "Unknown error";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTextField(
      {required String label,
        required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PayU OLW SDK Demo"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
                label: "OLW Merchant Key",
                controller: olwMerchantKeyController),

            _buildTextField(
                label: "OLW Merchant Salt",
                controller: olwMerchantSaltController),
            
            _buildTextField(
                label: "Customer Mobile",
                controller: customerMobileController),

            _buildTextField(
                label: "Logo Name",
                controller: merchantLogoController),

            _buildTextField(
                label: "Support Email",
                controller: supportEmailController),
            _buildTextField(
                label: "Primary Color (Hex)",
                controller: primaryColorController),
            _buildTextField(
                label: "Terms & Conditions URL",
                controller: termsUrlController),
            _buildTextField(
                label: "Kyc Redirection Url",
                controller: redirectionUrl),
            _buildTextField(
                label: "PayU ReferenceId",
                controller: payuReferenceId),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Production Mode"),
              value: isProduction,
              onChanged: (value) {
                setState(() => isProduction = value);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: launchOLWSDK,
              child: const Text("Launch OLW SDK"),
            ),
            const SizedBox(height: 12),

            Divider(height: 20, thickness: 2,  color: const Color.fromARGB(255, 79, 11, 11)),

            _buildTextField(
                label: "CheckoutPro Merchant Key",
                controller: checkOutProMerchantKeyController),

            _buildTextField(
                label: "CheckoutPro Merchant Salt",
                controller: checkOutProMerchantSaltController),

            ElevatedButton(
            child: const Text("Open CheckOutPro Payment"),
            onPressed: () async {
              // Mark CheckOutPro as active so shared generateHash callback returns hash to CheckOutPro.
              _activePaymentFlow = _ActivePaymentFlow.checkoutPro;
              debugPrint("Active payment flow set to CheckOutPro");

              _checkoutPro.openCheckoutScreen(
                payUPaymentParams: PayUParams.createPayUPaymentParams(
                  merchantKey: checkOutProMerchantKeyController.text,
                ),
                payUCheckoutProConfig: PayUParams.createPayUConfigParams(),
              );
            },
          ),
          ],
          
        ),
      ),
    );
  }

// Checkout Pro methods:
showAlertDialog(BuildContext context, String title, String content) {
  debugPrint("Showing alert title = $title");
  debugPrint("Showing alert content= $content");
    Widget okButton = TextButton(
      child: const Text("OK"),
      onPressed: () {
        Navigator.pop(context);
      },
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              scrollDirection: Axis.vertical,

              child: Text(content),
            ),
            actions: [okButton],
          );
        });
  }

  @override
  onPaymentSuccess(dynamic response) {
    debugPrint("onPaymentSuccess: $response");
    _activePaymentFlow = null;
    showAlertDialog(context, "onPaymentSuccess", response.toString());
  }

  @override
  onPaymentFailure(dynamic response) {
    debugPrint("onPaymentFailure: $response");
    _activePaymentFlow = null;
    showAlertDialog(context, "onPaymentFailure", response.toString());
  }

  @override
  onPaymentCancel(Map? response) {
    debugPrint("onPaymentCancel: $response");
    _activePaymentFlow = null;
    showAlertDialog(context, "onPaymentCancel", response.toString());
  }

  // @override: from Checkout pro sample
  // onError(Map? response) {
  //   showAlertDialog(context, "onError", response.toString());
  // }
}


// CheckOUt Pro data
class PayUTestCredentials { 
  //static const merchantKey = checkout.text // CheckOutPro test key — replace from PayU dashboard
  //static const merchantSalt = ""; // CheckOutPro test salt — replace from PayU dashboard
  //Use your success and fail URL's.
  
  static const iosSurl = "https://payu.herokuapp.com/ios_success";//TODO: Add Success URL.
  static const iosFurl = "https://payu.herokuapp.com/ios_failure";//TODO Add Fail URL.
  static const androidSurl = "https://payuresponse.firebaseapp.com/success";//TODO: Add Success URL.
  static const androidFurl = "https://payuresponse.firebaseapp.com/failure";//TODO Add Fail URL.


  //static const merchantAccessKey = "";//TODO: Add Merchant Access Key - Optional
  //static const sodexoSourceId = ""; //TODO: Add sodexo Source Id - Optional
}

// CheckOUt Pro data
//Pass these values from your app to SDK, this data is only for test purpose
class PayUParams {
  /// Pass merchant key from UI so hash salt and payment key stay in sync.
  static Map createPayUPaymentParams({required String merchantKey}) {
   /* var siParams = {
      PayUSIParamsKeys.isFreeTrial: true,
      PayUSIParamsKeys.billingAmount: '1',              //Required
      PayUSIParamsKeys.billingInterval: 1,              //Required
      PayUSIParamsKeys.paymentStartDate: '2023-04-20',  //Required
      PayUSIParamsKeys.paymentEndDate: '2023-04-30',    //Required
      PayUSIParamsKeys.billingCycle:                    //Required
          'daily', //Can be any of 'daily','weekly','yearly','adhoc','once','monthly'
      PayUSIParamsKeys.remarks: 'Test SI transaction',
      PayUSIParamsKeys.billingCurrency: 'INR',
      PayUSIParamsKeys.billingLimit: 'ON', //ON, BEFORE, AFTER
      PayUSIParamsKeys.billingRule: 'MAX', //MAX, EXACT
    };*/

    var additionalParam = {
      PayUAdditionalParamKeys.udf1: "udf1",
      PayUAdditionalParamKeys.udf2: "udf2",
      PayUAdditionalParamKeys.udf3: "udf3",
      PayUAdditionalParamKeys.udf4: "udf4",
      PayUAdditionalParamKeys.udf5: "udf5"//,
      // PayUAdditionalParamKeys.merchantAccessKey:
      //     PayUTestCredentials.merchantAccessKey,
      // PayUAdditionalParamKeys.sourceId:PayUTestCredentials.sodexoSourceId,
      // PayUAdditionalParamKeys.walletUrn:"100000"
    };


/*var spitPaymentDetails =
   {
     "type": "absolute",
     "splitInfo": {
       PayUTestCredentials.merchantKey: {
         "aggregatorSubTxnId": "1234567540099887766650092", //unique for each transaction
         "aggregatorSubAmt": "1"
       },
       /* "qOoYIv": {
          "aggregatorSubTxnId": "12345678",
          "aggregatorSubAmt": "40"
       },*/
     }
   };*/

/* var skus =  [ {
                                  "skuId": "puspendraskuwallet1",
                                  "skuName": "Smartphone",
                                  "skuAmount": "6000",
                                  "quantity": 1,
                                  "offerKeys": null
                                },
                                {
                                  "skuId": "puspendraskuwallet2",
                                  "skuName": "Smartwatch",
                                  "skuAmount": "6000",
                                  "quantity": 1,
                                  "offer_key": null
                                }
                              ];
         var skuDetails = {
         "skus" : skus
         };*/

    var payUPaymentParams = {
      PayUPaymentParamKey.key: merchantKey,
      PayUPaymentParamKey.amount: "10", // inCase of skudDetails pass amount equal to total skuAmount
      PayUPaymentParamKey.productInfo: "Info",
      PayUPaymentParamKey.firstName: "Abc",
      PayUPaymentParamKey.email: "test@gmail.com",
      PayUPaymentParamKey.phone: "yourMObile",
      PayUPaymentParamKey.ios_surl: PayUTestCredentials.iosSurl,
      PayUPaymentParamKey.ios_furl: PayUTestCredentials.iosFurl,
      PayUPaymentParamKey.android_surl: PayUTestCredentials.androidSurl,
      PayUPaymentParamKey.android_furl: PayUTestCredentials.androidFurl,
      // 0 = Production, 1 = Test — use "1" for sandbox/test credentials.
      PayUPaymentParamKey.environment: "1",
      PayUPaymentParamKey.userCredential: "$merchantKey:test@gmail.com",
      PayUPaymentParamKey.transactionId:
          DateTime.now().millisecondsSinceEpoch.toString(),
      PayUPaymentParamKey.additionalParam: additionalParam,
      PayUPaymentParamKey.enableNativeOTP: true,
     // PayUPaymentParamKey.splitPaymentDetails:json.encode(spitPaymentDetails),
//TODO: Pass a unique token to fetch offers. - Optional
      //PayUPaymentParamKey.skuDetails: skuDetails,  // Pass skuDetails to fetch product offers. - Optional
     // PayUPaymentParamKey.userToken:"anshul_bajpai_token", //TODO: Pass a unique token to fetch offers. - Optional
    };
    debugPrint("payUPaymentParams = $payUPaymentParams");
    return payUPaymentParams;
  }

  static Map createPayUConfigParams() {
    /*var paymentModesOrder = [
      {"Wallets": "PHONEPE"},
      {"UPI": "TEZ"},
      {"Wallets": ""},
      {"EMI": ""},
      {"NetBanking": ""},
    ];

    var cartDetails = [
      {"GST": "5%"},
      {"Delivery Date": "25 Dec"},
      {"Status": "In Progress"}
    ];
    var enforcePaymentList = [
      //{"payment_type": "CARD", "card_type": "CC", "card_scheme": "MAST"},
      {"payment_type": "CARD", "card_type": "DC", "card_scheme": "VISA"},
      {"payment_type": "CARD", "card_type": "CC", "card_scheme": "VISA"},
      //{"payment_type": "UPI"},
      {"payment_type": "NB"},
    ];*/

     var customNotes = [
      {
        "custom_note": "Its Common custom note for testing purpose",
        "custom_note_category": [PayUPaymentTypeKeys.emi,PayUPaymentTypeKeys.card]
      },
      {
        "custom_note": "Payment options custom note",
        "custom_note_category": null
      }
    ];

    var payUCheckoutProConfig = {
      PayUCheckoutProConfigKeys.primaryColor: "#4994EC",
      PayUCheckoutProConfigKeys.secondaryColor: "#FFFFFF",
      PayUCheckoutProConfigKeys.merchantName: "PayU",
      PayUCheckoutProConfigKeys.merchantLogo: "logo",
      PayUCheckoutProConfigKeys.showExitConfirmationOnCheckoutScreen: true,
      PayUCheckoutProConfigKeys.showExitConfirmationOnPaymentScreen: true,
      //PayUCheckoutProConfigKeys.cartDetails: cartDetails,
      //PayUCheckoutProConfigKeys.paymentModesOrder: paymentModesOrder,
      PayUCheckoutProConfigKeys.merchantResponseTimeout: 30000,
      PayUCheckoutProConfigKeys.customNotes: customNotes,
      //PayUCheckoutProConfigKeys.autoSelectOtp: true,
      //PayUCheckoutProConfigKeys.enforcePaymentList: enforcePaymentList,
      PayUCheckoutProConfigKeys.waitingTime: 30000,
      PayUCheckoutProConfigKeys.autoApprove: true,
      PayUCheckoutProConfigKeys.merchantSMSPermission: true,
      PayUCheckoutProConfigKeys.showCbToolbar: true,
      PayUCheckoutProConfigKeys.showMerchantLogo : true,
      PayUCheckoutProConfigKeys.enableSavedCard : true,
      PayUCheckoutProConfigKeys.enableSslDialog : true,
      PayUCheckoutProConfigKeys.baseTextColor : "#4994EC",
     // PayUCheckoutProConfigKeys.enableREOptions : true/false (default -> true)
    };
    debugPrint("payUCheckoutProConfig: $payUCheckoutProConfig");

    return payUCheckoutProConfig;
  }
}
