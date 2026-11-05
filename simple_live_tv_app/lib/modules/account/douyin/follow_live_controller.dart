import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/hot_live/hot_live_controller.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';

class DouyinFollowLiveController extends BasePageController<LiveRoomItemExt> {
  final site = Sites.allSites[Constant.kDouyin]!;

  @override
  void onInit() {
    scrollController.addListener(scrollListener);
    refreshData();
    super.onInit();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
        (scrollController.position.maxScrollExtent - 100.w)) {
      loadData();
    }
  }

  @override
  Future<List<LiveRoomItemExt>> getData(int page, int pageSize) async {
    if (!DouyinAccountService.instance.logined.value) {
      return [];
    }
    var result = await (site.liveSite as DouyinSite)
        .getFollowLiveRooms(page: page);

    return result.items
        .map(
          (e) => LiveRoomItemExt(
            roomId: e.roomId,
            title: e.title,
            cover: e.cover,
            userName: e.userName,
            online: e.online,
          ),
        )
        .toList();
  }

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
    super.onClose();
  }
}
