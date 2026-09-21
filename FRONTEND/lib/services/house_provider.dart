import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/house_model.dart';
import '../models/device_model.dart';
import '../models/security_event_model.dart';
import '../models/resident_model.dart';
import '../models/detection_event_model.dart';
import '../models/room_model.dart';
import '../models/rfid_card_model.dart';
import '../models/access_history_model.dart';
import 'api_service.dart';

class HouseProvider extends ChangeNotifier {
  final ApiService _apiService;

  HouseModel? _house;
  List<DeviceModel> _devices = [];
  List<SecurityEventModel> _securityEvents = [];
  List<DetectionEventModel> _detectionEvents = [];
  List<ResidentModel> _residents = [];
  List<RoomModel> _rooms = [];
  List<RfidCardModel> _rfidCards = [];
  List<AccessHistoryModel> _accessHistory = [];
  Map<String, dynamic> _deviceSummary = {};
  String _threatStatus = 'NORMAL';
  SecurityEventModel? _activeThreat;

  bool _isLoading = false;
  String? _errorMessage;

  HouseProvider(this._apiService);

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
  List<RoomModel> get rooms => _rooms;
  List<RfidCardModel> get rfidCards => _rfidCards;
  List<AccessHistoryModel> get accessHistory => _accessHistory;
  Map<String, dynamic> get deviceSummary => _deviceSummary;
  String get threatStatus => _threatStatus;
  SecurityEventModel? get activeThreat => _activeThreat;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> refreshAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      fetchHouseData(),
      fetchDevices(),
      fetchSecurityStatus(),
      fetchDetectionEvents(),
      fetchResidents(),
      fetchRooms(),
      fetchRfidCards(),
      fetchAccessHistory(),
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

  Future<void> fetchSecurityStatus() async {
    try {
      final res = await _apiService.getSecurityStatus();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];

        if (data['securityStatus'] != null && _house != null) {
          _house = _house!.copyWith(securityStatus: data['securityStatus']);
        }

        if (data['recentEvents'] != null) {
          final list = data['recentEvents'] as List;
          _securityEvents = list.map((e) => SecurityEventModel.fromJson(e)).toList();
        }

        if (data['recentDetections'] != null) {
          final list = data['recentDetections'] as List;
          _detectionEvents = list.map((d) => DetectionEventModel.fromJson(d)).toList();
        }

        if (data['recentAccess'] != null) {
          final list = data['recentAccess'] as List;
          _accessHistory = list.map((a) => AccessHistoryModel.fromJson(a)).toList();
        }

        if (data['deviceSummary'] != null) {
          _deviceSummary = Map<String, dynamic>.from(data['deviceSummary']);
        }

        _threatStatus = data['threatStatus'] ?? 'NORMAL';

        if (data['activeThreat'] != null) {
          _activeThreat = SecurityEventModel.fromJson(data['activeThreat']);
        } else {
          _activeThreat = null;
        }

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load security status.';
    }
  }

  Future<void> fetchSecurityEvents() async {
    await fetchSecurityStatus();
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
        await fetchSecurityStatus();
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

  // --- Room Management Methods ---
  Future<void> fetchRooms() async {
    try {
      final res = await _apiService.getRooms();
      if (res['success'] == true && res['data']?['rooms'] != null) {
        final list = res['data']['rooms'] as List;
        _rooms = list.map((r) => RoomModel.fromJson(r)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load rooms.';
    }
  }

  Future<bool> createRoom({
    required String name,
    String roomType = 'OTHER',
    String description = '',
    bool isRestricted = false,
  }) async {
    final res = await _apiService.createRoom(
      name: name,
      roomType: roomType,
      description: description,
      isRestricted: isRestricted,
    );
    if (res['success'] == true) {
      await fetchRooms();
      return true;
    }
    return false;
  }

  Future<bool> updateRoom(
    String roomId, {
    String? name,
    String? roomType,
    String? description,
    bool? isRestricted,
  }) async {
    final res = await _apiService.updateRoom(
      roomId,
      name: name,
      roomType: roomType,
      description: description,
      isRestricted: isRestricted,
    );
    if (res['success'] == true) {
      await fetchRooms();
      return true;
    }
    return false;
  }

  Future<bool> deleteRoom(String roomId) async {
    final res = await _apiService.deleteRoom(roomId);
    if (res['success'] == true) {
      await fetchRooms();
      return true;
    }
    return false;
  }

  Future<bool> setRoomPermission(
    String roomId,
    String residentId, {
    required bool canAccess,
    String? scheduleStart,
    String? scheduleEnd,
    bool isActive = true,
  }) async {
    final res = await _apiService.setRoomPermission(
      roomId,
      residentId,
      canAccess: canAccess,
      scheduleStart: scheduleStart,
      scheduleEnd: scheduleEnd,
      isActive: isActive,
    );
    if (res['success'] == true) {
      await fetchRooms();
      return true;
    }
    return false;
  }

  // --- RFID Management Methods ---
  Future<void> fetchRfidCards() async {
    try {
      final res = await _apiService.getRfidCards();
      if (res['success'] == true && res['data']?['cards'] != null) {
        final list = res['data']['cards'] as List;
        _rfidCards = list.map((c) => RfidCardModel.fromJson(c)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load RFID cards.';
    }
  }

  Future<bool> registerRfidCard({
    required String cardUid,
    required String label,
    String? residentId,
  }) async {
    final res = await _apiService.registerRfidCard(
      cardUid: cardUid,
      label: label,
      residentId: residentId,
    );
    if (res['success'] == true) {
      await fetchRfidCards();
      return true;
    }
    return false;
  }

  Future<bool> updateRfidCard(
    String cardId, {
    String? label,
    String? residentId,
    String? status,
  }) async {
    final res = await _apiService.updateRfidCard(
      cardId,
      label: label,
      residentId: residentId,
      status: status,
    );
    if (res['success'] == true) {
      await fetchRfidCards();
      return true;
    }
    return false;
  }

  Future<bool> deleteRfidCard(String cardId) async {
    final res = await _apiService.deleteRfidCard(cardId);
    if (res['success'] == true) {
      await fetchRfidCards();
      return true;
    }
    return false;
  }

  // --- Access History Audit Methods ---
  Future<void> fetchAccessHistory({String? roomId, String? residentId, String? accessMethod, String? status}) async {
    try {
      final res = await _apiService.getAccessHistory(
        roomId: roomId,
        residentId: residentId,
        accessMethod: accessMethod,
        status: status,
      );
      if (res['success'] == true && res['data']?['logs'] != null) {
        final list = res['data']['logs'] as List;
        _accessHistory = list.map((a) => AccessHistoryModel.fromJson(a)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load access history.';
    }
  }

  // --- Security State & Actions ---
  Future<bool> setSecurityState(String state) async {
    if (_house != null) {
      _house = _house!.copyWith(securityStatus: state);
      notifyListeners();
    }
    final res = await _apiService.setSecurityState(state);
    await fetchSecurityStatus();
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
    await fetchSecurityStatus();
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
