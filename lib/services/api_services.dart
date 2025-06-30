import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// API 常量类，提取重复的配置
class ApiConstants {
  static const Duration timeout = Duration(seconds: 10); // 统一超时时间
  static const String contentType = 'application/json'; // 统一 Content-Type
  static const String sendCodePath = '/v1/passport/comm/sendEmailVerify';// 发送验证码
  static const String resetPasswordPath = '/v1/passport/auth/forget';// 重置密码
  static const String loginPath = '/v1/passport/auth/login';// 登录
  static const String registerPath = '/v1/passport/auth/register';// 注册
  static const String subscribePath = '/v1/user/getSubscribe';// 获取订阅路径
  static const String subscribeListPath = '/v1/user/plan/fetch'; // 商品列表路径
  static const String paymentMethodsPath = '/v1/user/order/getPaymentMethod'; // 获取支付方式
  static const String purchaseOrderPath = '/v1/user/order/save'; // 创建订单
  static const String checkoutOrderPath = '/v1/user/order/checkout'; // 付款
  static const String orderDetailPath = '/v1/user/order/detail'; // 订单状态
  static const String closeOrderPath = '/v1/user/order/cancel'; // 取消订单
  static const String userInfoPath = '/v1/user/info'; // 用户信息路径
  static const String orderListPath = '/v1/user/order/fetch'; // 订单列表路径
}

// API 服务类，提供认证相关接口调用
class ApiService {
  // 通用 HTTP 请求方法，封装重复逻辑
  static Future<Map<String, dynamic>> _request(
    String url, {
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    headers ??= {'Content-Type': ApiConstants.contentType}; // 默认 JSON 格式
    final response = method == 'POST'
        ? await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(ApiConstants.timeout)
        : await http
            .get(uri, headers: headers)
            .timeout(ApiConstants.timeout);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // 输入验证辅助方法
  static void _validateEmail(String email) {
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw Exception('无效的邮箱格式');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw Exception('密码长度必须大于6位');
    }
  }

  static void _validateCode(String code) {
    if (code.isEmpty || code.length < 4) {
      throw Exception('验证码无效');
    }
  }

  // 发送验证码到指定邮箱
  static Future<Map<String, dynamic>> sendCode({
    required String apiBaseUrl,
    required String email,
    required int type,
  }) async {
    _validateEmail(email);
    return _request(
      '$apiBaseUrl${ApiConstants.sendCodePath}',
      method: 'POST',
      body: {'email': email, 'type': type},
    );
  }
// 获取订单列表
  static Future<Map<String, dynamic>> getOrderList({
    required String apiBaseUrl,
    required String token,
    required int page,
    required int size,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    
    final uri = '$apiBaseUrl${ApiConstants.orderListPath}?page=$page&size=$size';
    final data = await _request(
      uri,
      method: 'GET',
      headers: headers,
    );

    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取订单列表失败');
    }
    
    return data['data'] as Map<String, dynamic>;
  }
  // 重置密码
  static Future<Map<String, dynamic>> resetPassword({
    required String apiBaseUrl,
    required String email,
    required String password,
    required String code,
    String? token,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    _validateCode(code);
    final headers = {'Content-Type': ApiConstants.contentType};
    if (token != null) {
      headers['Authorization'] = ' $token';
    }
    return _request(
      '$apiBaseUrl${ApiConstants.resetPasswordPath}',
      method: 'POST',
      headers: headers,
      body: {
        'email': email,
        'password': password,
        'code': code,
      },
    );
  }

  // 登录请求
  static Future<Map<String, dynamic>> login({
    required String apiBaseUrl,
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    return _request(
      '$apiBaseUrl${ApiConstants.loginPath}',
      method: 'POST',
      body: {'email': email, 'password': password},
    );
  }

  // 获取支付方式
  static Future<List<Map<String, dynamic>>> getPaymentMethods({
    required String apiBaseUrl,
    required String token,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final data = await _request(
      '$apiBaseUrl${ApiConstants.paymentMethodsPath}',
      method: 'GET',
      headers: headers,
    );
    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取支付方式失败');
    }
    final list = (data['data']['list'] as List<dynamic>?) ?? [];
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  // 创建订单
  static Future<String> createOrder({
    required String apiBaseUrl,
    required String token,
    required int subscribeId,
    required int quantity,
    required int paymentId,
    String? coupon,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final body = {
      'subscribe_id': subscribeId,
      'quantity': quantity,
      'payment': paymentId,
      if (coupon != null) 'coupon': coupon,
    };
    final data = await _request(
      '$apiBaseUrl${ApiConstants.purchaseOrderPath}',
      method: 'POST',
      headers: headers,
      body: body,
    );
    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '创建订单失败');
    }
    return data['data']['order_no'] as String;
  }

  // 付款
  static Future<Map<String, dynamic>> checkoutOrder({
    required String apiBaseUrl,
    required String token,
    required String orderNo,
    required String returnUrl,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final body = {
      'orderNo': orderNo,
      'returnUrl': returnUrl,
    };
    final data = await _request(
      '$apiBaseUrl${ApiConstants.checkoutOrderPath}',
      method: 'POST',
      headers: headers,
      body: body,
    );
    if (data['code'] != 200) {
      throw Exception(data['msg'] ?? '付款请求失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  // 检测订单状态
  static Future<Map<String, dynamic>> getOrderDetail({
    required String apiBaseUrl,
    required String token,
    required String orderNo,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final uri = '$apiBaseUrl${ApiConstants.orderDetailPath}?order_no=$orderNo';
    final data = await _request(
      uri,
      method: 'GET',
      headers: headers,
    );
    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取订单详情失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  // 取消订单
  static Future<void> closeOrder({
    required String apiBaseUrl,
    required String token,
    required String orderNo,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final body = {'orderNo': orderNo};
    final data = await _request(
      '$apiBaseUrl${ApiConstants.closeOrderPath}',
      method: 'POST',
      headers: headers,
      body: body,
    );
    if (data['code'] != 200) {
      throw Exception(data['msg'] ?? '取消订单失败');
    }
  }

  // 注册请求
  static Future<Map<String, dynamic>> register({
    required String apiBaseUrl,
    required String email,
    required String password,
    required String invite,
    String? code,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    if (code != null && code.isNotEmpty) _validateCode(code);
    return _request(
      '$apiBaseUrl${ApiConstants.registerPath}',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
        'invite': invite,
        'code': code?.isEmpty ?? true ? null : code,
      },
    );
  }

  // 获取用户订阅信息并构建订阅 URL
  static Future<List<Map<String, String>>> getUserSubscribe({
    required String apiBaseUrl,
    required String token,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final data = await _request(
      '$apiBaseUrl${ApiConstants.subscribePath}',
      method: 'GET',
      headers: headers,
    );

    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取用户订阅信息失败');
    }

    final list = (data['data']['list'] as List<dynamic>?) ?? [];
    if (list.isEmpty) {
      throw Exception('响应中未找到订阅');
    }

    final subscribeDetails = <Map<String, String>>[];
    for (var item in list) {
      final subscription = item as Map<String, dynamic>;
      final subscribeToken = subscription['token'] as String?;
      final subscribeName = (subscription['subscribe'] as Map<String, dynamic>?)?['name'] as String?;
      if (subscribeToken != null && subscribeToken.isNotEmpty && subscribeName != null) {
        subscribeDetails.add({
          'url': '$apiBaseUrl/api/subscribe?token=$subscribeToken',
          'name': subscribeName,
        });
      }
    }

    if (subscribeDetails.isEmpty) {
      throw Exception('订阅数据中未找到有效的 token 或 name');
    }

    return subscribeDetails;
  }

  // 获取商品内容详情（订阅列表）
  static Future<List<Map<String, dynamic>>> getSubscribeList({
    required String apiBaseUrl,
    required String token,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    final data = await _request(
      '$apiBaseUrl${ApiConstants.subscribeListPath}',
      method: 'GET',
      headers: headers,
    );

    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取订阅商品列表失败');
    }

    final listData = data['data'] as Map<String, dynamic>;
    final list = (listData['list'] as List<dynamic>?) ?? [];
    
    return list.map((item) => item as Map<String, dynamic>).toList();
  }

  // 获取用户信息
  static Future<Map<String, dynamic>> getUserInfo({
    required String apiBaseUrl,
    required String token,
  }) async {
    final headers = {
      'Content-Type': ApiConstants.contentType,
      'Authorization': ' $token',
    };
    
    final data = await _request(
      '$apiBaseUrl${ApiConstants.userInfoPath}',
      method: 'GET',
      headers: headers,
    );

    if (data['code'] != 200 || data['data'] == null) {
      throw Exception(data['msg'] ?? '获取用户信息失败');
    }
    
    return data['data'] as Map<String, dynamic>;
  }
}
