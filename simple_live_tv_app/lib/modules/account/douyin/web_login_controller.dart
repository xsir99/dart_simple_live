import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';

class DouyinWebLoginController extends BaseController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  Timer? pollTimer;
  bool isLoggingIn = false;

  @override
  void onInit() {
    super.onInit();
    // 清除旧 Cookie，保证扫码状态完全崭新
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
    Log.i("Douyin login page loaded: $uri");
    // 适当放大页面，让二维码在 TV 屏幕上更大更清晰
    try {
      await controller.evaluateJavascript(source: """
        try {
          if (document.body) {
            document.body.style.zoom = '1.2';
          }
        } catch(e) {}
      """);
    } catch (_) {}
    await checkLoginStatus();
  }

  void onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage message,
  ) {
    Log.i("Douyin WebView console: ${message.message}");
  }

  void onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    Log.e(
      "Douyin WebView error: ${error.description} (${error.type})",
      StackTrace.current,
    );
  }

  Future<bool> checkLoginStatus({bool showToastOnFail = false}) async {
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
        if (showToastOnFail) {
          SmartDialog.showToast("尚未检测到登录状态，请先在手机上扫码并确认登录");
        }
        return false;
      }

      isLoggingIn = true;
      pollTimer?.cancel();

      final cookieStr =
          cookiesMap.entries.map((e) => "${e.key}=${e.value}").join("; ");
      Log.i("Douyin login cookies: $cookieStr");
      DouyinAccountService.instance.setCookie(cookieStr);
      await DouyinAccountService.instance.loadUserInfo();
      SmartDialog.showToast(
          "抖音登录成功: ${DouyinAccountService.instance.name.value}");
      Get.back();
      return true;
    } catch (e, st) {
      Log.e("Check Douyin login error: $e", st);
      if (showToastOnFail) {
        SmartDialog.showToast("登录检查异常，请重试");
      }
      return false;
    } finally {
      if (!DouyinAccountService.instance.logined.value) {
        isLoggingIn = false;
      }
    }
  }

  Future<bool> logined() async {
    return await checkLoginStatus(showToastOnFail: true);
  }

  @override
  void onClose() {
    pollTimer?.cancel();
    super.onClose();
  }
}

