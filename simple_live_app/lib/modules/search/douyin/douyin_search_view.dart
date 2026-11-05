import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/search/douyin/douyin_search_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

class DouyinSearchView extends StatelessWidget {
  const DouyinSearchView({Key? key}) : super(key: key);
  DouyinSearchController get controller => Get.find<DouyinSearchController>();

  @override
  Widget build(BuildContext context) {
    var roomRowCount = MediaQuery.of(context).size.width ~/ 200;
    if (roomRowCount < 2) roomRowCount = 2;

    var userRowCount = MediaQuery.of(context).size.width ~/ 500;
    if (userRowCount < 1) userRowCount = 1;
    return KeepAliveWrapper(
      child: Stack(
        children: [
          Positioned.fill(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStop: controller.onLoadStop,
              onLoadStart: controller.onLoadStart,
              initialSettings: InAppWebViewSettings(
                useOnLoadResource: true,
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
                useShouldOverrideUrlLoading: true,
              ),
              onCreateWindow: controller.onCreateWindow,
              shouldOverrideUrlLoading:
                  (webController, navigationAction) async {
                var uri = navigationAction.request.url;
                if (uri == null) {
                  return NavigationActionPolicy.ALLOW;
                }
                if (uri.host == "live.douyin.com") {
                  var regExp = RegExp(r"live\.douyin\.com/([\d|\w]+)");
                  var id = regExp.firstMatch(uri.toString())?.group(1) ?? "";

                  AppNavigator.toLiveRoomDetail(
                      site: controller.site, roomId: id);
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Padding(
                padding: AppStyle.edgeInsetsA12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "如果页面无法显示，可打开浏览器搜索后复制直播间链接进行解析",
                      textAlign: TextAlign.center,
                    ),
                    TextButton.icon(
                      onPressed: controller.openBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text("打开浏览器"),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Obx(
            () => Visibility(
              visible: controller.pageLoadding.value,
              child: const AppLoaddingWidget(),
            ),
          ),
        ],
      ),
    );
  }
}
