import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/douyin_categories_data.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/scripts/douyin_sign.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  /// 使用 QQBrowser User-Agent（参考 DouyinLiveRecorder）
  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.97 Safari/537.36 Core/1.116.567.400 QQBrowser/19.7.6764.400";

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";

  /// 默认 Cookie - 只需要 ttwid 字段即可获取所有画质（包括蓝光）
  /// 经过测试验证，LOGIN_STATUS=1 等其他字段都是可选的
  static const String kDefaultCookie =
      "ttwid=1%7CB1qls3GdnZhUov9o2NxOMxxYS2ff6OSvEWbv0ytbES4%7C1680522049%7C280d802d6d478e3e78d0c807f7c487e7ffec0ae4e5fdd6a0fe74c3c6af149511";

  /// 用户设置的 cookie
  String cookie = "";

  /// 当前登录用户的 sec_uid
  String secUserId = "";

  /// 关注列表分页游标，索引 0 为第一页（无游标），后续为对应页码的请求游标
  final List<int?> _followCursors = [null];

  /// 重置登录相关状态（切换账号或登出时调用）
  void resetLoginState() {
    secUserId = "";
    _followCursors.clear();
    _followCursors.add(null);
  }

  void _logDebug(String msg) {
    // 同时使用 print 和 CoreLog 确保日志输出
    print("[Douyin] $msg");
    CoreLog.d("[Douyin] $msg");
  }

  Map<String, dynamic> headers = {
    "Authority": kDefaultAuthority,
    "Referer": kDefaultReferer,
    "User-Agent": kDefaultUserAgent,
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      // 如果用户已设置 cookie，直接使用用户的 cookie
      if (cookie.isNotEmpty) {
        headers["cookie"] = cookie;
        return headers;
      }

      // 使用默认的 ttwid cookie（只需要 ttwid 即可获取所有画质）
      headers["cookie"] = kDefaultCookie;
      return headers;
    } catch (e) {
      CoreLog.error(e);
      if (!(headers["cookie"]?.toString().isNotEmpty ?? false)) {
        headers["cookie"] = kDefaultCookie;
      }
      return headers;
    }
  }

  /// 从抖音首页 HTML 中提取分类 JSON 数组
  String? _extractCategoryData(String html) {
    const key = '\\"pathname\\":\\"/\\",\\"categoryData\\":';
    var idx = html.indexOf(key);
    if (idx >= 0) {
      var start = html.indexOf('[', idx + key.length);
      if (start >= 0) {
        var depth = 0;
        var inString = false;
        var escape = false;
        for (var i = start; i < html.length; i++) {
          var ch = html[i];
          if (inString) {
            if (escape) {
              escape = false;
              continue;
            }
            if (ch == r'\\') {
              escape = true;
              continue;
            }
            if (ch == '"') {
              inString = false;
            }
            continue;
          }
          if (ch == '"') {
            inString = true;
          } else if (ch == '[') {
            depth++;
          } else if (ch == ']') {
            depth--;
            if (depth == 0) {
              return html
                  .substring(start, i + 1)
                  .replaceAll('\\"', '"')
                  .replaceAll(r'\\', r'\');
            }
          }
        }
      }
    }

    // 兼容旧版 HTML 中双重转义的分类数据
    var renderData =
        RegExp(r'\{\\"pathname\\":\\"\/\\",\\"categoryData.*?\]\\n')
            .firstMatch(html)
            ?.group(0);
    if (renderData == null || renderData.isEmpty) return null;
    return renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
  }

  /// 解析分类 href（如 /category/1_1 或 /category/1_1_1_1010032）为 partition 与 type
  (String, String) _parseCategoryHref(String href) {
    var parts = href.split('/').last.split('_');
    return (parts.last, parts[parts.length - 2]);
  }

  /// 从斗鱼分类接口拉取图标，按分类名称建立映射
  Future<Map<String, String>> _loadDouyuCategoryIcons() async {
    var icons = <String, String>{};
    try {
      var douyuCategories = await DouyuSite().getCategores();
      for (var category in douyuCategories) {
        for (var sub in category.children) {
          var pic = sub.pic;
          if (pic != null && pic.isNotEmpty) {
            icons[sub.name] = pic;
          }
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return icons;
  }

  /// 按名称查找最合适的斗鱼图标
  String? _findBestIcon(String name, Map<String, String> iconMap) {
    if (iconMap.containsKey(name)) {
      return iconMap[name];
    }
    String? bestKey;
    for (var key in iconMap.keys) {
      if (key.length < 2) continue;
      if (name.contains(key) || key.contains(name)) {
        if (bestKey == null || key.length > bestKey.length) {
          bestKey = key;
        }
      }
    }
    return bestKey != null ? iconMap[bestKey] : null;
  }

  /// 从 DTV 静态分类数据构建分类列表
  List<LiveCategory> _parseStaticCategories(Map<String, String> iconMap) {
    var categories = <LiveCategory>[];
    for (var item in douyinCategoriesData) {
      var (id, type) = _parseCategoryHref(item["href"].toString());
      var categoryId = '$id,$type';
      var categoryName = item["title"].toString();
      var subs = <LiveSubCategory>[];
      for (var subItem in item["subcategories"] as List) {
        var (subId, subType) = _parseCategoryHref(subItem["href"].toString());
        var subName = subItem["title"].toString();
        subs.add(
          LiveSubCategory(
            id: '$subId,$subType',
            name: subName,
            parentId: categoryId,
            pic: _findBestIcon(subName, iconMap) ??
                _findBestIcon(categoryName, iconMap) ??
                "",
          ),
        );
      }

      var category = LiveCategory(
        children: subs,
        id: categoryId,
        name: categoryName,
      );
      subs.insert(
        0,
        LiveSubCategory(
          id: category.id,
          name: category.name,
          parentId: category.id,
          pic: _findBestIcon(categoryName, iconMap) ?? "",
        ),
      );
      categories.add(category);
    }
    return categories;
  }

  /// 从抖音首页 HTML 构建分类列表（作为静态数据的兜底）
  Future<List<LiveCategory>> _getCategoriesFromHtml() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    var categoryDataJson = _extractCategoryData(result);
    if (categoryDataJson == null || categoryDataJson.isEmpty) {
      throw Exception("抖音分类数据解析失败");
    }
    var renderDataJson = json.decode(categoryDataJson);

    for (var item in renderDataJson) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
        0,
        LiveSubCategory(
          id: category.id,
          name: category.name,
          parentId: category.id,
          pic: "",
        ),
      );
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    var iconMap = await _loadDouyuCategoryIcons();
    var categories = _parseStaticCategories(iconMap);
    if (categories.isNotEmpty) {
      return categories;
    }
    return _getCategoriesFromHtml();
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var ids = category.id.split(',');
    var partitionId = ids[0];
    var partitionType = ids[1];

    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "enter_from": "link_share",
        "cookie_enabled": "true",
        "screen_width": "1980",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "125.0.0.0",
        "browser_online": "true",
        "count": '15',
        "offset": ((page - 1) * 15).toString(),
        "partition": partitionId,
        "partition_type": partitionType,
        "req_from": '2',
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    var dataList = (result["data"]?["data"] as List?) ?? [];
    var hasMore = dataList.length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in dataList) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online:
            asT<int?>(item["room"]?["user_count"]) ??
            int.tryParse(item["room"]?["user_count"]?.toString() ?? "") ??
            int.tryParse(
              item["room"]?["room_view_stats"]?["display_value"]?.toString() ?? "",
            ) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "enter_from": "link_share",
        "cookie_enabled": "true",
        "screen_width": "1980",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "125.0.0.0",
        "browser_online": "true",
        "count": '15',
        "offset": ((page - 1) * 15).toString(),
        "partition": '720',
        "partition_type": '1',
        "req_from": '2',
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    var dataList = (result["data"]?["data"] as List?) ?? [];
    var hasMore = dataList.length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in dataList) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online:
            asT<int?>(item["room"]?["user_count"]) ??
            int.tryParse(item["room"]?["user_count"]?.toString() ?? "") ??
            int.tryParse(
              item["room"]?["room_view_stats"]?["display_value"]?.toString() ?? "",
            ) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  /// 获取抖音账号关注且正在直播的列表
  /// 先通过 /aweme/v1/web/user/following/list/ 拉取关注列表，
  /// 再逐个调用 /aweme/v1/web/user/profile/other/ 判断 live_status，
  /// 最后通过 web_rid 获取直播间详情。
  /// 关注直播内部游标，指向下一页要拉取的关注列表页码
  int _followLiveNextPage = 1;


  Future<LiveCategoryResult> getFollowLiveRooms({int page = 1}) async {
    // 确保已拿到当前用户的 sec_uid
    if (secUserId.isEmpty) {
      await _ensureSecUserId();
    }
    if (secUserId.isEmpty) {
      throw Exception("抖音关注直播需要登录，请配置登录 Cookie 后再试");
    }

    if (page == 1) {
      _followLiveNextPage = 1;
      _followCursors.clear();
      _followCursors.add(null);
    }

    var items = <LiveRoomItem>[];
    var hasMore = false;

    // 遍历关注列表提取正在直播的主播（内存瞬时过滤，整列表约 2 秒内完成）
    while (true) {
      var result = await _fetchFollowingList(_followLiveNextPage);
      if (result == null) break;

      hasMore = (result["has_more"] == 1 || result["has_more"] == true);
      var followings = (result["followings"] as List?) ??
          (result["data"] as List?) ??
          [];
      _logDebug(
          "关注列表第 $_followLiveNextPage 页返回 ${followings.length} 条，has_more=$hasMore");

      if (followings.isEmpty) break;

      // 内存瞬间过滤：仅提取正在直播的用户，不发起全量 profile 网络请求
      for (var item in followings) {
        var user = item as Map<String, dynamic>;
        var userRoomId = user["room_id"]?.toString() ?? user["room_id_str"]?.toString() ?? "";
        var hasUserRoom = (userRoomId.isNotEmpty && userRoomId != "0");
        var userLiveStatus = asT<int?>(user["live_status"]) ?? 0;
        var hasRoomFlag = user["has_room"] == true;
        var rawRoomData = user["room_data"];

        // 只有明确开播的用户才处理，未开播的瞬间跳过（0ms）
        var isLive = hasUserRoom ||
            hasRoomFlag ||
            [1, 2, 5, 7].contains(userLiveStatus) ||
            (rawRoomData != null && rawRoomData != "" && rawRoomData != "{}");
        if (!isLive) continue;

        Map<String, dynamic>? roomData;
        if (rawRoomData is Map) {
          roomData = rawRoomData.cast<String, dynamic>();
        } else if (rawRoomData is String && rawRoomData.isNotEmpty) {
          try {
            roomData = jsonDecode(rawRoomData) as Map<String, dynamic>;
          } catch (_) {}
        }

        var webRid = roomData?["owner"]?["web_rid"]?.toString() ??
            roomData?["web_rid"]?.toString() ??
            user["web_rid"]?.toString() ??
            "";
        var roomId = roomData?["id_str"]?.toString() ?? userRoomId;

        var targetId = webRid.isNotEmpty ? webRid : roomId;
        if (targetId.isEmpty || targetId == "0") continue;

        var nickname = user["nickname"]?.toString() ?? "";
        var avatar = (user["avatar_thumb"]?["url_list"] as List?)?.first?.toString() ?? "";
        var roomTitle = roomData?["title"]?.toString() ?? nickname;
        var roomCover = (roomData?["cover"]?["url_list"] as List?)?.first?.toString() ?? avatar;
        var roomOnline = asT<int?>(roomData?["user_count"]) ??
            int.tryParse(roomData?["user_count"]?.toString() ?? "") ??
            asT<int?>(roomData?["room_view_stats"]?["display_value"]) ??
            int.tryParse(roomData?["room_view_stats"]?["display_value"]?.toString() ?? "") ??
            asT<int?>(roomData?["stats"]?["total_user"]) ??
            int.tryParse(roomData?["stats"]?["total_user"]?.toString() ?? "") ??
            asT<int?>(user["user_count"]) ??
            int.tryParse(user["user_count"]?.toString() ?? "") ??
            0;

        if (!items.any((x) => x.roomId == targetId)) {
          items.add(
            LiveRoomItem(
              roomId: targetId,
              title: roomTitle,
              cover: roomCover,
              userName: nickname,
              online: roomOnline,
            ),
          );
        }
      }

      _followLiveNextPage++;
      if (!hasMore) break;
    }

    _logDebug("本次返回正在直播 ${items.length} 人，还有更多=$hasMore");
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  /// 拉取一页关注列表
  Future<Map<String, dynamic>?> _fetchFollowingList(int page) async {
    var maxTime = "0";
    if (page > 1 && _followCursors.length >= page) {
      var cursor = _followCursors[page - 1];
      if (cursor != null && cursor > 0) {
        maxTime = cursor.toString();
      }
    }

    var query = <String, String>{
      "sec_user_id": secUserId,
      "offset": "0",
      "min_time": "0",
      "max_time": maxTime,
      "count": "50",
      "source_type": maxTime == "0" ? "2" : "1",
      "gps_access": "0",
      "address_book_access": "0",
      "is_top": "1",
      "aid": "6383",
      "channel": "channel_pc_web",
      "pc_client_type": "1",
      "pc_libra_divert": "Windows",
      "support_h265": "1",
      "support_dash": "1",
      "webcast_sdk_version": "170400",
      "webcast_version_code": "170400",
      "version_code": "170400",
      "version_name": "17.4.0",
      "device_platform": "webapp",
    };

    var uri = Uri.parse(
      "https://www.douyin.com/aweme/v1/web/user/following/list/",
    ).replace(scheme: "https", port: 443, queryParameters: query);
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var headers = await getRequestHeaders();
    headers["Authority"] = "www.douyin.com";
    headers["Referer"] = "https://www.douyin.com/user/$secUserId";

    var result = await HttpClient.instance.getJson(requestUrl, header: headers);
    if (result is! Map) return null;
    if (result["status_code"] != 0) return null;

    var followList = (result["followings"] as List?) ??
        (result["data"] as List?) ??
        [];
    _logDebug("关注列表第 $page 页返回 ${followList.length} 条，has_more=${result["has_more"]}");

    // 记录下一页游标（根据 DouYin_Spider 实录，下一页以 min_time 作为 max_time）
    var nextCursor = asT<int?>(result["min_time"]) ??
        asT<int?>(result["cursor"]) ??
        asT<int?>(result["max_time"]);
    if (_followCursors.length < page + 1) {
      _followCursors.add(nextCursor);
    } else {
      _followCursors[page] = nextCursor;
    }
    return result as Map<String, dynamic>;
  }

  /// 获取当前登录用户的 sec_uid
  Future<void> _ensureSecUserId() async {
    var uri = Uri.parse("https://www.douyin.com/webcast/user/me/").replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": "6383",
        "app_name": "douyin_web",
        "live_id": "1",
        "device_platform": "webapp",
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);
    var headers = await getRequestHeaders();
    headers["Authority"] = "www.douyin.com";
    headers["Referer"] = "https://www.douyin.com/";

    var result = await HttpClient.instance.getJson(requestUrl, header: headers);
    if (result is Map && result["status_code"] == 0) {
      secUserId = asT<String?>(result["data"]?["sec_uid"]) ?? "";
    }
  }



  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    // 有两种roomId，一种是webRid，一种是roomId
    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // roomId一般长度为19位，例如：7376429659866598196
    // webRid是固定的，用户每次开播都是同一个webRid
    // webRid一般长度为11-12位，例如：416144012050
    // 这里简单进行判断，如果roomId长度小于15，则认为是webRid
    if (roomId.length <= 16) {
      var webRid = roomId;
      return await getRoomDetailByWebRid(webRid);
    }

    return await getRoomDetailByRoomId(roomId);
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);

    // 通过房间信息获取WebRid
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var room = roomData["data"]["room"];
    var owner = room["owner"];

    var status = asT<int?>(room["status"]) ?? 0;

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: owner["nickname"].toString(),
      userAvatar: owner["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["user_count"]) ??
              int.tryParse(room["user_count"]?.toString() ?? "") ??
              asT<int?>(room["room_view_stats"]?["display_value"]) ??
              int.tryParse(room["room_view_stats"]?["display_value"]?.toString() ?? "") ??
              asT<int?>(room["stats"]?["total_user"]) ??
              0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: room["stream_url"],
    );
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e) {
      CoreLog.error(e);
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);

    var roomDataList = data["data"] as List?;
    if (roomDataList == null || roomDataList.isEmpty) {
      throw Exception("抖音直播间 API 返回空房间数据: $webRid");
    }
    var roomData = roomDataList.first as Map;
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = roomData["owner"];

    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();
    return LiveRoomDetail(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : userData["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(roomData["user_count"]) ??
              int.tryParse(roomData["user_count"]?.toString() ?? "") ??
              asT<int?>(roomData["room_view_stats"]?["display_value"]) ??
              int.tryParse(roomData["room_view_stats"]?["display_value"]?.toString() ?? "") ??
              asT<int?>(roomData["stats"]?["total_user"]) ??
              0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidHtml(String webRid) async {
    var roomData = await _getRoomDataByHtml(webRid);
    var roomId = roomData["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    var userUniqueId = roomData["userStore"]["odin"]["user_unique_id"]
        .toString();

    var room = roomData["roomStore"]["roomInfo"]["room"];
    var owner = room["owner"];
    var anchor = roomData["roomStore"]["roomInfo"]["anchor"];
    var roomStatus = (asT<int?>(room["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : anchor["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : anchor["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["user_count"]) ??
              int.tryParse(room["user_count"]?.toString() ?? "") ??
              asT<int?>(room["room_view_stats"]?["display_value"]) ??
              int.tryParse(room["room_view_stats"]?["display_value"]?.toString() ?? "") ??
              asT<int?>(room["stats"]?["total_user"]) ??
              0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? room["stream_url"] : {},
    );
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return webInfo["userStore"]["odin"]["user_unique_id"].toString();
    } catch (e) {
      return generateRandomNumber(12).toString();
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  Future<String> _getWebCookie(String webRid) async {
    var headResp = await HttpClient.instance.head(
      "https://live.douyin.com/$webRid",
      header: headers,
    );
    var dyCookie = "";
    headResp.headers["set-cookie"]?.forEach((element) {
      var cookie = element.split(";")[0];
      if (cookie.contains("ttwid")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("__ac_nonce")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("msToken")) {
        dyCookie += "$cookie;";
      }
    });
    return dyCookie;
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    var dyCookie = await _getWebCookie(webRid);
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "Authority": kDefaultAuthority,
        "Referer": kDefaultReferer,
        "Cookie": dyCookie,
        "User-Agent": kDefaultUserAgent,
      },
    );

    var renderData =
        RegExp(
          r'\{\\"state\\":\{\\"appStore.*?\]\\n',
        ).firstMatch(result)?.group(0) ??
        "";
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    var renderDataJson = json.decode(str);
    return renderDataJson["state"];
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";

    // 提前获取 headers
    var requestHeader = await getRequestHeaders();

    // 使用动态 Referer（包含房间号，参考 DouyinLiveRecorder）
    requestHeader["Referer"] = "https://live.douyin.com/$webRid";

    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Chrome",
        "browser_version": "125.0.0.0",
        "web_rid": webRid,
        "msToken": "",
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: requestHeader,
    );

    if (result is! Map) {
      throw Exception("抖音接口返回格式异常");
    }

    return result["data"];
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    return result;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
    List<LivePlayQuality> qualities = [];

    try {
      var liveCoreData = detail.data["live_core_sdk_data"];

      if (liveCoreData == null) {
        return qualities;
      }

      var pullData = liveCoreData["pull_data"];

      if (pullData == null) {
        return qualities;
      }

      var options = pullData["options"];

      var qulityList = options?["qualities"];

      var streamData = pullData["stream_data"]?.toString() ?? "";

      if (!streamData.startsWith('{')) {
        var flvList = (detail.data["flv_pull_url"] as Map).values
            .cast<String>()
            .toList();
        var hlsList = (detail.data["hls_pull_url_map"] as Map).values
            .cast<String>()
            .toList();
        for (var quality in qulityList) {
          int level = quality["level"];
          List<String> urls = [];
          var flvIndex = flvList.length - level;
          if (flvIndex >= 0 && flvIndex < flvList.length) {
            urls.add(flvList[flvIndex]);
          }
          var hlsIndex = hlsList.length - level;
          if (hlsIndex >= 0 && hlsIndex < hlsList.length) {
            urls.add(hlsList[hlsIndex]);
          }
          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: level,
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      } else {
        var qualityData = json.decode(streamData)["data"] as Map;

        for (var quality in qulityList) {
          List<String> urls = [];

          var flvUrl = qualityData[quality["sdk_key"]]?["main"]?["flv"]
              ?.toString();

          if (flvUrl != null && flvUrl.isNotEmpty) {
            urls.add(flvUrl);
          }
          var hlsUrl = qualityData[quality["sdk_key"]]?["main"]?["hls"]
              ?.toString();

          if (hlsUrl != null && hlsUrl.isNotEmpty) {
            urls.add(hlsUrl);
          }

          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: quality["level"],
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      }
    } catch (e, stackTrace) {
      CoreLog.error(e);
      CoreLog.error(stackTrace);
    }
    // var qualityData = json.decode(
    //     detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    _logDebug("获取到的画质列表: ${qualities.map((q) => q.quality).toList()}");
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    // 返回列表的副本，防止外部 clear() 影响原始数据
    return LivePlayUrl(urls: List<String>.from(quality.data));
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    // 优先按关键词搜索；若未登录或失败且关键词像 web_rid，则回退到房间详情
    try {
      return await _searchRoomsByKeyword(keyword, page: page);
    } catch (e) {
      if (RegExp(r'^\d+$').hasMatch(keyword)) {
        return _searchRoomsByWebRid(keyword);
      }
      rethrow;
    }
  }

  /// 通过抖音 Web 搜索接口按关键词搜索直播间
  Future<LiveSearchRoomResult> _searchRoomsByKeyword(
    String keyword, {
    int page = 1,
  }) async {
    var serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "device_platform": "webapp",
        "aid": "6383",
        "channel": "channel_pc_web",
        "search_channel": "aweme_live",
        "keyword": keyword,
        "search_source": "normal_search",
        "query_correct_type": "1",
        "is_filter_search": "0",
        "from_group_id": "",
        "disable_rs": "0",
        "offset": ((page - 1) * 15).toString(),
        "count": "15",
        "need_filter_settings": "1",
        "list_type": "single",
        "pc_search_top_1_params": '{"enable_ai_search_top_1":1}',
        "update_version_code": "170400",
        "pc_client_type": "1",
        "pc_libra_divert": "Windows",
        "support_h265": "1",
        "support_dash": "1",
        "version_code": "170400",
        "version_name": "17.4.0",
        "cookie_enabled": "true",
        "screen_width": "2048",
        "screen_height": "1152",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Chrome",
        "browser_version": "152.0.0.0",
        "browser_online": "true",
        "engine_name": "Blink",
        "engine_version": "152.0.0.0",
        "os_name": "Windows",
        "os_version": "10",
        "cpu_core_num": "12",
        "device_memory": "32",
        "platform": "PC",
        "downlink": "10",
        "effective_type": "4g",
        "round_trip_time": "50",
        "webid": generateRandomNumber(19).toString(),
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var requestHeaders = await getRequestHeaders();
    requestHeaders["Authority"] = "www.douyin.com";
    requestHeaders["Referer"] =
        "https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live";

    var result = await HttpClient.instance.getJson(
      requestUrl,
      queryParameters: {},
      header: requestHeaders,
    );

    if (result is! Map) {
      throw Exception("抖音搜索接口返回格式异常");
    }

    var statusCode = asT<int?>(result["status_code"]);
    if (statusCode == 2483) {
      throw Exception("抖音搜索需要登录，请配置登录 Cookie 后再试");
    }

    var items = <LiveRoomItem>[];
    var dataList = result["data"] as List? ?? [];
    for (var item in dataList) {
      var lives = item["lives"];
      if (lives == null) continue;
      var rawData = json.decode(lives["rawdata"]?.toString() ?? "{}");
      var owner = rawData["owner"];
      var stats = rawData["stats"] as Map?;
      var roomViewStats = rawData["room_view_stats"] as Map?;
      var online =
          asT<int?>(rawData["user_count"]) ??
          int.tryParse(rawData["user_count"]?.toString() ?? "") ??
          asT<int?>(stats?["total_user"]) ??
          int.tryParse(stats?["total_user"]?.toString() ?? "") ??
          asT<int?>(roomViewStats?["display_value"]) ??
          int.tryParse(roomViewStats?["display_value"]?.toString() ?? "") ??
          0;
      items.add(
        LiveRoomItem(
          roomId: owner?["web_rid"]?.toString() ?? rawData["id_str"]?.toString() ?? "",
          title: rawData["title"]?.toString() ?? "",
          cover: rawData["cover"]?["url_list"]?.first?.toString() ?? "",
          userName: owner?["nickname"]?.toString() ?? "",
          online: online,
        ),
      );
    }

    var hasMore = (result["has_more"] == 1 || result["has_more"] == true) ||
        items.length >= 15;
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
  }

  /// 通过 web_rid 直接获取单个直播间结果（兼容旧逻辑）
  Future<LiveSearchRoomResult> _searchRoomsByWebRid(String webRid) async {
    _logDebug("searchRooms 通过 web_rid 获取房间详情: $webRid");
    var detail = await getRoomDetailByWebRid(webRid);
    var roomItem = LiveRoomItem(
      roomId: detail.roomId,
      title: detail.title,
      cover: detail.cover,
      userName: detail.userName,
      online: detail.online,
    );
    return LiveSearchRoomResult(hasMore: false, items: [roomItem]);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    var roomResult = await _searchRoomsByKeyword(keyword, page: page);
    var anchors = roomResult.items.map((item) {
      return LiveAnchorItem(
        roomId: item.roomId,
        avatar: "",
        userName: item.userName,
        liveStatus: true,
      );
    }).toList();
    return LiveSearchAnchorResult(
      hasMore: roomResult.hasMore,
      items: anchors,
    );
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId);
    return result.status;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
  }) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  // 生成随机的数字
  int generateRandomNumber(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(10));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item);
    }
    return int.tryParse(stringBuffer.toString()) ??
        Random().nextInt(1000000000);
  }
}
