import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/account/douyin/web_login_controller.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class DouyinWebLoginPage extends GetView<DouyinWebLoginController> {
  const DouyinWebLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "抖音扫码登录",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.check,
                text: "完成登录",
                onTap: controller.logined,
              ),
              AppStyle.hGap48,
            ],
          ),
          AppStyle.vGap24,
          Expanded(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStop: controller.onLoadStop,
              onConsoleMessage: controller.onConsoleMessage,
              onReceivedError: controller.onReceivedError,
              initialSettings: InAppWebViewSettings(
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0",
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                cacheEnabled: true,
                thirdPartyCookiesEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
              ),
              shouldOverrideUrlLoading: (webController, navigationAction) async {
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA24,
            child: Text(
              "请使用抖音手机 App 扫描页面中的二维码并确认登录",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32.w),
            ),
          ),
        ],
      ),
    );
  }
}
