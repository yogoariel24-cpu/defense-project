import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider([ApiService? apiService]) : _apiService = apiService ?? ApiService();

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  bool get isPlatformAdmin => _currentUser?.role == 'PLATFORM_ADMIN';
  bool get isHomeowner => _currentUser?.role == 'HOMEOWNER';
  bool get isResident => _currentUser?.role == 'RESIDENT';

  ApiService get apiService => _apiService;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.login(email, password);
      if (res['success'] == true && res['data'] != null) {
        _token = res['data']['token'];
        _currentUser = UserModel.fromJson(res['data']['user']);
        _apiService.setAuth(_token, _currentUser?.houseId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Login failed. Please check credentials.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerHomeowner({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? houseName,
    String? address,
    String? houseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.registerHomeowner(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        houseName: houseName,
        address: address,
        houseId: houseId,
      );

      if (res['success'] == true && res['data'] != null) {
        _token = res['data']['token'];
        _currentUser = UserModel.fromJson(res['data']['user']);
        _apiService.setAuth(_token, _currentUser?.houseId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Registration failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _token = null;
    _apiService.setAuth(null, null);
    notifyListeners();
  }
}
