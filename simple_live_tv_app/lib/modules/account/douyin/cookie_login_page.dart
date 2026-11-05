import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/tv_input_channel.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class DouyinCookieLoginPage extends StatefulWidget {
  const DouyinCookieLoginPage({super.key});

  @override
  State<DouyinCookieLoginPage> createState() => _DouyinCookieLoginPageState();
}

class _DouyinCookieLoginPageState extends State<DouyinCookieLoginPage> {
  final textController = TextEditingController();
  final _displayFocusNode = FocusNode(canRequestFocus: false);

  @override
  void dispose() {
    _displayFocusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  Future<void> openSystemInput() async {
    final value = await TvInputChannel.show(
      title: "粘贴抖音 Cookie",
      hint: "请粘贴包含 sessionid 的完整 Cookie",
      initialText: textController.text,
    );
    if (value == null) return;
    setState(() {
      textController.text = value;
    });
  }

  void saveCookie() {
    var input = textController.text.trim();
    if (input.isEmpty) {
      return;
    }
    DouyinAccountService.instance.setCookie(input);
    DouyinAccountService.instance.loadUserInfo();
    SmartDialog.showToast("抖音 Cookie 已保存");
    Get.back();
  }

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
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "粘贴抖音 Cookie",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          AppStyle.vGap48,
          Expanded(
            child: Padding(
              padding: AppStyle.edgeInsetsH48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: textController,
                    focusNode: _displayFocusNode,
                    readOnly: true,
                    maxLines: 6,
                    style: AppStyle.textStyleWhite,
                    decoration: InputDecoration(
                      hintText: "请按下方按钮用系统键盘输入 Cookie",
                      hintStyle: AppStyle.textStyleWhite.copyWith(
                        color: Colors.white54,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppStyle.radius16,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppStyle.radius16,
                        borderSide: BorderSide(
                          color: Colors.white,
                          width: 4.w,
                        ),
                      ),
                    ),
                  ),
                  AppStyle.vGap48,
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.keyboard,
                    text: "使用系统键盘输入",
                    onTap: openSystemInput,
                  ),
                  AppStyle.vGap24,
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.check,
                    text: "保存",
                    onTap: saveCookie,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
