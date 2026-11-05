import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/requests/http_client.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';

class DouyinAccountService extends GetxService {
  static DouyinAccountService get instance => Get.find<DouyinAccountService>();

  var logined = false.obs;
  var cookie = "";
  var name = "未登录".obs;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyinCookie, "");
    logined.value = cookie.isNotEmpty;
    setSite();
    loadUserInfo();
    super.onInit();
  }

  Future loadUserInfo() async {
    if (cookie.isEmpty) {
      return;
    }
    try {
      var result = await HttpClient.instance.getJson(
        "https://www.douyin.com/webcast/user/me/",
        queryParameters: {
          "aid": "6383",
          "app_name": "douyin_web",
          "live_id": "1",
          "device_platform": "web",
        },
        header: {
          "Cookie": cookie,
          "Referer": "https://www.douyin.com/",
          "User-Agent": DouyinSite.kDefaultUserAgent,
        },
      );
      if (result is Map && result["status_code"] == 0) {
        var data = result["data"];
        name.value = data?["nickname"]?.toString() ?? "已登录";
      } else if (result is Map && result["status_code"] == 2483) {
        SmartDialog.showToast("抖音登录已失效，请重新登录");
        logout();
        return;
      }
      setSite();
    } catch (e) {
      SmartDialog.showToast("获取抖音用户信息失败，可前往账号管理重试");
      setSite();
    }
  }

  void setSite() {
    var site = (Sites.allSites[Constant.kDouyin]!.liveSite as DouyinSite);
    site.cookie = cookie;
    site.resetLoginState();
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, cookie);
    logined.value = cookie.isNotEmpty;
    setSite();
  }

  void logout() async {
    cookie = "";
    name.value = "未登录";
    setSite();
    await LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, "");
    logined.value = false;
  }
}
