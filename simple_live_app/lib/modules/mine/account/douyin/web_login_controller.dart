import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';

class DouyinWebLoginController extends BaseController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  Timer? pollTimer;
  bool isLoggingIn = false;

  @override
  void onInit() {
    super.onInit();
    cookieManager.deleteAllCookies();
    startPoll();
  }

  void startPoll() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      checkLoginStatus();
    });
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(
            "https://www.douyin.com/login_page?service=https%3A%2F%2Fwww.douyin.com"),
      ),
    );
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) async {
    if (uri == null) {
      return;
    }
    await checkLoginStatus();
  }

  Future<bool> checkLoginStatus() async {
    if (isLoggingIn) return false;
    try {
      final cookiesMap = <String, String>{};
      for (final url in [
        WebUri("https://www.douyin.com"),
        WebUri("https://sso.douyin.com"),
        WebUri("https://live.douyin.com"),
      ]) {
        try {
          final list = await cookieManager.getCookies(url: url);
          for (final c in list) {
            if (c.name.isNotEmpty && c.value.isNotEmpty) {
              cookiesMap[c.name] = c.value;
            }
          }
        } catch (_) {}
      }

      final hasSession = cookiesMap.containsKey("sessionid") ||
          cookiesMap.containsKey("sessionid_ss");
      if (!hasSession) {
        return false;
      }

      isLoggingIn = true;
      pollTimer?.cancel();

      final cookieStr =
          cookiesMap.entries.map((e) => "${e.key}=${e.value}").join("; ");
      Log.i("Douyin login cookies: $cookieStr");
      DouyinAccountService.instance.setCookie(cookieStr);
      Get.back();
      return true;
    } catch (e) {
      return false;
    } finally {
      if (!DouyinAccountService.instance.hasCookie.value) {
        isLoggingIn = false;
      }
    }
  }

  Future<bool> logined() async {
    return await checkLoginStatus();
  }

  @override
  void onClose() {
    pollTimer?.cancel();
    super.onClose();
  }
}
