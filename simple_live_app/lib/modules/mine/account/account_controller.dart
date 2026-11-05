import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result = await Utils.showAlertDialog("确定要清除自定义 Cookie 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
      }
    } else {
      douyinLogin();
    }
  }

  void douyinLogin() {
    Utils.showBottomSheet(
      title: "登录抖音",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text("Web登录"),
            subtitle: const Text("在网页上登录后自动获取 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kDouyinWebLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入完整 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doDouyinCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doDouyinCookieLogin() {
    var savedCookie = DouyinAccountService.instance.cookie;
    var controller = TextEditingController(text: savedCookie);

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认已内置有效的 ttwid，可观看所有画质（包括蓝光）。\n"
                "如需使用搜索功能，请粘贴包含 sessionid 等登录态的完整 Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "请粘贴完整 Cookie，或只输入 ttwid 值",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  controller.text = DouyinSite.kDefaultCookie;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 Cookie"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                // 如果输入内容里没有等号，认为是仅 ttwid 的值，自动补全前缀
                var cookie = input.contains('=') ? input : 'ttwid=$input';
                DouyinAccountService.instance.setCookie(cookie);
                SmartDialog.showToast("抖音 Cookie 已保存");
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
}
