import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api'; // Android Emulator alias for host localhost
    }
    return 'http://localhost:5000/api'; // Windows desktop, Web, macOS, iOS
  }

  String? _authToken;
  String? _currentHouseId;

  void setAuth(String? token, String? houseId) {
    _authToken = token;
    _currentHouseId = houseId;
  }

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      map['Authorization'] = 'Bearer $_authToken';
    }
    if (_currentHouseId != null) {
      map['x-house-id'] = _currentHouseId!;
    }
    return map;
  }

  // --- Auth Endpoints ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 8));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to backend server ($baseUrl). Make sure server is running.'};
    }
  }

  Future<Map<String, dynamic>> registerHomeowner({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? houseName,
    String? address,
    String? houseId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register-homeowner'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'house_name': houseName,
          'address': address,
          if (houseId != null && houseId.isNotEmpty) 'house_id': houseId,
        }),
      ).timeout(const Duration(seconds: 8));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to backend server. Make sure server is running.'};
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch current user'};
    }
  }

  // --- House Endpoints ---
  Future<Map<String, dynamic>> getHouseDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/houses'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load house data'};
    }
  }

  Future<Map<String, dynamic>> updateHouseSettings(Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/houses'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update house settings'};
    }
  }

  // --- Lighting Endpoints ---
  Future<Map<String, dynamic>> getLighting() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lighting'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch lighting status'};
    }
  }

  Future<Map<String, dynamic>> setLightMode(String mode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lighting/mode'),
        headers: _headers,
        body: jsonEncode({'mode': mode}),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to switch lighting mode'};
    }
  }

  Future<Map<String, dynamic>> setBrightness(int brightness, {String? lightId, bool? isOn}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lighting/brightness'),
        headers: _headers,
        body: jsonEncode({
          'brightness_percentage': brightness,
          if (lightId != null) 'light_id': lightId,
          if (isOn != null) 'is_on': isOn,
        }),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to adjust brightness'};
    }
  }

  // --- Security Endpoints ---
  Future<Map<String, dynamic>> getSecurityStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/security'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch security status'};
    }
  }

  Future<Map<String, dynamic>> setSecurityState(String state) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/security/state'),
        headers: _headers,
        body: jsonEncode({'status': state}),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update security state'};
    }
  }

  Future<Map<String, dynamic>> sendSecurityTelemetry(Map<String, dynamic> telemetryData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/security/telemetry/capture'),
        headers: _headers,
        body: jsonEncode(telemetryData),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to send telemetry'};
    }
  }

  Future<Map<String, dynamic>> getDetectionEvents({int limit = 50, String? objectType, String? status}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (objectType != null) 'object_type': objectType,
        if (status != null) 'status': status,
      };
      final uri = Uri.parse('$baseUrl/security/detections').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch detection events'};
    }
  }

  Future<Map<String, dynamic>> getSecurityEventDetails(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/security/events/$eventId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch event details'};
    }
  }

  Future<Map<String, dynamic>> updateSecurityEventStatus(String eventId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/security/events/$eventId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update event status'};
    }
  }

  // --- Emergency Endpoints ---
  Future<Map<String, dynamic>> triggerEmergency(String notes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emergency/trigger'),
        headers: _headers,
        body: jsonEncode({'notes': notes}),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to trigger emergency'};
    }
  }

  Future<Map<String, dynamic>> getEmergencyHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/emergency/history'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch emergency history'};
    }
  }

  // --- Devices Endpoints ---
  Future<Map<String, dynamic>> getDevices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/devices'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch devices'};
    }
  }

  Future<Map<String, dynamic>> registerDevice(Map<String, dynamic> deviceData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: _headers,
        body: jsonEncode(deviceData),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to register device'};
    }
  }

  // --- Residents Endpoints ---
  Future<Map<String, dynamic>> getResidents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/residents'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch residents'};
    }
  }

  Future<Map<String, dynamic>> addResident(Map<String, dynamic> residentData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/residents'),
        headers: _headers,
        body: jsonEncode(residentData),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to add resident'};
    }
  }

  Future<Map<String, dynamic>> updateResidentPermissions(String residentId, Map<String, dynamic> permissions) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/residents/$residentId'),
        headers: _headers,
        body: jsonEncode({'permissions': permissions}),
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update resident'};
    }
  }

  Future<Map<String, dynamic>> deleteResident(String residentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/residents/$residentId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete resident'};
    }
  }

  // --- Admin Endpoints ---
  Future<Map<String, dynamic>> getAdminHomeowners() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/homeowners'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch homeowner accounts'};
    }
  }

  Future<Map<String, dynamic>> createAdminHomeowner(Map<String, dynamic> homeownerData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/homeowners'),
        headers: _headers,
        body: jsonEncode(homeownerData),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create homeowner account'};
    }
  }

  Future<Map<String, dynamic>> updateAdminHomeowner(String userId, Map<String, dynamic> homeownerData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/homeowners/$userId'),
        headers: _headers,
        body: jsonEncode(homeownerData),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update homeowner account'};
    }
  }

  Future<Map<String, dynamic>> updateAccountStatus(String userId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update account status'};
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String userId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/admin/users/$userId'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete account'};
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/stats'), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch platform statistics'};
    }
  }

  // --- Payment Endpoints ---
  Future<Map<String, dynamic>> submitPayment({
    required String subscriptionPlan,
    required String paymentMethod,
    required String paymentReference,
    double? paymentAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/houses/payment/submit'),
        headers: _headers,
        body: jsonEncode({
          'subscription_plan': subscriptionPlan,
          'payment_method': paymentMethod,
          'payment_reference': paymentReference,
          'payment_amount': paymentAmount,
        }),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit payment transaction'};
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/houses/payment/status'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load payment status'};
    }
  }

  Future<Map<String, dynamic>> validateAdminPayment(String userId, String action, {String? rejectionReason}) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/homeowners/$userId/payment'),
        headers: _headers,
        body: jsonEncode({
          'action': action, // 'APPROVE' or 'REJECT'
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
        }),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update payment validation status'};
    }
  }

  // --- Hardware Device Ordering & Admin Provisioning ---
  Future<Map<String, dynamic>> orderDevice(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/houses/devices/order'),
        headers: _headers,
        body: jsonEncode(orderData),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit hardware device order'};
    }
  }

  Future<Map<String, dynamic>> getHouseDeviceOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/houses/devices/orders'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load device orders'};
    }
  }

  Future<Map<String, dynamic>> provisionDeviceToHouse(String houseId, Map<String, dynamic> deviceData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/houses/$houseId/devices'),
        headers: _headers,
        body: jsonEncode(deviceData),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to provision hardware device'};
    }
  }

  Future<Map<String, dynamic>> getAdminDeviceOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/device-orders'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load device orders'};
    }
  }
}
