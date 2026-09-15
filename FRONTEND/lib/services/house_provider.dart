import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/house_model.dart';
import '../models/device_model.dart';
import '../models/security_event_model.dart';
import '../models/resident_model.dart';
import '../models/detection_event_model.dart';
import 'api_service.dart';

class HouseProvider extends ChangeNotifier {
  final ApiService _apiService;

  HouseModel? _house;
  List<DeviceModel> _devices = [];
  List<SecurityEventModel> _securityEvents = [];
  List<DetectionEventModel> _detectionEvents = [];
  List<ResidentModel> _residents = [];
  bool _isLoading = false;
  String? _errorMessage;

  HouseProvider(this._apiService) {
    refreshAll();
  }

  HouseModel get house =>
      _house ??
      HouseModel(
        id: '',
        name: 'Connecting...',
        address: 'Fetching live house data...',
        securityStatus: 'DISARMED',
        lightMode: 'AUTO',
        globalBrightness: 75,
        emergencyContactPolice: '911',
        emergencyContactSecurity: '+1-800-VIGILIS',
      );

  List<DeviceModel> get devices => _devices;
  List<SecurityEventModel> get securityEvents => _securityEvents;
  List<DetectionEventModel> get detectionEvents => _detectionEvents;
  List<ResidentModel> get residents => _residents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> refreshAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      fetchHouseData(),
      fetchDevices(),
      fetchSecurityEvents(),
      fetchDetectionEvents(),
      fetchResidents(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHouseData() async {
    try {
      final res = await _apiService.getHouseDetails();
      if (res['success'] == true && res['data']?['house'] != null) {
        _house = HouseModel.fromJson(res['data']['house']);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load house data.';
    }
  }

  Future<void> fetchDevices() async {
    try {
      final res = await _apiService.getDevices();
      if (res['success'] == true && res['data']?['devices'] != null) {
        final list = res['data']['devices'] as List;
        _devices = list.map((d) => DeviceModel.fromJson(d)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load devices.';
    }
  }

  Future<void> fetchSecurityEvents() async {
    try {
      final res = await _apiService.getSecurityStatus();
      if (res['success'] == true && res['data']?['recentEvents'] != null) {
        final list = res['data']['recentEvents'] as List;
        _securityEvents = list.map((e) => SecurityEventModel.fromJson(e)).toList();
        if (res['data']['securityStatus'] != null && _house != null) {
          _house = _house!.copyWith(securityStatus: res['data']['securityStatus']);
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load security events.';
    }
  }

  Future<void> fetchDetectionEvents() async {
    try {
      final res = await _apiService.getDetectionEvents(limit: 30);
      if (res['success'] == true && res['data']?['detections'] != null) {
        final list = res['data']['detections'] as List;
        _detectionEvents = list.map((d) => DetectionEventModel.fromJson(d)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load detection events.';
    }
  }

  Future<bool> updateSecurityEventStatus(String eventId, String status) async {
    try {
      final res = await _apiService.updateSecurityEventStatus(eventId, status);
      if (res['success'] == true) {
        await fetchSecurityEvents();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchResidents() async {
    try {
      final res = await _apiService.getResidents();
      if (res['success'] == true && res['data']?['residents'] != null) {
        final list = res['data']['residents'] as List;
        _residents = list.map((r) => ResidentModel.fromJson(r)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load residents.';
    }
  }

  Future<bool> setSecurityState(String state) async {
    if (_house != null) {
      _house = _house!.copyWith(securityStatus: state);
      notifyListeners();
    }
    final res = await _apiService.setSecurityState(state);
    await fetchSecurityEvents();
    return res['success'] == true;
  }

  Future<bool> setLightMode(String mode) async {
    if (_house != null) {
      _house = _house!.copyWith(lightMode: mode);
      notifyListeners();
    }
    final res = await _apiService.setLightMode(mode);
    await fetchDevices();
    return res['success'] == true;
  }

  Future<bool> setBrightness(int brightness) async {
    if (_house != null) {
      _house = _house!.copyWith(globalBrightness: brightness, lightMode: 'MANUAL');
      notifyListeners();
    }
    final res = await _apiService.setBrightness(brightness);
    await fetchDevices();
    return res['success'] == true;
  }

  Future<bool> triggerEmergency({String notes = 'Manual App Trigger'}) async {
    // Buzz device with haptic alarm feedback
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 500), () => HapticFeedback.vibrate());
    } catch (_) {}

    if (_house != null) {
      _house = _house!.copyWith(securityStatus: 'ALARM_TRIGGERED');
      notifyListeners();
    }

    final res = await _apiService.triggerEmergency(notes);
    await fetchSecurityEvents();
    return res['success'] == true;
  }

  Future<bool> addDevice(Map<String, dynamic> deviceData) async {
    final res = await _apiService.registerDevice(deviceData);
    if (res['success'] == true) {
      await fetchDevices();
      return true;
    }
    return false;
  }

  Future<bool> addResident(Map<String, dynamic> residentData) async {
    final res = await _apiService.addResident(residentData);
    if (res['success'] == true) {
      await fetchResidents();
      return true;
    }
    return false;
  }

  Future<bool> updateResidentPermissions(String residentId, Map<String, dynamic> permissions) async {
    final res = await _apiService.updateResidentPermissions(residentId, permissions);
    if (res['success'] == true) {
      await fetchResidents();
      return true;
    }
    return false;
  }

  Future<bool> deleteResident(String residentId) async {
    final res = await _apiService.deleteResident(residentId);
    if (res['success'] == true) {
      await fetchResidents();
      return true;
    }
    return false;
  }
}
