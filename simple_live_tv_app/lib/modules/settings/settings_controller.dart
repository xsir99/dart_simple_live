import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';

class SettingsController extends BaseController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  var tabIndex = 0.obs;

  SettingsController() {
    tabController = TabController(length: 5, vsync: this);
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (tabIndex.value == currentIndex) {
        return;
      }
      tabIndex.value = currentIndex;
      if (tabIndex.value == 0) {
        hardwareDecodeFocusNode.requestFocus();
      }
      if (tabIndex.value == 1) {
        danmakuFoucsNode.requestFocus();
      }
      if (tabIndex.value == 2) {
        autoUpdateFollowEnableFocusNode.requestFocus();
      }
      if (tabIndex.value == 3) {
        bilibiliFoucsNode.requestFocus();
      }
      if (tabIndex.value == 4) {
        versionFocusNode.requestFocus();
      }
    });
  }
  var hardwareDecodeFocusNode = AppFocusNode()..isFoucsed.value = true;
  var compatibleModeFocusNode = AppFocusNode();
  var scaleFoucsNode = AppFocusNode();
  var defaultQualityFocusNode = AppFocusNode();
  var danmakuFoucsNode = AppFocusNode();
  var danmakuSizeFoucsNode = AppFocusNode();
  var danmakuSpeedFoucsNode = AppFocusNode();
  var danmakuAreaFoucsNode = AppFocusNode();
  var danmakuOpacityFoucsNode = AppFocusNode();
  var danmakuStorkeFoucsNode = AppFocusNode();

  var autoUpdateFollowEnableFocusNode = AppFocusNode();
  var autoUpdateFollowDurationFocusNode = AppFocusNode();
  var updateFollowThreadFocusNode = AppFocusNode();

  var bilibiliFoucsNode = AppFocusNode();
  var douyinFoucsNode = AppFocusNode();
  var versionFocusNode = AppFocusNode();

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }

  void douyinTap() {
    if (DouyinAccountService.instance.logined.value) {
      Get.dialog(
        AlertDialog(
          title: const Text("抖音账号"),
          content: const Text("已登录抖音账号，请选择操作"),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                DouyinAccountService.instance.logout();
              },
              child: const Text("退出登录"),
            ),
            TextButton(
              autofocus: true,
              onPressed: () {
                Get.back();
                toDouyinFollowLive();
              },
              child: const Text("查看关注直播"),
            ),
          ],
        ),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text("抖音登录"),
        content: const Text("请使用手机抖音扫码，或粘贴浏览器 Cookie 登录"),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.toNamed(RoutePath.kDouyinWebLogin);
            },
            child: const Text("扫码登录"),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.toNamed(RoutePath.kDouyinCookieLogin);
            },
            child: const Text("Cookie登录"),
          ),
        ],
      ),
    );
  }

  void toDouyinFollowLive() {
    Get.toNamed(RoutePath.kDouyinFollowLive);
  }
}
