import 'package:fuodz/constants/api.dart';
import 'package:fuodz/services/alert.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuodz/constants/app_routes.dart';
import 'package:fuodz/models/api_response.dart';
import 'package:fuodz/requests/auth.request.dart';
import 'package:fuodz/services/auth.service.dart';
import 'package:fuodz/traits/qrcode_scanner.trait.dart';
import 'package:fuodz/views/pages/auth/register.page.dart';
import 'package:localize_and_translate/localize_and_translate.dart';
import 'base.view_model.dart';
import 'package:velocity_x/velocity_x.dart';

class LoginViewModel extends MyBaseViewModel with QrcodeScannerTrait {
  //the textediting controllers
  TextEditingController emailTEC = new TextEditingController();
  TextEditingController passwordTEC = new TextEditingController();

  //
  AuthRequest _authRequest = AuthRequest();

  LoginViewModel(BuildContext context) {
    this.viewContext = context;
  }

void initialise() {
  // استخدام بيانات المطور في وضع التطوير
  emailTEC.text = kReleaseMode ? "" : "dev@test.com";
  passwordTEC.text = kReleaseMode ? "" : "any_password";
}

  // Developer Mode: محاكاة تسجيل دخول ناجح
Future<void> _devModeLogin() async {
  print("🛠️ ========== DEVELOPER MODE ==========");
  print("⚠️ Bypassing real authentication");
  print("🔧 Creating mock user and vendor data");
  
  try {
    // إنشاء بيانات مستخدم وهمية
    final mockUser = {
      "id": 999,
      "vendor_id": 1,
      "name": "Developer User",
      "email": "dev@test.com",
      "phone": "+201234567890",
      "photo": "https://via.placeholder.com/150",
      "role_name": "manager",
      "is_online": true,
      "has_multiple_vendors": false,
      "roles": []
    };

    // إنشاء بيانات متجر وهمية
    final mockVendor = {
      "id": 1,
      "name": "Test Vendor",
      "description": "Developer Test Vendor",
      "base_delivery_fee": "10",
      "delivery_fee": "10",
      "delivery_range": "50",
      "tax": "0",
      "phone": "+201234567890",
      "email": "vendor@test.com",
      "address": "Test Address",
      "latitude": "30.0444",
      "longitude": "31.2357",
      "comission": "10",
      "pickup": 1,
      "delivery": 1,
      "rating": 5,
      "charge_per_km": 0,
      "is_open": true,
      "is_active": 1,
      "logo": "https://via.placeholder.com/150",
      "feature_image": "https://via.placeholder.com/300",
      "can_rate": true,
      "allow_schedule_order": true,
      "has_sub_categories": false,
      "use_subscription": false,
      "has_subscription": false,
      "vendor_type": {
        "id": 1,
        "name": "Food",
        "slug": "food",
        "description": "Food delivery",
        "color": "#FF0000",
        "logo": "https://via.placeholder.com/100"
      }
    };

    // حفظ البيانات
    await AuthServices.saveUser(mockUser);
    await AuthServices.saveVendor(mockVendor);
    await AuthServices.setAuthBearerToken("dev_mock_token_12345");
    await AuthServices.isAuthenticated();
    
    print("✅ Mock data saved successfully");
    print("🏠 Navigating to home...");
    
    // الانتقال للصفحة الرئيسية
    Navigator.of(viewContext).pushNamedAndRemoveUntil(
      AppRoutes.homeRoute,
      (route) => false,
    );
  } catch (error) {
    print("💥 Developer mode error: $error");
    toastError("Developer mode error: $error");
  }
}

void processLogin() async {
  if (formKey.currentState!.validate()) {
    print("🔐 ========== LOGIN ATTEMPT ==========");
    print("📧 Email: ${emailTEC.text}");
    print("🔑 Password: ${passwordTEC.text}");
    print("🌐 API URL: ${Api.baseUrl}${Api.login}");
    
    setBusy(true);

    // تفعيل وضع المطور
    if (!kReleaseMode && emailTEC.text == "dev@test.com") {
      await _devModeLogin();
      setBusy(false);
      return;
    }

    final apiResponse = await _authRequest.loginRequest(
      email: emailTEC.text,
      password: passwordTEC.text,
    );
    
    print("📡 ========== API RESPONSE ==========");
    print("📊 Status Code: ${apiResponse.code}");
    print("📝 Message: ${apiResponse.message}");
    print("❌ Has Errors: ${apiResponse.hasError()}");
    print("🔢 Errors Count: ${apiResponse.errors.length}");
    print("📦 Full Body: ${apiResponse.body}");
    print("=====================================");
    
    await handleDeviceLogin(apiResponse);

    setBusy(false);
  }
}

  //QRCode login
  void initateQrcodeLogin() async {
    //
    final loginCode = await openScanner(viewContext);
    if (loginCode == null) {
      toastError("Operation failed/cancelled".tr());
    } else {
      setBusy(true);

      try {
        final apiResponse = await _authRequest.qrLoginRequest(
          code: loginCode,
        );
        //
    await handleDeviceLogin(apiResponse);
      } catch (error) {
        print("QR Code login error ==> $error");
      }

      setBusy(false);
    }
  }

  ///
  ///
  ///
handleDeviceLogin(ApiResponse apiResponse) async {
  try {
    print("🔍 ========== HANDLING LOGIN ==========");
    print("📊 Response code: ${apiResponse.code}");
    print("📋 Response errors: ${apiResponse.errors}");
    print("📝 Response message: ${apiResponse.message}");
    
    if (apiResponse.hasError()) {
      print("❌ LOGIN FAILED!");
      print("💬 Error message: ${apiResponse.message}");
      AlertService.error(
        title: "Login Failed".tr(),
        text: apiResponse.message,
      );
    } else {
      print("✅ LOGIN SUCCESSFUL!");
      print("🔥 Checking Firebase token...");
      final fbToken = apiResponse.body["fb_token"];
      print("🎫 FB Token exists: ${fbToken != null}");
      print("👤 User data exists: ${apiResponse.body["user"] != null}");
      print("🏪 Vendor data exists: ${apiResponse.body["vendor"] != null}");
      
      await FirebaseAuth.instance.signInWithCustomToken(fbToken);
      print("✅ Firebase auth successful");
      
      await AuthServices.saveUser(apiResponse.body["user"]);
      await AuthServices.saveVendor(apiResponse.body["vendor"]);
      await AuthServices.setAuthBearerToken(apiResponse.body["token"]);
      await AuthServices.isAuthenticated();
      
      print("🏠 Navigating to home...");
      Navigator.of(viewContext).pushNamedAndRemoveUntil(
        AppRoutes.homeRoute,
        (route) => false,
      );
    }
  } on FirebaseAuthException catch (error) {
    print("🔥 Firebase Auth Exception: ${error.code} - ${error.message}");
    AlertService.error(
      title: "Login Failed".tr(),
      text: "${error.message}",
    );
  } catch (error) {
    print("💥 General Exception: $error");
    AlertService.error(
      title: "Login Failed".tr(),
      text: "$error",
    );
  }
}
  void openForgotPassword() {
    Navigator.of(viewContext).pushNamed(
      AppRoutes.forgotPasswordRoute,
    );
  }

  void openRegistrationlink() async {
    viewContext.nextPage(RegisterPage());
    /*
    final url = Api.register;
    openExternalWebpageLink(url);
    */
  }
}
